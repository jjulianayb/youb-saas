-- Data Architecture 2.0 P0 event capture contract tests.
-- All fixtures are fictitious and rolled back.
begin;

create temp table p0_auth_users as
select id, row_number() over (order by created_at, id) as n
from auth.users
limit 2;
do $$ begin if (select count(*) from p0_auth_users) < 2 then raise exception 'P0 suite requires two auth users'; end if; end $$;
grant select on p0_auth_users to authenticated;

insert into public.organizations(id,name,slug,plan,status) values
 ('e9000000-0000-0000-0000-000000000001','P0 Event Org','p0-event-org','essencial','active');
insert into public.memberships(organization_id,user_id,role)
select 'e9000000-0000-0000-0000-000000000001',id,case when p0_auth_users.n=1 then 'admin_youb' else 'rh' end
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
 ('e9000000-0000-0000-0000-000000000102','e9000000-0000-0000-0000-000000000001','Area Two');
insert into public.positions(id,organization_id,name,level) values
 ('e9000000-0000-0000-0000-000000000201','e9000000-0000-0000-0000-000000000001','Position One','Pleno'),
 ('e9000000-0000-0000-0000-000000000202','e9000000-0000-0000-0000-000000000001','Position Two','Sênior');
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
