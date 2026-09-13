-- Data Architecture 2.0 — P0 historical event capture
-- Additive only. Operational tables remain the current-state source of truth.
-- organizational_events is append-only history; memory relations are a temporal projection.

insert into public.organizational_memory_entity_types(entity_type, description) values
  ('competency','A competency reference.'),
  ('position_competency','A position competency mapping reference.')
on conflict (entity_type) do nothing;

insert into public.organizational_memory_relationship_types(relationship_type, description) values
  ('occupies','An employee occupies a position.'),
  ('reports_to','An employee reports to another employee.'),
  ('has_competency','A position has a competency mapping.')
on conflict (relationship_type) do nothing;

insert into public.organizational_event_types(event_type, description, implemented) values
  ('competency_expected_level_changed','A position competency expected level changed.',true),
  ('competency_score_changed','An existing competency score changed.',true),
  ('intervention_started','An intervention became in progress.',true),
  ('intervention_completed','An intervention was completed.',true),
  ('action_started','An intelligence action became in progress.',true),
  ('action_completed','An intelligence action was completed.',true)
on conflict (event_type) do nothing;

-- led_to remains catalogued for compatibility, but cannot be asserted as a fact.
alter table public.organizational_memory_relations
  drop constraint if exists organizational_memory_relations_led_to_epistemic_check;
alter table public.organizational_memory_relations
  add constraint organizational_memory_relations_led_to_epistemic_check
  check (relationship_type <> 'led_to' or knowledge_kind in ('derived','interpreted','hypothesis'));

