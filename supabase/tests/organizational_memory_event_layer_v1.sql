-- youB — Organizational Memory + Event Layer V1 dedicated QA suite
-- Disposable staging only. Transactional fixtures, fail-fast assertions, no migration execution.
begin;
create temp table ctx(key text primary key, value uuid not null) on commit drop;
do $$ declare k text; begin
  foreach k in array array['organizational_memory_relations','organizational_events','organizational_event_types','organizational_memory_entity_types'] loop
    if to_regclass('public.'||k) is null then raise exception 'missing Organizational Memory/Event prerequisite: %', k; end if;
  end loop;
  if (select count(*) from auth.users) < 5 then raise exception 'suite requires five auth users'; end if;
end $$;
insert into ctx values
 ('org_a','11111111-1111-1111-1111-111111111111'),('org_b','22222222-2222-2222-2222-222222222222'),
 ('employee_a','11111111-0000-0000-0000-000000000001'),('employee_b','22222222-0000-0000-0000-000000000001'),
 ('fact_a','11111111-0000-0000-0000-000000000031'),('hypothesis_a','11111111-0000-0000-0000-000000000032'),
 ('relation_a','11111111-0000-0000-0000-000000000033'),('relation_a_next','11111111-0000-0000-0000-000000000034'),('relation_sensitive','11111111-0000-0000-0000-000000000038'),
 ('event_a','11111111-0000-0000-0000-000000000035'),('event_sensitive','11111111-0000-0000-0000-000000000039'),('event_b_probe','22222222-0000-0000-0000-000000000036');
insert into ctx select 'user_'||row_number() over(order by created_at),id from auth.users order by created_at limit 5;
insert into public.organizations(id,name,slug,plan,status) values
 ((select value from ctx where key='org_a'),'Memory Event A','memory-event-a','essencial','active'),
 ((select value from ctx where key='org_b'),'Memory Event B','memory-event-b','essencial','active');
insert into public.memberships(organization_id,user_id,role) values
 ((select value from ctx where key='org_a'),(select value from ctx where key='user_1'),'admin_youb'),
 ((select value from ctx where key='org_a'),(select value from ctx where key='user_2'),'diretoria'),
 ((select value from ctx where key='org_a'),(select value from ctx where key='user_3'),'gestor'),
 ((select value from ctx where key='org_a'),(select value from ctx where key='user_4'),'colaborador'),
 ((select value from ctx where key='org_a'),(select value from ctx where key='user_5'),'rh');
insert into public.employees(id,organization_id,auth_user_id,full_name,email,manager_employee_id) values
 ((select value from ctx where key='employee_a'),(select value from ctx where key='org_a'),null,'Memory Employee A','memory-a@example.invalid',null),
 ((select value from ctx where key='employee_b'),(select value from ctx where key='org_b'),null,'Memory Employee B','memory-b@example.invalid',null);

create or replace function pg_temp.assert_true(label text, condition boolean) returns void language plpgsql as $$ begin if condition is distinct from true then raise exception 'FAIL-FAST assertion: %',label; end if; end; $$;

-- Controlled catalog vocabulary: extensible only through explicit catalog changes.
select pg_temp.assert_true('entity vocabulary includes epistemic kinds',
  (select count(*) from public.organizational_memory_entity_types where entity_type in ('fact','declaration','reading','hypothesis','decision','intervention','outcome')) = 7);
select pg_temp.assert_true('event vocabulary includes core events',
  (select count(*) from public.organizational_event_types where event_type in ('employee_created','employee_status_changed','area_changed','position_changed','manager_changed','feedback_recorded','checkin_recorded','pdi_created','pdi_updated','assessment_recorded','learning_assigned','learning_completed','organizational_reading_created','recommendation_created','decision_recorded','intervention_created','action_created','action_completed','outcome_recorded')) = 19);
select pg_temp.assert_true('event vocabulary includes future training contracts',
  (select count(*) from public.organizational_event_types where event_type in ('training_assigned','training_scheduled','training_completed','training_expiring','training_expired','recertification_scheduled') and implemented = false) = 6);
select pg_temp.assert_true('event type arbitrary text rejected',not exists(select 1 from public.organizational_event_types where event_type='arbitrary_silent_event'));

