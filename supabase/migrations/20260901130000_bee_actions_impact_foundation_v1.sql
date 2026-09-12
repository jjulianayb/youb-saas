-- youB — Bee Action Authorization + Impact Model V1
-- Additive structural foundation only. No RPC, trigger, webhook or executor.

create table if not exists public.bee_action_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  requester_user_id uuid not null references auth.users(id) on delete restrict,
  requester_employee_id uuid,
  source_recommendation_id uuid,
  source_intervention_id uuid,
  source_action_id uuid,
  action_key text not null,
  capability_level text not null check (capability_level in ('observe','explain','ask','recommend','prepare','execute')),
  risk_level text not null check (risk_level in ('informational','personal_reversible','operational','sensitive','prohibited_autonomous')),
  authorization_requirement text not null check (authorization_requirement in ('none','confirmation','approval','prohibited')),
  purpose text not null,
  target_scope_type text not null check (target_scope_type in ('employee','team','area','position','process','unit','organization')),
  target_scope_ref text,
  target_employee_id uuid,
  sensitivity text not null default 'standard' check (sensitivity in ('standard','restricted','highly_sensitive')),
  authorization_status text not null default 'not_required' check (authorization_status in ('not_required','awaiting_confirmation','awaiting_approval','approved','rejected','expired')),
  execution_status text not null default 'not_started' check (execution_status in ('not_started','ready','executing','completed','failed','cancelled')),
  confirmed_by uuid references auth.users(id) on delete set null,
  confirmed_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  request_payload jsonb not null default '{}'::jsonb,
  execution_payload jsonb not null default '{}'::jsonb,
  execution_result jsonb not null default '{}'::jsonb,
  failure_reason text,
  correlation_id uuid not null default gen_random_uuid(),
  executed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bee_action_requests_requester_employee_same_org_fkey foreign key (organization_id, requester_employee_id) references public.employees(organization_id, id),
  constraint bee_action_requests_target_employee_same_org_fkey foreign key (organization_id, target_employee_id) references public.employees(organization_id, id),
  constraint bee_action_requests_recommendation_same_org_fkey foreign key (organization_id, source_recommendation_id) references public.intelligence_recommendations(organization_id, id),
  constraint bee_action_requests_intervention_same_org_fkey foreign key (organization_id, source_intervention_id) references public.intelligence_interventions(organization_id, id),
  constraint bee_action_requests_action_same_org_fkey foreign key (organization_id, source_action_id) references public.intelligence_actions(organization_id, id),
  constraint bee_action_requests_prohibited_autonomous_guard check (
    risk_level <> 'prohibited_autonomous'
    or (authorization_requirement = 'prohibited' and capability_level <> 'execute' and execution_status not in ('ready','executing','completed'))
  ),
  constraint bee_action_requests_execute_authorization_guard check (
    capability_level <> 'execute' or authorization_requirement not in ('none','prohibited')
  ),
  constraint bee_action_requests_approval_guard check (
    authorization_requirement <> 'approval'
    or execution_status not in ('ready','executing','completed')
    or (approved_by is not null and approved_at is not null)
  ),
  constraint bee_action_requests_confirmation_guard check (
    authorization_requirement <> 'confirmation'
    or execution_status not in ('ready','executing','completed')
    or (confirmed_by is not null and confirmed_at is not null)
  ),
  constraint bee_action_requests_request_payload_object check (jsonb_typeof(request_payload) = 'object'),
  constraint bee_action_requests_execution_payload_object check (jsonb_typeof(execution_payload) = 'object'),
  constraint bee_action_requests_execution_result_object check (jsonb_typeof(execution_result) = 'object')
);
create index if not exists idx_bee_action_requests_org_created on public.bee_action_requests(organization_id, created_at desc);
create index if not exists idx_bee_action_requests_requester on public.bee_action_requests(requester_user_id, created_at desc);
alter table public.bee_action_requests enable row level security;
drop policy if exists bee_action_requests_select_role on public.bee_action_requests;
drop policy if exists bee_action_requests_insert_admin on public.bee_action_requests;
drop policy if exists bee_action_requests_update_admin on public.bee_action_requests;
drop policy if exists bee_action_requests_delete_admin on public.bee_action_requests;
create policy bee_action_requests_select_role on public.bee_action_requests for select to authenticated using ((requester_user_id = auth.uid() and public.is_org_member(organization_id)) or public.intelligence_is_admin(organization_id));
create policy bee_action_requests_insert_admin on public.bee_action_requests for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy bee_action_requests_update_admin on public.bee_action_requests for update to authenticated using (public.intelligence_is_admin(organization_id)) with check (public.intelligence_is_admin(organization_id));
create policy bee_action_requests_delete_admin on public.bee_action_requests for delete to authenticated using (public.intelligence_is_admin(organization_id));
grant select, insert, update, delete on public.bee_action_requests to authenticated;
comment on table public.bee_action_requests is 'Bee-mediated action request, authorization and audit metadata; it does not replace intelligence_actions and stores no raw conversation.';
comment on column public.bee_action_requests.target_scope_ref is 'Descriptive business reference only; never an authorization mechanism.';

