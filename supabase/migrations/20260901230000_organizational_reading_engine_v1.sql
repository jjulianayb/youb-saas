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
