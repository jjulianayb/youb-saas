-- youB — Decision Engine + Wiring Core V1 dedicated QA suite
-- Disposable staging only. Transactional fixtures, fail-fast assertions, no migration execution.
begin;
create temp table ctx(key text primary key, value uuid not null) on commit drop;
do $$ declare k text; begin
  foreach k in array array['intelligence_decisions','intelligence_decision_interventions','intelligence_recommendations','intelligence_interventions','organizational_memory_relations','organizational_events'] loop
    if to_regclass('public.'||k) is null then raise exception 'missing Decision Engine prerequisite: %', k; end if;
  end loop;
  if (select count(*) from auth.users) < 5 then raise exception 'suite requires five auth users'; end if;
end $$;
insert into ctx values
 ('org_a','33333333-3333-3333-3333-333333333333'),('org_b','44444444-4444-4444-4444-444444444444'),
 ('employee_a','33333333-0000-0000-0000-000000000001'),('employee_b','44444444-0000-0000-0000-000000000001'),
 ('recommendation_a','33333333-0000-0000-0000-000000000011'),('recommendation_b','44444444-0000-0000-0000-000000000011'),
 ('intervention_a','33333333-0000-0000-0000-000000000021'),('intervention_b','44444444-0000-0000-0000-000000000021'),
 ('decision_a','33333333-0000-0000-0000-000000000031'),('decision_b','33333333-0000-0000-0000-000000000032'),
 ('decision_superseded','33333333-0000-0000-0000-000000000033'),('decision_pending','33333333-0000-0000-0000-000000000034'),
 ('decision_no_action','33333333-0000-0000-0000-000000000035'),('decision_rejected','33333333-0000-0000-0000-000000000036'),
 ('decision_org_b','44444444-0000-0000-0000-000000000037'),('decision_memory','33333333-0000-0000-0000-000000000053'),
 ('decision_effective','33333333-0000-0000-0000-000000000040'),('decision_pending_return','33333333-0000-0000-0000-000000000041'),('decision_pending_reject','33333333-0000-0000-0000-000000000042'),('decision_pending_actor','33333333-0000-0000-0000-000000000043'),('decision_pending_return_action','33333333-0000-0000-0000-000000000044'),
 ('decision_event','33333333-0000-0000-0000-000000000039');
insert into ctx select 'user_'||row_number() over(order by created_at),id from auth.users order by created_at limit 5;
insert into public.organizations(id,name,slug,plan,status) values
 ((select value from ctx where key='org_a'),'Decision Engine A','decision-engine-a','essencial','active'),
 ((select value from ctx where key='org_b'),'Decision Engine B','decision-engine-b','essencial','active');
insert into public.memberships(organization_id,user_id,role) values
 ((select value from ctx where key='org_a'),(select value from ctx where key='user_1'),'admin_youb'),
 ((select value from ctx where key='org_a'),(select value from ctx where key='user_2'),'diretoria'),
 ((select value from ctx where key='org_a'),(select value from ctx where key='user_3'),'gestor'),
 ((select value from ctx where key='org_a'),(select value from ctx where key='user_4'),'colaborador'),
 ((select value from ctx where key='org_a'),(select value from ctx where key='user_5'),'rh');
insert into public.employees(id,organization_id,auth_user_id,full_name,email,manager_employee_id) values
 ((select value from ctx where key='employee_a'),(select value from ctx where key='org_a'),null,'Decision Employee A','decision-a@example.invalid',null),
 ((select value from ctx where key='employee_b'),(select value from ctx where key='org_b'),null,'Decision Employee B','decision-b@example.invalid',null);
insert into public.intelligence_recommendations(
 id,organization_id,title,status,created_by,recommendation_type,scope_type,scope_ref,evidence_state,unknowns,alternatives,do_not_recommend,measurement_plan,owner_employee_id,approval_required,context
) values
 ((select value from ctx where key='recommendation_a'),(select value from ctx where key='org_a'),'Recommendation A','proposed',(select value from ctx where key='user_1'),'intervene','employee',(select value from ctx where key='employee_a'),'moderate','[]','[{"option":"A"}]','[]','{}',(select value from ctx where key='employee_a'),false,'{"fixture":"decision"}'),
 ((select value from ctx where key='recommendation_b'),(select value from ctx where key='org_b'),'Recommendation B','proposed',(select value from ctx where key='user_1'),'maintain','organization',(select value from ctx where key='org_b'),'strong','[]','[]','[]','{}',null,false,'{"fixture":"decision"}');
