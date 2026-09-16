-- youB — Ambient Intelligence Foundation V1
-- Structural, connector-neutral foundation only. No provider integration, queue, worker,
-- LLM engine, graph database, autonomous action or external message is introduced.

create table if not exists public.ambient_source_registry (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  source_key text not null check (source_key ~ '^[a-z][a-z0-9_.-]*$'),
  source_type text not null check (source_type in ('calendar','email','meeting','messaging','task','hr_system','user_input','internal_record')),
  display_name text not null check (btrim(display_name) <> ''),
  status text not null default 'planned' check (status in ('planned','available','disabled')),
  capabilities text[] not null default '{}'::text[],
  owner_user_id uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_by_user_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ambient_source_registry_no_secrets check (metadata::text !~* '(access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|password|credential|api[_ -]?key|private[_ -]?key)')
);
create unique index if not exists ambient_source_registry_org_key on public.ambient_source_registry(organization_id, source_key);
create unique index if not exists ambient_source_registry_org_id on public.ambient_source_registry(organization_id, id);

create table if not exists public.ambient_observations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  source_registry_id uuid,
  observation_type text not null check (observation_type ~ '^[a-z][a-z0-9_.-]*$'),
  epistemic_kind text not null check (epistemic_kind in ('system_record','machine_observed','human_declared','machine_inferred','human_confirmed','human_corrected')),
  summary text not null check (btrim(summary) <> '' and length(summary) <= 2000),
  observed_at timestamptz not null,
  recorded_at timestamptz not null default now(),
  valid_from timestamptz,
  valid_until timestamptz,
  sensitivity text not null default 'standard' check (sensitivity in ('standard','restricted','highly_sensitive')),
  confidence numeric(5,4),
  scope_type text check (scope_type is null or scope_type in ('organization','area','team','employee','position','personal')),
  scope_ref text,
  provenance jsonb not null default '{}'::jsonb check (jsonb_typeof(provenance) = 'object'),
  structured_value jsonb not null default '{}'::jsonb check (jsonb_typeof(structured_value) = 'object'),
  correlation_id uuid,
  actor_user_id uuid references auth.users(id) on delete set null,
  created_by_user_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  supersedes_observation_id uuid,
  created_at timestamptz not null default now(),
  constraint ambient_observations_org_id unique (organization_id, id),
  constraint ambient_observations_source_fk foreign key (organization_id, source_registry_id) references public.ambient_source_registry(organization_id, id),
  constraint ambient_observations_supersedes_fk foreign key (organization_id, supersedes_observation_id) references public.ambient_observations(organization_id, id),
  constraint ambient_observations_temporal_window check (valid_until is null or valid_from is null or valid_until >= valid_from),
  constraint ambient_observations_confidence check (confidence is null or (confidence >= 0 and confidence <= 1)),
  constraint ambient_observations_machine_confidence check (epistemic_kind not in ('machine_observed','machine_inferred') or confidence is not null),
  constraint ambient_observations_inference_basis check (epistemic_kind <> 'machine_inferred' or provenance ? 'basis'),
  constraint ambient_observations_no_raw_content check ((provenance::text || structured_value::text) !~* '(raw[_ -]?(transcript|message|email|body)|full[_ -]?(transcript|message|email|body)|chain[_ -]?of[_ -]?thought|prompt|access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|password|credential|api[_ -]?key)'),
  constraint ambient_observations_human_actor check (epistemic_kind not in ('human_declared','human_confirmed','human_corrected') or actor_user_id is not null)
);
create index if not exists ambient_observations_org_time on public.ambient_observations(organization_id, observed_at desc, recorded_at desc);
create index if not exists ambient_observations_scope on public.ambient_observations(organization_id, scope_type, scope_ref, observed_at desc);
create index if not exists ambient_observations_correlation on public.ambient_observations(organization_id, correlation_id);

