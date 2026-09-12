-- youB — Evidence + Recommendation Operational V1
-- Manual/controlled provenance foundation. No causal inference, scoring, LLM or automation.
insert into public.organizational_memory_entity_types(entity_type,description) values ('evidence_assessment','A structured evaluation of evidence sufficiency and limitations.') on conflict (entity_type) do nothing;

create table if not exists public.intelligence_evidence_assessments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
 reading_id uuid not null, hypothesis_id uuid, status text not null default 'under_investigation' check(status in('draft','under_investigation','assessed','archived')),
 evidence_state text not null check(evidence_state in('insufficient','weak','moderate','strong','conflicting')),
 supporting_evidence_count integer not null default 0 check(supporting_evidence_count>=0), contradicting_evidence_count integer not null default 0 check(contradicting_evidence_count>=0),
 unknowns jsonb not null default '[]'::jsonb check(jsonb_typeof(unknowns)='array'), limitations jsonb not null default '[]'::jsonb check(jsonb_typeof(limitations)='array'), assessment_summary text not null check(btrim(assessment_summary)<>''),
 assessed_by_user_id uuid references auth.users(id) on delete set null, assessed_at timestamptz, context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint intelligence_evidence_assessments_organization_id_id_key unique(organization_id,id),
 constraint evidence_assessments_reading_same_org_fkey foreign key(organization_id,reading_id) references public.intelligence_organizational_readings(organization_id,id),
 constraint evidence_assessments_hypothesis_same_org_fkey foreign key(organization_id,hypothesis_id) references public.intelligence_organizational_reading_hypotheses(organization_id,id),
 constraint evidence_assessments_assessed_pair_check check((assessed_by_user_id is null)=(assessed_at is null)),
 constraint evidence_assessments_assessed_status_check check(status<>'assessed' or(assessed_by_user_id is not null and assessed_at is not null))
);
create table if not exists public.intelligence_evidence_assessment_evidence (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, assessment_id uuid not null, evidence_id uuid not null,
 evidence_relation text not null check(evidence_relation in('supports','contradicts')), provenance_note text, context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(),
 constraint evidence_assessment_evidence_unique unique(organization_id,assessment_id,evidence_id,evidence_relation),
 constraint evidence_assessment_evidence_assessment_same_org_fkey foreign key(organization_id,assessment_id) references public.intelligence_evidence_assessments(organization_id,id) on delete cascade,
 constraint evidence_assessment_evidence_evidence_same_org_fkey foreign key(organization_id,evidence_id) references public.intelligence_evidence(organization_id,id)
);
create table if not exists public.intelligence_evidence_assessment_revisions (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, assessment_id uuid not null, revision_number integer not null check(revision_number>0), changed_by_user_id uuid not null references auth.users(id) on delete restrict, change_reason text not null check(btrim(change_reason)<>''), previous_snapshot jsonb not null check(jsonb_typeof(previous_snapshot)='object'), new_snapshot jsonb not null check(jsonb_typeof(new_snapshot)='object'), created_at timestamptz not null default now(),
 constraint evidence_assessment_revisions_unique unique(organization_id,assessment_id,revision_number), constraint evidence_assessment_revisions_assessment_same_org_fkey foreign key(organization_id,assessment_id) references public.intelligence_evidence_assessments(organization_id,id) on delete cascade
);

