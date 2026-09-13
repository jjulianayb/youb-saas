-- Data Architecture 2.0 P0 event capture contract tests.
-- All fixtures are fictitious and rolled back.
begin;

create temp table p0_auth_users as
select id, row_number() over (order by created_at, id) as n
from auth.users
limit 3;
do $$ begin if (select count(*) from p0_auth_users) < 3 then raise exception 'P0 suite requires three auth users'; end if; end $$;
grant select on p0_auth_users to authenticated;

insert into public.organizations(id,name,slug,plan,status) values
 ('e9000000-0000-0000-0000-000000000001','P0 Event Org','p0-event-org','essencial','active');
insert into public.memberships(organization_id,user_id,role)
select 'e9000000-0000-0000-0000-000000000001',id,case when p0_auth_users.n=1 then 'admin_youb' when p0_auth_users.n=2 then 'rh' else 'diretoria' end
from p0_auth_users;
insert into public.organizations(id,name,slug,plan,status) values
 ('e9000000-0000-0000-0000-000000000002','P0 Other Org','p0-other-org','essencial','active');
insert into public.employees(id,organization_id,auth_user_id,full_name,email,status) values
 ('e9000000-0000-0000-0000-000000000011','e9000000-0000-0000-0000-000000000001',(select id from p0_auth_users where p0_auth_users.n=1),'P0 Admin','p0-admin@example.invalid','active'),
 ('e9000000-0000-0000-0000-000000000012','e9000000-0000-0000-0000-000000000001',(select id from p0_auth_users where p0_auth_users.n=2),'P0 Manager One','p0-manager-one@example.invalid','active'),
 ('e9000000-0000-0000-0000-000000000013','e9000000-0000-0000-0000-000000000001',null,'P0 Employee','p0-employee@example.invalid','active'),
 ('e9000000-0000-0000-0000-000000000021','e9000000-0000-0000-0000-000000000002',null,'Other Employee','other@example.invalid','active');
insert into public.areas(id,organization_id,name) values
 ('e9000000-0000-0000-0000-000000000101','e9000000-0000-0000-0000-000000000001','Area One'),
 ('e9000000-0000-0000-0000-000000000102','e9000000-0000-0000-0000-000000000001','Area Two'),
 ('e9000000-0000-0000-0000-000000000111','e9000000-0000-0000-0000-000000000002','Other Area');
insert into public.positions(id,organization_id,name,level) values
 ('e9000000-0000-0000-0000-000000000201','e9000000-0000-0000-0000-000000000001','Position One','Pleno'),
 ('e9000000-0000-0000-0000-000000000202','e9000000-0000-0000-0000-000000000001','Position Two','Sênior'),
 ('e9000000-0000-0000-0000-000000000211','e9000000-0000-0000-0000-000000000002','Other Position','Pleno');
insert into public.competencies(id,organization_id,name,active) values
 ('e9000000-0000-0000-0000-000000000301','e9000000-0000-0000-0000-000000000001','Competency One',true);
insert into public.position_competencies(id,organization_id,position_id,competency_id,expected_level,active) values
 ('e9000000-0000-0000-0000-000000000401','e9000000-0000-0000-0000-000000000001','e9000000-0000-0000-0000-000000000201','e9000000-0000-0000-0000-000000000301',2,true);
insert into public.cycles(id,organization_id,name,cycle_type,status) values
 ('e9000000-0000-0000-0000-000000000501','e9000000-0000-0000-0000-000000000001','P0 Cycle','performance','active');
insert into public.assessments(id,organization_id,cycle_id,subject_employee_id,evaluator_employee_id,position_id,status) values
 ('e9000000-0000-0000-0000-000000000601','e9000000-0000-0000-0000-000000000001','e9000000-0000-0000-0000-000000000501','e9000000-0000-0000-0000-000000000013','e9000000-0000-0000-0000-000000000012','e9000000-0000-0000-0000-000000000201','draft');
insert into public.assessment_competency_scores(id,organization_id,assessment_id,competency_id,position_competency_id,expected_level_snapshot) values
 ('e9000000-0000-0000-0000-000000000701','e9000000-0000-0000-0000-000000000001','e9000000-0000-0000-0000-000000000601','e9000000-0000-0000-0000-000000000301','e9000000-0000-0000-0000-000000000401',2);