insert into public.intelligence_interventions(
 id,organization_id,recommendation_id,employee_id,intervention_type,title,plan,status,intervention_family,objective,target_scope_type,target_scope_ref,success_criteria,measurement_plan,requires_human_approval,context,owner_employee_id,created_by
) values
 ((select value from ctx where key='intervention_a'),(select value from ctx where key='org_a'),(select value from ctx where key='recommendation_a'),(select value from ctx where key='employee_a'),'coaching','Intervention A','{}','draft','coaching','Improve decision readiness','employee',(select value from ctx where key='employee_a'),'[]','{}',false,'{"fixture":"decision"}',(select value from ctx where key='employee_a'),(select value from ctx where key='user_1')),
 ((select value from ctx where key='intervention_b'),(select value from ctx where key='org_b'),(select value from ctx where key='recommendation_b'),(select value from ctx where key='employee_b'),'learning','Intervention B','{}','draft','learning','Improve decision readiness','employee',(select value from ctx where key='employee_b'),'[]','{}',false,'{"fixture":"decision"}',(select value from ctx where key='employee_b'),(select value from ctx where key='user_1'));

create or replace function pg_temp.assert_true(label text, condition boolean) returns void language plpgsql as $$ begin if condition is distinct from true then raise exception 'FAIL-FAST assertion: %',label; end if; end; $$;

-- Closed vocabularies and JSON contracts.
select pg_temp.assert_true('decision types are closed',not exists(select 1 from public.intelligence_decisions where decision_type='arbitrary'));
select pg_temp.assert_true('scope types reuse shared scope vocabulary',not exists(select 1 from public.intelligence_decisions where scope_type='workspace'));
select pg_temp.assert_true('risk scale reuses Bee Action vocabulary',not exists(select 1 from public.intelligence_decisions where risk_level='high'));
select pg_temp.assert_true('status vocabulary is closed',not exists(select 1 from public.intelligence_decisions where status='approved'));
select pg_temp.assert_true('decision event vocabulary is implemented',
  (select count(*) from public.organizational_event_types where event_type in ('decision_created','decision_approved','decision_rejected','decision_deferred','decision_superseded','decision_effective') and implemented=true)=6);
select pg_temp.assert_true('revision and return event contracts are implemented',
  (select count(*) from public.organizational_event_types where event_type in ('decision_revised','decision_returned_for_review') and implemented=true)=2);

-- Structurally valid historical decisions: one Recommendation can have multiple Decisions.
insert into public.intelligence_decisions(
 id,organization_id,decision_type,scope_type,scope_ref,recommendation_id,decision_statement,selected_option,alternatives_considered,rationale,evidence_snapshot,unknowns,risk_level,risk_accepted,status,owner_employee_id,decision_maker_user_id,approval_required,context
) values
 ((select value from ctx where key='decision_a'),(select value from ctx where key='org_a'),'accept_recommendation','employee',(select value from ctx where key='employee_a'),(select value from ctx where key='recommendation_a'),'Accept Recommendation A','accept','[{"option":"accept"},{"option":"defer"}]','Human review selected the recommendation.','{"available":["evidence-1"],"captured_at":"2026-01-02T00:00:00Z"}','["future outcome"]','operational',true,'decided',(select value from ctx where key='employee_a'),(select value from ctx where key='user_1'),false,'{"source":"human_review"}'),
 ((select value from ctx where key='decision_b'),(select value from ctx where key='org_a'),'select_alternative','team','team-a',(select value from ctx where key='recommendation_a'),'Select an alternative for Recommendation A','alternative','[{"option":"accept"},{"option":"alternative"}]','An alternative was selected after review.','{"available":["evidence-1"],"captured_at":"2026-01-03T00:00:00Z"}','[]','personal_reversible',false,'draft',(select value from ctx where key='employee_a'),null,false,'{"source":"human_review"}'),
 ((select value from ctx where key='decision_superseded'),(select value from ctx where key='org_a'),'maintain','employee',(select value from ctx where key='employee_a'),(select value from ctx where key='recommendation_a'),'Maintain the current course','maintain','[{"option":"maintain"}]','Later human review superseded the first decision.','{"available":["evidence-2"],"captured_at":"2026-02-01T00:00:00Z"}','[]','operational',true,'draft',(select value from ctx where key='employee_a'),(select value from ctx where key='user_1'),false,'{"source":"human_review"}');
