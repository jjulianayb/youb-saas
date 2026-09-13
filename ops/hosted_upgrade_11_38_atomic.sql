-- ==================================================
-- MIGRATION: 20260830020000_access_context_foundation.sql
-- ==================================================
-- youB — fundação de acesso por camada
-- Sprint 1: additive only. Não altera memberships/roles legados nem concede acesso
-- automaticamente. Aplicar somente após revisão, testes RLS e plano de bootstrap.

create table if not exists public.platform_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform_role text not null check (platform_role in ('platform_admin', 'platform_support', 'platform_analyst')),
  status text not null default 'active' check (status in ('active', 'suspended', 'revoked')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, platform_role)
);

create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  status text not null default 'active' check (status in ('active', 'suspended', 'closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.partner_memberships (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  partner_role text not null check (partner_role in ('partner_admin', 'partner_operator', 'partner_support')),
  status text not null default 'active' check (status in ('invited', 'active', 'suspended', 'revoked')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (partner_id, user_id)
);

create table if not exists public.partner_organization_access (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  access_scope text not null check (access_scope in ('provisioning', 'implementation', 'support', 'reporting')),
  status text not null default 'active' check (status in ('active', 'suspended', 'revoked')),
  granted_by uuid references auth.users(id) on delete set null,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  unique (partner_id, organization_id, access_scope)
);

create index if not exists idx_platform_memberships_user on public.platform_memberships(user_id);
create index if not exists idx_partner_memberships_user on public.partner_memberships(user_id);
create index if not exists idx_partner_memberships_partner on public.partner_memberships(partner_id);
create index if not exists idx_partner_org_access_org on public.partner_organization_access(organization_id);
create index if not exists idx_partner_org_access_partner on public.partner_organization_access(partner_id);

create or replace function public.is_platform_role(allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.platform_memberships pm
    where pm.user_id = auth.uid()
      and pm.platform_role = any(allowed_roles)
      and pm.status = 'active'
      and (pm.expires_at is null or pm.expires_at > now())
  );
$$;

grant execute on function public.is_platform_role(text[]) to authenticated;

create or replace function public.has_partner_role(target_partner uuid, allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.partner_memberships pm
    join public.partners p on p.id = pm.partner_id
    where pm.partner_id = target_partner
      and pm.user_id = auth.uid()
      and pm.partner_role = any(allowed_roles)
      and pm.status = 'active'
      and p.status = 'active'
      and (pm.expires_at is null or pm.expires_at > now())
  );
$$;

grant execute on function public.has_partner_role(uuid, text[]) to authenticated;

create or replace function public.has_partner_org_access(target_org uuid, allowed_scopes text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.partner_memberships pm
    join public.partners p on p.id = pm.partner_id
    join public.partner_organization_access poa on poa.partner_id = pm.partner_id
    where pm.user_id = auth.uid()
      and pm.status = 'active'
      and p.status = 'active'
      and poa.organization_id = target_org
      and poa.access_scope = any(allowed_scopes)
      and poa.status = 'active'
      and (pm.expires_at is null or pm.expires_at > now())
      and (poa.expires_at is null or poa.expires_at > now())
  );
$$;

grant execute on function public.has_partner_org_access(uuid, text[]) to authenticated;

alter table public.platform_memberships enable row level security;
alter table public.partners enable row level security;
alter table public.partner_memberships enable row level security;
alter table public.partner_organization_access enable row level security;

-- Bootstrap de plataforma deve ser feito por operação segura/service role.
drop policy if exists platform_memberships_select_scoped on public.platform_memberships;
create policy platform_memberships_select_scoped
on public.platform_memberships for select to authenticated
using (user_id = auth.uid() or public.is_platform_role(array['platform_admin']));

drop policy if exists platform_memberships_manage_admin on public.platform_memberships;
create policy platform_memberships_manage_admin
on public.platform_memberships for all to authenticated
using (public.is_platform_role(array['platform_admin']))
with check (public.is_platform_role(array['platform_admin']));

drop policy if exists partners_select_scoped on public.partners;
create policy partners_select_scoped
on public.partners for select to authenticated
using (
  public.is_platform_role(array['platform_admin', 'platform_support', 'platform_analyst'])
  or public.has_partner_role(id, array['partner_admin', 'partner_operator', 'partner_support'])
);

drop policy if exists partners_manage_admin on public.partners;
create policy partners_manage_admin
on public.partners for all to authenticated
using (public.is_platform_role(array['platform_admin']))
with check (public.is_platform_role(array['platform_admin']));

drop policy if exists partner_memberships_select_scoped on public.partner_memberships;
create policy partner_memberships_select_scoped
on public.partner_memberships for select to authenticated
using (
  user_id = auth.uid()
  or public.is_platform_role(array['platform_admin', 'platform_support'])
  or public.has_partner_role(partner_id, array['partner_admin', 'partner_operator', 'partner_support'])
);

drop policy if exists partner_memberships_manage_scoped on public.partner_memberships;
create policy partner_memberships_manage_scoped
on public.partner_memberships for all to authenticated
using (
  public.is_platform_role(array['platform_admin'])
  or public.has_partner_role(partner_id, array['partner_admin'])
)
with check (
  public.is_platform_role(array['platform_admin'])
  or public.has_partner_role(partner_id, array['partner_admin'])
);

drop policy if exists partner_org_access_select_scoped on public.partner_organization_access;
create policy partner_org_access_select_scoped
on public.partner_organization_access for select to authenticated
using (
  status = 'active'
  and (expires_at is null or expires_at > now())
  and (
    public.is_platform_role(array['platform_admin', 'platform_support'])
    or public.has_partner_role(partner_id, array['partner_admin', 'partner_operator', 'partner_support'])
  )
);

drop policy if exists partner_org_access_manage_scoped on public.partner_organization_access;
create policy partner_org_access_manage_scoped
on public.partner_organization_access for all to authenticated
using (
  public.is_platform_role(array['platform_admin'])
  or public.has_partner_role(partner_id, array['partner_admin'])
)
with check (
  public.is_platform_role(array['platform_admin'])
  or public.has_partner_role(partner_id, array['partner_admin'])
);

grant select, insert, update, delete on public.platform_memberships,
  public.partners, public.partner_memberships,
  public.partner_organization_access to authenticated;

comment on table public.platform_memberships is
  'Acesso da camada PLATFORM; não substitui memberships organizacionais.';
comment on table public.partner_organization_access is
  'Grant explícito de um partner para uma organização e finalidade.';
-- ==================================================
-- MIGRATION: 20260831030000_intelligence_core_foundation.sql
-- ==================================================
-- youB — Intelligence Core foundation
-- Structural contracts only. No scoring, confidence, diagnosis, ranking or recommendation algorithm.
-- Access remains organization-scoped; platform/partner access is intentionally not inherited.

create table if not exists public.intelligence_signals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  signal_type text not null,
  observed_at timestamptz not null default now(),
  value jsonb not null default '{}'::jsonb,
  source_type text not null,
  source_id text,
  status text not null default 'received' check (status in ('received','reviewed','archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.intelligence_evidence (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  signal_id uuid references public.intelligence_signals(id) on delete set null,
  evidence_type text not null,
  summary text not null,
  payload jsonb not null default '{}'::jsonb,
  source_type text not null,
  source_id text,
  observed_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.intelligence_recommendations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  title text not null,
  rationale text,
  status text not null default 'draft' check (status in ('draft','proposed','accepted','rejected','expired')),
  source_evidence_ids jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.intelligence_interventions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  recommendation_id uuid references public.intelligence_recommendations(id) on delete set null,
  employee_id uuid references public.employees(id) on delete set null,
  intervention_type text not null,
  title text not null,
  plan jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft','proposed','approved','in_progress','completed','cancelled')),
  owner_employee_id uuid references public.employees(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.intelligence_actions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  intervention_id uuid references public.intelligence_interventions(id) on delete set null,
  action_type text not null,
  title text not null,
  details jsonb not null default '{}'::jsonb,
  status text not null default 'proposed' check (status in ('proposed','approved','in_progress','completed','cancelled')),
  assignee_employee_id uuid references public.employees(id) on delete set null,
  due_at timestamptz,
  completed_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.intelligence_outcomes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  intervention_id uuid references public.intelligence_interventions(id) on delete set null,
  action_id uuid references public.intelligence_actions(id) on delete set null,
  outcome_type text not null,
  status text not null default 'observed' check (status in ('observed','confirmed','rejected')),
  details jsonb not null default '{}'::jsonb,
  measured_at timestamptz not null default now(),
  recorded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.knowledge_sources (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  source_type text not null check (source_type in ('policy','procedure','culture','onboarding','benefit','manual','faq','training','other')),
  name text not null,
  owner_user_id uuid references auth.users(id) on delete set null,
  access_level text not null default 'organization' check (access_level in ('organization','management','restricted')),
  status text not null default 'active' check (status in ('active','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.knowledge_documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  knowledge_source_id uuid references public.knowledge_sources(id) on delete set null,
  document_type text not null check (document_type in ('policy','procedure','culture','onboarding','benefit','manual','faq','training','other')),
  title text not null,
  version text not null default '1.0',
  status text not null default 'draft' check (status in ('draft','published','archived')),
  valid_from date,
  valid_until date,
  content text,
  storage_path text,
  access_level text not null default 'organization' check (access_level in ('organization','management','restricted')),
  owner_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_intelligence_signals_org on public.intelligence_signals(organization_id, observed_at desc);
create index if not exists idx_intelligence_evidence_org on public.intelligence_evidence(organization_id, observed_at desc);
create index if not exists idx_intelligence_recommendations_org on public.intelligence_recommendations(organization_id, created_at desc);
create index if not exists idx_intelligence_interventions_org on public.intelligence_interventions(organization_id, created_at desc);
create index if not exists idx_intelligence_actions_org on public.intelligence_actions(organization_id, due_at);
create index if not exists idx_intelligence_outcomes_org on public.intelligence_outcomes(organization_id, measured_at desc);
create index if not exists idx_knowledge_sources_org on public.knowledge_sources(organization_id, status);
create index if not exists idx_knowledge_documents_org on public.knowledge_documents(organization_id, status, valid_until);

-- RLS is deliberately organization membership only in this foundation.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'intelligence_signals','intelligence_evidence','intelligence_recommendations',
    'intelligence_interventions','intelligence_actions','intelligence_outcomes',
    'knowledge_sources','knowledge_documents'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('drop policy if exists %I on public.%I', table_name || '_select_members', table_name);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_org_member(organization_id))', table_name || '_select_members', table_name);
    execute format('drop policy if exists %I on public.%I', table_name || '_insert_members', table_name);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.is_org_member(organization_id))', table_name || '_insert_members', table_name);
    execute format('drop policy if exists %I on public.%I', table_name || '_update_members', table_name);
    execute format('create policy %I on public.%I for update to authenticated using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id))', table_name || '_update_members', table_name);
    execute format('drop policy if exists %I on public.%I', table_name || '_delete_members', table_name);
    execute format('create policy %I on public.%I for delete to authenticated using (public.is_org_member(organization_id))', table_name || '_delete_members', table_name);
  end loop;
end $$;

grant select, insert, update, delete on public.intelligence_signals, public.intelligence_evidence, public.intelligence_recommendations, public.intelligence_interventions, public.intelligence_actions, public.intelligence_outcomes, public.knowledge_sources, public.knowledge_documents to authenticated;

comment on schema public is 'Intelligence contracts intentionally contain no scoring or recommendation algorithm.';
-- ==================================================
-- MIGRATION: 20260831040000_access_foundation_hardening.sql
-- ==================================================
-- youB — hardening da fundação de acesso
-- A camada Platform atribui primeiro a relação partner-organização.
-- Bootstrap/promoção de platform_memberships permanecem fora do JWT público.

create table if not exists public.platform_partner_organization_assignments (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  status text not null default 'active' check (status in ('active','revoked')),
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (partner_id, organization_id)
);
create index if not exists idx_platform_partner_org_assignment_lookup on public.platform_partner_organization_assignments(partner_id, organization_id, status);
alter table public.platform_partner_organization_assignments enable row level security;
revoke all on public.platform_partner_organization_assignments from authenticated;

create or replace function public.require_platform_partner_org_assignment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.platform_partner_organization_assignments a where a.partner_id = new.partner_id and a.organization_id = new.organization_id and a.status = 'active') then
    raise exception 'partner organization relation requires an active Platform assignment';
  end if;
  return new;
end;
$$;
revoke execute on function public.require_platform_partner_org_assignment() from public, authenticated;
drop trigger if exists enforce_platform_partner_org_assignment on public.partner_organization_access;
create trigger enforce_platform_partner_org_assignment before insert or update of partner_id, organization_id on public.partner_organization_access for each row execute function public.require_platform_partner_org_assignment();

-- Provisioning, promotion, suspension and revocation are server-side.
drop policy if exists platform_memberships_manage_admin on public.platform_memberships;
revoke insert, update, delete on public.platform_memberships from authenticated;

drop policy if exists platform_partner_org_assignments_select_platform on public.platform_partner_organization_assignments;
create policy platform_partner_org_assignments_select_platform on public.platform_partner_organization_assignments for select to authenticated using (public.is_platform_role(array['platform_admin','platform_support','platform_analyst']));
grant select on public.platform_partner_organization_assignments to authenticated;

comment on table public.platform_partner_organization_assignments is 'Relação previamente atribuída pela camada Platform; escrita somente por operação privilegiada server-side.';
comment on table public.platform_memberships is 'Bootstrap, promoção, suspensão e revogação somente server-side; JWT autenticado não administra esta tabela.';
-- ==================================================
-- MIGRATION: 20260831050000_intelligence_core_hardening.sql
-- ==================================================
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
-- ==================================================
-- MIGRATION: 20260831200000_signal_evidence_model_v1.sql
-- ==================================================
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
-- ==================================================
-- MIGRATION: 20260831210000_recommendation_model_v1_base.sql
-- ==================================================
-- Recommendation Model V1 base columns. Structural only; no automatic generation or execution.
alter table public.intelligence_recommendations add column if not exists recommendation_type text, add column if not exists scope_type text, add column if not exists scope_ref text, add column if not exists evidence_state text, add column if not exists problem_statement text, add column if not exists unknowns jsonb not null default '[]'::jsonb, add column if not exists recommended_intervention_type text, add column if not exists alternatives jsonb not null default '[]'::jsonb, add column if not exists do_not_recommend jsonb not null default '[]'::jsonb, add column if not exists expected_outcome text, add column if not exists measurement_plan jsonb not null default '{}'::jsonb, add column if not exists estimated_cost numeric, add column if not exists currency text, add column if not exists owner_employee_id uuid, add column if not exists approval_required boolean not null default false, add column if not exists approved_by uuid, add column if not exists approved_at timestamptz, add column if not exists follow_up_at timestamptz, add column if not exists context jsonb not null default '{}'::jsonb;
do $$ begin
 if not exists(select 1 from pg_constraint where conname='recommendations_owner_same_org_fkey') then alter table public.intelligence_recommendations add constraint recommendations_owner_same_org_fkey foreign key(organization_id,owner_employee_id) references public.employees(organization_id,id); end if;
 if not exists(select 1 from pg_constraint where conname='recommendations_approved_by_fkey') then alter table public.intelligence_recommendations add constraint recommendations_approved_by_fkey foreign key(approved_by) references auth.users(id) on delete set null; end if;
end $$;

-- ==================================================
-- MIGRATION: 20260831210001_intervention_model_v1_base.sql
-- ==================================================
-- Intervention Model V1 base columns. Structural only; no automatic creation or execution.
alter table public.intelligence_interventions add column if not exists intervention_family text, add column if not exists objective text, add column if not exists target_scope_type text, add column if not exists target_scope_ref text, add column if not exists success_criteria jsonb not null default '[]'::jsonb, add column if not exists measurement_plan jsonb not null default '{}'::jsonb, add column if not exists estimated_cost numeric, add column if not exists currency text, add column if not exists starts_at timestamptz, add column if not exists expected_end_at timestamptz, add column if not exists follow_up_at timestamptz, add column if not exists requires_human_approval boolean not null default false, add column if not exists context jsonb not null default '{}'::jsonb;
-- ==================================================
-- MIGRATION: 20260831210002_recommendation_intervention_v1_constraints.sql
-- ==================================================
-- Recommendation and Intervention V1 constraints. Structural only.
do $$ begin
 if not exists(select 1 from pg_constraint where conname='recommendations_type_v1_check') then alter table public.intelligence_recommendations add constraint recommendations_type_v1_check check(recommendation_type is null or recommendation_type in('investigate','intervene','maintain','replicate','monitor','no_action')); end if;
 if not exists(select 1 from pg_constraint where conname='recommendations_scope_type_v1_check') then alter table public.intelligence_recommendations add constraint recommendations_scope_type_v1_check check(scope_type is null or scope_type in('employee','team','area','position','process','unit','organization')); end if;
 if not exists(select 1 from pg_constraint where conname='recommendations_evidence_state_v1_check') then alter table public.intelligence_recommendations add constraint recommendations_evidence_state_v1_check check(evidence_state is null or evidence_state in('insufficient','moderate','strong')); end if;
 if not exists(select 1 from pg_constraint where conname='recommendations_insufficient_intervene_v1_check') then alter table public.intelligence_recommendations add constraint recommendations_insufficient_intervene_v1_check check(evidence_state is distinct from 'insufficient' or recommendation_type is null or recommendation_type in('investigate','monitor','no_action')); end if;
 if not exists(select 1 from pg_constraint where conname='recommendations_cost_currency_v1_check') then alter table public.intelligence_recommendations add constraint recommendations_cost_currency_v1_check check((estimated_cost is null and currency is null) or(estimated_cost is not null and estimated_cost>=0 and currency is not null and length(btrim(currency))>0)); end if;
 if not exists(select 1 from pg_constraint where conname='recommendations_unknowns_array_v1_check') then alter table public.intelligence_recommendations add constraint recommendations_unknowns_array_v1_check check(jsonb_typeof(unknowns)='array'); end if;
 if not exists(select 1 from pg_constraint where conname='recommendations_alternatives_array_v1_check') then alter table public.intelligence_recommendations add constraint recommendations_alternatives_array_v1_check check(jsonb_typeof(alternatives)='array'); end if;
 if not exists(select 1 from pg_constraint where conname='recommendations_do_not_recommend_array_v1_check') then alter table public.intelligence_recommendations add constraint recommendations_do_not_recommend_array_v1_check check(jsonb_typeof(do_not_recommend)='array'); end if;
 if not exists(select 1 from pg_constraint where conname='recommendations_measurement_plan_object_v1_check') then alter table public.intelligence_recommendations add constraint recommendations_measurement_plan_object_v1_check check(jsonb_typeof(measurement_plan)='object'); end if;
 if not exists(select 1 from pg_constraint where conname='recommendations_context_object_v1_check') then alter table public.intelligence_recommendations add constraint recommendations_context_object_v1_check check(jsonb_typeof(context)='object'); end if;
 if not exists(select 1 from pg_constraint where conname='interventions_family_v1_check') then alter table public.intelligence_interventions add constraint interventions_family_v1_check check(intervention_family is null or intervention_family in('investigation','learning','mentoring','coaching','leadership','process','work_design','communication','recognition','career','succession','mobility','structure','people_practice','consulting','none')); end if;
 if not exists(select 1 from pg_constraint where conname='interventions_target_scope_type_v1_check') then alter table public.intelligence_interventions add constraint interventions_target_scope_type_v1_check check(target_scope_type is null or target_scope_type in('employee','team','area','position','process','unit','organization')); end if;
 if not exists(select 1 from pg_constraint where conname='interventions_dates_v1_check') then alter table public.intelligence_interventions add constraint interventions_dates_v1_check check(starts_at is null or expected_end_at is null or expected_end_at>=starts_at); end if;
 if not exists(select 1 from pg_constraint where conname='interventions_cost_currency_v1_check') then alter table public.intelligence_interventions add constraint interventions_cost_currency_v1_check check((estimated_cost is null and currency is null) or(estimated_cost is not null and estimated_cost>=0 and currency is not null and length(btrim(currency))>0)); end if;
 if not exists(select 1 from pg_constraint where conname='interventions_success_criteria_array_v1_check') then alter table public.intelligence_interventions add constraint interventions_success_criteria_array_v1_check check(jsonb_typeof(success_criteria)='array'); end if;
 if not exists(select 1 from pg_constraint where conname='interventions_measurement_plan_object_v1_check') then alter table public.intelligence_interventions add constraint interventions_measurement_plan_object_v1_check check(jsonb_typeof(measurement_plan)='object'); end if;
 if not exists(select 1 from pg_constraint where conname='interventions_context_object_v1_check') then alter table public.intelligence_interventions add constraint interventions_context_object_v1_check check(jsonb_typeof(context)='object'); end if;
end $$;
-- ==================================================
-- MIGRATION: 20260901000000_recommendation_intervention_model_v1.sql
-- ==================================================
create index if not exists idx_intelligence_recommendations_org_type_state on public.intelligence_recommendations(organization_id,recommendation_type,evidence_state,status);
create index if not exists idx_intelligence_recommendations_org_scope on public.intelligence_recommendations(organization_id,scope_type);
create index if not exists idx_intelligence_interventions_org_family_scope on public.intelligence_interventions(organization_id,intervention_family,target_scope_type);
drop policy if exists intelligence_recommendations_insert_role on public.intelligence_recommendations;
drop policy if exists intelligence_recommendations_update_role on public.intelligence_recommendations;
create policy intelligence_recommendations_insert_role on public.intelligence_recommendations for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy intelligence_recommendations_update_role on public.intelligence_recommendations for update to authenticated using(public.intelligence_is_admin(organization_id)) with check(public.intelligence_is_admin(organization_id));
drop policy if exists intelligence_interventions_insert_role on public.intelligence_interventions;
drop policy if exists intelligence_interventions_update_role on public.intelligence_interventions;
create policy intelligence_interventions_insert_role on public.intelligence_interventions for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy intelligence_interventions_update_role on public.intelligence_interventions for update to authenticated using(public.intelligence_is_admin(organization_id)) with check(public.intelligence_is_admin(organization_id));
drop policy if exists recommendation_evidence_insert on public.intelligence_recommendation_evidence;
create policy recommendation_evidence_insert on public.intelligence_recommendation_evidence for insert to authenticated with check(public.intelligence_is_admin(organization_id));
comment on table public.intelligence_recommendations is 'Structured, explainable contract for Leitura Organizacional. No automatic generation, scoring or execution.';
comment on column public.intelligence_recommendations.scope_ref is 'Reference only; never an authorization mechanism.';
comment on column public.intelligence_recommendations.source_evidence_ids is 'Compatibility only; intelligence_recommendation_evidence is authoritative.';
comment on table public.intelligence_interventions is 'Extensible intervention contract. No recommendation-to-intervention automation or execution in V1.';
comment on column public.intelligence_interventions.target_scope_ref is 'Reference only; never an authorization mechanism.';
-- ==================================================
-- MIGRATION: 20260901130000_bee_actions_impact_foundation_v1.sql
-- ==================================================
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
-- ==================================================
-- MIGRATION: 20260901150000_bee_actions_impact_hardening_v1.sql
-- ==================================================
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
-- ==================================================
-- MIGRATION: 20260901170000_organizational_memory_event_layer_v1.sql
-- ==================================================
-- youB — Organizational Memory + Event Layer V1
-- Additive contract only: PostgreSQL storage, temporal relations and a light append-oriented event layer.
-- No graph database, full event sourcing, replay, queue/Kafka, triggers or automatic event capture.

create table if not exists public.organizational_memory_entity_types (
  entity_type text primary key check (entity_type ~ '^[a-z][a-z0-9_]*$'),
  description text not null,
  created_at timestamptz not null default now()
);

insert into public.organizational_memory_entity_types(entity_type, description) values
  ('fact','A structured organizational fact.'),
  ('declaration','A declared statement, not independently validated as fact.'),
  ('reading','An organizational reading or interpretation record.'),
  ('hypothesis','A hypothesis that must not be treated as a fact.'),
  ('decision','A recorded organizational decision.'),
  ('intervention','An intervention record.'),
  ('outcome','An outcome record.'),
  ('employee','An employee reference; entity id is descriptive and not an implicit authorization.'),
  ('area','An area reference; entity id is descriptive and not an implicit authorization.'),
  ('position','A position reference; entity id is descriptive and not an implicit authorization.'),
  ('unit','A unit reference; entity id is descriptive and not an implicit authorization.'),
  ('organization','An organization reference.'),
  ('feedback','A feedback reference.'),
  ('checkin','A check-in reference.'),
  ('pdi','A PDI reference.'),
  ('assessment','An assessment reference.'),
  ('recommendation','A recommendation reference.'),
  ('action','An action reference.'),
  ('event','An organizational event reference.')
on conflict (entity_type) do nothing;

create table if not exists public.organizational_memory_relationship_types (
  relationship_type text primary key check (relationship_type ~ '^[a-z][a-z0-9_]*$'),
  description text not null,
  created_at timestamptz not null default now()
);

insert into public.organizational_memory_relationship_types(relationship_type, description) values
  ('supports','Supports the target record.'),
  ('contradicts','Contradicts the target record.'),
  ('derived_from','Was derived from the target record.'),
  ('declares','Declares the target record.'),
  ('observes','Observes the target record.'),
  ('concerns','Concerns the target record.'),
  ('manages','Represents a management relationship.'),
  ('belongs_to','Represents organizational membership.'),
  ('affects','Affects the target record.'),
  ('led_to','Is recorded as leading to the target record.'),
  ('requires','Requires the target record.'),
  ('related_to','General documented relationship.')
on conflict (relationship_type) do nothing;

create table if not exists public.organizational_memory_relations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  source_entity_type text not null references public.organizational_memory_entity_types(entity_type),
  source_entity_id uuid not null,
  target_entity_type text not null references public.organizational_memory_entity_types(entity_type),
  target_entity_id uuid not null,
  relationship_type text not null references public.organizational_memory_relationship_types(relationship_type),
  knowledge_kind text not null check (knowledge_kind in ('fact','declared','observed','derived','interpreted','hypothesis')),
  valid_from timestamptz not null,
  valid_until timestamptz,
  recorded_at timestamptz not null default now(),
  source_type text not null check (source_type in ('manual','system','service','bee','import','integration')),
  source_id text,
  sensitivity text not null default 'standard' check (sensitivity in ('standard','restricted','highly_sensitive')),
  context jsonb not null default '{}'::jsonb check (jsonb_typeof(context) = 'object'),
  created_at timestamptz not null default now(),
  constraint organizational_memory_relations_valid_window_check check (valid_until is null or valid_until >= valid_from)
);

create table if not exists public.organizational_event_types (
  event_type text primary key check (event_type ~ '^[a-z][a-z0-9_]*$'),
  description text not null,
  implemented boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.organizational_event_types(event_type, description, implemented) values
  ('employee_created','Employee was created.',true),
  ('employee_status_changed','Employee status changed.',true),
  ('area_changed','Employee area changed.',true),
  ('position_changed','Employee position changed.',true),
  ('manager_changed','Employee manager changed.',true),
  ('feedback_recorded','Feedback was recorded.',true),
  ('checkin_recorded','Check-in was recorded.',true),
  ('pdi_created','PDI was created.',true),
  ('pdi_updated','PDI was updated.',true),
  ('assessment_recorded','Assessment was recorded.',true),
  ('learning_assigned','Learning activity was assigned.',true),
  ('learning_completed','Learning activity was completed.',true),
  ('organizational_reading_created','Organizational reading was created.',true),
  ('recommendation_created','Recommendation was created.',true),
  ('decision_recorded','Decision was recorded.',true),
  ('intervention_created','Intervention was created.',true),
  ('action_created','Action was created.',true),
  ('action_completed','Action was completed.',true),
  ('outcome_recorded','Outcome was recorded.',true),
  ('training_assigned','Future training compliance event contract.',false),
  ('training_scheduled','Future training compliance event contract.',false),
  ('training_completed','Future training compliance event contract.',false),
  ('training_expiring','Future training compliance event contract.',false),
  ('training_expired','Future training compliance event contract.',false),
  ('recertification_scheduled','Future training compliance event contract.',false)
on conflict (event_type) do nothing;

create table if not exists public.organizational_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  event_type text not null references public.organizational_event_types(event_type),
  entity_type text not null references public.organizational_memory_entity_types(entity_type),
  entity_id uuid not null,
  related_entity_type text references public.organizational_memory_entity_types(entity_type),
  related_entity_id uuid,
  occurred_at timestamptz not null,
  recorded_at timestamptz not null default now(),
  source_type text not null check (source_type in ('manual','system','service','bee','import','integration')),
  source_id text,
  actor_user_id uuid references auth.users(id) on delete set null,
  sensitivity text not null default 'standard' check (sensitivity in ('standard','restricted','highly_sensitive')),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  correlation_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists idx_org_memory_relations_org_valid on public.organizational_memory_relations(organization_id, valid_from desc, valid_until);
create index if not exists idx_org_memory_relations_source on public.organizational_memory_relations(organization_id, source_entity_type, source_entity_id);
create index if not exists idx_org_memory_relations_target on public.organizational_memory_relations(organization_id, target_entity_type, target_entity_id);
create index if not exists idx_org_events_org_occurred on public.organizational_events(organization_id, occurred_at desc, recorded_at desc);
create index if not exists idx_org_events_entity on public.organizational_events(organization_id, entity_type, entity_id, occurred_at desc);
create index if not exists idx_org_events_correlation on public.organizational_events(organization_id, correlation_id);

alter table public.organizational_memory_entity_types enable row level security;
alter table public.organizational_memory_relationship_types enable row level security;
alter table public.organizational_event_types enable row level security;
alter table public.organizational_memory_relations enable row level security;
alter table public.organizational_events enable row level security;

create policy organizational_memory_entity_types_select on public.organizational_memory_entity_types for select to authenticated using (true);
create policy organizational_memory_relationship_types_select on public.organizational_memory_relationship_types for select to authenticated using (true);
create policy organizational_event_types_select on public.organizational_event_types for select to authenticated using (true);

create policy organizational_memory_relations_select on public.organizational_memory_relations
  for select to authenticated using (
    public.intelligence_is_admin(organization_id)
    or (public.has_org_role(organization_id, array['diretoria']) and sensitivity in ('standard','restricted'))
  );
create policy organizational_memory_relations_insert on public.organizational_memory_relations
  for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy organizational_memory_relations_update on public.organizational_memory_relations
  for update to authenticated using (public.intelligence_is_admin(organization_id)) with check (public.intelligence_is_admin(organization_id));
create policy organizational_memory_relations_delete on public.organizational_memory_relations
  for delete to authenticated using (public.intelligence_is_admin(organization_id));

create policy organizational_events_select on public.organizational_events
  for select to authenticated using (
    public.intelligence_is_admin(organization_id)
    or (public.has_org_role(organization_id, array['diretoria']) and sensitivity in ('standard','restricted'))
  );
-- Events are append-oriented: admin/RH may record them, but this V1 grants no update/delete.
create policy organizational_events_insert on public.organizational_events
  for insert to authenticated with check (public.intelligence_is_admin(organization_id));

grant select on public.organizational_memory_entity_types, public.organizational_memory_relationship_types, public.organizational_event_types to authenticated;
grant select, insert, update, delete on public.organizational_memory_relations to authenticated;
grant select, insert on public.organizational_events to authenticated;

comment on table public.organizational_memory_relations is 'Temporal organizational memory relations. Polymorphic entity ids are descriptive; authorization never depends on them. History is preserved by closing intervals and inserting new relations.';
comment on column public.organizational_memory_relations.knowledge_kind is 'Epistemic kind: hypothesis is explicitly distinct from fact and is never promoted implicitly.';
comment on table public.organizational_events is 'Light append-oriented event layer. An event records something that happened; it is not current state and does not implement full event sourcing or replay.';
comment on column public.organizational_events.payload is 'Structured metadata only; raw Bee conversations and full prompts are not stored here.';
comment on table public.organizational_event_types is 'Controlled, extensible event vocabulary. New event types require an explicit catalog migration; arbitrary event_type text is rejected.';
comment on table public.organizational_memory_entity_types is 'Controlled entity vocabulary. Polymorphic entity ids intentionally have no invented foreign key.';
-- ==================================================
-- MIGRATION: 20260901193000_organizational_memory_event_layer_v1_hardening.sql
-- ==================================================
-- youB — Organizational Memory + Event Layer V1 additive hardening
-- Declarative activation gate: catalog contracts with implemented=false remain
-- visible, but organizational_events can only reference implemented=true types.
-- No trigger, replay, queue or automatic event capture is introduced.

alter table public.organizational_event_types
  add constraint organizational_event_types_event_type_implemented_key
  unique (event_type, implemented);

alter table public.organizational_events
  add column event_type_implemented boolean not null default true;

alter table public.organizational_events
  add constraint organizational_events_event_type_implemented_check
  check (event_type_implemented is true);

alter table public.organizational_events
  add constraint organizational_events_event_type_implemented_fkey
  foreign key (event_type, event_type_implemented)
  references public.organizational_event_types (event_type, implemented);

comment on column public.organizational_events.event_type_implemented is
  'Technical activation witness. Must remain true and match the catalog, so implemented=false contracts cannot be recorded.';
comment on constraint organizational_events_event_type_implemented_check on public.organizational_events is
  'Only active event types may be recorded; future catalog contracts remain readable but inactive.';
comment on constraint organizational_events_event_type_implemented_fkey on public.organizational_events is
  'Composite catalog reference couples event recording to implemented=true.';
-- ==================================================
-- MIGRATION: 20260901210000_decision_engine_v1.sql
-- ==================================================
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
-- ==================================================
-- MIGRATION: 20260901213000_decision_engine_v1_hardening.sql
-- ==================================================
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
-- ==================================================
-- MIGRATION: 20260901230000_organizational_reading_engine_v1.sql
-- ==================================================
-- youB — Organizational Reading Engine V1
-- Product concept: Leitura Organizacional. Structural/provenance foundation only.
-- No automatic generation, scoring, ranking, ML, LLM, diagnosis or downstream automation.

-- Composite tenant-safe reference support for existing provenance sources.
do $$ begin
  if not exists (select 1 from pg_constraint where conrelid='public.intelligence_evidence'::regclass and conname='intelligence_evidence_organization_id_id_key') then
    alter table public.intelligence_evidence add constraint intelligence_evidence_organization_id_id_key unique (organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.knowledge_sources'::regclass and conname='knowledge_sources_organization_id_id_key') then
    alter table public.knowledge_sources add constraint knowledge_sources_organization_id_id_key unique (organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.knowledge_documents'::regclass and conname='knowledge_documents_organization_id_id_key') then
    alter table public.knowledge_documents add constraint knowledge_documents_organization_id_id_key unique (organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.organizational_events'::regclass and conname='organizational_events_organization_id_id_key') then
    alter table public.organizational_events add constraint organizational_events_organization_id_id_key unique (organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.organizational_memory_relations'::regclass and conname='organizational_memory_relations_organization_id_id_key') then
    alter table public.organizational_memory_relations add constraint organizational_memory_relations_organization_id_id_key unique (organization_id,id);
  end if;
end $$;

create table if not exists public.intelligence_organizational_readings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  reading_type text not null check (reading_type in ('movement','pattern','anomaly','risk','opportunity','tension','gap','evolution')),
  scope_type text not null check (scope_type in ('employee','team','area','position','process','unit','organization')),
  scope_ref text not null check (btrim(scope_ref) <> ''),
  title text not null check (btrim(title) <> ''),
  description text not null check (btrim(description) <> ''),
  status text not null default 'open' check (status in ('open','under_investigation','supported','dismissed','resolved','archived')),
  -- A Reading is an interpreted organizational description in V1, never a fact.
  knowledge_kind text not null default 'interpreted' check (knowledge_kind = 'interpreted'),
  observation_window_start timestamptz not null,
  observation_window_end timestamptz not null,
  detected_at timestamptz not null default now(),
  source_summary text not null check (btrim(source_summary) <> ''),
  context jsonb not null default '{}'::jsonb check (jsonb_typeof(context) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint intelligence_organizational_readings_organization_id_id_key unique (organization_id,id),
  constraint intelligence_organizational_readings_window_check check (observation_window_end >= observation_window_start)
);

create table if not exists public.intelligence_organizational_reading_sources (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  reading_id uuid not null,
  source_type text not null check (source_type in ('evidence','knowledge_source','knowledge_document','organizational_event','memory_relation')),
  evidence_id uuid,
  knowledge_source_id uuid,
  knowledge_document_id uuid,
  organizational_event_id uuid,
  memory_relation_id uuid,
  relationship_type text not null default 'supports' check (relationship_type in ('supports','contradicts','contextualizes','derived_from','observed_in')),
  provenance_note text,
  context jsonb not null default '{}'::jsonb check (jsonb_typeof(context) = 'object'),
  created_at timestamptz not null default now(),
  constraint intelligence_reading_sources_unique unique (organization_id,reading_id,source_type,evidence_id,knowledge_source_id,knowledge_document_id,organizational_event_id,memory_relation_id),
  constraint intelligence_reading_sources_reading_same_org_fkey foreign key (organization_id,reading_id) references public.intelligence_organizational_readings(organization_id,id) on delete cascade,
  constraint intelligence_reading_sources_evidence_same_org_fkey foreign key (organization_id,evidence_id) references public.intelligence_evidence(organization_id,id),
  constraint intelligence_reading_sources_knowledge_source_same_org_fkey foreign key (organization_id,knowledge_source_id) references public.knowledge_sources(organization_id,id),
  constraint intelligence_reading_sources_knowledge_document_same_org_fkey foreign key (organization_id,knowledge_document_id) references public.knowledge_documents(organization_id,id),
  constraint intelligence_reading_sources_event_same_org_fkey foreign key (organization_id,organizational_event_id) references public.organizational_events(organization_id,id),
  constraint intelligence_reading_sources_memory_relation_same_org_fkey foreign key (organization_id,memory_relation_id) references public.organizational_memory_relations(organization_id,id),
  constraint intelligence_reading_sources_exact_source_check check (
    (source_type='evidence' and evidence_id is not null and knowledge_source_id is null and knowledge_document_id is null and organizational_event_id is null and memory_relation_id is null)
    or (source_type='knowledge_source' and evidence_id is null and knowledge_source_id is not null and knowledge_document_id is null and organizational_event_id is null and memory_relation_id is null)
    or (source_type='knowledge_document' and evidence_id is null and knowledge_source_id is null and knowledge_document_id is not null and organizational_event_id is null and memory_relation_id is null)
    or (source_type='organizational_event' and evidence_id is null and knowledge_source_id is null and knowledge_document_id is null and organizational_event_id is not null and memory_relation_id is null)
    or (source_type='memory_relation' and evidence_id is null and knowledge_source_id is null and knowledge_document_id is null and organizational_event_id is null and memory_relation_id is not null)
  )
);

create table if not exists public.intelligence_organizational_reading_hypotheses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  reading_id uuid not null,
  hypothesis_statement text not null check (btrim(hypothesis_statement) <> ''),
  status text not null default 'proposed' check (status in ('proposed','under_investigation','supported','dismissed')),
  knowledge_kind text not null default 'hypothesis' check (knowledge_kind = 'hypothesis'),
  context jsonb not null default '{}'::jsonb check (jsonb_typeof(context) = 'object'),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint intelligence_reading_hypotheses_organization_id_id_key unique (organization_id,id),
  constraint intelligence_reading_hypotheses_reading_same_org_fkey foreign key (organization_id,reading_id) references public.intelligence_organizational_readings(organization_id,id) on delete cascade
);

create table if not exists public.intelligence_organizational_reading_revisions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  reading_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  changed_by_user_id uuid not null references auth.users(id) on delete restrict,
  change_reason text not null check (btrim(change_reason) <> ''),
  previous_snapshot jsonb not null check (jsonb_typeof(previous_snapshot) = 'object'),
  new_snapshot jsonb not null check (jsonb_typeof(new_snapshot) = 'object'),
  created_at timestamptz not null default now(),
  constraint intelligence_reading_revisions_unique unique (organization_id,reading_id,revision_number),
  constraint intelligence_reading_revisions_reading_same_org_fkey foreign key (organization_id,reading_id) references public.intelligence_organizational_readings(organization_id,id) on delete cascade
);

create index if not exists idx_org_readings_org_detected on public.intelligence_organizational_readings(organization_id,detected_at desc);
create index if not exists idx_org_readings_org_scope on public.intelligence_organizational_readings(organization_id,scope_type,scope_ref);
create index if not exists idx_reading_sources_org_reading on public.intelligence_organizational_reading_sources(organization_id,reading_id);
create index if not exists idx_reading_hypotheses_org_reading on public.intelligence_organizational_reading_hypotheses(organization_id,reading_id);
create index if not exists idx_reading_revisions_org_reading on public.intelligence_organizational_reading_revisions(organization_id,reading_id,revision_number desc);

alter table public.intelligence_organizational_readings enable row level security;
alter table public.intelligence_organizational_reading_sources enable row level security;
alter table public.intelligence_organizational_reading_hypotheses enable row level security;
alter table public.intelligence_organizational_reading_revisions enable row level security;
create policy organizational_readings_select_role on public.intelligence_organizational_readings for select to authenticated using (
  public.intelligence_is_admin(organization_id)
  or (public.has_org_role(organization_id,array['diretoria']) and scope_type in ('team','area','unit','process','organization'))
);
create policy organizational_readings_insert_admin on public.intelligence_organizational_readings for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy organizational_reading_sources_select_role on public.intelligence_organizational_reading_sources for select to authenticated using (
  public.intelligence_is_admin(organization_id)
  or exists (select 1 from public.intelligence_organizational_readings r where r.organization_id=public.intelligence_organizational_reading_sources.organization_id and r.id=public.intelligence_organizational_reading_sources.reading_id and public.has_org_role(r.organization_id,array['diretoria']) and r.scope_type in ('team','area','unit','process','organization'))
);
create policy organizational_reading_sources_insert_admin on public.intelligence_organizational_reading_sources for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy organizational_reading_sources_delete_admin on public.intelligence_organizational_reading_sources for delete to authenticated using (public.intelligence_is_admin(organization_id));
create policy organizational_reading_hypotheses_select_role on public.intelligence_organizational_reading_hypotheses for select to authenticated using (
  public.intelligence_is_admin(organization_id)
  or exists (select 1 from public.intelligence_organizational_readings r where r.organization_id=public.intelligence_organizational_reading_hypotheses.organization_id and r.id=public.intelligence_organizational_reading_hypotheses.reading_id and public.has_org_role(r.organization_id,array['diretoria']) and r.scope_type in ('team','area','unit','process','organization'))
);
create policy organizational_reading_hypotheses_insert_admin on public.intelligence_organizational_reading_hypotheses for insert to authenticated with check (public.intelligence_is_admin(organization_id));
create policy organizational_reading_hypotheses_delete_admin on public.intelligence_organizational_reading_hypotheses for delete to authenticated using (public.intelligence_is_admin(organization_id));
create policy organizational_reading_revisions_select_role on public.intelligence_organizational_reading_revisions for select to authenticated using (
  public.intelligence_is_admin(organization_id)
  or exists (select 1 from public.intelligence_organizational_readings r where r.organization_id=public.intelligence_organizational_reading_revisions.organization_id and r.id=public.intelligence_organizational_reading_revisions.reading_id and public.has_org_role(r.organization_id,array['diretoria']) and r.scope_type in ('team','area','unit','process','organization'))
);
revoke update,delete on public.intelligence_organizational_readings from authenticated;
revoke insert,update,delete on public.intelligence_organizational_reading_revisions from authenticated;
grant select,insert on public.intelligence_organizational_readings to authenticated;
grant select,insert,delete on public.intelligence_organizational_reading_sources to authenticated;
grant select,insert,delete on public.intelligence_organizational_reading_hypotheses to authenticated;
grant select on public.intelligence_organizational_reading_revisions to authenticated;

-- Event contracts are controlled-service inputs; no trigger emits them.
insert into public.organizational_event_types(event_type,description,implemented) values
 ('organizational_reading_created','An Organizational Reading was created.',true),
 ('organizational_reading_updated','An Organizational Reading was revised through a controlled path.',true),
 ('organizational_reading_supported','An Organizational Reading was marked supported by human review.',true),
 ('organizational_reading_dismissed','An Organizational Reading was dismissed by human review.',true)
on conflict (event_type) do nothing;

create or replace function public.organizational_reading_snapshot(p_reading public.intelligence_organizational_readings)
returns jsonb language sql stable as $$
 select jsonb_build_object('reading_type',p_reading.reading_type,'scope_type',p_reading.scope_type,'scope_ref',p_reading.scope_ref,'title',p_reading.title,'description',p_reading.description,'status',p_reading.status,'knowledge_kind',p_reading.knowledge_kind,'observation_window_start',p_reading.observation_window_start,'observation_window_end',p_reading.observation_window_end,'detected_at',p_reading.detected_at,'source_summary',p_reading.source_summary,'context',p_reading.context);
$$;
create or replace function public._append_organizational_reading_revision(p_organization_id uuid,p_reading_id uuid,p_previous_snapshot jsonb,p_new_snapshot jsonb,p_change_reason text)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare next_revision integer;
begin
 if p_change_reason is null or btrim(p_change_reason)='' then raise exception 'reading revision requires a change reason'; end if;
 select coalesce(max(revision_number),0)+1 into next_revision from public.intelligence_organizational_reading_revisions where organization_id=p_organization_id and reading_id=p_reading_id;
 insert into public.intelligence_organizational_reading_revisions(organization_id,reading_id,revision_number,changed_by_user_id,change_reason,previous_snapshot,new_snapshot) values(p_organization_id,p_reading_id,next_revision,auth.uid(),p_change_reason,p_previous_snapshot,p_new_snapshot);
 return next_revision;
end;
$$;

create or replace function public.revise_organizational_reading(p_reading_id uuid,p_new_snapshot jsonb,p_change_reason text)
returns public.intelligence_organizational_readings language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.intelligence_organizational_readings%rowtype; n public.intelligence_organizational_readings%rowtype; k text;
begin
 if auth.uid() is null then raise exception 'reading revision requires an authenticated actor'; end if;
 if jsonb_typeof(p_new_snapshot)<>'object' then raise exception 'reading revision snapshot must be a JSON object'; end if;
 foreach k in array array['reading_type','scope_type','scope_ref','title','description','status','knowledge_kind','observation_window_start','observation_window_end','detected_at','source_summary','context'] loop
  if not (p_new_snapshot ? k) then raise exception 'reading revision snapshot is missing %',k; end if;
 end loop;
 select * into r from public.intelligence_organizational_readings where id=p_reading_id for update;
 if not found then raise exception 'organizational reading not found'; end if;
 if not public.is_org_member(r.organization_id) or not public.intelligence_is_admin(r.organization_id) then raise exception 'actor is not authorized to revise this organizational reading'; end if;
 if r.status not in ('open','under_investigation') then raise exception 'reading content can only be revised while open or under_investigation'; end if;
 if jsonb_typeof(p_new_snapshot->'context')<>'object' then raise exception 'reading context must be a JSON object'; end if;
 n:=r; n.reading_type:=p_new_snapshot->>'reading_type'; n.scope_type:=p_new_snapshot->>'scope_type'; n.scope_ref:=p_new_snapshot->>'scope_ref'; n.title:=p_new_snapshot->>'title'; n.description:=p_new_snapshot->>'description'; n.status:=p_new_snapshot->>'status'; n.knowledge_kind:=p_new_snapshot->>'knowledge_kind'; n.observation_window_start:=(p_new_snapshot->>'observation_window_start')::timestamptz; n.observation_window_end:=(p_new_snapshot->>'observation_window_end')::timestamptz; n.detected_at:=(p_new_snapshot->>'detected_at')::timestamptz; n.source_summary:=p_new_snapshot->>'source_summary'; n.context:=p_new_snapshot->'context';
 perform public._append_organizational_reading_revision(r.organization_id,r.id,public.organizational_reading_snapshot(r),public.organizational_reading_snapshot(n),p_change_reason);
 update public.intelligence_organizational_readings set reading_type=n.reading_type,scope_type=n.scope_type,scope_ref=n.scope_ref,title=n.title,description=n.description,status=n.status,knowledge_kind=n.knowledge_kind,observation_window_start=n.observation_window_start,observation_window_end=n.observation_window_end,detected_at=n.detected_at,source_summary=n.source_summary,context=n.context,updated_at=now() where id=r.id;
 select * into r from public.intelligence_organizational_readings where id=p_reading_id; return r;
end;
$$;
revoke execute on function public.organizational_reading_snapshot(public.intelligence_organizational_readings) from public,authenticated;
revoke execute on function public._append_organizational_reading_revision(uuid,uuid,jsonb,jsonb,text) from public,authenticated;
grant execute on function public.revise_organizational_reading(uuid,jsonb,text) to authenticated;

comment on table public.intelligence_organizational_readings is 'Leitura Organizacional V1: interpretação estruturada de dados/contexto, not an automatically confirmed fact or diagnosis. No generation algorithm or downstream automation.';
comment on column public.intelligence_organizational_readings.scope_ref is 'Descriptive business reference only; never an authorization mechanism.';
comment on column public.intelligence_organizational_readings.knowledge_kind is 'V1 is always interpreted. It is not fact, declared, observed or confirmed cause.';
comment on table public.intelligence_organizational_reading_sources is 'Tenant-safe provenance links to existing evidence, knowledge, event and memory records; does not duplicate the Evidence Engine.';
comment on table public.intelligence_organizational_reading_hypotheses is 'A possible explanation for a Reading, never an automatically confirmed cause.';
comment on table public.intelligence_organizational_reading_revisions is 'Append-only history for controlled Organizational Reading edits.';
-- ==================================================
-- MIGRATION: 20260901233000_organizational_reading_sources_hardening.sql
-- ==================================================
-- youB — Organizational Reading Engine V1 source uniqueness hardening
-- Additive only. Keeps intelligence_reading_sources_exact_source_check intact.
-- Partial unique indexes enforce logical source identity despite unused NULL columns.
create unique index if not exists intelligence_reading_sources_evidence_unique
  on public.intelligence_organizational_reading_sources(organization_id, reading_id, evidence_id)
  where source_type = 'evidence' and evidence_id is not null;
create unique index if not exists intelligence_reading_sources_knowledge_source_unique
  on public.intelligence_organizational_reading_sources(organization_id, reading_id, knowledge_source_id)
  where source_type = 'knowledge_source' and knowledge_source_id is not null;
create unique index if not exists intelligence_reading_sources_knowledge_document_unique
  on public.intelligence_organizational_reading_sources(organization_id, reading_id, knowledge_document_id)
  where source_type = 'knowledge_document' and knowledge_document_id is not null;
create unique index if not exists intelligence_reading_sources_event_unique
  on public.intelligence_organizational_reading_sources(organization_id, reading_id, organizational_event_id)
  where source_type = 'organizational_event' and organizational_event_id is not null;
create unique index if not exists intelligence_reading_sources_memory_relation_unique
  on public.intelligence_organizational_reading_sources(organization_id, reading_id, memory_relation_id)
  where source_type = 'memory_relation' and memory_relation_id is not null;

comment on index public.intelligence_reading_sources_evidence_unique is 'Logical tenant-safe evidence source uniqueness per Organizational Reading.';
comment on index public.intelligence_reading_sources_knowledge_source_unique is 'Logical tenant-safe knowledge source uniqueness per Organizational Reading.';
comment on index public.intelligence_reading_sources_knowledge_document_unique is 'Logical tenant-safe knowledge document uniqueness per Organizational Reading.';
comment on index public.intelligence_reading_sources_event_unique is 'Logical tenant-safe organizational event uniqueness per Organizational Reading.';
comment on index public.intelligence_reading_sources_memory_relation_unique is 'Logical tenant-safe memory relation uniqueness per Organizational Reading.';
-- ==================================================
-- MIGRATION: 20260901240000_evidence_recommendation_operational_v1.sql
-- ==================================================
-- youB — Evidence + Recommendation Operational V1
-- Manual/controlled provenance foundation. No causal inference, scoring, LLM or automation.
insert into public.organizational_memory_entity_types(entity_type,description) values ('evidence_assessment','A structured evaluation of evidence sufficiency and limitations.') on conflict (entity_type) do nothing;

create table if not exists public.intelligence_evidence_assessments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 reading_id uuid not null, hypothesis_id uuid, status text not null default 'under_investigation' check(status in('draft','under_investigation','assessed','archived')),
 evidence_state text not null check(evidence_state in('insufficient','weak','moderate','strong','conflicting')),
 supporting_evidence_count integer not null default 0 check(supporting_evidence_count>=0), contradicting_evidence_count integer not null default 0 check(contradicting_evidence_count>=0),
 unknowns jsonb not null default '[]'::jsonb check(jsonb_typeof(unknowns)='array'), limitations jsonb not null default '[]'::jsonb check(jsonb_typeof(limitations)='array'), assessment_summary text not null check(btrim(assessment_summary)<>''),
 assessed_by_user_id uuid references auth.users(id) on delete set null, assessed_at timestamptz, context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint intelligence_evidence_assessments_organization_id_id_key unique(organization_id,id),
 constraint evidence_assessments_reading_same_org_fkey foreign key(organization_id,reading_id) references public.intelligence_organizational_readings(organization_id,id),
 constraint evidence_assessments_hypothesis_same_org_fkey foreign key(organization_id,hypothesis_id) references public.intelligence_organizational_reading_hypotheses(organization_id,id),
 constraint evidence_assessments_assessed_pair_check check((assessed_by_user_id is null)=(assessed_at is null)),
 constraint evidence_assessments_assessed_status_check check(status<>'assessed' or(assessed_by_user_id is not null and assessed_at is not null))
);
create table if not exists public.intelligence_evidence_assessment_evidence (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, assessment_id uuid not null, evidence_id uuid not null,
 evidence_relation text not null check(evidence_relation in('supports','contradicts')), provenance_note text, context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(),
 constraint evidence_assessment_evidence_unique unique(organization_id,assessment_id,evidence_id,evidence_relation),
 constraint evidence_assessment_evidence_assessment_same_org_fkey foreign key(organization_id,assessment_id) references public.intelligence_evidence_assessments(organization_id,id) on delete cascade,
 constraint evidence_assessment_evidence_evidence_same_org_fkey foreign key(organization_id,evidence_id) references public.intelligence_evidence(organization_id,id)
);
create table if not exists public.intelligence_evidence_assessment_revisions (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, assessment_id uuid not null, revision_number integer not null check(revision_number>0), changed_by_user_id uuid not null references auth.users(id) on delete restrict, change_reason text not null check(btrim(change_reason)<>''), previous_snapshot jsonb not null check(jsonb_typeof(previous_snapshot)='object'), new_snapshot jsonb not null check(jsonb_typeof(new_snapshot)='object'), created_at timestamptz not null default now(),
 constraint evidence_assessment_revisions_unique unique(organization_id,assessment_id,revision_number), constraint evidence_assessment_revisions_assessment_same_org_fkey foreign key(organization_id,assessment_id) references public.intelligence_evidence_assessments(organization_id,id) on delete cascade
);

create table if not exists public.intelligence_recommendation_readings (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, recommendation_id uuid not null, reading_id uuid not null, relationship_type text not null default 'motivated_by' check(relationship_type='motivated_by'), context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(), constraint recommendation_readings_unique unique(organization_id,recommendation_id,reading_id), constraint recommendation_readings_recommendation_same_org_fkey foreign key(organization_id,recommendation_id) references public.intelligence_recommendations(organization_id,id) on delete cascade, constraint recommendation_readings_reading_same_org_fkey foreign key(organization_id,reading_id) references public.intelligence_organizational_readings(organization_id,id) on delete restrict
);
create table if not exists public.intelligence_recommendation_assessments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, recommendation_id uuid not null, assessment_id uuid not null, relationship_type text not null default 'based_on' check(relationship_type='based_on'), context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(), constraint recommendation_assessments_unique unique(organization_id,recommendation_id,assessment_id), constraint recommendation_assessments_recommendation_same_org_fkey foreign key(organization_id,recommendation_id) references public.intelligence_recommendations(organization_id,id) on delete cascade, constraint recommendation_assessments_assessment_same_org_fkey foreign key(organization_id,assessment_id) references public.intelligence_evidence_assessments(organization_id,id) on delete restrict
);
create table if not exists public.intelligence_recommendation_hypotheses (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, recommendation_id uuid not null, hypothesis_id uuid not null, relationship_type text not null default 'considers' check(relationship_type='considers'), context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(), constraint recommendation_hypotheses_unique unique(organization_id,recommendation_id,hypothesis_id), constraint recommendation_hypotheses_recommendation_same_org_fkey foreign key(organization_id,recommendation_id) references public.intelligence_recommendations(organization_id,id) on delete cascade, constraint recommendation_hypotheses_hypothesis_same_org_fkey foreign key(organization_id,hypothesis_id) references public.intelligence_organizational_reading_hypotheses(organization_id,id) on delete restrict
);
create table if not exists public.intelligence_recommendation_evidence (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, recommendation_id uuid not null, evidence_id uuid not null, evidence_relation text not null check(evidence_relation in('supports','contradicts')), context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(), constraint recommendation_evidence_operational_unique unique(organization_id,recommendation_id,evidence_id,evidence_relation), constraint recommendation_evidence_operational_recommendation_same_org_fkey foreign key(organization_id,recommendation_id) references public.intelligence_recommendations(organization_id,id) on delete cascade, constraint recommendation_evidence_operational_evidence_same_org_fkey foreign key(organization_id,evidence_id) references public.intelligence_evidence(organization_id,id) on delete restrict
);
create table if not exists public.intelligence_recommendation_revisions (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, recommendation_id uuid not null, revision_number integer not null check(revision_number>0), changed_by_user_id uuid not null references auth.users(id) on delete restrict, change_reason text not null check(btrim(change_reason)<>''), previous_snapshot jsonb not null check(jsonb_typeof(previous_snapshot)='object'), new_snapshot jsonb not null check(jsonb_typeof(new_snapshot)='object'), created_at timestamptz not null default now(), constraint recommendation_revisions_unique unique(organization_id,recommendation_id,revision_number), constraint recommendation_revisions_recommendation_same_org_fkey foreign key(organization_id,recommendation_id) references public.intelligence_recommendations(organization_id,id) on delete cascade
);

alter table public.intelligence_recommendation_evidence add column if not exists evidence_relation text not null default 'supports';
alter table public.intelligence_recommendation_evidence add column if not exists context jsonb not null default '{}'::jsonb;
alter table public.intelligence_recommendation_evidence drop constraint if exists recommendation_evidence_operational_relation_check;
alter table public.intelligence_recommendation_evidence add constraint recommendation_evidence_operational_relation_check check(evidence_relation in('supports','contradicts'));
alter table public.intelligence_recommendation_evidence add constraint recommendation_evidence_operational_context_check check(jsonb_typeof(context)='object');

alter table public.intelligence_recommendations drop constraint if exists intelligence_recommendations_evidence_sufficiency_check;
alter table public.intelligence_recommendations add constraint intelligence_recommendations_evidence_sufficiency_check check(status not in('proposed','accepted') or evidence_state is distinct from 'insufficient');
create index if not exists idx_evidence_assessments_org_reading on public.intelligence_evidence_assessments(organization_id,reading_id,created_at desc);
create index if not exists idx_assessment_evidence_org_assessment on public.intelligence_evidence_assessment_evidence(organization_id,assessment_id);
create index if not exists idx_rec_readings_org_recommendation on public.intelligence_recommendation_readings(organization_id,recommendation_id);
create index if not exists idx_rec_assessments_org_recommendation on public.intelligence_recommendation_assessments(organization_id,recommendation_id);
create index if not exists idx_rec_revisions_org_recommendation on public.intelligence_recommendation_revisions(organization_id,recommendation_id,revision_number desc);

alter table public.intelligence_evidence_assessments enable row level security; alter table public.intelligence_evidence_assessment_evidence enable row level security; alter table public.intelligence_evidence_assessment_revisions enable row level security;
alter table public.intelligence_recommendation_readings enable row level security; alter table public.intelligence_recommendation_assessments enable row level security; alter table public.intelligence_recommendation_hypotheses enable row level security; alter table public.intelligence_recommendation_evidence enable row level security; alter table public.intelligence_recommendation_revisions enable row level security;
create policy evidence_assessments_select_role on public.intelligence_evidence_assessments for select to authenticated using(public.intelligence_is_admin(organization_id) or exists(select 1 from public.intelligence_organizational_readings r where r.organization_id=intelligence_evidence_assessments.organization_id and r.id=intelligence_evidence_assessments.reading_id and public.has_org_role(r.organization_id,array['diretoria']) and r.scope_type in('team','area','unit','process','organization')));
create policy evidence_assessments_insert_admin on public.intelligence_evidence_assessments for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy assessment_evidence_select_role on public.intelligence_evidence_assessment_evidence for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy assessment_evidence_insert_admin on public.intelligence_evidence_assessment_evidence for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy assessment_evidence_delete_admin on public.intelligence_evidence_assessment_evidence for delete to authenticated using(public.intelligence_is_admin(organization_id));
create policy assessment_revisions_select_role on public.intelligence_evidence_assessment_revisions for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy operational_rec_links_select_role on public.intelligence_recommendation_readings for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy operational_rec_links_assessment_select_role on public.intelligence_recommendation_assessments for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy operational_rec_links_hypothesis_select_role on public.intelligence_recommendation_hypotheses for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy operational_rec_links_evidence_select_role on public.intelligence_recommendation_evidence for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy operational_rec_links_readings_insert_admin on public.intelligence_recommendation_readings for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_assessments_insert_admin on public.intelligence_recommendation_assessments for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_hypotheses_insert_admin on public.intelligence_recommendation_hypotheses for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_evidence_insert_admin on public.intelligence_recommendation_evidence for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_readings_delete_admin on public.intelligence_recommendation_readings for delete to authenticated using(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_assessments_delete_admin on public.intelligence_recommendation_assessments for delete to authenticated using(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_hypotheses_delete_admin on public.intelligence_recommendation_hypotheses for delete to authenticated using(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_evidence_delete_admin on public.intelligence_recommendation_evidence for delete to authenticated using(public.intelligence_is_admin(organization_id));
create policy recommendation_revisions_select_role on public.intelligence_recommendation_revisions for select to authenticated using(public.intelligence_is_decision_maker(organization_id));

grant select,insert on public.intelligence_evidence_assessments to authenticated;
grant select,insert,delete on public.intelligence_evidence_assessment_evidence to authenticated;
grant select on public.intelligence_evidence_assessment_revisions to authenticated;
grant select,insert,delete on public.intelligence_recommendation_readings,public.intelligence_recommendation_assessments,public.intelligence_recommendation_hypotheses,public.intelligence_recommendation_evidence to authenticated;
revoke update,delete on public.intelligence_evidence_assessments from authenticated; revoke insert,update,delete on public.intelligence_evidence_assessment_revisions from authenticated;
revoke update,delete on public.intelligence_recommendations from authenticated; revoke delete on public.intelligence_recommendations from authenticated; drop policy if exists intelligence_recommendations_update_role on public.intelligence_recommendations; drop policy if exists intelligence_recommendations_delete_role on public.intelligence_recommendations;
revoke insert,update,delete on public.intelligence_recommendation_revisions from authenticated; grant select on public.intelligence_evidence_assessment_revisions,public.intelligence_recommendation_revisions to authenticated;

insert into public.organizational_event_types(event_type,description,implemented) values
 ('evidence_assessment_created','An Evidence Assessment was created.',true),('evidence_assessment_updated','An Evidence Assessment was revised through a controlled path.',true),('recommendation_prepared','A Recommendation was prepared from an explicit evidence assessment.',true),('recommendation_evidence_updated','Recommendation evidence provenance was updated.',true) on conflict(event_type) do nothing;

create or replace function public._evidence_assessment_snapshot(a public.intelligence_evidence_assessments) returns jsonb language sql stable as $$ select jsonb_build_object('reading_id',a.reading_id,'hypothesis_id',a.hypothesis_id,'status',a.status,'evidence_state',a.evidence_state,'supporting_evidence_count',a.supporting_evidence_count,'contradicting_evidence_count',a.contradicting_evidence_count,'unknowns',a.unknowns,'limitations',a.limitations,'assessment_summary',a.assessment_summary,'assessed_by_user_id',a.assessed_by_user_id,'assessed_at',a.assessed_at,'context',a.context); $$;
create or replace function public._recommendation_snapshot(r public.intelligence_recommendations) returns jsonb language sql stable as $$ select jsonb_build_object('title',r.title,'rationale',r.rationale,'evidence_state',r.evidence_state,'unknowns',r.unknowns,'alternatives',r.alternatives,'do_not_recommend',r.do_not_recommend,'measurement_plan',r.measurement_plan,'approval_required',r.approval_required,'owner_employee_id',r.owner_employee_id,'scope_type',r.scope_type,'scope_ref',r.scope_ref,'status',r.status,'context',r.context); $$;
create or replace function public._append_evidence_assessment_revision(o uuid,a uuid,p jsonb,n jsonb,reason text) returns integer language plpgsql security definer set search_path=public,pg_temp as $$ declare v integer; begin if reason is null or btrim(reason)='' then raise exception 'assessment revision requires a reason'; end if; select coalesce(max(revision_number),0)+1 into v from public.intelligence_evidence_assessment_revisions where organization_id=o and assessment_id=a; insert into public.intelligence_evidence_assessment_revisions(organization_id,assessment_id,revision_number,changed_by_user_id,change_reason,previous_snapshot,new_snapshot) values(o,a,v,auth.uid(),reason,p,n); return v; end; $$;
create or replace function public._append_recommendation_revision(o uuid,r uuid,p jsonb,n jsonb,reason text) returns integer language plpgsql security definer set search_path=public,pg_temp as $$ declare v integer; begin if reason is null or btrim(reason)='' then raise exception 'recommendation revision requires a reason'; end if; select coalesce(max(revision_number),0)+1 into v from public.intelligence_recommendation_revisions where organization_id=o and recommendation_id=r; insert into public.intelligence_recommendation_revisions(organization_id,recommendation_id,revision_number,changed_by_user_id,change_reason,previous_snapshot,new_snapshot) values(o,r,v,auth.uid(),reason,p,n); return v; end; $$;

create or replace function public.revise_intelligence_evidence_assessment(
 p_assessment_id uuid,
 p_new_snapshot jsonb,
 p_reason text
) returns public.intelligence_evidence_assessments
language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_assessment public.intelligence_evidence_assessments%rowtype;
 v_next public.intelligence_evidence_assessments%rowtype;
 v_key text;
begin
 if auth.uid() is null or jsonb_typeof(p_new_snapshot)<>'object' then raise exception 'invalid assessment revision request'; end if;
 if p_new_snapshot ? 'assessed_by_user_id' or p_new_snapshot ? 'assessed_at' then raise exception 'assessment authorship and timestamp are server-controlled'; end if;
 foreach v_key in array array['status','evidence_state','supporting_evidence_count','contradicting_evidence_count','unknowns','limitations','assessment_summary','context'] loop
  if not(p_new_snapshot ? v_key) then raise exception 'assessment revision snapshot is missing %',v_key; end if;
 end loop;
 select ea.* into strict v_assessment from public.intelligence_evidence_assessments as ea where ea.id=p_assessment_id for update;
 if not public.is_org_member(v_assessment.organization_id) or not public.intelligence_is_admin(v_assessment.organization_id) then raise exception 'actor is not authorized to revise assessment'; end if;
 if v_assessment.status not in('draft','under_investigation') then raise exception 'assessed assessment is immutable; create a new assessment for a later analysis'; end if;
 if p_new_snapshot->>'status' not in('draft','under_investigation','assessed') then raise exception 'assessment revision status must be draft, under_investigation or assessed'; end if;
 if jsonb_typeof(p_new_snapshot->'unknowns')<>'array' or jsonb_typeof(p_new_snapshot->'limitations')<>'array' or jsonb_typeof(p_new_snapshot->'context')<>'object' then raise exception 'assessment JSON shapes are invalid'; end if;
 v_next:=v_assessment;
 v_next.status:=p_new_snapshot->>'status'; v_next.evidence_state:=p_new_snapshot->>'evidence_state'; v_next.supporting_evidence_count:=(p_new_snapshot->>'supporting_evidence_count')::integer; v_next.contradicting_evidence_count:=(p_new_snapshot->>'contradicting_evidence_count')::integer; v_next.unknowns:=p_new_snapshot->'unknowns'; v_next.limitations:=p_new_snapshot->'limitations'; v_next.assessment_summary:=p_new_snapshot->>'assessment_summary'; v_next.context:=p_new_snapshot->'context';
 if v_next.status='assessed' then v_next.assessed_by_user_id:=auth.uid(); v_next.assessed_at:=now(); else v_next.assessed_by_user_id:=null; v_next.assessed_at:=null; end if;
 perform public._append_evidence_assessment_revision(v_assessment.organization_id,v_assessment.id,public._evidence_assessment_snapshot(v_assessment),public._evidence_assessment_snapshot(v_next),p_reason);
 update public.intelligence_evidence_assessments as ea set status=v_next.status,evidence_state=v_next.evidence_state,supporting_evidence_count=v_next.supporting_evidence_count,contradicting_evidence_count=v_next.contradicting_evidence_count,unknowns=v_next.unknowns,limitations=v_next.limitations,assessment_summary=v_next.assessment_summary,assessed_by_user_id=v_next.assessed_by_user_id,assessed_at=v_next.assessed_at,context=v_next.context,updated_at=now() where ea.id=p_assessment_id;
 select ea.* into strict v_assessment from public.intelligence_evidence_assessments as ea where ea.id=p_assessment_id;
 return v_assessment;
end; $$;
create or replace function public.revise_intelligence_recommendation(
 p_recommendation_id uuid,
 p_new_snapshot jsonb,
 p_reason text
) returns public.intelligence_recommendations
language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_recommendation public.intelligence_recommendations%rowtype;
 v_next public.intelligence_recommendations%rowtype;
 v_key text;
begin
 if auth.uid() is null or jsonb_typeof(p_new_snapshot)<>'object' then raise exception 'invalid recommendation revision request'; end if;
 foreach v_key in array array['title','rationale','evidence_state','unknowns','alternatives','do_not_recommend','measurement_plan','approval_required','scope_type','scope_ref','status','context'] loop
  if not(p_new_snapshot ? v_key) then raise exception 'recommendation revision snapshot is missing %',v_key; end if;
 end loop;
 select rec.* into strict v_recommendation from public.intelligence_recommendations as rec where rec.id=p_recommendation_id for update;
 if not public.is_org_member(v_recommendation.organization_id) or not public.intelligence_is_admin(v_recommendation.organization_id) then raise exception 'actor is not authorized to revise recommendation'; end if;
 if v_recommendation.status not in('draft','proposed') then raise exception 'recommendation can only be revised while draft or proposed'; end if;
 if jsonb_typeof(p_new_snapshot->'unknowns')<>'array' or jsonb_typeof(p_new_snapshot->'alternatives')<>'array' or jsonb_typeof(p_new_snapshot->'do_not_recommend')<>'array' or jsonb_typeof(p_new_snapshot->'measurement_plan')<>'object' or jsonb_typeof(p_new_snapshot->'context')<>'object' or jsonb_typeof(p_new_snapshot->'approval_required')<>'boolean' then raise exception 'recommendation JSON shapes are invalid'; end if;
 v_next:=v_recommendation;
 v_next.title:=p_new_snapshot->>'title'; v_next.rationale:=p_new_snapshot->>'rationale'; v_next.evidence_state:=p_new_snapshot->>'evidence_state'; v_next.unknowns:=p_new_snapshot->'unknowns'; v_next.alternatives:=p_new_snapshot->'alternatives'; v_next.do_not_recommend:=p_new_snapshot->'do_not_recommend'; v_next.measurement_plan:=p_new_snapshot->'measurement_plan'; v_next.approval_required:=(p_new_snapshot->>'approval_required')::boolean; v_next.scope_type:=p_new_snapshot->>'scope_type'; v_next.scope_ref:=p_new_snapshot->>'scope_ref'; v_next.status:=p_new_snapshot->>'status'; v_next.context:=p_new_snapshot->'context';
 perform public._append_recommendation_revision(v_recommendation.organization_id,v_recommendation.id,public._recommendation_snapshot(v_recommendation),public._recommendation_snapshot(v_next),p_reason);
 update public.intelligence_recommendations as rec set title=v_next.title,rationale=v_next.rationale,evidence_state=v_next.evidence_state,unknowns=v_next.unknowns,alternatives=v_next.alternatives,do_not_recommend=v_next.do_not_recommend,measurement_plan=v_next.measurement_plan,approval_required=v_next.approval_required,scope_type=v_next.scope_type,scope_ref=v_next.scope_ref,status=v_next.status,context=v_next.context,updated_at=now() where rec.id=p_recommendation_id;
 select rec.* into strict v_recommendation from public.intelligence_recommendations as rec where rec.id=p_recommendation_id;
 return v_recommendation;
end; $$;
revoke execute on function public._evidence_assessment_snapshot(public.intelligence_evidence_assessments),public._recommendation_snapshot(public.intelligence_recommendations),public._append_evidence_assessment_revision(uuid,uuid,jsonb,jsonb,text),public._append_recommendation_revision(uuid,uuid,jsonb,jsonb,text) from public,authenticated;
grant execute on function public.revise_intelligence_evidence_assessment(uuid,jsonb,text),public.revise_intelligence_recommendation(uuid,jsonb,text) to authenticated;
comment on table public.intelligence_evidence_assessments is 'Evidence sufficiency assessment; counts are summaries and normalized evidence links are authoritative, not probability of cause.';
comment on table public.intelligence_recommendation_evidence is 'Legacy composed identity is organization_id + recommendation_id + evidence_id; one evidence cannot be both supports and contradicts for the same Recommendation. evidence_relation and context are additive provenance fields; no synthetic id is used.';
comment on column public.intelligence_evidence_assessments.evidence_state is 'insufficient, weak, moderate, strong or conflicting; none is a causal probability.';
comment on table public.intelligence_recommendation_evidence is 'Explicit supporting/contradicting evidence provenance for a Recommendation.';
-- ==================================================
-- MIGRATION: 20260902000000_classic_dho_access_people_wiring_v1.sql
-- ==================================================
-- youB — Classic DHO Access + People Wiring V1
-- Hardening additive: preserve data, replace broad classic policies with
-- tenant-, role- and population-aware policies. Do not apply automatically.

create or replace function public.classic_is_org_admin(target_org uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select public.has_org_role(target_org, array['admin_youb','rh']);
$$;

create or replace function public.classic_has_single_own_employee(target_org uuid, target_employee uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select count(*) = 1 and (array_agg(e.id))[1] = target_employee
  from public.employees e
  where e.organization_id = target_org
    and e.auth_user_id = auth.uid();
$$;

create or replace function public.classic_manager_employee_id(target_org uuid)
returns uuid
language sql stable security definer
set search_path = public, pg_temp
as $$
  select case when count(*) = 1 then (array_agg(e.id))[1] else null end
  from public.employees e
  where e.organization_id = target_org
    and e.auth_user_id = auth.uid()
    and e.status = 'active';
$$;

create or replace function public.classic_is_direct_report(target_org uuid, target_employee uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.employees e
    where e.organization_id = target_org
      and e.id = target_employee
      and e.status = 'active'
      and e.manager_employee_id = public.classic_manager_employee_id(target_org)
      and public.classic_manager_employee_id(target_org) is not null
  );
$$;

create or replace function public.classic_can_read_employee(target_org uuid, target_employee uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select
    public.has_org_role(target_org, array['admin_youb','rh','diretoria'])
    or (public.has_org_role(target_org, array['gestor']) and (
      public.classic_is_direct_report(target_org, target_employee)
      or public.classic_has_single_own_employee(target_org, target_employee)
    ))
    or (public.has_org_role(target_org, array['colaborador']) and public.classic_has_single_own_employee(target_org, target_employee));
$$;

create or replace function public.classic_can_read_sensitive_employee(target_org uuid, target_employee uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select
    public.has_org_role(target_org, array['admin_youb','rh'])
    or (public.has_org_role(target_org, array['gestor']) and public.classic_is_direct_report(target_org, target_employee))
    or (public.has_org_role(target_org, array['colaborador']) and public.classic_has_single_own_employee(target_org, target_employee));
$$;

create or replace function public.classic_can_write_employee(target_org uuid, target_employee uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select
    public.has_org_role(target_org, array['admin_youb','rh'])
    or (public.has_org_role(target_org, array['gestor']) and public.classic_is_direct_report(target_org, target_employee));
$$;

revoke all on function public.classic_is_org_admin(uuid), public.classic_has_single_own_employee(uuid, uuid), public.classic_manager_employee_id(uuid), public.classic_is_direct_report(uuid, uuid), public.classic_can_read_employee(uuid, uuid), public.classic_can_read_sensitive_employee(uuid, uuid), public.classic_can_write_employee(uuid, uuid) from public;
grant execute on function public.classic_is_org_admin(uuid), public.classic_has_single_own_employee(uuid, uuid), public.classic_manager_employee_id(uuid), public.classic_is_direct_report(uuid, uuid), public.classic_can_read_employee(uuid, uuid), public.classic_can_read_sensitive_employee(uuid, uuid), public.classic_can_write_employee(uuid, uuid) to authenticated;

-- Preflight is deliberately before every new constraint. Legacy data is never
-- corrected or nulled silently; an incompatible database must stop here with a
-- diagnostic that names the failing category and row count.
do $$
declare
  v_cross_tenant bigint;
  v_missing_manager bigint;
  v_self_manager bigint;
  v_legacy_incompatible bigint;
  v_duplicate_keys bigint;
begin
  select count(*) into v_cross_tenant
  from public.employees e
  where e.manager_employee_id is not null
    and exists (
      select 1 from public.employees manager
      where manager.id = e.manager_employee_id
        and manager.organization_id <> e.organization_id
    );
  if v_cross_tenant > 0 then
    raise exception 'classic_dho_access_people_wiring_v1 preflight failed: % manager references cross-tenant employees; no data was changed', v_cross_tenant using errcode = '23514';
  end if;

  select count(*) into v_missing_manager
  from public.employees e
  where e.manager_employee_id is not null
    and not exists (select 1 from public.employees manager where manager.id = e.manager_employee_id);
  if v_missing_manager > 0 then
    raise exception 'classic_dho_access_people_wiring_v1 preflight failed: % manager references point to nonexistent employees; no data was changed', v_missing_manager using errcode = '23503';
  end if;

  select count(*) into v_self_manager
  from public.employees e
  where e.manager_employee_id = e.id;
  if v_self_manager > 0 then
    raise exception 'classic_dho_access_people_wiring_v1 preflight failed: % employees self-reference as manager; no data was changed', v_self_manager using errcode = '23514';
  end if;

  select count(*) into v_legacy_incompatible
  from public.employees e
  where e.organization_id is null or e.id is null;
  if v_legacy_incompatible > 0 then
    raise exception 'classic_dho_access_people_wiring_v1 preflight failed: % employees have null organization_id/id and are incompatible with the candidate key; no data was changed', v_legacy_incompatible using errcode = '23514';
  end if;

  select count(*) into v_duplicate_keys
  from (
    select e.organization_id, e.id
    from public.employees e
    group by e.organization_id, e.id
    having count(*) > 1
  ) duplicates;
  if v_duplicate_keys > 0 then
    raise exception 'classic_dho_access_people_wiring_v1 preflight failed: % duplicate (organization_id, id) candidate keys; no data was changed', v_duplicate_keys using errcode = '23505';
  end if;
end $$;

-- PostgreSQL requires a unique candidate key matching the referenced columns
-- for a composite FK. The base schema only has employees.id as its primary key,
-- so create the exact same-tenant candidate key when it is absent. Existing
-- compatible unique constraints/indexes are detected and reused.
do $$
declare
  v_org_attnum int2;
  v_id_attnum int2;
  v_has_key boolean;
begin
  select attnum into v_org_attnum from pg_attribute
    where attrelid = 'public.employees'::regclass and attname = 'organization_id' and not attisdropped;
  select attnum into v_id_attnum from pg_attribute
    where attrelid = 'public.employees'::regclass and attname = 'id' and not attisdropped;
  if v_org_attnum is null or v_id_attnum is null then
    raise exception 'classic_dho_access_people_wiring_v1 cannot install: employees.organization_id and employees.id are required for the candidate key' using errcode = '42703';
  end if;

  select exists (
    select 1 from pg_constraint c
    where c.conrelid = 'public.employees'::regclass
      and c.contype in ('p', 'u')
      and c.conkey = array[v_org_attnum, v_id_attnum]::int2[]
  ) or exists (
    select 1 from pg_index i
    where i.indrelid = 'public.employees'::regclass
      and i.indisunique
      and i.indnkeyatts = 2
      and i.indkey::text = v_org_attnum::text || ' ' || v_id_attnum::text
  ) into v_has_key;

  if not v_has_key then
    alter table public.employees
      add constraint employees_organization_id_id_key unique (organization_id, id);
  end if;
end $$;

-- The candidate key now makes the tenant part of the manager reference. The
-- check rejects self-management independently of the FK.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'employees_manager_same_org_fkey' and conrelid = 'public.employees'::regclass) then
    alter table public.employees
      add constraint employees_manager_same_org_fkey
      foreign key (organization_id, manager_employee_id)
      references public.employees (organization_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'employees_manager_not_self_check' and conrelid = 'public.employees'::regclass) then
    alter table public.employees
      add constraint employees_manager_not_self_check
      check (manager_employee_id is null or manager_employee_id <> id);
  end if;
end $$;

create index if not exists idx_employees_org_auth_status
  on public.employees(organization_id, auth_user_id, status);
create index if not exists idx_employees_org_manager_status
  on public.employees(organization_id, manager_employee_id, status);
create index if not exists idx_assessments_org_subject
  on public.assessments(organization_id, subject_employee_id);
create index if not exists idx_feedbacks_org_target
  on public.feedbacks(organization_id, target_employee_id);
create index if not exists idx_feedbacks_org_author
  on public.feedbacks(organization_id, author_employee_id);
create index if not exists idx_pdis_org_employee
  on public.pdis(organization_id, employee_id);
create index if not exists idx_checkins_org_employee
  on public.checkins(organization_id, employee_id);

-- The prior role-permissions migration intentionally recreated a broad matrix.
-- Replace all policies for the affected classic entities atomically in this
-- migration so no previous permissive policy remains active.
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('employees','areas','positions','competencies','cycles','assessments','feedbacks','pdis','checkins','disciplinary_actions','disciplinary_action_approvals')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- Reference data is non-personal but remains tenant-bound.
create policy classic_areas_select_members on public.areas
for select to authenticated using (public.is_org_member(organization_id));
create policy classic_areas_write_admin_hr on public.areas
for all to authenticated using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));

create policy classic_positions_select_members on public.positions
for select to authenticated using (public.is_org_member(organization_id));
create policy classic_positions_write_admin_hr on public.positions
for all to authenticated using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));

create policy classic_competencies_select_members on public.competencies
for select to authenticated using (public.is_org_member(organization_id));
create policy classic_competencies_write_admin_hr on public.competencies
for all to authenticated using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));

create policy classic_cycles_select_members on public.cycles
for select to authenticated using (public.is_org_member(organization_id));
create policy classic_cycles_write_admin_hr on public.cycles
for all to authenticated using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));

create policy classic_employees_select_population on public.employees
for select to authenticated
using (public.classic_can_read_employee(organization_id, id));
create policy classic_employees_write_admin_hr on public.employees
for all to authenticated
using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));

create policy classic_assessments_select_population on public.assessments
for select to authenticated
using (public.classic_can_read_employee(organization_id, subject_employee_id));
create policy classic_assessments_insert_population on public.assessments
for insert to authenticated
with check (
  public.classic_can_write_employee(organization_id, subject_employee_id)
  and (evaluator_employee_id is null or public.classic_can_read_employee(organization_id, evaluator_employee_id))
);
create policy classic_assessments_update_admin_hr on public.assessments
for update to authenticated
using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));
create policy classic_assessments_delete_admin_hr on public.assessments
for delete to authenticated
using (public.classic_is_org_admin(organization_id));