-- Structurally valid tenant-A memory records, with explicit epistemic distinction.
insert into public.organizational_memory_relations(id,organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,recorded_at,source_type,source_id,sensitivity,context) values
 ((select value from ctx where key='relation_a'),(select value from ctx where key='org_a'),'fact',(select value from ctx where key='fact_a'),'employee',(select value from ctx where key='employee_a'),'concerns','fact','2026-01-01 00:00:00+00','2026-01-02 00:00:00+00','manual','qa-fact','standard','{"kind":"fact"}'),
 ((select value from ctx where key='relation_a_next'),(select value from ctx where key='org_a'),'hypothesis',(select value from ctx where key='hypothesis_a'),'employee',(select value from ctx where key='employee_a'),'concerns','hypothesis','2026-02-01 00:00:00+00','2026-02-02 00:00:00+00','manual','qa-hypothesis','restricted','{"kind":"hypothesis"}'),
 ((select value from ctx where key='relation_sensitive'),(select value from ctx where key='org_a'),'decision',(select value from ctx where key='fact_a'),'employee',(select value from ctx where key='employee_a'),'concerns','derived','2026-01-05 00:00:00+00','2026-01-06 00:00:00+00','manual','qa-sensitive','highly_sensitive','{"kind":"sensitive"}');
select pg_temp.assert_true('fact remains distinct from hypothesis',
  (select count(*) from public.organizational_memory_relations where organization_id=(select value from ctx where key='org_a') and knowledge_kind='fact')=1
  and (select count(*) from public.organizational_memory_relations where organization_id=(select value from ctx where key='org_a') and knowledge_kind='hypothesis')=1
  and not exists(select 1 from public.organizational_memory_relations where knowledge_kind='hypothesis' and source_entity_type='fact'));

-- Temporal history: close the old relation and insert a new one; neither record is overwritten.
update public.organizational_memory_relations set valid_until='2026-01-31 23:59:59+00' where id=(select value from ctx where key='relation_a');
insert into public.organizational_memory_relations(organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,source_type,source_id,sensitivity,context) values
 ((select value from ctx where key='org_a'),'fact',(select value from ctx where key='fact_a'),'employee',(select value from ctx where key='employee_a'),'concerns','observed','2026-02-01 00:00:00+00','service','qa-history-next','standard','{"history":"new interval"}');
select pg_temp.assert_true('temporal validity preserves old and new history',
  (select valid_until from public.organizational_memory_relations where id=(select value from ctx where key='relation_a'))='2026-01-31 23:59:59+00'
  and (select count(*) from public.organizational_memory_relations where source_id in ('qa-fact','qa-history-next'))=2);

create or replace function pg_temp.invalid_relation_window() returns boolean language plpgsql security invoker as $$ begin begin insert into public.organizational_memory_relations(organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,valid_until,source_type,context) values((select value from ctx where key='org_a'),'fact',(select value from ctx where key='fact_a'),'employee',(select value from ctx where key='employee_a'),'related_to','fact','2026-03-02','2026-03-01','manual','{}'); return false; exception when others then return true; end; end; $$;
create or replace function pg_temp.invalid_relation_json() returns boolean language plpgsql security invoker as $$ begin begin insert into public.organizational_memory_relations(organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,source_type,context) values((select value from ctx where key='org_a'),'fact',(select value from ctx where key='fact_a'),'employee',(select value from ctx where key='employee_a'),'related_to','fact','2026-03-01','manual','[]'); return false; exception when others then return true; end; end; $$;
create or replace function pg_temp.invalid_relation_vocab() returns boolean language plpgsql security invoker as $$ begin begin insert into public.organizational_memory_relations(organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,source_type,context) values((select value from ctx where key='org_a'),'not_a_type',(select value from ctx where key='fact_a'),'employee',(select value from ctx where key='employee_a'),'related_to','not_a_kind','2026-03-01','manual','{}'); return false; exception when others then return true; end; end; $$;
select pg_temp.assert_true('invalid temporal window rejected',pg_temp.invalid_relation_window());
select pg_temp.assert_true('relation context must be JSON object',pg_temp.invalid_relation_json());
select pg_temp.assert_true('invalid entity and knowledge vocab rejected',pg_temp.invalid_relation_vocab());