update public.intelligence_decisions set status='superseded' where id=(select value from ctx where key='decision_superseded');
insert into public.intelligence_decisions(
 id,organization_id,decision_type,scope_type,scope_ref,recommendation_id,decision_statement,alternatives_considered,rationale,evidence_snapshot,unknowns,risk_level,risk_accepted,status,owner_employee_id,decision_maker_user_id,approval_required,required_approver_role,context
) values
 ((select value from ctx where key='decision_pending'),(select value from ctx where key='org_a'),'select_alternative','organization',(select value from ctx where key='org_a'),(select value from ctx where key='recommendation_a'),'Pending approval decision','[]','Awaiting explicit approval.','{"available":["evidence-1"]}','[]','sensitive',true,'pending_approval',(select value from ctx where key='employee_a'),(select value from ctx where key='user_1'),true,'diretoria','{"source":"human_review"}'),
 ((select value from ctx where key='decision_no_action'),(select value from ctx where key='org_a'),'no_action','employee',(select value from ctx where key='employee_a'),(select value from ctx where key='recommendation_a'),'Take no action','[]','Human decision to take no action.','{"available":[]}','[]','informational',false,'decided',(select value from ctx where key='employee_a'),(select value from ctx where key='user_1'),false,'{"source":"human_review"}'),
 ((select value from ctx where key='decision_rejected'),(select value from ctx where key='org_a'),'reject','employee',(select value from ctx where key='employee_a'),(select value from ctx where key='recommendation_a'),'Reject the proposal','[]','Human decision rejected the proposal.','{"available":["evidence-1"]}','[]','operational',true,'decided',(select value from ctx where key='employee_a'),(select value from ctx where key='user_1'),false,'{"source":"human_review"}'),
 ((select value from ctx where key='decision_org_b'),(select value from ctx where key='org_b'),'maintain','organization',(select value from ctx where key='org_b'),(select value from ctx where key='recommendation_b'),'Maintain organization B','[]','Fixture for tenant-safe probes.','{"available":[]}','[]','informational',false,'draft',null,(select value from ctx where key='user_1'),false,null,'{"source":"fixture"}');
insert into public.intelligence_decisions(
 id,organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,rationale,evidence_snapshot,unknowns,risk_level,risk_accepted,status,owner_employee_id,decision_maker_user_id,approval_required,required_approver_role,effective_at,context
) values
 ((select value from ctx where key='decision_effective'),(select value from ctx where key='org_a'),'maintain','organization',(select value from ctx where key='org_a'),'Effective decision','[]','Established current state.','{"available":["evidence-1"]}','[]','operational',true,'effective',null,(select value from ctx where key='user_1'),false,null,'2026-02-01','{}'),
 ((select value from ctx where key='decision_pending_return'),(select value from ctx where key='org_a'),'maintain','organization',(select value from ctx where key='org_a'),'Pending return decision','[]','Awaiting review.','{"available":["evidence-1"]}','[]','operational',true,'pending_approval',(select value from ctx where key='employee_a'),(select value from ctx where key='user_1'),true,'diretoria',null,'{}'),
 ((select value from ctx where key='decision_pending_reject'),(select value from ctx where key='org_a'),'maintain','organization',(select value from ctx where key='org_a'),'Pending reject decision','[]','Awaiting rejection.','{"available":["evidence-1"]}','[]','operational',true,'pending_approval',(select value from ctx where key='employee_a'),(select value from ctx where key='user_1'),true,'diretoria',null,'{}'),
 ((select value from ctx where key='decision_pending_actor'),(select value from ctx where key='org_a'),'maintain','organization',(select value from ctx where key='org_a'),'Pending actor decision','[]','Awaiting approver.','{"available":["evidence-1"]}','[]','operational',true,'pending_approval',(select value from ctx where key='employee_a'),(select value from ctx where key='user_1'),true,'diretoria',null,'{}'),
 ((select value from ctx where key='decision_pending_return_action'),(select value from ctx where key='org_a'),'maintain','organization',(select value from ctx where key='org_a'),'Pending return action','[]','Awaiting review action.','{"available":["evidence-1"]}','[]','operational',true,'pending_approval',(select value from ctx where key='employee_a'),(select value from ctx where key='user_1'),true,'diretoria',null,'{}');
select pg_temp.assert_true('multiple Decisions for one Recommendation remain preserved',(select count(*) from public.intelligence_decisions where recommendation_id=(select value from ctx where key='recommendation_a'))=6);
select pg_temp.assert_true('superseded predecessor retains history without pointing forward',(select supersedes_decision_id is null from public.intelligence_decisions where id=(select value from ctx where key='decision_superseded')));
select pg_temp.assert_true('evidence snapshot is preserved',(select evidence_snapshot->>'captured_at' from public.intelligence_decisions where id=(select value from ctx where key='decision_a'))='2026-01-02T00:00:00Z');

