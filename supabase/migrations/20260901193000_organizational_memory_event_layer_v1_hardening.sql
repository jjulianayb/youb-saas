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
