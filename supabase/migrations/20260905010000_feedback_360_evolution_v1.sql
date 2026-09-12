-- youB — Feedback 360 + Evolução entre Ciclos V1
-- Additive implementation on the frozen PR #14 head.
-- Do not reuse legacy feedbacks or PR #14 assessments for multi-rater responses.

create table if not exists public.feedback_360_rounds (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  cycle_id uuid not null,
  name text not null,
  description text,
  confidentiality_mode text not null default 'confidential' check (confidentiality_mode = 'confidential'),
  status text not null default 'draft' check (status in ('draft','active','closed')),
  created_by_user_id uuid references auth.users(id) on delete set null,
  activated_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feedback_360_rounds_organization_id_id_key unique (organization_id,id),
  constraint feedback_360_rounds_name_not_blank check (length(btrim(name)) > 0),
  constraint feedback_360_rounds_cycle_same_org_fkey foreign key (organization_id,cycle_id) references public.cycles(organization_id,id)
);

create table if not exists public.feedback_360_participants (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  round_id uuid not null,
  subject_employee_id uuid not null,
  evaluator_employee_id uuid not null,
  relationship_type text not null check (relationship_type in ('self','manager','peer','direct_report')),
  status text not null default 'pending' check (status in ('pending','in_progress','submitted')),
  invited_at timestamptz not null default now(),
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feedback_360_participants_organization_id_id_key unique (organization_id,id),
  constraint feedback_360_participants_unique_relation unique (organization_id,round_id,subject_employee_id,evaluator_employee_id,relationship_type),
  constraint feedback_360_participants_round_same_org_fkey foreign key (organization_id,round_id) references public.feedback_360_rounds(organization_id,id) on delete cascade,
  constraint feedback_360_participants_subject_same_org_fkey foreign key (organization_id,subject_employee_id) references public.employees(organization_id,id) on delete restrict,
  constraint feedback_360_participants_evaluator_same_org_fkey foreign key (organization_id,evaluator_employee_id) references public.employees(organization_id,id) on delete restrict,
  constraint feedback_360_participants_status_time_check check ((status in ('pending','in_progress') and submitted_at is null) or (status = 'submitted' and submitted_at is not null))
);

create table if not exists public.feedback_360_subject_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  round_id uuid not null,
  subject_employee_id uuid not null,
  competency_id uuid not null,
  position_competency_id uuid not null,
  position_id_snapshot uuid not null,
  expected_level_snapshot smallint not null check (expected_level_snapshot between 1 and 5),
  created_at timestamptz not null default now(),
  constraint feedback_360_subject_competencies_organization_id_id_key unique (organization_id,id),
  constraint feedback_360_subject_competencies_unique unique (organization_id,round_id,subject_employee_id,competency_id),
  constraint feedback_360_subject_competencies_round_same_org_fkey foreign key (organization_id,round_id) references public.feedback_360_rounds(organization_id,id) on delete cascade,
  constraint feedback_360_subject_competencies_subject_same_org_fkey foreign key (organization_id,subject_employee_id) references public.employees(organization_id,id) on delete restrict,
  constraint feedback_360_subject_competencies_competency_same_org_fkey foreign key (organization_id,competency_id) references public.competencies(organization_id,id) on delete restrict,
  constraint feedback_360_subject_competencies_mapping_same_org_fkey foreign key (organization_id,position_competency_id) references public.position_competencies(organization_id,id) on delete restrict,
  constraint feedback_360_subject_competencies_position_same_org_fkey foreign key (organization_id,position_id_snapshot) references public.positions(organization_id,id) on delete restrict
);

