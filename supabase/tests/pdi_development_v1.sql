-- PDI + Development V1 rollback-only suite.
begin;

create temp table pdi_users as select id,row_number() over(order by created_at,id) as n from auth.users limit 6;
grant select on pdi_users to authenticated;

do $$ begin
  if (select count(*) from pdi_users) < 6 then raise exception 'PDI suite requires six auth users'; end if;
  if to_regclass('public.pdis') is null or to_regclass('public.pdi_objectives') is null or to_regclass('public.pdi_actions') is null or to_regclass('public.pdi_checkins') is null or to_regclass('public.pdi_source_links') is null or to_regclass('public.pdi_audit_events') is null then raise exception 'PDI V1 tables are missing'; end if;
end $$;

insert into public.organizations(id,name,slug,plan,status) values
 ('a7000000-0000-0000-0000-000000000001','PDI A','pdi-a','essencial','active'),
 ('b7000000-0000-0000-0000-000000000001','PDI B','pdi-b','essencial','active');
insert into public.memberships(organization_id,user_id,role)
select 'a7000000-0000-0000-0000-000000000001',id,case n when 1 then 'admin_youb' when 2 then 'rh' when 3 then 'diretoria' when 4 then 'gestor' when 5 then 'colaborador' else 'gestor' end from pdi_users;
insert into public.memberships(organization_id,user_id,role) select 'b7000000-0000-0000-0000-000000000001',id,'colaborador' from pdi_users where n=5;
insert into public.employees(id,organization_id,auth_user_id,full_name,email,status,manager_employee_id) values
 ('a7000000-0000-0000-0000-000000000011','a7000000-0000-0000-0000-000000000001',(select id from pdi_users where n=1),'Admin PDI','admin-pdi@example.invalid','active',null),
 ('a7000000-0000-0000-0000-000000000012','a7000000-0000-0000-0000-000000000001',(select id from pdi_users where n=2),'RH PDI','rh-pdi@example.invalid','active',null),
 ('a7000000-0000-0000-0000-000000000013','a7000000-0000-0000-0000-000000000001',(select id from pdi_users where n=3),'Diretoria PDI','diretoria-pdi@example.invalid','active',null),
 ('a7000000-0000-0000-0000-000000000014','a7000000-0000-0000-0000-000000000001',(select id from pdi_users where n=4),'Gestor PDI','gestor-pdi@example.invalid','active',null),
 ('a7000000-0000-0000-0000-000000000015','a7000000-0000-0000-0000-000000000001',(select id from pdi_users where n=5),'Colaborador PDI','colab-pdi@example.invalid','active',null),
 ('a7000000-0000-0000-0000-000000000016','a7000000-0000-0000-0000-000000000001',null,'Liderado PDI','direct-pdi@example.invalid','active','a7000000-0000-0000-0000-000000000014'),
 ('a7000000-0000-0000-0000-000000000017','a7000000-0000-0000-0000-000000000001',null,'Fora PDI','outside-pdi@example.invalid','active',null),
 ('b7000000-0000-0000-0000-000000000011','b7000000-0000-0000-0000-000000000001',null,'Pessoa B','pessoa-b@example.invalid','active',null);
insert into public.cycles(id,organization_id,name,cycle_type,status) values
 ('a7000000-0000-0000-0000-000000000021','a7000000-0000-0000-0000-000000000001','Ciclo PDI','performance','closed'),
 ('b7000000-0000-0000-0000-000000000021','b7000000-0000-0000-0000-000000000001','Ciclo B','performance','closed');
-- Legacy fixture: represents a record created before the V1 additive migration.
insert into public.pdis(id,organization_id,employee_id,cycle_id,objective,actions,status,due_date)
values ('a7000000-0000-0000-0000-000000000051','a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000016','a7000000-0000-0000-0000-000000000021','Legacy objective','[{"title":"Legacy action"}]'::jsonb,'draft','2030-12-31'),
 ('b7000000-0000-0000-0000-000000000051','b7000000-0000-0000-0000-000000000001','b7000000-0000-0000-0000-000000000011','b7000000-0000-0000-0000-000000000021','Tenant B objective','[]'::jsonb,'draft','2030-12-31');
