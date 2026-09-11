-- youB — Competency + Cycle + Assessment V1
-- Rollback-only runtime suite. Requires the complete chain through PR #14.
begin;

create temp table cca_users as select id,row_number() over(order by created_at,id) as n from auth.users limit 7;
grant select on cca_users to authenticated;
DO $$ BEGIN
  IF (select count(*) from cca_users) < 7 THEN RAISE EXCEPTION 'CCA suite requires seven disposable auth users'; END IF;
  IF to_regclass('public.position_competencies') IS NULL OR to_regclass('public.assessment_competency_scores') IS NULL THEN RAISE EXCEPTION 'CCA tables are missing'; END IF;
END $$;

insert into public.organizations(id,name,slug,plan,status) values
 ('a5000000-0000-0000-0000-000000000001','CCA A','cca-a','essencial','active'),
 ('b5000000-0000-0000-0000-000000000001','CCA B','cca-b','essencial','active');
insert into public.memberships(organization_id,user_id,role)
select 'a5000000-0000-0000-0000-000000000001',id,case n when 1 then 'admin_youb' when 2 then 'rh' when 3 then 'diretoria' when 4 then 'gestor' when 5 then 'colaborador' end from cca_users where n <= 5;
insert into public.memberships(organization_id,user_id,role) select 'b5000000-0000-0000-0000-000000000001',id,'rh' from cca_users where n=1;
insert into public.positions(id,organization_id,name,level) values
 ('a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000001','Engenharia','pleno'),
 ('a5000000-0000-0000-0000-000000000012','a5000000-0000-0000-0000-000000000001','Sem mapping','junior'),
 ('a5000000-0000-0000-0000-000000000013','a5000000-0000-0000-0000-000000000001','Fora da equipe','senior'),
 ('b5000000-0000-0000-0000-000000000011','b5000000-0000-0000-0000-000000000001','Cargo B','pleno');
insert into public.competencies(id,organization_id,name,description) values
 ('a5000000-0000-0000-0000-000000000021','a5000000-0000-0000-0000-000000000001','Colaboração','Trabalha com clareza'),
 ('a5000000-0000-0000-0000-000000000022','a5000000-0000-0000-0000-000000000001','Entrega','Entrega resultados'),
 ('b5000000-0000-0000-0000-000000000021','b5000000-0000-0000-0000-000000000001','Competência B','Tenant B');
insert into public.employees(id,organization_id,auth_user_id,full_name,status,position_id,manager_employee_id) values
 ('a5000000-0000-0000-0000-000000000031','a5000000-0000-0000-0000-000000000001',(select id from cca_users where n=1),'Admin','active','a5000000-0000-0000-0000-000000000011',null),
 ('a5000000-0000-0000-0000-000000000032','a5000000-0000-0000-0000-000000000001',(select id from cca_users where n=2),'RH','active','a5000000-0000-0000-0000-000000000011',null),
 ('a5000000-0000-0000-0000-000000000033','a5000000-0000-0000-0000-000000000001',(select id from cca_users where n=3),'Diretoria','active','a5000000-0000-0000-0000-000000000011',null),
 ('a5000000-0000-0000-0000-000000000034','a5000000-0000-0000-0000-000000000001',(select id from cca_users where n=4),'Gestor','active','a5000000-0000-0000-0000-000000000011',null),
 ('a5000000-0000-0000-0000-000000000035','a5000000-0000-0000-0000-000000000001',(select id from cca_users where n=5),'Direto','active','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000034'),
 ('a5000000-0000-0000-0000-000000000036','a5000000-0000-0000-0000-000000000001',null,'Sem cargo','active',null,'a5000000-0000-0000-0000-000000000034'),
 ('a5000000-0000-0000-0000-000000000037','a5000000-0000-0000-0000-000000000001',null,'Sem mapping','active','a5000000-0000-0000-0000-000000000012','a5000000-0000-0000-0000-000000000034'),
 ('a5000000-0000-0000-0000-000000000038','a5000000-0000-0000-0000-000000000001',null,'Fora','active','a5000000-0000-0000-0000-000000000013',null),
 ('a5000000-0000-0000-0000-000000000039','a5000000-0000-0000-0000-000000000001',null,'Direto dois','active','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000034'),
 ('a5000000-0000-0000-0000-000000000040','a5000000-0000-0000-0000-000000000001',null,'Direto três','active','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000034'),
 ('b5000000-0000-0000-0000-000000000031','b5000000-0000-0000-0000-000000000001',null,'Pessoa B','active','b5000000-0000-0000-0000-000000000011',null);
