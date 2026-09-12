-- youB — hardening do Intelligence Core
-- Papel + escopo + integridade cross-tenant. Sem IA, score, confidence ou algoritmo.

create or replace function public.intelligence_is_admin(target_org uuid) returns boolean language sql stable security definer set search_path = public as $$ select public.has_org_role(target_org, array['admin_youb','rh']); $$;
create or replace function public.intelligence_is_decision_maker(target_org uuid) returns boolean language sql stable security definer set search_path = public as $$ select public.has_org_role(target_org, array['admin_youb','diretoria','rh']); $$;
create or replace function public.intelligence_has_employee_scope(target_org uuid, target_employee uuid) returns boolean language sql stable security definer set search_path = public as $$ select public.intelligence_is_decision_maker(target_org) or (public.has_org_role(target_org, array['gestor']) and target_employee is not null and exists (select 1 from public.employees subject join public.employees manager on manager.id = subject.manager_employee_id where subject.id = target_employee and subject.organization_id = target_org and manager.auth_user_id = auth.uid())); $$;
create or replace function public.intelligence_is_own_employee(target_org uuid, target_employee uuid) returns boolean language sql stable security definer set search_path = public as $$ select target_employee is not null and exists (select 1 from public.employees e where e.id = target_employee and e.organization_id = target_org and e.auth_user_id = auth.uid()); $$;
create or replace function public.knowledge_access_allowed(target_org uuid, target_access text) returns boolean language sql stable security definer set search_path = public as $$ select public.is_org_member(target_org) and case target_access when 'organization' then true when 'management' then public.has_org_role(target_org, array['admin_youb','diretoria','rh','gestor']) when 'restricted' then public.has_org_role(target_org, array['admin_youb','rh']) else false end; $$;
grant execute on function public.intelligence_is_admin(uuid), public.intelligence_is_decision_maker(uuid), public.intelligence_has_employee_scope(uuid, uuid), public.intelligence_is_own_employee(uuid, uuid), public.knowledge_access_allowed(uuid, text) to authenticated;

do $$ declare t text; c text; begin foreach t in array array['employees','intelligence_signals','intelligence_evidence','intelligence_recommendations','intelligence_interventions','intelligence_actions','knowledge_sources'] loop c := t || '_organization_id_id_key'; if not exists (select 1 from pg_constraint where conname = c) then execute format('alter table public.%I add constraint %I unique (organization_id, id)', t, c); end if; end loop; end $$;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'signals_employee_same_org_fkey') then alter table public.intelligence_signals add constraint signals_employee_same_org_fkey foreign key (organization_id, employee_id) references public.employees (organization_id, id); end if;
  if not exists (select 1 from pg_constraint where conname = 'evidence_signal_same_org_fkey') then alter table public.intelligence_evidence add constraint evidence_signal_same_org_fkey foreign key (organization_id, signal_id) references public.intelligence_signals (organization_id, id); end if;
  if not exists (select 1 from pg_constraint where conname = 'recommendations_employee_same_org_fkey') then alter table public.intelligence_recommendations add constraint recommendations_employee_same_org_fkey foreign key (organization_id, employee_id) references public.employees (organization_id, id); end if;
  if not exists (select 1 from pg_constraint where conname = 'interventions_recommendation_same_org_fkey') then alter table public.intelligence_interventions add constraint interventions_recommendation_same_org_fkey foreign key (organization_id, recommendation_id) references public.intelligence_recommendations (organization_id, id); end if;
  if not exists (select 1 from pg_constraint where conname = 'interventions_employee_same_org_fkey') then alter table public.intelligence_interventions add constraint interventions_employee_same_org_fkey foreign key (organization_id, employee_id) references public.employees (organization_id, id); end if;
  if not exists (select 1 from pg_constraint where conname = 'interventions_owner_same_org_fkey') then alter table public.intelligence_interventions add constraint interventions_owner_same_org_fkey foreign key (organization_id, owner_employee_id) references public.employees (organization_id, id); end if;
  if not exists (select 1 from pg_constraint where conname = 'actions_intervention_same_org_fkey') then alter table public.intelligence_actions add constraint actions_intervention_same_org_fkey foreign key (organization_id, intervention_id) references public.intelligence_interventions (organization_id, id); end if;
  if not exists (select 1 from pg_constraint where conname = 'actions_assignee_same_org_fkey') then alter table public.intelligence_actions add constraint actions_assignee_same_org_fkey foreign key (organization_id, assignee_employee_id) references public.employees (organization_id, id); end if;
  if not exists (select 1 from pg_constraint where conname = 'outcomes_intervention_same_org_fkey') then alter table public.intelligence_outcomes add constraint outcomes_intervention_same_org_fkey foreign key (organization_id, intervention_id) references public.intelligence_interventions (organization_id, id); end if;
  if not exists (select 1 from pg_constraint where conname = 'outcomes_action_same_org_fkey') then alter table public.intelligence_outcomes add constraint outcomes_action_same_org_fkey foreign key (organization_id, action_id) references public.intelligence_actions (organization_id, id); end if;
  if not exists (select 1 from pg_constraint where conname = 'documents_source_same_org_fkey') then alter table public.knowledge_documents add constraint documents_source_same_org_fkey foreign key (organization_id, knowledge_source_id) references public.knowledge_sources (organization_id, id); end if;