create table if not exists public.intelligence_recommendation_readings (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, recommendation_id uuid not null, reading_id uuid not null, relationship_type text not null default 'motivated_by' check(relationship_type='motivated_by'), context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(), constraint recommendation_readings_unique unique(organization_id,recommendation_id,reading_id), constraint recommendation_readings_recommendation_same_org_fkey foreign key(organization_id,recommendation_id) references public.intelligence_recommendations(organization_id,id) on delete cascade, constraint recommendation_readings_reading_same_org_fkey foreign key(organization_id,reading_id) references public.intelligence_organizational_readings(organization_id,id) on delete restrict
);
create table if not exists public.intelligence_recommendation_assessments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, recommendation_id uuid not null, assessment_id uuid not null, relationship_type text not null default 'based_on' check(relationship_type='based_on'), context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(), constraint recommendation_assessments_unique unique(organization_id,recommendation_id,assessment_id), constraint recommendation_assessments_recommendation_same_org_fkey foreign key(organization_id,recommendation_id) references public.intelligence_recommendations(organization_id,id) on delete cascade, constraint recommendation_assessments_assessment_same_org_fkey foreign key(organization_id,assessment_id) references public.intelligence_evidence_assessments(organization_id,id) on delete restrict
);
create table if not exists public.intelligence_recommendation_hypotheses (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, recommendation_id uuid not null, hypothesis_id uuid not null, relationship_type text not null default 'considers' check(relationship_type='considers'), context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(), constraint recommendation_hypotheses_unique unique(organization_id,recommendation_id,hypothesis_id), constraint recommendation_hypotheses_recommendation_same_org_fkey foreign key(organization_id,recommendation_id) references public.intelligence_recommendations(organization_id,id) on delete cascade, constraint recommendation_hypotheses_hypothesis_same_org_fkey foreign key(organization_id,hypothesis_id) references public.intelligence_organizational_reading_hypotheses(organization_id,id) on delete restrict
);
create table if not exists public.intelligence_recommendation_evidence (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, recommendation_id uuid not null, evidence_id uuid not null, evidence_relation text not null check(evidence_relation in('supports','contradicts')), context jsonb not null default '{}'::jsonb check(jsonb_typeof(context)='object'), created_at timestamptz not null default now(), constraint recommendation_evidence_operational_unique unique(organization_id,recommendation_id,evidence_id,evidence_relation), constraint recommendation_evidence_operational_recommendation_same_org_fkey foreign key(organization_id,recommendation_id) references public.intelligence_recommendations(organization_id,id) on delete cascade, constraint recommendation_evidence_operational_evidence_same_org_fkey foreign key(organization_id,evidence_id) references public.intelligence_evidence(organization_id,id) on delete restrict
);
create table if not exists public.intelligence_recommendation_revisions (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, recommendation_id uuid not null, revision_number integer not null check(revision_number>0), changed_by_user_id uuid not null references auth.users(id) on delete restrict, change_reason text not null check(btrim(change_reason)<>''), previous_snapshot jsonb not null check(jsonb_typeof(previous_snapshot)='object'), new_snapshot jsonb not null check(jsonb_typeof(new_snapshot)='object'), created_at timestamptz not null default now(), constraint recommendation_revisions_unique unique(organization_id,recommendation_id,revision_number), constraint recommendation_revisions_recommendation_same_org_fkey foreign key(organization_id,recommendation_id) references public.intelligence_recommendations(organization_id,id) on delete cascade
);

alter table public.intelligence_recommendation_evidence add column if not exists evidence_relation text not null default 'supports';
alter table public.intelligence_recommendation_evidence add column if not exists context jsonb not null default '{}'::jsonb;
alter table public.intelligence_recommendation_evidence drop constraint if exists recommendation_evidence_operational_relation_check;
alter table public.intelligence_recommendation_evidence add constraint recommendation_evidence_operational_relation_check check(evidence_relation in('supports','contradicts'));
alter table public.intelligence_recommendation_evidence add constraint recommendation_evidence_operational_context_check check(jsonb_typeof(context)='object');

