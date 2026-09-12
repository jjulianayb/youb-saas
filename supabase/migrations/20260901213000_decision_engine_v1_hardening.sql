-- youB — Decision Engine V1 hardening
-- Additive hardening only. Keeps intelligence_decisions as current state while
-- requiring controlled revision/approval/supersession paths for authenticated users.

-- In V1, the predecessor becomes superseded. It does not point forward to its
-- successor. The existing self/cross-tenant FK remains the guard for a NEW row's
-- supersedes_decision_id.
alter table public.intelligence_decisions
  drop constraint if exists intelligence_decisions_superseded_target_check;

create table if not exists public.intelligence_decision_revisions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  decision_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  changed_by_user_id uuid not null references auth.users(id) on delete restrict,
  change_reason text not null check (btrim(change_reason) <> ''),
  previous_snapshot jsonb not null check (jsonb_typeof(previous_snapshot) = 'object'),
  new_snapshot jsonb not null check (jsonb_typeof(new_snapshot) = 'object'),
  created_at timestamptz not null default now(),
  constraint intelligence_decision_revisions_unique unique (organization_id, decision_id, revision_number),
  constraint intelligence_decision_revisions_decision_same_org_fkey
    foreign key (organization_id, decision_id)
    references public.intelligence_decisions(organization_id, id) on delete cascade
);

create index if not exists idx_intelligence_decision_revisions_org_decision
  on public.intelligence_decision_revisions(organization_id, decision_id, revision_number desc);

-- Snapshot contract used by the controlled revision paths. It intentionally
-- contains decision content and lifecycle provenance, never raw conversation.
create or replace function public.intelligence_decision_snapshot(p_decision public.intelligence_decisions)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'decision_type', p_decision.decision_type,
    'scope_type', p_decision.scope_type,
    'scope_ref', p_decision.scope_ref,
    'recommendation_id', p_decision.recommendation_id,
    'decision_statement', p_decision.decision_statement,
    'selected_option', p_decision.selected_option,
    'alternatives_considered', p_decision.alternatives_considered,
    'rationale', p_decision.rationale,
    'evidence_snapshot', p_decision.evidence_snapshot,
    'unknowns', p_decision.unknowns,
    'risk_level', p_decision.risk_level,
    'risk_accepted', p_decision.risk_accepted,
    'status', p_decision.status,
    'owner_employee_id', p_decision.owner_employee_id,
    'decision_maker_user_id', p_decision.decision_maker_user_id,
    'approval_required', p_decision.approval_required,
    'required_approver_role', p_decision.required_approver_role,
    'approved_by', p_decision.approved_by,
    'approved_at', p_decision.approved_at,
    'effective_at', p_decision.effective_at,
    'review_at', p_decision.review_at,
    'supersedes_decision_id', p_decision.supersedes_decision_id,
    'context', p_decision.context
  );
$$;