-- Impact is additive on the existing Outcome contract.
alter table public.intelligence_outcomes add column if not exists outcome_level text;
alter table public.intelligence_outcomes add column if not exists claim_strength text;
alter table public.intelligence_outcomes add column if not exists measurement_kind text;
alter table public.intelligence_outcomes add column if not exists validation_status text;
alter table public.intelligence_outcomes add column if not exists metric_key text;
alter table public.intelligence_outcomes add column if not exists metric_label text;
alter table public.intelligence_outcomes add column if not exists metric_unit text;
alter table public.intelligence_outcomes add column if not exists baseline_value numeric;
alter table public.intelligence_outcomes add column if not exists observed_value numeric;
alter table public.intelligence_outcomes add column if not exists delta_value numeric;
alter table public.intelligence_outcomes add column if not exists baseline_at timestamptz;
alter table public.intelligence_outcomes add column if not exists window_start timestamptz;
alter table public.intelligence_outcomes add column if not exists window_end timestamptz;
alter table public.intelligence_outcomes add column if not exists data_source_type text;
alter table public.intelligence_outcomes add column if not exists data_source_id text;
alter table public.intelligence_outcomes add column if not exists measurement_methodology text;
alter table public.intelligence_outcomes add column if not exists attribution_note text;
alter table public.intelligence_outcomes add column if not exists financial_value numeric;
alter table public.intelligence_outcomes add column if not exists currency text;
alter table public.intelligence_outcomes add column if not exists validated_by uuid references auth.users(id) on delete set null;
alter table public.intelligence_outcomes add column if not exists validated_at timestamptz;
alter table public.intelligence_outcomes add column if not exists context jsonb not null default '{}'::jsonb;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'intelligence_outcomes_organization_id_id_key') then alter table public.intelligence_outcomes add constraint intelligence_outcomes_organization_id_id_key unique (organization_id, id); end if;
end $$;

