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
