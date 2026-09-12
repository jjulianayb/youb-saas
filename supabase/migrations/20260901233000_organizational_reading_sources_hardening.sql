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