alter table public.intelligence_recommendations drop constraint if exists intelligence_recommendations_evidence_sufficiency_check;
alter table public.intelligence_recommendations add constraint intelligence_recommendations_evidence_sufficiency_check check(status not in('proposed','accepted') or evidence_state is distinct from 'insufficient');
create index if not exists idx_evidence_assessments_org_reading on public.intelligence_evidence_assessments(organization_id,reading_id,created_at desc);
create index if not exists idx_assessment_evidence_org_assessment on public.intelligence_evidence_assessment_evidence(organization_id,assessment_id);
create index if not exists idx_rec_readings_org_recommendation on public.intelligence_recommendation_readings(organization_id,recommendation_id);
create index if not exists idx_rec_assessments_org_recommendation on public.intelligence_recommendation_assessments(organization_id,recommendation_id);
create index if not exists idx_rec_revisions_org_recommendation on public.intelligence_recommendation_revisions(organization_id,recommendation_id,revision_number desc);

alter table public.intelligence_evidence_assessments enable row level security; alter table public.intelligence_evidence_assessment_evidence enable row level security; alter table public.intelligence_evidence_assessment_revisions enable row level security;
alter table public.intelligence_recommendation_readings enable row level security; alter table public.intelligence_recommendation_assessments enable row level security; alter table public.intelligence_recommendation_hypotheses enable row level security; alter table public.intelligence_recommendation_evidence enable row level security; alter table public.intelligence_recommendation_revisions enable row level security;
create policy evidence_assessments_select_role on public.intelligence_evidence_assessments for select to authenticated using(public.intelligence_is_admin(organization_id) or exists(select 1 from public.intelligence_organizational_readings r where r.organization_id=intelligence_evidence_assessments.organization_id and r.id=intelligence_evidence_assessments.reading_id and public.has_org_role(r.organization_id,array['diretoria']) and r.scope_type in('team','area','unit','process','organization')));
create policy evidence_assessments_insert_admin on public.intelligence_evidence_assessments for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy assessment_evidence_select_role on public.intelligence_evidence_assessment_evidence for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy assessment_evidence_insert_admin on public.intelligence_evidence_assessment_evidence for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy assessment_evidence_delete_admin on public.intelligence_evidence_assessment_evidence for delete to authenticated using(public.intelligence_is_admin(organization_id));
create policy assessment_revisions_select_role on public.intelligence_evidence_assessment_revisions for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy operational_rec_links_select_role on public.intelligence_recommendation_readings for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy operational_rec_links_assessment_select_role on public.intelligence_recommendation_assessments for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy operational_rec_links_hypothesis_select_role on public.intelligence_recommendation_hypotheses for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy operational_rec_links_evidence_select_role on public.intelligence_recommendation_evidence for select to authenticated using(public.intelligence_is_decision_maker(organization_id));
create policy operational_rec_links_readings_insert_admin on public.intelligence_recommendation_readings for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_assessments_insert_admin on public.intelligence_recommendation_assessments for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_hypotheses_insert_admin on public.intelligence_recommendation_hypotheses for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_evidence_insert_admin on public.intelligence_recommendation_evidence for insert to authenticated with check(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_readings_delete_admin on public.intelligence_recommendation_readings for delete to authenticated using(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_assessments_delete_admin on public.intelligence_recommendation_assessments for delete to authenticated using(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_hypotheses_delete_admin on public.intelligence_recommendation_hypotheses for delete to authenticated using(public.intelligence_is_admin(organization_id));
create policy operational_rec_links_evidence_delete_admin on public.intelligence_recommendation_evidence for delete to authenticated using(public.intelligence_is_admin(organization_id));
create policy recommendation_revisions_select_role on public.intelligence_recommendation_revisions for select to authenticated using(public.intelligence_is_decision_maker(organization_id));

grant select,insert on public.intelligence_evidence_assessments to authenticated;
grant select,insert,delete on public.intelligence_evidence_assessment_evidence to authenticated;
grant select on public.intelligence_evidence_assessment_revisions to authenticated;
grant select,insert,delete on public.intelligence_recommendation_readings,public.intelligence_recommendation_assessments,public.intelligence_recommendation_hypotheses,public.intelligence_recommendation_evidence to authenticated;
revoke update,delete on public.intelligence_evidence_assessments from authenticated; revoke insert,update,delete on public.intelligence_evidence_assessment_revisions from authenticated;
revoke update,delete on public.intelligence_recommendations from authenticated; revoke delete on public.intelligence_recommendations from authenticated; drop policy if exists intelligence_recommendations_update_role on public.intelligence_recommendations; drop policy if exists intelligence_recommendations_delete_role on public.intelligence_recommendations;
revoke insert,update,delete on public.intelligence_recommendation_revisions from authenticated; grant select on public.intelligence_evidence_assessment_revisions,public.intelligence_recommendation_revisions to authenticated;

insert into public.organizational_event_types(event_type,description,implemented) values
 ('evidence_assessment_created','An Evidence Assessment was created.',true),('evidence_assessment_updated','An Evidence Assessment was revised through a controlled path.',true),('recommendation_prepared','A Recommendation was prepared from an explicit evidence assessment.',true),('recommendation_evidence_updated','Recommendation evidence provenance was updated.',true) on conflict(event_type) do nothing;

create or replace function public._evidence_assessment_snapshot(a public.intelligence_evidence_assessments) returns jsonb language sql stable as $$ select jsonb_build_object('reading_id',a.reading_id,'hypothesis_id',a.hypothesis_id,'status',a.status,'evidence_state',a.evidence_state,'supporting_evidence_count',a.supporting_evidence_count,'contradicting_evidence_count',a.contradicting_evidence_count,'unknowns',a.unknowns,'limitations',a.limitations,'assessment_summary',a.assessment_summary,'assessed_by_user_id',a.assessed_by_user_id,'assessed_at',a.assessed_at,'context',a.context); $$;
create or replace function public._recommendation_snapshot(r public.intelligence_recommendations) returns jsonb language sql stable as $$ select jsonb_build_object('title',r.title,'rationale',r.rationale,'evidence_state',r.evidence_state,'unknowns',r.unknowns,'alternatives',r.alternatives,'do_not_recommend',r.do_not_recommend,'measurement_plan',r.measurement_plan,'approval_required',r.approval_required,'owner_employee_id',r.owner_employee_id,'scope_type',r.scope_type,'scope_ref',r.scope_ref,'status',r.status,'context',r.context); $$;
create or replace function public._append_evidence_assessment_revision(o uuid,a uuid,p jsonb,n jsonb,reason text) returns integer language plpgsql security definer set search_path=public,pg_temp as $$ declare v integer; begin if reason is null or btrim(reason)='' then raise exception 'assessment revision requires a reason'; end if; select coalesce(max(revision_number),0)+1 into v from public.intelligence_evidence_assessment_revisions where organization_id=o and assessment_id=a; insert into public.intelligence_evidence_assessment_revisions(organization_id,assessment_id,revision_number,changed_by_user_id,change_reason,previous_snapshot,new_snapshot) values(o,a,v,auth.uid(),reason,p,n); return v; end; $$;
create or replace function public._append_recommendation_revision(o uuid,r uuid,p jsonb,n jsonb,reason text) returns integer language plpgsql security definer set search_path=public,pg_temp as $$ declare v integer; begin if reason is null or btrim(reason)='' then raise exception 'recommendation revision requires a reason'; end if; select coalesce(max(revision_number),0)+1 into v from public.intelligence_recommendation_revisions where organization_id=o and recommendation_id=r; insert into public.intelligence_recommendation_revisions(organization_id,recommendation_id,revision_number,changed_by_user_id,change_reason,previous_snapshot,new_snapshot) values(o,r,v,auth.uid(),reason,p,n); return v; end; $$;

create or replace function public.revise_intelligence_evidence_assessment(
 p_assessment_id uuid,
 p_new_snapshot jsonb,
 p_reason text
) returns public.intelligence_evidence_assessments
language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_assessment public.intelligence_evidence_assessments%rowtype;
 v_next public.intelligence_evidence_assessments%rowtype;
 v_key text;
begin
 if auth.uid() is null or jsonb_typeof(p_new_snapshot)<>'object' then raise exception 'invalid assessment revision request'; end if;
 if p_new_snapshot ? 'assessed_by_user_id' or p_new_snapshot ? 'assessed_at' then raise exception 'assessment authorship and timestamp are server-controlled'; end if;
 foreach v_key in array array['status','evidence_state','supporting_evidence_count','contradicting_evidence_count','unknowns','limitations','assessment_summary','context'] loop
  if not(p_new_snapshot ? v_key) then raise exception 'assessment revision snapshot is missing %',v_key; end if;
 end loop;
 select ea.* into strict v_assessment from public.intelligence_evidence_assessments as ea where ea.id=p_assessment_id for update;
 if not public.is_org_member(v_assessment.organization_id) or not public.intelligence_is_admin(v_assessment.organization_id) then raise exception 'actor is not authorized to revise assessment'; end if;
 if v_assessment.status not in('draft','under_investigation') then raise exception 'assessed assessment is immutable; create a new assessment for a later analysis'; end if;
 if p_new_snapshot->>'status' not in('draft','under_investigation','assessed') then raise exception 'assessment revision status must be draft, under_investigation or assessed'; end if;
 if jsonb_typeof(p_new_snapshot->'unknowns')<>'array' or jsonb_typeof(p_new_snapshot->'limitations')<>'array' or jsonb_typeof(p_new_snapshot->'context')<>'object' then raise exception 'assessment JSON shapes are invalid'; end if;
 v_next:=v_assessment;
 v_next.status:=p_new_snapshot->>'status'; v_next.evidence_state:=p_new_snapshot->>'evidence_state'; v_next.supporting_evidence_count:=(p_new_snapshot->>'supporting_evidence_count')::integer; v_next.contradicting_evidence_count:=(p_new_snapshot->>'contradicting_evidence_count')::integer; v_next.unknowns:=p_new_snapshot->'unknowns'; v_next.limitations:=p_new_snapshot->'limitations'; v_next.assessment_summary:=p_new_snapshot->>'assessment_summary'; v_next.context:=p_new_snapshot->'context';
 if v_next.status='assessed' then v_next.assessed_by_user_id:=auth.uid(); v_next.assessed_at:=now(); else v_next.assessed_by_user_id:=null; v_next.assessed_at:=null; end if;
 perform public._append_evidence_assessment_revision(v_assessment.organization_id,v_assessment.id,public._evidence_assessment_snapshot(v_assessment),public._evidence_assessment_snapshot(v_next),p_reason);
 update public.intelligence_evidence_assessments as ea set status=v_next.status,evidence_state=v_next.evidence_state,supporting_evidence_count=v_next.supporting_evidence_count,contradicting_evidence_count=v_next.contradicting_evidence_count,unknowns=v_next.unknowns,limitations=v_next.limitations,assessment_summary=v_next.assessment_summary,assessed_by_user_id=v_next.assessed_by_user_id,assessed_at=v_next.assessed_at,context=v_next.context,updated_at=now() where ea.id=p_assessment_id;
 select ea.* into strict v_assessment from public.intelligence_evidence_assessments as ea where ea.id=p_assessment_id;
 return v_assessment;
end; $$;
create or replace function public.revise_intelligence_recommendation(
 p_recommendation_id uuid,
 p_new_snapshot jsonb,
 p_reason text
) returns public.intelligence_recommendations
language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_recommendation public.intelligence_recommendations%rowtype;
 v_next public.intelligence_recommendations%rowtype;
 v_key text;
begin
 if auth.uid() is null or jsonb_typeof(p_new_snapshot)<>'object' then raise exception 'invalid recommendation revision request'; end if;
 foreach v_key in array array['title','rationale','evidence_state','unknowns','alternatives','do_not_recommend','measurement_plan','approval_required','scope_type','scope_ref','status','context'] loop
  if not(p_new_snapshot ? v_key) then raise exception 'recommendation revision snapshot is missing %',v_key; end if;
 end loop;
 select rec.* into strict v_recommendation from public.intelligence_recommendations as rec where rec.id=p_recommendation_id for update;
 if not public.is_org_member(v_recommendation.organization_id) or not public.intelligence_is_admin(v_recommendation.organization_id) then raise exception 'actor is not authorized to revise recommendation'; end if;
 if v_recommendation.status not in('draft','proposed') then raise exception 'recommendation can only be revised while draft or proposed'; end if;
 if jsonb_typeof(p_new_snapshot->'unknowns')<>'array' or jsonb_typeof(p_new_snapshot->'alternatives')<>'array' or jsonb_typeof(p_new_snapshot->'do_not_recommend')<>'array' or jsonb_typeof(p_new_snapshot->'measurement_plan')<>'object' or jsonb_typeof(p_new_snapshot->'context')<>'object' or jsonb_typeof(p_new_snapshot->'approval_required')<>'boolean' then raise exception 'recommendation JSON shapes are invalid'; end if;
 v_next:=v_recommendation;
 v_next.title:=p_new_snapshot->>'title'; v_next.rationale:=p_new_snapshot->>'rationale'; v_next.evidence_state:=p_new_snapshot->>'evidence_state'; v_next.unknowns:=p_new_snapshot->'unknowns'; v_next.alternatives:=p_new_snapshot->'alternatives'; v_next.do_not_recommend:=p_new_snapshot->'do_not_recommend'; v_next.measurement_plan:=p_new_snapshot->'measurement_plan'; v_next.approval_required:=(p_new_snapshot->>'approval_required')::boolean; v_next.scope_type:=p_new_snapshot->>'scope_type'; v_next.scope_ref:=p_new_snapshot->>'scope_ref'; v_next.status:=p_new_snapshot->>'status'; v_next.context:=p_new_snapshot->'context';
 perform public._append_recommendation_revision(v_recommendation.organization_id,v_recommendation.id,public._recommendation_snapshot(v_recommendation),public._recommendation_snapshot(v_next),p_reason);
 update public.intelligence_recommendations as rec set title=v_next.title,rationale=v_next.rationale,evidence_state=v_next.evidence_state,unknowns=v_next.unknowns,alternatives=v_next.alternatives,do_not_recommend=v_next.do_not_recommend,measurement_plan=v_next.measurement_plan,approval_required=v_next.approval_required,scope_type=v_next.scope_type,scope_ref=v_next.scope_ref,status=v_next.status,context=v_next.context,updated_at=now() where rec.id=p_recommendation_id;
 select rec.* into strict v_recommendation from public.intelligence_recommendations as rec where rec.id=p_recommendation_id;
 return v_recommendation;
end; $$;
revoke execute on function public._evidence_assessment_snapshot(public.intelligence_evidence_assessments),public._recommendation_snapshot(public.intelligence_recommendations),public._append_evidence_assessment_revision(uuid,uuid,jsonb,jsonb,text),public._append_recommendation_revision(uuid,uuid,jsonb,jsonb,text) from public,authenticated;
grant execute on function public.revise_intelligence_evidence_assessment(uuid,jsonb,text),public.revise_intelligence_recommendation(uuid,jsonb,text) to authenticated;
comment on table public.intelligence_evidence_assessments is 'Evidence sufficiency assessment; counts are summaries and normalized evidence links are authoritative, not probability of cause.';
comment on table public.intelligence_recommendation_evidence is 'Legacy composed identity is organization_id + recommendation_id + evidence_id; one evidence cannot be both supports and contradicts for the same Recommendation. evidence_relation and context are additive provenance fields; no synthetic id is used.';
comment on column public.intelligence_evidence_assessments.evidence_state is 'insufficient, weak, moderate, strong or conflicting; none is a causal probability.';
comment on table public.intelligence_recommendation_evidence is 'Explicit supporting/contradicting evidence provenance for a Recommendation.';