create or replace function pg_temp.invalid_decision_vocab() returns boolean language plpgsql security invoker as $$ begin begin
  insert into public.intelligence_decisions(organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,status,context)
  values((select value from ctx where key='org_a'),'arbitrary','organization','org-a','Invalid','[]','{}','[]','informational','draft','{}'); return false;
exception when others then return true; end; end; $$;
create or replace function pg_temp.invalid_decision_json() returns boolean language plpgsql security invoker as $$ begin begin
  insert into public.intelligence_decisions(organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,status,context)
  values((select value from ctx where key='org_a'),'maintain','organization','org-a','Invalid','{}','[]','{}','informational','draft','[]'); return false;
exception when others then return true; end; end; $$;
create or replace function pg_temp.invalid_effective_without_approval() returns boolean language plpgsql security invoker as $$ begin begin
  insert into public.intelligence_decisions(organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,risk_accepted,status,decision_maker_user_id,approval_required,required_approver_role,context)
  values((select value from ctx where key='org_a'),'maintain','organization','org-a','Invalid effective','[]','{}','[]','sensitive',true,'effective',(select value from ctx where key='user_1'),true,'diretoria','{}'); return false;
exception when others then return true; end; end; $$;
create or replace function pg_temp.invalid_approval_provenance() returns boolean language plpgsql security invoker as $$ begin begin
  insert into public.intelligence_decisions(organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,status,decision_maker_user_id,approval_required,required_approver_role,approved_by,context)
  values((select value from ctx where key='org_a'),'maintain','organization','org-a','Invalid approval provenance','[]','{}','[]','sensitive','pending_approval',(select value from ctx where key='user_1'),true,'diretoria',(select value from ctx where key='user_2'),'{}'); return false;
exception when others then return true; end; end; $$;
create or replace function pg_temp.invalid_self_supersede() returns boolean language plpgsql security invoker as $$ begin begin
  insert into public.intelligence_decisions(id,organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,status,decision_maker_user_id,approval_required,supersedes_decision_id,context)
  values('33333333-0000-0000-0000-000000000050',(select value from ctx where key='org_a'),'maintain','organization','org-a','Invalid self supersede','[]','{}','[]','informational','superseded',(select value from ctx where key='user_1'),false,'33333333-0000-0000-0000-000000000050','{}'); return false;
exception when others then return true; end; end; $$;
create or replace function pg_temp.invalid_cross_tenant_supersede() returns boolean language plpgsql security invoker as $$ begin begin
  insert into public.intelligence_decisions(organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,status,decision_maker_user_id,approval_required,supersedes_decision_id,context)
  values((select value from ctx where key='org_a'),'maintain','organization','org-a','Invalid cross tenant supersede','[]','{}','[]','informational','superseded',(select value from ctx where key='user_1'),false,(select value from ctx where key='decision_org_b'),'{}'); return false;
exception when others then return true; end; end; $$;
select pg_temp.assert_true('invalid decision vocabulary rejected',pg_temp.invalid_decision_vocab());
select pg_temp.assert_true('invalid decision JSON shapes rejected',pg_temp.invalid_decision_json());
select pg_temp.assert_true('effective without required approval rejected',pg_temp.invalid_effective_without_approval());
select pg_temp.assert_true('approval provenance must be paired',pg_temp.invalid_approval_provenance());
select pg_temp.assert_true('self supersede rejected',pg_temp.invalid_self_supersede());
select pg_temp.assert_true('cross-tenant supersede rejected structurally',pg_temp.invalid_cross_tenant_supersede());

-- Decision can be explicitly represented in Organizational Memory; no automatic projection exists.
insert into public.organizational_memory_relations(organization_id,source_entity_type,source_entity_id,target_entity_type,target_entity_id,relationship_type,knowledge_kind,valid_from,source_type,source_id,sensitivity,context)
values((select value from ctx where key='org_a'),'decision',(select value from ctx where key='decision_a'),'organization',(select value from ctx where key='org_a'),'declares','declared','2026-01-02','service',(select value::text from ctx where key='decision_a'),'standard','{"decision_id":"decision_a"}');
select pg_temp.assert_true('decision memory projection is epistemically declared',exists(select 1 from public.organizational_memory_relations where source_entity_type='decision' and source_entity_id=(select value from ctx where key='decision_a') and knowledge_kind='declared'));

