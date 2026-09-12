-- youB — Classic DHO Access + People Wiring V1
-- Hardening additive: preserve data, replace broad classic policies with
-- tenant-, role- and population-aware policies. Do not apply automatically.

create or replace function public.classic_is_org_admin(target_org uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select public.has_org_role(target_org, array['admin_youb','rh']);
$$;

create or replace function public.classic_has_single_own_employee(target_org uuid, target_employee uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select count(*) = 1 and (array_agg(e.id))[1] = target_employee
  from public.employees e
  where e.organization_id = target_org
    and e.auth_user_id = auth.uid();
$$;

create or replace function public.classic_manager_employee_id(target_org uuid)
returns uuid
language sql stable security definer
set search_path = public, pg_temp
as $$
  select case when count(*) = 1 then (array_agg(e.id))[1] else null end
  from public.employees e
  where e.organization_id = target_org
    and e.auth_user_id = auth.uid()
    and e.status = 'active';
$$;

create or replace function public.classic_is_direct_report(target_org uuid, target_employee uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.employees e
    where e.organization_id = target_org
      and e.id = target_employee
      and e.status = 'active'
      and e.manager_employee_id = public.classic_manager_employee_id(target_org)
      and public.classic_manager_employee_id(target_org) is not null
  );
$$;

create or replace function public.classic_can_read_employee(target_org uuid, target_employee uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select
    public.has_org_role(target_org, array['admin_youb','rh','diretoria'])
    or (public.has_org_role(target_org, array['gestor']) and (
      public.classic_is_direct_report(target_org, target_employee)
      or public.classic_has_single_own_employee(target_org, target_employee)
    ))
    or (public.has_org_role(target_org, array['colaborador']) and public.classic_has_single_own_employee(target_org, target_employee));
$$;

create or replace function public.classic_can_read_sensitive_employee(target_org uuid, target_employee uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select
    public.has_org_role(target_org, array['admin_youb','rh'])
    or (public.has_org_role(target_org, array['gestor']) and public.classic_is_direct_report(target_org, target_employee))
    or (public.has_org_role(target_org, array['colaborador']) and public.classic_has_single_own_employee(target_org, target_employee));
$$;

create or replace function public.classic_can_write_employee(target_org uuid, target_employee uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select
    public.has_org_role(target_org, array['admin_youb','rh'])
    or (public.has_org_role(target_org, array['gestor']) and public.classic_is_direct_report(target_org, target_employee));
$$;

revoke all on function public.classic_is_org_admin(uuid), public.classic_has_single_own_employee(uuid, uuid), public.classic_manager_employee_id(uuid), public.classic_is_direct_report(uuid, uuid), public.classic_can_read_employee(uuid, uuid), public.classic_can_read_sensitive_employee(uuid, uuid), public.classic_can_write_employee(uuid, uuid) from public;
grant execute on function public.classic_is_org_admin(uuid), public.classic_has_single_own_employee(uuid, uuid), public.classic_manager_employee_id(uuid), public.classic_is_direct_report(uuid, uuid), public.classic_can_read_employee(uuid, uuid), public.classic_can_read_sensitive_employee(uuid, uuid), public.classic_can_write_employee(uuid, uuid) to authenticated;

-- Preflight is deliberately before every new constraint. Legacy data is never
-- corrected or nulled silently; an incompatible database must stop here with a
-- diagnostic that names the failing category and row count.
do $$
declare
  v_cross_tenant bigint;
  v_missing_manager bigint;
  v_self_manager bigint;
  v_legacy_incompatible bigint;
  v_duplicate_keys bigint;
begin
  select count(*) into v_cross_tenant
  from public.employees e
  where e.manager_employee_id is not null
    and exists (
      select 1 from public.employees manager
      where manager.id = e.manager_employee_id
        and manager.organization_id <> e.organization_id
    );
  if v_cross_tenant > 0 then
    raise exception 'classic_dho_access_people_wiring_v1 preflight failed: % manager references cross-tenant employees; no data was changed', v_cross_tenant using errcode = '23514';
  end if;

  select count(*) into v_missing_manager
  from public.employees e
  where e.manager_employee_id is not null
    and not exists (select 1 from public.employees manager where manager.id = e.manager_employee_id);
  if v_missing_manager > 0 then
    raise exception 'classic_dho_access_people_wiring_v1 preflight failed: % manager references point to nonexistent employees; no data was changed', v_missing_manager using errcode = '23503';
  end if;

  select count(*) into v_self_manager
  from public.employees e
  where e.manager_employee_id = e.id;
  if v_self_manager > 0 then
    raise exception 'classic_dho_access_people_wiring_v1 preflight failed: % employees self-reference as manager; no data was changed', v_self_manager using errcode = '23514';
  end if;

  select count(*) into v_legacy_incompatible
  from public.employees e
  where e.organization_id is null or e.id is null;
  if v_legacy_incompatible > 0 then
    raise exception 'classic_dho_access_people_wiring_v1 preflight failed: % employees have null organization_id/id and are incompatible with the candidate key; no data was changed', v_legacy_incompatible using errcode = '23514';
  end if;

  select count(*) into v_duplicate_keys
  from (
    select e.organization_id, e.id
    from public.employees e
    group by e.organization_id, e.id
    having count(*) > 1
  ) duplicates;
  if v_duplicate_keys > 0 then
    raise exception 'classic_dho_access_people_wiring_v1 preflight failed: % duplicate (organization_id, id) candidate keys; no data was changed', v_duplicate_keys using errcode = '23505';
  end if;
end $$;

-- PostgreSQL requires a unique candidate key matching the referenced columns
-- for a composite FK. The base schema only has employees.id as its primary key,
-- so create the exact same-tenant candidate key when it is absent. Existing
-- compatible unique constraints/indexes are detected and reused.
do $$
declare
  v_org_attnum int2;
  v_id_attnum int2;
  v_has_key boolean;
begin
  select attnum into v_org_attnum from pg_attribute
    where attrelid = 'public.employees'::regclass and attname = 'organization_id' and not attisdropped;
  select attnum into v_id_attnum from pg_attribute
    where attrelid = 'public.employees'::regclass and attname = 'id' and not attisdropped;
  if v_org_attnum is null or v_id_attnum is null then
    raise exception 'classic_dho_access_people_wiring_v1 cannot install: employees.organization_id and employees.id are required for the candidate key' using errcode = '42703';
  end if;

  select exists (
    select 1 from pg_constraint c
    where c.conrelid = 'public.employees'::regclass
      and c.contype in ('p', 'u')
      and c.conkey = array[v_org_attnum, v_id_attnum]::int2[]
  ) or exists (
    select 1 from pg_index i
    where i.indrelid = 'public.employees'::regclass
      and i.indisunique
      and i.indnkeyatts = 2
      and i.indkey::text = v_org_attnum::text || ' ' || v_id_attnum::text
  ) into v_has_key;

  if not v_has_key then
    alter table public.employees
      add constraint employees_organization_id_id_key unique (organization_id, id);
  end if;
end $$;

-- The candidate key now makes the tenant part of the manager reference. The
-- check rejects self-management independently of the FK.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'employees_manager_same_org_fkey' and conrelid = 'public.employees'::regclass) then
    alter table public.employees
      add constraint employees_manager_same_org_fkey
      foreign key (organization_id, manager_employee_id)
      references public.employees (organization_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'employees_manager_not_self_check' and conrelid = 'public.employees'::regclass) then
    alter table public.employees
      add constraint employees_manager_not_self_check
      check (manager_employee_id is null or manager_employee_id <> id);
  end if;
end $$;

create index if not exists idx_employees_org_auth_status
  on public.employees(organization_id, auth_user_id, status);
create index if not exists idx_employees_org_manager_status
  on public.employees(organization_id, manager_employee_id, status);
create index if not exists idx_assessments_org_subject
  on public.assessments(organization_id, subject_employee_id);
create index if not exists idx_feedbacks_org_target
  on public.feedbacks(organization_id, target_employee_id);
create index if not exists idx_feedbacks_org_author
  on public.feedbacks(organization_id, author_employee_id);
create index if not exists idx_pdis_org_employee
  on public.pdis(organization_id, employee_id);
create index if not exists idx_checkins_org_employee
  on public.checkins(organization_id, employee_id);

-- The prior role-permissions migration intentionally recreated a broad matrix.
-- Replace all policies for the affected classic entities atomically in this
-- migration so no previous permissive policy remains active.
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('employees','areas','positions','competencies','cycles','assessments','feedbacks','pdis','checkins','disciplinary_actions','disciplinary_action_approvals')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- Reference data is non-personal but remains tenant-bound.
create policy classic_areas_select_members on public.areas
for select to authenticated using (public.is_org_member(organization_id));
create policy classic_areas_write_admin_hr on public.areas
for all to authenticated using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));

create policy classic_positions_select_members on public.positions
for select to authenticated using (public.is_org_member(organization_id));
create policy classic_positions_write_admin_hr on public.positions
for all to authenticated using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));