end $$;

create table if not exists public.intelligence_recommendation_evidence (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  recommendation_id uuid not null,
  evidence_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (organization_id, recommendation_id, evidence_id),
  constraint recommendation_evidence_recommendation_same_org_fkey foreign key (organization_id, recommendation_id) references public.intelligence_recommendations(organization_id, id) on delete cascade,
  constraint recommendation_evidence_evidence_same_org_fkey foreign key (organization_id, evidence_id) references public.intelligence_evidence(organization_id, id) on delete cascade
);
create index if not exists idx_recommendation_evidence_evidence on public.intelligence_recommendation_evidence(organization_id, evidence_id);
alter table public.intelligence_recommendation_evidence enable row level security;

do $$ declare t text; p text; begin foreach t in array array['intelligence_signals','intelligence_evidence','intelligence_recommendations','intelligence_interventions','intelligence_actions','intelligence_outcomes','knowledge_sources','knowledge_documents'] loop foreach p in array array[t || '_select_members', t || '_insert_members', t || '_update_members', t || '_delete_members'] loop execute format('drop policy if exists %I on public.%I', p, t); end loop; end loop; end $$;
drop policy if exists recommendation_evidence_select on public.intelligence_recommendation_evidence;
drop policy if exists recommendation_evidence_insert on public.intelligence_recommendation_evidence;
drop policy if exists recommendation_evidence_delete on public.intelligence_recommendation_evidence;