-- Explicit Decision–Intervention wiring is tenant-safe and does not imply execution.
insert into public.intelligence_decision_interventions(organization_id,decision_id,intervention_id,context)
values((select value from ctx where key='org_a'),(select value from ctx where key='decision_a'),(select value from ctx where key='intervention_a'),'{}');
select pg_temp.assert_true('Decision–Intervention link preserved',exists(select 1 from public.intelligence_decision_interventions where decision_id=(select value from ctx where key='decision_a') and intervention_id=(select value from ctx where key='intervention_a')));
create or replace function pg_temp.invalid_cross_tenant_intervention_link() returns boolean language plpgsql security invoker as $$ begin begin
  insert into public.intelligence_decision_interventions(organization_id,decision_id,intervention_id,context)
  values((select value from ctx where key='org_a'),(select value from ctx where key='decision_a'),(select value from ctx where key='intervention_b'),'{}'); return false;
exception when others then return true; end; end; $$;
select pg_temp.assert_true('cross-tenant Decision–Intervention link rejected',pg_temp.invalid_cross_tenant_intervention_link());
select pg_temp.assert_true('rejected decision creates no intervention automatically',not exists(select 1 from public.intelligence_decision_interventions where decision_id=(select value from ctx where key='decision_rejected')));
select pg_temp.assert_true('no_action decision creates no intervention automatically',not exists(select 1 from public.intelligence_decision_interventions where decision_id=(select value from ctx where key='decision_no_action')));
select pg_temp.assert_true('no Action is created by deciding',not exists(select 1 from public.intelligence_actions where organization_id=(select value from ctx where key='org_a')));

-- Event wiring is an explicit implemented contract, not an automatic trigger.
insert into public.organizational_events(id,organization_id,event_type,entity_type,entity_id,occurred_at,source_type,source_id,actor_user_id,sensitivity,payload)
values((select value from ctx where key='decision_event'),(select value from ctx where key='org_a'),'decision_created','decision',(select value from ctx where key='decision_a'),'2026-01-02','service','decision-service',(select value from ctx where key='user_1'),'standard','{"decision_id":"decision_a"}');
select pg_temp.assert_true('decision event contract is accepted',exists(select 1 from public.organizational_events where id=(select value from ctx where key='decision_event')));

-- Role and tenant boundaries.
set local role authenticated;
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_1'),true);
select pg_temp.assert_true('admin reads own decisions',exists(select 1 from public.intelligence_decisions where organization_id=(select value from ctx where key='org_a')));
select pg_temp.assert_true('admin cannot read cross-tenant decisions',not exists(select 1 from public.intelligence_decisions where organization_id=(select value from ctx where key='org_b')));
create or replace function pg_temp.decision_cross_tenant_rls_probe() returns boolean language plpgsql security invoker as $$ declare msg text; begin begin
  insert into public.intelligence_decisions(organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,status,decision_maker_user_id,approval_required,context)
  values((select value from ctx where key='org_b'),'maintain','organization','org-b','Cross tenant decision','[]','{}','[]','informational','draft',(select value from ctx where key='user_1'),false,'{}'); return false;
exception when others then get stacked diagnostics msg=message_text; return msg ilike '%row-level security%'; end; end; $$;
select pg_temp.assert_true('admin cross-tenant decision write denied by RLS',pg_temp.decision_cross_tenant_rls_probe());

create or replace function pg_temp.admin_decision_insert_ok() returns boolean language plpgsql security invoker as $$ declare decision_id uuid := '33333333-0000-0000-0000-000000000051'; begin
  insert into public.intelligence_decisions(id,organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,status,decision_maker_user_id,approval_required,context)
  values(decision_id,(select value from ctx where key='org_a'),'maintain','organization','org-a','Admin decision','[]','{}','[]','informational','draft',(select value from ctx where key='user_1'),false,'{}'); return exists(select 1 from public.intelligence_decisions where id=decision_id);
end; $$;
select pg_temp.assert_true('admin can create own decision',pg_temp.admin_decision_insert_ok());

select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_2'),true);
select pg_temp.assert_true('diretoria reads permitted organizational decision',exists(select 1 from public.intelligence_decisions where organization_id=(select value from ctx where key='org_a') and scope_type='organization'));
create or replace function pg_temp.directoria_decision_insert_ok() returns boolean language plpgsql security invoker as $$ declare decision_id uuid := '33333333-0000-0000-0000-000000000052'; begin
  insert into public.intelligence_decisions(id,organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,status,decision_maker_user_id,approval_required,context)
  values(decision_id,(select value from ctx where key='org_a'),'maintain','organization','org-a','Diretoria decision','[]','{}','[]','operational','draft',(select value from ctx where key='user_2'),false,'{}'); return exists(select 1 from public.intelligence_decisions where id=decision_id);