insert into public.intelligence_interventions(id,organization_id,employee_id,intervention_type,title,status) values
 ('e9000000-0000-0000-0000-000000000801','e9000000-0000-0000-0000-000000000001','e9000000-0000-0000-0000-000000000013','development','P0 Intervention','approved');
insert into public.intelligence_actions(id,organization_id,intervention_id,action_type,title,status,assignee_employee_id) values
 ('e9000000-0000-0000-0000-000000000901','e9000000-0000-0000-0000-000000000001','e9000000-0000-0000-0000-000000000801','development','P0 Action','proposed','e9000000-0000-0000-0000-000000000013');

-- Existing temporal state is represented by prior graph intervals.
insert into public.organizational_memory_relations(
 organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,source_type,source_id
) values
 ('e9000000-0000-0000-0000-000000000001','employee','e9000000-0000-0000-0000-000000000013','area','e9000000-0000-0000-0000-000000000101','belongs_to','fact','2026-01-01','service','fixture'),
 ('e9000000-0000-0000-0000-000000000001','employee','e9000000-0000-0000-0000-000000000013','position','e9000000-0000-0000-0000-000000000201','occupies','fact','2026-01-01','service','fixture'),
 ('e9000000-0000-0000-0000-000000000001','employee','e9000000-0000-0000-0000-000000000013','employee','e9000000-0000-0000-0000-000000000012','reports_to','fact','2026-01-01','service','fixture');

create or replace function pg_temp.p0_fail_employee_created_event() returns trigger
language plpgsql as $$
begin
  if current_setting('p0.force_employee_create_failure',true)='on' and new.event_type='employee_created' then
    raise exception 'p0 forced employee event failure';
  end if;
  return new;
end;
$$;
create trigger p0_fail_employee_created_event
before insert on public.organizational_events
for each row execute function pg_temp.p0_fail_employee_created_event();

select set_config('request.jwt.claim.sub',(select id::text from p0_auth_users where p0_auth_users.n=1),true);
set local role authenticated;

select public.update_employee_profile(
 'e9000000-0000-0000-0000-000000000013','P0 Employee Updated','updated@example.invalid',
 'e9000000-0000-0000-0000-000000000102','e9000000-0000-0000-0000-000000000202','senior',
 'e9000000-0000-0000-0000-000000000011','inactive'
);

do $$
declare n bigint;
begin
 select count(*) into n from public.organizational_events where organization_id='e9000000-0000-0000-0000-000000000001' and entity_id='e9000000-0000-0000-0000-000000000013' and event_type in ('employee_status_changed','area_changed','position_changed','manager_changed');
 if n<>4 then raise exception 'employee structural event count expected 4, got %',n; end if;
 if (select count(*) from public.organizational_memory_relations where organization_id='e9000000-0000-0000-0000-000000000001' and source_entity_id='e9000000-0000-0000-0000-000000000013' and relationship_type in ('belongs_to','occupies','reports_to') and valid_until is null)<>3 then raise exception 'current employee relation projection is incomplete'; end if;
 if (select count(*) from public.organizational_memory_relations where organization_id='e9000000-0000-0000-0000-000000000001' and source_entity_id='e9000000-0000-0000-0000-000000000013' and relationship_type in ('belongs_to','occupies','reports_to') and valid_until is not null)<>3 then raise exception 'prior employee relation intervals were not closed'; end if;
 if exists(select 1 from public.organizational_events where entity_id='e9000000-0000-0000-0000-000000000013' and actor_user_id<>(select id from p0_auth_users where p0_auth_users.n=1)) then raise exception 'event actor was not derived from auth.uid()'; end if;
end $$;

-- Idempotent profile replay does not duplicate events.
select public.update_employee_profile(
 'e9000000-0000-0000-0000-000000000013','P0 Employee Updated','updated@example.invalid',
 'e9000000-0000-0000-0000-000000000102','e9000000-0000-0000-0000-000000000202','senior',
 'e9000000-0000-0000-0000-000000000011','inactive'
);
do $$ begin if (select count(*) from public.organizational_events where entity_id='e9000000-0000-0000-0000-000000000013')<>4 then raise exception 'idempotent profile replay duplicated events'; end if; end $$;

