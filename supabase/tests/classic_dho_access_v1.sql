-- youB — Classic DHO Access + People Wiring V1
-- Rollback-only staging suite. Never apply a migration here.
-- Requires the new classic access migration and at least six disposable auth users.

begin;

create temp table classic_access_users as
select id, row_number() over (order by created_at, id) as n
from auth.users
limit 6;
grant select on classic_access_users to authenticated;

DO $$
BEGIN
  IF (select count(*) from classic_access_users) < 6 THEN
    RAISE EXCEPTION 'Classic DHO access suite requires six disposable auth users';
  END IF;
  IF to_regclass('public.employees') IS NULL
     OR to_regclass('public.checkins') IS NULL
     OR to_regclass('public.assessments') IS NULL
     OR to_regclass('public.feedbacks') IS NULL
     OR to_regclass('public.pdis') IS NULL THEN
    RAISE EXCEPTION 'Classic DHO access suite prerequisites are missing';
  END IF;
  IF NOT EXISTS (select 1 from pg_proc where proname = 'classic_is_direct_report') THEN
    RAISE EXCEPTION 'Classic DHO access helpers are missing';
  END IF;
END $$;

insert into public.organizations(id, name, slug, plan, status) values
  ('a3000000-0000-0000-0000-000000000001', 'Classic Access A', 'classic-access-a', 'essencial', 'active'),
  ('b3000000-0000-0000-0000-000000000001', 'Classic Access B', 'classic-access-b', 'essencial', 'active');

insert into public.memberships(organization_id, user_id, role)
select 'a3000000-0000-0000-0000-000000000001', id,
  case n when 1 then 'admin_youb' when 2 then 'rh' when 3 then 'diretoria' when 4 then 'gestor' when 5 then 'colaborador' else 'gestor' end
from classic_access_users;

insert into public.employees(id, organization_id, auth_user_id, full_name, email, status, manager_employee_id) values
  ('a3000000-0000-0000-0000-000000000011', 'a3000000-0000-0000-0000-000000000001', (select id from classic_access_users where n=1), 'Admin A', 'admin-a@example.invalid', 'active', null),
  ('a3000000-0000-0000-0000-000000000012', 'a3000000-0000-0000-0000-000000000001', (select id from classic_access_users where n=2), 'RH A', 'rh-a@example.invalid', 'active', null),
  ('a3000000-0000-0000-0000-000000000013', 'a3000000-0000-0000-0000-000000000001', (select id from classic_access_users where n=3), 'Diretoria A', 'diretoria-a@example.invalid', 'active', null),
  ('a3000000-0000-0000-0000-000000000014', 'a3000000-0000-0000-0000-000000000001', (select id from classic_access_users where n=4), 'Gestor A', 'gestor-a@example.invalid', 'active', null),
  ('a3000000-0000-0000-0000-000000000015', 'a3000000-0000-0000-0000-000000000001', (select id from classic_access_users where n=5), 'Colaborador A', 'colaborador-a@example.invalid', 'active', null),
  ('a3000000-0000-0000-0000-000000000016', 'a3000000-0000-0000-0000-000000000001', null, 'Direto A', 'direto-a@example.invalid', 'active', 'a3000000-0000-0000-0000-000000000014'),
  ('a3000000-0000-0000-0000-000000000017', 'a3000000-0000-0000-0000-000000000001', null, 'Fora A', 'fora-a@example.invalid', 'active', null),
  ('b3000000-0000-0000-0000-000000000011', 'b3000000-0000-0000-0000-000000000001', null, 'Pessoa B', 'pessoa-b@example.invalid', 'active', null);

insert into public.cycles(id, organization_id, name, cycle_type, status) values
  ('a3000000-0000-0000-0000-000000000021', 'a3000000-0000-0000-0000-000000000001', 'Ciclo A', 'performance', 'active'),
  ('b3000000-0000-0000-0000-000000000021', 'b3000000-0000-0000-0000-000000000001', 'Ciclo B', 'performance', 'active');