-- Internal append-only writer. It is callable only by the controlled
-- security-definer functions below, never directly by an authenticated client.
create or replace function public._intelligence_append_decision_revision(
  p_organization_id uuid,
  p_decision_id uuid,
  p_previous_snapshot jsonb,
  p_new_snapshot jsonb,
  p_change_reason text
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  next_revision integer;
begin
  if p_change_reason is null or btrim(p_change_reason) = '' then
    raise exception 'decision revision requires a change reason';
  end if;
  if jsonb_typeof(p_previous_snapshot) <> 'object' or jsonb_typeof(p_new_snapshot) <> 'object' then
    raise exception 'decision revision snapshots must be JSON objects';
  end if;
  select coalesce(max(revision_number), 0) + 1
    into next_revision
    from public.intelligence_decision_revisions
   where organization_id = p_organization_id
     and decision_id = p_decision_id;
  insert into public.intelligence_decision_revisions(
    organization_id, decision_id, revision_number, changed_by_user_id,
    change_reason, previous_snapshot, new_snapshot
  ) values (
    p_organization_id, p_decision_id, next_revision, auth.uid(),
    p_change_reason, p_previous_snapshot, p_new_snapshot
  );
  return next_revision;
end;
$$;

-- Direct table updates/deletes are removed from the authenticated surface. A
-- revision must be appended and the current row changed atomically by a
-- controlled function, so content cannot be silently overwritten.
revoke update, delete on public.intelligence_decisions from authenticated;
drop policy if exists intelligence_decisions_update_admin on public.intelligence_decisions;
drop policy if exists intelligence_decisions_delete_admin on public.intelligence_decisions;
drop policy if exists intelligence_decisions_approve_directoria on public.intelligence_decisions;
drop policy if exists intelligence_decisions_insert_admin on public.intelligence_decisions;
drop policy if exists intelligence_decisions_insert_directoria on public.intelligence_decisions;
create policy intelligence_decisions_insert_admin on public.intelligence_decisions
  for insert to authenticated with check (
    public.intelligence_is_admin(organization_id)
    and supersedes_decision_id is null
    and status <> 'superseded'
  );
create policy intelligence_decisions_insert_directoria on public.intelligence_decisions
  for insert to authenticated with check (
    public.has_org_role(organization_id, array['diretoria'])
    and scope_type in ('team','area','unit','process','organization')
    and approval_required = false
    and decision_maker_user_id = auth.uid()
    and status in ('draft','pending_review','decided')
    and supersedes_decision_id is null
  );

-- Revision visibility follows the same conservative decision visibility rules.
alter table public.intelligence_decision_revisions enable row level security;
drop policy if exists intelligence_decision_revisions_select_role on public.intelligence_decision_revisions;
create policy intelligence_decision_revisions_select_role on public.intelligence_decision_revisions
  for select to authenticated using (
    public.intelligence_is_admin(organization_id)
    or exists (
      select 1 from public.intelligence_decisions d
      where d.organization_id = intelligence_decision_revisions.organization_id
        and d.id = intelligence_decision_revisions.decision_id
        and public.has_org_role(d.organization_id, array['diretoria'])
        and d.scope_type in ('team','area','unit','process','organization')
    )
  );
revoke insert, update, delete on public.intelligence_decision_revisions from authenticated;
grant select on public.intelligence_decision_revisions to authenticated;

-- The event catalog is an explicit future-service contract. No trigger writes it.
insert into public.organizational_event_types(event_type, description, implemented) values
  ('decision_revised','Decision content was revised through the controlled revision path.',true),
  ('decision_returned_for_review','A decision was returned to review before approval.',true),
  ('decision_approved','A required human approval was recorded for a decision.',true)
on conflict (event_type) do nothing;

create or replace function public.revise_intelligence_decision(
  p_decision_id uuid,
  p_new_snapshot jsonb,
  p_change_reason text
)
returns public.intelligence_decisions
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  d public.intelligence_decisions%rowtype;
  v_new public.intelligence_decisions%rowtype;
  v_previous_snapshot jsonb;
  v_new_snapshot jsonb;
  v_key text;
  v_target_status text;
begin
  if auth.uid() is null then raise exception 'decision revision requires an authenticated actor'; end if;
  if jsonb_typeof(p_new_snapshot) <> 'object' then raise exception 'decision revision snapshot must be a JSON object'; end if;
  foreach v_key in array array['scope_type','scope_ref','decision_statement','selected_option','alternatives_considered','rationale','evidence_snapshot','unknowns','risk_level','risk_accepted'] loop
    if not (p_new_snapshot ? v_key) then raise exception 'decision revision snapshot is missing %', v_key; end if;
  end loop;
  select * into d from public.intelligence_decisions where id = p_decision_id for update;
  if not found then raise exception 'decision not found'; end if;
  if not public.is_org_member(d.organization_id) then raise exception 'actor is not a member of this organization'; end if;
  if not public.intelligence_is_admin(d.organization_id)
     and not (public.has_org_role(d.organization_id, array['diretoria']) and d.scope_type in ('team','area','unit','process','organization')) then
    raise exception 'actor is not authorized to revise this decision';
  end if;
  if d.status in ('draft','pending_review') then
    v_target_status := d.status;
  elsif d.status = 'pending_approval'
        and public.has_org_role(d.organization_id, array['diretoria'])
        and d.required_approver_role = 'diretoria' then
    v_target_status := 'pending_review';
  else
    raise exception 'decision content can only be revised in draft, pending_review, or returned from pending_approval';
  end if;
  if public.has_org_role(d.organization_id, array['diretoria']) and not public.intelligence_is_admin(d.organization_id)
     and (p_new_snapshot->>'scope_type') not in ('team','area','unit','process','organization') then
    raise exception 'diretoria cannot revise this decision outside organizational scope';
  end if;
  if btrim(coalesce(p_new_snapshot->>'scope_ref','')) = '' or btrim(coalesce(p_new_snapshot->>'decision_statement','')) = '' then
    raise exception 'scope_ref and decision_statement are required';
  end if;
  if jsonb_typeof(p_new_snapshot->'alternatives_considered') <> 'array'
     or jsonb_typeof(p_new_snapshot->'evidence_snapshot') <> 'object'
     or jsonb_typeof(p_new_snapshot->'unknowns') <> 'array'
     or jsonb_typeof(p_new_snapshot->'risk_accepted') <> 'boolean' then
    raise exception 'decision revision JSON shapes are invalid';
  end if;
  v_new := d;
  v_new.scope_type := p_new_snapshot->>'scope_type';
  v_new.scope_ref := p_new_snapshot->>'scope_ref';
  v_new.decision_statement := p_new_snapshot->>'decision_statement';
  v_new.selected_option := p_new_snapshot->>'selected_option';
  v_new.alternatives_considered := p_new_snapshot->'alternatives_considered';
  v_new.rationale := p_new_snapshot->>'rationale';
  v_new.evidence_snapshot := p_new_snapshot->'evidence_snapshot';
  v_new.unknowns := p_new_snapshot->'unknowns';
  v_new.risk_level := p_new_snapshot->>'risk_level';
  v_new.risk_accepted := (p_new_snapshot->>'risk_accepted')::boolean;
  v_new.status := v_target_status;
  v_new.approved_by := null;
  v_new.approved_at := null;
  v_previous_snapshot := public.intelligence_decision_snapshot(d);
  v_new_snapshot := public.intelligence_decision_snapshot(v_new);
  perform public._intelligence_append_decision_revision(d.organization_id, d.id, v_previous_snapshot, v_new_snapshot, p_change_reason);
  update public.intelligence_decisions set
    scope_type=v_new.scope_type, scope_ref=v_new.scope_ref,
    decision_statement=v_new.decision_statement, selected_option=v_new.selected_option,
    alternatives_considered=v_new.alternatives_considered, rationale=v_new.rationale,
    evidence_snapshot=v_new.evidence_snapshot, unknowns=v_new.unknowns,
    risk_level=v_new.risk_level, risk_accepted=v_new.risk_accepted,
    status=v_new.status, approved_by=null, approved_at=null, updated_at=now()
  where id=d.id;
  select * into d from public.intelligence_decisions where id=p_decision_id;
  return d;
end;
$$;

create or replace function public.approve_intelligence_decision(p_decision_id uuid)
returns public.intelligence_decisions
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare d public.intelligence_decisions%rowtype;
begin
  if auth.uid() is null then raise exception 'decision approval requires an authenticated actor'; end if;
  select * into d from public.intelligence_decisions where id=p_decision_id for update;
  if not found then raise exception 'decision not found'; end if;
  if not public.is_org_member(d.organization_id)
     or not public.has_org_role(d.organization_id, array['diretoria'])
     or d.scope_type not in ('team','area','unit','process','organization')
     or d.approval_required is not true
     or d.required_approver_role <> 'diretoria'
     or d.status <> 'pending_approval' then
    raise exception 'actor is not the required diretoria approver for this decision';
  end if;
  update public.intelligence_decisions set approved_by=auth.uid(), approved_at=now(), status='decided', updated_at=now() where id=d.id;
  select * into d from public.intelligence_decisions where id=p_decision_id;
  return d;
end;
$$;

create or replace function public.return_intelligence_decision_for_review(p_decision_id uuid, p_change_reason text)
returns public.intelligence_decisions
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare d public.intelligence_decisions%rowtype; v_new_snapshot jsonb;
begin
  if auth.uid() is null then raise exception 'decision review return requires an authenticated actor'; end if;
  select * into d from public.intelligence_decisions where id=p_decision_id for update;
  if not found then raise exception 'decision not found'; end if;
  if not public.is_org_member(d.organization_id) or not public.has_org_role(d.organization_id, array['diretoria'])
     or d.scope_type not in ('team','area','unit','process','organization')
     or d.approval_required is not true or d.required_approver_role <> 'diretoria' or d.status <> 'pending_approval' then
    raise exception 'only the required diretoria approver can return this decision for review';
  end if;
  v_new_snapshot := jsonb_set(public.intelligence_decision_snapshot(d), '{status}', to_jsonb('pending_review'::text), true);
  perform public._intelligence_append_decision_revision(d.organization_id, d.id, public.intelligence_decision_snapshot(d), v_new_snapshot, p_change_reason);
  update public.intelligence_decisions set status='pending_review', approved_by=null, approved_at=null, updated_at=now() where id=d.id;
  select * into d from public.intelligence_decisions where id=p_decision_id;
  return d;
end;
$$;

create or replace function public.reject_intelligence_decision(p_decision_id uuid, p_change_reason text)
returns public.intelligence_decisions
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare d public.intelligence_decisions%rowtype; v_new_snapshot jsonb;
begin
  if auth.uid() is null then raise exception 'decision rejection requires an authenticated actor'; end if;
  select * into d from public.intelligence_decisions where id=p_decision_id for update;
  if not found then raise exception 'decision not found'; end if;
  if not public.is_org_member(d.organization_id) or not public.has_org_role(d.organization_id, array['diretoria'])
     or d.scope_type not in ('team','area','unit','process','organization')
     or d.approval_required is not true or d.required_approver_role <> 'diretoria' or d.status <> 'pending_approval' then
    raise exception 'only the required diretoria approver can reject this decision';
  end if;
  v_new_snapshot := jsonb_set(public.intelligence_decision_snapshot(d), '{status}', to_jsonb('cancelled'::text), true);
  perform public._intelligence_append_decision_revision(d.organization_id, d.id, public.intelligence_decision_snapshot(d), v_new_snapshot, p_change_reason);
  update public.intelligence_decisions set status='cancelled', approved_by=null, approved_at=null, updated_at=now() where id=d.id;
  select * into d from public.intelligence_decisions where id=p_decision_id;
  return d;
end;
$$;

create or replace function public.create_superseding_intelligence_decision(
  p_previous_decision_id uuid,
  p_new_snapshot jsonb,
  p_change_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  previous_decision public.intelligence_decisions%rowtype;
  new_id uuid;
  v_previous_snapshot jsonb;
  v_new_snapshot jsonb;
  v_status text;
  v_requested_status text;
  v_approval_required boolean;
  v_required_role text;
  v_effective_at timestamptz;
  v_recommendation_id uuid;
  v_owner_employee_id uuid;
  v_key text;
begin
  if auth.uid() is null then raise exception 'superseding decision requires an authenticated actor'; end if;
  if jsonb_typeof(p_new_snapshot) <> 'object' then raise exception 'new decision snapshot must be a JSON object'; end if;
  foreach v_key in array array['decision_type','scope_type','scope_ref','decision_statement','selected_option','alternatives_considered','rationale','evidence_snapshot','unknowns','risk_level','risk_accepted','status','approval_required','context'] loop
    if not (p_new_snapshot ? v_key) then raise exception 'new decision snapshot is missing %', v_key; end if;
  end loop;
  select * into previous_decision from public.intelligence_decisions where id=p_previous_decision_id for update;
  if not found then raise exception 'previous decision not found'; end if;
  if not public.is_org_member(previous_decision.organization_id) then raise exception 'actor is not a member of this organization'; end if;
  if not public.intelligence_is_admin(previous_decision.organization_id)
     and not (public.has_org_role(previous_decision.organization_id, array['diretoria']) and previous_decision.scope_type in ('team','area','unit','process','organization')) then
    raise exception 'actor is not authorized to supersede this decision';
  end if;
  if previous_decision.status not in ('decided','effective') then raise exception 'only decided or effective decisions can be superseded'; end if;
  if btrim(coalesce(p_new_snapshot->>'scope_ref',''))='' or btrim(coalesce(p_new_snapshot->>'decision_statement',''))='' then raise exception 'scope_ref and decision_statement are required'; end if;
  if jsonb_typeof(p_new_snapshot->'alternatives_considered') <> 'array' or jsonb_typeof(p_new_snapshot->'evidence_snapshot') <> 'object' or jsonb_typeof(p_new_snapshot->'unknowns') <> 'array' or jsonb_typeof(p_new_snapshot->'risk_accepted') <> 'boolean' or jsonb_typeof(p_new_snapshot->'approval_required') <> 'boolean' then
    raise exception 'new decision JSON shapes are invalid';
  end if;
  if public.has_org_role(previous_decision.organization_id, array['diretoria']) and not public.intelligence_is_admin(previous_decision.organization_id)
     and (p_new_snapshot->>'scope_type') not in ('team','area','unit','process','organization') then
    raise exception 'diretoria cannot create this superseding scope';
  end if;
  v_requested_status := p_new_snapshot->>'status';
  if v_requested_status not in ('decided','effective') then raise exception 'successor status must be decided or effective'; end if;
  v_approval_required := (p_new_snapshot->>'approval_required')::boolean;
  v_required_role := nullif(p_new_snapshot->>'required_approver_role','');
  if v_approval_required and v_required_role is null then raise exception 'approval-required successor needs an approver role'; end if;
  if not v_approval_required and v_required_role is not null then raise exception 'non-approval successor cannot name an approver role'; end if;
  v_status := case when v_approval_required then 'pending_approval' else v_requested_status end;
  v_effective_at := nullif(p_new_snapshot->>'effective_at','')::timestamptz;
  if v_status='effective' and v_effective_at is null then raise exception 'effective successor needs effective_at'; end if;
  v_recommendation_id := nullif(p_new_snapshot->>'recommendation_id','')::uuid;
  v_owner_employee_id := nullif(p_new_snapshot->>'owner_employee_id','')::uuid;
  insert into public.intelligence_decisions(
    organization_id,decision_type,scope_type,scope_ref,recommendation_id,decision_statement,selected_option,alternatives_considered,rationale,evidence_snapshot,unknowns,risk_level,risk_accepted,status,owner_employee_id,decision_maker_user_id,approval_required,required_approver_role,effective_at,supersedes_decision_id,context
  ) values (
    previous_decision.organization_id,p_new_snapshot->>'decision_type',p_new_snapshot->>'scope_type',p_new_snapshot->>'scope_ref',v_recommendation_id,p_new_snapshot->>'decision_statement',p_new_snapshot->>'selected_option',p_new_snapshot->'alternatives_considered',p_new_snapshot->>'rationale',p_new_snapshot->'evidence_snapshot',p_new_snapshot->'unknowns',p_new_snapshot->>'risk_level',(p_new_snapshot->>'risk_accepted')::boolean,v_status,v_owner_employee_id,auth.uid(),v_approval_required,v_required_role,v_effective_at,previous_decision.id,p_new_snapshot->'context'
  ) returning id into new_id;
  v_previous_snapshot := public.intelligence_decision_snapshot(previous_decision);
  v_new_snapshot := jsonb_set(v_previous_snapshot, '{status}', to_jsonb('superseded'::text), true);
  perform public._intelligence_append_decision_revision(previous_decision.organization_id, previous_decision.id, v_previous_snapshot, v_new_snapshot, p_change_reason);
  update public.intelligence_decisions set status='superseded', updated_at=now() where id=previous_decision.id;
  return new_id;
end;
$$;

revoke execute on function public.intelligence_decision_snapshot(public.intelligence_decisions) from public, authenticated;
revoke execute on function public._intelligence_append_decision_revision(uuid,uuid,jsonb,jsonb,text) from public, authenticated;
grant execute on function public.revise_intelligence_decision(uuid,jsonb,text) to authenticated;
grant execute on function public.approve_intelligence_decision(uuid) to authenticated;
grant execute on function public.return_intelligence_decision_for_review(uuid,text) to authenticated;
grant execute on function public.reject_intelligence_decision(uuid,text) to authenticated;
grant execute on function public.create_superseding_intelligence_decision(uuid,jsonb,text) to authenticated;

comment on table public.intelligence_decision_revisions is 'Append-only audit history for substantive Decision revisions and controlled lifecycle transitions. Previous and new snapshots are retained; no raw conversation or prompt data.';
comment on column public.intelligence_decision_revisions.previous_snapshot is 'Full structured Decision snapshot before the revision.';
comment on column public.intelligence_decision_revisions.new_snapshot is 'Full structured Decision snapshot after the revision.';
comment on function public.revise_intelligence_decision(uuid,jsonb,text) is 'Controlled atomic revision path. Draft/pending_review edits remain auditable; pending_approval edits return to pending_review.';
comment on function public.approve_intelligence_decision(uuid) is 'Explicit human approval. Only required diretoria may approve and provenance is auth.uid plus approved_at.';
comment on function public.create_superseding_intelligence_decision(uuid,jsonb,text) is 'Creates the successor and marks the predecessor superseded atomically; the new row points to the predecessor.';
