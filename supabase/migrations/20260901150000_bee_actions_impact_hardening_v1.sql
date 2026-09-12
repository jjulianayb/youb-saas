-- youB — Bee Actions + Impact Model V1 additive QA/governance hardening
-- This migration only tightens invariants; it does not create an executor or automate execution.

alter table public.bee_action_requests
  drop constraint if exists bee_action_requests_authorization_state_hardening_check;
alter table public.bee_action_requests
  add constraint bee_action_requests_authorization_state_hardening_check check (
    (authorization_requirement = 'none' and authorization_status = 'not_required')
    or (authorization_requirement = 'confirmation' and authorization_status in ('awaiting_confirmation','approved','rejected','expired'))
    or (authorization_requirement = 'approval' and authorization_status in ('awaiting_approval','approved','rejected','expired'))
    or (authorization_requirement = 'prohibited' and authorization_status = 'rejected' and execution_status = 'not_started')
  );

alter table public.bee_action_requests
  drop constraint if exists bee_action_requests_authorization_metadata_hardening_check;
alter table public.bee_action_requests
  add constraint bee_action_requests_authorization_metadata_hardening_check check (
    (authorization_requirement <> 'confirmation' or authorization_status <> 'approved' or (confirmed_by is not null and confirmed_at is not null))
    and (authorization_requirement <> 'approval' or authorization_status <> 'approved' or (approved_by is not null and approved_at is not null))
  );

alter table public.bee_action_requests
  drop constraint if exists bee_action_requests_active_execution_authorization_hardening_check;
alter table public.bee_action_requests
  add constraint bee_action_requests_active_execution_authorization_hardening_check check (
    execution_status not in ('ready','executing','completed')
    or (authorization_requirement in ('confirmation','approval') and authorization_status = 'approved')
  );

alter table public.bee_action_requests
  drop constraint if exists bee_action_requests_rejected_expired_execution_hardening_check;
alter table public.bee_action_requests
  add constraint bee_action_requests_rejected_expired_execution_hardening_check check (
    authorization_status not in ('rejected','expired')
    or execution_status not in ('ready','executing','completed')
  );

alter table public.bee_action_requests
  drop constraint if exists bee_action_requests_sensitive_execute_approval_hardening_check;
alter table public.bee_action_requests
  add constraint bee_action_requests_sensitive_execute_approval_hardening_check check (
    capability_level <> 'execute'
    or risk_level <> 'sensitive'
    or authorization_requirement = 'approval'
  );

alter table public.bee_action_requests
  drop constraint if exists bee_action_requests_completed_at_hardening_check;
alter table public.bee_action_requests
  add constraint bee_action_requests_completed_at_hardening_check check (
    execution_status <> 'completed' or executed_at is not null
  );

alter table public.intelligence_outcomes
  drop constraint if exists intelligence_outcomes_validated_metadata_hardening_check;
alter table public.intelligence_outcomes
  add constraint intelligence_outcomes_validated_metadata_hardening_check check (
    validation_status <> 'validated'
    or (validated_by is not null and validated_at is not null)
  );

alter table public.intelligence_outcomes
  drop constraint if exists intelligence_outcomes_financial_methodology_hardening_check;
alter table public.intelligence_outcomes
  add constraint intelligence_outcomes_financial_methodology_hardening_check check (
    financial_value is null
    or (financial_value >= 0 and currency is not null and btrim(currency) <> '' and nullif(btrim(measurement_methodology),'') is not null)
  );

comment on constraint bee_action_requests_authorization_state_hardening_check on public.bee_action_requests is 'V1 authorization state machine: requirement and status remain coherent; prohibited requests are rejected and not executable.';
comment on constraint bee_action_requests_authorization_metadata_hardening_check on public.bee_action_requests is 'Approved confirmation/approval requests require their corresponding provenance metadata.';
comment on constraint bee_action_requests_active_execution_authorization_hardening_check on public.bee_action_requests is 'Active execution states require approved authorization.';
comment on constraint bee_action_requests_sensitive_execute_approval_hardening_check on public.bee_action_requests is 'Sensitive execute capability requires approval, never confirmation only.';
comment on constraint intelligence_outcomes_validated_metadata_hardening_check on public.intelligence_outcomes is 'Validated outcomes always require validator provenance.';
comment on constraint intelligence_outcomes_financial_methodology_hardening_check on public.intelligence_outcomes is 'Financial values require non-negative value, currency and methodology; no ROI is calculated.';
