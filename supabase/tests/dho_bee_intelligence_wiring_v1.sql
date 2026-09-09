-- PR #17 DHO → Bee Intelligence wiring contract suite.
begin;
create or replace function pg_temp.assert_true(label text, actual boolean) returns void language plpgsql as $$ begin if not actual then raise exception '%: expected true',label; end if; end $$;
select pg_temp.assert_true('approved DHO contracts exist',
  to_regclass('public.assessments') is not null and to_regclass('public.assessment_competency_scores') is not null
  and to_regclass('public.feedback_360_rounds') is not null and to_regclass('public.pdis') is not null
  and to_regclass('public.pdi_objectives') is not null and to_regclass('public.intelligence_organizational_readings') is not null
  and to_regclass('public.intelligence_recommendations') is not null and to_regclass('public.intelligence_decisions') is not null
  and to_regclass('public.bee_action_requests') is not null);
select pg_temp.assert_true('safe read contracts exist',
  exists(select 1 from pg_proc where proname='fb360_read_evolution')
  and exists(select 1 from pg_proc where proname='fb360_read_subject_result')
  and exists(select 1 from pg_proc where proname='pdi_read_organization_aggregate'));
select pg_temp.assert_true('PDI source links have no confidential 360 columns',
  not exists(select 1 from information_schema.columns where table_schema='public' and table_name='pdi_source_links' and column_name in ('participant_id','evaluator_employee_id','feedback_360_scores_id','comment')));
select pg_temp.assert_true('PDI direct writes remain blocked',
  not has_table_privilege('authenticated','public.pdis','insert')
  and not has_table_privilege('authenticated','public.pdi_objectives','update')
  and not has_table_privilege('authenticated','public.pdi_actions','delete'));
select pg_temp.assert_true('PDI context can be read but not directly mutated',
  has_table_privilege('authenticated','public.pdis','select')
  and not has_table_privilege('authenticated','public.pdi_audit_events','insert'));
select pg_temp.assert_true('intelligence tables use RLS',
  (select count(*) >= 10 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname like 'intelligence_%' and c.relrowsecurity));
select pg_temp.assert_true('Bee action requests remain authorization records',
  exists(select 1 from pg_constraint where conrelid='public.bee_action_requests'::regclass and conname like '%prohibited_autonomous%'));
rollback;
