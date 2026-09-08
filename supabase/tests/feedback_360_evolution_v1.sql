-- youB — Feedback 360 + Evolução entre Ciclos V1
-- Rollback-only suite. Requires the complete chain through frozen PR #14 plus PR #15.
begin;

create temp table fb360_users as select id,row_number() over(order by created_at,id) as n from auth.users limit 10;
grant select on fb360_users to authenticated;
DO $$ BEGIN
  IF (select count(*) from fb360_users) < 10 THEN RAISE EXCEPTION 'Feedback 360 suite requires ten disposable auth users'; END IF;
END $$;

insert into public.organizations(id,name,slug,plan,status) values
 ('a6000000-0000-0000-0000-000000000001','360 A','fb360-a','essencial','active'),
 ('b6000000-0000-0000-0000-000000000001','360 B','fb360-b','essencial','active');
insert into public.memberships(organization_id,user_id,role)
select 'a6000000-0000-0000-0000-000000000001',id,case when n=1 then 'admin_youb' when n=2 then 'rh' when n=3 then 'diretoria' when n=4 then 'gestor' else 'colaborador' end from fb360_users where n in (1,2,3,4,5,8,9,10);
insert into public.memberships(organization_id,user_id,role) select 'b6000000-0000-0000-0000-000000000001',id,'rh' from fb360_users where n=1;
insert into public.positions(id,organization_id,name,level) values
 ('a6000000-0000-0000-0000-000000000011','a6000000-0000-0000-0000-000000000001','Engenharia','pleno'),
 ('a6000000-0000-0000-0000-000000000012','a6000000-0000-0000-0000-000000000001','Sem mapping','junior'),
 ('a6000000-0000-0000-0000-000000000013','a6000000-0000-0000-0000-000000000001','Fora','senior'),
 ('b6000000-0000-0000-0000-000000000011','b6000000-0000-0000-0000-000000000001','Cargo B','pleno');
insert into public.competencies(id,organization_id,name,description) values
 ('a6000000-0000-0000-0000-000000000021','a6000000-0000-0000-0000-000000000001','Colaboração','Colabora'),
 ('a6000000-0000-0000-0000-000000000022','a6000000-0000-0000-0000-000000000001','Entrega','Entrega'),
 ('b6000000-0000-0000-0000-000000000021','b6000000-0000-0000-0000-000000000001','Competência B','B');
insert into public.position_competencies(organization_id,position_id,competency_id,expected_level) values
 ('a6000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000011','a6000000-0000-0000-0000-000000000021',3),
 ('a6000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000011','a6000000-0000-0000-0000-000000000022',4);