create policy classic_competencies_select_members on public.competencies
for select to authenticated using (public.is_org_member(organization_id));
create policy classic_competencies_write_admin_hr on public.competencies
for all to authenticated using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));

create policy classic_cycles_select_members on public.cycles
for select to authenticated using (public.is_org_member(organization_id));
create policy classic_cycles_write_admin_hr on public.cycles
for all to authenticated using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));

create policy classic_employees_select_population on public.employees
for select to authenticated
using (public.classic_can_read_employee(organization_id, id));
create policy classic_employees_write_admin_hr on public.employees
for all to authenticated
using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));

create policy classic_assessments_select_population on public.assessments
for select to authenticated
using (public.classic_can_read_employee(organization_id, subject_employee_id));
create policy classic_assessments_insert_population on public.assessments
for insert to authenticated
with check (
  public.classic_can_write_employee(organization_id, subject_employee_id)
  and (evaluator_employee_id is null or public.classic_can_read_employee(organization_id, evaluator_employee_id))
);
create policy classic_assessments_update_admin_hr on public.assessments
for update to authenticated
using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));
create policy classic_assessments_delete_admin_hr on public.assessments
for delete to authenticated
using (public.classic_is_org_admin(organization_id));

create policy classic_feedbacks_select_population on public.feedbacks
for select to authenticated
using (
  public.classic_can_read_sensitive_employee(organization_id, target_employee_id)
  or (author_employee_id is not null and public.classic_can_read_sensitive_employee(organization_id, author_employee_id))
);
create policy classic_feedbacks_insert_population on public.feedbacks
for insert to authenticated
with check (
  public.classic_can_write_employee(organization_id, target_employee_id)
  and (
    public.classic_is_org_admin(organization_id)
    or (author_employee_id is not null and public.classic_has_single_own_employee(organization_id, author_employee_id))
  )
);
create policy classic_feedbacks_update_population on public.feedbacks
for update to authenticated
using (
  public.classic_is_org_admin(organization_id)
  or (author_employee_id is not null and public.classic_has_single_own_employee(organization_id, author_employee_id))
)
with check (
  public.classic_can_write_employee(organization_id, target_employee_id)
  and (
    public.classic_is_org_admin(organization_id)
    or (author_employee_id is not null and public.classic_has_single_own_employee(organization_id, author_employee_id))
  )
);
create policy classic_feedbacks_delete_population on public.feedbacks
for delete to authenticated
using (
  public.classic_is_org_admin(organization_id)
  or (author_employee_id is not null and public.classic_has_single_own_employee(organization_id, author_employee_id))
);