insert into public.assessments(id, organization_id, cycle_id, subject_employee_id, evaluator_employee_id, scores) values
  ('a3000000-0000-0000-0000-000000000031', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000021', 'a3000000-0000-0000-0000-000000000016', 'a3000000-0000-0000-0000-000000000014', '{}'::jsonb),
  ('a3000000-0000-0000-0000-000000000032', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000021', 'a3000000-0000-0000-0000-000000000017', null, '{}'::jsonb),
  ('a3000000-0000-0000-0000-000000000033', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000021', 'a3000000-0000-0000-0000-000000000015', null, '{}'::jsonb),
  ('b3000000-0000-0000-0000-000000000031', 'b3000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-000000000021', 'b3000000-0000-0000-0000-000000000011', null, '{}'::jsonb);
insert into public.feedbacks(id, organization_id, author_employee_id, target_employee_id, cycle_id, content) values
  ('a3000000-0000-0000-0000-000000000041', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000014', 'a3000000-0000-0000-0000-000000000016', 'a3000000-0000-0000-0000-000000000021', 'direct'),
  ('a3000000-0000-0000-0000-000000000042', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000014', 'a3000000-0000-0000-0000-000000000017', 'a3000000-0000-0000-0000-000000000021', 'outside'),
  ('a3000000-0000-0000-0000-000000000043', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000015', 'a3000000-0000-0000-0000-000000000015', 'a3000000-0000-0000-0000-000000000021', 'self');
insert into public.pdis(id, organization_id, employee_id, cycle_id, objective) values
  ('a3000000-0000-0000-0000-000000000051', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000016', 'a3000000-0000-0000-0000-000000000021', 'direct'),
  ('a3000000-0000-0000-0000-000000000052', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000017', 'a3000000-0000-0000-0000-000000000021', 'outside'),
  ('a3000000-0000-0000-0000-000000000053', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000015', 'a3000000-0000-0000-0000-000000000021', 'self');
insert into public.checkins(id, organization_id, employee_id, mood, engagement, energy, workload, note) values
  ('a3000000-0000-0000-0000-000000000061', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000016', 4, 4, 4, 3, 'direct'),
  ('a3000000-0000-0000-0000-000000000062', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000017', 4, 4, 4, 3, 'outside'),
  ('a3000000-0000-0000-0000-000000000063', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000015', 4, 4, 4, 3, 'self');

create or replace function pg_temp.assert_count(label text, actual bigint, expected bigint)
returns void language plpgsql as $$ begin if actual <> expected then raise exception '%: expected %, got %', label, expected, actual; end if; end $$;
create or replace function pg_temp.assert_true(label text, actual boolean)
returns void language plpgsql as $$ begin if not actual then raise exception '%: expected true', label; end if; end $$;
create or replace function pg_temp.try_manager_fk(p_id uuid, p_org uuid, p_manager uuid)
returns boolean language plpgsql security invoker as $$
begin
  begin
    insert into public.employees(id, organization_id, full_name, status, manager_employee_id)
    values (p_id, p_org, 'constraint probe', 'active', p_manager);
    delete from public.employees where id = p_id;
    return true;
  exception when others then
    return false;
  end;
end $$;
create or replace function pg_temp.try_manager_outside_assessment()
returns boolean language plpgsql security invoker as $$ begin begin insert into public.assessments(organization_id,cycle_id,subject_employee_id,scores) values ('a3000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000021','a3000000-0000-0000-0000-000000000017','{}'); return true; exception when others then return false; end; end $$;
create or replace function pg_temp.try_manager_self_update(p_id uuid)
returns boolean language plpgsql security invoker as $$ begin begin update public.employees set manager_employee_id = id where id = p_id; return true; exception when others then return false; end; end $$;

-- Constraint installation checks: the candidate key is exact, the FK exists,
-- and same-tenant/cross-tenant/self-manager behavior is explicit.
select pg_temp.assert_true('employees candidate key exists',
  exists (
    select 1 from pg_constraint c
    where c.conrelid = 'public.employees'::regclass
      and c.contype in ('p', 'u')
      and c.conkey = array[
        (select attnum from pg_attribute where attrelid = 'public.employees'::regclass and attname = 'organization_id'),
        (select attnum from pg_attribute where attrelid = 'public.employees'::regclass and attname = 'id')
      ]::int2[]
  )
  or exists (
    select 1 from pg_index i
    where i.indrelid = 'public.employees'::regclass
      and i.indisunique and i.indnkeyatts = 2
      and i.indkey::text = (
        select attnum::text from pg_attribute where attrelid = 'public.employees'::regclass and attname = 'organization_id'
      ) || ' ' || (
        select attnum::text from pg_attribute where attrelid = 'public.employees'::regclass and attname = 'id'
      )
  )
);
select pg_temp.assert_true('same-tenant manager FK exists', exists (
  select 1 from pg_constraint
  where conrelid = 'public.employees'::regclass
    and conname = 'employees_manager_same_org_fkey'
    and contype = 'f'
));
select pg_temp.assert_true('same-tenant manager accepted', pg_temp.try_manager_fk('a3000000-0000-0000-0000-000000000071', 'a3000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000014'));
select pg_temp.assert_true('cross-tenant manager rejected', not pg_temp.try_manager_fk('a3000000-0000-0000-0000-000000000072', 'a3000000-0000-0000-0000-000000000001', 'b3000000-0000-0000-0000-000000000011'));
select pg_temp.assert_true('self-manager rejected', not pg_temp.try_manager_self_update('a3000000-0000-0000-0000-000000000017'));

set local role authenticated;

-- A, B, G: organization and RH isolation.
select set_config('request.jwt.claim.sub', (select id::text from classic_access_users where n=2), false);
select pg_temp.assert_count('rh own employees', (select count(*) from public.employees where organization_id = 'a3000000-0000-0000-0000-000000000001'), 7);
select pg_temp.assert_count('rh cannot see tenant B', (select count(*) from public.employees where organization_id = 'b3000000-0000-0000-0000-000000000001'), 0);

-- H: diretoria sees organizational people but no raw individual assessments.
select set_config('request.jwt.claim.sub', (select id::text from classic_access_users where n=3), false);
select pg_temp.assert_count('diretoria employees', (select count(*) from public.employees where organization_id = 'a3000000-0000-0000-0000-000000000001'), 7);
select pg_temp.assert_count('diretoria raw assessments denied', (select count(*) from public.assessments where organization_id = 'a3000000-0000-0000-0000-000000000001'), 0);
select pg_temp.assert_count('diretoria raw feedback denied', (select count(*) from public.feedbacks where organization_id = 'a3000000-0000-0000-0000-000000000001'), 0);

-- D, E, J, K, L, M, N, O, V: direct reports only; IDs and area/cargo cannot expand scope.
select set_config('request.jwt.claim.sub', (select id::text from classic_access_users where n=4), false);
select pg_temp.assert_count('manager employee population', (select count(*) from public.employees where organization_id = 'a3000000-0000-0000-0000-000000000001'), 2);
select pg_temp.assert_count('manager direct assessment', (select count(*) from public.assessments where organization_id = 'a3000000-0000-0000-0000-000000000001'), 1);
select pg_temp.assert_count('manager direct feedback', (select count(*) from public.feedbacks where organization_id = 'a3000000-0000-0000-0000-000000000001'), 1);
select pg_temp.assert_count('manager direct pdi', (select count(*) from public.pdis where organization_id = 'a3000000-0000-0000-0000-000000000001'), 1);
select pg_temp.assert_count('manager direct checkin', (select count(*) from public.checkins where organization_id = 'a3000000-0000-0000-0000-000000000001'), 1);
select pg_temp.assert_count('manager manipulated outside id', (select count(*) from public.employees where id = 'a3000000-0000-0000-0000-000000000017'), 0);
select pg_temp.assert_count('manager tenant B id', (select count(*) from public.employees where id = 'b3000000-0000-0000-0000-000000000011'), 0);
select pg_temp.assert_count('manager outside insert denied', case when pg_temp.try_manager_outside_assessment() then 1 else 0 end, 0);

-- F, U, T: manager with no employee link receives no fallback population.
select set_config('request.jwt.claim.sub', (select id::text from classic_access_users where n=6), false);
select pg_temp.assert_count('unlinked manager population', (select count(*) from public.employees where organization_id = 'a3000000-0000-0000-0000-000000000001'), 0);
select pg_temp.assert_count('unlinked manager checkins', (select count(*) from public.checkins where organization_id = 'a3000000-0000-0000-0000-000000000001'), 0);

-- B, C, J, K, L, M: collaborator sees only own authorized context.
select set_config('request.jwt.claim.sub', (select id::text from classic_access_users where n=5), false);
select pg_temp.assert_count('collaborator own employee', (select count(*) from public.employees where organization_id = 'a3000000-0000-0000-0000-000000000001'), 1);
select pg_temp.assert_count('collaborator incomplete assessment denied', (select count(*) from public.assessments where organization_id = 'a3000000-0000-0000-0000-000000000001'), 0);
select pg_temp.assert_count('collaborator own feedback', (select count(*) from public.feedbacks where organization_id = 'a3000000-0000-0000-0000-000000000001'), 1);
select pg_temp.assert_count('collaborator own pdi', (select count(*) from public.pdis where organization_id = 'a3000000-0000-0000-0000-000000000001'), 1);
select pg_temp.assert_count('collaborator own checkin', (select count(*) from public.checkins where organization_id = 'a3000000-0000-0000-0000-000000000001'), 1);
select pg_temp.assert_count('collaborator other employee denied', (select count(*) from public.employees where id = 'a3000000-0000-0000-0000-000000000016'), 0);
select pg_temp.assert_count('collaborator other checkin denied', (select count(*) from public.checkins where id = 'a3000000-0000-0000-0000-000000000061'), 0);

-- The authenticated check-in regression: own row is readable, another employee is not.
select pg_temp.assert_count('checkin own by auth_user_id', (select count(*) from public.checkins where employee_id = 'a3000000-0000-0000-0000-000000000015'), 1);
select pg_temp.assert_count('checkin other by auth_user_id', (select count(*) from public.checkins where employee_id = 'a3000000-0000-0000-0000-000000000016'), 0);

reset role;
rollback;