insert into public.employees(id,organization_id,auth_user_id,full_name,status,position_id,manager_employee_id) values
 ('a6000000-0000-0000-0000-000000000031','a6000000-0000-0000-0000-000000000001',(select id from fb360_users where n=1),'Admin','active','a6000000-0000-0000-0000-000000000011',null),
 ('a6000000-0000-0000-0000-000000000032','a6000000-0000-0000-0000-000000000001',(select id from fb360_users where n=2),'RH','active','a6000000-0000-0000-0000-000000000011',null),
 ('a6000000-0000-0000-0000-000000000033','a6000000-0000-0000-0000-000000000001',(select id from fb360_users where n=3),'Diretoria','active','a6000000-0000-0000-0000-000000000011',null),
 ('a6000000-0000-0000-0000-000000000034','a6000000-0000-0000-0000-000000000001',(select id from fb360_users where n=4),'Gestor','active','a6000000-0000-0000-0000-000000000011',null),
 ('a6000000-0000-0000-0000-000000000035','a6000000-0000-0000-0000-000000000001',(select id from fb360_users where n=5),'Pessoa alvo','active','a6000000-0000-0000-0000-000000000011','a6000000-0000-0000-0000-000000000034'),
 ('a6000000-0000-0000-0000-000000000036','a6000000-0000-0000-0000-000000000001',null,'Sem cargo','active',null,'a6000000-0000-0000-0000-000000000034'),
 ('a6000000-0000-0000-0000-000000000037','a6000000-0000-0000-0000-000000000001',null,'Sem mapping','active','a6000000-0000-0000-0000-000000000012','a6000000-0000-0000-0000-000000000034'),
 ('a6000000-0000-0000-0000-000000000038','a6000000-0000-0000-0000-000000000001',null,'Fora da equipe','active','a6000000-0000-0000-0000-000000000013',null),
 ('a6000000-0000-0000-0000-000000000039','a6000000-0000-0000-0000-000000000001',null,'Pessoa dois','active','a6000000-0000-0000-0000-000000000011','a6000000-0000-0000-0000-000000000034'),
 ('a6000000-0000-0000-0000-000000000040','a6000000-0000-0000-0000-000000000001',null,'Pessoa três','active','a6000000-0000-0000-0000-000000000011','a6000000-0000-0000-0000-000000000034'),
 ('a6000000-0000-0000-0000-000000000042','a6000000-0000-0000-0000-000000000001',(select id from fb360_users where n=8),'Avaliador um','active','a6000000-0000-0000-0000-000000000011','a6000000-0000-0000-0000-000000000035'),
 ('a6000000-0000-0000-0000-000000000043','a6000000-0000-0000-0000-000000000001',(select id from fb360_users where n=9),'Avaliador dois','active','a6000000-0000-0000-0000-000000000011','a6000000-0000-0000-0000-000000000035'),
 ('a6000000-0000-0000-0000-000000000044','a6000000-0000-0000-0000-000000000001',(select id from fb360_users where n=10),'Avaliador três','active','a6000000-0000-0000-0000-000000000011','a6000000-0000-0000-0000-000000000035'),
 ('b6000000-0000-0000-0000-000000000031','b6000000-0000-0000-0000-000000000001',null,'Pessoa B','active','b6000000-0000-0000-0000-000000000011',null);

create or replace function pg_temp.assert_true(label text,v boolean) returns void language plpgsql as $$ begin if not v then raise exception '% expected true',label; end if; end $$;
create or replace function pg_temp.try_sql(sql text) returns boolean language plpgsql security invoker as $$ begin execute sql; return true; exception when others then return false; end $$;
create or replace function pg_temp.try_add(r uuid,s uuid,e uuid,t text) returns boolean language plpgsql security invoker as $$ begin perform public.fb360_add_participant(r,s,e,t); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_activate(r uuid) returns boolean language plpgsql security invoker as $$ begin perform public.fb360_activate_round(r); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_save(p uuid,c uuid) returns boolean language plpgsql security invoker as $$ begin perform public.fb360_save_score(p,c,5::smallint,'blocked'); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_submit(p uuid) returns boolean language plpgsql security invoker as $$ begin perform public.fb360_submit_participation(p); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_close(r uuid) returns boolean language plpgsql security invoker as $$ begin perform public.fb360_close_round(r); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_result(o uuid,r uuid,s uuid) returns boolean language plpgsql security invoker as $$ begin perform * from public.fb360_read_subject_result(o,r,s); return true; exception when others then return false; end $$;
create or replace function pg_temp.try_aggregate(o uuid,r uuid) returns boolean language plpgsql security invoker as $$ begin perform * from public.fb360_read_organization_aggregate(o,r); return true; exception when others then return false; end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=1),false);
select public.cca_create_cycle('a6000000-0000-0000-0000-000000000001','Ciclo 360','performance','2026-01-01','2026-03-31') as id \gset cycle_
select public.cca_activate_cycle(:'cycle_id'::uuid);
select public.cca_create_cycle('a6000000-0000-0000-0000-000000000001','Ciclo anterior','performance','2025-01-01','2025-03-31') as id \gset old_cycle_
select public.cca_activate_cycle(:'old_cycle_id'::uuid);
select public.cca_create_cycle('a6000000-0000-0000-0000-000000000001','Ciclo futuro','performance','2027-01-01','2027-03-31') as id \gset new_cycle_
select public.cca_activate_cycle(:'new_cycle_id'::uuid);
select public.cca_create_cycle('b6000000-0000-0000-0000-000000000001','Ciclo B','performance','2026-01-01','2026-03-31') as id \gset cycle_b_
select public.cca_activate_cycle(:'cycle_b_id'::uuid);