create policy intelligence_signals_select_role on public.intelligence_signals for select to authenticated using (public.intelligence_has_employee_scope(organization_id, employee_id) or public.intelligence_is_own_employee(organization_id, employee_id));
create policy intelligence_signals_insert_role on public.intelligence_signals for insert to authenticated with check (public.intelligence_has_employee_scope(organization_id, employee_id));
create policy intelligence_signals_update_role on public.intelligence_signals for update to authenticated using (public.intelligence_has_employee_scope(organization_id, employee_id)) with check (public.intelligence_has_employee_scope(organization_id, employee_id));
create policy intelligence_signals_delete_role on public.intelligence_signals for delete to authenticated using (public.intelligence_is_admin(organization_id));
create policy intelligence_evidence_select_role on public.intelligence_evidence for select to authenticated using (exists (select 1 from public.intelligence_signals s where s.id = signal_id and s.organization_id = intelligence_evidence.organization_id and public.intelligence_has_employee_scope(s.organization_id, s.employee_id)));
create policy intelligence_evidence_insert_role on public.intelligence_evidence for insert to authenticated with check (public.intelligence_is_decision_maker(organization_id));
create policy intelligence_evidence_update_role on public.intelligence_evidence for update to authenticated using (public.intelligence_is_decision_maker(organization_id)) with check (public.intelligence_is_decision_maker(organization_id));
create policy intelligence_evidence_delete_role on public.intelligence_evidence for delete to authenticated using (public.intelligence_is_admin(organization_id));
create policy intelligence_recommendations_select_role on public.intelligence_recommendations for select to authenticated using (public.intelligence_has_employee_scope(organization_id, employee_id) or public.intelligence_is_own_employee(organization_id, employee_id));
create policy intelligence_recommendations_insert_role on public.intelligence_recommendations for insert to authenticated with check (public.intelligence_has_employee_scope(organization_id, employee_id));
create policy intelligence_recommendations_update_role on public.intelligence_recommendations for update to authenticated using (public.intelligence_has_employee_scope(organization_id, employee_id)) with check (public.intelligence_has_employee_scope(organization_id, employee_id));
create policy intelligence_recommendations_delete_role on public.intelligence_recommendations for delete to authenticated using (public.intelligence_is_admin(organization_id));
create policy intelligence_interventions_select_role on public.intelligence_interventions for select to authenticated using (public.intelligence_has_employee_scope(organization_id, employee_id) or public.intelligence_is_own_employee(organization_id, employee_id));
create policy intelligence_interventions_insert_role on public.intelligence_interventions for insert to authenticated with check (public.intelligence_has_employee_scope(organization_id, employee_id));
create policy intelligence_interventions_update_role on public.intelligence_interventions for update to authenticated using (public.intelligence_has_employee_scope(organization_id, employee_id)) with check (public.intelligence_has_employee_scope(organization_id, employee_id));
create policy intelligence_interventions_delete_role on public.intelligence_interventions for delete to authenticated using (public.intelligence_is_admin(organization_id));
create policy intelligence_actions_select_role on public.intelligence_actions for select to authenticated using (public.intelligence_has_employee_scope(organization_id, assignee_employee_id) or public.intelligence_is_own_employee(organization_id, assignee_employee_id));
create policy intelligence_actions_insert_role on public.intelligence_actions for insert to authenticated with check (public.intelligence_has_employee_scope(organization_id, assignee_employee_id));
create policy intelligence_actions_update_role on public.intelligence_actions for update to authenticated using (public.intelligence_has_employee_scope(organization_id, assignee_employee_id)) with check (public.intelligence_has_employee_scope(organization_id, assignee_employee_id));
create policy intelligence_actions_delete_role on public.intelligence_actions for delete to authenticated using (public.intelligence_is_admin(organization_id));
create policy intelligence_outcomes_select_role on public.intelligence_outcomes for select to authenticated using (public.intelligence_is_decision_maker(organization_id));
create policy intelligence_outcomes_insert_role on public.intelligence_outcomes for insert to authenticated with check (public.intelligence_is_decision_maker(organization_id));
create policy intelligence_outcomes_update_role on public.intelligence_outcomes for update to authenticated using (public.intelligence_is_decision_maker(organization_id)) with check (public.intelligence_is_decision_maker(organization_id));
create policy intelligence_outcomes_delete_role on public.intelligence_outcomes for delete to authenticated using (public.intelligence_is_admin(organization_id));
create policy knowledge_sources_select_access on public.knowledge_sources for select to authenticated using (public.knowledge_access_allowed(organization_id, access_level));
create policy knowledge_sources_insert_admin on public.knowledge_sources for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy knowledge_sources_update_admin on public.knowledge_sources for update to authenticated using (public.intelligence_is_admin(organization_id)) with check (public.intelligence_is_admin(organization_id));
create policy knowledge_sources_delete_admin on public.knowledge_sources for delete to authenticated using (public.intelligence_is_admin(organization_id));
create policy knowledge_documents_select_access on public.knowledge_documents for select to authenticated using (public.knowledge_access_allowed(organization_id, access_level));
create policy knowledge_documents_insert_admin on public.knowledge_documents for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy knowledge_documents_update_admin on public.knowledge_documents for update to authenticated using (public.intelligence_is_admin(organization_id)) with check (public.intelligence_is_admin(organization_id));
create policy knowledge_documents_delete_admin on public.knowledge_documents for delete to authenticated using (public.intelligence_is_admin(organization_id));
create policy recommendation_evidence_select on public.intelligence_recommendation_evidence for select to authenticated using (public.intelligence_is_decision_maker(organization_id));
create policy recommendation_evidence_insert on public.intelligence_recommendation_evidence for insert to authenticated with check (public.intelligence_is_decision_maker(organization_id));
create policy recommendation_evidence_delete on public.intelligence_recommendation_evidence for delete to authenticated using (public.intelligence_is_admin(organization_id));
grant select, insert, update, delete on public.intelligence_recommendation_evidence to authenticated;
comment on column public.intelligence_recommendations.source_evidence_ids is 'Compatibilidade/denormalização; a relação referencial é intelligence_recommendation_evidence.';