create table if not exists public.ambient_observation_reviews (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  observation_id uuid not null,
  review_type text not null check (review_type in ('confirm','correct','reject')),
  reviewer_user_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  correction_summary text check (correction_summary is null or (btrim(correction_summary) <> '' and length(correction_summary) <= 2000)),
  correction_value jsonb check (correction_value is null or jsonb_typeof(correction_value) = 'object'),
  reason text check (reason is null or length(reason) <= 2000),
  correlation_id uuid,
  created_at timestamptz not null default now(),
  constraint ambient_observation_reviews_org_id unique (organization_id, id),
  constraint ambient_observation_reviews_observation_fk foreign key (organization_id, observation_id) references public.ambient_observations(organization_id, id),
  constraint ambient_observation_reviews_correct_payload check (review_type <> 'correct' or correction_summary is not null or correction_value is not null),
  constraint ambient_observation_reviews_no_raw_content check ((coalesce(correction_summary,'') || coalesce(reason,'') || coalesce(correction_value::text,'')) !~* '(raw[_ -]?(transcript|message|email|body)|full[_ -]?(transcript|message|email|body)|chain[_ -]?of[_ -]?thought|prompt|access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|password|credential|api[_ -]?key)')
);
create index if not exists ambient_observation_reviews_observation on public.ambient_observation_reviews(organization_id, observation_id, created_at desc);

create table if not exists public.ambient_user_preferences (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  preference_key text not null check (preference_key ~ '^[a-z][a-z0-9_.-]*$'),
  preference_value jsonb not null check (jsonb_typeof(preference_value) = 'object'),
  privacy text not null default 'private' check (privacy = 'private'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ambient_user_preferences_org_key unique (organization_id, user_id, preference_key),
  constraint ambient_user_preferences_no_raw_content check (preference_value::text !~* '(raw[_ -]?(transcript|message|email|body)|full[_ -]?(transcript|message|email|body)|chain[_ -]?of[_ -]?thought|prompt|access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|password|credential|api[_ -]?key)')
);

create table if not exists public.ambient_attention_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  horizon text not null check (horizon in ('now','today','week','later')),
  attention_type text not null check (attention_type in ('confirm','review','decide','converse','delegate','act','monitor')),
  title text not null check (btrim(title) <> '' and length(title) <= 500),
  rationale text check (rationale is null or length(rationale) <= 2000),
  status text not null default 'open' check (status in ('open','completed','dismissed','snoozed')),
  priority smallint not null default 3 check (priority between 1 and 3),
  due_at timestamptz,
  source_observation_id uuid,
  source_recommendation_id uuid,
  context jsonb not null default '{}'::jsonb check (jsonb_typeof(context) = 'object'),
  human_required boolean not null default true check (human_required is true),
  created_by_user_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ambient_attention_items_org_id unique (organization_id, id),
  constraint ambient_attention_items_observation_fk foreign key (organization_id, source_observation_id) references public.ambient_observations(organization_id, id),
  constraint ambient_attention_items_no_raw_content check ((coalesce(title,'') || coalesce(rationale,'') || context::text) !~* '(raw[_ -]?(transcript|message|email|body)|full[_ -]?(transcript|message|email|body)|chain[_ -]?of[_ -]?thought|prompt|access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|password|credential|api[_ -]?key)')
);
create index if not exists ambient_attention_items_owner_horizon on public.ambient_attention_items(organization_id, owner_user_id, horizon, priority, due_at);

create table if not exists public.ambient_leadership_commitments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  created_by_user_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  title text not null check (btrim(title) <> '' and length(title) <= 500),
  context text check (context is null or length(context) <= 2000),
  impact text check (impact is null or length(impact) <= 2000),
  horizon text not null default 'week' check (horizon in ('now','today','week','later')),
  status text not null default 'planned' check (status in ('planned','completed','deferred','cancelled')),
  due_at timestamptz,
  provenance jsonb not null default '{"epistemic_kind":"human_declared"}'::jsonb check (jsonb_typeof(provenance) = 'object' and provenance->>'epistemic_kind' = 'human_declared'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ambient_leadership_commitments_no_raw_content check ((coalesce(title,'') || coalesce(context,'') || coalesce(impact,'') || provenance::text) !~* '(raw[_ -]?(transcript|message|email|body)|full[_ -]?(transcript|message|email|body)|chain[_ -]?of[_ -]?thought|prompt|access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|password|credential|api[_ -]?key)')
);
create index if not exists ambient_leadership_commitments_owner_horizon on public.ambient_leadership_commitments(organization_id, owner_user_id, horizon, due_at);