create policy classic_feedbacks_select_population on public.feedbacks
for select to authenticated
using (
  public.classic_can_read_sensitive_employee(organization_id, target_employee_id)
  or (author_employee_id is not null and public.classic_can_read_sensitive_employee(organization_id, author_employee_id))
);
create policy classic_feedbacks_insert_population on public.feedbacks
for insert to authenticated
with check (
  public.classic_can_write_employee(organization_id, target_employee_id)
  and (
    public.classic_is_org_admin(organization_id)
    or (author_employee_id is not null and public.classic_has_single_own_employee(organization_id, author_employee_id))
  )
);
create policy classic_feedbacks_update_population on public.feedbacks
for update to authenticated
using (
  public.classic_is_org_admin(organization_id)
  or (author_employee_id is not null and public.classic_has_single_own_employee(organization_id, author_employee_id))
)
with check (
  public.classic_can_write_employee(organization_id, target_employee_id)
  and (
    public.classic_is_org_admin(organization_id)
    or (author_employee_id is not null and public.classic_has_single_own_employee(organization_id, author_employee_id))
  )
);
create policy classic_feedbacks_delete_population on public.feedbacks
for delete to authenticated
using (
  public.classic_is_org_admin(organization_id)
  or (author_employee_id is not null and public.classic_has_single_own_employee(organization_id, author_employee_id))
);

