#!/usr/bin/env bash
set -euo pipefail

: "${DATABASE_URL:=${DB_URL:-postgresql://postgres:postgres@127.0.0.1:5432/postgres}}"

org_id="dddddddd-dddd-dddd-dddd-dddddddddddd"
area_id="dddddddd-0000-0000-0000-000000000001"
position_id="dddddddd-0000-0000-0000-000000000003"
manager_id="dddddddd-0000-0000-0000-000000000010"
admin_id="$(psql "$DATABASE_URL" -X -Atqc "select user_id from public.memberships where organization_id='$org_id' and role='admin_youb' limit 1")"
created_email="p0-concurrent-create@example.invalid"
correlation_id="f0000000-0000-0000-0000-000000000901"

setup_owned=0
if [[ -z "$admin_id" ]]; then
  org_id="f0000000-0000-0000-0000-000000000001"
  area_id="f0000000-0000-0000-0000-000000000101"
  position_id="f0000000-0000-0000-0000-000000000201"
  manager_id="f0000000-0000-0000-0000-000000000011"
  admin_id="10000000-0000-0000-0000-000000000001"
  setup_owned=1
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<SQL
insert into public.organizations(id,name,slug,plan,status)
values ('$org_id','P0 Concurrent Org','p0-concurrent-org','essencial','active')
on conflict (id) do nothing;
insert into public.memberships(organization_id,user_id,role)
values ('$org_id','$admin_id','admin_youb')
on conflict (organization_id,user_id) do nothing;
insert into public.areas(id,organization_id,name)
values ('$area_id','$org_id','P0 Concurrent Area')
on conflict (id) do nothing;
insert into public.positions(id,organization_id,name,level)
values ('$position_id','$org_id','P0 Concurrent Position','pleno')
on conflict (id) do nothing;
insert into public.employees(id,organization_id,full_name,email,status)
values ('$manager_id','$org_id','P0 Concurrent Manager','p0-concurrent-manager@example.invalid','active')
on conflict (id) do nothing;
SQL
fi

# Remove only a previous run's deterministic fixture/event. This script runs on an ephemeral validation DB.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<SQL
begin;
delete from public.organizational_memory_relations
where source_entity_id in (select entity_id from public.organizational_events where correlation_id='$correlation_id'::uuid)
   or target_entity_id in (select entity_id from public.organizational_events where correlation_id='$correlation_id'::uuid);
delete from public.organizational_events where correlation_id='$correlation_id'::uuid;
delete from public.employees where organization_id='$org_id' and email='$created_email';
commit;
SQL

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# Both clients use the same operation-scoped lock key. Client A holds it for two seconds
# before calling the RPC; client B starts during that interval and must wait for A.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 >"$work_dir/a.log" 2>&1 <<SQL &
begin;
select set_config('request.jwt.claim.sub','$admin_id',false);
set local role authenticated;
select pg_advisory_xact_lock(hashtextextended('$org_id:create_employee_profile:$correlation_id',0));
select pg_sleep(2);
select (public.create_employee_profile('$org_id','P0 Concurrent Employee','$created_email','$area_id','$position_id','pleno','$manager_id','active','$correlation_id'::uuid)).id;
commit;
SQL
pid_a=$!
sleep 0.25
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 >"$work_dir/b.log" 2>&1 <<SQL &
begin;
select set_config('request.jwt.claim.sub','$admin_id',false);
set local role authenticated;
select (public.create_employee_profile('$org_id','P0 Concurrent Employee','$created_email','$area_id','$position_id','pleno','$manager_id','active','$correlation_id'::uuid)).id;
commit;
SQL
pid_b=$!
wait "$pid_a"
wait "$pid_b"

employee_count="$(psql "$DATABASE_URL" -X -Atqc "select count(*) from public.employees where organization_id='$org_id' and email='$created_email'")"
event_count="$(psql "$DATABASE_URL" -X -Atqc "select count(*) from public.organizational_events where organization_id='$org_id' and event_type='employee_created' and correlation_id='$correlation_id'::uuid")"
relation_count="$(psql "$DATABASE_URL" -X -Atqc "select count(*) from public.organizational_memory_relations r join public.employees e on e.id=r.source_entity_id where e.organization_id='$org_id' and e.email='$created_email' and r.valid_until is null and r.relationship_type in ('belongs_to','occupies','reports_to')")"
actor_count="$(psql "$DATABASE_URL" -X -Atqc "select count(*) from public.organizational_events where organization_id='$org_id' and event_type='employee_created' and correlation_id='$correlation_id'::uuid and actor_user_id='$admin_id'::uuid")"

if [[ "$employee_count" != 1 || "$event_count" != 1 || "$relation_count" != 3 || "$actor_count" != 1 ]]; then
  echo "concurrent employee creation failed: employees=$employee_count events=$event_count relations=$relation_count actors=$actor_count"
  cat "$work_dir/a.log" "$work_dir/b.log"
  exit 3
fi

# Clean the deterministic fixture/event created by this concurrency proof.
psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<SQL
begin;
delete from public.organizational_memory_relations
where source_entity_id in (select id from public.employees where organization_id='$org_id' and email='$created_email');
delete from public.organizational_events where organization_id='$org_id' and correlation_id='$correlation_id'::uuid;
delete from public.employees where organization_id='$org_id' and email='$created_email';
commit;
SQL

if [[ "$setup_owned" == 1 ]]; then
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 <<SQL
begin;
delete from public.employees where id='$manager_id';
delete from public.positions where id='$position_id';
delete from public.areas where id='$area_id';
delete from public.memberships where organization_id='$org_id';
delete from public.organizations where id='$org_id';
commit;
SQL
fi

echo "CONCURRENT_EMPLOYEE_CREATE=PASS"
