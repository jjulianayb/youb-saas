-- Regression suite for the RPC ACL and search_path hardening introduced by PR #25.
-- Rollback-only: inspect function metadata, do not mutate application data.

begin;

create or replace function pg_temp.assert_true(label text, actual boolean)
returns void
language plpgsql
as $$
begin
  if not actual then
    raise exception '%: expected true', label;
  end if;
end;
$$;

create temporary table expected_privileged_rpc(signature text primary key);
insert into expected_privileged_rpc(signature) values
  ('public.approve_intelligence_decision(uuid)'),
  ('public.create_superseding_intelligence_decision(uuid,jsonb,text)'),
  ('public.has_org_role(uuid,text[])'),
  ('public.has_partner_org_access(uuid,text[])'),
  ('public.has_partner_role(uuid,text[])'),
  ('public.intelligence_has_employee_scope(uuid,uuid)'),
  ('public.intelligence_is_admin(uuid)'),
  ('public.intelligence_is_decision_maker(uuid)'),
  ('public.intelligence_is_own_employee(uuid,uuid)'),
  ('public.intelligence_signal_read_allowed(uuid,uuid,text)'),
  ('public.intelligence_signal_sensitive_access(uuid,text)'),
  ('public.intelligence_signal_write_allowed(uuid)'),
  ('public.is_org_employee(uuid,uuid)'),
  ('public.is_org_member(uuid)'),
  ('public.is_platform_role(text[])'),
  ('public.knowledge_access_allowed(uuid,text)'),
  ('public.reject_intelligence_decision(uuid,text)'),
  ('public.return_intelligence_decision_for_review(uuid,text)'),
  ('public.revise_intelligence_decision(uuid,jsonb,text)'),
  ('public.revise_intelligence_evidence_assessment(uuid,jsonb,text)'),
  ('public.revise_intelligence_recommendation(uuid,jsonb,text)'),
  ('public.revise_organizational_reading(uuid,jsonb,text)');

do $$
declare
  item record;
  fn regprocedure;
begin
  for item in select signature from expected_privileged_rpc order by signature loop
    fn := item.signature::regprocedure;
    perform pg_temp.assert_true(item.signature || ' exists', to_regprocedure(item.signature) is not null);
    perform pg_temp.assert_true(item.signature || ' denies anon', not has_function_privilege('anon', fn, 'execute'));
    perform pg_temp.assert_true(item.signature || ' allows authenticated', has_function_privilege('authenticated', fn, 'execute'));
    perform pg_temp.assert_true(item.signature || ' allows service_role', has_function_privilege('service_role', fn, 'execute'));
  end loop;
end;
$$;

select pg_temp.assert_true(
  'intelligence_decision_snapshot search_path',
  'search_path=pg_catalog, public, pg_temp' = any(coalesce((select proconfig from pg_proc where oid = 'public.intelligence_decision_snapshot(public.intelligence_decisions)'::regprocedure), array[]::text[]))
);
select pg_temp.assert_true(
  'organizational_reading_snapshot search_path',
  'search_path=pg_catalog, public, pg_temp' = any(coalesce((select proconfig from pg_proc where oid = 'public.organizational_reading_snapshot(public.intelligence_organizational_readings)'::regprocedure), array[]::text[]))
);
select pg_temp.assert_true(
  '_evidence_assessment_snapshot search_path',
  'search_path=pg_catalog, public, pg_temp' = any(coalesce((select proconfig from pg_proc where oid = 'public._evidence_assessment_snapshot(public.intelligence_evidence_assessments)'::regprocedure), array[]::text[]))
);
select pg_temp.assert_true(
  '_recommendation_snapshot search_path',
  'search_path=pg_catalog, public, pg_temp' = any(coalesce((select proconfig from pg_proc where oid = 'public._recommendation_snapshot(public.intelligence_recommendations)'::regprocedure), array[]::text[]))
);

rollback;