alter table public.intelligence_outcomes drop constraint if exists intelligence_outcomes_outcome_level_check;
alter table public.intelligence_outcomes add constraint intelligence_outcomes_outcome_level_check check (outcome_level is null or outcome_level in ('execution','learning','application','capability','people','business','financial'));
alter table public.intelligence_outcomes drop constraint if exists intelligence_outcomes_claim_strength_check;
alter table public.intelligence_outcomes add constraint intelligence_outcomes_claim_strength_check check (claim_strength is null or claim_strength in ('observed','associated','contribution_supported','causal_validated'));
alter table public.intelligence_outcomes drop constraint if exists intelligence_outcomes_measurement_kind_check;
alter table public.intelligence_outcomes add constraint intelligence_outcomes_measurement_kind_check check (measurement_kind is null or measurement_kind in ('measured','estimated'));
alter table public.intelligence_outcomes drop constraint if exists intelligence_outcomes_validation_status_check;
alter table public.intelligence_outcomes add constraint intelligence_outcomes_validation_status_check check (validation_status is null or validation_status in ('unvalidated','reviewed','validated'));
alter table public.intelligence_outcomes drop constraint if exists intelligence_outcomes_window_order_check;
alter table public.intelligence_outcomes add constraint intelligence_outcomes_window_order_check check (window_start is null or window_end is null or window_end >= window_start);
alter table public.intelligence_outcomes drop constraint if exists intelligence_outcomes_baseline_order_check;
alter table public.intelligence_outcomes add constraint intelligence_outcomes_baseline_order_check check (baseline_at is null or baseline_at <= measured_at);
alter table public.intelligence_outcomes drop constraint if exists intelligence_outcomes_financial_value_check;
alter table public.intelligence_outcomes add constraint intelligence_outcomes_financial_value_check check (financial_value is null or (financial_value >= 0 and currency is not null and btrim(currency) <> ''));
alter table public.intelligence_outcomes drop constraint if exists intelligence_outcomes_financial_methodology_check;
alter table public.intelligence_outcomes add constraint intelligence_outcomes_financial_methodology_check check (outcome_level is distinct from 'financial' or financial_value is null or nullif(btrim(measurement_methodology),'') is not null);
alter table public.intelligence_outcomes drop constraint if exists intelligence_outcomes_causal_validation_check;
alter table public.intelligence_outcomes add constraint intelligence_outcomes_causal_validation_check check (claim_strength is distinct from 'causal_validated' or (validation_status = 'validated' and validated_by is not null and validated_at is not null and nullif(btrim(measurement_methodology),'') is not null));
alter table public.intelligence_outcomes drop constraint if exists intelligence_outcomes_context_object_check;
alter table public.intelligence_outcomes add constraint intelligence_outcomes_context_object_check check (jsonb_typeof(context) = 'object');

-- Impact reads remain decision-maker scoped; direct writes are admin/RH only.
drop policy if exists intelligence_outcomes_insert_role on public.intelligence_outcomes;
drop policy if exists intelligence_outcomes_update_role on public.intelligence_outcomes;
create policy intelligence_outcomes_insert_role on public.intelligence_outcomes for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy intelligence_outcomes_update_role on public.intelligence_outcomes for update to authenticated using (public.intelligence_is_admin(organization_id)) with check (public.intelligence_is_admin(organization_id));

create table if not exists public.intelligence_outcome_evidence (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  outcome_id uuid not null,
  evidence_id uuid not null,
  relation text not null check (relation in ('supports','contradicts','neutral')),
  created_at timestamptz not null default now(),
  primary key (organization_id, outcome_id, evidence_id),
  constraint outcome_evidence_outcome_same_org_fkey foreign key (organization_id, outcome_id) references public.intelligence_outcomes(organization_id, id) on delete cascade,
  constraint outcome_evidence_evidence_same_org_fkey foreign key (organization_id, evidence_id) references public.intelligence_evidence(organization_id, id) on delete cascade
);
create index if not exists idx_outcome_evidence_evidence on public.intelligence_outcome_evidence(organization_id, evidence_id);
alter table public.intelligence_outcome_evidence enable row level security;
drop policy if exists outcome_evidence_select on public.intelligence_outcome_evidence;
drop policy if exists outcome_evidence_insert on public.intelligence_outcome_evidence;
drop policy if exists outcome_evidence_update on public.intelligence_outcome_evidence;
drop policy if exists outcome_evidence_delete on public.intelligence_outcome_evidence;
create policy outcome_evidence_select on public.intelligence_outcome_evidence for select to authenticated using (public.intelligence_is_decision_maker(organization_id));
create policy outcome_evidence_insert on public.intelligence_outcome_evidence for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy outcome_evidence_update on public.intelligence_outcome_evidence for update to authenticated using (public.intelligence_is_admin(organization_id)) with check (public.intelligence_is_admin(organization_id));
create policy outcome_evidence_delete on public.intelligence_outcome_evidence for delete to authenticated using (public.intelligence_is_admin(organization_id));
grant select, insert, update, delete on public.intelligence_outcome_evidence to authenticated;
comment on table public.intelligence_outcome_evidence is 'Tenant-safe Outcome–Evidence relation; contradictory evidence is retained.';
comment on column public.intelligence_outcomes.claim_strength is 'Declared claim strength; never calculated automatically.';
comment on column public.intelligence_outcomes.delta_value is 'Recorded delta only; no automatic formula or ROI.';