insert into public.platform_memberships(user_id,platform_role) select id,case when n=1 then 'platform_admin' else 'platform_analyst' end from cca_users where n in (1,6);
insert into public.partners(id,name,slug) values ('c5000000-0000-0000-0000-000000000001','Partner CCA','cca-partner');
insert into public.partner_memberships(partner_id,user_id,partner_role) select 'c5000000-0000-0000-0000-000000000001',id,'partner_operator' from cca_users where n=6;
create or replace function pg_temp.assert_true(label text,v boolean) returns void language plpgsql as $$ begin if not v then raise exception '% expected true',label; end if; end $$;
create or replace function pg_temp.assert_eq(label text,actual text,expected text) returns void language plpgsql as $$ begin if actual is distinct from expected then raise exception '% expected %, got %',label,expected,actual; end if; end $$;
create or replace function pg_temp.try_sql(sql text) returns boolean language plpgsql security invoker as $$ begin execute sql; return true; exception when others then return false; end $$;
create or replace function pg_temp.try_create_cycle(n text,s date,e date) returns boolean language plpgsql security invoker as $$ begin perform public.cca_create_cycle('a5000000-0000-0000-0000-000000000001',n,'performance',s,e); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_activate(i uuid) returns boolean language plpgsql security invoker as $$ begin perform public.cca_activate_cycle(i); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_close(i uuid) returns boolean language plpgsql security invoker as $$ begin perform public.cca_close_cycle(i); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_update_cycle(i uuid) returns boolean language plpgsql security invoker as $$ begin perform public.cca_update_draft_cycle(i,'invalid','2026-09-01','2026-12-31'); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_create_assessment(c uuid,s uuid,e uuid) returns boolean language plpgsql security invoker as $$ begin perform public.cca_create_assessment(c,s,e); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_update_score(a uuid,c uuid) returns boolean language plpgsql security invoker as $$ begin perform public.cca_save_assessment_score(a,c,5::smallint,'blocked'); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_bad_score(a uuid,c uuid) returns boolean language plpgsql security invoker as $$ begin perform public.cca_save_assessment_score(a,c,6::smallint,'x'); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_complete(a uuid) returns boolean language plpgsql security invoker as $$ begin perform public.cca_complete_assessment(a); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_aggregate(o uuid,c uuid) returns boolean language plpgsql security invoker as $$ begin perform * from public.cca_read_assessment_aggregate(o,c); return true; exception when others then return false; end $$;

-- Cross-tenant FK and range checks are exercised as the local owner; application writes use RPCs.
select pg_temp.assert_true('mapping cross-tenant FK rejected',not pg_temp.try_sql($q$insert into public.position_competencies(organization_id,position_id,competency_id,expected_level) values ('a5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000021',3)$q$));
select pg_temp.assert_true('expected level range rejected',not pg_temp.try_sql($q$insert into public.position_competencies(organization_id,position_id,competency_id,expected_level) values ('a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000021',6)$q$));

