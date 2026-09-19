-- Controlled SQL integration test. Requires privileged test runner for synthetic auth fixtures.
-- Uses fresh random IDs, switches to authenticated for business operations, and rolls back all fixtures.
-- This does not test browser login or email delivery.
begin;
set local statement_timeout = '15s';
create temporary table qa_release_ids(k text primary key,v uuid);
insert into qa_release_ids values ('user_a',gen_random_uuid()),('user_b',gen_random_uuid());
insert into auth.users(id,email) select v,'qa-'||v||'@example.invalid' from qa_release_ids;
grant select,insert,update on qa_release_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select v::text from qa_release_ids where k='user_a'),true);
insert into qa_release_ids select 'org_a',id from public.create_organization('QA transacional A','qa-'||gen_random_uuid());
insert into qa_release_ids select 'employee_a',id from public.create_employee_profile((select v from qa_release_ids where k='org_a'),'QA Pessoa A');
insert into qa_release_ids select 'pdi_a',public.pdi_create((select v from qa_release_ids where k='org_a'),(select v from qa_release_ids where k='employee_a'),'QA objetivo');
insert into qa_release_ids select 'cycle_a',public.cca_create_cycle((select v from qa_release_ids where k='org_a'),'QA ciclo');
do $$ begin
 if not exists(select 1 from public.employees where id=(select v from qa_release_ids where k='employee_a')) then raise exception 'QA owner employee read failed'; end if;
 if not exists(select 1 from public.pdis where id=(select v from qa_release_ids where k='pdi_a')) then raise exception 'QA owner PDI read failed'; end if;
end $$;
do $$ declare p uuid := (select v from qa_release_ids where k='pdi_a'); e uuid := (select v from qa_release_ids where k='employee_a'); o uuid; a uuid; begin
 perform public.pdi_propose(p,(select version from public.pdis where id=p));
 perform public.pdi_activate(p,(select version from public.pdis where id=p));
 o := public.pdi_add_objective(p,'QA objetivo verificável',null,'QA critério',e);
 a := public.pdi_add_action(o,'QA ação',null,e);
 perform public.pdi_set_action_status(a,'in_progress',(select version from public.pdi_actions where id=a));
 perform public.pdi_add_checkin(p,'QA avanço','QA próximo passo',null,null,o,a);
 perform public.pdi_set_action_status(a,'completed',(select version from public.pdi_actions where id=a),null,'QA evidência de execução');
 perform public.pdi_set_objective_status(o,'completed',(select version from public.pdi_objectives where id=o),'QA critério atingido');
 perform public.pdi_transition(p,'completed',(select version from public.pdis where id=p));
 if not exists(select 1 from public.pdis where id=p and status='completed') then raise exception 'QA PDI completion failed'; end if;
 if not exists(select 1 from public.pdi_checkins where pdi_id=p and author_user_id=auth.uid() and author_employee_id is null) then raise exception 'QA PDI checkin missing'; end if;
end $$;
select set_config('request.jwt.claim.sub',(select v::text from qa_release_ids where k='user_b'),true);
insert into qa_release_ids select 'org_b',id from public.create_organization('QA transacional B','qa-'||gen_random_uuid());
do $$ declare rejected boolean := false; begin
 if exists(select 1 from public.employees where id=(select v from qa_release_ids where k='employee_a')) then raise exception 'QA cross tenant employee leak'; end if;
 if exists(select 1 from public.pdis where id=(select v from qa_release_ids where k='pdi_a')) then raise exception 'QA cross tenant PDI leak'; end if;
 begin
 perform public.pdi_create((select v from qa_release_ids where k='org_a'),(select v from qa_release_ids where k='employee_a'),'QA forbidden');
 exception when insufficient_privilege then rejected := true;
 end;
 if not rejected then raise exception 'QA cross tenant PDI write was not denied'; end if;
end $$;
rollback;