end; $$;
select pg_temp.assert_true('diretoria can record explicitly authorized organizational decision',pg_temp.directoria_decision_insert_ok());
select public.approve_intelligence_decision((select value from ctx where key='decision_pending')); 
select pg_temp.assert_true('diretoria approval has provenance',exists(select 1 from public.intelligence_decisions where id=(select value from ctx where key='decision_pending') and approved_by=(select value from ctx where key='user_2') and approved_at is not null));

create or replace function pg_temp.decision_insert_denied_probe() returns boolean language plpgsql security invoker as $$ declare msg text; begin begin
  insert into public.intelligence_decisions(organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,status,decision_maker_user_id,approval_required,context)
  values((select value from ctx where key='org_a'),'maintain','organization','org-a','Unauthorized decision','[]','{}','[]','informational','draft',auth.uid(),false,'{}'); return false;
exception when others then get stacked diagnostics msg=message_text; return msg ilike '%row-level security%'; end; end; $$;
select pg_temp.assert_true('diretoria explicit decision contract is available',not pg_temp.decision_insert_denied_probe());

select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_3'),true);
select pg_temp.assert_true('gestor has no generic decision read',not exists(select 1 from public.intelligence_decisions where organization_id=(select value from ctx where key='org_a')));
select pg_temp.assert_true('gestor cannot insert decision',pg_temp.decision_insert_denied_probe());
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_4'),true);
select pg_temp.assert_true('colaborador has no generic decision read',not exists(select 1 from public.intelligence_decisions where organization_id=(select value from ctx where key='org_a')));
select pg_temp.assert_true('colaborador cannot insert decision',pg_temp.decision_insert_denied_probe());

select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_5'),true);
create or replace function pg_temp.rh_decision_insert_ok() returns boolean language plpgsql security invoker as $$ declare decision_id uuid := '33333333-0000-0000-0000-000000000053'; begin
  insert into public.intelligence_decisions(id,organization_id,decision_type,scope_type,scope_ref,decision_statement,alternatives_considered,evidence_snapshot,unknowns,risk_level,status,decision_maker_user_id,approval_required,context)
  values(decision_id,(select value from ctx where key='org_a'),'defer','organization',(select value from ctx where key='org_a'),'RH deferred decision','[]','{"available":[]}','["more evidence"]','personal_reversible','pending_review',(select value from ctx where key='user_5'),false,'{}'); return exists(select 1 from public.intelligence_decisions where id=decision_id);
end; $$;
select pg_temp.assert_true('RH can create own tenant decision',pg_temp.rh_decision_insert_ok());
select pg_temp.assert_true('RH reads own tenant decisions',exists(select 1 from public.intelligence_decisions where organization_id=(select value from ctx where key='org_a')));
select pg_temp.assert_true('RH cannot read cross-tenant decisions',not exists(select 1 from public.intelligence_decisions where organization_id=(select value from ctx where key='org_b')));