-- Structurally valid append-oriented tenant-A event.
insert into public.organizational_events(id,organization_id,event_type,entity_type,entity_id,related_entity_type,related_entity_id,occurred_at,recorded_at,source_type,source_id,actor_user_id,sensitivity,payload,correlation_id) values
 ((select value from ctx where key='event_a'),(select value from ctx where key='org_a'),'employee_created','employee',(select value from ctx where key='employee_a'),'organization',(select value from ctx where key='org_a'),'2026-01-03 00:00:00+00','2026-01-04 00:00:00+00','manual','qa-event',(select value from ctx where key='user_1'),'standard','{"status":"created"}','11111111-0000-0000-0000-000000000037'),
 ((select value from ctx where key='event_sensitive'),(select value from ctx where key='org_a'),'decision_recorded','decision',(select value from ctx where key='fact_a'),null,null,'2026-01-05 00:00:00+00','2026-01-06 00:00:00+00','manual','qa-sensitive-event',(select value from ctx where key='user_1'),'highly_sensitive','{"status":"sensitive"}',null);
select pg_temp.assert_true('event records occurrence and structured payload',
  (select payload->>'status' from public.organizational_events where id=(select value from ctx where key='event_a'))='created');

create or replace function pg_temp.invalid_event_payload() returns boolean language plpgsql security invoker as $$ begin begin insert into public.organizational_events(organization_id,event_type,entity_type,entity_id,occurred_at,source_type,payload) values((select value from ctx where key='org_a'),'employee_created','employee',(select value from ctx where key='employee_a'),'2026-03-01','manual','[]'); return false; exception when others then return true; end; end; $$;
create or replace function pg_temp.invalid_event_vocab() returns boolean language plpgsql security invoker as $$ begin begin insert into public.organizational_events(organization_id,event_type,entity_type,entity_id,occurred_at,source_type,payload) values((select value from ctx where key='org_a'),'arbitrary_silent_event','employee',(select value from ctx where key='employee_a'),'2026-03-01','manual','{}'); return false; exception when others then return true; end; end; $$;
create or replace function pg_temp.invalid_event_sensitivity() returns boolean language plpgsql security invoker as $$ begin begin insert into public.organizational_events(organization_id,event_type,entity_type,entity_id,occurred_at,source_type,sensitivity,payload) values((select value from ctx where key='org_a'),'employee_created','employee',(select value from ctx where key='employee_a'),'2026-03-01','manual','secret','{}'); return false; exception when others then return true; end; end; $$;
select pg_temp.assert_true('event payload must be JSON object',pg_temp.invalid_event_payload());
select pg_temp.assert_true('event type catalog rejects arbitrary text',pg_temp.invalid_event_vocab());
select pg_temp.assert_true('event sensitivity vocabulary rejects arbitrary text',pg_temp.invalid_event_sensitivity());

select pg_temp.assert_true('event activation witness has true default',
  (select column_default from information_schema.columns where table_schema='public' and table_name='organizational_events' and column_name='event_type_implemented') in ('true','true::boolean'));
select pg_temp.assert_true('event activation witness CHECK exists',exists(select 1 from pg_constraint where conrelid='public.organizational_events'::regclass and conname='organizational_events_event_type_implemented_check'));
select pg_temp.assert_true('event activation witness composite FK exists',exists(select 1 from pg_constraint where conrelid='public.organizational_events'::regclass and conname='organizational_events_event_type_implemented_fkey'));

-- Authorized writer probes use valid entity, source, payload and tenant data.
create or replace function pg_temp.training_event_rejected(candidate text) returns boolean language plpgsql security invoker as $$ declare msg text; begin
  begin
    insert into public.organizational_events(organization_id,event_type,entity_type,entity_id,occurred_at,source_type,actor_user_id,sensitivity,payload)
    values((select value from ctx where key='org_a'),candidate,'employee',(select value from ctx where key='employee_a'),'2026-05-01','manual',(select value from ctx where key='user_5'),'standard','{}');
    return false;
  exception when others then get stacked diagnostics msg=message_text; return msg ilike '%foreign key%' or msg ilike '%check constraint%';
  end;
end; $$;
create or replace function pg_temp.rh_memory_insert_and_close() returns boolean language plpgsql security invoker as $$ declare relation_id uuid := '11111111-0000-0000-0000-000000000040'; begin
  insert into public.organizational_memory_relations(id,organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,source_type,source_id,sensitivity,context)
  values(relation_id,(select value from ctx where key='org_a'),'decision',(select value from ctx where key='fact_a'),'employee',(select value from ctx where key='employee_a'),'concerns','declared','2026-05-01','manual','qa-rh-memory','standard','{}');
  update public.organizational_memory_relations set valid_until='2026-05-31 23:59:59+00' where id=relation_id;
  return (select valid_until='2026-05-31 23:59:59+00' from public.organizational_memory_relations where id=relation_id);
