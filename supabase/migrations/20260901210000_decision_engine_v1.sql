-- youB — Decision Engine + Wiring Core V1
-- Additive structural contract only. Human decision recording is distinct from
-- recommendation, approval, intervention, action and outcome execution.
-- No scoring, LLM, UI, automatic evidence engine, triggers or auto-execution.

-- Composite reference support for tenant-safe Recommendation links.
do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.intelligence_recommendations'::regclass
      and conname = 'intelligence_recommendations_organization_id_id_key'
  ) then
    alter table public.intelligence_recommendations
      add constraint intelligence_recommendations_organization_id_id_key unique (organization_id, id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.intelligence_interventions'::regclass
      and conname = 'intelligence_interventions_organization_id_id_key'
  ) then
    alter table public.intelligence_interventions
      add constraint intelligence_interventions_organization_id_id_key unique (organization_id, id);
  end if;
end $$;

create table if not exists public.intelligence_decisions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  decision_type text not null check (decision_type in ('accept_recommendation','select_alternative','request_evidence','defer','reject','no_action','maintain')),
  scope_type text not null check (scope_type in ('employee','team','area','position','process','unit','organization')),
  scope_ref text not null check (btrim(scope_ref) <> ''),
  recommendation_id uuid,
  decision_statement text not null check (btrim(decision_statement) <> ''),
  selected_option text,
  alternatives_considered jsonb not null default '[]'::jsonb check (jsonb_typeof(alternatives_considered) = 'array'),
  rationale text,
  evidence_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(evidence_snapshot) = 'object'),
  unknowns jsonb not null default '[]'::jsonb check (jsonb_typeof(unknowns) = 'array'),
  risk_level text not null check (risk_level in ('informational','personal_reversible','operational','sensitive','prohibited_autonomous')),
  risk_accepted boolean not null default false,
  status text not null default 'draft' check (status in ('draft','pending_review','pending_approval','decided','effective','superseded','expired','cancelled')),
  owner_employee_id uuid,
  decision_maker_user_id uuid references auth.users(id) on delete set null,
  approval_required boolean not null default false,
  required_approver_role text check (required_approver_role is null or required_approver_role in ('admin_youb','rh','diretoria')),
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  effective_at timestamptz,
  review_at timestamptz,
  supersedes_decision_id uuid,
  context jsonb not null default '{}'::jsonb check (jsonb_typeof(context) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint intelligence_decisions_organization_id_id_key unique (organization_id, id),
  constraint intelligence_decisions_recommendation_same_org_fkey
    foreign key (organization_id, recommendation_id)
    references public.intelligence_recommendations (organization_id, id),
  constraint intelligence_decisions_owner_same_org_fkey
    foreign key (organization_id, owner_employee_id)
    references public.employees (organization_id, id),
  constraint intelligence_decisions_supersedes_same_org_fkey
    foreign key (organization_id, supersedes_decision_id)
    references public.intelligence_decisions (organization_id, id),
  constraint intelligence_decisions_approval_fields_pair_check
    check ((approved_by is null) = (approved_at is null)),
  constraint intelligence_decisions_approval_contract_check
    check (
      (approval_required = false and required_approver_role is null and approved_by is null and approved_at is null)
      or (approval_required = true and required_approver_role is not null)
    ),
  constraint intelligence_decisions_pending_approval_check
    check (status <> 'pending_approval' or approval_required = true),
  constraint intelligence_decisions_effective_approval_check
    check (status <> 'effective' or not approval_required or (approved_by is not null and approved_at is not null)),
  constraint intelligence_decisions_effective_at_check
    check (status <> 'effective' or effective_at is not null),
  constraint intelligence_decisions_superseded_target_check
    check (status <> 'superseded' or supersedes_decision_id is not null),
  constraint intelligence_decisions_not_self_supersede_check
    check (supersedes_decision_id is null or supersedes_decision_id <> id),
  constraint intelligence_decisions_decision_maker_check
    check (status in ('draft','pending_review','pending_approval') or decision_maker_user_id is not null),
  constraint intelligence_decisions_review_window_check
    check (review_at is null or effective_at is null or review_at >= effective_at)
);

insert into public.organizational_event_types(event_type, description, implemented) values
  ('decision_created','A human decision record was created.',true),
  ('decision_approved','A required approval was recorded for a decision.',true),
  ('decision_rejected','A decision proposal was rejected.',true),
  ('decision_deferred','A decision was explicitly deferred.',true),
  ('decision_superseded','A prior decision was superseded by a later decision.',true),
  ('decision_effective','A decision became effective after its required gates.',true)
on conflict (event_type) do nothing;

create table if not exists public.intelligence_decision_interventions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  decision_id uuid not null,
  intervention_id uuid not null,
  relationship_type text not null default 'derived_from_decision' check (relationship_type = 'derived_from_decision'),
  context jsonb not null default '{}'::jsonb check (jsonb_typeof(context) = 'object'),
  created_at timestamptz not null default now(),
  constraint intelligence_decision_interventions_unique unique (organization_id, decision_id, intervention_id),
  constraint intelligence_decision_interventions_decision_same_org_fkey
    foreign key (organization_id, decision_id)
    references public.intelligence_decisions (organization_id, id) on delete cascade,
  constraint intelligence_decision_interventions_intervention_same_org_fkey
    foreign key (organization_id, intervention_id)
    references public.intelligence_interventions (organization_id, id) on delete cascade
);