create or replace function public._organizational_entity_belongs_to_org(
  p_organization_id uuid,
  p_entity_type text,
  p_entity_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if p_entity_id is null then return false; end if;
  if p_entity_type = 'employee' then
    return exists(select 1 from public.employees where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'area' then
    return exists(select 1 from public.areas where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'position' then
    return exists(select 1 from public.positions where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'competency' then
    return exists(select 1 from public.competencies where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'position_competency' then
    return exists(select 1 from public.position_competencies where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'assessment' then
    return exists(select 1 from public.assessments where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'intervention' then
    return exists(select 1 from public.intelligence_interventions where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'action' then
    return exists(select 1 from public.intelligence_actions where organization_id=p_organization_id and id=p_entity_id);
  elsif p_entity_type = 'organization' then
    return exists(select 1 from public.organizations where id=p_organization_id and id=p_entity_id);
  end if;
  return false;
end;
$$;

create or replace function public._append_organizational_event(
  p_organization_id uuid,
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_occurred_at timestamptz,
  p_source_type text,
  p_source_id text,
  p_sensitivity text default 'standard',
  p_payload jsonb default '{}'::jsonb,
  p_correlation_id uuid default gen_random_uuid(),
  p_related_entity_type text default null,
  p_related_entity_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_actor uuid;
  v_implemented boolean;
begin
  v_actor := auth.uid();
  if v_actor is null then
    raise exception 'event actor must come from auth.uid()' using errcode='42501';
  end if;
  if p_organization_id is null or p_event_type is null or p_entity_type is null or p_entity_id is null then
    raise exception 'event tenant, type and entity are required' using errcode='22023';
  end if;
  select implemented into v_implemented
  from public.organizational_event_types
  where event_type=p_event_type;
  if not found or v_implemented is not true then
    raise exception 'event type is not implemented: %', p_event_type using errcode='23514';
  end if;
  if not exists(select 1 from public.organizational_memory_entity_types where entity_type=p_entity_type) then
    raise exception 'event entity type is not registered: %', p_entity_type using errcode='23514';
  end if;
  if not public._organizational_entity_belongs_to_org(p_organization_id,p_entity_type,p_entity_id) then
    raise exception 'event entity is outside the authorized tenant' using errcode='42501';
  end if;
  if p_related_entity_type is not null or p_related_entity_id is not null then
    if p_related_entity_type is null or p_related_entity_id is null then
      raise exception 'related event entity must be provided as a pair' using errcode='22023';
    end if;
    if not exists(select 1 from public.organizational_memory_entity_types where entity_type=p_related_entity_type) then
      raise exception 'event related entity type is not registered: %', p_related_entity_type using errcode='23514';
    end if;
    if not public._organizational_entity_belongs_to_org(p_organization_id,p_related_entity_type,p_related_entity_id) then
      raise exception 'event related entity is outside the authorized tenant' using errcode='42501';
    end if;
  end if;
  if p_source_type not in ('manual','system','service','bee','import','integration') then
    raise exception 'event source type is invalid' using errcode='23514';
  end if;
  if nullif(btrim(coalesce(p_source_id,'')),'') is null then
    raise exception 'event source id is required' using errcode='22023';
  end if;
  if p_sensitivity not in ('standard','restricted','highly_sensitive') then
    raise exception 'event sensitivity is invalid' using errcode='23514';
  end if;
  if p_occurred_at is null or jsonb_typeof(coalesce(p_payload,'{}'::jsonb)) <> 'object' then
    raise exception 'event time and object payload are required' using errcode='22023';
  end if;
  insert into public.organizational_events(
    organization_id,event_type,entity_type,entity_id,related_entity_type,related_entity_id,
    occurred_at,recorded_at,source_type,source_id,actor_user_id,sensitivity,payload,correlation_id
  ) values (
    p_organization_id,p_event_type,p_entity_type,p_entity_id,p_related_entity_type,p_related_entity_id,
    p_occurred_at,now(),p_source_type,p_source_id,v_actor,p_sensitivity,coalesce(p_payload,'{}'::jsonb),coalesce(p_correlation_id,gen_random_uuid())
  ) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public._sync_employee_temporal_relation(
  p_organization_id uuid,
  p_employee_id uuid,
  p_relationship_type text,
  p_target_entity_type text,
  p_target_entity_id uuid,
  p_valid_from timestamptz,
  p_event_id uuid,
  p_correlation_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_relationship_type not in ('occupies','belongs_to','reports_to') then
    raise exception 'employee temporal relationship is not allowed' using errcode='23514';
  end if;
  if not public._organizational_entity_belongs_to_org(p_organization_id,'employee',p_employee_id) then
    raise exception 'employee relation source is outside the tenant' using errcode='42501';
  end if;
  update public.organizational_memory_relations
  set valid_until=p_valid_from
  where organization_id=p_organization_id
    and source_entity_type='employee'
    and source_entity_id=p_employee_id
    and relationship_type=p_relationship_type
    and valid_until is null
    and (p_target_entity_id is null or target_entity_id is distinct from p_target_entity_id);
  if p_target_entity_id is null then return; end if;
  if not public._organizational_entity_belongs_to_org(p_organization_id,p_target_entity_type,p_target_entity_id) then
    raise exception 'employee relation target is outside the tenant' using errcode='42501';
  end if;
  if not exists(
    select 1 from public.organizational_memory_relations
    where organization_id=p_organization_id
      and source_entity_type='employee'
      and source_entity_id=p_employee_id
      and relationship_type=p_relationship_type
      and target_entity_type=p_target_entity_type
      and target_entity_id=p_target_entity_id
      and valid_until is null
  ) then
    insert into public.organizational_memory_relations(
      organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,
      relationship_type,knowledge_kind,valid_from,source_type,source_id,sensitivity,context
    ) values (
      p_organization_id,'employee',p_employee_id,p_target_entity_type,p_target_entity_id,
      p_relationship_type,'fact',p_valid_from,'service',p_event_id::text,'standard',
      jsonb_build_object('event_id',p_event_id,'correlation_id',p_correlation_id)
    );
  end if;
end;
$$;

-- The new writer is internal: domain functions call it, authenticated clients cannot.
revoke all on function public._organizational_entity_belongs_to_org(uuid,text,uuid) from public, authenticated, anon;
revoke all on function public._append_organizational_event(uuid,text,text,uuid,timestamptz,text,text,text,jsonb,uuid,text,uuid) from public, authenticated, anon;
revoke all on function public._sync_employee_temporal_relation(uuid,uuid,text,text,uuid,timestamptz,uuid,uuid) from public, authenticated, anon;

create or replace function public.update_employee_profile(
  p_employee_id uuid,
  p_full_name text,
  p_email text,
  p_area_id uuid,
  p_position_id uuid,
  p_seniority text,
  p_manager_employee_id uuid,
  p_status text default null
)
returns public.employees
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_before public.employees%rowtype;
  v_after public.employees%rowtype;
  v_org uuid;
  v_status text;
  v_now timestamptz := clock_timestamp();
  v_correlation uuid := gen_random_uuid();
  v_event uuid;
begin
  select e.* into strict v_before from public.employees e where e.id=p_employee_id for update;
  v_org := v_before.organization_id;
  if not public.has_org_role(v_org,array['admin_youb','rh']) then
    raise exception 'employee update is not authorized' using errcode='42501';
  end if;
  if nullif(btrim(coalesce(p_full_name,'')),'') is null then
    raise exception 'employee name is required' using errcode='22023';
  end if;
  if p_seniority is not null and p_seniority not in ('junior','pleno','senior') then
    raise exception 'employee seniority is invalid' using errcode='23514';
  end if;
  v_status := coalesce(p_status,v_before.status);
  if v_status not in ('active','inactive') then
    raise exception 'employee status is invalid' using errcode='23514';
  end if;
  if p_area_id is not null and not public._organizational_entity_belongs_to_org(v_org,'area',p_area_id) then
    raise exception 'area is outside the employee tenant' using errcode='42501';
  end if;
  if p_position_id is not null and not public._organizational_entity_belongs_to_org(v_org,'position',p_position_id) then
    raise exception 'position is outside the employee tenant' using errcode='42501';
  end if;
  if p_manager_employee_id is not null and (p_manager_employee_id=p_employee_id or not public._organizational_entity_belongs_to_org(v_org,'employee',p_manager_employee_id)) then
    raise exception 'manager is invalid for the employee tenant' using errcode='23514';
  end if;
  update public.employees
  set full_name=btrim(p_full_name), email=nullif(btrim(p_email),''), area_id=p_area_id,
      position_id=p_position_id, seniority=p_seniority, manager_employee_id=p_manager_employee_id,
      status=v_status
  where id=p_employee_id;
  if v_before.status is distinct from v_status then
    v_event := public._append_organizational_event(v_org,'employee_status_changed','employee',p_employee_id,v_now,'service','update_employee_profile','standard',jsonb_build_object('before',v_before.status,'after',v_status),v_correlation);
  end if;
  if v_before.area_id is distinct from p_area_id then
    v_event := public._append_organizational_event(v_org,'area_changed','employee',p_employee_id,v_now,'service','update_employee_profile','standard',jsonb_build_object('before',v_before.area_id,'after',p_area_id),v_correlation,case when p_area_id is null then null else 'area' end,p_area_id);
    perform public._sync_employee_temporal_relation(v_org,p_employee_id,'belongs_to','area',p_area_id,v_now,v_event,v_correlation);
  end if;
  if v_before.position_id is distinct from p_position_id then
    v_event := public._append_organizational_event(v_org,'position_changed','employee',p_employee_id,v_now,'service','update_employee_profile','standard',jsonb_build_object('before',v_before.position_id,'after',p_position_id),v_correlation,case when p_position_id is null then null else 'position' end,p_position_id);
    perform public._sync_employee_temporal_relation(v_org,p_employee_id,'occupies','position',p_position_id,v_now,v_event,v_correlation);
  end if;
  if v_before.manager_employee_id is distinct from p_manager_employee_id then
    v_event := public._append_organizational_event(v_org,'manager_changed','employee',p_employee_id,v_now,'service','update_employee_profile','standard',jsonb_build_object('before',v_before.manager_employee_id,'after',p_manager_employee_id),v_correlation,case when p_manager_employee_id is null then null else 'employee' end,p_manager_employee_id);
    perform public._sync_employee_temporal_relation(v_org,p_employee_id,'reports_to','employee',p_manager_employee_id,v_now,v_event,v_correlation);
  end if;
  select e.* into strict v_after from public.employees e where e.id=p_employee_id;
  return v_after;
end;
$$;

revoke update on public.employees from authenticated;
revoke all on function public.update_employee_profile(uuid,text,text,uuid,uuid,text,uuid,text) from public;
grant execute on function public.update_employee_profile(uuid,text,text,uuid,uuid,text,uuid,text) to authenticated;

create or replace function public.create_employee_profile(
  p_organization_id uuid,
  p_full_name text,
  p_email text default null,
  p_area_id uuid default null,
  p_position_id uuid default null,
  p_seniority text default null,
  p_manager_employee_id uuid default null,
  p_status text default 'active',
  p_correlation_id uuid default null
)
returns public.employees
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_employee public.employees%rowtype;
  v_existing_id uuid;
  v_correlation uuid := coalesce(p_correlation_id,gen_random_uuid());
  v_employee_id uuid := gen_random_uuid();
  v_now timestamptz := clock_timestamp();
  v_event uuid;
  v_status text := coalesce(p_status,'active');
begin
  if auth.uid() is null or p_organization_id is null or not public.has_org_role(p_organization_id,array['admin_youb','diretoria','rh']) then
    raise exception 'employee creation is not authorized' using errcode='42501';
  end if;
  if p_correlation_id is not null then
    select oe.entity_id into v_existing_id
    from public.organizational_events oe
    where oe.organization_id=p_organization_id
      and oe.event_type='employee_created'
      and oe.entity_type='employee'
      and oe.source_type='service'
      and oe.source_id='create_employee_profile'
      and oe.correlation_id=p_correlation_id
    limit 1;
    if v_existing_id is not null then
      select e.* into strict v_employee from public.employees e where e.organization_id=p_organization_id and e.id=v_existing_id;
      return v_employee;
    end if;
  end if;
  if nullif(btrim(coalesce(p_full_name,'')),'') is null then
    raise exception 'employee name is required' using errcode='22023';
  end if;
  if v_status not in ('active','inactive') then
    raise exception 'employee status is invalid' using errcode='23514';
  end if;
  if p_seniority is not null and p_seniority not in ('junior','pleno','senior') then
    raise exception 'employee seniority is invalid' using errcode='23514';
  end if;
  if p_area_id is not null and not public._organizational_entity_belongs_to_org(p_organization_id,'area',p_area_id) then
    raise exception 'area is outside the employee tenant' using errcode='42501';
  end if;
  if p_position_id is not null and not public._organizational_entity_belongs_to_org(p_organization_id,'position',p_position_id) then
    raise exception 'position is outside the employee tenant' using errcode='42501';
  end if;
  if p_manager_employee_id is not null then
    if p_manager_employee_id=v_employee_id or not public._organizational_entity_belongs_to_org(p_organization_id,'employee',p_manager_employee_id) then
      raise exception 'manager is invalid for the employee tenant' using errcode='23514';
    end if;
  end if;
  insert into public.employees(id,organization_id,full_name,email,area_id,position_id,seniority,manager_employee_id,status,created_at)
  values(v_employee_id,p_organization_id,btrim(p_full_name),nullif(btrim(p_email),''),p_area_id,p_position_id,p_seniority,p_manager_employee_id,v_status,v_now)
  returning * into strict v_employee;
  v_event := public._append_organizational_event(
    p_organization_id,'employee_created','employee',v_employee.id,v_now,'service','create_employee_profile','standard',
    jsonb_build_object('status',v_employee.status,'area_id',v_employee.area_id,'position_id',v_employee.position_id,'manager_employee_id',v_employee.manager_employee_id,'seniority',v_employee.seniority),
    v_correlation
  );
  if v_employee.area_id is not null then
    perform public._sync_employee_temporal_relation(p_organization_id,v_employee.id,'belongs_to','area',v_employee.area_id,v_now,v_event,v_correlation);
  end if;
  if v_employee.position_id is not null then
    perform public._sync_employee_temporal_relation(p_organization_id,v_employee.id,'occupies','position',v_employee.position_id,v_now,v_event,v_correlation);
  end if;
  if v_employee.manager_employee_id is not null then
    perform public._sync_employee_temporal_relation(p_organization_id,v_employee.id,'reports_to','employee',v_employee.manager_employee_id,v_now,v_event,v_correlation);
  end if;
  return v_employee;
end;
$$;

-- Employee creation is controlled by the domain RPC; employees may still have no auth_user_id.
revoke insert on public.employees from authenticated;
revoke all on function public.create_employee_profile(uuid,text,text,uuid,uuid,text,uuid,text,uuid) from public;
grant execute on function public.create_employee_profile(uuid,text,text,uuid,uuid,text,uuid,text,uuid) to authenticated;

-- Assessment mapping and score writes already use domain RPCs. Add event capture there.
create or replace function public.cca_update_position_competency(p_id uuid,p_expected_level smallint,p_active boolean)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; old_level smallint; old_active boolean; pos uuid; comp uuid; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  select organization_id,position_id,competency_id,expected_level,active into o,pos,comp,old_level,old_active from public.position_competencies where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'mapping is outside the authorized tenant' using errcode='42501'; end if;
  if p_expected_level not between 1 and 5 then raise exception 'expected_level must be between 1 and 5' using errcode='23514'; end if;
  update public.position_competencies set expected_level=p_expected_level,active=p_active where id=p_id;
  if old_level is distinct from p_expected_level then
    ev:=public._append_organizational_event(o,'competency_expected_level_changed','position_competency',p_id,now_at,'service','cca_update_position_competency','standard',jsonb_build_object('before',old_level,'after',p_expected_level,'position_id',pos,'competency_id',comp,'active_before',old_active,'active_after',p_active),corr,'competency',comp);
  end if;
  return true;
end $$;

create or replace function public.cca_save_assessment_score(p_assessment_id uuid,p_competency_id uuid,p_score smallint,p_evidence_note text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; cycle_status text; old_score smallint; old_note text; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  if p_score is null or p_score not between 1 and 5 then raise exception 'score must be an integer between 1 and 5' using errcode='23514'; end if;
  select a.organization_id,a.status,c.status into o,s,cycle_status from public.assessments a join public.cycles c on c.organization_id=a.organization_id and c.id=a.cycle_id where a.id=p_assessment_id for update;
  if o is null or not public.cca_can_manage_assessment(o,p_assessment_id) then raise exception 'assessment is outside the authorized population' using errcode='42501'; end if;
  if s not in ('draft','in_progress') or cycle_status <> 'active' then raise exception 'assessment is not editable' using errcode='23514'; end if;
  select score,evidence_note into old_score,old_note from public.assessment_competency_scores where organization_id=o and assessment_id=p_assessment_id and competency_id=p_competency_id for update;
  if not found then raise exception 'competency is not part of the assessment snapshot' using errcode='23503'; end if;
  update public.assessment_competency_scores set score=p_score,evidence_note=nullif(btrim(p_evidence_note),''),updated_at=now() where organization_id=o and assessment_id=p_assessment_id and competency_id=p_competency_id;
  update public.assessments set status='in_progress',updated_at=now() where id=p_assessment_id;
  if old_score is distinct from p_score then
    ev:=public._append_organizational_event(o,'competency_score_changed','assessment',p_assessment_id,now_at,'service','cca_save_assessment_score','standard',jsonb_build_object('competency_id',p_competency_id,'before',old_score,'after',p_score,'evidence_note_before',old_note,'evidence_note_after',nullif(btrim(p_evidence_note),'')),corr,'competency',p_competency_id);
  end if;
  return true;
end $$;

-- Lifecycle writes are domain RPCs; authenticated clients cannot update/delete these states directly.
alter table public.intelligence_interventions add column if not exists started_at timestamptz;
alter table public.intelligence_interventions add column if not exists completed_at timestamptz;
alter table public.intelligence_actions add column if not exists started_at timestamptz;

create or replace function public.intelligence_start_intervention(p_intervention_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.intelligence_interventions%rowtype; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  select * into strict r from public.intelligence_interventions where id=p_intervention_id for update;
  if not (public.intelligence_is_decision_maker(r.organization_id) or (r.employee_id is not null and public.intelligence_has_employee_scope(r.organization_id,r.employee_id))) then raise exception 'intervention is outside the authorized scope' using errcode='42501'; end if;
  if r.status='in_progress' then return true; end if;
  if r.status not in ('approved','proposed') then raise exception 'intervention cannot be started from status %',r.status using errcode='23514'; end if;
  update public.intelligence_interventions set status='in_progress',started_at=now(),updated_at=now() where id=p_intervention_id;
  ev:=public._append_organizational_event(r.organization_id,'intervention_started','intervention',r.id,now_at,'service','intelligence_start_intervention','standard',jsonb_build_object('before',r.status,'after','in_progress','employee_id',r.employee_id,'owner_employee_id',r.owner_employee_id),corr,case when r.employee_id is null then null else 'employee' end,r.employee_id);
  return true;
end $$;

create or replace function public.intelligence_complete_intervention(p_intervention_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.intelligence_interventions%rowtype; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  select * into strict r from public.intelligence_interventions where id=p_intervention_id for update;
  if not (public.intelligence_is_decision_maker(r.organization_id) or (r.employee_id is not null and public.intelligence_has_employee_scope(r.organization_id,r.employee_id))) then raise exception 'intervention is outside the authorized scope' using errcode='42501'; end if;
  if r.status='completed' then return true; end if;
  if r.status<>'in_progress' then raise exception 'intervention cannot be completed from status %',r.status using errcode='23514'; end if;
  update public.intelligence_interventions set status='completed',completed_at=now(),updated_at=now() where id=p_intervention_id;
  ev:=public._append_organizational_event(r.organization_id,'intervention_completed','intervention',r.id,now_at,'service','intelligence_complete_intervention','standard',jsonb_build_object('before',r.status,'after','completed','employee_id',r.employee_id,'owner_employee_id',r.owner_employee_id),corr,case when r.employee_id is null then null else 'employee' end,r.employee_id);
  return true;
end $$;

create or replace function public.intelligence_start_action(p_action_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.intelligence_actions%rowtype; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  select * into strict r from public.intelligence_actions where id=p_action_id for update;
  if not (public.intelligence_is_decision_maker(r.organization_id) or (r.assignee_employee_id is not null and public.intelligence_has_employee_scope(r.organization_id,r.assignee_employee_id))) then raise exception 'action is outside the authorized scope' using errcode='42501'; end if;
  if r.status='in_progress' then return true; end if;
  if r.status not in ('approved','proposed') then raise exception 'action cannot be started from status %',r.status using errcode='23514'; end if;
  update public.intelligence_actions set status='in_progress',started_at=now(),updated_at=now() where id=p_action_id;
  ev:=public._append_organizational_event(r.organization_id,'action_started','action',r.id,now_at,'service','intelligence_start_action','standard',jsonb_build_object('before',r.status,'after','in_progress','intervention_id',r.intervention_id,'assignee_employee_id',r.assignee_employee_id),corr,case when r.intervention_id is null then null else 'intervention' end,r.intervention_id);
  return true;
end $$;

create or replace function public.intelligence_complete_action(p_action_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.intelligence_actions%rowtype; ev uuid; corr uuid:=gen_random_uuid(); now_at timestamptz:=clock_timestamp();
begin
  select * into strict r from public.intelligence_actions where id=p_action_id for update;
  if not (public.intelligence_is_decision_maker(r.organization_id) or (r.assignee_employee_id is not null and public.intelligence_has_employee_scope(r.organization_id,r.assignee_employee_id))) then raise exception 'action is outside the authorized scope' using errcode='42501'; end if;
  if r.status='completed' then return true; end if;
  if r.status<>'in_progress' then raise exception 'action cannot be completed from status %',r.status using errcode='23514'; end if;
  update public.intelligence_actions set status='completed',completed_at=coalesce(completed_at,now()),updated_at=now() where id=p_action_id;
  ev:=public._append_organizational_event(r.organization_id,'action_completed','action',r.id,now_at,'service','intelligence_complete_action','standard',jsonb_build_object('before',r.status,'after','completed','intervention_id',r.intervention_id,'assignee_employee_id',r.assignee_employee_id),corr,case when r.intervention_id is null then null else 'intervention' end,r.intervention_id);
  return true;
end $$;

revoke update,delete on public.intelligence_interventions,public.intelligence_actions from authenticated;
revoke all on function public.intelligence_start_intervention(uuid),public.intelligence_complete_intervention(uuid),public.intelligence_start_action(uuid),public.intelligence_complete_action(uuid) from public;
grant execute on function public.intelligence_start_intervention(uuid),public.intelligence_complete_intervention(uuid),public.intelligence_start_action(uuid),public.intelligence_complete_action(uuid) to authenticated;

revoke update,delete on public.organizational_events from authenticated;