set local role authenticated;
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=1),false);
select pg_temp.assert_true('RH/Admin creates competency',public.cca_create_competency('a5000000-0000-0000-0000-000000000001','Comunicação','Clareza') is not null);
select pg_temp.assert_true('Admin maps first competency',public.cca_create_position_competency('a5000000-0000-0000-0000-000000000011'::uuid,'a5000000-0000-0000-0000-000000000021'::uuid,3::smallint) is not null);
select pg_temp.assert_true('Admin maps second competency',public.cca_create_position_competency('a5000000-0000-0000-0000-000000000011'::uuid,'a5000000-0000-0000-0000-000000000022'::uuid,4::smallint) is not null);
select pg_temp.assert_true('Admin maps outside position',public.cca_create_position_competency('a5000000-0000-0000-0000-000000000013'::uuid,'a5000000-0000-0000-0000-000000000021'::uuid,2::smallint) is not null);
select pg_temp.assert_true('mapping duplicate rejected',not pg_temp.try_sql($q$select public.cca_create_position_competency('a5000000-0000-0000-0000-000000000011'::uuid,'a5000000-0000-0000-0000-000000000021'::uuid,3::smallint)$q$));
select pg_temp.assert_true('invalid cycle period rejected',not pg_temp.try_create_cycle('invalid','2026-09-10','2026-09-01'));
select public.cca_create_cycle('a5000000-0000-0000-0000-000000000001','Ciclo V1','performance','2026-09-01','2026-12-31') as id \gset cycle_
select pg_temp.assert_true('draft can activate',public.cca_activate_cycle(:'cycle_id'::uuid));
select pg_temp.assert_true('active cannot return draft',not pg_temp.try_update_cycle(:'cycle_id'::uuid));
select public.cca_create_cycle('a5000000-0000-0000-0000-000000000001','Ciclo Gestor','performance','2026-09-01','2026-12-31') as id \gset cycle2_
select public.cca_activate_cycle(:'cycle2_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=1),false);
select public.cca_create_cycle('b5000000-0000-0000-0000-000000000001','Ciclo B','performance','2026-09-01','2026-12-31') as id \gset cycle_b_
select public.cca_activate_cycle(:'cycle_b_id'::uuid);
select public.cca_create_cycle('a5000000-0000-0000-0000-000000000001','Ciclo Draft','performance',null,null) as id \gset draft_
select pg_temp.assert_true('draft missing period cannot activate',not pg_temp.try_activate(:'draft_id'::uuid));
select pg_temp.assert_true('draft cycle rejects assessment',not pg_temp.try_create_assessment(:'draft_id'::uuid,'a5000000-0000-0000-0000-000000000035','a5000000-0000-0000-0000-000000000034'));

-- Atomic start snapshots all active mappings and captures the position.
select public.cca_create_assessment(:'cycle_id'::uuid,'a5000000-0000-0000-0000-000000000035','a5000000-0000-0000-0000-000000000034') as id \gset assessment_
select pg_temp.assert_true('assessment snapshot has two criteria',(select count(*)=2 from public.assessment_competency_scores where assessment_id=:'assessment_id'::uuid));
select pg_temp.assert_eq('expected level snapshot',''||(select expected_level_snapshot from public.assessment_competency_scores where assessment_id=:'assessment_id'::uuid and competency_id='a5000000-0000-0000-0000-000000000021'),'3');
select public.cca_update_position_competency((select id from public.position_competencies where position_id='a5000000-0000-0000-0000-000000000011' and competency_id='a5000000-0000-0000-0000-000000000021'),5::smallint,true);
select pg_temp.assert_eq('mapping change does not rewrite snapshot',''||(select expected_level_snapshot from public.assessment_competency_scores where assessment_id=:'assessment_id'::uuid and competency_id='a5000000-0000-0000-0000-000000000021'),'3');
select pg_temp.assert_true('equivalent assessment duplicate rejected',not pg_temp.try_create_assessment(:'cycle_id'::uuid,'a5000000-0000-0000-0000-000000000035','a5000000-0000-0000-0000-000000000034'));
select pg_temp.assert_true('active can close',public.cca_close_cycle(:'cycle_id'::uuid));
select pg_temp.assert_true('closed cannot reactivate',not pg_temp.try_activate(:'cycle_id'::uuid));
select pg_temp.assert_true('employee without position explicit failure',not pg_temp.try_create_assessment(:'cycle2_id'::uuid,'a5000000-0000-0000-0000-000000000036','a5000000-0000-0000-0000-000000000034'));
select pg_temp.assert_true('position without mapping explicit failure',not pg_temp.try_create_assessment(:'cycle2_id'::uuid,'a5000000-0000-0000-0000-000000000037','a5000000-0000-0000-0000-000000000034'));

-- Manager path: direct report only, scores 1–5, submit; RH completes.
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=4),false);
select pg_temp.assert_true('manager cannot create outside population',not pg_temp.try_create_assessment(:'cycle2_id'::uuid,'a5000000-0000-0000-0000-000000000038','a5000000-0000-0000-0000-000000000034'));
select pg_temp.assert_true('manager sees direct mapping only',(select count(*)=2 from public.position_competencies));
select public.cca_create_assessment(:'cycle2_id'::uuid,'a5000000-0000-0000-0000-000000000035','a5000000-0000-0000-0000-000000000034') as id \gset manager_assessment_
select public.cca_save_assessment_score(:'manager_assessment_id'::uuid,'a5000000-0000-0000-0000-000000000021'::uuid,5::smallint,'evidência');
select pg_temp.assert_true('score outside range rejected',not pg_temp.try_bad_score(:'manager_assessment_id'::uuid,'a5000000-0000-0000-0000-000000000022'::uuid));
select public.cca_save_assessment_score(:'manager_assessment_id'::uuid,'a5000000-0000-0000-0000-000000000022'::uuid,4::smallint,'entrega');
select pg_temp.assert_true('manager submits',public.cca_submit_assessment(:'manager_assessment_id'::uuid));
select pg_temp.assert_true('manager cannot complete',not pg_temp.try_complete(:'manager_assessment_id'::uuid));
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=2),false);
select pg_temp.assert_true('RH completes',public.cca_complete_assessment(:'manager_assessment_id'::uuid));
select pg_temp.assert_eq('assessment completed',(select status from public.assessments where id=:'manager_assessment_id'::uuid),'completed');
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=4),false);
select pg_temp.assert_true('completed score immutable',not pg_temp.try_update_score(:'manager_assessment_id'::uuid,'a5000000-0000-0000-0000-000000000021'::uuid));