create index if not exists idx_intelligence_decisions_org_created
  on public.intelligence_decisions(organization_id, created_at desc);
create index if not exists idx_intelligence_decisions_org_recommendation
  on public.intelligence_decisions(organization_id, recommendation_id, created_at desc);
create index if not exists idx_intelligence_decisions_org_scope
  on public.intelligence_decisions(organization_id, scope_type, scope_ref);
create index if not exists idx_decision_interventions_org_decision
  on public.intelligence_decision_interventions(organization_id, decision_id);
create index if not exists idx_decision_interventions_org_intervention
  on public.intelligence_decision_interventions(organization_id, intervention_id);

alter table public.intelligence_decisions enable row level security;
alter table public.intelligence_decision_interventions enable row level security;

drop policy if exists intelligence_decisions_select_role on public.intelligence_decisions;
drop policy if exists intelligence_decisions_insert_admin on public.intelligence_decisions;
drop policy if exists intelligence_decisions_update_admin on public.intelligence_decisions;
drop policy if exists intelligence_decisions_delete_admin on public.intelligence_decisions;
drop policy if exists intelligence_decisions_insert_directoria on public.intelligence_decisions;
drop policy if exists intelligence_decisions_approve_directoria on public.intelligence_decisions;
create policy intelligence_decisions_select_role on public.intelligence_decisions
  for select to authenticated using (
    public.intelligence_is_admin(organization_id)
    or (
      public.has_org_role(organization_id, array['diretoria'])
      and scope_type in ('team','area','unit','process','organization')
    )
  );
create policy intelligence_decisions_insert_admin on public.intelligence_decisions
  for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy intelligence_decisions_update_admin on public.intelligence_decisions
  for update to authenticated
  using (public.intelligence_is_admin(organization_id))
  with check (public.intelligence_is_admin(organization_id));
create policy intelligence_decisions_delete_admin on public.intelligence_decisions
  for delete to authenticated using (public.intelligence_is_admin(organization_id));
-- Explicit contract: diretoria may record organizational-scope decisions as its own
-- human decision, but cannot create approval-required decisions through this path.
create policy intelligence_decisions_insert_directoria on public.intelligence_decisions
  for insert to authenticated with check (
    public.has_org_role(organization_id, array['diretoria'])
    and scope_type in ('team','area','unit','process','organization')
    and approval_required = false
    and decision_maker_user_id = auth.uid()
    and status in ('draft','pending_review','decided')
  );
-- Explicit contract: diretoria may provide approval only when the decision names
-- diretoria as the required approver and provenance is the current user.
create policy intelligence_decisions_approve_directoria on public.intelligence_decisions
  for update to authenticated
  using (
    public.has_org_role(organization_id, array['diretoria'])
    and approval_required = true
    and required_approver_role = 'diretoria'
  )
  with check (
    public.has_org_role(organization_id, array['diretoria'])
    and approval_required = true
    and required_approver_role = 'diretoria'
    and approved_by = auth.uid()
    and approved_at is not null
    and status in ('pending_approval','decided','effective')
  );

create policy intelligence_decision_interventions_select_role on public.intelligence_decision_interventions
  for select to authenticated using (
    public.intelligence_is_admin(organization_id)
    or exists (
      select 1 from public.intelligence_decisions d
      where d.organization_id = intelligence_decision_interventions.organization_id
        and d.id = intelligence_decision_interventions.decision_id
        and public.has_org_role(d.organization_id, array['diretoria'])
        and d.scope_type in ('team','area','unit','process','organization')
    )
  );
create policy intelligence_decision_interventions_insert_admin on public.intelligence_decision_interventions
  for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy intelligence_decision_interventions_delete_admin on public.intelligence_decision_interventions
  for delete to authenticated using (public.intelligence_is_admin(organization_id));

grant select, insert, update, delete on public.intelligence_decisions to authenticated;
grant select, insert, delete on public.intelligence_decision_interventions to authenticated;

comment on table public.intelligence_decisions is 'Human Decision Engine V1 record. Recommendation, Decision, Approval, Intervention, Action and Outcome remain distinct contracts; no decision automatically creates or executes downstream work.';
comment on column public.intelligence_decisions.recommendation_id is 'Optional tenant-safe link. One Recommendation may have zero or more historical Decisions.';
comment on column public.intelligence_decisions.evidence_snapshot is 'Immutable-at-recording-time snapshot of available evidence metadata; it is not recalculated historically.';
comment on column public.intelligence_decisions.scope_ref is 'Descriptive business reference only; never an authorization mechanism.';
comment on column public.intelligence_decisions.supersedes_decision_id is 'Optional tenant-safe historical predecessor; superseded decisions remain available for history.';
comment on table public.intelligence_decision_interventions is 'Explicit derived-from-decision link. It does not create an Intervention and does not authorize or execute an Action.';
