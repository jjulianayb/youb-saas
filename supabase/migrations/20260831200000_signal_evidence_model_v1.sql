-- youB — Signal & Evidence Model V1
-- Additive compatibility migration. No scoring, confidence, diagnosis or automation.

alter table public.intelligence_signals
  add column if not exists signal_family text,
  add column if not exists signal_nature text,
  add column if not exists scope_type text,
  add column if not exists scope_ref text,
  add column if not exists direction text,
  add column if not exists persistence text,
  add column if not exists impact_level text,
  add column if not exists sensitivity text,
  add column if not exists window_start date,
  add column if not exists window_end date,
  add column if not exists context jsonb not null default '{}'::jsonb;

alter table public.intelligence_signals drop constraint if exists intelligence_signals_status_check;
update public.intelligence_signals
set status = case status when 'received' then 'observed' when 'reviewed' then 'corroborated' when 'archived' then 'dismissed' else status end
where status in ('received','reviewed','archived');

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'signals_signal_family_v1_check') then alter table public.intelligence_signals add constraint signals_signal_family_v1_check check (signal_family is null or signal_family in ('performance','development','leadership','experience','talent','work','knowledge','organization')); end if;
  if not exists (select 1 from pg_constraint where conname = 'signals_signal_nature_v1_check') then alter table public.intelligence_signals add constraint signals_signal_nature_v1_check check (signal_nature is null or signal_nature in ('risk','opportunity','change','anomaly')); end if;
  if not exists (select 1 from pg_constraint where conname = 'signals_scope_type_v1_check') then alter table public.intelligence_signals add constraint signals_scope_type_v1_check check (scope_type is null or scope_type in ('employee','team','area','position','process','unit','organization')); end if;
  if not exists (select 1 from pg_constraint where conname = 'signals_direction_v1_check') then alter table public.intelligence_signals add constraint signals_direction_v1_check check (direction is null or direction in ('improving','deteriorating','anomalous','mixed','neutral')); end if;
  if not exists (select 1 from pg_constraint where conname = 'signals_persistence_v1_check') then alter table public.intelligence_signals add constraint signals_persistence_v1_check check (persistence is null or persistence in ('isolated','recurring','trend')); end if;
  if not exists (select 1 from pg_constraint where conname = 'signals_impact_level_v1_check') then alter table public.intelligence_signals add constraint signals_impact_level_v1_check check (impact_level is null or impact_level in ('low','moderate','high','critical')); end if;
  if not exists (select 1 from pg_constraint where conname = 'signals_sensitivity_v1_check') then alter table public.intelligence_signals add constraint signals_sensitivity_v1_check check (sensitivity is null or sensitivity in ('standard','restricted','highly_sensitive')); end if;
  if not exists (select 1 from pg_constraint where conname = 'signals_status_v1_check') then alter table public.intelligence_signals add constraint signals_status_v1_check check (status in ('observed','investigating','corroborated','dismissed','resolved')); end if;
  if not exists (select 1 from pg_constraint where conname = 'signals_window_order_v1_check') then alter table public.intelligence_signals add constraint signals_window_order_v1_check check (window_start is null or window_end is null or window_end >= window_start); end if;
end $$;

alter table public.intelligence_evidence
  add column if not exists relation text not null default 'neutral',
  add column if not exists independence_group text;

update public.intelligence_evidence
set evidence_type = 'documented'
where evidence_type not in ('quantitative','qualitative','behavioral','operational','business','documented');

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'evidence_type_v1_check') then alter table public.intelligence_evidence add constraint evidence_type_v1_check check (evidence_type in ('quantitative','qualitative','behavioral','operational','business','documented')); end if;
  if not exists (select 1 from pg_constraint where conname = 'evidence_relation_v1_check') then alter table public.intelligence_evidence add constraint evidence_relation_v1_check check (relation in ('supports','contradicts','neutral')); end if;
end $$;

