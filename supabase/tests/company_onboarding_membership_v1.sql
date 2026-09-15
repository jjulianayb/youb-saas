-- Commercial V1 company onboarding, membership and employee-linking suite.
-- Rollback-only local test; never apply this file to production.

begin;

do $$ begin
  if to_regprocedure('public.link_organization_user(uuid,text,text,uuid)') is null then
    raise exception 'link_organization_user RPC is missing';
  end if;
end $$;

insert into public.organizations(id, name, slug, plan, status) values
  ('c4000000-0000-0000-0000-000000000001', 'Company Onboarding A', 'company-onboarding-a', 'essencial', 'active'),
  ('d4000000-0000-0000-0000-000000000001', 'Company Onboarding B', 'company-onboarding-b', 'essencial', 'active');
insert into public.memberships(organization_id, user_id, role) values
  ('c4000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'admin_youb');
insert into public.employees(id, organization_id, full_name, email, status) values
  ('c4000000-0000-0000-0000-000000000011', 'c4000000-0000-0000-0000-000000000001', 'RH A', 'rh@example.invalid', 'active'),
  ('c4000000-0000-0000-0000-000000000012', 'c4000000-0000-0000-0000-000000000001', 'Diretoria A', 'diretoria@example.invalid', 'active'),
  ('c4000000-0000-0000-0000-000000000013', 'c4000000-0000-0000-0000-000000000001', 'Gestor A', 'gestor@example.invalid', 'active'),
  ('c4000000-0000-0000-0000-000000000014', 'c4000000-0000-0000-0000-000000000001', 'Colaborador A', 'colaborador@example.invalid', 'active'),
  ('d4000000-0000-0000-0000-000000000011', 'd4000000-0000-0000-0000-000000000001', 'Pessoa B', 'peer-one@example.invalid', 'active');

create or replace function pg_temp.assert_true(label text, actual boolean)
returns void language plpgsql as $$ begin if not actual then raise exception '%: expected true', label; end $$;
create or replace function pg_temp.try_cross_org_link()
returns boolean language plpgsql security invoker as $$
begin
  begin
    perform public.link_organization_user('d4000000-0000-0000-0000-000000000001', 'peer-one@example.invalid', 'colaborador', 'd4000000-0000-0000-0000-000000000011');
    return true;
  exception when others then
    return false;
  end;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', false);

select pg_temp.assert_true('RH linked', exists (select 1 from public.link_organization_user('c4000000-0000-0000-0000-000000000001', 'rh@example.invalid', 'rh', 'c4000000-0000-0000-0000-000000000011')));
select pg_temp.assert_true('Diretoria linked', exists (select 1 from public.link_organization_user('c4000000-0000-0000-0000-000000000001', 'diretoria@example.invalid', 'diretoria', 'c4000000-0000-0000-0000-000000000012')));
select pg_temp.assert_true('Gestor linked', exists (select 1 from public.link_organization_user('c4000000-0000-0000-0000-000000000001', 'gestor@example.invalid', 'gestor', 'c4000000-0000-0000-0000-000000000013')));
select pg_temp.assert_true('Colaborador linked', exists (select 1 from public.link_organization_user('c4000000-0000-0000-0000-000000000001', 'colaborador@example.invalid', 'colaborador', 'c4000000-0000-0000-0000-000000000014')));
select pg_temp.assert_true('roles are assigned', (select count(*) from public.memberships where organization_id = 'c4000000-0000-0000-0000-000000000001' and role in ('rh','diretoria','gestor','colaborador')) = 4);
select pg_temp.assert_true('employee links are tenant-local', (select count(*) from public.employees where organization_id = 'c4000000-0000-0000-0000-000000000001' and auth_user_id is not null) = 4);
select pg_temp.assert_true('cross-organization link denied', not pg_temp.try_cross_org_link());
select pg_temp.assert_true('company B employee hidden from company A admin', (select count(*) from public.employees where organization_id = 'd4000000-0000-0000-0000-000000000001') = 0);
select pg_temp.assert_true('company B organization hidden from company A admin', (select count(*) from public.organizations where id = 'd4000000-0000-0000-0000-000000000001') = 0);

rollback;