create policy classic_pdis_select_population on public.pdis
for select to authenticated
using (public.classic_can_read_sensitive_employee(organization_id, employee_id));
create policy classic_pdis_insert_population on public.pdis
for insert to authenticated
with check (
  public.classic_can_write_employee(organization_id, employee_id)
  or (public.has_org_role(organization_id, array['colaborador']) and public.classic_has_single_own_employee(organization_id, employee_id))
);
create policy classic_pdis_update_population on public.pdis
for update to authenticated
using (
  public.classic_can_write_employee(organization_id, employee_id)
  or (public.has_org_role(organization_id, array['colaborador']) and public.classic_has_single_own_employee(organization_id, employee_id))
)
with check (
  public.classic_can_write_employee(organization_id, employee_id)
  or (public.has_org_role(organization_id, array['colaborador']) and public.classic_has_single_own_employee(organization_id, employee_id))
);
create policy classic_pdis_delete_population on public.pdis
for delete to authenticated
using (
  public.classic_can_write_employee(organization_id, employee_id)
  or (public.has_org_role(organization_id, array['colaborador']) and public.classic_has_single_own_employee(organization_id, employee_id))
);

create policy classic_checkins_select_population on public.checkins
for select to authenticated
using (public.classic_can_read_sensitive_employee(organization_id, employee_id));
create policy classic_checkins_insert_population on public.checkins
for insert to authenticated
with check (public.classic_can_write_employee(organization_id, employee_id));
create policy classic_checkins_update_population on public.checkins
for update to authenticated
using (public.classic_can_write_employee(organization_id, employee_id))
with check (public.classic_can_write_employee(organization_id, employee_id));
create policy classic_checkins_delete_admin_hr on public.checkins
for delete to authenticated
using (public.classic_is_org_admin(organization_id));

