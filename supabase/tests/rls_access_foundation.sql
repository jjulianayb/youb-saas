-- youB / Sprint 1 — permanent RLS access-foundation suite
-- Run only in disposable staging after the legacy migrations and the hardened access migration have been applied.
-- This suite never applies a migration. Every fixture is created inside a transaction and rolled back at the end.

begin;
create temp table rls_suite_context (key text primary key, value uuid not null) on commit drop;
create temp table rls_suite_results (name text primary key, passed boolean not null, detail text not null) on commit drop;
grant select on rls_suite_context, rls_suite_results to authenticated;

do $$
declare required_table text;
begin
  foreach required_table in array array[
    'platform_memberships', 'partners', 'partner_memberships', 'partner_organization_access', 'platform_partner_organization_assignments', 'organizations', 'memberships',
    'areas', 'positions', 'employees', 'competencies', 'cycles', 'assessments', 'feedbacks', 'pdis', 'checkins', 'disciplinary_actions'
  ] loop
    if to_regclass('public.' || required_table) is null then raise exception 'RLS suite prerequisite missing: public.%', required_table; end if;
  end loop;
  if not exists (select 1 from auth.users) then raise exception 'RLS suite requires at least one auth user'; end if;
end $$;

insert into rls_suite_context(key, value) values
  ('org_a', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'), ('org_b', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  ('admin_partner', '11111111-1111-1111-1111-111111111111'), ('operator_partner', '22222222-2222-2222-2222-222222222222'), ('support_partner', '33333333-3333-3333-3333-333333333333'),
  ('expired_partner', '44444444-4444-4444-4444-444444444444'), ('suspended_partner', '55555555-5555-5555-5555-555555555555'), ('revoked_partner', '66666666-6666-6666-6666-666666666666'), ('no_grant_partner', '77777777-7777-7777-7777-777777777777'),
  ('admin_employee_a', 'aaaaaaaa-0000-0000-0000-000000000001'), ('employee_b', 'bbbbbbbb-0000-0000-0000-000000000001'), ('area_a', 'aaaaaaaa-0000-0000-0000-000000000002'), ('area_b', 'bbbbbbbb-0000-0000-0000-000000000002'),
  ('position_a', 'aaaaaaaa-0000-0000-0000-000000000003'), ('position_b', 'bbbbbbbb-0000-0000-0000-000000000003'), ('competency_a', 'aaaaaaaa-0000-0000-0000-000000000004'), ('competency_b', 'bbbbbbbb-0000-0000-0000-000000000004'),
  ('cycle_a', 'aaaaaaaa-0000-0000-0000-000000000005'), ('cycle_b', 'bbbbbbbb-0000-0000-0000-000000000005'), ('assessment_a', 'aaaaaaaa-0000-0000-0000-000000000006'), ('assessment_b', 'bbbbbbbb-0000-0000-0000-000000000006'),
  ('feedback_a', 'aaaaaaaa-0000-0000-0000-000000000007'), ('feedback_b', 'bbbbbbbb-0000-0000-0000-000000000007'), ('pdi_a', 'aaaaaaaa-0000-0000-0000-000000000008'), ('pdi_b', 'bbbbbbbb-0000-0000-0000-000000000008'),
  ('checkin_a', 'aaaaaaaa-0000-0000-0000-000000000009'), ('checkin_b', 'bbbbbbbb-0000-0000-0000-000000000009'), ('disciplinary_a', 'aaaaaaaa-0000-0000-0000-00000000000a'), ('disciplinary_b', 'bbbbbbbb-0000-0000-0000-00000000000a');
insert into rls_suite_context(key, value) select 'actor', id from auth.users order by created_at limit 1;
insert into public.organizations(id, name, slug, plan, status) values
  ((select value from rls_suite_context where key = 'org_a'), 'RLS Suite Tenant A', 'rls-suite-tenant-a', 'essencial', 'active'),
  ((select value from rls_suite_context where key = 'org_b'), 'RLS Suite Tenant B', 'rls-suite-tenant-b', 'essencial', 'active');
insert into public.memberships(organization_id, user_id, role) select (select value from rls_suite_context where key = 'org_a'), value, 'admin_youb' from rls_suite_context where key = 'actor';
insert into public.areas(id, organization_id, name) values
  ((select value from rls_suite_context where key = 'area_a'), (select value from rls_suite_context where key = 'org_a'), 'Suite Area A'), ((select value from rls_suite_context where key = 'area_b'), (select value from rls_suite_context where key = 'org_b'), 'Suite Area B');
insert into public.positions(id, organization_id, name, level) values
  ((select value from rls_suite_context where key = 'position_a'), (select value from rls_suite_context where key = 'org_a'), 'Suite Position A', 'L1'), ((select value from rls_suite_context where key = 'position_b'), (select value from rls_suite_context where key = 'org_b'), 'Suite Position B', 'L1');
insert into public.employees(id, organization_id, auth_user_id, full_name, email, area_id, position_id) values
  ((select value from rls_suite_context where key = 'admin_employee_a'), (select value from rls_suite_context where key = 'org_a'), (select value from rls_suite_context where key = 'actor'), 'RLS Suite Employee A', 'rls-a@example.invalid', (select value from rls_suite_context where key = 'area_a'), (select value from rls_suite_context where key = 'position_a')),
  ((select value from rls_suite_context where key = 'employee_b'), (select value from rls_suite_context where key = 'org_b'), null, 'RLS Suite Employee B', 'rls-b@example.invalid', (select value from rls_suite_context where key = 'area_b'), (select value from rls_suite_context where key = 'position_b'));
insert into public.competencies(id, organization_id, name, description) values
  ((select value from rls_suite_context where key = 'competency_a'), (select value from rls_suite_context where key = 'org_a'), 'Suite Competency A', 'fixture'), ((select value from rls_suite_context where key = 'competency_b'), (select value from rls_suite_context where key = 'org_b'), 'Suite Competency B', 'fixture');
insert into public.cycles(id, organization_id, name, cycle_type, status) values
  ((select value from rls_suite_context where key = 'cycle_a'), (select value from rls_suite_context where key = 'org_a'), 'Suite Cycle A', 'performance', 'draft'), ((select value from rls_suite_context where key = 'cycle_b'), (select value from rls_suite_context where key = 'org_b'), 'Suite Cycle B', 'performance', 'draft');
insert into public.assessments(id, organization_id, cycle_id, subject_employee_id, evaluator_employee_id) values
  ((select value from rls_suite_context where key = 'assessment_a'), (select value from rls_suite_context where key = 'org_a'), (select value from rls_suite_context where key = 'cycle_a'), (select value from rls_suite_context where key = 'admin_employee_a'), (select value from rls_suite_context where key = 'admin_employee_a')),
  ((select value from rls_suite_context where key = 'assessment_b'), (select value from rls_suite_context where key = 'org_b'), (select value from rls_suite_context where key = 'cycle_b'), (select value from rls_suite_context where key = 'employee_b'), null);
insert into public.feedbacks(id, organization_id, author_employee_id, target_employee_id, cycle_id, content) values
  ((select value from rls_suite_context where key = 'feedback_a'), (select value from rls_suite_context where key = 'org_a'), (select value from rls_suite_context where key = 'admin_employee_a'), (select value from rls_suite_context where key = 'admin_employee_a'), (select value from rls_suite_context where key = 'cycle_a'), 'fixture'),
  ((select value from rls_suite_context where key = 'feedback_b'), (select value from rls_suite_context where key = 'org_b'), (select value from rls_suite_context where key = 'employee_b'), (select value from rls_suite_context where key = 'employee_b'), (select value from rls_suite_context where key = 'cycle_b'), 'fixture');
insert into public.pdis(id, organization_id, employee_id, cycle_id, objective) values
  ((select value from rls_suite_context where key = 'pdi_a'), (select value from rls_suite_context where key = 'org_a'), (select value from rls_suite_context where key = 'admin_employee_a'), (select value from rls_suite_context where key = 'cycle_a'), 'fixture'), ((select value from rls_suite_context where key = 'pdi_b'), (select value from rls_suite_context where key = 'org_b'), (select value from rls_suite_context where key = 'employee_b'), (select value from rls_suite_context where key = 'cycle_b'), 'fixture');
insert into public.checkins(id, organization_id, employee_id, mood, engagement, energy, workload, note) values
  ((select value from rls_suite_context where key = 'checkin_a'), (select value from rls_suite_context where key = 'org_a'), (select value from rls_suite_context where key = 'admin_employee_a'), 4, 4, 4, 3, 'fixture'), ((select value from rls_suite_context where key = 'checkin_b'), (select value from rls_suite_context where key = 'org_b'), (select value from rls_suite_context where key = 'employee_b'), 4, 4, 4, 3, 'fixture');
insert into public.disciplinary_actions(id, organization_id, employee_id, action_type, reason) values
  ((select value from rls_suite_context where key = 'disciplinary_a'), (select value from rls_suite_context where key = 'org_a'), (select value from rls_suite_context where key = 'admin_employee_a'), 'warning', 'fixture'), ((select value from rls_suite_context where key = 'disciplinary_b'), (select value from rls_suite_context where key = 'org_b'), (select value from rls_suite_context where key = 'employee_b'), 'warning', 'fixture');
insert into public.partners(id, name, slug) values
  ((select value from rls_suite_context where key = 'admin_partner'), 'RLS Suite Partner Admin', 'rls-suite-partner-admin'), ((select value from rls_suite_context where key = 'operator_partner'), 'RLS Suite Partner Operator', 'rls-suite-partner-operator'), ((select value from rls_suite_context where key = 'support_partner'), 'RLS Suite Partner Support', 'rls-suite-partner-support'), ((select value from rls_suite_context where key = 'expired_partner'), 'RLS Suite Partner Expired', 'rls-suite-partner-expired'), ((select value from rls_suite_context where key = 'suspended_partner'), 'RLS Suite Partner Suspended', 'rls-suite-partner-suspended'), ((select value from rls_suite_context where key = 'revoked_partner'), 'RLS Suite Partner Revoked', 'rls-suite-partner-revoked'), ((select value from rls_suite_context where key = 'no_grant_partner'), 'RLS Suite Partner No Grant', 'rls-suite-partner-no-grant');
insert into public.partner_memberships(partner_id, user_id, partner_role)
select value, (select value from rls_suite_context where key = 'actor'), role_name from (values ('admin_partner'::text, 'partner_admin'::text), ('operator_partner'::text, 'partner_operator'::text), ('support_partner'::text, 'partner_support'::text), ('expired_partner'::text, 'partner_operator'::text), ('suspended_partner'::text, 'partner_support'::text), ('revoked_partner'::text, 'partner_admin'::text), ('no_grant_partner'::text, 'partner_operator'::text)) roles(key, role_name) join rls_suite_context c on c.key = roles.key;
insert into public.platform_partner_organization_assignments(partner_id, organization_id, assigned_by) values
  ((select value from rls_suite_context where key = 'admin_partner'), (select value from rls_suite_context where key = 'org_a'), (select value from rls_suite_context where key = 'actor')), ((select value from rls_suite_context where key = 'operator_partner'), (select value from rls_suite_context where key = 'org_a'), (select value from rls_suite_context where key = 'actor')), ((select value from rls_suite_context where key = 'support_partner'), (select value from rls_suite_context where key = 'org_a'), (select value from rls_suite_context where key = 'actor')), ((select value from rls_suite_context where key = 'expired_partner'), (select value from rls_suite_context where key = 'org_b'), (select value from rls_suite_context where key = 'actor')), ((select value from rls_suite_context where key = 'suspended_partner'), (select value from rls_suite_context where key = 'org_b'), (select value from rls_suite_context where key = 'actor')), ((select value from rls_suite_context where key = 'revoked_partner'), (select value from rls_suite_context where key = 'org_b'), (select value from rls_suite_context where key = 'actor'));
insert into public.partner_organization_access(partner_id, organization_id, access_scope, status, expires_at) values
  ((select value from rls_suite_context where key = 'admin_partner'), (select value from rls_suite_context where key = 'org_a'), 'reporting', 'active', now() + interval '1 day'), ((select value from rls_suite_context where key = 'operator_partner'), (select value from rls_suite_context where key = 'org_a'), 'reporting', 'active', now() + interval '1 day'), ((select value from rls_suite_context where key = 'support_partner'), (select value from rls_suite_context where key = 'org_a'), 'reporting', 'active', now() + interval '1 day'), ((select value from rls_suite_context where key = 'expired_partner'), (select value from rls_suite_context where key = 'org_b'), 'reporting', 'active', now() - interval '1 minute'), ((select value from rls_suite_context where key = 'suspended_partner'), (select value from rls_suite_context where key = 'org_b'), 'reporting', 'suspended', now() + interval '1 day'), ((select value from rls_suite_context where key = 'revoked_partner'), (select value from rls_suite_context where key = 'org_b'), 'reporting', 'revoked', now() + interval '1 day');

create or replace function pg_temp.try_insert_access(target_partner uuid, target_org uuid, target_scope text) returns boolean language plpgsql security invoker as $$ begin begin insert into public.partner_organization_access(partner_id, organization_id, access_scope) values (target_partner, target_org, target_scope); return true; exception when others then return false; end; end; $$;
create or replace function pg_temp.try_insert_platform_membership() returns boolean language plpgsql security invoker as $$ begin begin insert into public.platform_memberships(user_id, platform_role) values ((select value from rls_suite_context where key = 'actor'), 'platform_support'); return true; exception when others then return false; end; end; $$;
create or replace function pg_temp.try_update_platform_membership() returns boolean language plpgsql security invoker as $$ begin begin update public.platform_memberships set status = 'suspended' where user_id = (select value from rls_suite_context where key = 'actor') and platform_role = 'platform_support'; if not found then raise exception 'no target row'; end if; return true; exception when others then return false; end; end; $$;
create or replace function pg_temp.try_delete_platform_membership() returns boolean language plpgsql security invoker as $$ begin begin delete from public.platform_memberships where user_id = (select value from rls_suite_context where key = 'actor') and platform_role = 'platform_support'; if not found then raise exception 'no target row'; end if; return true; exception when others then return false; end; end; $$;
select set_config('request.jwt.claim.sub', (select value::text from rls_suite_context where key = 'actor'), false);
set local role authenticated;
select jsonb_build_object(
  'tenant_a_visible', (select count(*) = 1 from public.organizations where id = (select value from rls_suite_context where key = 'org_a')),
  'tenant_b_isolated', (select count(*) = 0 from public.organizations where id = (select value from rls_suite_context where key = 'org_b')),
  'user_without_partner_hidden', (select set_config('request.jwt.claim.sub', '99999999-9999-9999-9999-999999999999', false) is not null and (select count(*) = 0 from public.partners)),
  'partner_admin_role_separate', (select set_config('request.jwt.claim.sub', (select value::text from rls_suite_context where key = 'actor'), false) is not null and public.has_partner_role((select value from rls_suite_context where key = 'admin_partner'), array['partner_admin'])),
  'partner_operator_role_separate', public.has_partner_role((select value from rls_suite_context where key = 'operator_partner'), array['partner_operator']),
  'partner_support_role_separate', public.has_partner_role((select value from rls_suite_context where key = 'support_partner'), array['partner_support']),
  'active_grant_visible', (select count(*) = 1 from public.partner_organization_access where partner_id = (select value from rls_suite_context where key = 'admin_partner')),
  'expired_grant_hidden', (select count(*) = 0 from public.partner_organization_access where partner_id = (select value from rls_suite_context where key = 'expired_partner')),
  'suspended_grant_hidden', (select count(*) = 0 from public.partner_organization_access where partner_id = (select value from rls_suite_context where key = 'suspended_partner')),
  'revoked_grant_hidden', (select count(*) = 0 from public.partner_organization_access where partner_id = (select value from rls_suite_context where key = 'revoked_partner')),
  'partner_without_org_grant_hidden', (select count(*) = 0 from public.partner_organization_access where partner_id = (select value from rls_suite_context where key = 'no_grant_partner')),
  'admin_can_manage_assigned_grant', pg_temp.try_insert_access((select value from rls_suite_context where key = 'admin_partner'), (select value from rls_suite_context where key = 'org_a'), 'provisioning'),
  'partner_admin_cannot_self_grant_unassigned_org', not pg_temp.try_insert_access((select value from rls_suite_context where key = 'admin_partner'), (select value from rls_suite_context where key = 'org_b'), 'implementation'),
  'operator_cannot_manage_grant', not pg_temp.try_insert_access((select value from rls_suite_context where key = 'operator_partner'), (select value from rls_suite_context where key = 'org_b'), 'implementation'),
  'support_cannot_manage_grant', not pg_temp.try_insert_access((select value from rls_suite_context where key = 'support_partner'), (select value from rls_suite_context where key = 'org_b'), 'support'),
  'platform_does_not_auto_grant', (select count(*) = 0 from public.platform_memberships),
  'platform_memberships_insert_denied', not pg_temp.try_insert_platform_membership(),
  'platform_memberships_update_denied', not pg_temp.try_update_platform_membership(),
  'platform_memberships_delete_denied', not pg_temp.try_delete_platform_membership(),
  'helper_rejects_only_expired_org', not public.has_partner_org_access((select value from rls_suite_context where key = 'org_b'), array['reporting']),
  'legacy_organizations_isolated', (select count(*) = 0 from public.organizations where id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_memberships_isolated', (select count(*) = 0 from public.memberships where organization_id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_areas_isolated', (select count(*) = 0 from public.areas where organization_id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_positions_isolated', (select count(*) = 0 from public.positions where organization_id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_employees_isolated', (select count(*) = 0 from public.employees where organization_id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_competencies_isolated', (select count(*) = 0 from public.competencies where organization_id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_cycles_isolated', (select count(*) = 0 from public.cycles where organization_id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_assessments_isolated', (select count(*) = 0 from public.assessments where organization_id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_feedbacks_isolated', (select count(*) = 0 from public.feedbacks where organization_id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_pdis_isolated', (select count(*) = 0 from public.pdis where organization_id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_checkins_isolated', (select count(*) = 0 from public.checkins where organization_id = (select value from rls_suite_context where key = 'org_b')),
  'legacy_disciplinary_isolated', (select count(*) = 0 from public.disciplinary_actions where organization_id = (select value from rls_suite_context where key = 'org_b'))
) as rls_suite_result;
reset role;
rollback;