create table if not exists public.ambient_attention_briefs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  horizon text not null check (horizon in ('now','today','week','later')),
  context_status text not null check (context_status in ('sufficient','insufficient')),
  insufficiency_reason text,
  focus_statement text,
  priority_items jsonb not null default '[]'::jsonb check (jsonb_typeof(priority_items) = 'array' and jsonb_array_length(priority_items) <= 3),
  do_items jsonb not null default '[]'::jsonb check (jsonb_typeof(do_items) = 'array'),
  delegate_items jsonb not null default '[]'::jsonb check (jsonb_typeof(delegate_items) = 'array'),
  stop_items jsonb not null default '[]'::jsonb check (jsonb_typeof(stop_items) = 'array'),
  source_observation_ids uuid[] not null default '{}'::uuid[],
  generated_by text not null default 'human_reviewed_service' check (generated_by in ('human_reviewed_service','future_planner_preview')),
  created_by_user_id uuid not null default auth.uid() references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint ambient_attention_briefs_insufficient_empty check (context_status <> 'insufficient' or (focus_statement is null and jsonb_array_length(priority_items) = 0 and jsonb_array_length(do_items) = 0 and jsonb_array_length(delegate_items) = 0 and jsonb_array_length(stop_items) = 0)),
  constraint ambient_attention_briefs_no_raw_content check ((coalesce(insufficiency_reason,'') || coalesce(focus_statement,'') || priority_items::text || do_items::text || delegate_items::text || stop_items::text) !~* '(raw[_ -]?(transcript|message|email|body)|full[_ -]?(transcript|message|email|body)|chain[_ -]?of[_ -]?thought|prompt|access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|password|credential|api[_ -]?key)')
);
create index if not exists ambient_attention_briefs_owner_horizon on public.ambient_attention_briefs(organization_id, owner_user_id, horizon, created_at desc);

-- Extend the existing controlled event catalog. These entries remain connector-neutral.
insert into public.organizational_event_types(event_type, description, implemented) values
  ('ambient_source_registered','An ambient source contract was registered.',true),
  ('ambient_observation_recorded','A normalized ambient observation was recorded.',true),
  ('ambient_observation_confirmed','A human confirmed an ambient observation.',true),
  ('ambient_observation_corrected','A human corrected an ambient observation.',true),
  ('ambient_attention_created','A human-reviewable attention item was prepared.',true),
  ('ambient_attention_completed','A human completed an attention item.',true),
  ('leadership_commitment_created','A leadership commitment was declared.',true),
  ('leadership_commitment_completed','A leadership commitment was completed.',true),
  ('ambient_preference_updated','A private user work preference was updated.',true)
on conflict (event_type) do nothing;

alter table public.ambient_source_registry enable row level security;
alter table public.ambient_observations enable row level security;
alter table public.ambient_observation_reviews enable row level security;
alter table public.ambient_user_preferences enable row level security;
alter table public.ambient_attention_items enable row level security;
alter table public.ambient_leadership_commitments enable row level security;
alter table public.ambient_attention_briefs enable row level security;

