-- youB — PDI + Development V1
-- Fast-track additive implementation. public.pdis remains the plan root.
-- Do not edit historical migrations or rewrite legacy objective/actions data.

alter table public.pdis add column if not exists title text;
alter table public.pdis add column if not exists purpose text;
alter table public.pdis add column if not exists created_by_user_id uuid references auth.users(id) on delete set null;
alter table public.pdis add column if not exists proposed_by_user_id uuid references auth.users(id) on delete set null;
alter table public.pdis add column if not exists proposed_at timestamptz;
alter table public.pdis add column if not exists activated_by_user_id uuid references auth.users(id) on delete set null;
alter table public.pdis add column if not exists activated_at timestamptz;
alter table public.pdis add column if not exists paused_by_user_id uuid references auth.users(id) on delete set null;
alter table public.pdis add column if not exists paused_at timestamptz;
alter table public.pdis add column if not exists pause_reason text;
alter table public.pdis add column if not exists completed_by_user_id uuid references auth.users(id) on delete set null;
alter table public.pdis add column if not exists completed_at timestamptz;
alter table public.pdis add column if not exists cancelled_by_user_id uuid references auth.users(id) on delete set null;
alter table public.pdis add column if not exists cancelled_at timestamptz;
alter table public.pdis add column if not exists cancellation_reason text;
alter table public.pdis add column if not exists updated_at timestamptz not null default now();
alter table public.pdis add column if not exists version bigint not null default 1;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='pdis_organization_id_id_key' and conrelid='public.pdis'::regclass) then
    alter table public.pdis add constraint pdis_organization_id_id_key unique (organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname='pdis_v1_status_check' and conrelid='public.pdis'::regclass) then
    alter table public.pdis drop constraint if exists pdis_status_check;
    alter table public.pdis add constraint pdis_v1_status_check check (status in ('draft','proposed','active','paused','completed','cancelled'));
  end if;
  if not exists (select 1 from pg_constraint where conname='pdis_version_positive_check' and conrelid='public.pdis'::regclass) then
    alter table public.pdis add constraint pdis_version_positive_check check (version > 0);
  end if;
end $$;

create table if not exists public.pdi_objectives (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  pdi_id uuid not null,
  title text not null,
  description text,
  success_criteria text not null,
  responsible_employee_id uuid,
  due_date date,
  status text not null default 'draft' check (status in ('draft','active','completed','cancelled')),
  progress_note text,
  completion_note text,
  completed_by_user_id uuid references auth.users(id) on delete set null,
  completed_at timestamptz,
  created_by_user_id uuid references auth.users(id) on delete set null,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pdi_objectives_pdi_same_org_fkey foreign key (organization_id,pdi_id) references public.pdis(organization_id,id) on delete restrict,
  constraint pdi_objectives_responsible_same_org_fkey foreign key (organization_id,responsible_employee_id) references public.employees(organization_id,id) on delete restrict,
  constraint pdi_objectives_title_not_blank check (length(btrim(title)) > 0),
  constraint pdi_objectives_success_not_blank check (length(btrim(success_criteria)) > 0),
  constraint pdi_objectives_due_date_check check (due_date is null or due_date >= created_at::date)
);

create table if not exists public.pdi_actions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  objective_id uuid not null,
  title text not null,
  description text,
  responsible_employee_id uuid not null,
  due_date date,
  status text not null default 'planned' check (status in ('planned','in_progress','blocked','completed','cancelled')),
  blocker text,
  completion_note text,
  completed_by_user_id uuid references auth.users(id) on delete set null,
  completed_at timestamptz,
  created_by_user_id uuid references auth.users(id) on delete set null,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pdi_actions_objective_same_org_fkey foreign key (organization_id,objective_id) references public.pdi_objectives(organization_id,id) on delete restrict,
  constraint pdi_actions_responsible_same_org_fkey foreign key (organization_id,responsible_employee_id) references public.employees(organization_id,id) on delete restrict,
  constraint pdi_actions_title_not_blank check (length(btrim(title)) > 0),
  constraint pdi_actions_blocker_check check ((status = 'blocked' and nullif(btrim(blocker),'') is not null) or status <> 'blocked'),
  constraint pdi_actions_due_date_check check (due_date is null or due_date >= created_at::date)
);