insert into public.positions(id,organization_id,name,level) values ('a7000000-0000-0000-0000-000000000031','a7000000-0000-0000-0000-000000000001','PDI Position','senior');
insert into public.competencies(id,organization_id,name,description) values ('a7000000-0000-0000-0000-000000000041','a7000000-0000-0000-0000-000000000001','PDI Competency','Context only');
insert into public.position_competencies(id,organization_id,position_id,competency_id,expected_level) values ('a7000000-0000-0000-0000-000000000051','a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000031','a7000000-0000-0000-0000-000000000041',3);
update public.employees set position_id='a7000000-0000-0000-0000-000000000031' where id='a7000000-0000-0000-0000-000000000015';
insert into public.assessments(id,organization_id,cycle_id,subject_employee_id,evaluator_employee_id,position_id,status,created_by_user_id,submitted_at,completed_at,scores)
values ('a7000000-0000-0000-0000-000000000061','a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000021','a7000000-0000-0000-0000-000000000015','a7000000-0000-0000-0000-000000000014','a7000000-0000-0000-0000-000000000031','completed',(select id from pdi_users where n=1),'2030-01-01','2030-01-02','{}'::jsonb);
insert into public.assessment_competency_scores(organization_id,assessment_id,competency_id,position_competency_id,expected_level_snapshot,score)
values ('a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000061','a7000000-0000-0000-0000-000000000041','a7000000-0000-0000-0000-000000000051',3,4);
insert into public.feedback_360_rounds(id,organization_id,cycle_id,name,status,closed_at) values ('a7000000-0000-0000-0000-000000000071','a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000021','Feedback seguro','closed','2030-01-03');

create or replace function pg_temp.assert_true(label text,actual boolean) returns void language plpgsql as $$ begin if not actual then raise exception '%: expected true',label; end if; end $$;
create or replace function pg_temp.try_sql(statement text) returns boolean language plpgsql security invoker as $$ begin begin execute statement; return true; exception when others then return false; end; end $$;

-- Collaborator can read only own data and cannot write tables directly.
set local role authenticated;
select set_config('request.jwt.claim.sub',(select id::text from pdi_users where n=5),false);
select pg_temp.assert_true('collaborator sees own legacy pdi',(select count(*)=0 from public.pdis where organization_id='a7000000-0000-0000-0000-000000000001' and employee_id='a7000000-0000-0000-0000-000000000016'));
select pg_temp.assert_true('collaborator cannot read external pdi',(select count(*)=0 from public.pdis where organization_id='a7000000-0000-0000-0000-000000000001' and employee_id='a7000000-0000-0000-0000-000000000017'));
select pg_temp.assert_true('direct pdi insert is blocked',not pg_temp.try_sql($q$insert into public.pdis(organization_id,employee_id,objective) values ('a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000015','bypass')$q$));
select pg_temp.assert_true('pdi root remains legacy intact',(select objective='Legacy objective' and actions='[{"title":"Legacy action"}]'::jsonb from public.pdis where id='a7000000-0000-0000-0000-000000000051'));
select public.pdi_create('a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000015','Develop active listening','2030-12-31') as created_pdi \gset
select pg_temp.assert_true('new pdi starts draft',(select status='draft' from public.pdis where id=:'created_pdi'));
select public.pdi_add_objective(:'created_pdi','Active listening','Practice weekly','Complete three reviewed conversations','a7000000-0000-0000-0000-000000000015','2030-11-30') as created_objective \gset
select public.pdi_add_action(:'created_objective','Prepare conversation plan','Use a short agenda','a7000000-0000-0000-0000-000000000015','2030-10-30') as created_action \gset
select pg_temp.assert_true('new action is normalized',(select count(*)=1 and not exists(select 1 from public.pdis where id=:'created_pdi' and actions <> '[]'::jsonb) from public.pdi_actions where id=:'created_action'));
select public.pdi_add_checkin(:'created_pdi','Progress recorded','Repeat next week','No blocker','private note',:'created_objective',:'created_action') as created_checkin \gset
select pg_temp.assert_true('checkin append only',not pg_temp.try_sql(format('update public.pdi_checkins set progress_note=%L where id=%L','tamper',:'created_checkin')) and not pg_temp.try_sql(format('delete from public.pdi_checkins where id=%L',:'created_checkin')));
select pg_temp.assert_true('audit append only',not pg_temp.try_sql(format('update public.pdi_audit_events set reason=%L where entity_id=%L','tamper',:'created_pdi')) and not pg_temp.try_sql(format('delete from public.pdi_audit_events where entity_id=%L',:'created_pdi')));
select pg_temp.assert_true('assessment source link is safe',(select public.pdi_add_source_link(:'created_pdi','assessment_v1','a7000000-0000-0000-0000-000000000061'::uuid,null,null,null,'context only',4,:'created_objective') is not null));
select pg_temp.assert_true('no score automatically creates another pdi',(select count(*)=2 from public.pdis where organization_id='a7000000-0000-0000-0000-000000000001'));
select pg_temp.assert_true('peer below threshold rejected',not pg_temp.try_sql(format('select public.pdi_add_source_link(%L,%L,null,%L,%L,%L,%L,null,null)',:'created_pdi','feedback_360','a7000000-0000-0000-0000-000000000071','a7000000-0000-0000-0000-000000000041','peer','no raw')));
select pg_temp.assert_true('source link has no confidential columns',(select count(*)=0 from information_schema.columns where table_schema='public' and table_name='pdi_source_links' and column_name in ('participant_id','evaluator_employee_id','feedback_360_score_id','comment')));