create table if not exists public.feedback_360_scores (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  participant_id uuid not null,
  subject_competency_id uuid not null,
  score smallint check (score is null or score between 1 and 5),
  comment text check (comment is null or char_length(comment) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feedback_360_scores_organization_id_id_key unique (organization_id,id),
  constraint feedback_360_scores_unique unique (organization_id,participant_id,subject_competency_id),
  constraint feedback_360_scores_participant_same_org_fkey foreign key (organization_id,participant_id) references public.feedback_360_participants(organization_id,id) on delete cascade,
  constraint feedback_360_scores_competency_same_org_fkey foreign key (organization_id,subject_competency_id) references public.feedback_360_subject_competencies(organization_id,id) on delete cascade
);

create index if not exists idx_feedback_360_rounds_org_cycle on public.feedback_360_rounds(organization_id,cycle_id,status);
create index if not exists idx_feedback_360_participants_org_round on public.feedback_360_participants(organization_id,round_id,status);
create index if not exists idx_feedback_360_participants_org_evaluator on public.feedback_360_participants(organization_id,evaluator_employee_id,status);
create index if not exists idx_feedback_360_participants_org_subject on public.feedback_360_participants(organization_id,subject_employee_id,status);
create index if not exists idx_feedback_360_subject_comp_org_round on public.feedback_360_subject_competencies(organization_id,round_id,subject_employee_id);
create index if not exists idx_feedback_360_scores_org_participant on public.feedback_360_scores(organization_id,participant_id);

create or replace function public.fb360_set_updated_at()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists fb360_rounds_updated_at on public.feedback_360_rounds;
create trigger fb360_rounds_updated_at before update on public.feedback_360_rounds for each row execute function public.fb360_set_updated_at();
drop trigger if exists fb360_participants_updated_at on public.feedback_360_participants;
create trigger fb360_participants_updated_at before update on public.feedback_360_participants for each row execute function public.fb360_set_updated_at();
drop trigger if exists fb360_scores_updated_at on public.feedback_360_scores;
create trigger fb360_scores_updated_at before update on public.feedback_360_scores for each row execute function public.fb360_set_updated_at();

alter table public.feedback_360_rounds enable row level security;
alter table public.feedback_360_participants enable row level security;
alter table public.feedback_360_subject_competencies enable row level security;
alter table public.feedback_360_scores enable row level security;

create policy fb360_rounds_select_members on public.feedback_360_rounds for select to authenticated using (public.is_org_member(organization_id));
create policy fb360_participants_select_scoped on public.feedback_360_participants for select to authenticated using (
  public.classic_is_org_admin(organization_id)
  or public.classic_has_single_own_employee(organization_id,evaluator_employee_id)
);
create policy fb360_subject_competencies_select_scoped on public.feedback_360_subject_competencies for select to authenticated using (
  public.classic_is_org_admin(organization_id)
  or exists (
    select 1 from public.feedback_360_participants p
    where p.organization_id=feedback_360_subject_competencies.organization_id
      and p.round_id=feedback_360_subject_competencies.round_id
      and p.subject_employee_id=feedback_360_subject_competencies.subject_employee_id
      and public.classic_has_single_own_employee(p.organization_id,p.evaluator_employee_id)
  )
);
create policy fb360_scores_select_scoped on public.feedback_360_scores for select to authenticated using (
  public.classic_is_org_admin(organization_id)
  or exists (
    select 1 from public.feedback_360_participants p
    where p.organization_id=feedback_360_scores.organization_id
      and p.id=feedback_360_scores.participant_id
      and public.classic_has_single_own_employee(p.organization_id,p.evaluator_employee_id)
  )
);

revoke insert,update,delete on public.feedback_360_rounds,public.feedback_360_participants,public.feedback_360_subject_competencies,public.feedback_360_scores from authenticated;
grant select on public.feedback_360_rounds,public.feedback_360_participants,public.feedback_360_subject_competencies,public.feedback_360_scores to authenticated;

create or replace function public.fb360_create_round(p_organization_id uuid,p_cycle_id uuid,p_name text,p_description text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare i uuid;
begin
  if auth.uid() is null or not public.classic_is_org_admin(p_organization_id) then raise exception 'only Admin/RH can create a 360 round' using errcode='42501'; end if;
  if not exists(select 1 from public.cycles c where c.organization_id=p_organization_id and c.id=p_cycle_id and c.status in ('draft','active')) then raise exception 'cycle is outside the authorized tenant or unavailable' using errcode='42501'; end if;
  insert into public.feedback_360_rounds(organization_id,cycle_id,name,description,created_by_user_id)
    values(p_organization_id,p_cycle_id,btrim(p_name),nullif(btrim(p_description),''),auth.uid()) returning id into i;
  return i;
end $$;

create or replace function public.fb360_update_draft_round(p_round_id uuid,p_name text,p_description text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text;
begin
  select organization_id,status into o,s from public.feedback_360_rounds where id=p_round_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'round is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' then raise exception 'only draft rounds are editable' using errcode='23514'; end if;
  update public.feedback_360_rounds set name=btrim(p_name),description=nullif(btrim(p_description),'') where id=p_round_id;
  return true;
end $$;

create or replace function public.fb360_add_participant(p_round_id uuid,p_subject_employee_id uuid,p_evaluator_employee_id uuid,p_relationship_type text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; i uuid; subject_manager uuid;
begin
  select organization_id,status into o,s from public.feedback_360_rounds where id=p_round_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'round is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' then raise exception 'participants can only be configured in draft' using errcode='23514'; end if;
  if p_relationship_type not in ('self','manager','peer','direct_report') then raise exception 'invalid relationship type' using errcode='23514'; end if;
  select manager_employee_id into subject_manager from public.employees where organization_id=o and id=p_subject_employee_id and status='active';
  if not found or not exists(select 1 from public.employees where organization_id=o and id=p_evaluator_employee_id and status='active') then raise exception 'subject and evaluator must be active employees in the same tenant' using errcode='42501'; end if;
  if p_relationship_type='self' and p_subject_employee_id <> p_evaluator_employee_id then raise exception 'self relationship requires the same employee' using errcode='42501'; end if;
  if p_relationship_type='manager' and (subject_manager is null or subject_manager <> p_evaluator_employee_id) then raise exception 'manager relationship requires the direct manager' using errcode='42501'; end if;
  if p_relationship_type='direct_report' and not exists(select 1 from public.employees e where e.organization_id=o and e.id=p_evaluator_employee_id and e.manager_employee_id=p_subject_employee_id and e.status='active') then raise exception 'direct_report relationship requires a direct report' using errcode='42501'; end if;
  insert into public.feedback_360_participants(organization_id,round_id,subject_employee_id,evaluator_employee_id,relationship_type)
    values(o,p_round_id,p_subject_employee_id,p_evaluator_employee_id,p_relationship_type) returning id into i;
  return i;
exception when unique_violation then raise exception 'duplicate 360 participant relationship' using errcode='23505';
end $$;

create or replace function public.fb360_remove_participant(p_participant_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text;
begin
  select organization_id,r.status into o,s from public.feedback_360_participants p join public.feedback_360_rounds r on r.organization_id=p.organization_id and r.id=p.round_id where p.id=p_participant_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'participant is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' then raise exception 'participants cannot be removed after activation' using errcode='23514'; end if;
  delete from public.feedback_360_participants where id=p_participant_id;
  return true;
end $$;

create or replace function public.fb360_activate_round(p_round_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; cycle_status text; subject_count bigint; participant_count bigint; invalid_subjects bigint;
begin
  select r.organization_id,r.status,c.status into o,s,cycle_status from public.feedback_360_rounds r join public.cycles c on c.organization_id=r.organization_id and c.id=r.cycle_id where r.id=p_round_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'round is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'draft' or cycle_status <> 'active' then raise exception 'round requires draft status and an active cycle' using errcode='23514'; end if;
  select count(distinct subject_employee_id),count(*) into subject_count,participant_count from public.feedback_360_participants where organization_id=o and round_id=p_round_id;
  if subject_count=0 or participant_count=0 then raise exception 'round requires subjects and participants' using errcode='23514'; end if;
  select count(*) into invalid_subjects
  from (select distinct p.subject_employee_id from public.feedback_360_participants p where p.organization_id=o and p.round_id=p_round_id) subjects
  where not exists(select 1 from public.employees e where e.organization_id=o and e.id=subjects.subject_employee_id and e.status='active' and e.position_id is not null)
     or not exists(select 1 from public.position_competencies pc join public.employees e on e.organization_id=pc.organization_id and e.position_id=pc.position_id where pc.organization_id=o and e.id=subjects.subject_employee_id and e.status='active' and pc.active);
  if invalid_subjects > 0 then raise exception 'round configuration pending: every subject needs a position and active mappings' using errcode='23514'; end if;
  insert into public.feedback_360_subject_competencies(organization_id,round_id,subject_employee_id,competency_id,position_competency_id,position_id_snapshot,expected_level_snapshot)
    select o,p_round_id,e.id,pc.competency_id,pc.id,e.position_id,pc.expected_level
    from public.employees e join public.position_competencies pc on pc.organization_id=e.organization_id and pc.position_id=e.position_id and pc.active
    where e.organization_id=o and e.status='active' and e.id in (select distinct subject_employee_id from public.feedback_360_participants where organization_id=o and round_id=p_round_id)
    on conflict (organization_id,round_id,subject_employee_id,competency_id) do nothing;
  insert into public.feedback_360_scores(organization_id,participant_id,subject_competency_id)
    select o,p.id,sc.id from public.feedback_360_participants p join public.feedback_360_subject_competencies sc on sc.organization_id=p.organization_id and sc.round_id=p.round_id and sc.subject_employee_id=p.subject_employee_id
    where p.organization_id=o and p.round_id=p_round_id on conflict do nothing;
  update public.feedback_360_rounds set status='active',activated_at=now(),updated_at=now() where id=p_round_id;
  return true;
end $$;

create or replace function public.fb360_save_score(p_participant_id uuid,p_subject_competency_id uuid,p_score smallint,p_comment text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; round_status text; evaluator uuid;
begin
  if auth.uid() is null or p_score is null or p_score not between 1 and 5 then raise exception 'score must be between 1 and 5' using errcode='23514'; end if;
  select p.organization_id,p.status,r.status,p.evaluator_employee_id into o,s,round_status,evaluator from public.feedback_360_participants p join public.feedback_360_rounds r on r.organization_id=p.organization_id and r.id=p.round_id where p.id=p_participant_id for update;
  if o is null or not public.classic_has_single_own_employee(o,evaluator) then raise exception 'participant is outside the evaluator population' using errcode='42501'; end if;
  if s not in ('pending','in_progress') or round_status <> 'active' then raise exception 'participation is not editable' using errcode='23514'; end if;
  update public.feedback_360_scores set score=p_score,comment=nullif(btrim(p_comment),''),updated_at=now() where organization_id=o and participant_id=p_participant_id and subject_competency_id=p_subject_competency_id;
  if not found then raise exception 'competency is not part of the participant snapshot' using errcode='23503'; end if;
  update public.feedback_360_participants set status='in_progress',updated_at=now() where id=p_participant_id;
  return true;
end $$;

create or replace function public.fb360_submit_participation(p_participant_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text; round_status text; evaluator uuid; total bigint; filled bigint;
begin
  select p.organization_id,p.status,r.status,p.evaluator_employee_id into o,s,round_status,evaluator from public.feedback_360_participants p join public.feedback_360_rounds r on r.organization_id=p.organization_id and r.id=p.round_id where p.id=p_participant_id for update;
  if o is null or not public.classic_has_single_own_employee(o,evaluator) then raise exception 'participant is outside the evaluator population' using errcode='42501'; end if;
  if s not in ('pending','in_progress') or round_status <> 'active' then raise exception 'participation cannot be submitted' using errcode='23514'; end if;
  select count(*),count(*) filter(where score is not null) into total,filled from public.feedback_360_scores where organization_id=o and participant_id=p_participant_id;
  if total=0 or total <> filled then raise exception 'all snapped competencies must have a score' using errcode='23514'; end if;
  update public.feedback_360_participants set status='submitted',submitted_at=now(),updated_at=now() where id=p_participant_id;
  return true;
end $$;

create or replace function public.fb360_close_round(p_round_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare o uuid; s text;
begin
  select organization_id,status into o,s from public.feedback_360_rounds where id=p_round_id for update;
  if o is null or not public.classic_is_org_admin(o) then raise exception 'round is outside the authorized tenant' using errcode='42501'; end if;
  if s <> 'active' then raise exception 'only active rounds can be closed' using errcode='23514'; end if;
  update public.feedback_360_rounds set status='closed',closed_at=now(),updated_at=now() where id=p_round_id;
  return true;
end $$;

create or replace function public.fb360_read_subject_result(p_organization_id uuid,p_round_id uuid,p_subject_employee_id uuid)
returns table(round_id uuid,subject_employee_id uuid,competency_id uuid,competency_name text,position_id uuid,relationship_type text,response_count bigint,average_score numeric,expected_level_snapshot smallint,feedback_comment text)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cycle_status text; round_status text;
begin
  if auth.uid() is null or p_organization_id is null or p_round_id is null then raise exception 'result authorization is required' using errcode='42501'; end if;
  if not exists(select 1 from public.employees e where e.organization_id=p_organization_id and e.id=p_subject_employee_id and e.status='active') then raise exception 'subject is outside the requested tenant' using errcode='42501'; end if;
  if not (public.classic_is_org_admin(p_organization_id) or public.classic_has_single_own_employee(p_organization_id,p_subject_employee_id) or public.classic_is_direct_report(p_organization_id,p_subject_employee_id)) then raise exception 'subject result is outside the authorized population' using errcode='42501'; end if;
  select r.status,c.status into round_status,cycle_status from public.feedback_360_rounds r join public.cycles c on c.organization_id=r.organization_id and c.id=r.cycle_id where r.organization_id=p_organization_id and r.id=p_round_id;
  if round_status is null or round_status <> 'closed' then raise exception 'results require a closed round' using errcode='23514'; end if;
  return query
  with grouped as (
    select sc.round_id,sc.subject_employee_id,sc.competency_id,c.name,sc.position_id_snapshot,p.relationship_type,count(distinct p.id) as n,round(avg(s.score)::numeric,2) as avg_score,max(sc.expected_level_snapshot) as expected,
      case when p.relationship_type in ('self','manager') then max(s.comment) else null end as safe_comment
    from public.feedback_360_subject_competencies sc
    join public.feedback_360_scores s on s.organization_id=sc.organization_id and s.subject_competency_id=sc.id and s.score is not null
    join public.feedback_360_participants p on p.organization_id=s.organization_id and p.id=s.participant_id and p.status='submitted'
    join public.competencies c on c.organization_id=sc.organization_id and c.id=sc.competency_id
    where sc.organization_id=p_organization_id and sc.round_id=p_round_id and sc.subject_employee_id=p_subject_employee_id
    group by sc.round_id,sc.subject_employee_id,sc.competency_id,c.name,sc.position_id_snapshot,p.relationship_type
  )
  select g.round_id,g.subject_employee_id,g.competency_id,g.name,g.position_id_snapshot,g.relationship_type,g.n,g.avg_score,g.expected,g.safe_comment
  from grouped g where g.relationship_type in ('self','manager') or g.n >= 3;
end $$;

create or replace function public.fb360_read_organization_aggregate(p_organization_id uuid,p_round_id uuid)
returns table(round_id uuid,competency_id uuid,competency_name text,source_role text,position_id uuid,subject_count bigint,response_count bigint,average_score numeric)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare round_status text;
begin
  if auth.uid() is null or not public.has_org_role(p_organization_id,array['admin_youb','rh','diretoria']) then raise exception 'aggregate is not authorized for this tenant' using errcode='42501'; end if;
  select status into round_status from public.feedback_360_rounds where organization_id=p_organization_id and id=p_round_id;
  if round_status is null or round_status <> 'closed' then raise exception 'round is outside the requested tenant or not closed' using errcode='42501'; end if;
  return query
    select sc.round_id,sc.competency_id,c.name,p.relationship_type,sc.position_id_snapshot,count(distinct sc.subject_employee_id),count(distinct p.id),round(avg(s.score)::numeric,2)
    from public.feedback_360_subject_competencies sc
    join public.feedback_360_scores s on s.organization_id=sc.organization_id and s.subject_competency_id=sc.id and s.score is not null
    join public.feedback_360_participants p on p.organization_id=s.organization_id and p.id=s.participant_id and p.status='submitted'
    join public.competencies c on c.organization_id=sc.organization_id and c.id=sc.competency_id
    where sc.organization_id=p_organization_id and sc.round_id=p_round_id
    group by sc.round_id,sc.competency_id,c.name,p.relationship_type,sc.position_id_snapshot
    having count(distinct sc.subject_employee_id) >= 3 and count(distinct p.id) >= 3;
end $$;

create or replace function public.fb360_read_evolution(p_organization_id uuid,p_subject_employee_id uuid,p_origin_filter text default null)
returns table(source_type text,cycle_id uuid,round_id uuid,competency_id uuid,competency_name text,position_id uuid,expected_level_snapshot smallint,score numeric,previous_score numeric,delta numeric,distance_to_expected numeric,completed_at timestamptz)
language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null or not exists(select 1 from public.employees e where e.organization_id=p_organization_id and e.id=p_subject_employee_id and e.status='active') then raise exception 'evolution subject is outside the requested tenant' using errcode='42501'; end if;
  if not (public.classic_is_org_admin(p_organization_id) or public.classic_has_single_own_employee(p_organization_id,p_subject_employee_id) or public.classic_is_direct_report(p_organization_id,p_subject_employee_id)) then raise exception 'evolution is outside the authorized population' using errcode='42501'; end if;
  if p_origin_filter is not null and p_origin_filter not in ('assessment_v1','self','manager','peer','direct_report') then raise exception 'invalid evolution origin' using errcode='23514'; end if;
  return query
  with points as (
    select 'assessment_v1'::text source_type,a.cycle_id::uuid,null::uuid round_id,s.competency_id,c.name as competency_name,a.position_id,s.expected_level_snapshot,s.score::numeric score,a.completed_at
    from public.assessments a join public.assessment_competency_scores s on s.organization_id=a.organization_id and s.assessment_id=a.id and s.score is not null join public.competencies c on c.organization_id=s.organization_id and c.id=s.competency_id
    where a.organization_id=p_organization_id and a.subject_employee_id=p_subject_employee_id and a.status='completed'
    union all
    select p.relationship_type::text,r.cycle_id::uuid,r.id::uuid round_id,sc.competency_id,c.name as competency_name,sc.position_id_snapshot,sc.expected_level_snapshot,avg(s.score)::numeric score,max(p.submitted_at) completed_at
    from public.feedback_360_rounds r join public.feedback_360_participants p on p.organization_id=r.organization_id and p.round_id=r.id and p.status='submitted' join public.feedback_360_subject_competencies sc on sc.organization_id=p.organization_id and sc.round_id=p.round_id and sc.subject_employee_id=p.subject_employee_id join public.feedback_360_scores s on s.organization_id=p.organization_id and s.participant_id=p.id and s.subject_competency_id=sc.id and s.score is not null join public.competencies c on c.organization_id=sc.organization_id and c.id=sc.competency_id
    where r.organization_id=p_organization_id and r.status='closed' and p.subject_employee_id=p_subject_employee_id
    group by p.relationship_type,r.cycle_id,r.id,sc.competency_id,c.name,sc.position_id_snapshot,sc.expected_level_snapshot
    having p.relationship_type in ('self','manager') or count(distinct p.id) >= 3
  ), ordered as (
    select points.*,
      lag(points.score) over (
        partition by points.source_type,points.competency_id
        order by points.completed_at,coalesce(points.round_id,points.cycle_id)
      ) as previous_score_candidate,
      lag(points.position_id) over (
        partition by points.source_type,points.competency_id
        order by points.completed_at,coalesce(points.round_id,points.cycle_id)
      ) as previous_position_id,
      lag(points.expected_level_snapshot) over (
        partition by points.source_type,points.competency_id
        order by points.completed_at,coalesce(points.round_id,points.cycle_id)
      ) as previous_expected_level
    from points
    where p_origin_filter is null or points.source_type=p_origin_filter
  ), comparable as (
    select o.*,
      case when o.previous_score_candidate is not null
        and o.previous_position_id is not distinct from o.position_id
        and o.previous_expected_level is not distinct from o.expected_level_snapshot
        then o.previous_score_candidate end as previous_score
    from ordered o
  )
  select c.source_type,c.cycle_id,c.round_id,c.competency_id,c.competency_name,c.position_id,c.expected_level_snapshot,c.score,c.previous_score,
    case when c.previous_score is not null then c.score-c.previous_score end as delta,
    c.score-c.expected_level_snapshot as distance_to_expected,c.completed_at
  from comparable c order by c.competency_name,c.source_type,c.completed_at;
end $$;

revoke all on function public.fb360_set_updated_at() from public;
revoke all on function public.fb360_create_round(uuid,uuid,text,text),public.fb360_update_draft_round(uuid,text,text),public.fb360_add_participant(uuid,uuid,uuid,text),public.fb360_remove_participant(uuid),public.fb360_activate_round(uuid),public.fb360_save_score(uuid,uuid,smallint,text),public.fb360_submit_participation(uuid),public.fb360_close_round(uuid),public.fb360_read_subject_result(uuid,uuid,uuid),public.fb360_read_organization_aggregate(uuid,uuid),public.fb360_read_evolution(uuid,uuid,text) from public;
grant execute on function public.fb360_create_round(uuid,uuid,text,text),public.fb360_update_draft_round(uuid,text,text),public.fb360_add_participant(uuid,uuid,uuid,text),public.fb360_remove_participant(uuid),public.fb360_activate_round(uuid),public.fb360_save_score(uuid,uuid,smallint,text),public.fb360_submit_participation(uuid),public.fb360_close_round(uuid),public.fb360_read_subject_result(uuid,uuid,uuid),public.fb360_read_organization_aggregate(uuid,uuid),public.fb360_read_evolution(uuid,uuid,text) to authenticated;

comment on table public.feedback_360_rounds is 'Confidential 360 rounds. Raw operational access is restricted to Admin/RH; V1 aggregate outputs never expose individual identity.';
comment on table public.feedback_360_subject_competencies is 'Historical competency/position/expected-level snapshot created when a 360 round is activated.';
comment on table public.feedback_360_scores is '360 scores are immutable after participant submission; peer/direct_report comments are never returned to subject aggregates.';