create table if not exists public.pdi_checkins (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  pdi_id uuid not null,
  objective_id uuid,
  action_id uuid,
  author_employee_id uuid not null,
  checkin_at timestamptz not null default now(),
  progress_note text not null,
  next_step text,
  blocker text,
  evidence_reference text,
  created_at timestamptz not null default now(),
  constraint pdi_checkins_pdi_same_org_fkey foreign key (organization_id,pdi_id) references public.pdis(organization_id,id) on delete restrict,
  constraint pdi_checkins_objective_same_org_fkey foreign key (organization_id,objective_id) references public.pdi_objectives(organization_id,id) on delete restrict,
  constraint pdi_checkins_action_same_org_fkey foreign key (organization_id,action_id) references public.pdi_actions(organization_id,id) on delete restrict,
  constraint pdi_checkins_author_same_org_fkey foreign key (organization_id,author_employee_id) references public.employees(organization_id,id) on delete restrict,
  constraint pdi_checkins_progress_not_blank check (length(btrim(progress_note)) > 0),
  constraint pdi_checkins_reference_length check (evidence_reference is null or char_length(evidence_reference) <= 2000),
  constraint pdi_checkins_scope_check check (objective_id is not null or action_id is not null or pdi_id is not null)
);

create table if not exists public.pdi_source_links (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  pdi_id uuid not null,
  objective_id uuid,
  source_kind text not null check (source_kind in ('assessment_v1','feedback_360','manual')),
  source_assessment_id uuid,
  source_round_id uuid,
  source_subject_employee_id uuid,
  competency_id uuid,
  relationship_type text check (relationship_type is null or relationship_type in ('self','manager','peer','direct_report')),
  position_id_snapshot uuid,
  expected_level_snapshot smallint check (expected_level_snapshot is null or expected_level_snapshot between 1 and 5),
  safe_aggregate_score numeric check (safe_aggregate_score is null or safe_aggregate_score between 1 and 5),
  context_note text,
  linked_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint pdi_source_links_pdi_same_org_fkey foreign key (organization_id,pdi_id) references public.pdis(organization_id,id) on delete restrict,
  constraint pdi_source_links_objective_same_org_fkey foreign key (organization_id,objective_id) references public.pdi_objectives(organization_id,id) on delete restrict,
  constraint pdi_source_links_subject_same_org_fkey foreign key (organization_id,source_subject_employee_id) references public.employees(organization_id,id) on delete restrict,
  constraint pdi_source_links_competency_same_org_fkey foreign key (organization_id,competency_id) references public.competencies(organization_id,id) on delete restrict,
  constraint pdi_source_links_source_shape_check check (
    (source_kind = 'assessment_v1' and source_assessment_id is not null and source_round_id is null and relationship_type is null)
    or (source_kind = 'feedback_360' and source_round_id is not null and source_assessment_id is null and source_subject_employee_id is not null and competency_id is not null and relationship_type is not null)
    or (source_kind = 'manual' and source_assessment_id is null and source_round_id is null)
  )
);

create table if not exists public.pdi_audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  entity_type text not null check (entity_type in ('pdi','objective','action','checkin','source_link')),
  entity_id uuid not null,
  event_type text not null check (event_type in ('created','proposed','activated','paused','resumed','updated','completed','cancelled','objective_created','objective_updated','objective_completed','objective_cancelled','action_created','action_updated','action_completed','action_cancelled','checkin_created','source_link_created')),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_employee_id uuid references public.employees(id) on delete set null,
  reason text,
  before_payload jsonb,
  after_payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_pdi_objectives_org_pdi on public.pdi_objectives(organization_id,pdi_id,status);
create index if not exists idx_pdi_actions_org_objective on public.pdi_actions(organization_id,objective_id,status);
create index if not exists idx_pdi_checkins_org_pdi on public.pdi_checkins(organization_id,pdi_id,checkin_at desc);
create index if not exists idx_pdi_source_links_org_pdi on public.pdi_source_links(organization_id,pdi_id);
create index if not exists idx_pdi_audit_events_org_entity on public.pdi_audit_events(organization_id,entity_type,entity_id,created_at desc);

alter table public.pdis enable row level security;
alter table public.pdi_objectives enable row level security;
alter table public.pdi_actions enable row level security;
alter table public.pdi_checkins enable row level security;
alter table public.pdi_source_links enable row level security;
alter table public.pdi_audit_events enable row level security;

create or replace function public.pdi_actor_employee_id(p_organization_id uuid)
returns uuid language sql stable security definer set search_path=public,pg_temp as $$
  select case when count(*) = 1 then min(e.id) else null end
  from public.employees e
  where e.organization_id=p_organization_id and e.auth_user_id=auth.uid() and e.status='active'
$$;