-- Collaborator sees only own completed assessment and cannot write score.
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=5),false);
select pg_temp.assert_true('collaborator reads own completed',(select count(*)=1 from public.assessments where id=:'manager_assessment_id'::uuid));
select pg_temp.assert_true('collaborator cannot write score',not pg_temp.try_update_score(:'manager_assessment_id'::uuid,'a5000000-0000-0000-0000-000000000021'::uuid));

-- Aggregate authorization is explicit, tenant-bound and k-anonymous.
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=3),false);
select pg_temp.assert_true('diretoria cannot read raw individual',(select count(*)=0 from public.assessments where organization_id='a5000000-0000-0000-0000-000000000001'));
select pg_temp.assert_true('diretoria cannot read raw scores',(select count(*)=0 from public.assessment_competency_scores where organization_id='a5000000-0000-0000-0000-000000000001'));
select pg_temp.assert_true('diretoria cannot edit cycle',not pg_temp.try_activate(:'cycle_id'::uuid));
select pg_temp.assert_true('one completed assessment is hidden',(select count(*)=0 from public.cca_read_assessment_aggregate('a5000000-0000-0000-0000-000000000001'::uuid,:'cycle2_id'::uuid)));
select pg_temp.assert_true('cross-tenant cycle is denied',not pg_temp.try_aggregate('a5000000-0000-0000-0000-000000000001'::uuid,:'cycle_b_id'::uuid));
select pg_temp.assert_true('tampered organization is denied',not pg_temp.try_aggregate('b5000000-0000-0000-0000-000000000001'::uuid,:'cycle2_id'::uuid));
select pg_temp.assert_true('nonexistent cycle fails closed',not pg_temp.try_aggregate('a5000000-0000-0000-0000-000000000001'::uuid,'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid));
select pg_temp.assert_true('aggregate shape excludes raw identity',(select not (array_to_string(proargnames,',') ~ '(employee|evaluator|comment|evidence)') from pg_proc where oid='public.cca_read_assessment_aggregate(uuid,uuid)'::regprocedure));
select pg_temp.assert_true('legacy aggregate signature removed',to_regprocedure('public.cca_read_assessment_aggregate(uuid)') is null);
select pg_temp.assert_true('aggregate execute only authenticated',not has_function_privilege('anon','public.cca_read_assessment_aggregate(uuid,uuid)','execute') and has_function_privilege('authenticated','public.cca_read_assessment_aggregate(uuid,uuid)','execute'));
select pg_temp.assert_true('all PR14 security definer functions pin search_path',(select bool_and(prosecdef and array_to_string(proconfig,',') like '%search_path=public%' and array_to_string(proconfig,',') like '%pg_temp%') from pg_proc where pronamespace='public'::regnamespace and proname like 'cca_%'));

-- A second completed assessment is still below threshold 3.
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=1),false);
select public.cca_create_assessment(:'cycle2_id'::uuid,'a5000000-0000-0000-0000-000000000039'::uuid,'a5000000-0000-0000-0000-000000000034'::uuid) as id \gset aggregate_two_
select public.cca_save_assessment_score(:'aggregate_two_id'::uuid,'a5000000-0000-0000-0000-000000000021'::uuid,4::smallint,'second evidence');
select public.cca_save_assessment_score(:'aggregate_two_id'::uuid,'a5000000-0000-0000-0000-000000000022'::uuid,3::smallint,'second delivery');
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=4),false);
select public.cca_submit_assessment(:'aggregate_two_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=2),false);
select public.cca_complete_assessment(:'aggregate_two_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=3),false);
select pg_temp.assert_true('two completed assessments are hidden',(select count(*)=0 from public.cca_read_assessment_aggregate('a5000000-0000-0000-0000-000000000001'::uuid,:'cycle2_id'::uuid)));

-- Three completed assessments allow a group, but a competency with only two scores stays hidden.
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=1),false);
select public.cca_create_assessment(:'cycle2_id'::uuid,'a5000000-0000-0000-0000-000000000040'::uuid,'a5000000-0000-0000-0000-000000000034'::uuid) as id \gset aggregate_three_
select public.cca_save_assessment_score(:'aggregate_three_id'::uuid,'a5000000-0000-0000-0000-000000000021'::uuid,2::smallint,'third evidence');
select public.cca_save_assessment_score(:'aggregate_three_id'::uuid,'a5000000-0000-0000-0000-000000000022'::uuid,2::smallint,'third delivery');
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=4),false);
select public.cca_submit_assessment(:'aggregate_three_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=2),false);
select public.cca_complete_assessment(:'aggregate_three_id'::uuid);
reset role;
delete from public.assessment_competency_scores where assessment_id=:'aggregate_three_id'::uuid and competency_id='a5000000-0000-0000-0000-000000000022'::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=3),false);
select pg_temp.assert_true('three completed scores expose only sufficiently populated groups',(select count(*)=1 and count(*) filter(where competency_id='a5000000-0000-0000-0000-000000000021')=1 and count(*) filter(where competency_id='a5000000-0000-0000-0000-000000000022')=0 and min(assessment_count)=3 from public.cca_read_assessment_aggregate('a5000000-0000-0000-0000-000000000001'::uuid,:'cycle2_id'::uuid)));

-- Manager, collaborator, unassigned user and platform/partner identities never receive the RPC.
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=4),false);
select pg_temp.assert_true('manager aggregate denied',not pg_temp.try_aggregate('a5000000-0000-0000-0000-000000000001'::uuid,:'cycle2_id'::uuid));
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=5),false);
select pg_temp.assert_true('collaborator aggregate denied',not pg_temp.try_aggregate('a5000000-0000-0000-0000-000000000001'::uuid,:'cycle2_id'::uuid));
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=7),false);
select pg_temp.assert_true('user without membership aggregate denied',not pg_temp.try_aggregate('a5000000-0000-0000-0000-000000000001'::uuid,:'cycle2_id'::uuid));
select set_config('request.jwt.claim.sub',(select id::text from cca_users where n=6),false);
select pg_temp.assert_true('platform and partner aggregate denied',not pg_temp.try_aggregate('a5000000-0000-0000-0000-000000000001'::uuid,:'cycle2_id'::uuid));

reset role;
rollback;