create policy ambient_sources_select on public.ambient_source_registry for select to authenticated using (public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria']) or owner_user_id = auth.uid());
create policy ambient_sources_insert on public.ambient_source_registry for insert to authenticated with check (public.intelligence_is_admin(organization_id) and created_by_user_id = auth.uid());
create policy ambient_sources_update on public.ambient_source_registry for update to authenticated using (public.intelligence_is_admin(organization_id)) with check (public.intelligence_is_admin(organization_id) and created_by_user_id = auth.uid());

create policy ambient_observations_select on public.ambient_observations for select to authenticated using (created_by_user_id = auth.uid() or (public.intelligence_is_admin(organization_id)) or (public.has_org_role(organization_id, array['diretoria']) and sensitivity in ('standard','restricted')));
create policy ambient_observations_insert on public.ambient_observations for insert to authenticated with check (created_by_user_id = auth.uid() and (public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria','gestor','colaborador'])));

create policy ambient_observation_reviews_select on public.ambient_observation_reviews for select to authenticated using (reviewer_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria']));
create policy ambient_observation_reviews_insert on public.ambient_observation_reviews for insert to authenticated with check (reviewer_user_id = auth.uid() and exists (select 1 from public.ambient_observations o where o.organization_id = ambient_observation_reviews.organization_id and o.id = ambient_observation_reviews.observation_id and (o.created_by_user_id = auth.uid() or public.intelligence_is_admin(o.organization_id) or public.has_org_role(o.organization_id, array['diretoria','gestor','colaborador']))));

-- Preferences are user-owned by default: no manager, RH or diretoria read path exists.
create policy ambient_preferences_owner_select on public.ambient_user_preferences for select to authenticated using (user_id = auth.uid());
create policy ambient_preferences_owner_insert on public.ambient_user_preferences for insert to authenticated with check (user_id = auth.uid());
create policy ambient_preferences_owner_update on public.ambient_user_preferences for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy ambient_preferences_owner_delete on public.ambient_user_preferences for delete to authenticated using (user_id = auth.uid());

create policy ambient_attention_select on public.ambient_attention_items for select to authenticated using (owner_user_id = auth.uid() or created_by_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria']));
create policy ambient_attention_insert on public.ambient_attention_items for insert to authenticated with check (created_by_user_id = auth.uid() and (owner_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria'])));
create policy ambient_attention_update on public.ambient_attention_items for update to authenticated using (owner_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria'])) with check (owner_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria']));

create policy ambient_commitments_select on public.ambient_leadership_commitments for select to authenticated using (owner_user_id = auth.uid() or created_by_user_id = auth.uid());
create policy ambient_commitments_insert on public.ambient_leadership_commitments for insert to authenticated with check (created_by_user_id = auth.uid() and (owner_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria'])));
create policy ambient_commitments_update on public.ambient_leadership_commitments for update to authenticated using (owner_user_id = auth.uid() or created_by_user_id = auth.uid()) with check (owner_user_id = auth.uid() or created_by_user_id = auth.uid());

create policy ambient_briefs_select on public.ambient_attention_briefs for select to authenticated using (owner_user_id = auth.uid() or created_by_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria']));
create policy ambient_briefs_insert on public.ambient_attention_briefs for insert to authenticated with check (created_by_user_id = auth.uid() and (owner_user_id = auth.uid() or public.intelligence_is_admin(organization_id) or public.has_org_role(organization_id, array['diretoria'])));

revoke all on public.ambient_source_registry, public.ambient_observations, public.ambient_observation_reviews, public.ambient_user_preferences, public.ambient_attention_items, public.ambient_leadership_commitments, public.ambient_attention_briefs from anon;
grant select, insert, update on public.ambient_source_registry to authenticated;
grant select, insert on public.ambient_observations to authenticated;
grant select, insert on public.ambient_observation_reviews to authenticated;
grant select, insert, update, delete on public.ambient_user_preferences to authenticated;
grant select, insert, update on public.ambient_attention_items to authenticated;
grant select, insert, update on public.ambient_leadership_commitments to authenticated;
grant select, insert on public.ambient_attention_briefs to authenticated;

comment on table public.ambient_source_registry is 'Connector-neutral source registry. It stores capabilities and metadata only; provider credentials and tokens are forbidden by contract.';
comment on table public.ambient_observations is 'Normalized observations with explicit epistemic kind, provenance, temporal validity, sensitivity and correlation. Raw communications are forbidden.';
comment on column public.ambient_observations.epistemic_kind is 'system_record, machine_observed, human_declared, machine_inferred, human_confirmed or human_corrected; inferred is never fact by implication.';
comment on table public.ambient_observation_reviews is 'Append-only confirmation, rejection and correction history. Corrections never overwrite the original observation.';
comment on table public.ambient_user_preferences is 'Private user-owned work preferences. No default read path exists for manager, RH or diretoria.';
comment on table public.ambient_attention_items is 'Human-reviewable attention/planning foundation. Every item requires human confirmation and has an explicit horizon and attention type.';
comment on table public.ambient_leadership_commitments is 'Leadership commitments represented as context + impact + priority, not as an autonomous task manager.';
comment on table public.ambient_attention_briefs is 'Bounded brief snapshot. Empty context must remain explicitly insufficient and cannot fabricate priorities.';