-- Sensitive history follows the same direct-report rule. Approval writes are
-- left to the existing authorized approver workflow, but reads are scoped.
create policy classic_disciplinary_select_population on public.disciplinary_actions
for select to authenticated
using (public.classic_can_read_sensitive_employee(organization_id, employee_id));
create policy classic_disciplinary_insert_population on public.disciplinary_actions
for insert to authenticated
with check (public.classic_can_write_employee(organization_id, employee_id));
create policy classic_disciplinary_update_admin_hr on public.disciplinary_actions
for update to authenticated
using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));
create policy classic_disciplinary_delete_admin_hr on public.disciplinary_actions
for delete to authenticated
using (public.classic_is_org_admin(organization_id));

create policy classic_disciplinary_approvals_select_population on public.disciplinary_action_approvals
for select to authenticated
using (
  exists (
    select 1 from public.disciplinary_actions a
    where a.id = action_id
      and a.organization_id = disciplinary_action_approvals.organization_id
      and public.classic_can_read_sensitive_employee(a.organization_id, a.employee_id)
  )
);
create policy classic_disciplinary_approvals_insert_population on public.disciplinary_action_approvals
for insert to authenticated
with check (
  exists (
    select 1 from public.disciplinary_actions a
    where a.id = action_id
      and a.organization_id = disciplinary_action_approvals.organization_id
      and public.classic_can_write_employee(a.organization_id, a.employee_id)
  )
);
create policy classic_disciplinary_approvals_update_authorized on public.disciplinary_action_approvals
for update to authenticated
using (
  exists (
    select 1 from public.disciplinary_actions a
    where a.id = action_id
      and a.organization_id = disciplinary_action_approvals.organization_id
      and public.classic_can_write_employee(a.organization_id, a.employee_id)
  )
)
with check (
  exists (
    select 1 from public.disciplinary_actions a
    where a.id = action_id
      and a.organization_id = disciplinary_action_approvals.organization_id
      and public.classic_can_write_employee(a.organization_id, a.employee_id)
  )
);