-- Creation is a controlled domain operation with a single event and initial graph projection.
do $$
declare
  v_created public.employees%rowtype;
  v_retry public.employees%rowtype;
  v_event public.organizational_events%rowtype;
  v_before timestamptz := clock_timestamp();
  v_correlation uuid := 'e9000000-0000-0000-0000-000000009901';
begin
  select * into strict v_created from public.create_employee_profile(
    'e9000000-0000-0000-0000-000000000001','P0 Created Employee',null,
    'e9000000-0000-0000-0000-000000000102','e9000000-0000-0000-0000-000000000202',
    'senior','e9000000-0000-0000-0000-000000000012','active',v_correlation
  );
  if v_created.auth_user_id is not null then raise exception 'employee creation unexpectedly required an Auth user'; end if;
  if v_created.created_at < v_before then raise exception 'created_at predates the creation operation'; end if;
  if (select count(*) from public.organizational_events where entity_id=v_created.id and event_type='employee_created')<>1 then raise exception 'employee creation did not generate exactly one employee_created event'; end if;
  select * into strict v_event from public.organizational_events where entity_id=v_created.id and event_type='employee_created';
  if v_event.actor_user_id<>(select id from p0_auth_users where p0_auth_users.n=1) then raise exception 'employee_created actor was not derived from auth.uid()'; end if;
  if v_event.correlation_id<>v_correlation then raise exception 'employee_created correlation_id was not preserved'; end if;
  if v_event.occurred_at < v_before or v_event.occurred_at > clock_timestamp() then raise exception 'employee_created occurred_at is outside the creation interval'; end if;
  if v_event.payload ? 'full_name' or v_event.payload ? 'email' then raise exception 'employee_created payload contains unnecessary PII'; end if;
  if not (v_event.payload ? 'status' and v_event.payload ? 'area_id' and v_event.payload ? 'position_id' and v_event.payload ? 'manager_employee_id' and v_event.payload ? 'seniority') then raise exception 'employee_created payload is missing contract fields'; end if;
  if (select count(*) from public.organizational_memory_relations where source_entity_id=v_created.id and valid_until is null)<>3 then raise exception 'initial employee relations are incomplete'; end if;
  if not exists(select 1 from public.organizational_memory_relations where source_entity_id=v_created.id and relationship_type='belongs_to' and target_entity_id='e9000000-0000-0000-0000-000000000102' and valid_from=v_event.occurred_at and source_id=v_event.id::text) then raise exception 'initial belongs_to relation is missing or misdated'; end if;
  if not exists(select 1 from public.organizational_memory_relations where source_entity_id=v_created.id and relationship_type='occupies' and target_entity_id='e9000000-0000-0000-0000-000000000202' and valid_from=v_event.occurred_at and source_id=v_event.id::text) then raise exception 'initial occupies relation is missing or misdated'; end if;
  if not exists(select 1 from public.organizational_memory_relations where source_entity_id=v_created.id and relationship_type='reports_to' and target_entity_id='e9000000-0000-0000-0000-000000000012' and valid_from=v_event.occurred_at and source_id=v_event.id::text) then raise exception 'initial reports_to relation is missing or misdated'; end if;
  select * into strict v_retry from public.create_employee_profile(
    'e9000000-0000-0000-0000-000000000001','P0 Created Employee Retry','should-not-be-used@example.invalid',
    'e9000000-0000-0000-0000-000000000101','e9000000-0000-0000-0000-000000000201',
    'junior','e9000000-0000-0000-0000-000000000012','inactive',v_correlation
  );
  if v_retry.id<>v_created.id then raise exception 'creation retry was not idempotent'; end if;
  if (select count(*) from public.organizational_events where entity_id=v_created.id and event_type='employee_created')<>1 then raise exception 'creation retry duplicated employee_created'; end if;
end $$;

-- Authorization contract: the existing RLS contract permits diretoria to manage people,
-- so the domain RPCs preserve create and edit for diretoria (not an expansion).
do $$
declare v_directoria public.employees%rowtype; v_updated public.employees%rowtype; v_directoria_id uuid;
begin
  select id into v_directoria_id from p0_auth_users where p0_auth_users.n=3;
  perform set_config('request.jwt.claim.sub',v_directoria_id::text,true);
  select * into strict v_directoria from public.create_employee_profile('e9000000-0000-0000-0000-000000000001','P0 Diretoria Employee',null,null,null,null,null,'active','e9000000-0000-0000-0000-000000009903');
  select * into strict v_updated from public.update_employee_profile(v_directoria.id,'P0 Diretoria Employee Updated',null,null,null,null,null,'inactive');
  if v_updated.status<>'inactive' then raise exception 'diretoria employee edit was not authorized'; end if;
  if (select actor_user_id from public.organizational_events where entity_id=v_directoria.id and event_type='employee_created')<>v_directoria_id then raise exception 'diretoria create actor mismatch'; end if;
  perform set_config('request.jwt.claim.sub',(select id::text from p0_auth_users where p0_auth_users.n=1),true);