create policy classic_pdis_select_population on public.pdis
for select to authenticated
using (public.classic_can_read_sensitive_employee(organization_id, employee_id));
create policy classic_pdis_insert_population on public.pdis
for insert to authenticated
with check (
  public.classic_can_write_employee(organization_id, employee_id)
  or (public.has_org_role(organization_id, array['colaborador']) and public.classic_has_single_own_employee(organization_id, employee_id))
);
create policy classic_pdis_update_population on public.pdis
for update to authenticated
using (
  public.classic_can_write_employee(organization_id, employee_id)
  or (public.has_org_role(organization_id, array['colaborador']) and public.classic_has_single_own_employee(organization_id, employee_id))
)
with check (
  public.classic_can_write_employee(organization_id, employee_id)
  or (public.has_org_role(organization_id, array['colaborador']) and public.classic_has_single_own_employee(organization_id, employee_id))
);
create policy classic_pdis_delete_population on public.pdis
for delete to authenticated
using (
  public.classic_can_write_employee(organization_id, employee_id)
  or (public.has_org_role(organization_id, array['colaborador']) and public.classic_has_single_own_employee(organization_id, employee_id))
);

create policy classic_checkins_select_population on public.checkins
for select to authenticated
using (public.classic_can_read_sensitive_employee(organization_id, employee_id));
create policy classic_checkins_insert_population on public.checkins
for insert to authenticated
with check (public.classic_can_write_employee(organization_id, employee_id));
create policy classic_checkins_update_population on public.checkins
for update to authenticated
using (public.classic_can_write_employee(organization_id, employee_id))
with check (public.classic_can_write_employee(organization_id, employee_id));
create policy classic_checkins_delete_admin_hr on public.checkins
for delete to authenticated
using (public.classic_is_org_admin(organization_id));