end; $$;
create or replace function pg_temp.rh_event_insert_ok() returns boolean language plpgsql security invoker as $$ declare event_id uuid := '11111111-0000-0000-0000-000000000041'; begin
  insert into public.organizational_events(id,organization_id,event_type,entity_type,entity_id,occurred_at,source_type,actor_user_id,sensitivity,payload)
  values(event_id,(select value from ctx where key='org_a'),'decision_recorded','decision',(select value from ctx where key='fact_a'),'2026-05-01','manual',(select value from ctx where key='user_5'),'standard','{}');
  return exists(select 1 from public.organizational_events where id=event_id);
end; $$;
create or replace function pg_temp.memory_insert_denied_probe() returns boolean language plpgsql security invoker as $$ declare msg text; begin
  begin
    insert into public.organizational_memory_relations(organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,source_type,sensitivity,context)
    values((select value from ctx where key='org_a'),'fact',(select value from ctx where key='fact_a'),'employee',(select value from ctx where key='employee_a'),'concerns','fact','2026-06-01','manual','standard','{}');
    return false;
  exception when others then get stacked diagnostics msg=message_text; return msg ilike '%row-level security%';
  end;
end; $$;
create or replace function pg_temp.event_insert_denied_probe() returns boolean language plpgsql security invoker as $$ declare msg text; begin
  begin
    insert into public.organizational_events(organization_id,event_type,entity_type,entity_id,occurred_at,source_type,sensitivity,payload)
    values((select value from ctx where key='org_a'),'decision_recorded','decision',(select value from ctx where key='fact_a'),'2026-06-01','manual','standard','{}');
    return false;
  exception when others then get stacked diagnostics msg=message_text; return msg ilike '%row-level security%';
  end;
end; $$;

create or replace function pg_temp.memory_cross_tenant_rls_probe() returns boolean language plpgsql security invoker as $$ declare msg text; begin begin insert into public.organizational_memory_relations(organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,source_type,sensitivity,context) values((select value from ctx where key='org_b'),'fact',(select value from ctx where key='employee_b'),'employee',(select value from ctx where key='employee_b'),'concerns','fact','2026-04-01','manual','standard','{}'); return false; exception when others then get stacked diagnostics msg=message_text; return msg ilike '%row-level security%' or msg ilike '%permission denied%'; end; end; $$;
create or replace function pg_temp.event_cross_tenant_rls_probe() returns boolean language plpgsql security invoker as $$ declare msg text; begin begin insert into public.organizational_events(id,organization_id,event_type,entity_type,entity_id,occurred_at,source_type,sensitivity,payload) values((select value from ctx where key='event_b_probe'),(select value from ctx where key='org_b'),'employee_created','employee',(select value from ctx where key='employee_b'),'2026-04-01','manual','standard','{}'); return false; exception when others then get stacked diagnostics msg=message_text; return msg ilike '%row-level security%' or msg ilike '%permission denied%'; end; end; $$;

set local role authenticated;
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_1'),true);
select pg_temp.assert_true('admin cross-tenant memory write denied',pg_temp.memory_cross_tenant_rls_probe());
select pg_temp.assert_true('admin cross-tenant event write denied',pg_temp.event_cross_tenant_rls_probe());
select pg_temp.assert_true('admin reads own memory',exists(select 1 from public.organizational_memory_relations where organization_id=(select value from ctx where key='org_a')));
select pg_temp.assert_true('admin reads own events',exists(select 1 from public.organizational_events where organization_id=(select value from ctx where key='org_a')));

-- Append-only event contract: no update/delete grant is exposed in V1.
create or replace function pg_temp.event_update_denied() returns boolean language plpgsql security invoker as $$ declare affected bigint; begin begin update public.organizational_events set payload='{"changed":true}' where id=(select value from ctx where key='event_a'); get diagnostics affected = row_count; return affected = 0; exception when others then return true; end; end; $$;
create or replace function pg_temp.event_delete_denied() returns boolean language plpgsql security invoker as $$ begin begin delete from public.organizational_events where id=(select value from ctx where key='event_a'); return false; exception when others then return true; end; end; $$;
select pg_temp.assert_true('event update is denied to preserve occurrence history',pg_temp.event_update_denied());
select pg_temp.assert_true('event delete is denied to preserve occurrence history',pg_temp.event_delete_denied());