end $$;

create or replace function pg_temp.try_create_employee(p_org uuid,p_area uuid,p_position uuid,p_manager uuid) returns boolean
language plpgsql security invoker as $$
begin
  perform public.create_employee_profile(p_org,'P0 Invalid Create',null,p_area,p_position,null,p_manager,'active',gen_random_uuid());
  return true;
exception when others then return false;
end $$;
do $$ begin
  if pg_temp.try_create_employee('e9000000-0000-0000-0000-000000000001','e9000000-0000-0000-0000-000000000111',null,null) then raise exception 'cross-tenant area was accepted during employee creation'; end if;
  if pg_temp.try_create_employee('e9000000-0000-0000-0000-000000000001',null,'e9000000-0000-0000-0000-000000000211',null) then raise exception 'cross-tenant position was accepted during employee creation'; end if;
  if pg_temp.try_create_employee('e9000000-0000-0000-0000-000000000001',null,null,'e9000000-0000-0000-0000-000000000021') then raise exception 'cross-tenant manager was accepted during employee creation'; end if;
end $$;

-- A failure after the employee insert rolls back the employee and event together.
do $$
declare v_failed boolean := false; v_email text := 'p0-rollback@example.invalid';
begin
  perform set_config('p0.force_employee_create_failure','on',true);
  begin
    perform public.create_employee_profile('e9000000-0000-0000-0000-000000000001','P0 Rollback Employee',v_email,null,null,null,null,'active','e9000000-0000-0000-0000-000000009902');
  exception when others then v_failed := true;
  end;
  perform set_config('p0.force_employee_create_failure','off',true);
  if not v_failed then raise exception 'forced event failure was not raised'; end if;
  if exists(select 1 from public.employees where email=v_email) then raise exception 'employee survived event failure'; end if;
  if exists(select 1 from public.organizational_events where source_id='create_employee_profile' and correlation_id='e9000000-0000-0000-0000-000000009902') then raise exception 'employee_created event survived rollback'; end if;
end $$;

create or replace function pg_temp.try_direct_employee_insert() returns boolean
language plpgsql security invoker as $$
begin
  insert into public.employees(organization_id,full_name,status) values('e9000000-0000-0000-0000-000000000001','P0 Direct Insert Must Fail','active');
  return true;
exception when others then return false;
end $$;
do $$ begin if pg_temp.try_direct_employee_insert() then raise exception 'direct employee INSERT bypassed create_employee_profile'; end if; end $$;

-- Direct employee update is blocked; cross-tenant domain update is blocked without changing state.
create or replace function pg_temp.try_direct_employee_update() returns boolean language plpgsql security invoker as $$ begin update public.employees set status='active' where id='e9000000-0000-0000-0000-000000000013'; return true; exception when others then return false; end $$;
select pg_temp.try_direct_employee_update() as direct_employee_update_allowed;
do $$ begin if pg_temp.try_direct_employee_update() then raise exception 'direct employee mutation bypassed domain RPC'; end if; end $$;
create or replace function pg_temp.try_cross_tenant_profile() returns boolean language plpgsql security invoker as $$ begin perform public.update_employee_profile('e9000000-0000-0000-0000-000000000013','forbidden','forbidden@example.invalid',null,null,'senior','e9000000-0000-0000-0000-000000000021','active'); return true; exception when others then return false; end $$;
do $$ begin if pg_temp.try_cross_tenant_profile() then raise exception 'cross-tenant profile mutation was accepted'; end if; if (select status from public.employees where id='e9000000-0000-0000-0000-000000000013')<>'inactive' then raise exception 'failed cross-tenant mutation changed state'; end if; end $$;