create or replace function public.pdi_can_read_raw(p_organization_id uuid,p_employee_id uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select public.has_org_role(p_organization_id,array['admin_youb','rh'])
    or (public.has_org_role(p_organization_id,array['gestor']) and public.classic_is_direct_report(p_organization_id,p_employee_id))
    or (public.has_org_role(p_organization_id,array['colaborador']) and public.classic_has_single_own_employee(p_organization_id,p_employee_id))
$$;

create or replace function public.pdi_can_manage(p_organization_id uuid,p_employee_id uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select public.has_org_role(p_organization_id,array['admin_youb','rh'])
    or (public.has_org_role(p_organization_id,array['gestor']) and public.classic_is_direct_report(p_organization_id,p_employee_id))
    or (public.has_org_role(p_organization_id,array['colaborador']) and public.classic_has_single_own_employee(p_organization_id,p_employee_id))
$$;

create or replace function public.pdi_is_operator(p_organization_id uuid,p_employee_id uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select public.pdi_can_manage(p_organization_id,p_employee_id)
$$;

create or replace function public.pdi_set_updated_at()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin new.updated_at=now(); return new; end $$;
drop trigger if exists pdi_pdis_updated_at on public.pdis;
create trigger pdi_pdis_updated_at before update on public.pdis for each row execute function public.pdi_set_updated_at();
drop trigger if exists pdi_objectives_updated_at on public.pdi_objectives;
create trigger pdi_objectives_updated_at before update on public.pdi_objectives for each row execute function public.pdi_set_updated_at();
drop trigger if exists pdi_actions_updated_at on public.pdi_actions;
create trigger pdi_actions_updated_at before update on public.pdi_actions for each row execute function public.pdi_set_updated_at();

create or replace function public.pdi_audit_immutable()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin raise exception 'pdi audit events are immutable' using errcode='42501'; end $$;
drop trigger if exists pdi_audit_no_update on public.pdi_audit_events;
create trigger pdi_audit_no_update before update or delete on public.pdi_audit_events for each row execute function public.pdi_audit_immutable();

create or replace function public.pdi_append_audit(p_organization_id uuid,p_entity_type text,p_entity_id uuid,p_event_type text,p_reason text default null,p_before jsonb default null,p_after jsonb default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; v_employee uuid;
begin
  v_employee := public.pdi_actor_employee_id(p_organization_id);
  insert into public.pdi_audit_events(organization_id,entity_type,entity_id,event_type,actor_user_id,actor_employee_id,reason,before_payload,after_payload)
  values(p_organization_id,p_entity_type,p_entity_id,p_event_type,auth.uid(),v_employee,nullif(btrim(p_reason),''),p_before,p_after)
  returning id into v_id;
  return v_id;
end $$;

-- Replace only incompatible legacy pdis policies; historical migrations remain untouched.
drop policy if exists pdis_member_select on public.pdis;
drop policy if exists pdis_member_insert on public.pdis;
drop policy if exists pdis_member_update on public.pdis;
drop policy if exists pdis_member_delete on public.pdis;
drop policy if exists pdis_select_by_role on public.pdis;
drop policy if exists pdis_insert_management on public.pdis;
drop policy if exists classic_pdis_select_population on public.pdis;
drop policy if exists classic_pdis_insert_population on public.pdis;
drop policy if exists classic_pdis_update_population on public.pdis;
drop policy if exists classic_pdis_delete_population on public.pdis;
create policy pdi_root_select_population on public.pdis for select to authenticated using (public.pdi_can_read_raw(organization_id,employee_id));

create policy pdi_objectives_select_population on public.pdi_objectives for select to authenticated using (exists(select 1 from public.pdis p where p.organization_id=pdi_objectives.organization_id and p.id=pdi_objectives.pdi_id and public.pdi_can_read_raw(p.organization_id,p.employee_id)));
create policy pdi_actions_select_population on public.pdi_actions for select to authenticated using (exists(select 1 from public.pdi_objectives o join public.pdis p on p.organization_id=o.organization_id and p.id=o.pdi_id where o.organization_id=pdi_actions.organization_id and o.id=pdi_actions.objective_id and public.pdi_can_read_raw(p.organization_id,p.employee_id)));
create policy pdi_checkins_select_population on public.pdi_checkins for select to authenticated using (public.pdi_can_read_raw(organization_id,(select p.employee_id from public.pdis p where p.organization_id=pdi_checkins.organization_id and p.id=pdi_checkins.pdi_id)));
create policy pdi_source_links_select_population on public.pdi_source_links for select to authenticated using (exists(select 1 from public.pdis p where p.organization_id=pdi_source_links.organization_id and p.id=pdi_source_links.pdi_id and public.pdi_can_read_raw(p.organization_id,p.employee_id)));
create policy pdi_audit_events_select_population on public.pdi_audit_events for select to authenticated using (
  exists(select 1 from public.pdis p where p.organization_id=pdi_audit_events.organization_id and p.id=pdi_audit_events.entity_id and pdi_audit_events.entity_type='pdi' and public.pdi_can_read_raw(p.organization_id,p.employee_id))
  or public.has_org_role(organization_id,array['admin_youb','rh'])
);

revoke insert,update,delete on public.pdis,public.pdi_objectives,public.pdi_actions,public.pdi_checkins,public.pdi_source_links,public.pdi_audit_events from authenticated;
revoke all on public.pdi_audit_events from authenticated;
revoke all on function public.pdi_actor_employee_id(uuid),public.pdi_can_read_raw(uuid,uuid),public.pdi_can_manage(uuid,uuid),public.pdi_is_operator(uuid,uuid),public.pdi_set_updated_at(),public.pdi_audit_immutable(),public.pdi_append_audit(uuid,text,uuid,text,text,jsonb,jsonb) from public;
grant select on public.pdis,public.pdi_objectives,public.pdi_actions,public.pdi_checkins,public.pdi_source_links to authenticated;

create or replace function public.pdi_create(p_organization_id uuid,p_employee_id uuid,p_objective text,p_due_date date default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; v_user uuid;
begin
  if auth.uid() is null or p_organization_id is null or p_employee_id is null or nullif(btrim(p_objective),'') is null then raise exception 'pdi creation requires tenant, subject and objective' using errcode='22023'; end if;
  if not public.pdi_can_manage(p_organization_id,p_employee_id) then raise exception 'pdi subject is outside the authorized population' using errcode='42501'; end if;
  if not exists(select 1 from public.employees where organization_id=p_organization_id and id=p_employee_id and status='active') then raise exception 'pdi subject is outside the tenant' using errcode='42501'; end if;
  v_user := auth.uid();
  insert into public.pdis(organization_id,employee_id,objective,title,purpose,due_date,status,created_by_user_id,version)
  values(p_organization_id,p_employee_id,btrim(p_objective),btrim(p_objective),btrim(p_objective),p_due_date,'draft',v_user,1) returning id into v_id;
  perform public.pdi_append_audit(p_organization_id,'pdi',v_id,'created',null,null,jsonb_build_object('status','draft','employee_id',p_employee_id,'objective',btrim(p_objective)));
  return v_id;
end $$;

create or replace function public.pdi_propose(p_pdi_id uuid,p_expected_version bigint)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_p public.pdis%rowtype;
begin
  select * into v_p from public.pdis where id=p_pdi_id for update;
  if v_p.id is null or not public.pdi_can_manage(v_p.organization_id,v_p.employee_id) then raise exception 'pdi is outside the authorized population' using errcode='42501'; end if;
  if v_p.status <> 'draft' or v_p.version <> p_expected_version then raise exception 'pdi proposal transition is stale or invalid' using errcode='23514'; end if;
  update public.pdis set status='proposed',proposed_by_user_id=auth.uid(),proposed_at=now(),version=version+1 where id=p_pdi_id and version=p_expected_version;
  perform public.pdi_append_audit(v_p.organization_id,'pdi',p_pdi_id,'proposed'); return true;
end $$;

create or replace function public.pdi_activate(p_pdi_id uuid,p_expected_version bigint)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_p public.pdis%rowtype;
begin
  select * into v_p from public.pdis where id=p_pdi_id for update;
  if v_p.id is null or not public.has_org_role(v_p.organization_id,array['admin_youb','rh']) and not (public.has_org_role(v_p.organization_id,array['gestor']) and public.classic_is_direct_report(v_p.organization_id,v_p.employee_id)) then raise exception 'pdi activation is outside the authorized population' using errcode='42501'; end if;
  if v_p.status <> 'proposed' or v_p.version <> p_expected_version then raise exception 'pdi activation is stale or invalid' using errcode='23514'; end if;
  update public.pdis set status='active',activated_by_user_id=auth.uid(),activated_at=now(),version=version+1 where id=p_pdi_id and version=p_expected_version;
  perform public.pdi_append_audit(v_p.organization_id,'pdi',p_pdi_id,'activated'); return true;
end $$;

create or replace function public.pdi_transition(p_pdi_id uuid,p_next_status text,p_expected_version bigint,p_reason text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_p public.pdis%rowtype; v_event text;
begin
  select * into v_p from public.pdis where id=p_pdi_id for update;
  if v_p.id is null or not public.pdi_can_manage(v_p.organization_id,v_p.employee_id) then raise exception 'pdi is outside the authorized population' using errcode='42501'; end if;
  if v_p.version <> p_expected_version then raise exception 'pdi version is stale' using errcode='40001'; end if;
  if (v_p.status='active' and p_next_status='paused') then v_event='paused';
  elsif (v_p.status='paused' and p_next_status='active') then v_event='resumed';
  elsif (v_p.status='active' and p_next_status='completed') then v_event='completed';
  elsif (v_p.status='active' and p_next_status='cancelled') then v_event='cancelled';
  else raise exception 'invalid pdi lifecycle transition' using errcode='23514'; end if;
  if p_next_status='completed' and not exists(select 1 from public.pdi_objectives o where o.organization_id=v_p.organization_id and o.pdi_id=v_p.id and o.status not in ('completed','cancelled')) then null; elsif p_next_status='completed' then raise exception 'all pdi objectives must be resolved before completion' using errcode='23514'; end if;
  update public.pdis set status=p_next_status,
    paused_by_user_id=case when p_next_status='paused' then auth.uid() else paused_by_user_id end,
    paused_at=case when p_next_status='paused' then now() else paused_at end,
    pause_reason=case when p_next_status='paused' then nullif(btrim(p_reason),'') else pause_reason end,
    completed_by_user_id=case when p_next_status='completed' then auth.uid() else completed_by_user_id end,
    completed_at=case when p_next_status='completed' then now() else completed_at end,
    cancelled_by_user_id=case when p_next_status='cancelled' then auth.uid() else cancelled_by_user_id end,
    cancelled_at=case when p_next_status='cancelled' then now() else cancelled_at end,
    cancellation_reason=case when p_next_status='cancelled' then nullif(btrim(p_reason),'') else cancellation_reason end,
    version=version+1 where id=p_pdi_id and version=p_expected_version;
  perform public.pdi_append_audit(v_p.organization_id,'pdi',p_pdi_id,v_event,p_reason); return true;
end $$;

create or replace function public.pdi_add_objective(p_pdi_id uuid,p_title text,p_description text,p_success_criteria text,p_responsible_employee_id uuid,p_due_date date default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_p public.pdis%rowtype; v_id uuid;
begin
  select * into v_p from public.pdis where id=p_pdi_id;
  if v_p.id is null or not public.pdi_can_manage(v_p.organization_id,v_p.employee_id) or v_p.status in ('completed','cancelled') then raise exception 'objective is outside the authorized pdi' using errcode='42501'; end if;
  if nullif(btrim(p_title),'') is null or nullif(btrim(p_success_criteria),'') is null then raise exception 'objective title and success criteria are required' using errcode='22023'; end if;
  if p_responsible_employee_id is not null and not exists(select 1 from public.employees where organization_id=v_p.organization_id and id=p_responsible_employee_id and status='active') then raise exception 'objective responsible is outside the tenant' using errcode='42501'; end if;
  insert into public.pdi_objectives(organization_id,pdi_id,title,description,success_criteria,responsible_employee_id,due_date,status,created_by_user_id) values(v_p.organization_id,p_pdi_id,btrim(p_title),nullif(btrim(p_description),''),btrim(p_success_criteria),p_responsible_employee_id,p_due_date,case when v_p.status='active' then 'active' else 'draft' end,auth.uid()) returning id into v_id;
  update public.pdis set version=version+1 where id=p_pdi_id;
  perform public.pdi_append_audit(v_p.organization_id,'objective',v_id,'objective_created',null,null,jsonb_build_object('pdi_id',p_pdi_id,'title',btrim(p_title))); return v_id;
end $$;

create or replace function public.pdi_set_objective_status(p_objective_id uuid,p_next_status text,p_expected_version bigint,p_completion_note text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_o public.pdi_objectives%rowtype; v_pdi_employee uuid; v_pdi_status text; v_event text;
begin
  select o.* into v_o from public.pdi_objectives o where o.id=p_objective_id for update;
  select p.employee_id,p.status into v_pdi_employee,v_pdi_status from public.pdis p where p.organization_id=v_o.organization_id and p.id=v_o.pdi_id;
  if v_o.id is null or not public.pdi_can_manage(v_o.organization_id,v_pdi_employee) then raise exception 'objective is outside the authorized population' using errcode='42501'; end if;
  if v_o.version <> p_expected_version or v_pdi_status in ('completed','cancelled') then raise exception 'objective version or pdi lifecycle is invalid' using errcode='23514'; end if;
  if not ((v_o.status='draft' and p_next_status='active') or (v_o.status='active' and p_next_status in ('completed','cancelled'))) then raise exception 'invalid objective lifecycle transition' using errcode='23514'; end if;
  if p_next_status='completed' and nullif(btrim(p_completion_note),'') is null then raise exception 'objective completion requires a human note' using errcode='22023'; end if;
  v_event := case when p_next_status='completed' then 'objective_completed' when p_next_status='cancelled' then 'objective_cancelled' else 'objective_updated' end;
  update public.pdi_objectives set status=p_next_status,completion_note=case when p_next_status='completed' then btrim(p_completion_note) else completion_note end,completed_by_user_id=case when p_next_status='completed' then auth.uid() else completed_by_user_id end,completed_at=case when p_next_status='completed' then now() else completed_at end,version=version+1 where id=p_objective_id and version=p_expected_version;
  update public.pdis set version=version+1 where id=v_o.pdi_id;
  perform public.pdi_append_audit(v_o.organization_id,'objective',p_objective_id,v_event,p_completion_note); return true;
end $$;

create or replace function public.pdi_add_action(p_objective_id uuid,p_title text,p_description text,p_responsible_employee_id uuid,p_due_date date default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_o public.pdi_objectives%rowtype; v_p public.pdis%rowtype; v_id uuid;
begin
  select o.* into v_o from public.pdi_objectives o where o.id=p_objective_id;
  select p.* into v_p from public.pdis p where p.organization_id=v_o.organization_id and p.id=v_o.pdi_id;
  if v_o.id is null or v_p.id is null or not public.pdi_can_manage(v_p.organization_id,v_p.employee_id) or v_p.status in ('completed','cancelled') or v_o.status in ('completed','cancelled') then raise exception 'action is outside the authorized pdi' using errcode='42501'; end if;
  if nullif(btrim(p_title),'') is null or not exists(select 1 from public.employees where organization_id=v_p.organization_id and id=p_responsible_employee_id and status='active') then raise exception 'action title and tenant responsible are required' using errcode='22023'; end if;
  insert into public.pdi_actions(organization_id,objective_id,title,description,responsible_employee_id,due_date,created_by_user_id) values(v_p.organization_id,p_objective_id,btrim(p_title),nullif(btrim(p_description),''),p_responsible_employee_id,p_due_date,auth.uid()) returning id into v_id;
  update public.pdi_objectives set version=version+1 where id=p_objective_id;
  update public.pdis set version=version+1 where id=v_p.id;
  perform public.pdi_append_audit(v_p.organization_id,'action',v_id,'action_created',null,null,jsonb_build_object('objective_id',p_objective_id,'title',btrim(p_title))); return v_id;
end $$;

create or replace function public.pdi_set_action_status(p_action_id uuid,p_next_status text,p_expected_version bigint,p_blocker text default null,p_completion_note text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_a public.pdi_actions%rowtype; v_o public.pdi_objectives%rowtype; v_p public.pdis%rowtype; v_event text;
begin
  select a.* into v_a from public.pdi_actions a where a.id=p_action_id for update;
  select o.* into v_o from public.pdi_objectives o where o.organization_id=v_a.organization_id and o.id=v_a.objective_id;
  select p.* into v_p from public.pdis p where p.organization_id=v_o.organization_id and p.id=v_o.pdi_id;
  if v_a.id is null or v_p.id is null or not public.pdi_can_manage(v_p.organization_id,v_p.employee_id) or v_p.status in ('completed','cancelled') then raise exception 'action is outside the authorized population' using errcode='42501'; end if;
  if v_a.version <> p_expected_version or v_o.status in ('completed','cancelled') then raise exception 'action version or objective lifecycle is invalid' using errcode='23514'; end if;
  if not ((v_a.status='planned' and p_next_status='in_progress') or (v_a.status='in_progress' and p_next_status in ('blocked','completed','cancelled')) or (v_a.status='blocked' and p_next_status='in_progress')) then raise exception 'invalid action lifecycle transition' using errcode='23514'; end if;
  if p_next_status='blocked' and nullif(btrim(p_blocker),'') is null then raise exception 'blocked action requires a blocker' using errcode='22023'; end if;
  if p_next_status='completed' and nullif(btrim(p_completion_note),'') is null then raise exception 'action completion requires a human note' using errcode='22023'; end if;
  v_event := case when p_next_status='completed' then 'action_completed' when p_next_status='cancelled' then 'action_cancelled' else 'action_updated' end;
  update public.pdi_actions set status=p_next_status,blocker=case when p_next_status='blocked' then btrim(p_blocker) else blocker end,completion_note=case when p_next_status='completed' then btrim(p_completion_note) else completion_note end,completed_by_user_id=case when p_next_status='completed' then auth.uid() else completed_by_user_id end,completed_at=case when p_next_status='completed' then now() else completed_at end,version=version+1 where id=p_action_id and version=p_expected_version;
  update public.pdi_objectives set version=version+1 where id=v_o.id;
  update public.pdis set version=version+1 where id=v_p.id;
  perform public.pdi_append_audit(v_p.organization_id,'action',p_action_id,v_event,p_blocker,null,jsonb_build_object('status',p_next_status)); return true;
end $$;

create or replace function public.pdi_add_checkin(p_pdi_id uuid,p_progress_note text,p_next_step text default null,p_blocker text default null,p_evidence_reference text default null,p_objective_id uuid default null,p_action_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_p public.pdis%rowtype; v_id uuid;
begin
  select * into v_p from public.pdis where id=p_pdi_id;
  if v_p.id is null or not public.pdi_can_manage(v_p.organization_id,v_p.employee_id) or v_p.status in ('completed','cancelled') then raise exception 'check-in is outside the authorized population' using errcode='42501'; end if;
  if nullif(btrim(p_progress_note),'') is null then raise exception 'check-in progress is required' using errcode='22023'; end if;
  if p_objective_id is not null and not exists(select 1 from public.pdi_objectives where organization_id=v_p.organization_id and id=p_objective_id and pdi_id=p_pdi_id) then raise exception 'check-in objective is outside the pdi' using errcode='42501'; end if;
  if p_action_id is not null and not exists(select 1 from public.pdi_actions a join public.pdi_objectives o on o.organization_id=a.organization_id and o.id=a.objective_id where a.organization_id=v_p.organization_id and a.id=p_action_id and o.pdi_id=p_pdi_id) then raise exception 'check-in action is outside the pdi' using errcode='42501'; end if;
  insert into public.pdi_checkins(organization_id,pdi_id,objective_id,action_id,author_employee_id,progress_note,next_step,blocker,evidence_reference) values(v_p.organization_id,p_pdi_id,p_objective_id,p_action_id,public.pdi_actor_employee_id(v_p.organization_id),btrim(p_progress_note),nullif(btrim(p_next_step),''),nullif(btrim(p_blocker),''),nullif(btrim(p_evidence_reference),'')) returning id into v_id;
  perform public.pdi_append_audit(v_p.organization_id,'checkin',v_id,'checkin_created'); return v_id;
end $$;

create or replace function public.pdi_add_source_link(p_pdi_id uuid,p_source_kind text,p_source_assessment_id uuid default null,p_source_round_id uuid default null,p_competency_id uuid default null,p_relationship_type text default null,p_context_note text default null,p_safe_aggregate_score numeric default null,p_objective_id uuid default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_p public.pdis%rowtype; v_id uuid; v_subject uuid; v_position uuid; v_expected smallint; v_count bigint; v_avg numeric; v_assessment_score numeric;
begin
  select * into v_p from public.pdis where id=p_pdi_id;
  if v_p.id is null or not public.pdi_can_manage(v_p.organization_id,v_p.employee_id) or v_p.status in ('completed','cancelled') then raise exception 'source link is outside the authorized population' using errcode='42501'; end if;
  if p_source_kind='assessment_v1' then
    if p_source_assessment_id is null or p_source_round_id is not null or p_relationship_type is not null then raise exception 'invalid assessment source link shape' using errcode='23514'; end if;
    select a.subject_employee_id,a.position_id,s.expected_level_snapshot,s.score::numeric into v_subject,v_position,v_expected,v_assessment_score from public.assessments a join public.assessment_competency_scores s on s.organization_id=a.organization_id and s.assessment_id=a.id where a.organization_id=v_p.organization_id and a.id=p_source_assessment_id and a.subject_employee_id=v_p.employee_id and a.status='completed' limit 1;
    if v_subject is null then raise exception 'assessment source is invalid or outside the pdi population' using errcode='42501'; end if;
    p_safe_aggregate_score := coalesce(p_safe_aggregate_score,v_assessment_score);
  elsif p_source_kind='feedback_360' then
    if p_source_round_id is null or p_source_assessment_id is not null or p_competency_id is null or p_relationship_type not in ('self','manager','peer','direct_report') then raise exception 'invalid feedback source link shape' using errcode='23514'; end if;
    select sc.subject_employee_id,sc.position_id_snapshot,sc.expected_level_snapshot,count(distinct p.id),round(avg(s.score)::numeric,2) into v_subject,v_position,v_expected,v_count,v_avg
    from public.feedback_360_rounds r join public.feedback_360_participants p on p.organization_id=r.organization_id and p.round_id=r.id and p.status='submitted' and p.relationship_type=p_relationship_type join public.feedback_360_subject_competencies sc on sc.organization_id=p.organization_id and sc.round_id=p.round_id and sc.subject_employee_id=p.subject_employee_id and sc.competency_id=p_competency_id join public.feedback_360_scores s on s.organization_id=p.organization_id and s.participant_id=p.id and s.subject_competency_id=sc.id and s.score is not null
    where r.organization_id=v_p.organization_id and r.id=p_source_round_id and r.status='closed' and sc.subject_employee_id=v_p.employee_id group by sc.subject_employee_id,sc.position_id_snapshot,sc.expected_level_snapshot;
    if v_subject is null or (p_relationship_type in ('peer','direct_report') and v_count < 3) then raise exception 'feedback source is not a safe aggregate for this population' using errcode='42501'; end if;
    if p_safe_aggregate_score is not null and round(p_safe_aggregate_score,2) <> v_avg then raise exception 'feedback aggregate does not match the safe source result' using errcode='23514'; end if;
    p_safe_aggregate_score := v_avg;
  elsif p_source_kind='manual' then
    if p_source_assessment_id is not null or p_source_round_id is not null or p_relationship_type is not null then raise exception 'invalid manual source link shape' using errcode='23514'; end if;
  else raise exception 'invalid pdi source kind' using errcode='23514'; end if;
  if p_objective_id is not null and not exists(select 1 from public.pdi_objectives where organization_id=v_p.organization_id and id=p_objective_id and pdi_id=p_pdi_id) then raise exception 'source objective is outside the pdi' using errcode='42501'; end if;
  insert into public.pdi_source_links(organization_id,pdi_id,objective_id,source_kind,source_assessment_id,source_round_id,source_subject_employee_id,competency_id,relationship_type,position_id_snapshot,expected_level_snapshot,safe_aggregate_score,context_note,linked_by_user_id) values(v_p.organization_id,p_pdi_id,p_objective_id,p_source_kind,p_source_assessment_id,p_source_round_id,case when p_source_kind='manual' then null else v_subject end,p_competency_id,p_relationship_type,v_position,v_expected,p_safe_aggregate_score,nullif(btrim(p_context_note),''),auth.uid()) returning id into v_id;
  perform public.pdi_append_audit(v_p.organization_id,'source_link',v_id,'source_link_created'); return v_id;
end $$;

create or replace function public.pdi_read_organization_aggregate(p_organization_id uuid)
returns table(metric text,value bigint) language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_subjects bigint; v_plans bigint;
begin
  if auth.uid() is null or not public.has_org_role(p_organization_id,array['admin_youb','rh','diretoria']) then raise exception 'pdi aggregate is not authorized' using errcode='42501'; end if;
  select count(distinct employee_id),count(*) into v_subjects,v_plans from public.pdis where organization_id=p_organization_id;
  if v_subjects < 5 or v_plans < 5 then return; end if;
  return query select 'active_plans'::text,count(*)::bigint from public.pdis where organization_id=p_organization_id and status='active';
  return query select 'objectives_by_status'::text,count(*)::bigint from public.pdi_objectives where organization_id=p_organization_id;
  return query select 'actions_by_status'::text,count(*)::bigint from public.pdi_actions where organization_id=p_organization_id;
  return query select 'blocked_actions'::text,count(*)::bigint from public.pdi_actions where organization_id=p_organization_id and status='blocked';
  return query select 'checkin_cadence'::text,count(*)::bigint from public.pdi_checkins where organization_id=p_organization_id;
  return query select 'completed_objectives'::text,count(*)::bigint from public.pdi_objectives where organization_id=p_organization_id and status='completed';
end $$;

revoke all on function public.pdi_create(uuid,uuid,text,date),public.pdi_propose(uuid,bigint),public.pdi_activate(uuid,bigint),public.pdi_transition(uuid,text,bigint,text),public.pdi_add_objective(uuid,text,text,text,uuid,date),public.pdi_set_objective_status(uuid,text,bigint,text),public.pdi_add_action(uuid,text,text,uuid,date),public.pdi_set_action_status(uuid,text,bigint,text,text),public.pdi_add_checkin(uuid,text,text,text,text,uuid,uuid),public.pdi_add_source_link(uuid,text,uuid,uuid,uuid,text,text,numeric,uuid),public.pdi_read_organization_aggregate(uuid) from public;
grant execute on function public.pdi_create(uuid,uuid,text,date),public.pdi_propose(uuid,bigint),public.pdi_activate(uuid,bigint),public.pdi_transition(uuid,text,bigint,text),public.pdi_add_objective(uuid,text,text,text,uuid,date),public.pdi_set_objective_status(uuid,text,bigint,text),public.pdi_add_action(uuid,text,text,uuid,date),public.pdi_set_action_status(uuid,text,bigint,text,text),public.pdi_add_checkin(uuid,text,text,text,text,uuid,uuid),public.pdi_add_source_link(uuid,text,uuid,uuid,uuid,text,text,numeric,uuid),public.pdi_read_organization_aggregate(uuid) to authenticated;

comment on table public.pdis is 'PDI V1 root. Legacy objective/actions JSONB are preserved for compatibility; new actions are normalized in pdi_actions.';
comment on table public.pdi_source_links is 'Safe contextual links only. Feedback 360 links never persist participant, evaluator, raw score row or confidential comments.';
comment on table public.pdi_audit_events is 'Immutable PDI audit trail, including lifecycle and relevant objective/action changes.';