-- Controlled collaborative editing and append-only revision history.
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_2'),true);
select public.revise_intelligence_decision((select id from public.intelligence_decisions where id='33333333-0000-0000-0000-000000000052'), '{"scope_type":"organization","scope_ref":"org-a","decision_statement":"Diretoria revised draft","selected_option":null,"alternatives_considered":[],"rationale":"New rationale","evidence_snapshot":{"available":["draft-evidence"]},"unknowns":[],"risk_level":"operational","risk_accepted":true}'::jsonb, 'diretoria draft review');
select pg_temp.assert_true('diretoria can revise draft', exists(select 1 from public.intelligence_decisions where id='33333333-0000-0000-0000-000000000052' and status='draft'));
select pg_temp.assert_true('draft revision stores before and after snapshots', exists(select 1 from public.intelligence_decision_revisions r where r.decision_id='33333333-0000-0000-0000-000000000052' and r.revision_number=1 and r.previous_snapshot->>'decision_statement'='Diretoria decision' and r.new_snapshot->>'decision_statement'='Diretoria revised draft'));
select public.revise_intelligence_decision((select value from ctx where key='decision_memory'), '{"scope_type":"organization","scope_ref":"org-a","decision_statement":"RH deferred decision revised","selected_option":null,"alternatives_considered":[],"rationale":"Director review","evidence_snapshot":{"available":["review-evidence"]},"unknowns":["one unknown"],"risk_level":"personal_reversible","risk_accepted":false}'::jsonb, 'diretoria pending review');
select pg_temp.assert_true('diretoria can revise pending_review', exists(select 1 from public.intelligence_decisions where id=(select value from ctx where key='decision_memory') and status='pending_review'));
select pg_temp.assert_true('pending_review revision preserves evidence snapshot before and after', (select (previous_snapshot->'evidence_snapshot' ? 'available') and jsonb_typeof(previous_snapshot->'evidence_snapshot'->'available')='array' and jsonb_array_length(previous_snapshot->'evidence_snapshot'->'available')=0 and jsonb_typeof(new_snapshot->'evidence_snapshot'->'available')='array' and (new_snapshot->'evidence_snapshot'->'available'->>0)='review-evidence' from public.intelligence_decision_revisions r where r.decision_id=(select value from ctx where key='decision_memory') order by revision_number desc limit 1));
select pg_temp.assert_true('evidence snapshot revision is auditable', (select count(*)=1 from public.intelligence_decision_revisions where decision_id=(select value from ctx where key='decision_memory') and previous_snapshot ? 'evidence_snapshot' and new_snapshot ? 'evidence_snapshot'));
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_5'),true);
select public.revise_intelligence_decision((select value from ctx where key='decision_memory'), '{"scope_type":"organization","scope_ref":"org-a","decision_statement":"RH revision after director review","selected_option":null,"alternatives_considered":[],"rationale":"RH collaboration","evidence_snapshot":{"available":["rh-evidence"]},"unknowns":[],"risk_level":"personal_reversible","risk_accepted":false}'::jsonb, 'RH collaboration');
select pg_temp.assert_true('RH can revise pending_review', exists(select 1 from public.intelligence_decision_revisions where decision_id=(select value from ctx where key='decision_memory') and revision_number=2 and changed_by_user_id=(select value from ctx where key='user_5')));
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_1'),true);
select public.revise_intelligence_decision('33333333-0000-0000-0000-000000000051', '{"scope_type":"organization","scope_ref":"org-a","decision_statement":"Admin revised draft","selected_option":null,"alternatives_considered":[],"rationale":"Admin collaboration","evidence_snapshot":{"available":["admin-evidence"]},"unknowns":[],"risk_level":"informational","risk_accepted":false}'::jsonb, 'admin collaboration');
select pg_temp.assert_true('admin can revise draft', exists(select 1 from public.intelligence_decision_revisions where decision_id='33333333-0000-0000-0000-000000000051' and changed_by_user_id=(select value from ctx where key='user_1')));
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_2'),true);

-- Alteration during pending approval must return to review and be revised before approval.
select public.revise_intelligence_decision((select value from ctx where key='decision_pending_return'), '{"scope_type":"organization","scope_ref":"org-a","decision_statement":"Changed before approval","selected_option":null,"alternatives_considered":[],"rationale":"Substantive director change","evidence_snapshot":{"available":["new-evidence"]},"unknowns":[],"risk_level":"sensitive","risk_accepted":true}'::jsonb, 'substantive change before approval');
select pg_temp.assert_true('pending approval substantive revision returns to review', (select status='pending_review' from public.intelligence_decisions where id=(select value from ctx where key='decision_pending_return')));
select pg_temp.assert_true('pending approval substantive revision is stored', exists(select 1 from public.intelligence_decision_revisions where decision_id=(select value from ctx where key='decision_pending_return') and revision_number=1 and new_snapshot->>'decision_statement'='Changed before approval'));
select public.return_intelligence_decision_for_review((select value from ctx where key='decision_pending_return_action'),'return for review');
select pg_temp.assert_true('diretoria can return approval for review without deleting history', exists(select 1 from public.intelligence_decisions where id=(select value from ctx where key='decision_pending_return_action') and status='pending_review'));
select pg_temp.assert_true('returned decision history remains', (select count(*)=1 from public.intelligence_decision_revisions where decision_id=(select value from ctx where key='decision_pending_return_action')));
select public.reject_intelligence_decision((select value from ctx where key='decision_pending_reject'),'reject approval');
select pg_temp.assert_true('diretoria can reject pending approval without deleting history', exists(select 1 from public.intelligence_decisions where id=(select value from ctx where key='decision_pending_reject') and status='cancelled'));
select pg_temp.assert_true('rejected decision history remains', (select count(*)=1 from public.intelligence_decision_revisions where decision_id=(select value from ctx where key='decision_pending_reject')));