select public.cca_update_position_competency('e9000000-0000-0000-0000-000000000401',3::smallint,true);
select public.cca_save_assessment_score('e9000000-0000-0000-0000-000000000601','e9000000-0000-0000-0000-000000000301',2::smallint,'first score');
select public.cca_save_assessment_score('e9000000-0000-0000-0000-000000000601','e9000000-0000-0000-0000-000000000301',3::smallint,'changed score');
do $$ begin
 if (select count(*) from public.organizational_events where event_type='competency_expected_level_changed')<>1 then raise exception 'expected level event missing'; end if;
 if (select count(*) from public.organizational_events where event_type='competency_score_changed')<>2 then raise exception 'score change events missing'; end if;
end $$;

select public.intelligence_start_intervention('e9000000-0000-0000-0000-000000000801');
select public.intelligence_start_intervention('e9000000-0000-0000-0000-000000000801');
select public.intelligence_complete_intervention('e9000000-0000-0000-0000-000000000801');
select public.intelligence_complete_intervention('e9000000-0000-0000-0000-000000000801');
select public.intelligence_start_action('e9000000-0000-0000-0000-000000000901');
select public.intelligence_start_action('e9000000-0000-0000-0000-000000000901');
select public.intelligence_complete_action('e9000000-0000-0000-0000-000000000901');
select public.intelligence_complete_action('e9000000-0000-0000-0000-000000000901');
do $$ begin
 if (select count(*) from public.organizational_events where event_type='intervention_started')<>1 then raise exception 'intervention start not idempotent'; end if;
 if (select count(*) from public.organizational_events where event_type='intervention_completed')<>1 then raise exception 'intervention completion not idempotent'; end if;
 if (select count(*) from public.organizational_events where event_type='action_started')<>1 then raise exception 'action start not idempotent'; end if;
 if (select count(*) from public.organizational_events where event_type='action_completed')<>1 then raise exception 'action completion not idempotent'; end if;
 if (select started_at from public.intelligence_interventions where id='e9000000-0000-0000-0000-000000000801') is null or (select completed_at from public.intelligence_interventions where id='e9000000-0000-0000-0000-000000000801') is null then raise exception 'intervention timestamps missing'; end if;
 if (select started_at from public.intelligence_actions where id='e9000000-0000-0000-0000-000000000901') is null or (select completed_at from public.intelligence_actions where id='e9000000-0000-0000-0000-000000000901') is null then raise exception 'action timestamps missing'; end if;
end $$;

create or replace function pg_temp.try_direct_intervention_update() returns boolean language plpgsql security invoker as $$ begin update public.intelligence_interventions set status='cancelled' where id='e9000000-0000-0000-0000-000000000801'; return true; exception when others then return false; end $$;
create or replace function pg_temp.try_direct_action_update() returns boolean language plpgsql security invoker as $$ begin update public.intelligence_actions set status='cancelled' where id='e9000000-0000-0000-0000-000000000901'; return true; exception when others then return false; end $$;
create or replace function pg_temp.try_event_update() returns boolean language plpgsql security invoker as $$ begin update public.organizational_events set payload='{}'::jsonb; return true; exception when others then return false; end $$;
create or replace function pg_temp.try_event_delete() returns boolean language plpgsql security invoker as $$ begin delete from public.organizational_events; return true; exception when others then return false; end $$;
do $$ begin if pg_temp.try_direct_intervention_update() or pg_temp.try_direct_action_update() then raise exception 'intervention/action lifecycle bypassed domain RPC'; end if; if pg_temp.try_event_update() or pg_temp.try_event_delete() then raise exception 'organizational_events is not append-only'; end if; if has_function_privilege('authenticated','public._append_organizational_event(uuid,text,text,uuid,timestamptz,text,text,text,jsonb,uuid,text,uuid)','execute') then raise exception 'internal event writer is exposed'; end if; end $$;

create or replace function pg_temp.try_led_to_fact() returns boolean language plpgsql security invoker as $$ begin insert into public.organizational_memory_relations(organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,source_type,source_id) values('e9000000-0000-0000-0000-000000000001','employee','e9000000-0000-0000-0000-000000000013','intervention','e9000000-0000-0000-0000-000000000801','led_to','fact',now(),'service','test'); return true; exception when others then return false; end $$;
do $$ begin if pg_temp.try_led_to_fact() then raise exception 'led_to fact was accepted'; end if; end $$;

commit;