-- Manager can operate only on direct reports, not on the external employee.
select set_config('request.jwt.claim.sub',(select id::text from pdi_users where n=4),false);
select public.pdi_create('a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000016','Direct report development','2030-12-31') as manager_pdi \gset
select pg_temp.assert_true('manager cannot create outside pdi',not pg_temp.try_sql($q$select public.pdi_create('a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000017','outside',null)$q$));
select public.pdi_propose(:'manager_pdi',1);
select pg_temp.assert_true('manager activates proposed pdi',(select public.pdi_activate(:'manager_pdi',2)));
select pg_temp.assert_true('invalid direct pdi lifecycle rejected',not pg_temp.try_sql(format('select public.pdi_transition(%L,%L,3,%L)',:'manager_pdi','completed','bad')));
select public.pdi_transition(:'manager_pdi','paused',3,'conversation paused');
select public.pdi_transition(:'manager_pdi','active',4,'conversation resumed');
select pg_temp.assert_true('stale update rejected',not pg_temp.try_sql(format('select public.pdi_transition(%L,%L,3,%L)',:'manager_pdi','paused','stale')));

-- Diretoria has no raw PDI access and only receives the safe aggregate RPC.
select set_config('request.jwt.claim.sub',(select id::text from pdi_users where n=3),false);
select pg_temp.assert_true('diretoria has no raw pdi',(select count(*)=0 from public.pdis where organization_id='a7000000-0000-0000-0000-000000000001'));
select pg_temp.assert_true('diretoria aggregate is suppressed for small population',(select count(*)=0 from public.pdi_read_organization_aggregate('a7000000-0000-0000-0000-000000000001')));
select pg_temp.assert_true('directoria cannot write',not pg_temp.try_sql(format('select public.pdi_create(%L,%L,%L,null)','a7000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000016','bad')));

-- Required function/security properties.
select pg_temp.assert_true('pdi rpc search paths fixed',(select bool_and(prosecdef and array_to_string(proconfig,',') like '%search_path=public%' and array_to_string(proconfig,',') like '%pg_temp%') from pg_proc where pronamespace='public'::regnamespace and proname in ('pdi_create','pdi_propose','pdi_activate','pdi_transition','pdi_add_objective','pdi_add_action','pdi_add_checkin','pdi_add_source_link')));
select pg_temp.assert_true('authenticated cannot write pdi tables',not has_table_privilege('authenticated','public.pdis','insert') and not has_table_privilege('authenticated','public.pdi_objectives','update') and not has_table_privilege('authenticated','public.pdi_audit_events','delete'));

reset role;
rollback;