-- An actor without the required role cannot approve.
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_3'),true);
create or replace function pg_temp.non_approver_probe() returns boolean language plpgsql security invoker as $$ declare msg text; begin begin perform public.approve_intelligence_decision((select value from ctx where key='decision_pending_actor')); return false; exception when others then get stacked diagnostics msg=message_text; return msg ilike '%required diretoria approver%' or msg ilike '%permission%'; end; end; $$;
select pg_temp.assert_true('actor without required role cannot approve',pg_temp.non_approver_probe());
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_2'),true);
create or replace function pg_temp.cross_tenant_revision_probe() returns boolean language plpgsql security invoker as $$ declare msg text; begin begin perform public.revise_intelligence_decision((select value from ctx where key='decision_org_b'), '{"scope_type":"organization","scope_ref":"org-b","decision_statement":"cross tenant","selected_option":null,"alternatives_considered":[],"rationale":null,"evidence_snapshot":{},"unknowns":[],"risk_level":"informational","risk_accepted":false}'::jsonb, 'cross tenant'); return false; exception when others then get stacked diagnostics msg=message_text; return msg ilike '%not a member%' or msg ilike '%not authorized%'; end; end; $$;
select pg_temp.assert_true('decision from another tenant cannot be revised',pg_temp.cross_tenant_revision_probe());
create or replace function pg_temp.cross_tenant_approval_probe() returns boolean language plpgsql security invoker as $$ declare msg text; begin begin perform public.approve_intelligence_decision((select value from ctx where key='decision_org_b')); return false; exception when others then get stacked diagnostics msg=message_text; return msg ilike '%required diretoria approver%' or msg ilike '%not a member%'; end; end; $$;
select pg_temp.assert_true('decision from another tenant cannot be approved',pg_temp.cross_tenant_approval_probe());

-- Switch to admin for the effective-state and corrected supersession probes.
select set_config('request.jwt.claim.sub',(select value::text from ctx where key='user_1'),true);
create or replace function pg_temp.silent_content_update_probe(p_id uuid) returns boolean language plpgsql security invoker as $$ declare msg text; begin begin update public.intelligence_decisions set decision_statement='silent overwrite',evidence_snapshot='{}' where id=p_id; return false; exception when others then get stacked diagnostics msg=message_text; return msg ilike '%permission denied%' or msg ilike '%row-level security%'; end; end; $$;
select pg_temp.assert_true('silent decided content update fails',pg_temp.silent_content_update_probe((select value from ctx where key='decision_a')));
select pg_temp.assert_true('silent effective evidence update fails',pg_temp.silent_content_update_probe((select value from ctx where key='decision_effective')));
insert into ctx(key,value) values ('successor',public.create_superseding_intelligence_decision((select value from ctx where key='decision_effective'), '{"decision_type":"maintain","scope_type":"organization","scope_ref":"org-a","recommendation_id":null,"decision_statement":"Successor decision","selected_option":"new-course","alternatives_considered":[],"rationale":"New decision after effective state","evidence_snapshot":{"available":["new-evidence"]},"unknowns":[],"risk_level":"operational","risk_accepted":true,"status":"effective","approval_required":false,"required_approver_role":null,"effective_at":"2026-03-01T00:00:00Z","owner_employee_id":null,"context":{"supersession":true}}'::jsonb, 'replace effective decision'));
select pg_temp.assert_true('new successor points to predecessor',(select supersedes_decision_id=(select value from ctx where key='decision_effective') from public.intelligence_decisions where id=(select value from ctx where key='successor')));
select pg_temp.assert_true('predecessor becomes superseded',(select status='superseded' from public.intelligence_decisions where id=(select value from ctx where key='decision_effective')));
select pg_temp.assert_true('successor remains effective',(select status='effective' from public.intelligence_decisions where id=(select value from ctx where key='successor')));
select pg_temp.assert_true('supersession history is retained',(select count(*)=1 from public.intelligence_decision_revisions where decision_id=(select value from ctx where key='decision_effective') and (new_snapshot->>'status')='superseded'));

-- No automatic decision/intervention/action machinery is present.
select pg_temp.assert_true('no user trigger on Decision Engine tables',not exists(select 1 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('intelligence_decisions','intelligence_decision_interventions') and not t.tgisinternal));
select pg_temp.assert_true('Decision Engine stores no raw conversation or prompt',not exists(select 1 from information_schema.columns where table_schema='public' and table_name in ('intelligence_decisions','intelligence_decision_interventions') and column_name in ('conversation','raw_conversation','prompt','raw_prompt','message','chain_of_thought')));
rollback;