create index if not exists idx_intelligence_signals_org_family_status_observed on public.intelligence_signals(organization_id, signal_family, status, observed_at desc);
create index if not exists idx_intelligence_signals_org_scope_type on public.intelligence_signals(organization_id, scope_type);
create index if not exists idx_intelligence_signals_org_sensitivity on public.intelligence_signals(organization_id, sensitivity);
create index if not exists idx_intelligence_evidence_org_signal_relation on public.intelligence_evidence(organization_id, signal_id, relation);

create or replace function public.intelligence_signal_sensitive_access(target_org uuid, target_sensitivity text) returns boolean language sql stable security definer set search_path = public as $$
  select case coalesce(target_sensitivity, 'standard')
    when 'standard' then public.is_org_member(target_org)
    when 'restricted' then public.has_org_role(target_org, array['admin_youb','diretoria','rh','gestor'])
    when 'highly_sensitive' then public.has_org_role(target_org, array['admin_youb','rh'])
    else false
  end;
$$;

create or replace function public.intelligence_signal_read_allowed(target_org uuid, target_employee uuid, target_sensitivity text) returns boolean language sql stable security definer set search_path = public as $$
  select public.intelligence_signal_sensitive_access(target_org, target_sensitivity)
    and ((target_employee is null and public.intelligence_is_decision_maker(target_org))
      or (target_employee is not null and (public.intelligence_has_employee_scope(target_org, target_employee) or public.intelligence_is_own_employee(target_org, target_employee))));
$$;

-- V1 direct writes are deliberately narrower than reads. Operational events such as
-- check-ins, feedback and PDI remain the write-side inputs for future organizational readings.
create or replace function public.intelligence_signal_write_allowed(target_org uuid) returns boolean language sql stable security definer set search_path = public as $$
  select public.has_org_role(target_org, array['admin_youb','rh']);
$$;

grant execute on function public.intelligence_signal_sensitive_access(uuid, text), public.intelligence_signal_read_allowed(uuid, uuid, text), public.intelligence_signal_write_allowed(uuid) to authenticated;

drop policy if exists intelligence_signals_select_role on public.intelligence_signals;
drop policy if exists intelligence_signals_insert_role on public.intelligence_signals;
drop policy if exists intelligence_signals_update_role on public.intelligence_signals;
drop policy if exists intelligence_signals_delete_role on public.intelligence_signals;
create policy intelligence_signals_select_role on public.intelligence_signals for select to authenticated using (public.intelligence_signal_read_allowed(organization_id, employee_id, sensitivity));
create policy intelligence_signals_insert_role on public.intelligence_signals for insert to authenticated with check (public.intelligence_signal_write_allowed(organization_id));
create policy intelligence_signals_update_role on public.intelligence_signals for update to authenticated using (public.intelligence_signal_write_allowed(organization_id)) with check (public.intelligence_signal_write_allowed(organization_id));
create policy intelligence_signals_delete_role on public.intelligence_signals for delete to authenticated using (public.intelligence_is_admin(organization_id));

drop policy if exists intelligence_evidence_select_role on public.intelligence_evidence;
create policy intelligence_evidence_select_role on public.intelligence_evidence for select to authenticated using (exists (select 1 from public.intelligence_signals s where s.id = signal_id and s.organization_id = intelligence_evidence.organization_id and public.intelligence_signal_read_allowed(s.organization_id, s.employee_id, s.sensitivity)));

comment on table public.intelligence_signals is 'Leitura Organizacional: DADOS → CONTEXTO → LEITURAS ORGANIZACIONAIS → PADRÕES → HIPÓTESES → EVIDÊNCIAS → DECISÕES → AÇÕES → IMPACTO → MEMÓRIA ORGANIZACIONAL. Technical V1 storage is additive and read-oriented; no confidence, diagnosis or automatic recommendation.';
comment on table public.intelligence_evidence is 'Evidence may support, contradict or contextualize a Leitura Organizacional. V1 has no strength or confidence calculation.';
comment on column public.intelligence_signals.scope_ref is 'Descriptive target reference only; never an authorization mechanism.';
comment on column public.intelligence_evidence.independence_group is 'Optional provenance grouping for future independence analysis; no weights are applied in V1.';