-- Draft configuration and explicit relationship rules.
select public.fb360_create_round('a6000000-0000-0000-0000-000000000001'::uuid,:'cycle_id'::uuid,'Rodada 1','confidential') as id \gset round1_
select public.fb360_add_participant(:'round1_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'self') as id \gset r1_self_
select public.fb360_add_participant(:'round1_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000034'::uuid,'manager') as id \gset r1_manager_
select public.fb360_add_participant(:'round1_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000042'::uuid,'peer') as id \gset r1_peer_
select public.fb360_add_participant(:'round1_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000042'::uuid,'direct_report') as id \gset r1_direct_
select pg_temp.assert_true('duplicate participant rejected',not pg_temp.try_add(:'round1_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000042'::uuid,'peer'));
select pg_temp.assert_true('invalid manager rejected',not pg_temp.try_add(:'round1_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000043'::uuid,'manager'));
select pg_temp.assert_true('invalid self rejected',not pg_temp.try_add(:'round1_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000043'::uuid,'self'));
select pg_temp.assert_true('cross tenant participant rejected',not pg_temp.try_add(:'round1_id'::uuid,'b6000000-0000-0000-0000-000000000031'::uuid,'a6000000-0000-0000-0000-000000000034'::uuid,'peer'));
select pg_temp.assert_true('missing position cannot activate',not pg_temp.try_add(:'round1_id'::uuid,'a6000000-0000-0000-0000-000000000037'::uuid,'a6000000-0000-0000-0000-000000000034'::uuid,'direct_report'));

-- Add a second round with two peers/direct reports: both groups must stay hidden.
select public.fb360_create_round('a6000000-0000-0000-0000-000000000001'::uuid,:'cycle_id'::uuid,'Rodada 2','confidential') as id \gset round2_
select public.fb360_add_participant(:'round2_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000042'::uuid,'peer') as id \gset r2_peer1_
select public.fb360_add_participant(:'round2_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000043'::uuid,'peer') as id \gset r2_peer2_
select public.fb360_add_participant(:'round2_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000042'::uuid,'direct_report') as id \gset r2_direct1_
select public.fb360_add_participant(:'round2_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000043'::uuid,'direct_report') as id \gset r2_direct2_

-- Third round has three peers/direct reports and three subjects for the secure executive aggregate.
select public.fb360_create_round('a6000000-0000-0000-0000-000000000001'::uuid,:'new_cycle_id'::uuid,'Rodada 3','confidential') as id \gset round3_
select public.fb360_add_participant(:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000042'::uuid,'peer') as id \gset r3_peer1_
select public.fb360_add_participant(:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000043'::uuid,'peer') as id \gset r3_peer2_
select public.fb360_add_participant(:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000044'::uuid,'peer') as id \gset r3_peer3_
select public.fb360_add_participant(:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000042'::uuid,'direct_report') as id \gset r3_direct1_
select public.fb360_add_participant(:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000043'::uuid,'direct_report') as id \gset r3_direct2_
select public.fb360_add_participant(:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000044'::uuid,'direct_report') as id \gset r3_direct3_
select public.fb360_add_participant(:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000039'::uuid,'a6000000-0000-0000-0000-000000000034'::uuid,'manager') as id \gset r3_manager2_
select public.fb360_add_participant(:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000040'::uuid,'a6000000-0000-0000-0000-000000000034'::uuid,'manager') as id \gset r3_manager3_
select public.fb360_add_participant(:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'a6000000-0000-0000-0000-000000000034'::uuid,'manager') as id \gset r3_manager1_
select public.fb360_activate_round(:'round1_id'::uuid);
select public.fb360_activate_round(:'round2_id'::uuid);
select public.fb360_activate_round(:'round3_id'::uuid);
select pg_temp.assert_true('snapshot criteria exist',(select count(*)=2 from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035'));

-- Snapshot remains historical after mapping mutation.
select public.cca_update_position_competency((select id from public.position_competencies where organization_id='a6000000-0000-0000-0000-000000000001' and position_id='a6000000-0000-0000-0000-000000000011' and competency_id='a6000000-0000-0000-0000-000000000021'),5::smallint,true);
select pg_temp.assert_true('expected level snapshot immutable',(select expected_level_snapshot=3 from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000021'));

-- Submit round 1 with one self, one manager, one peer and one direct report.
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=5),false);
select public.fb360_save_score(:'r1_self_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),5::smallint,'auto comentário');
select public.fb360_save_score(:'r1_self_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),4::smallint,'auto entrega');
select public.fb360_submit_participation(:'r1_self_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=4),false);
select public.fb360_save_score(:'r1_manager_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'feedback do gestor');
select public.fb360_save_score(:'r1_manager_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),3::smallint,'entrega do gestor');
select public.fb360_submit_participation(:'r1_manager_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=8),false);
select public.fb360_save_score(:'r1_peer_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'peer secreto');
select public.fb360_save_score(:'r1_peer_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),4::smallint,'peer entrega');
select public.fb360_submit_participation(:'r1_peer_id'::uuid);
select public.fb360_save_score(:'r1_direct_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),3::smallint,'direct secreto');
select public.fb360_save_score(:'r1_direct_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),3::smallint,'direct entrega');
select public.fb360_submit_participation(:'r1_direct_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=1),false);
select public.fb360_close_round(:'round1_id'::uuid);
select pg_temp.assert_true('closed round immutable',not pg_temp.try_save(:'r1_self_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round1_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000021')));

-- Round 2: two valid peer/direct_report responses remain hidden.
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=8),false);
select public.fb360_save_score(:'r2_peer1_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round2_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'hidden');
select public.fb360_save_score(:'r2_peer1_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round2_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000022'),4::smallint,'hidden');
select public.fb360_submit_participation(:'r2_peer1_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=9),false);
select public.fb360_save_score(:'r2_peer2_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round2_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'hidden');
select public.fb360_save_score(:'r2_peer2_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round2_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000022'),4::smallint,'hidden');
select public.fb360_submit_participation(:'r2_peer2_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=8),false);
select public.fb360_save_score(:'r2_direct1_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round2_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'hidden');
select public.fb360_save_score(:'r2_direct1_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round2_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000022'),4::smallint,'hidden');
select public.fb360_submit_participation(:'r2_direct1_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=9),false);
select public.fb360_save_score(:'r2_direct2_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round2_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'hidden');
select public.fb360_save_score(:'r2_direct2_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round2_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000022'),4::smallint,'hidden');
select public.fb360_submit_participation(:'r2_direct2_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=1),false);
select public.fb360_close_round(:'round2_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=5),false);
select pg_temp.assert_true('two peer responses hidden',(select count(*)=0 from public.fb360_read_subject_result('a6000000-0000-0000-0000-000000000001'::uuid,:'round2_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid) where relationship_type='peer'));
select pg_temp.assert_true('two direct_report responses hidden',(select count(*)=0 from public.fb360_read_subject_result('a6000000-0000-0000-0000-000000000001'::uuid,:'round2_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid) where relationship_type='direct_report'));

-- Round 3: three responses allowed, comments remain hidden for peer/direct_report.
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=8),false);
select public.fb360_save_score(:'r3_peer1_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),5::smallint,'secret1');
select public.fb360_save_score(:'r3_peer1_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),5::smallint,'secret1');
select public.fb360_submit_participation(:'r3_peer1_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=9),false);
select public.fb360_save_score(:'r3_peer2_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'secret2');
select public.fb360_save_score(:'r3_peer2_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),4::smallint,'secret2');
select public.fb360_submit_participation(:'r3_peer2_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=10),false);
select public.fb360_save_score(:'r3_peer3_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),3::smallint,'secret3');
select public.fb360_save_score(:'r3_peer3_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),3::smallint,'secret3');
select public.fb360_submit_participation(:'r3_peer3_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=8),false);
select public.fb360_save_score(:'r3_direct1_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),5::smallint,'direct1');
select public.fb360_save_score(:'r3_direct1_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),5::smallint,'direct1');
select public.fb360_submit_participation(:'r3_direct1_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=9),false);
select public.fb360_save_score(:'r3_direct2_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'direct2');
select public.fb360_save_score(:'r3_direct2_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),4::smallint,'direct2');
select public.fb360_submit_participation(:'r3_direct2_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=10),false);
select public.fb360_save_score(:'r3_direct3_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),3::smallint,'direct3');
select public.fb360_save_score(:'r3_direct3_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),3::smallint,'direct3');
select public.fb360_submit_participation(:'r3_direct3_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=4),false);
select public.fb360_save_score(:'r3_manager1_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'manager 1');
select public.fb360_save_score(:'r3_manager1_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000035' and competency_id='a6000000-0000-0000-0000-000000000022'),3::smallint,'manager 1');
select public.fb360_submit_participation(:'r3_manager1_id'::uuid);
select public.fb360_save_score(:'r3_manager2_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000039' and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'manager 2');
select public.fb360_save_score(:'r3_manager2_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000039' and competency_id='a6000000-0000-0000-0000-000000000022'),4::smallint,'manager 2');
select public.fb360_submit_participation(:'r3_manager2_id'::uuid);
select public.fb360_save_score(:'r3_manager3_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000040' and competency_id='a6000000-0000-0000-0000-000000000021'),4::smallint,'manager 3');
select public.fb360_save_score(:'r3_manager3_id'::uuid,(select id from public.feedback_360_subject_competencies where round_id=:'round3_id'::uuid and subject_employee_id='a6000000-0000-0000-0000-000000000040' and competency_id='a6000000-0000-0000-0000-000000000022'),4::smallint,'manager 3');
select public.fb360_submit_participation(:'r3_manager3_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=1),false);
select public.fb360_close_round(:'round3_id'::uuid);
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=5),false);
select pg_temp.assert_true('three peer responses visible',(select count(*)=2 from public.fb360_read_subject_result('a6000000-0000-0000-0000-000000000001'::uuid,:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid) where relationship_type='peer'));
select pg_temp.assert_true('three direct_report responses visible',(select count(*)=2 from public.fb360_read_subject_result('a6000000-0000-0000-0000-000000000001'::uuid,:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid) where relationship_type='direct_report'));
select pg_temp.assert_true('confidential comments hidden',(select count(*)=0 from public.fb360_read_subject_result('a6000000-0000-0000-0000-000000000001'::uuid,:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid) where relationship_type in ('peer','direct_report') and feedback_comment is not null));
select pg_temp.assert_true('manager one response and comment visible',(select count(*)=4 and count(*) filter(where relationship_type='manager' and feedback_comment is not null)=2 from public.fb360_read_subject_result('a6000000-0000-0000-0000-000000000001'::uuid,:'round1_id'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid)));
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=3),false);
select pg_temp.assert_true('secure executive aggregate',(select count(*)>=2 from public.fb360_read_organization_aggregate('a6000000-0000-0000-0000-000000000001'::uuid,:'round3_id'::uuid)));

-- Raw protection and role denial.
select pg_temp.assert_true('collaborator sees only own participant raw',(select count(*)=0 from public.feedback_360_scores where organization_id='a6000000-0000-0000-0000-000000000001' and participant_id <> :'r1_self_id'::uuid));
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=3),false);
select pg_temp.assert_true('diretoria cannot read raw scores',(select count(*)=0 from public.feedback_360_scores where organization_id='a6000000-0000-0000-0000-000000000001'));
select pg_temp.assert_true('cross tenant aggregate denied',not pg_temp.try_aggregate('a6000000-0000-0000-0000-000000000001'::uuid,:'cycle_b_id'::uuid));
select pg_temp.assert_true('tampered tenant denied',not pg_temp.try_aggregate('b6000000-0000-0000-0000-000000000001'::uuid,:'round3_id'::uuid));
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=4),false);
select pg_temp.assert_true('manager cannot read external subject',not pg_temp.try_result('a6000000-0000-0000-0000-000000000001'::uuid,:'round3_id'::uuid,'a6000000-0000-0000-0000-000000000038'::uuid));
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=6),false);
select pg_temp.assert_true('platform has no aggregate',not pg_temp.try_aggregate('a6000000-0000-0000-0000-000000000001'::uuid,:'round3_id'::uuid));

-- PR #14 assessment source remains separate and evolution returns delta.
reset role;
insert into public.assessments(id,organization_id,cycle_id,subject_employee_id,evaluator_employee_id,position_id,status,created_by_user_id,submitted_at,completed_at)
 values ('a6000000-0000-0000-0000-000000000501','a6000000-0000-0000-0000-000000000001',:'old_cycle_id'::uuid,'a6000000-0000-0000-0000-000000000035','a6000000-0000-0000-0000-000000000034','a6000000-0000-0000-0000-000000000011','completed',(select id from fb360_users where n=1),'2025-03-01','2025-03-02'),
 ('a6000000-0000-0000-0000-000000000502','a6000000-0000-0000-0000-000000000001',:'new_cycle_id'::uuid,'a6000000-0000-0000-0000-000000000035','a6000000-0000-0000-0000-000000000034','a6000000-0000-0000-0000-000000000011','completed',(select id from fb360_users where n=1),'2027-03-01','2027-03-02');
insert into public.assessment_competency_scores(organization_id,assessment_id,competency_id,position_competency_id,expected_level_snapshot,score)
select 'a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000501'::uuid,competency_id,id,expected_level,3 from public.position_competencies where organization_id='a6000000-0000-0000-0000-000000000001' and position_id='a6000000-0000-0000-0000-000000000011'
union all select 'a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000502'::uuid,competency_id,id,expected_level,5 from public.position_competencies where organization_id='a6000000-0000-0000-0000-000000000001' and position_id='a6000000-0000-0000-0000-000000000011';

-- Historical incompatibility fixtures: same competency with a changed position and a changed expected level.
insert into public.cycles(id,organization_id,name,cycle_type,starts_at,ends_at,status)
values
 ('a6000000-0000-0000-0000-000000000061','a6000000-0000-0000-0000-000000000001','Ciclo cargo alterado','performance','2029-01-01','2029-03-31','closed'),
 ('a6000000-0000-0000-0000-000000000062','a6000000-0000-0000-0000-000000000001','Ciclo esperado alterado','performance','2028-01-01','2028-03-31','closed');
insert into public.positions(id,organization_id,name,level) values ('a6000000-0000-0000-0000-000000000014','a6000000-0000-0000-0000-000000000001','Engenharia alterada','senior');
insert into public.position_competencies(organization_id,position_id,competency_id,expected_level)
values ('a6000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000014','a6000000-0000-0000-0000-000000000021',3);
update public.employees set position_id='a6000000-0000-0000-0000-000000000014' where organization_id='a6000000-0000-0000-0000-000000000001' and id='a6000000-0000-0000-0000-000000000035';
insert into public.assessments(id,organization_id,cycle_id,subject_employee_id,evaluator_employee_id,status,created_by_user_id,submitted_at,completed_at)
values ('a6000000-0000-0000-0000-000000000503','a6000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000061','a6000000-0000-0000-0000-000000000035','a6000000-0000-0000-0000-000000000034','completed',(select id from fb360_users where n=1),'2029-03-01','2029-03-02');
insert into public.assessment_competency_scores(organization_id,assessment_id,competency_id,position_competency_id,expected_level_snapshot,score)
select 'a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000503'::uuid,competency_id,id,3,4 from public.position_competencies where organization_id='a6000000-0000-0000-0000-000000000001' and position_id='a6000000-0000-0000-0000-000000000014' and competency_id='a6000000-0000-0000-0000-000000000021';
update public.employees set position_id='a6000000-0000-0000-0000-000000000011' where organization_id='a6000000-0000-0000-0000-000000000001' and id='a6000000-0000-0000-0000-000000000035';
insert into public.assessments(id,organization_id,cycle_id,subject_employee_id,evaluator_employee_id,status,created_by_user_id,submitted_at,completed_at)
values ('a6000000-0000-0000-0000-000000000504','a6000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000062','a6000000-0000-0000-0000-000000000035','a6000000-0000-0000-0000-000000000034','completed',(select id from fb360_users where n=1),'2028-03-01','2028-03-02');
insert into public.assessment_competency_scores(organization_id,assessment_id,competency_id,position_competency_id,expected_level_snapshot,score)
select 'a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000504'::uuid,competency_id,id,3,4 from public.position_competencies where organization_id='a6000000-0000-0000-0000-000000000001' and position_id='a6000000-0000-0000-0000-000000000011' and competency_id='a6000000-0000-0000-0000-000000000021';

set local role authenticated;
select set_config('request.jwt.claim.sub',(select id::text from fb360_users where n=5),false);
select pg_temp.assert_true('evolution keeps assessment source',(select count(*)=6 from public.fb360_read_evolution('a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'assessment_v1')));
select pg_temp.assert_true('same competency origin position expected compares',(select count(*)=1 from public.fb360_read_evolution('a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'assessment_v1') where cycle_id=:'new_cycle_id'::uuid and competency_id='a6000000-0000-0000-0000-000000000021' and previous_score=3 and delta=2));
select pg_temp.assert_true('different position does not compare',(select count(*)=1 and count(*) filter(where previous_score is null and delta is null)=1 from public.fb360_read_evolution('a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'assessment_v1') where cycle_id='a6000000-0000-0000-0000-000000000061'::uuid and competency_id='a6000000-0000-0000-0000-000000000021')));
select pg_temp.assert_true('different expected level does not compare',(select count(*)=1 and count(*) filter(where previous_score is null and delta is null)=1 from public.fb360_read_evolution('a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'assessment_v1') where cycle_id='a6000000-0000-0000-0000-000000000062'::uuid and competency_id='a6000000-0000-0000-0000-000000000021')));
select pg_temp.assert_true('different competency has no predecessor',(select count(*) filter(where competency_id='a6000000-0000-0000-0000-000000000022' and previous_score is null and delta is null)>=1 from public.fb360_read_evolution('a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'assessment_v1')));
select pg_temp.assert_true('different origin is not mixed',(select count(*)=2 and count(*) filter(where source_type='self' and previous_score is null and delta is null)=2 from public.fb360_read_evolution('a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,null) where source_type='self')));
select pg_temp.assert_true('no comparable predecessor yields nulls',(select count(*)>=2 from public.fb360_read_evolution('a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'assessment_v1') where previous_score is null and delta is null));
select pg_temp.assert_true('historical snapshots remain intact',(select count(*)=1 from public.assessment_competency_scores where assessment_id='a6000000-0000-0000-0000-000000000501' and expected_level_snapshot=5 and score=3) and (select count(*)=1 from public.assessment_competency_scores where assessment_id='a6000000-0000-0000-0000-000000000502' and expected_level_snapshot=5 and score=5));
select pg_temp.assert_true('evolution rejects invalid origin',not pg_temp.try_sql($q$select * from public.fb360_read_evolution('a6000000-0000-0000-0000-000000000001'::uuid,'a6000000-0000-0000-0000-000000000035'::uuid,'invalid')$q$));

select pg_temp.assert_true('security definer functions pin search path',(select bool_and(prosecdef and array_to_string(proconfig,',') like '%search_path=public%' and array_to_string(proconfig,',') like '%pg_temp%') from pg_proc where pronamespace='public'::regnamespace and proname like 'fb360_%'));
select pg_temp.assert_true('no public execute on application functions',not has_function_privilege('anon','public.fb360_create_round(uuid,uuid,text,text)','execute') and has_function_privilege('authenticated','public.fb360_create_round(uuid,uuid,text,text)','execute'));

reset role;
rollback;
