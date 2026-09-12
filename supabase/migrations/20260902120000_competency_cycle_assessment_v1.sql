-- youB — Competency + Cycle + Assessment V1
-- Additive implementation on top of PR #13. Do not edit historical migrations.
-- New assessments use normalized competency score rows; legacy scores JSONB is preserved.

-- Tenant-safe candidate keys are prerequisites for all composite foreign keys.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'positions_organization_id_id_key' and conrelid = 'public.positions'::regclass) then
    alter table public.positions add constraint positions_organization_id_id_key unique (organization_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'competencies_organization_id_id_key' and conrelid = 'public.competencies'::regclass) then
    alter table public.competencies add constraint competencies_organization_id_id_key unique (organization_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'cycles_organization_id_id_key' and conrelid = 'public.cycles'::regclass) then
    alter table public.cycles add constraint cycles_organization_id_id_key unique (organization_id, id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'assessments_organization_id_id_key' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_organization_id_id_key unique (organization_id, id);
  end if;
end $$;

-- Fail closed on legacy references before installing tenant-safe foreign keys.
do $$
declare n bigint;
begin
  select count(*) into n from public.assessments a where not exists (select 1 from public.cycles c where c.id=a.cycle_id and c.organization_id=a.organization_id);
  if n > 0 then raise exception 'competency_cycle_assessment_v1 preflight: % assessments reference a cycle in another tenant or no cycle', n using errcode='23503'; end if;
  select count(*) into n from public.assessments a where not exists (select 1 from public.employees e where e.id=a.subject_employee_id and e.organization_id=a.organization_id);
  if n > 0 then raise exception 'competency_cycle_assessment_v1 preflight: % assessments reference a subject in another tenant or no employee', n using errcode='23503'; end if;
  select count(*) into n from public.assessments a where a.evaluator_employee_id is not null and not exists (select 1 from public.employees e where e.id=a.evaluator_employee_id and e.organization_id=a.organization_id);
  if n > 0 then raise exception 'competency_cycle_assessment_v1 preflight: % assessments reference an evaluator in another tenant or no employee', n using errcode='23503'; end if;
end $$;

alter table public.cycles add column if not exists updated_at timestamptz not null default now();
alter table public.cycles add column if not exists activated_at timestamptz;
alter table public.cycles add column if not exists closed_at timestamptz;
alter table public.cycles add column if not exists created_by_user_id uuid references auth.users(id) on delete set null;
alter table public.cycles add constraint cycles_name_not_blank_check check (length(btrim(name)) > 0);
alter table public.cycles add constraint cycles_dates_order_check check (starts_at is null or ends_at is null or ends_at >= starts_at);

alter table public.assessments add column if not exists position_id uuid;
alter table public.assessments add column if not exists status text not null default 'draft';
alter table public.assessments add column if not exists created_by_user_id uuid references auth.users(id) on delete set null;
alter table public.assessments add column if not exists updated_at timestamptz not null default now();
alter table public.assessments add column if not exists submitted_at timestamptz;
alter table public.assessments add column if not exists completed_at timestamptz;
alter table public.assessments add column if not exists completed_by_user_id uuid references auth.users(id) on delete set null;
alter table public.assessments add constraint assessments_status_check check (status in ('draft','in_progress','submitted','completed'));
alter table public.assessments add constraint assessments_status_timestamps_check check (
  (status in ('draft','in_progress') and submitted_at is null and completed_at is null)
  or (status = 'submitted' and submitted_at is not null and completed_at is null)
  or (status = 'completed' and submitted_at is not null and completed_at is not null)
);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'assessments_cycle_same_org_fkey' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_cycle_same_org_fkey foreign key (organization_id, cycle_id) references public.cycles(organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'assessments_subject_same_org_fkey' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_subject_same_org_fkey foreign key (organization_id, subject_employee_id) references public.employees(organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'assessments_evaluator_same_org_fkey' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_evaluator_same_org_fkey foreign key (organization_id, evaluator_employee_id) references public.employees(organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'assessments_position_same_org_fkey' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_position_same_org_fkey foreign key (organization_id, position_id) references public.positions(organization_id,id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'assessments_cycle_subject_unique' and conrelid = 'public.assessments'::regclass) then
    alter table public.assessments add constraint assessments_cycle_subject_unique unique (organization_id,cycle_id,subject_employee_id);
  end if;
end $$;

create table if not exists public.position_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  position_id uuid not null,
  competency_id uuid not null,
  expected_level smallint not null check (expected_level between 1 and 5),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint position_competencies_organization_id_id_key unique (organization_id,id),
  constraint position_competencies_unique_mapping unique (organization_id,position_id,competency_id),
  constraint position_competencies_position_same_org_fkey foreign key (organization_id,position_id) references public.positions(organization_id,id) on delete restrict,
  constraint position_competencies_competency_same_org_fkey foreign key (organization_id,competency_id) references public.competencies(organization_id,id) on delete restrict
);

create table if not exists public.assessment_competency_scores (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  assessment_id uuid not null,
  competency_id uuid not null,
  position_competency_id uuid not null,
  expected_level_snapshot smallint not null check (expected_level_snapshot between 1 and 5),
  score smallint check (score is null or score between 1 and 5),
  evidence_note text check (evidence_note is null or char_length(evidence_note) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint assessment_competency_scores_organization_id_id_key unique (organization_id,id),
  constraint assessment_competency_scores_unique unique (organization_id,assessment_id,competency_id),
  constraint assessment_scores_assessment_same_org_fkey foreign key (organization_id,assessment_id) references public.assessments(organization_id,id) on delete cascade,
  constraint assessment_scores_competency_same_org_fkey foreign key (organization_id,competency_id) references public.competencies(organization_id,id) on delete restrict,
  constraint assessment_scores_mapping_same_org_fkey foreign key (organization_id,position_competency_id) references public.position_competencies(organization_id,id) on delete restrict
);

create index if not exists idx_position_competencies_org_position on public.position_competencies(organization_id,position_id,active);
create index if not exists idx_position_competencies_org_competency on public.position_competencies(organization_id,competency_id);
create index if not exists idx_assessment_scores_org_assessment on public.assessment_competency_scores(organization_id,assessment_id);
create index if not exists idx_assessment_scores_org_competency on public.assessment_competency_scores(organization_id,competency_id);
create index if not exists idx_assessments_org_status on public.assessments(organization_id,status,cycle_id);

alter table public.position_competencies enable row level security;
alter table public.assessment_competency_scores enable row level security;

create or replace function public.cca_set_updated_at()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists cca_cycles_updated_at on public.cycles;
create trigger cca_cycles_updated_at before update on public.cycles for each row execute function public.cca_set_updated_at();
drop trigger if exists cca_assessments_updated_at on public.assessments;
create trigger cca_assessments_updated_at before update on public.assessments for each row execute function public.cca_set_updated_at();
drop trigger if exists cca_position_competencies_updated_at on public.position_competencies;
create trigger cca_position_competencies_updated_at before update on public.position_competencies for each row execute function public.cca_set_updated_at();
drop trigger if exists cca_assessment_scores_updated_at on public.assessment_competency_scores;
create trigger cca_assessment_scores_updated_at before update on public.assessment_competency_scores for each row execute function public.cca_set_updated_at();

-- New assessment rows capture the subject's position and never accept a client-supplied mismatch.
create or replace function public.cca_capture_assessment_position()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare p_org uuid; p_position uuid; p_status text;
begin
  select e.organization_id,e.position_id into p_org,p_position from public.employees e where e.id=new.subject_employee_id;
  if p_org is null or p_org <> new.organization_id then raise exception 'assessment subject must belong to the same tenant' using errcode='23503'; end if;
  -- Legacy fixture/data rows may remain draft and position-less for compatibility;
  -- every V1 RPC-created assessment has created_by_user_id and requires a position.
  if p_position is null and new.created_by_user_id is not null then raise exception 'assessment configuration pending: subject employee has no position' using errcode='23514'; end if;
  if new.position_id is not null and new.position_id <> p_position then raise exception 'assessment position snapshot does not match subject position' using errcode='23514'; end if;
  new.position_id := p_position;
  if new.status is null then new.status := 'draft'; end if;
  if new.status not in ('draft','in_progress','submitted','completed') then raise exception 'invalid assessment lifecycle status' using errcode='23514'; end if;
  return new;
end $$;
drop trigger if exists cca_assessment_position_snapshot on public.assessments;
create trigger cca_assessment_position_snapshot before insert on public.assessments for each row execute function public.cca_capture_assessment_position();

create or replace function public.cca_employee_has_role(target_org uuid, target_employee uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists (select 1 from public.employees e join public.memberships m on m.organization_id=e.organization_id and m.user_id=e.auth_user_id where e.organization_id=target_org and e.id=target_employee and e.status='active' and m.role=any(allowed_roles));
$$;

create or replace function public.cca_is_assessment_manager(target_org uuid, target_assessment uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists (
    select 1 from public.assessments a
    where a.organization_id=target_org and a.id=target_assessment
      and public.classic_has_single_own_employee(target_org,a.evaluator_employee_id)
      and public.classic_is_direct_report(target_org,a.subject_employee_id)
      and a.evaluator_employee_id=public.classic_manager_employee_id(target_org)
  );
$$;

create or replace function public.cca_can_manage_assessment(target_org uuid, target_assessment uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select public.classic_is_org_admin(target_org) or public.cca_is_assessment_manager(target_org,target_assessment);
$$;

-- Replace broad legacy assessment policies with lifecycle- and population-aware reads.
do $$ declare r record; begin
  for r in select policyname from pg_policies where schemaname='public' and tablename='assessments' loop execute format('drop policy if exists %I on public.assessments',r.policyname); end loop;
end $$;
create policy cca_assessments_select_scoped on public.assessments for select to authenticated using (
  public.classic_is_org_admin(organization_id)
  or public.cca_is_assessment_manager(organization_id,id)
  or (public.has_org_role(organization_id,array['colaborador']) and status='completed' and public.classic_has_single_own_employee(organization_id,subject_employee_id))
);

do $$ declare r record; begin
  for r in select policyname from pg_policies where schemaname='public' and tablename='cycles' loop execute format('drop policy if exists %I on public.cycles',r.policyname); end loop;
end $$;
create policy cca_cycles_select_members on public.cycles for select to authenticated using (public.is_org_member(organization_id));

do $$ declare r record; begin
  for r in select policyname from pg_policies where schemaname='public' and tablename='competencies' loop execute format('drop policy if exists %I on public.competencies',r.policyname); end loop;
end $$;
create policy cca_competencies_select_members on public.competencies for select to authenticated using (public.is_org_member(organization_id));

create policy cca_position_competencies_select_scoped on public.position_competencies for select to authenticated using (
  public.classic_is_org_admin(organization_id)
  or public.has_org_role(organization_id,array['diretoria'])
  or exists (select 1 from public.employees e where e.organization_id=position_competencies.organization_id and e.position_id=position_competencies.position_id and e.status='active' and public.classic_is_direct_report(position_competencies.organization_id,e.id))
  or exists (select 1 from public.assessment_competency_scores s join public.assessments a on a.organization_id=s.organization_id and a.id=s.assessment_id where s.organization_id=position_competencies.organization_id and s.position_competency_id=position_competencies.id and a.status='completed' and public.classic_has_single_own_employee(a.organization_id,a.subject_employee_id))
);

create policy cca_assessment_scores_select_scoped on public.assessment_competency_scores for select to authenticated using (
  exists (select 1 from public.assessments a where a.organization_id=assessment_competency_scores.organization_id and a.id=assessment_competency_scores.assessment_id and (
    public.classic_is_org_admin(a.organization_id) or public.cca_is_assessment_manager(a.organization_id,a.id) or (a.status='completed' and public.classic_has_single_own_employee(a.organization_id,a.subject_employee_id))
  ))
);

revoke insert,update,delete on public.cycles,public.competencies,public.assessments,public.position_competencies,public.assessment_competency_scores from authenticated;
grant select on public.cycles,public.competencies,public.assessments,public.position_competencies,public.assessment_competency_scores to authenticated;

create or replace function public.cca_create_competency(p_organization_id uuid,p_name text,p_description text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare i uuid;
begin
  if not public.classic_is_org_admin(p_organization_id) then raise exception 'only Admin/RH can create competencies in this tenant' using errcode='42501'; end if;
  insert into public.competencies(organization_id,name,description,active) values(p_organization_id,btrim(p_name),nullif(btrim(p_description),''),true) returning id into i;
  return i;
end $$;

create or replace function public.cca_update_competency(p_id uuid,p_name text,p_description text,p_active boolean)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid;
begin
  select organization_id into o from public.competencies where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'competency is outside the authorized tenant' using errcode='42501'; end if;
  update public.competencies set name=btrim(p_name),description=nullif(btrim(p_description),''),active=p_active where id=p_id;
  return true;
end $$;

create or replace function public.cca_create_position_competency(p_position_id uuid,p_competency_id uuid,p_expected_level smallint)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; i uuid;
begin
  select p.organization_id into o from public.positions p where p.id=p_position_id;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'position is outside the authorized tenant' using errcode='42501'; end if;
  if not exists(select 1 from public.competencies c where c.id=p_competency_id and c.organization_id=o and c.active) then raise exception 'competency is outside the authorized tenant or inactive' using errcode='23503'; end if;
  if p_expected_level not between 1 and 5 then raise exception 'expected_level must be between 1 and 5' using errcode='23514'; end if;
  insert into public.position_competencies(organization_id,position_id,competency_id,expected_level,active) values(o,p_position_id,p_competency_id,p_expected_level,true) returning id into i;
  return i;
exception when unique_violation then raise exception 'duplicate competency mapping for this position' using errcode='23505';
end $$;

create or replace function public.cca_update_position_competency(p_id uuid,p_expected_level smallint,p_active boolean)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid;
begin
  select organization_id into o from public.position_competencies where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'mapping is outside the authorized tenant' using errcode='42501'; end if;
  if p_expected_level not between 1 and 5 then raise exception 'expected_level must be between 1 and 5' using errcode='23514'; end if;
  update public.position_competencies set expected_level=p_expected_level,active=p_active where id=p_id;
  return true;
end $$;

create or replace function public.cca_deactivate_position_competency(p_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid;
begin
  select organization_id into o from public.position_competencies where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'mapping is outside the authorized tenant' using errcode='42501'; end if;
  update public.position_competencies set active=false where id=p_id;
  return true;
end $$;

create or replace function public.cca_create_cycle(p_organization_id uuid,p_name text,p_cycle_type text default 'performance',p_starts_at date default null,p_ends_at date default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare i uuid;
begin
  if not public.classic_is_org_admin(p_organization_id) then raise exception 'only Admin/RH can create cycles in this tenant' using errcode='42501'; end if;
  if p_starts_at is not null and p_ends_at is not null and p_ends_at < p_starts_at then raise exception 'cycle period is invalid' using errcode='23514'; end if;
  insert into public.cycles(organization_id,name,cycle_type,starts_at,ends_at,status,created_by_user_id) values(p_organization_id,btrim(p_name),coalesce(nullif(btrim(p_cycle_type),''),'performance'),p_starts_at,p_ends_at,'draft',auth.uid()) returning id into i;
  return i;
end $$;

create or replace function public.cca_update_draft_cycle(p_id uuid,p_name text,p_starts_at date,p_ends_at date)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text;
begin
  select organization_id,status into o,s from public.cycles where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'cycle is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' then raise exception 'only draft cycles are editable' using errcode='23514'; end if;
  if p_ends_at is null or p_starts_at is null or p_ends_at < p_starts_at then raise exception 'active cycle requires a valid period' using errcode='23514'; end if;
  update public.cycles set name=btrim(p_name),starts_at=p_starts_at,ends_at=p_ends_at where id=p_id;
  return true;
end $$;

create or replace function public.cca_activate_cycle(p_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; a date; e date;
begin
  select organization_id,status,starts_at,ends_at into o,s,a,e from public.cycles where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'cycle is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' then raise exception 'only draft cycles can be activated' using errcode='23514'; end if;
  if a is null or e is null or e < a then raise exception 'cycle activation requires a valid period' using errcode='23514'; end if;
  update public.cycles set status='active',activated_at=now() where id=p_id;
  return true;
end $$;

create or replace function public.cca_close_cycle(p_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text;
begin
  select organization_id,status into o,s from public.cycles where id=p_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'cycle is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'active' then raise exception 'only active cycles can be closed' using errcode='23514'; end if;
  update public.cycles set status='closed',closed_at=now() where id=p_id;
  return true;
end $$;

create or replace function public.cca_create_assessment(p_cycle_id uuid,p_subject_employee_id uuid,p_evaluator_employee_id uuid)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; cycle_status text; subject_pos uuid; manager_id uuid; i uuid; n bigint;
begin
  select c.organization_id,c.status into o,cycle_status from public.cycles c where c.id=p_cycle_id;
  if o is null or cycle_status <> 'active' then raise exception 'assessment requires an active cycle' using errcode='23514'; end if;
  select e.position_id,e.manager_employee_id into subject_pos,manager_id from public.employees e where e.id=p_subject_employee_id and e.organization_id=o and e.status='active';
  if not found then raise exception 'assessment subject is outside the authorized tenant or inactive' using errcode='42501'; end if;
  if subject_pos is null then raise exception 'assessment configuration pending: subject employee has no position' using errcode='23514'; end if;
  select count(*) into n from public.position_competencies pc where pc.organization_id=o and pc.position_id=subject_pos and pc.active;
  if n=0 then raise exception 'assessment configuration pending: position has no active competency mapping' using errcode='23514'; end if;
  if not exists(select 1 from public.employees e where e.id=p_evaluator_employee_id and e.organization_id=o and e.status='active' and e.auth_user_id is not null) then raise exception 'evaluator is outside the authorized tenant or inactive' using errcode='42501'; end if;
  if public.classic_is_org_admin(o) then
    if p_evaluator_employee_id <> manager_id and not public.cca_employee_has_role(o,p_evaluator_employee_id,array['admin_youb','rh']) then raise exception 'evaluator is not authorized for this subject' using errcode='42501'; end if;
  elsif public.classic_is_direct_report(o,p_subject_employee_id) and p_evaluator_employee_id=public.classic_manager_employee_id(o) then
    null;
  else
    raise exception 'only the authorized direct manager can create this assessment' using errcode='42501';
  end if;
  insert into public.assessments(organization_id,cycle_id,subject_employee_id,evaluator_employee_id,position_id,status,created_by_user_id)
    values(o,p_cycle_id,p_subject_employee_id,p_evaluator_employee_id,subject_pos,'draft',auth.uid()) returning id into i;
  insert into public.assessment_competency_scores(organization_id,assessment_id,competency_id,position_competency_id,expected_level_snapshot)
    select o,i,pc.competency_id,pc.id,pc.expected_level from public.position_competencies pc where pc.organization_id=o and pc.position_id=subject_pos and pc.active;
  return i;
exception when unique_violation then raise exception 'equivalent assessment already exists for this cycle and subject' using errcode='23505';
end $$;

create or replace function public.cca_save_assessment_score(p_assessment_id uuid,p_competency_id uuid,p_score smallint,p_evidence_note text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; cycle_status text;
begin
  if p_score is null or p_score not between 1 and 5 then raise exception 'score must be an integer between 1 and 5' using errcode='23514'; end if;
  select a.organization_id,a.status,c.status into o,s,cycle_status from public.assessments a join public.cycles c on c.organization_id=a.organization_id and c.id=a.cycle_id where a.id=p_assessment_id for update;
  if o is null or not public.cca_can_manage_assessment(o,p_assessment_id) then raise exception 'assessment is outside the authorized population' using errcode='42501'; end if;
  if s not in ('draft','in_progress') or cycle_status <> 'active' then raise exception 'assessment is not editable' using errcode='23514'; end if;
  update public.assessment_competency_scores set score=p_score,evidence_note=nullif(btrim(p_evidence_note),''),updated_at=now() where organization_id=o and assessment_id=p_assessment_id and competency_id=p_competency_id;
  if not found then raise exception 'competency is not part of the assessment snapshot' using errcode='23503'; end if;
  update public.assessments set status='in_progress',updated_at=now() where id=p_assessment_id;
  return true;
end $$;

create or replace function public.cca_submit_assessment(p_assessment_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; cycle_status text; total bigint; filled bigint;
begin
  select a.organization_id,a.status,c.status into o,s,cycle_status from public.assessments a join public.cycles c on c.organization_id=a.organization_id and c.id=a.cycle_id where a.id=p_assessment_id for update;
  if o is null or not public.cca_is_assessment_manager(o,p_assessment_id) then raise exception 'only the assigned evaluator can submit this assessment' using errcode='42501'; end if;
  if s not in ('draft','in_progress') or cycle_status <> 'active' then raise exception 'assessment cannot be submitted in its current state' using errcode='23514'; end if;
  select count(*),count(*) filter(where score is not null) into total,filled from public.assessment_competency_scores where organization_id=o and assessment_id=p_assessment_id;
  if total=0 or total<>filled then raise exception 'all snapped competencies must have a score before submission' using errcode='23514'; end if;
  update public.assessments set status='submitted',submitted_at=now(),updated_at=now() where id=p_assessment_id;
  return true;
end $$;

create or replace function public.cca_complete_assessment(p_assessment_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; cycle_status text;
begin
  select a.organization_id,a.status,c.status into o,s,cycle_status from public.assessments a join public.cycles c on c.organization_id=a.organization_id and c.id=a.cycle_id where a.id=p_assessment_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'only Admin/RH can complete this assessment' using errcode='42501'; end if;
  if s <> 'submitted' or cycle_status <> 'active' then raise exception 'only submitted assessments in an active cycle can be completed' using errcode='23514'; end if;
  update public.assessments set status='completed',completed_at=now(),completed_by_user_id=auth.uid(),updated_at=now() where id=p_assessment_id;
  return true;
end $$;

drop function if exists public.cca_read_assessment_aggregate(uuid);
create or replace function public.cca_read_assessment_aggregate(p_organization_id uuid,p_cycle_id uuid)
returns table(cycle_id uuid,competency_id uuid,competency_name text,position_id uuid,position_name text,assessment_count bigint,average_score numeric)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cycle_org uuid;
begin
  if auth.uid() is null or p_organization_id is null or p_cycle_id is null then
    raise exception 'aggregate authorization is required' using errcode='42501';
  end if;
  if not public.has_org_role(p_organization_id,array['admin_youb','rh','diretoria']) then
    raise exception 'aggregate is not authorized for this tenant' using errcode='42501';
  end if;
  select c.organization_id into cycle_org from public.cycles c where c.id=p_cycle_id;
  if cycle_org is null or cycle_org <> p_organization_id then
    raise exception 'cycle is outside the requested tenant' using errcode='42501';
  end if;
  return query
    select a.cycle_id,s.competency_id,c.name,a.position_id,p.name,count(distinct a.id),round(avg(s.score)::numeric,2)
    from public.assessments a
    join public.assessment_competency_scores s on s.organization_id=a.organization_id and s.assessment_id=a.id
    join public.competencies c on c.organization_id=s.organization_id and c.id=s.competency_id
    join public.positions p on p.organization_id=a.organization_id and p.id=a.position_id
    where a.organization_id=p_organization_id and a.cycle_id=p_cycle_id and a.status='completed' and s.score is not null
    group by a.cycle_id,s.competency_id,c.name,a.position_id,p.name
    having count(distinct a.id) >= 3;
end $$;

revoke all on function public.cca_set_updated_at(),public.cca_capture_assessment_position(),public.cca_employee_has_role(uuid,uuid,text[]),public.cca_is_assessment_manager(uuid,uuid),public.cca_can_manage_assessment(uuid,uuid) from public;
revoke all on function public.cca_create_competency(uuid,text,text),public.cca_update_competency(uuid,text,text,boolean),public.cca_create_position_competency(uuid,uuid,smallint),public.cca_update_position_competency(uuid,smallint,boolean),public.cca_deactivate_position_competency(uuid),public.cca_create_cycle(uuid,text,text,date,date),public.cca_update_draft_cycle(uuid,text,date,date),public.cca_activate_cycle(uuid),public.cca_close_cycle(uuid),public.cca_create_assessment(uuid,uuid,uuid),public.cca_save_assessment_score(uuid,uuid,smallint,text),public.cca_submit_assessment(uuid),public.cca_complete_assessment(uuid),public.cca_read_assessment_aggregate(uuid,uuid) from public;
grant execute on function public.cca_create_competency(uuid,text,text),public.cca_update_competency(uuid,text,text,boolean),public.cca_create_position_competency(uuid,uuid,smallint),public.cca_update_position_competency(uuid,smallint,boolean),public.cca_deactivate_position_competency(uuid),public.cca_create_cycle(uuid,text,text,date,date),public.cca_update_draft_cycle(uuid,text,date,date),public.cca_activate_cycle(uuid),public.cca_close_cycle(uuid),public.cca_create_assessment(uuid,uuid,uuid),public.cca_save_assessment_score(uuid,uuid,smallint,text),public.cca_submit_assessment(uuid),public.cca_complete_assessment(uuid),public.cca_read_assessment_aggregate(uuid,uuid) to authenticated;
grant execute on function public.cca_is_assessment_manager(uuid,uuid),public.cca_can_manage_assessment(uuid,uuid) to authenticated;

comment on column public.assessments.scores is 'Legacy compatibility JSONB only. New Competency + Cycle + Assessment V1 scores are authoritative in assessment_competency_scores.';
comment on column public.assessments.position_id is 'Position snapshot captured when the assessment starts; changes to employee position do not rewrite this assessment.';
comment on column public.assessment_competency_scores.expected_level_snapshot is 'Expected level copied from the active position mapping at assessment start; historical meaning is immutable.';