grant select, insert, update, delete on
  public.employees, public.areas, public.positions, public.competencies,
  public.cycles, public.assessments, public.feedbacks, public.pdis,
  public.checkins, public.disciplinary_actions,
  public.disciplinary_action_approvals to authenticated;

comment on function public.classic_manager_employee_id(uuid) is
  'Returns one active employee for auth.uid(); multiple or zero links return NULL and therefore no manager population.';
comment on function public.classic_is_direct_report(uuid, uuid) is
  'V1 population is direct reports only through same-tenant manager_employee_id; no hierarchy inference.';
-- ==================================================
-- MIGRATION: 20260902120000_competency_cycle_assessment_v1.sql
-- ==================================================
-- youB — Competency + Cycle + Assessment V1
-- Additive implementation on top of PR #13. Do not edit historical migrations.
-- New assessments use normalized competency score rows; legacy scores JSONB is preserved.

-- Tenant-safe candidate keys are prerequisites for all composite foreign keys.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'positions_organization_id_id_key' and conrelid = 'public.positions'::regclass) then
    alter table public.positions add constraint positions_organization_id_id_key unique (organization_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'competencies_organization_id_id_key' and conrelid = 'public.competencies'::regclass) then
    alter table public.competencies add constraint competencies_organization_id_id_key unique (organization_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'cycles_organization_id_id_key' and conrelid = 'public.cycles'::regclass) then
    alter table public.cycles add constraint cycles_organization_id_id_key unique (organization_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'assessments_organization_id_id_key' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_organization_id_id_key unique (organization_id, id);
  end if;
end $$;

-- Fail closed on legacy references before installing tenant-safe foreign keys.
do $$
declare n bigint;
begin
  select count(*) into n from public.assessments a where not exists (select 1 from public.cycles c where c.id=a.cycle_id and c.organization_id=a.organization_id);
  if n > 0 then raise exception 'competency_cycle_assessment_v1 preflight: % assessments reference a cycle in another tenant or no cycle', n using errcode='23503'; end if;
  select count(*) into n from public.assessments a where not exists (select 1 from public.employees e where e.id=a.subject_employee_id and e.organization_id=a.organization_id);
  if n > 0 then raise exception 'competency_cycle_assessment_v1 preflight: % assessments reference a subject in another tenant or no employee', n using errcode='23503'; end if;
  select count(*) into n from public.assessments a where a.evaluator_employee_id is not null and not exists (select 1 from public.employees e where e.id=a.evaluator_employee_id and e.organization_id=a.organization_id);
  if n > 0 then raise exception 'competency_cycle_assessment_v1 preflight: % assessments reference an evaluator in another tenant or no employee', n using errcode='23503'; end if;
end $$;

alter table public.cycles add column if not exists updated_at timestamptz not null default now();
alter table public.cycles add column if not exists activated_at timestamptz;
alter table public.cycles add column if not exists closed_at timestamptz;
alter table public.cycles add column if not exists created_by_user_id uuid references auth.users(id) on delete set null;
alter table public.cycles add constraint cycles_name_not_blank_check check (length(btrim(name)) > 0);
alter table public.cycles add constraint cycles_dates_order_check check (starts_at is null or ends_at is null or ends_at >= starts_at);

alter table public.assessments add column if not exists position_id uuid;
alter table public.assessments add column if not exists status text not null default 'draft';
alter table public.assessments add column if not exists created_by_user_id uuid references auth.users(id) on delete set null;
alter table public.assessments add column if not exists updated_at timestamptz not null default now();
alter table public.assessments add column if not exists submitted_at timestamptz;
alter table public.assessments add column if not exists completed_at timestamptz;
alter table public.assessments add column if not exists completed_by_user_id uuid references auth.users(id) on delete set null;
alter table public.assessments add constraint assessments_status_check check (status in ('draft','in_progress','submitted','completed'));
alter table public.assessments add constraint assessments_status_timestamps_check check (
  (status in ('draft','in_progress') and submitted_at is null and completed_at is null)
  or (status = 'submitted' and submitted_at is not null and completed_at is null)
  or (status = 'completed' and submitted_at is not null and completed_at is not null)
);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'assessments_cycle_same_org_fkey' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_cycle_same_org_fkey foreign key (organization_id, cycle_id) references public.cycles(organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'assessments_subject_same_org_fkey' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_subject_same_org_fkey foreign key (organization_id, subject_employee_id) references public.employees(organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'assessments_evaluator_same_org_fkey' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_evaluator_same_org_fkey foreign key (organization_id, evaluator_employee_id) references public.employees(organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'assessments_position_same_org_fkey' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_position_same_org_fkey foreign key (organization_id, position_id) references public.positions(organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'assessments_cycle_subject_unique' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_cycle_subject_unique unique (organization_id,cycle_id,subject_employee_id);
  end if;
end $$;

create table if not exists public.position_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  position_id uuid not null,
  competency_id uuid not null,
  expected_level smallint not null check (expected_level between 1 and 5),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint position_competencies_organization_id_id_key unique (organization_id,id),
  constraint position_competencies_unique_mapping unique (organization_id,position_id,competency_id),
  constraint position_competencies_position_same_org_fkey foreign key (organization_id,position_id) references public.positions(organization_id,id) on delete restrict,
  constraint position_competencies_competency_same_org_fkey foreign key (organization_id,competency_id) references public.competencies(organization_id,id) on delete restrict
);

create table if not exists public.assessment_competency_scores (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  assessment_id uuid not null,
  competency_id uuid not null,
  position_competency_id uuid not null,
  expected_level_snapshot smallint not null check (expected_level_snapshot between 1 and 5),
  score smallint check (score is null or score between 1 and 5),
  evidence_note text check (evidence_note is null or char_length(evidence_note) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint assessment_competency_scores_organization_id_id_key unique (organization_id,id),
  constraint assessment_competency_scores_unique unique (organization_id,assessment_id,competency_id),
  constraint assessment_scores_assessment_same_org_fkey foreign key (organization_id,assessment_id) references public.assessments(organization_id,id) on delete cascade,
  constraint assessment_scores_competency_same_org_fkey foreign key (organization_id,competency_id) references public.competencies(organization_id,id) on delete restrict,
  constraint assessment_scores_mapping_same_org_fkey foreign key (organization_id,position_competency_id) references public.position_competencies(organization_id,id) on delete restrict
);

create index if not exists idx_position_competencies_org_position on public.position_competencies(organization_id,position_id,active);
create index if not exists idx_position_competencies_org_competency on public.position_competencies(organization_id,competency_id);
create index if not exists idx_assessment_scores_org_assessment on public.assessment_competency_scores(organization_id,assessment_id);
create index if not exists idx_assessment_scores_org_competency on public.assessment_competency_scores(organization_id,competency_id);
create index if not exists idx_assessments_org_status on public.assessments(organization_id,status,cycle_id);

alter table public.position_competencies enable row level security;
alter table public.assessment_competency_scores enable row level security;

create or replace function public.cca_set_updated_at()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists cca_cycles_updated_at on public.cycles;
create trigger cca_cycles_updated_at before update on public.cycles for each row execute function public.cca_set_updated_at();
drop trigger if exists cca_assessments_updated_at on public.assessments;
create trigger cca_assessments_updated_at before update on public.assessments for each row execute function public.cca_set_updated_at();
drop trigger if exists cca_position_competencies_updated_at on public.position_competencies;
create trigger cca_position_competencies_updated_at before update on public.position_competencies for each row execute function public.cca_set_updated_at();
drop trigger if exists cca_assessment_scores_updated_at on public.assessment_competency_scores;
create trigger cca_assessment_scores_updated_at before update on public.assessment_competency_scores for each row execute function public.cca_set_updated_at();

-- New assessment rows capture the subject's position and never accept a client-supplied mismatch.
create or replace function public.cca_capture_assessment_position()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare p_org uuid; p_position uuid; p_status text;
begin
  select e.organization_id,e.position_id into p_org,p_position from public.employees e where e.id=new.subject_employee_id;
  if p_org is null or p_org <> new.organization_id then raise exception 'assessment subject must belong to the same tenant' using errcode='23503'; end if;
  -- Legacy fixture/data rows may remain draft and position-less for compatibility;
  -- every V1 RPC-created assessment has created_by_user_id and requires a position.
  if p_position is null and new.created_by_user_id is not null then raise exception 'assessment configuration pending: subject employee has no position' using errcode='23514'; end if;
  if new.position_id is not null and new.position_id <> p_position then raise exception 'assessment position snapshot does not match subject position' using errcode='23514'; end if;
  new.position_id := p_position;
  if new.status is null then new.status := 'draft'; end if;
  if new.status not in ('draft','in_progress','submitted','completed') then raise exception 'invalid assessment lifecycle status' using errcode='23514'; end if;
  return new;
end $$;
drop trigger if exists cca_assessment_position_snapshot on public.assessments;
create trigger cca_assessment_position_snapshot before insert on public.assessments for each row execute function public.cca_capture_assessment_position();

create or replace function public.cca_employee_has_role(target_org uuid, target_employee uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists (select 1 from public.employees e join public.memberships m on m.organization_id=e.organization_id and m.user_id=e.auth_user_id where e.organization_id=target_org and e.id=target_employee and e.status='active' and m.role=any(allowed_roles));
$$;

create or replace function public.cca_is_assessment_manager(target_org uuid, target_assessment uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists (
    select 1 from public.assessments a
    where a.organization_id=target_org and a.id=target_assessment
      and public.classic_has_single_own_employee(target_org,a.evaluator_employee_id)
      and public.classic_is_direct_report(target_org,a.subject_employee_id)
      and a.evaluator_employee_id=public.classic_manager_employee_id(target_org)
  );
$$;

create or replace function public.cca_can_manage_assessment(target_org uuid, target_assessment uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select public.classic_is_org_admin(target_org) or public.cca_is_assessment_manager(target_org,target_assessment);
$$;

-- Replace broad legacy assessment policies with lifecycle- and population-aware reads.
do $$ declare r record; begin
  for r in select policyname from pg_policies where schemaname='public' and tablename='assessments' loop execute format('drop policy if exists %I on public.assessments',r.policyname); end loop;
end $$;
create policy cca_assessments_select_scoped on public.assessments for select to authenticated using (
  public.classic_is_org_admin(organization_id)
  or public.cca_is_assessment_manager(organization_id,id)
  or (public.has_org_role(organization_id,array['colaborador']) and status='completed' and public.classic_has_single_own_employee(organization_id,subject_employee_id))
);

do $$ declare r record; begin
  for r in select policyname from pg_policies where schemaname='public' and tablename='cycles' loop execute format('drop policy if exists %I on public.cycles',r.policyname); end loop;
end $$;
create policy cca_cycles_select_members on public.cycles for select to authenticated using (public.is_org_member(organization_id));

do $$ declare r record; begin
  for r in select policyname from pg_policies where schemaname='public' and tablename='competencies' loop execute format('drop policy if exists %I on public.competencies',r.policyname); end loop;
end $$;
create policy cca_competencies_select_members on public.competencies for select to authenticated using (public.is_org_member(organization_id));

create policy cca_position_competencies_select_scoped on public.position_competencies for select to authenticated using (
  public.classic_is_org_admin(organization_id)
  or public.has_org_role(organization_id,array['diretoria'])
  or exists (select 1 from public.employees e where e.organization_id=position_competencies.organization_id and e.position_id=position_competencies.position_id and e.status='active' and public.classic_is_direct_report(position_competencies.organization_id,e.id))
  or exists (select 1 from public.assessment_competency_scores s join public.assessments a on a.organization_id=s.organization_id and a.id=s.assessment_id where s.organization_id=position_competencies.organization_id and s.position_competency_id=position_competencies.id and a.status='completed' and public.classic_has_single_own_employee(a.organization_id,a.subject_employee_id))
);

create policy cca_assessment_scores_select_scoped on public.assessment_competency_scores for select to authenticated using (
  exists (select 1 from public.assessments a where a.organization_id=assessment_competency_scores.organization_id and a.id=assessment_competency_scores.assessment_id and (
    public.classic_is_org_admin(a.organization_id) or public.cca_is_assessment_manager(a.organization_id,a.id) or (a.status='completed' and public.classic_has_single_own_employee(a.organization_id,a.subject_employee_id))
  ))
);

revoke insert,update,delete on public.cycles,public.competencies,public.assessments,public.position_competencies,public.assessment_competency_scores from authenticated;
grant select on public.cycles,public.competencies,public.assessments,public.position_competencies,public.assessment_competency_scores to authenticated;

create or replace function public.cca_create_competency(p_organization_id uuid,p_name text,p_description text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare i uuid;
begin
  if not public.classic_is_org_admin(p_organization_id) then raise exception 'only Admin/RH can create competencies in this tenant' using errcode='42501'; end if;
  insert into public.competencies(organization_id,name,description,active) values(p_organization_id,btrim(p_name),nullif(btrim(p_description),''),true) returning id into i;
  return i;
end $$;

create or replace function public.cca_update_competency(p_id uuid,p_name text,p_description text,p_active boolean)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid;
begin
  select organization_id into o from public.competencies where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'competency is outside the authorized tenant' using errcode='42501'; end if;
  update public.competencies set name=btrim(p_name),description=nullif(btrim(p_description),''),active=p_active where id=p_id;
  return true;
end $$;

create or replace function public.cca_create_position_competency(p_position_id uuid,p_competency_id uuid,p_expected_level smallint)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; i uuid;
begin
  select p.organization_id into o from public.positions p where p.id=p_position_id;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'position is outside the authorized tenant' using errcode='42501'; end if;
  if not exists(select 1 from public.competencies c where c.id=p_competency_id and c.organization_id=o and c.active) then raise exception 'competency is outside the authorized tenant or inactive' using errcode='23503'; end if;
  if p_expected_level not between 1 and 5 then raise exception 'expected_level must be between 1 and 5' using errcode='23514'; end if;
  insert into public.position_competencies(organization_id,position_id,competency_id,expected_level,active) values(o,p_position_id,p_competency_id,p_expected_level,true) returning id into i;
  return i;
exception when unique_violation then raise exception 'duplicate competency mapping for this position' using errcode='23505';
end $$;

create or replace function public.cca_update_position_competency(p_id uuid,p_expected_level smallint,p_active boolean)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid;
begin
  select organization_id into o from public.position_competencies where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'mapping is outside the authorized tenant' using errcode='42501'; end if;
  if p_expected_level not between 1 and 5 then raise exception 'expected_level must be between 1 and 5' using errcode='23514'; end if;
  update public.position_competencies set expected_level=p_expected_level,active=p_active where id=p_id;
  return true;
end $$;

create or replace function public.cca_deactivate_position_competency(p_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid;
begin
  select organization_id into o from public.position_competencies where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'mapping is outside the authorized tenant' using errcode='42501'; end if;
  update public.position_competencies set active=false where id=p_id;
  return true;
end $$;

create or replace function public.cca_create_cycle(p_organization_id uuid,p_name text,p_cycle_type text default 'performance',p_starts_at date default null,p_ends_at date default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare i uuid;
begin
  if not public.classic_is_org_admin(p_organization_id) then raise exception 'only Admin/RH can create cycles in this tenant' using errcode='42501'; end if;
  if p_starts_at is not null and p_ends_at is not null and p_ends_at < p_starts_at then raise exception 'cycle period is invalid' using errcode='23514'; end if;
  insert into public.cycles(organization_id,name,cycle_type,starts_at,ends_at,status,created_by_user_id) values(p_organization_id,btrim(p_name),coalesce(nullif(btrim(p_cycle_type),''),'performance'),p_starts_at,p_ends_at,'draft',auth.uid()) returning id into i;
  return i;
end $$;

create or replace function public.cca_update_draft_cycle(p_id uuid,p_name text,p_starts_at date,p_ends_at date)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text;
begin
  select organization_id,status into o,s from public.cycles where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'cycle is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' then raise exception 'only draft cycles are editable' using errcode='23514'; end if;
  if p_ends_at is null or p_starts_at is null or p_ends_at < p_starts_at then raise exception 'active cycle requires a valid period' using errcode='23514'; end if;
  update public.cycles set name=btrim(p_name),starts_at=p_starts_at,ends_at=p_ends_at where id=p_id;
  return true;
end $$;

create or replace function public.cca_activate_cycle(p_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; a date; e date;
begin
  select organization_id,status,starts_at,ends_at into o,s,a,e from public.cycles where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'cycle is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' then raise exception 'only draft cycles can be activated' using errcode='23514'; end if;
  if a is null or e is null or e < a then raise exception 'cycle activation requires a valid period' using errcode='23514'; end if;
  update public.cycles set status='active',activated_at=now() where id=p_id;
  return true;
end $$;

create or replace function public.cca_close_cycle(p_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text;
begin
  select organization_id,status into o,s from public.cycles where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'cycle is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'active' then raise exception 'only active cycles can be closed' using errcode='23514'; end if;
  update public.cycles set status='closed',closed_at=now() where id=p_id;
  return true;
end $$;

create or replace function public.cca_create_assessment(p_cycle_id uuid,p_subject_employee_id uuid,p_evaluator_employee_id uuid)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; cycle_status text; subject_pos uuid; manager_id uuid; i uuid; n bigint;
begin
  select c.organization_id,c.status into o,cycle_status from public.cycles c where c.id=p_cycle_id;
  if o is null or cycle_status <> 'active' then raise exception 'assessment requires an active cycle' using errcode='23514'; end if;
  select e.position_id,e.manager_employee_id into subject_pos,manager_id from public.employees e where e.id=p_subject_employee_id and e.organization_id=o and e.status='active';
  if not found then raise exception 'assessment subject is outside the authorized tenant or inactive' using errcode='42501'; end if;
  if subject_pos is null then raise exception 'assessment configuration pending: subject employee has no position' using errcode='23514'; end if;
  select count(*) into n from public.position_competencies pc where pc.organization_id=o and pc.position_id=subject_pos and pc.active;
  if n=0 then raise exception 'assessment configuration pending: position has no active competency mapping' using errcode='23514'; end if;
  if not exists(select 1 from public.employees e where e.id=p_evaluator_employee_id and e.organization_id=o and e.status='active' and e.auth_user_id is not null) then raise exception 'evaluator is outside the authorized tenant or inactive' using errcode='42501'; end if;
  if public.classic_is_org_admin(o) then
    if p_evaluator_employee_id <> manager_id and not public.cca_employee_has_role(o,p_evaluator_employee_id,array['admin_youb','rh']) then raise exception 'evaluator is not authorized for this subject' using errcode='42501'; end if;
  elsif public.classic_is_direct_report(o,p_subject_employee_id) and p_evaluator_employee_id=public.classic_manager_employee_id(o) then
    null;
  else
    raise exception 'only the authorized direct manager can create this assessment' using errcode='42501';
  end if;
  insert into public.assessments(organization_id,cycle_id,subject_employee_id,evaluator_employee_id,position_id,status,created_by_user_id)
    values(o,p_cycle_id,p_subject_employee_id,p_evaluator_employee_id,subject_pos,'draft',auth.uid()) returning id into i;
  insert into public.assessment_competency_scores(organization_id,assessment_id,competency_id,position_competency_id,expected_level_snapshot)
    select o,i,pc.competency_id,pc.id,pc.expected_level from public.position_competencies pc where pc.organization_id=o and pc.position_id=subject_pos and pc.active;
  return i;
exception when unique_violation then raise exception 'equivalent assessment already exists for this cycle and subject' using errcode='23505';
end $$;

create or replace function public.cca_save_assessment_score(p_assessment_id uuid,p_competency_id uuid,p_score smallint,p_evidence_note text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; cycle_status text;
begin
  if p_score is null or p_score not between 1 and 5 then raise exception 'score must be an integer between 1 and 5' using errcode='23514'; end if;
  select a.organization_id,a.status,c.status into o,s,cycle_status from public.assessments a join public.cycles c on c.organization_id=a.organization_id and c.id=a.cycle_id where a.id=p_assessment_id for update;
  if o is null or not public.cca_can_manage_assessment(o,p_assessment_id) then raise exception 'assessment is outside the authorized population' using errcode='42501'; end if;
  if s not in ('draft','in_progress') or cycle_status <> 'active' then raise exception 'assessment is not editable' using errcode='23514'; end if;
  update public.assessment_competency_scores set score=p_score,evidence_note=nullif(btrim(p_evidence_note),''),updated_at=now() where organization_id=o and assessment_id=p_assessment_id and competency_id=p_competency_id;
  if not found then raise exception 'competency is not part of the assessment snapshot' using errcode='23503'; end if;
  update public.assessments set status='in_progress',updated_at=now() where id=p_assessment_id;
  return true;
end $$;

create or replace function public.cca_submit_assessment(p_assessment_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; cycle_status text; total bigint; filled bigint;
begin
  select a.organization_id,a.status,c.status into o,s,cycle_status from public.assessments a join public.cycles c on c.organization_id=a.organization_id and c.id=a.cycle_id where a.id=p_assessment_id for update;
  if o is null or not public.cca_is_assessment_manager(o,p_assessment_id) then raise exception 'only the assigned evaluator can submit this assessment' using errcode='42501'; end if;
  if s not in ('draft','in_progress') or cycle_status <> 'active' then raise exception 'assessment cannot be submitted in its current state' using errcode='23514'; end if;
  select count(*),count(*) filter(where score is not null) into total,filled from public.assessment_competency_scores where organization_id=o and assessment_id=p_assessment_id;
  if total=0 or total<>filled then raise exception 'all snapped competencies must have a score before submission' using errcode='23514'; end if;
  update public.assessments set status='submitted',submitted_at=now(),updated_at=now() where id=p_assessment_id;
  return true;
end $$;

create or replace function public.cca_complete_assessment(p_assessment_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; cycle_status text;
begin
  select a.organization_id,a.status,c.status into o,s,cycle_status from public.assessments a join public.cycles c on c.organization_id=a.organization_id and c.id=a.cycle_id where a.id=p_assessment_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'only Admin/RH can complete this assessment' using errcode='42501'; end if;
  if s <> 'submitted' or cycle_status <> 'active' then raise exception 'only submitted assessments in an active cycle can be completed' using errcode='23514'; end if;
  update public.assessments set status='completed',completed_at=now(),completed_by_user_id=auth.uid(),updated_at=now() where id=p_assessment_id;
  return true;
end $$;

drop function if exists public.cca_read_assessment_aggregate(uuid);
create or replace function public.cca_read_assessment_aggregate(p_organization_id uuid,p_cycle_id uuid)
returns table(cycle_id uuid,competency_id uuid,competency_name text,position_id uuid,position_name text,assessment_count bigint,average_score numeric)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cycle_org uuid;
begin
  if auth.uid() is null or p_organization_id is null or p_cycle_id is null then
    raise exception 'aggregate authorization is required' using errcode='42501';
  end if;
  if not public.has_org_role(p_organization_id,array['admin_youb','rh','diretoria']) then
    raise exception 'aggregate is not authorized for this tenant' using errcode='42501';
  end if;
  select c.organization_id into cycle_org from public.cycles c where c.id=p_cycle_id;
  if cycle_org is null or cycle_org <> p_organization_id then
    raise exception 'cycle is outside the requested tenant' using errcode='42501';
  end if;
  return query
    select a.cycle_id,s.competency_id,c.name,a.position_id,p.name,count(distinct a.id),round(avg(s.score)::numeric,2)
    from public.assessments a
    join public.assessment_competency_scores s on s.organization_id=a.organization_id and s.assessment_id=a.id
    join public.competencies c on c.organization_id=s.organization_id and c.id=s.competency_id
    join public.positions p on p.organization_id=a.organization_id and p.id=a.position_id
    where a.organization_id=p_organization_id and a.cycle_id=p_cycle_id and a.status='completed' and s.score is not null
    group by a.cycle_id,s.competency_id,c.name,a.position_id,p.name
    having count(distinct a.id) >= 3;
end $$;

revoke all on function public.cca_set_updated_at(),public.cca_capture_assessment_position(),public.cca_employee_has_role(uuid,uuid,text[]),public.cca_is_assessment_manager(uuid,uuid),public.cca_can_manage_assessment(uuid,uuid) from public;
revoke all on function public.cca_create_competency(uuid,text,text),public.cca_update_competency(uuid,text,text,boolean),public.cca_create_position_competency(uuid,uuid,smallint),public.cca_update_position_competency(uuid,smallint,boolean),public.cca_deactivate_position_competency(uuid),public.cca_create_cycle(uuid,text,text,date,date),public.cca_update_draft_cycle(uuid,text,date,date),public.cca_activate_cycle(uuid),public.cca_close_cycle(uuid),public.cca_create_assessment(uuid,uuid,uuid),public.cca_save_assessment_score(uuid,uuid,smallint,text),public.cca_submit_assessment(uuid),public.cca_complete_assessment(uuid),public.cca_read_assessment_aggregate(uuid,uuid) from public;
grant execute on function public.cca_create_competency(uuid,text,text),public.cca_update_competency(uuid,text,text,boolean),public.cca_create_position_competency(uuid,uuid,smallint),public.cca_update_position_competency(uuid,smallint,boolean),public.cca_deactivate_position_competency(uuid),public.cca_create_cycle(uuid,text,text,date,date),public.cca_update_draft_cycle(uuid,text,date,date),public.cca_activate_cycle(uuid),public.cca_close_cycle(uuid),public.cca_create_assessment(uuid,uuid,uuid),public.cca_save_assessment_score(uuid,uuid,smallint,text),public.cca_submit_assessment(uuid),public.cca_complete_assessment(uuid),public.cca_read_assessment_aggregate(uuid,uuid) to authenticated;
grant execute on function public.cca_is_assessment_manager(uuid,uuid),public.cca_can_manage_assessment(uuid,uuid) to authenticated;

comment on column public.assessments.scores is 'Legacy compatibility JSONB only. New Competency + Cycle + Assessment V1 scores are authoritative in assessment_competency_scores.';
comment on column public.assessments.position_id is 'Position snapshot captured when the assessment starts; changes to employee position do not rewrite this assessment.';
comment on column public.assessment_competency_scores.expected_level_snapshot is 'Expected level copied from the active position mapping at assessment start; historical meaning is immutable.';
-- ==================================================
-- MIGRATION: 20260905010000_feedback_360_evolution_v1.sql
-- ==================================================
-- youB — Feedback 360 + Evolução entre Ciclos V1
-- Additive implementation on the frozen PR #14 head.
-- Do not reuse legacy feedbacks or PR #14 assessments for multi-rater responses.

create table if not exists public.feedback_360_rounds (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  cycle_id uuid not null,
  name text not null,
  description text,
  confidentiality_mode text not null default 'confidential' check (confidentiality_mode = 'confidential'),
  status text not null default 'draft' check (status in ('draft','active','closed')),
  created_by_user_id uuid references auth.users(id) on delete set null,
  activated_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feedback_360_rounds_organization_id_id_key unique (organization_id,id),
  constraint feedback_360_rounds_name_not_blank check (length(btrim(name)) > 0),
  constraint feedback_360_rounds_cycle_same_org_fkey foreign key (organization_id,cycle_id) references public.cycles(organization_id,id)
);

create table if not exists public.feedback_360_participants (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  round_id uuid not null,
  subject_employee_id uuid not null,
  evaluator_employee_id uuid not null,
  relationship_type text not null check (relationship_type in ('self','manager','peer','direct_report')),
  status text not null default 'pending' check (status in ('pending','in_progress','submitted')),
  invited_at timestamptz not null default now(),
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feedback_360_participants_organization_id_id_key unique (organization_id,id),
  constraint feedback_360_participants_unique_relation unique (organization_id,round_id,subject_employee_id,evaluator_employee_id,relationship_type),
  constraint feedback_360_participants_round_same_org_fkey foreign key (organization_id,round_id) references public.feedback_360_rounds(organization_id,id) on delete cascade,
  constraint feedback_360_participants_subject_same_org_fkey foreign key (organization_id,subject_employee_id) references public.employees(organization_id,id) on delete restrict,
  constraint feedback_360_participants_evaluator_same_org_fkey foreign key (organization_id,evaluator_employee_id) references public.employees(organization_id,id) on delete restrict,
  constraint feedback_360_participants_status_time_check check ((status in ('pending','in_progress') and submitted_at is null) or (status = 'submitted' and submitted_at is not null))
);

create table if not exists public.feedback_360_subject_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  round_id uuid not null,
  subject_employee_id uuid not null,
  competency_id uuid not null,
  position_competency_id uuid not null,
  position_id_snapshot uuid not null,
  expected_level_snapshot smallint not null check (expected_level_snapshot between 1 and 5),
  created_at timestamptz not null default now(),
  constraint feedback_360_subject_competencies_organization_id_id_key unique (organization_id,id),
  constraint feedback_360_subject_competencies_unique unique (organization_id,round_id,subject_employee_id,competency_id),
  constraint feedback_360_subject_competencies_round_same_org_fkey foreign key (organization_id,round_id) references public.feedback_360_rounds(organization_id,id) on delete cascade,
  constraint feedback_360_subject_competencies_subject_same_org_fkey foreign key (organization_id,subject_employee_id) references public.employees(organization_id,id) on delete restrict,
  constraint feedback_360_subject_competencies_competency_same_org_fkey foreign key (organization_id,competency_id) references public.competencies(organization_id,id) on delete restrict,
  constraint feedback_360_subject_competencies_mapping_same_org_fkey foreign key (organization_id,position_competency_id) references public.position_competencies(organization_id,id) on delete restrict,
  constraint feedback_360_subject_competencies_position_same_org_fkey foreign key (organization_id,position_id_snapshot) references public.positions(organization_id,id) on delete restrict
);

create table if not exists public.feedback_360_scores (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  participant_id uuid not null,
  subject_competency_id uuid not null,
  score smallint check (score is null or score between 1 and 5),
  comment text check (comment is null or char_length(comment) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feedback_360_scores_organization_id_id_key unique (organization_id,id),
  constraint feedback_360_scores_unique unique (organization_id,participant_id,subject_competency_id),
  constraint feedback_360_scores_participant_same_org_fkey foreign key (organization_id,participant_id) references public.feedback_360_participants(organization_id,id) on delete cascade,
  constraint feedback_360_scores_competency_same_org_fkey foreign key (organization_id,subject_competency_id) references public.feedback_360_subject_competencies(organization_id,id) on delete cascade
);

create index if not exists idx_feedback_360_rounds_org_cycle on public.feedback_360_rounds(organization_id,cycle_id,status);
create index if not exists idx_feedback_360_participants_org_round on public.feedback_360_participants(organization_id,round_id,status);
create index if not exists idx_feedback_360_participants_org_evaluator on public.feedback_360_participants(organization_id,evaluator_employee_id,status);
create index if not exists idx_feedback_360_participants_org_subject on public.feedback_360_participants(organization_id,subject_employee_id,status);
create index if not exists idx_feedback_360_subject_comp_org_round on public.feedback_360_subject_competencies(organization_id,round_id,subject_employee_id);
create index if not exists idx_feedback_360_scores_org_participant on public.feedback_360_scores(organization_id,participant_id);

create or replace function public.fb360_set_updated_at()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists fb360_rounds_updated_at on public.feedback_360_rounds;
create trigger fb360_rounds_updated_at before update on public.feedback_360_rounds for each row execute function public.fb360_set_updated_at();
drop trigger if exists fb360_participants_updated_at on public.feedback_360_participants;
create trigger fb360_participants_updated_at before update on public.feedback_360_participants for each row execute function public.fb360_set_updated_at();
drop trigger if exists fb360_scores_updated_at on public.feedback_360_scores;
create trigger fb360_scores_updated_at before update on public.feedback_360_scores for each row execute function public.fb360_set_updated_at();

alter table public.feedback_360_rounds enable row level security;
alter table public.feedback_360_participants enable row level security;
alter table public.feedback_360_subject_competencies enable row level security;
alter table public.feedback_360_scores enable row level security;

create policy fb360_rounds_select_members on public.feedback_360_rounds for select to authenticated using (public.is_org_member(organization_id));
create policy fb360_participants_select_scoped on public.feedback_360_participants for select to authenticated using (
  public.classic_is_org_admin(organization_id)
  or public.classic_has_single_own_employee(organization_id,evaluator_employee_id)
);
create policy fb360_subject_competencies_select_scoped on public.feedback_360_subject_competencies for select to authenticated using (
  public.classic_is_org_admin(organization_id)
  or exists (
    select 1 from public.feedback_360_participants p
    where p.organization_id=feedback_360_subject_competencies.organization_id
      and p.round_id=feedback_360_subject_competencies.round_id
      and p.subject_employee_id=feedback_360_subject_competencies.subject_employee_id
      and public.classic_has_single_own_employee(p.organization_id,p.evaluator_employee_id)
  )
);
create policy fb360_scores_select_scoped on public.feedback_360_scores for select to authenticated using (
  public.classic_is_org_admin(organization_id)
  or exists (
    select 1 from public.feedback_360_participants p
    where p.organization_id=feedback_360_scores.organization_id
      and p.id=feedback_360_scores.participant_id
      and public.classic_has_single_own_employee(p.organization_id,p.evaluator_employee_id)
  )
);

revoke insert,update,delete on public.feedback_360_rounds,public.feedback_360_participants,public.feedback_360_subject_competencies,public.feedback_360_scores from authenticated;
grant select on public.feedback_360_rounds,public.feedback_360_participants,public.feedback_360_subject_competencies,public.feedback_360_scores to authenticated;

create or replace function public.fb360_create_round(p_organization_id uuid,p_cycle_id uuid,p_name text,p_description text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare i uuid;
begin
  if auth.uid() is null or not public.classic_is_org_admin(p_organization_id) then raise exception 'only Admin/RH can create a 360 round' using errcode='42501'; end if;
  if not exists(select 1 from public.cycles c where c.organization_id=p_organization_id and c.id=p_cycle_id and c.status in ('draft','active')) then raise exception 'cycle is outside the authorized tenant or unavailable' using errcode='42501'; end if;
  insert into public.feedback_360_rounds(organization_id,cycle_id,name,description,created_by_user_id)
    values(p_organization_id,p_cycle_id,btrim(p_name),nullif(btrim(p_description),''),auth.uid()) returning id into i;
  return i;
end $$;

create or replace function public.fb360_update_draft_round(p_round_id uuid,p_name text,p_description text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text;
begin
  select organization_id,status into o,s from public.feedback_360_rounds where id=p_round_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'round is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' then raise exception 'only draft rounds are editable' using errcode='23514'; end if;
  update public.feedback_360_rounds set name=btrim(p_name),description=nullif(btrim(p_description),'') where id=p_round_id;
  return true;
end $$;

create or replace function public.fb360_add_participant(p_round_id uuid,p_subject_employee_id uuid,p_evaluator_employee_id uuid,p_relationship_type text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; i uuid; subject_manager uuid;
begin
  select organization_id,status into o,s from public.feedback_360_rounds where id=p_round_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'round is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' then raise exception 'participants can only be configured in draft' using errcode='23514'; end if;
  if p_relationship_type not in ('self','manager','peer','direct_report') then raise exception 'invalid relationship type' using errcode='23514'; end if;
  select manager_employee_id into subject_manager from public.employees where organization_id=o and id=p_subject_employee_id and status='active';
  if not found or not exists(select 1 from public.employees where organization_id=o and id=p_evaluator_employee_id and status='active') then raise exception 'subject and evaluator must be active employees in the same tenant' using errcode='42501'; end if;
  if p_relationship_type='self' and p_subject_employee_id <> p_evaluator_employee_id then raise exception 'self relationship requires the same employee' using errcode='42501'; end if;
  if p_relationship_type='manager' and (subject_manager is null or subject_manager <> p_evaluator_employee_id) then raise exception 'manager relationship requires the direct manager' using errcode='42501'; end if;
  if p_relationship_type='direct_report' and not exists(select 1 from public.employees e where e.organization_id=o and e.id=p_evaluator_employee_id and e.manager_employee_id=p_subject_employee_id and e.status='active') then raise exception 'direct_report relationship requires a direct report' using errcode='42501'; end if;
  insert into public.feedback_360_participants(organization_id,round_id,subject_employee_id,evaluator_employee_id,relationship_type)
    values(o,p_round_id,p_subject_employee_id,p_evaluator_employee_id,p_relationship_type) returning id into i;
  return i;
exception when unique_violation then raise exception 'duplicate 360 participant relationship' using errcode='23505';
end $$;

create or replace function public.fb360_remove_participant(p_participant_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text;
begin
  select organization_id,r.status into o,s from public.feedback_360_participants p join public.feedback_360_rounds r on r.organization_id=p.organization_id and r.id=p.round_id where p.id=p_participant_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'participant is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' then raise exception 'participants cannot be removed after activation' using errcode='23514'; end if;
  delete from public.feedback_360_participants where id=p_participant_id;
  return true;
end $$;

create or replace function public.fb360_activate_round(p_round_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; cycle_status text; subject_count bigint; participant_count bigint; invalid_subjects bigint;
begin
  select r.organization_id,r.status,c.status into o,s,cycle_status from public.feedback_360_rounds r join public.cycles c on c.organization_id=r.organization_id and c.id=r.cycle_id where r.id=p_round_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'round is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' or cycle_status <> 'active' then raise exception 'round requires draft status and an active cycle' using errcode='23514'; end if;
  select count(distinct subject_employee_id),count(*) into subject_count,participant_count from public.feedback_360_participants where organization_id=o and round_id=p_round_id;
  if subject_count=0 or participant_count=0 then raise exception 'round requires subjects and participants' using errcode='23514'; end if;
  select count(*) into invalid_subjects
  from (select distinct p.subject_employee_id from public.feedback_360_participants p where p.organization_id=o and p.round_id=p_round_id) subjects
  where not exists(select 1 from public.employees e where e.organization_id=o and e.id=subjects.subject_employee_id and e.status='active' and e.position_id is not null)
     or not exists(select 1 from public.position_competencies pc join public.employees e on e.organization_id=pc.organization_id and e.position_id=pc.position_id where pc.organization_id=o and e.id=subjects.subject_employee_id and e.status='active' and pc.active);
  if invalid_subjects > 0 then raise exception 'round configuration pending: every subject needs a position and active mappings' using errcode='23514'; end if;
  insert into public.feedback_360_subject_competencies(organization_id,round_id,subject_employee_id,competency_id,position_competency_id,position_id_snapshot,expected_level_snapshot)
    select o,p_round_id,e.id,pc.competency_id,pc.id,e.position_id,pc.expected_level
    from public.employees e join public.position_competencies pc on pc.organization_id=e.organization_id and pc.position_id=e.position_id and pc.active
    where e.organization_id=o and e.status='active' and e.id in (select distinct subject_employee_id from public.feedback_360_participants where organization_id=o and round_id=p_round_id)
    on conflict (organization_id,round_id,subject_employee_id,competency_id) do nothing;
  insert into public.feedback_360_scores(organization_id,participant_id,subject_competency_id)
    select o,p.id,sc.id from public.feedback_360_participants p join public.feedback_360_subject_competencies sc on sc.organization_id=p.organization_id and sc.round_id=p.round_id and sc.subject_employee_id=p.subject_employee_id
    where p.organization_id=o and p.round_id=p_round_id on conflict do nothing;
  update public.feedback_360_rounds set status='active',activated_at=now(),updated_at=now() where id=p_round_id;
  return true;
end $$;

create or replace function public.fb360_save_score(p_participant_id uuid,p_subject_competency_id uuid,p_score smallint,p_comment text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; round_status text; evaluator uuid;
begin
  if auth.uid() is null or p_score is null or p_score not between 1 and 5 then raise exception 'score must be between 1 and 5' using errcode='23514'; end if;
  select p.organization_id,p.status,r.status,p.evaluator_employee_id into o,s,round_status,evaluator from public.feedback_360_participants p join public.feedback_360_rounds r on r.organization_id=p.organization_id and r.id=p.round_id where p.id=p_participant_id for update;
  if o is null or not public.classic_has_single_own_employee(o,evaluator) then raise exception 'participant is outside the evaluator population' using errcode='42501'; end if;
  if s not in ('pending','in_progress') or round_status <> 'active' then raise exception 'participation is not editable' using errcode='23514'; end if;
  update public.feedback_360_scores set score=p_score,comment=nullif(btrim(p_comment),''),updated_at=now() where organization_id=o and participant_id=p_participant_id and subject_competency_id=p_subject_competency_id;
  if not found then raise exception 'competency is not part of the participant snapshot' using errcode='23503'; end if;
  update public.feedback_360_participants set status='in_progress',updated_at=now() where id=p_participant_id;
  return true;
end $$;

create or replace function public.fb360_submit_participation(p_participant_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; round_status text; evaluator uuid; total bigint; filled bigint;
begin
  select p.organization_id,p.status,r.status,p.evaluator_employee_id into o,s,round_status,evaluator from public.feedback_360_participants p join public.feedback_360_rounds r on r.organization_id=p.organization_id and r.id=p.round_id where p.id=p_participant_id for update;
  if o is null or not public.classic_has_single_own_employee(o,evaluator) then raise exception 'participant is outside the evaluator population' using errcode='42501'; end if;
  if s not in ('pending','in_progress') or round_status <> 'active' then raise exception 'participation cannot be submitted' using errcode='23514'; end if;
  select count(*),count(*) filter(where score is not null) into total,filled from public.feedback_360_scores where organization_id=o and participant_id=p_participant_id;
  if total=0 or total <> filled then raise exception 'all snapped competencies must have a score' using errcode='23514'; end if;
  update public.feedback_360_participants set status='submitted',submitted_at=now(),updated_at=now() where id=p_participant_id;
  return true;
end $$;

create or replace function public.fb360_close_round(p_round_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text;
begin
  select organization_id,status into o,s from public.feedback_360_rounds where id=p_round_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'round is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'active' then raise exception 'only active rounds can be closed' using errcode='23514'; end if;
  update public.feedback_360_rounds set status='closed',closed_at=now(),updated_at=now() where id=p_round_id;
  return true;
end $$;

create or replace function public.fb360_read_subject_result(p_organization_id uuid,p_round_id uuid,p_subject_employee_id uuid)
returns table(round_id uuid,subject_employee_id uuid,competency_id uuid,competency_name text,position_id uuid,relationship_type text,response_count bigint,average_score numeric,expected_level_snapshot smallint,feedback_comment text)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cycle_status text; round_status text;
begin
  if auth.uid() is null or p_organization_id is null or p_round_id is null then raise exception 'result authorization is required' using errcode='42501'; end if;
  if not exists(select 1 from public.employees e where e.organization_id=p_organization_id and e.id=p_subject_employee_id and e.status='active') then raise exception 'subject is outside the requested tenant' using errcode='42501'; end if;
  if not (public.classic_is_org_admin(p_organization_id) or public.classic_has_single_own_employee(p_organization_id,p_subject_employee_id) or public.classic_is_direct_report(p_organization_id,p_subject_employee_id)) then raise exception 'subject result is outside the authorized population' using errcode='42501'; end if;
  select r.status,c.status into round_status,cycle_status from public.feedback_360_rounds r join public.cycles c on c.organization_id=r.organization_id and c.id=r.cycle_id where r.organization_id=p_organization_id and r.id=p_round_id;
  if round_status is null or round_status <> 'closed' then raise exception 'results require a closed round' using errcode='23514'; end if;
  return query
  with grouped as (
    select sc.round_id,sc.subject_employee_id,sc.competency_id,c.name,sc.position_id_snapshot,p.relationship_type,count(distinct p.id) as n,round(avg(s.score)::numeric,2) as avg_score,max(sc.expected_level_snapshot) as expected,
      case when p.relationship_type in ('self','manager') then max(s.comment) else null end as safe_comment
    from public.feedback_360_subject_competencies sc
    join public.feedback_360_scores s on s.organization_id=sc.organization_id and s.subject_competency_id=sc.id and s.score is not null
    join public.feedback_360_participants p on p.organization_id=s.organization_id and p.id=s.participant_id and p.status='submitted'
    join public.competencies c on c.organization_id=sc.organization_id and c.id=sc.competency_id
    where sc.organization_id=p_organization_id and sc.round_id=p_round_id and sc.subject_employee_id=p_subject_employee_id
    group by sc.round_id,sc.subject_employee_id,sc.competency_id,c.name,sc.position_id_snapshot,p.relationship_type
  )
  select g.round_id,g.subject_employee_id,g.competency_id,g.name,g.position_id_snapshot,g.relationship_type,g.n,g.avg_score,g.expected,g.safe_comment
  from grouped g where g.relationship_type in ('self','manager') or g.n >= 3;
end $$;

create or replace function public.fb360_read_organization_aggregate(p_organization_id uuid,p_round_id uuid)
returns table(round_id uuid,competency_id uuid,competency_name text,source_role text,position_id uuid,subject_count bigint,response_count bigint,average_score numeric)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare round_status text;
begin
  if auth.uid() is null or not public.has_org_role(p_organization_id,array['admin_youb','rh','diretoria']) then raise exception 'aggregate is not authorized for this tenant' using errcode='42501'; end if;
  select status into round_status from public.feedback_360_rounds where organization_id=p_organization_id and id=p_round_id;
  if round_status is null or round_status <> 'closed' then raise exception 'round is outside the requested tenant or not closed' using errcode='42501'; end if;
  return query
    select sc.round_id,sc.competency_id,c.name,p.relationship_type,sc.position_id_snapshot,count(distinct sc.subject_employee_id),count(distinct p.id),round(avg(s.score)::numeric,2)
    from public.feedback_360_subject_competencies sc
    join public.feedback_360_scores s on s.organization_id=sc.organization_id and s.subject_competency_id=sc.id and s.score is not null
    join public.feedback_360_participants p on p.organization_id=s.organization_id and p.id=s.participant_id and p.status='submitted'
    join public.competencies c on c.organization_id=sc.organization_id and c.id=sc.competency_id
    where sc.organization_id=p_organization_id and sc.round_id=p_round_id
    group by sc.round_id,sc.competency_id,c.name,p.relationship_type,sc.position_id_snapshot
    having count(distinct sc.subject_employee_id) >= 3 and count(distinct p.id) >= 3;
end $$;

create or replace function public.fb360_read_evolution(p_organization_id uuid,p_subject_employee_id uuid,p_origin_filter text default null)
returns table(source_type text,cycle_id uuid,round_id uuid,competency_id uuid,competency_name text,position_id uuid,expected_level_snapshot smallint,score numeric,previous_score numeric,delta numeric,distance_to_expected numeric,completed_at timestamptz)
language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null or not exists(select 1 from public.employees e where e.organization_id=p_organization_id and e.id=p_subject_employee_id and e.status='active') then raise exception 'evolution subject is outside the requested tenant' using errcode='42501'; end if;
  if not (public.classic_is_org_admin(p_organization_id) or public.classic_has_single_own_employee(p_organization_id,p_subject_employee_id) or public.classic_is_direct_report(p_organization_id,p_subject_employee_id)) then raise exception 'evolution is outside the authorized population' using errcode='42501'; end if;
  if p_origin_filter is not null and p_origin_filter not in ('assessment_v1','self','manager','peer','direct_report') then raise exception 'invalid evolution origin' using errcode='23514'; end if;
  return query
  with points as (
    select 'assessment_v1'::text source_type,a.cycle_id::uuid,null::uuid round_id,s.competency_id,c.name as competency_name,a.position_id,s.expected_level_snapshot,s.score::numeric score,a.completed_at
    from public.assessments a join public.assessment_competency_scores s on s.organization_id=a.organization_id and s.assessment_id=a.id and s.score is not null join public.competencies c on c.organization_id=s.organization_id and c.id=s.competency_id
    where a.organization_id=p_organization_id and a.subject_employee_id=p_subject_employee_id and a.status='completed'
    union all
    select p.relationship_type::text,r.cycle_id::uuid,r.id::uuid round_id,sc.competency_id,c.name as competency_name,sc.position_id_snapshot,sc.expected_level_snapshot,avg(s.score)::numeric score,max(p.submitted_at) completed_at
    from public.feedback_360_rounds r join public.feedback_360_participants p on p.organization_id=r.organization_id and p.round_id=r.id and p.status='submitted' join public.feedback_360_subject_competencies sc on sc.organization_id=p.organization_id and sc.round_id=p.round_id and sc.subject_employee_id=p.subject_employee_id join public.feedback_360_scores s on s.organization_id=p.organization_id and s.participant_id=p.id and s.subject_competency_id=sc.id and s.score is not null join public.competencies c on c.organization_id=sc.organization_id and c.id=sc.competency_id
    where r.organization_id=p_organization_id and r.status='closed' and p.subject_employee_id=p_subject_employee_id
    group by p.relationship_type,r.cycle_id,r.id,sc.competency_id,c.name,sc.position_id_snapshot,sc.expected_level_snapshot
    having p.relationship_type in ('self','manager') or count(distinct p.id) >= 3
  ), ordered as (
    select points.*,
      lag(points.score) over (
        partition by points.source_type,points.competency_id
        order by points.completed_at,coalesce(points.round_id,points.cycle_id)
      ) as previous_score_candidate,
      lag(points.position_id) over (
        partition by points.source_type,points.competency_id
        order by points.completed_at,coalesce(points.round_id,points.cycle_id)
      ) as previous_position_id,
      lag(points.expected_level_snapshot) over (
        partition by points.source_type,points.competency_id
        order by points.completed_at,coalesce(points.round_id,points.cycle_id)
      ) as previous_expected_level
    from points
    where p_origin_filter is null or points.source_type=p_origin_filter
  ), comparable as (
    select o.*,
      case when o.previous_score_candidate is not null
        and o.previous_position_id is not distinct from o.position_id
        and o.previous_expected_level is not distinct from o.expected_level_snapshot
        then o.previous_score_candidate end as previous_score
    from ordered o
  )
  select c.source_type,c.cycle_id,c.round_id,c.competency_id,c.competency_name,c.position_id,c.expected_level_snapshot,c.score,c.previous_score,
    case when c.previous_score is not null then c.score-c.previous_score end as delta,
    c.score-c.expected_level_snapshot as distance_to_expected,c.completed_at
  from comparable c order by c.competency_name,c.source_type,c.completed_at;
end $$;

revoke all on function public.fb360_set_updated_at() from public;
revoke all on function public.fb360_create_round(uuid,uuid,text,text),public.fb360_update_draft_round(uuid,text,text),public.fb360_add_participant(uuid,uuid,uuid,text),public.fb360_remove_participant(uuid),public.fb360_activate_round(uuid),public.fb360_save_score(uuid,uuid,smallint,text),public.fb360_submit_participation(uuid),public.fb360_close_round(uuid),public.fb360_read_subject_result(uuid,uuid,uuid),public.fb360_read_organization_aggregate(uuid,uuid),public.fb360_read_evolution(uuid,uuid,text) from public;
grant execute on function public.fb360_create_round(uuid,uuid,text,text),public.fb360_update_draft_round(uuid,text,text),public.fb360_add_participant(uuid,uuid,uuid,text),public.fb360_remove_participant(uuid),public.fb360_activate_round(uuid),public.fb360_save_score(uuid,uuid,smallint,text),public.fb360_submit_participation(uuid),public.fb360_close_round(uuid),public.fb360_read_subject_result(uuid,uuid,uuid),public.fb360_read_organization_aggregate(uuid,uuid),public.fb360_read_evolution(uuid,uuid,text) to authenticated;

comment on table public.feedback_360_rounds is 'Confidential 360 rounds. Raw operational access is restricted to Admin/RH; V1 aggregate outputs never expose individual identity.';
comment on table public.feedback_360_subject_competencies is 'Historical competency/position/expected-level snapshot created when a 360 round is activated.';
comment on table public.feedback_360_scores is '360 scores are immutable after participant submission; peer/direct_report comments are never returned to subject aggregates.';
-- ==================================================
-- MIGRATION: 20260908100000_pdi_development_v1.sql
-- ==================================================
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
  constraint pdi_objectives_organization_id_id_key unique (organization_id,id),
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
  constraint pdi_actions_organization_id_id_key unique (organization_id,id),
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
    (source_kind = 'assessment_v1' and source_assessment_id is not null and source_round_id is null and competency_id is not null and relationship_type is null)
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
  select case when count(*) = 1 then (array_agg(e.id))[1] else null end
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

create or replace function public.pdi_can_control_lifecycle(p_organization_id uuid,p_employee_id uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select public.has_org_role(p_organization_id,array['admin_youb','rh'])
    or (public.has_org_role(p_organization_id,array['gestor']) and public.classic_is_direct_report(p_organization_id,p_employee_id))
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
revoke all on function public.pdi_actor_employee_id(uuid),public.pdi_can_read_raw(uuid,uuid),public.pdi_can_manage(uuid,uuid),public.pdi_is_operator(uuid,uuid),public.pdi_can_control_lifecycle(uuid,uuid),public.pdi_set_updated_at(),public.pdi_audit_immutable(),public.pdi_append_audit(uuid,text,uuid,text,text,jsonb,jsonb) from public;
grant select on public.pdis,public.pdi_objectives,public.pdi_actions,public.pdi_checkins,public.pdi_source_links,public.pdi_audit_events to authenticated;
grant execute on function public.pdi_can_read_raw(uuid,uuid) to authenticated;

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
  if v_p.id is null or not public.pdi_can_control_lifecycle(v_p.organization_id,v_p.employee_id) then raise exception 'pdi lifecycle is outside the authorized population' using errcode='42501'; end if;
  if v_p.version <> p_expected_version then raise exception 'pdi version is stale' using errcode='40001'; end if;
  if (v_p.status='active' and p_next_status='paused') then v_event='paused';
  elsif (v_p.status='paused' and p_next_status='active') then v_event='resumed';
  elsif (v_p.status='active' and p_next_status='completed') then v_event='completed';
  elsif (v_p.status='active' and p_next_status='cancelled') then v_event='cancelled';
  else raise exception 'invalid pdi lifecycle transition' using errcode='23514'; end if;
  if p_next_status='completed' then
    if not exists(select 1 from public.pdi_objectives o where o.organization_id=v_p.organization_id and o.pdi_id=v_p.id) then raise exception 'pdi completion requires at least one objective' using errcode='23514'; end if;
    if exists(select 1 from public.pdi_objectives o where o.organization_id=v_p.organization_id and o.pdi_id=v_p.id and o.status not in ('completed','cancelled')) then raise exception 'all pdi objectives must be resolved before completion' using errcode='23514'; end if;
  end if;
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
    if p_source_assessment_id is null or p_source_round_id is not null or p_competency_id is null or p_relationship_type is not null then raise exception 'invalid assessment source link shape' using errcode='23514'; end if;
    select a.subject_employee_id,a.position_id,s.expected_level_snapshot,s.score::numeric into v_subject,v_position,v_expected,v_assessment_score from public.assessments a join public.assessment_competency_scores s on s.organization_id=a.organization_id and s.assessment_id=a.id and s.competency_id=p_competency_id where a.organization_id=v_p.organization_id and a.id=p_source_assessment_id and a.subject_employee_id=v_p.employee_id and a.status='completed';
    if v_subject is null then raise exception 'assessment source is invalid or outside the pdi population' using errcode='42501'; end if;
    if p_safe_aggregate_score is not null and round(p_safe_aggregate_score,2) <> round(v_assessment_score,2) then raise exception 'assessment source value does not match the authorized context' using errcode='23514'; end if;
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

drop function if exists public.pdi_read_organization_aggregate(uuid);
create or replace function public.pdi_read_organization_aggregate(p_organization_id uuid)
returns table(metric text,status text,value bigint) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null or not public.has_org_role(p_organization_id,array['admin_youb','rh','diretoria']) then raise exception 'pdi aggregate is not authorized' using errcode='42501'; end if;
  return query
  with cells(metric,status,value,subject_count,plan_count) as (
    select 'active_plans'::text,'active'::text,count(*)::bigint,count(distinct p.employee_id),count(*)::bigint
    from public.pdis p where p.organization_id=p_organization_id and p.status='active'
    group by p.status
    union all
    select 'objectives_by_status'::text,o.status,count(*)::bigint,count(distinct p.employee_id),count(distinct p.id)::bigint
    from public.pdi_objectives o join public.pdis p on p.organization_id=o.organization_id and p.id=o.pdi_id
    where o.organization_id=p_organization_id group by o.status
    union all
    select 'actions_by_status'::text,a.status,count(*)::bigint,count(distinct p.employee_id),count(distinct p.id)::bigint
    from public.pdi_actions a join public.pdi_objectives o on o.organization_id=a.organization_id and o.id=a.objective_id join public.pdis p on p.organization_id=o.organization_id and p.id=o.pdi_id
    where a.organization_id=p_organization_id group by a.status
    union all
    select 'blocked_actions'::text,'blocked'::text,count(*)::bigint,count(distinct p.employee_id),count(distinct p.id)::bigint
    from public.pdi_actions a join public.pdi_objectives o on o.organization_id=a.organization_id and o.id=a.objective_id join public.pdis p on p.organization_id=o.organization_id and p.id=o.pdi_id
    where a.organization_id=p_organization_id and a.status='blocked'
    union all
    select 'checkin_cadence'::text,to_char(date_trunc('month',c.checkin_at),'YYYY-MM'),count(*)::bigint,count(distinct p.employee_id),count(distinct p.id)::bigint
    from public.pdi_checkins c join public.pdis p on p.organization_id=c.organization_id and p.id=c.pdi_id
    where c.organization_id=p_organization_id group by date_trunc('month',c.checkin_at)
    union all
    select 'completed_objectives'::text,'completed'::text,count(*)::bigint,count(distinct p.employee_id),count(distinct p.id)::bigint
    from public.pdi_objectives o join public.pdis p on p.organization_id=o.organization_id and p.id=o.pdi_id
    where o.organization_id=p_organization_id and o.status='completed'
  )
  select c.metric,c.status,c.value from cells c where c.subject_count >= 5 and c.plan_count >= 5 order by c.metric,c.status;
end $$;

revoke all on function public.pdi_create(uuid,uuid,text,date),public.pdi_propose(uuid,bigint),public.pdi_activate(uuid,bigint),public.pdi_transition(uuid,text,bigint,text),public.pdi_add_objective(uuid,text,text,text,uuid,date),public.pdi_set_objective_status(uuid,text,bigint,text),public.pdi_add_action(uuid,text,text,uuid,date),public.pdi_set_action_status(uuid,text,bigint,text,text),public.pdi_add_checkin(uuid,text,text,text,text,uuid,uuid),public.pdi_add_source_link(uuid,text,uuid,uuid,uuid,text,text,numeric,uuid),public.pdi_read_organization_aggregate(uuid) from public;
grant execute on function public.pdi_create(uuid,uuid,text,date),public.pdi_propose(uuid,bigint),public.pdi_activate(uuid,bigint),public.pdi_transition(uuid,text,bigint,text),public.pdi_add_objective(uuid,text,text,text,uuid,date),public.pdi_set_objective_status(uuid,text,bigint,text),public.pdi_add_action(uuid,text,text,uuid,date),public.pdi_set_action_status(uuid,text,bigint,text,text),public.pdi_add_checkin(uuid,text,text,text,text,uuid,uuid),public.pdi_add_source_link(uuid,text,uuid,uuid,uuid,text,text,numeric,uuid),public.pdi_read_organization_aggregate(uuid) to authenticated;

comment on table public.pdis is 'PDI V1 root. Legacy objective/actions JSONB are preserved for compatibility; new actions are normalized in pdi_actions.';
comment on table public.pdi_source_links is 'Safe contextual links only. Feedback 360 links never persist participant, evaluator, raw score row or confidential comments.';
comment on table public.pdi_audit_events is 'Immutable PDI audit trail, including lifecycle and relevant objective/action changes.';
-- ==================================================
-- MIGRATION: 20260911100000_signal_status_default_hardening_v1.sql
-- ==================================================
-- Commercial V1 hardening: align the intelligence signal default with the
-- already-approved signals_status_v1_check constraint without changing it.
DO $$
DECLARE
  constraint_definition text;
BEGIN
  SELECT pg_get_constraintdef(c.oid)
    INTO constraint_definition
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE c.conname = 'signals_status_v1_check'
    AND n.nspname = 'public'
    AND t.relname = 'intelligence_signals';

  IF constraint_definition IS NULL THEN
    RAISE EXCEPTION 'signals_status_v1_check is missing';
  END IF;

  IF constraint_definition NOT LIKE '%observed%' THEN
    RAISE EXCEPTION 'signals_status_v1_check must accept observed: %', constraint_definition;
  END IF;

  IF constraint_definition LIKE '%received%' THEN
    RAISE EXCEPTION 'signals_status_v1_check must not accept received: %', constraint_definition;
  END IF;
END
$$;

ALTER TABLE public.intelligence_signals
  ALTER COLUMN status SET DEFAULT 'observed';
-- ==================================================
-- MIGRATION: 20260911110000_position_competency_scope_hardening_v1.sql
-- ==================================================
-- Commercial V1 hardening: keep position-competency reads tenant-bound
-- before applying direct-report scope. This is a forward-only RLS fix.
DROP POLICY IF EXISTS cca_position_competencies_select_scoped ON public.position_competencies;

CREATE POLICY cca_position_competencies_select_scoped
ON public.position_competencies
FOR SELECT
TO authenticated
USING (
  public.is_org_member(organization_id)
  AND (
    public.classic_is_org_admin(organization_id)
    OR public.has_org_role(organization_id, ARRAY['diretoria'])
    OR EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.organization_id = position_competencies.organization_id
        AND e.position_id = position_competencies.position_id
        AND e.status = 'active'
        AND public.classic_is_direct_report(position_competencies.organization_id, e.id)
    )
    OR EXISTS (
      SELECT 1
      FROM public.assessment_competency_scores s
      JOIN public.assessments a
        ON a.organization_id = s.organization_id
       AND a.id = s.assessment_id
      WHERE s.organization_id = position_competencies.organization_id
        AND s.position_competency_id = position_competencies.id
        AND a.status = 'completed'
        AND public.classic_has_single_own_employee(a.organization_id, a.subject_employee_id)
    )
  )
);
-- ==================================================
-- MIGRATION: 20260911120000_cca_aggregate_execute_hardening_v1.sql
-- ==================================================
-- Commercial V1 hardening: aggregate assessment RPC is authenticated-only.
-- Preserve the RPC contract; tighten execution privileges forward-only.
REVOKE EXECUTE
ON FUNCTION public.cca_read_assessment_aggregate(uuid, uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.cca_read_assessment_aggregate(uuid, uuid)
TO authenticated;
-- ==================================================
-- MIGRATION: 20260911130000_feedback_360_execute_hardening_v1.sql
-- ==================================================
-- Commercial V1 hardening: Feedback 360 application RPCs are authenticated-only.
REVOKE EXECUTE ON FUNCTION
  public.fb360_create_round(uuid,uuid,text,text),
  public.fb360_update_draft_round(uuid,text,text),
  public.fb360_add_participant(uuid,uuid,uuid,text),
  public.fb360_remove_participant(uuid),
  public.fb360_activate_round(uuid),
  public.fb360_save_score(uuid,uuid,smallint,text),
  public.fb360_submit_participation(uuid),
  public.fb360_close_round(uuid),
  public.fb360_read_subject_result(uuid,uuid,uuid),
  public.fb360_read_organization_aggregate(uuid,uuid),
  public.fb360_read_evolution(uuid,uuid,text)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
  public.fb360_create_round(uuid,uuid,text,text),
  public.fb360_update_draft_round(uuid,text,text),
  public.fb360_add_participant(uuid,uuid,uuid,text),
  public.fb360_remove_participant(uuid),
  public.fb360_activate_round(uuid),
  public.fb360_save_score(uuid,uuid,smallint,text),
  public.fb360_submit_participation(uuid),
  public.fb360_close_round(uuid),
  public.fb360_read_subject_result(uuid,uuid,uuid),
  public.fb360_read_organization_aggregate(uuid,uuid),
  public.fb360_read_evolution(uuid,uuid,text)
TO authenticated;
-- ==================================================
-- MIGRATION: 20260911140000_recommendation_intervention_dml_hardening_v1.sql
-- ==================================================
-- Commercial V1 hardening: keep application DML grants aligned with the
-- authenticated RLS policies. RLS remains the authorization boundary.
GRANT SELECT, INSERT
ON public.intelligence_recommendations, public.intelligence_interventions
TO authenticated;

GRANT SELECT, INSERT
ON public.intelligence_recommendation_evidence
TO authenticated;
-- ==================================================
-- MIGRATION: 20260912100000_data_architecture_p0_event_capture_v1.sql
-- ==================================================
-- Data Architecture 2.0 — P0 historical event capture
-- Additive only. Operational tables remain the current-state source of truth.
-- organizational_events is append-only history; memory relations are a temporal projection.

insert into public.organizational_memory_entity_types(entity_type, description) values
  ('competency','A competency reference.'),
  ('position_competency','A position competency mapping reference.')
on conflict (entity_type) do nothing;

insert into public.organizational_memory_relationship_types(relationship_type, description) values
  ('occupies','An employee occupies a position.'),
  ('reports_to','An employee reports to another employee.'),
  ('has_competency','A position has a competency mapping.')
on conflict (relationship_type) do nothing;

insert into public.organizational_event_types(event_type, description, implemented) values
  ('competency_expected_level_changed','A position competency expected level changed.',true),
  ('competency_score_changed','An existing competency score changed.',true),
  ('intervention_started','An intervention became in progress.',true),
  ('intervention_completed','An intervention was completed.',true),
  ('action_started','An intelligence action became in progress.',true),
  ('action_completed','An intelligence action was completed.',true)
on conflict (event_type) do nothing;

-- led_to remains catalogued for compatibility, but cannot be asserted as a fact.
alter table public.organizational_memory_relations
  drop constraint if exists organizational_memory_relations_led_to_epistemic_check;
alter table public.organizational_memory_relations
  add constraint organizational_memory_relations_led_to_epistemic_check
  check (relationship_type <> 'led_to' or knowledge_kind in ('derived','interpreted','hypothesis'));

create or replace function public._organizational_entity_belongs_to_org(
  p_organization_id uuid,
  p_entity_type text,
  p_entity_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if p_entity_id is null then return false; end if;
  if p_entity_type = 'employee' then
    return exists(select 1 from public.employees where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'area' then
    return exists(select 1 from public.areas where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'position' then
    return exists(select 1 from public.positions where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'competency' then
    return exists(select 1 from public.competencies where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'position_competency' then
    return exists(select 1 from public.position_competencies where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'assessment' then
    return exists(select 1 from public.assessments where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'intervention' then
    return exists(select 1 from public.intelligence_interventions where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'action' then
    return exists(select 1 from public.intelligence_actions where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'organization' then
    return exists(select 1 from public.organizations where id=p_organization_id and id=p_entity_id);
  end if;
  return false;
end;
$$;

create or replace function public._append_organizational_event(
  p_organization_id uuid,
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_occurred_at timestamptz,
  p_source_type text,
  p_source_id text,
  p_sensitivity text default 'standard',
  p_payload jsonb default '{}'::jsonb,
  p_correlation_id uuid default gen_random_uuid(),
  p_related_entity_type text default null,
  p_related_entity_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_actor uuid;
  v_implemented boolean;
begin
  v_actor := auth.uid();
  if v_actor is null then
    raise exception 'event actor must come from auth.uid()' using errcode='42501';
  end if;
  if p_organization_id is null or p_event_type is null or p_entity_type is null or p_entity_id is null then
    raise exception 'event tenant, type and entity are required' using errcode='22023';
  end if;
  select implemented into v_implemented
  from public.organizational_event_types
  where event_type=p_event_type;
  if not found or v_implemented is not true then
    raise exception 'event type is not implemented: %', p_event_type using errcode='23514';
  end if;
  if not exists(select 1 from public.organizational_memory_entity_types where entity_type=p_entity_type) then
    raise exception 'event entity type is not registered: %', p_entity_type using errcode='23514';
  end if;
  if not public._organizational_entity_belongs_to_org(p_organization_id,p_entity_type,p_entity_id) then
    raise exception 'event entity is outside the authorized tenant' using errcode='42501';
  end if;
  if p_related_entity_type is not null or p_related_entity_id is not null then
    if p_related_entity_type is null or p_related_entity_id is null then
      raise exception 'related event entity must be provided as a pair' using errcode='22023';
    end if;
    if not exists(select 1 from public.organizational_memory_entity_types where entity_type=p_related_entity_type) then
      raise exception 'event related entity type is not registered: %', p_related_entity_type using errcode='23514';
    end if;
    if not public._organizational_entity_belongs_to_org(p_organization_id,p_related_entity_type,p_related_entity_id) then
      raise exception 'event related entity is outside the authorized tenant' using errcode='42501';
    end if;
  end if;
  if p_source_type not in ('manual','system','service','bee','import','integration') then
    raise exception 'event source type is invalid' using errcode='23514';
  end if;
  if nullif(btrim(coalesce(p_source_id,'')),'') is null then
    raise exception 'event source id is required' using errcode='22023';
  end if;
  if p_sensitivity not in ('standard','restricted','highly_sensitive') then
    raise exception 'event sensitivity is invalid' using errcode='23514';
  end if;
  if p_occurred_at is null or jsonb_typeof(coalesce(p_payload,'{}'::jsonb)) <> 'object' then
    raise exception 'event time and object payload are required' using errcode='22023';
  end if;
  insert into public.organizational_events(
    organization_id,event_type,entity_type,entity_id,related_entity_type,related_entity_id,
    occurred_at,recorded_at,source_type,source_id,actor_user_id,sensitivity,payload,correlation_id
  ) values (
    p_organization_id,p_event_type,p_entity_type,p_entity_id,p_related_entity_type,p_related_entity_id,
    p_occurred_at,now(),p_source_type,p_source_id,v_actor,p_sensitivity,coalesce(p_payload,'{}'::jsonb),coalesce(p_correlation_id,gen_random_uuid())
  ) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public._sync_employee_temporal_relation(
  p_organization_id uuid,
  p_employee_id uuid,
  p_relationship_type text,
  p_target_entity_type text,
  p_target_entity_id uuid,
  p_valid_from timestamptz,
  p_event_id uuid,
  p_correlation_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_relationship_type not in ('occupies','belongs_to','reports_to') then
    raise exception 'employee temporal relationship is not allowed' using errcode='23514';
  end if;
  if not public._organizational_entity_belongs_to_org(p_organization_id,'employee',p_employee_id) then
    raise exception 'employee relation source is outside the tenant' using errcode='42501';
  end if;
  update public.organizational_memory_relations
  set valid_until=p_valid_from
  where organization_id=p_organization_id
    and source_entity_type='employee'
    and source_entity_id=p_employee_id
    and relationship_type=p_relationship_type
    and valid_until is null
    and (p_target_entity_id is null or target_entity_id is distinct from p_target_entity_id);
  if p_target_entity_id is null then return; end if;
  if not public._organizational_entity_belongs_to_org(p_organization_id,p_target_entity_type,p_target_entity_id) then
    raise exception 'employee relation target is outside the tenant' using errcode='42501';
  end if;
  if not exists(
    select 1 from public.organizational_memory_relations
    where organization_id=p_organization_id
      and source_entity_type='employee'
      and source_entity_id=p_employee_id
      and relationship_type=p_relationship_type
      and target_entity_type=p_target_entity_type
      and target_entity_id=p_target_entity_id
      and valid_until is null
  ) then
    insert into public.organizational_memory_relations(
      organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,
      relationship_type,knowledge_kind,valid_from,source_type,source_id,sensitivity,context
    ) values (
      p_organization_id,'employee',p_employee_id,p_target_entity_type,p_target_entity_id,
      p_relationship_type,'fact',p_valid_from,'service',p_event_id::text,'standard',
      jsonb_build_object('event_id',p_event_id,'correlation_id',p_correlation_id)
    );
  end if;
end;
$$;

-- The new writer is internal: domain functions call it, authenticated clients cannot.
revoke all on function public._organizational_entity_belongs_to_org(uuid,text,uuid) from public, authenticated, anon;
revoke all on function public._append_organizational_event(uuid,text,text,uuid,timestamptz,text,text,text,jsonb,uuid,text,uuid) from public, authenticated, anon;
revoke all on function public._sync_employee_temporal_relation(uuid,uuid,text,text,uuid,timestamptz,uuid,uuid) from public, authenticated, anon;

create or replace function public.update_employee_profile(
  p_employee_id uuid,
  p_full_name text,
  p_email text,
  p_area_id uuid,
  p_position_id uuid,
  p_seniority text,
  p_manager_employee_id uuid,
  p_status text default null
)
returns public.employees
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_before public.employees%rowtype;
  v_after public.employees%rowtype;
  v_org uuid;
  v_status text;
  v_now timestamptz := clock_timestamp();
  v_correlation uuid := gen_random_uuid();
  v_event uuid;
begin
  select e.* into strict v_before from public.employees e where e.id=p_employee_id for update;
  v_org := v_before.organization_id;
  if not public.has_org_role(v_org,array['admin_youb','diretoria','rh']) then
    raise exception 'employee update is not authorized' using errcode='42501';
  end if;
  if nullif(btrim(coalesce(p_full_name,'')),'') is null then
    raise exception 'employee name is required' using errcode='22023';
  end if;
  if p_seniority is not null and p_seniority not in ('junior','pleno','senior') then
    raise exception 'employee seniority is invalid' using errcode='23514';
  end if;
  v_status := coalesce(p_status,v_before.status);
  if v_status not in ('active','inactive') then
    raise exception 'employee status is invalid' using errcode='23514';
  end if;
  if p_area_id is not null and not public._organizational_entity_belongs_to_org(v_org,'area',p_area_id) then
    raise exception 'area is outside the employee tenant' using errcode='42501';
  end if;
  if p_position_id is not null and not public._organizational_entity_belongs_to_org(v_org,'position',p_position_id) then
    raise exception 'position is outside the employee tenant' using errcode='42501';
  end if;
  if p_manager_employee_id is not null and (p_manager_employee_id=p_employee_id or not public._organizational_entity_belongs_to_org(v_org,'employee',p_manager_employee_id)) then
    raise exception 'manager is invalid for the employee tenant' using errcode='23514';
  end if;
  update public.employees
  set full_name=btrim(p_full_name), email=nullif(btrim(p_email),''), area_id=p_area_id,
      position_id=p_position_id, seniority=p_seniority, manager_employee_id=p_manager_employee_id,
      status=v_status
  where id=p_employee_id;
  if v_before.status is distinct from v_status then
    v_event := public._append_organizational_event(v_org,'employee_status_changed','employee',p_employee_id,v_now,'service','update_employee_profile','standard',jsonb_build_object('before',v_before.status,'after',v_status),v_correlation);
  end if;
  if v_before.area_id is distinct from p_area_id then
    v_event := public._append_organizational_event(v_org,'area_changed','employee',p_employee_id,v_now,'service','update_employee_profile','standard',jsonb_build_object('before',v_before.area_id,'after',p_area_id),v_correlation,case when p_area_id is null then null else 'area' end,p_area_id);
    perform public._sync_employee_temporal_relation(v_org,p_employee_id,'belongs_to','area',p_area_id,v_now,v_event,v_correlation);
  end if;
  if v_before.position_id is distinct from p_position_id then
    v_event := public._append_organizational_event(v_org,'position_changed','employee',p_employee_id,v_now,'service','update_employee_profile','standard',jsonb_build_object('before',v_before.position_id,'after',p_position_id),v_correlation,case when p_position_id is null then null else 'position' end,p_position_id);
    perform public._sync_employee_temporal_relation(v_org,p_employee_id,'occupies','position',p_position_id,v_now,v_event,v_correlation);
  end if;
  if v_before.manager_employee_id is distinct from p_manager_employee_id then
    v_event := public._append_organizational_event(v_org,'manager_changed','employee',p_employee_id,v_now,'service','update_employee_profile','standard',jsonb_build_object('before',v_before.manager_employee_id,'after',p_manager_employee_id),v_correlation,case when p_manager_employee_id is null then null else 'employee' end,p_manager_employee_id);
    perform public._sync_employee_temporal_relation(v_org,p_employee_id,'reports_to','employee',p_manager_employee_id,v_now,v_event,v_correlation);
  end if;
  select e.* into strict v_after from public.employees e where e.id=p_employee_id;
  return v_after;
end;
$$;

revoke update on public.employees from authenticated;
revoke all on function public.update_employee_profile(uuid,text,text,uuid,uuid,text,uuid,text) from public;
grant execute on function public.update_employee_profile(uuid,text,text,uuid,uuid,text,uuid,text) to authenticated;

create or replace function public.create_employee_profile(
  p_organization_id uuid,
  p_full_name text,
  p_email text default null,
  p_area_id uuid default null,
  p_position_id uuid default null,
  p_seniority text default null,
  p_manager_employee_id uuid default null,
  p_status text default 'active',
  p_correlation_id uuid default null
)
returns public.employees
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_employee public.employees%rowtype;
  v_existing_id uuid;
  v_correlation uuid := coalesce(p_correlation_id,gen_random_uuid());
  v_employee_id uuid := gen_random_uuid();
  v_now timestamptz := clock_timestamp();
  v_event uuid;
  v_status text := coalesce(p_status,'active');
begin
  if auth.uid() is null or p_organization_id is null or not public.has_org_role(p_organization_id,array['admin_youb','diretoria','rh']) then
    raise exception 'employee creation is not authorized' using errcode='42501';
  end if;
  -- correlation_id identifies one logical create operation; the xact lock closes the concurrent retry race.
  perform pg_advisory_xact_lock(hashtextextended(p_organization_id::text || ':create_employee_profile:' || v_correlation::text,0));
  if p_correlation_id is not null then
    select oe.entity_id into v_existing_id
    from public.organizational_events oe
    where oe.organization_id=p_organization_id
      and oe.event_type='employee_created'
      and oe.entity_type='employee'
      and oe.source_type='service'
      and oe.source_id='create_employee_profile'
      and oe.correlation_id=p_correlation_id
    limit 1;
    if v_existing_id is not null then
      select e.* into strict v_employee from public.employees e where e.organization_id=p_organization_id and e.id=v_existing_id;
      return v_employee;
    end if;
  end if;
  if nullif(btrim(coalesce(p_full_name,'')),'') is null then
    raise exception 'employee name is required' using errcode='22023';
  end if;
  if v_status not in ('active','inactive') then
    raise exception 'employee status is invalid' using errcode='23514';
  end if;
  if p_seniority is not null and p_seniority not in ('junior','pleno','senior') then
    raise exception 'employee seniority is invalid' using errcode='23514';
  end if;
  if p_area_id is not null and not public._organizational_entity_belongs_to_org(p_organization_id,'area',p_area_id) then
    raise exception 'area is outside the employee tenant' using errcode='42501';
  end if;
  if p_position_id is not null and not public._organizational_entity_belongs_to_org(p_organization_id,'position',p_position_id) then
    raise exception 'position is outside the employee tenant' using errcode='42501';
  end if;
  if p_manager_employee_id is not null then
    if p_manager_employee_id=v_employee_id or not public._organizational_entity_belongs_to_org(p_organization_id,'employee',p_manager_employee_id) then
      raise exception 'manager is invalid for the employee tenant' using errcode='23514';
    end if;
  end if;
  insert into public.employees(id,organization_id,full_name,email,area_id,position_id,seniority,manager_employee_id,status,created_at)
  values(v_employee_id,p_organization_id,btrim(p_full_name),nullif(btrim(p_email),''),p_area_id,p_position_id,p_seniority,p_manager_employee_id,v_status,v_now)
  returning * into strict v_employee;
  v_event := public._append_organizational_event(
    p_organization_id,'employee_created','employee',v_employee.id,v_now,'service','create_employee_profile','standard',
    jsonb_build_object('status',v_employee.status,'area_id',v_employee.area_id,'position_id',v_employee.position_id,'manager_employee_id',v_employee.manager_employee_id,'seniority',v_employee.seniority),
    v_correlation
  );
  if v_employee.area_id is not null then
    perform public._sync_employee_temporal_relation(p_organization_id,v_employee.id,'belongs_to','area',v_employee.area_id,v_now,v_event,v_correlation);
  end if;
  if v_employee.position_id is not null then
    perform public._sync_employee_temporal_relation(p_organization_id,v_employee.id,'occupies','position',v_employee.position_id,v_now,v_event,v_correlation);
  end if;
  if v_employee.manager_employee_id is not null then
    perform public._sync_employee_temporal_relation(p_organization_id,v_employee.id,'reports_to','employee',v_employee.manager_employee_id,v_now,v_event,v_correlation);
  end if;
  return v_employee;
end;
$$;

-- Employee creation is controlled by the domain RPC; employees may still have no auth_user_id.
revoke insert on public.employees from authenticated;
revoke all on function public.create_employee_profile(uuid,text,text,uuid,uuid,text,uuid,text,uuid) from public;
grant execute on function public.create_employee_profile(uuid,text,text,uuid,uuid,text,uuid,text,uuid) to authenticated;

-- Assessment mapping and score writes already use domain RPCs. Add event capture there.
create or replace function public.cca_update_position_competency(p_id uuid,p_expected_level smallint,p_active boolean)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; old_level smallint; old_active boolean; pos uuid; comp uuid; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  select organization_id,position_id,competency_id,expected_level,active into o,pos,comp,old_level,old_active from public.position_competencies where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'mapping is outside the authorized tenant' using errcode='42501'; end if;
  if p_expected_level not between 1 and 5 then raise exception 'expected_level must be between 1 and 5' using errcode='23514'; end if;
  update public.position_competencies set expected_level=p_expected_level,active=p_active where id=p_id;
  if old_level is distinct from p_expected_level then
    ev:=public._append_organizational_event(o,'competency_expected_level_changed','position_competency',p_id,now_at,'service','cca_update_position_competency','standard',jsonb_build_object('before',old_level,'after',p_expected_level,'position_id',pos,'competency_id',comp,'active_before',old_active,'active_after',p_active),corr,'competency',comp);
  end if;
  return true;
end $$;

create or replace function public.cca_save_assessment_score(p_assessment_id uuid,p_competency_id uuid,p_score smallint,p_evidence_note text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; cycle_status text; old_score smallint; old_note text; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  if p_score is null or p_score not between 1 and 5 then raise exception 'score must be an integer between 1 and 5' using errcode='23514'; end if;
  select a.organization_id,a.status,c.status into o,s,cycle_status from public.assessments a join public.cycles c on c.organization_id=a.organization_id and c.id=a.cycle_id where a.id=p_assessment_id for update;
  if o is null or not public.cca_can_manage_assessment(o,p_assessment_id) then raise exception 'assessment is outside the authorized population' using errcode='42501'; end if;
  if s not in ('draft','in_progress') or cycle_status <> 'active' then raise exception 'assessment is not editable' using errcode='23514'; end if;
  select score,evidence_note into old_score,old_note from public.assessment_competency_scores where organization_id=o and assessment_id=p_assessment_id and competency_id=p_competency_id for update;
  if not found then raise exception 'competency is not part of the assessment snapshot' using errcode='23503'; end if;
  update public.assessment_competency_scores set score=p_score,evidence_note=nullif(btrim(p_evidence_note),''),updated_at=now() where organization_id=o and assessment_id=p_assessment_id and competency_id=p_competency_id;
  update public.assessments set status='in_progress',updated_at=now() where id=p_assessment_id;
  if old_score is distinct from p_score then
    ev:=public._append_organizational_event(o,'competency_score_changed','assessment',p_assessment_id,now_at,'service','cca_save_assessment_score','standard',jsonb_build_object('competency_id',p_competency_id,'before',old_score,'after',p_score,'evidence_note_before',old_note,'evidence_note_after',nullif(btrim(p_evidence_note),'')),corr,'competency',p_competency_id);
  end if;
  return true;
end $$;

-- Lifecycle writes are domain RPCs; authenticated clients cannot update/delete these states directly.
alter table public.intelligence_interventions add column if not exists started_at timestamptz;
alter table public.intelligence_interventions add column if not exists completed_at timestamptz;
alter table public.intelligence_actions add column if not exists started_at timestamptz;

create or replace function public.intelligence_start_intervention(p_intervention_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.intelligence_interventions%rowtype; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  select * into strict r from public.intelligence_interventions where id=p_intervention_id for update;
  if not (public.intelligence_is_decision_maker(r.organization_id) or (r.employee_id is not null and public.intelligence_has_employee_scope(r.organization_id,r.employee_id))) then raise exception 'intervention is outside the authorized scope' using errcode='42501'; end if;
  if r.status='in_progress' then return true; end if;
  if r.status not in ('approved','proposed') then raise exception 'intervention cannot be started from status %',r.status using errcode='23514'; end if;
  update public.intelligence_interventions set status='in_progress',started_at=now(),updated_at=now() where id=p_intervention_id;
  ev:=public._append_organizational_event(r.organization_id,'intervention_started','intervention',r.id,now_at,'service','intelligence_start_intervention','standard',jsonb_build_object('before',r.status,'after','in_progress','employee_id',r.employee_id,'owner_employee_id',r.owner_employee_id),corr,case when r.employee_id is null then null else 'employee' end,r.employee_id);
  return true;
end $$;

create or replace function public.intelligence_complete_intervention(p_intervention_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.intelligence_interventions%rowtype; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  select * into strict r from public.intelligence_interventions where id=p_intervention_id for update;
  if not (public.intelligence_is_decision_maker(r.organization_id) or (r.employee_id is not null and public.intelligence_has_employee_scope(r.organization_id,r.employee_id))) then raise exception 'intervention is outside the authorized scope' using errcode='42501'; end if;
  if r.status='completed' then return true; end if;
  if r.status<>'in_progress' then raise exception 'intervention cannot be completed from status %',r.status using errcode='23514'; end if;
  update public.intelligence_interventions set status='completed',completed_at=now(),updated_at=now() where id=p_intervention_id;
  ev:=public._append_organizational_event(r.organization_id,'intervention_completed','intervention',r.id,now_at,'service','intelligence_complete_intervention','standard',jsonb_build_object('before',r.status,'after','completed','employee_id',r.employee_id,'owner_employee_id',r.owner_employee_id),corr,case when r.employee_id is null then null else 'employee' end,r.employee_id);
  return true;
end $$;

create or replace function public.intelligence_start_action(p_action_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.intelligence_actions%rowtype; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  select * into strict r from public.intelligence_actions where id=p_action_id for update;
  if not (public.intelligence_is_decision_maker(r.organization_id) or (r.assignee_employee_id is not null and public.intelligence_has_employee_scope(r.organization_id,r.assignee_employee_id))) then raise exception 'action is outside the authorized scope' using errcode='42501'; end if;
  if r.status='in_progress' then return true; end if;
  if r.status not in ('approved','proposed') then raise exception 'action cannot be started from status %',r.status using errcode='23514'; end if;
  update public.intelligence_actions set status='in_progress',started_at=now(),updated_at=now() where id=p_action_id;
  ev:=public._append_organizational_event(r.organization_id,'action_started','action',r.id,now_at,'service','intelligence_start_action','standard',jsonb_build_object('before',r.status,'after','in_progress','intervention_id',r.intervention_id,'assignee_employee_id',r.assignee_employee_id),corr,case when r.intervention_id is null then null else 'intervention' end,r.intervention_id);
  return true;
end $$;

create or replace function public.intelligence_complete_action(p_action_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.intelligence_actions%rowtype; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  select * into strict r from public.intelligence_actions where id=p_action_id for update;
  if not (public.intelligence_is_decision_maker(r.organization_id) or (r.assignee_employee_id is not null and public.intelligence_has_employee_scope(r.organization_id,r.assignee_employee_id))) then raise exception 'action is outside the authorized scope' using errcode='42501'; end if;
  if r.status='completed' then return true; end if;
  if r.status<>'in_progress' then raise exception 'action cannot be completed from status %',r.status using errcode='23514'; end if;
  update public.intelligence_actions set status='completed',completed_at=coalesce(completed_at,now()),updated_at=now() where id=p_action_id;
  ev:=public._append_organizational_event(r.organization_id,'action_completed','action',r.id,now_at,'service','intelligence_complete_action','standard',jsonb_build_object('before',r.status,'after','completed','intervention_id',r.intervention_id,'assignee_employee_id',r.assignee_employee_id),corr,case when r.intervention_id is null then null else 'intervention' end,r.intervention_id);
  return true;
end $$;

revoke update,delete on public.intelligence_interventions,public.intelligence_actions from authenticated;
revoke all on function public.intelligence_start_intervention(uuid),public.intelligence_complete_intervention(uuid),public.intelligence_start_action(uuid),public.intelligence_complete_action(uuid) from public;
grant execute on function public.intelligence_start_intervention(uuid),public.intelligence_complete_intervention(uuid),public.intelligence_start_action(uuid),public.intelligence_complete_action(uuid) to authenticated;

revoke update,delete on public.organizational_events from authenticated;
