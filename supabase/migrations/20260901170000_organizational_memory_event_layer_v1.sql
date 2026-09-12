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