select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_2'),true);
select pg_temp.assert_true('diretoria reads standard organizational memory',exists(select 1 from public.organizational_memory_relations where organization_id=(select value from ctx where key='org_a') and sensitivity='standard'));
select pg_temp.assert_true('diretoria does not read highly sensitive memory',not exists(select 1 from public.organizational_memory_relations where organization_id=(select value from ctx where key='org_a') and sensitivity='highly_sensitive'));
select pg_temp.assert_true('diretoria reads standard events',exists(select 1 from public.organizational_events where organization_id=(select value from ctx where key='org_a') and sensitivity='standard'));

select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_2'),true);
select pg_temp.assert_true('diretoria cannot insert memory',pg_temp.memory_insert_denied_probe());
select pg_temp.assert_true('diretoria cannot insert event',pg_temp.event_insert_denied_probe());

select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_3'),true);
select pg_temp.assert_true('gestor cannot insert memory',pg_temp.memory_insert_denied_probe());
select pg_temp.assert_true('gestor cannot insert event',pg_temp.event_insert_denied_probe());
select pg_temp.assert_true('gestor has no generic memory read',not exists(select 1 from public.organizational_memory_relations where organization_id=(select value from ctx where key='org_a')));
select pg_temp.assert_true('gestor has no generic event read',not exists(select 1 from public.organizational_events where organization_id=(select value from ctx where key='org_a')));
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_4'),true);
select pg_temp.assert_true('colaborador cannot insert memory',pg_temp.memory_insert_denied_probe());
select pg_temp.assert_true('colaborador cannot insert event',pg_temp.event_insert_denied_probe());
select pg_temp.assert_true('colaborador has no generic memory read',not exists(select 1 from public.organizational_memory_relations where organization_id=(select value from ctx where key='org_a')));
select pg_temp.assert_true('colaborador has no generic event read',not exists(select 1 from public.organizational_events where organization_id=(select value from ctx where key='org_a')));

select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_5'),true);
select pg_temp.assert_true('RH can insert and close own memory relation',pg_temp.rh_memory_insert_and_close());
select pg_temp.assert_true('RH can insert valid own event',pg_temp.rh_event_insert_ok());
select pg_temp.assert_true('RH manages own memory',exists(select 1 from public.organizational_memory_relations where organization_id=(select value from ctx where key='org_a')));
select pg_temp.assert_true('RH reads own events',exists(select 1 from public.organizational_events where organization_id=(select value from ctx where key='org_a')));

-- Future Training Compliance contracts remain visible but cannot be recorded.
select pg_temp.assert_true('training_assigned is inactive and rejected',pg_temp.training_event_rejected('training_assigned'));
select pg_temp.assert_true('training_scheduled is inactive and rejected',pg_temp.training_event_rejected('training_scheduled'));
select pg_temp.assert_true('training_completed is inactive and rejected',pg_temp.training_event_rejected('training_completed'));
select pg_temp.assert_true('training_expiring is inactive and rejected',pg_temp.training_event_rejected('training_expiring'));
select pg_temp.assert_true('training_expired is inactive and rejected',pg_temp.training_event_rejected('training_expired'));
select pg_temp.assert_true('recertification_scheduled is inactive and rejected',pg_temp.training_event_rejected('recertification_scheduled'));
select pg_temp.assert_true('RH cannot read cross-tenant memory',not exists(select 1 from public.organizational_memory_relations where organization_id=(select value from ctx where key='org_b')));
select pg_temp.assert_true('RH cannot read cross-tenant events',not exists(select 1 from public.organizational_events where organization_id=(select value from ctx where key='org_b')));

-- No automatic capture or replay machinery is created by this V1.
select pg_temp.assert_true('no user trigger on memory/event tables',not exists(select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('organizational_memory_relations','organizational_events') and not t.tgisinternal));
select pg_temp.assert_true('no raw conversation or prompt columns',not exists(select 1 from information_schema.columns where table_schema='public' and table_name in ('organizational_memory_relations','organizational_events') and column_name in ('conversation','raw_conversation','prompt','raw_prompt','message')));
rollback;