-- Sensitive history follows the same direct-report rule. Approval writes are
-- left to the existing authorized approver workflow, but reads are scoped.
create policy classic_disciplinary_select_population on public.disciplinary_actions
for select to authenticated
using (public.classic_can_read_sensitive_employee(organization_id, employee_id));
create policy classic_disciplinary_insert_population on public.disciplinary_actions
for insert to authenticated
with check (public.classic_can_write_employee(organization_id, employee_id));
create policy classic_disciplinary_update_admin_hr on public.disciplinary_actions
for update to authenticated
using (public.classic_is_org_admin(organization_id))
with check (public.classic_is_org_admin(organization_id));
create policy classic_disciplinary_delete_admin_hr on public.disciplinary_actions
for delete to authenticated
using (public.classic_is_org_admin(organization_id));

create policy classic_disciplinary_approvals_select_population on public.disciplinary_action_approvals
for select to authenticated
using (
  exists (
    select 1 from public.disciplinary_actions a
    where a.id = action_id
      and a.organization_id = disciplinary_action_approvals.organization_id
      and public.classic_can_read_sensitive_employee(a.organization_id, a.employee_id)
  )
);
create policy classic_disciplinary_approvals_insert_population on public.disciplinary_action_approvals
for insert to authenticated
with check (
  exists (
    select 1 from public.disciplinary_actions a
    where a.id = action_id
      and a.organization_id = disciplinary_action_approvals.organization_id
      and public.classic_can_write_employee(a.organization_id, a.employee_id)
  )
);
create policy classic_disciplinary_approvals_update_authorized on public.disciplinary_action_approvals
for update to authenticated
using (
  exists (
    select 1 from public.disciplinary_actions a
    where a.id = action_id
      and a.organization_id = disciplinary_action_approvals.organization_id
      and public.classic_can_write_employee(a.organization_id, a.employee_id)
  )
)
with check (
  exists (
    select 1 from public.disciplinary_actions a
    where a.id = action_id
      and a.organization_id = disciplinary_action_approvals.organization_id
      and public.classic_can_write_employee(a.organization_id, a.employee_id)
  )
);

grant select, insert, update, delete on
  public.employees, public.areas, public.positions, public.competencies,
  public.cycles, public.assessments, public.feedbacks, public.pdis,
  public.checkins, public.disciplinary_actions,
  public.disciplinary_action_approvals to authenticated;

comment on function public.classic_manager_employee_id(uuid) is
  'Returns one active employee for auth.uid(); multiple or zero links return NULL and therefore no manager population.';
comment on function public.classic_is_direct_report(uuid, uuid) is
  'V1 population is direct reports only through same-tenant manager_employee_id; no hierarchy inference.';
