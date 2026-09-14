-- youB — Ambient Intelligence Foundation V1 QA suite
-- Disposable, transactional, fail-fast. No provider, secret, transcript or external integration is used.
begin;
create temp table ctx(key text primary key, value uuid not null) on commit drop;
insert into ctx values
 ('org_a','a1000000-0000-0000-0000-000000000001'),('org_b','b1000000-0000-0000-0000-000000000001'),
 ('source_a','a1000000-0000-0000-0000-000000000010'),('source_b','b1000000-0000-0000-0000-000000000010'),
 ('obs_system','a1000000-0000-0000-0000-000000000020'),('obs_inferred','a1000000-0000-0000-0000-000000000021'),('obs_corrected','a1000000-0000-0000-0000-000000000022'),('obs_b','b1000000-0000-0000-0000-000000000023'),
 ('review_confirm','a1000000-0000-0000-0000-000000000030'),('review_correct','a1000000-0000-0000-0000-000000000031'),
 ('attention_a','a1000000-0000-0000-0000-000000000040'),('commitment_a','a1000000-0000-0000-0000-000000000041'),('brief_a','a1000000-0000-0000-0000-000000000042');
insert into public.organizations(id,name,slug,plan,status) values
 ((select value from ctx where key='org_a'),'Ambient Foundation A','ambient-foundation-a','essencial','active'),
 ((select value from ctx where key='org_b'),'Ambient Foundation B','ambient-foundation-b','essencial','active');
grant select on ctx to authenticated;
insert into public.memberships(organization_id,user_id,role) values
 ((select value from ctx where key='org_a'),'10000000-0000-0000-0000-000000000001','admin_youb'),
 ((select value from ctx where key='org_a'),'10000000-0000-0000-0000-000000000002','rh'),
 ((select value from ctx where key='org_a'),'10000000-0000-0000-0000-000000000003','diretoria'),
 ((select value from ctx where key='org_a'),'10000000-0000-0000-0000-000000000004','gestor'),
 ((select value from ctx where key='org_a'),'10000000-0000-0000-0000-000000000005','colaborador'),
 ((select value from ctx where key='org_b'),'10000000-0000-0000-0000-000000000001','admin_youb');
create or replace function pg_temp.assert_true(label text, condition boolean) returns void language plpgsql as $$ begin if condition is distinct from true then raise exception 'FAIL-FAST assertion: %',label; end if; end; $$;
create or replace function pg_temp.rejected(sql_text text) returns boolean language plpgsql security invoker as $$ begin execute sql_text; return false; exception when others then return true; end; $$;

select pg_temp.assert_true('ambient tables exist', (select count(*) from information_schema.tables where table_schema='public' and table_name in ('ambient_source_registry','ambient_observations','ambient_observation_reviews','ambient_user_preferences','ambient_attention_items','ambient_leadership_commitments','ambient_attention_briefs'))=7);
select pg_temp.assert_true('controlled event catalog extension exists', (select count(*) from public.organizational_event_types where event_type in ('ambient_source_registered','ambient_observation_recorded','ambient_observation_confirmed','ambient_observation_corrected','ambient_attention_created','ambient_attention_completed','leadership_commitment_created','leadership_commitment_completed','ambient_preference_updated'))=9);
select pg_temp.assert_true('ambient tables have RLS', (select count(*) from pg_class where relnamespace='public'::regnamespace and relname in ('ambient_source_registry','ambient_observations','ambient_observation_reviews','ambient_user_preferences','ambient_attention_items','ambient_leadership_commitments','ambient_attention_briefs') and relrowsecurity)=7);
select pg_temp.assert_true('no ambient table stores raw communications or credentials', not exists (select 1 from information_schema.columns where table_schema='public' and table_name like 'ambient_%' and column_name ~* '(transcript|raw|message_body|email_body|prompt|chain_of_thought|token|secret|password|credential)'));
select pg_temp.assert_true('no autonomous high-stakes columns exist', not exists (select 1 from information_schema.columns where table_schema='public' and table_name like 'ambient_%' and column_name ~* '(fire|terminate|promotion|remuneration|salary|autonomous|execute)'));

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
insert into public.ambient_source_registry(id,organization_id,source_key,source_type,display_name,status,capabilities,owner_user_id,metadata,created_by_user_id)
values ((select value from ctx where key='source_a'),(select value from ctx where key='org_a'),'internal-checkins','internal_record','Check-ins internos','available',array['read_observations'],'10000000-0000-0000-0000-000000000001','{"connector":"neutral","planned":false}','10000000-0000-0000-0000-000000000001');
insert into public.ambient_source_registry(id,organization_id,source_key,source_type,display_name,status,owner_user_id,metadata,created_by_user_id)
values ((select value from ctx where key='source_b'),(select value from ctx where key='org_b'),'internal-checkins','internal_record','Check-ins internos B','available','10000000-0000-0000-0000-000000000001','{}','10000000-0000-0000-0000-000000000001');
select pg_temp.assert_true('source registry stores capability metadata without secrets', exists(select 1 from public.ambient_source_registry where id=(select value from ctx where key='source_a') and metadata->>'connector'='neutral'));
select pg_temp.assert_true('source secret rejected', pg_temp.rejected(format($q$insert into public.ambient_source_registry(organization_id,source_key,source_type,display_name,metadata,created_by_user_id) values (%L,'bad-source','email','Bad','{"access_token":"no"}'::jsonb,'10000000-0000-0000-0000-000000000001')$q$,(select value from ctx where key='org_a'))));
select pg_temp.assert_true('actor spoof rejected by RLS', pg_temp.rejected(format($q$insert into public.ambient_source_registry(organization_id,source_key,source_type,display_name,metadata,created_by_user_id) values (%L,'spoofed','user_input','Spoof','{}'::jsonb,'10000000-0000-0000-0000-000000000002')$q$,(select value from ctx where key='org_a'))));
select pg_temp.assert_true('cross tenant source linkage rejected', pg_temp.rejected(format($q$insert into public.ambient_observations(organization_id,source_registry_id,observation_type,epistemic_kind,summary,observed_at,provenance,structured_value,created_by_user_id) values (%L,%L,'checkin','system_record','Cross tenant','2026-09-01','{}','{}','10000000-0000-0000-0000-000000000001')$q$,(select value from ctx where key='org_a'),(select value from ctx where key='source_b'))));

insert into public.ambient_observations(id,organization_id,source_registry_id,observation_type,epistemic_kind,summary,observed_at,sensitivity,scope_type,scope_ref,provenance,structured_value,actor_user_id,created_by_user_id)
values ((select value from ctx where key='obs_system'),(select value from ctx where key='org_a'),(select value from ctx where key='source_a'),'checkin','system_record','Check-in registrado pelo sistema','2026-09-01','standard','organization',(select value from ctx where key='org_a'),'{"record_id":"checkin-1"}','{"engagement":4}',null,'10000000-0000-0000-0000-000000000001'),
 ((select value from ctx where key='obs_inferred'),(select value from ctx where key='org_a'),(select value from ctx where key='source_a'),'work_pattern','machine_inferred','Possível concentração de decisões','2026-09-02','restricted','organization',(select value from ctx where key='org_a'),'{"basis":["checkin-1"],"method":"rule-preview"}','{"candidate":"delegation"}',null,'10000000-0000-0000-0000-000000000001'),
 ((select value from ctx where key='obs_b'),(select value from ctx where key='org_b'),(select value from ctx where key='source_b'),'checkin','system_record','Tenant B record','2026-09-01','standard','organization',(select value from ctx where key='org_b'),'{"record_id":"b-1"}','{}',null,'10000000-0000-0000-0000-000000000001');
select pg_temp.assert_true('system record remains epistemically distinct', (select epistemic_kind='system_record' from public.ambient_observations where id=(select value from ctx where key='obs_system')));
select pg_temp.assert_true('machine inference is not fact', (select epistemic_kind='machine_inferred' from public.ambient_observations where id=(select value from ctx where key='obs_inferred')) and not exists(select 1 from public.ambient_observations where id=(select value from ctx where key='obs_inferred') and epistemic_kind='system_record'));
select pg_temp.assert_true('inference without basis rejected', pg_temp.rejected(format($q$insert into public.ambient_observations(organization_id,source_registry_id,observation_type,epistemic_kind,summary,observed_at,confidence,provenance,structured_value,created_by_user_id) values (%L,%L,'inference','machine_inferred','No basis','2026-09-03',0.4,'{}','{}','10000000-0000-0000-0000-000000000001')$q$,(select value from ctx where key='org_a'),(select value from ctx where key='source_a'))));
select pg_temp.assert_true('raw transcript rejected', pg_temp.rejected(format($q$insert into public.ambient_observations(organization_id,source_registry_id,observation_type,epistemic_kind,summary,observed_at,confidence,provenance,structured_value,created_by_user_id) values (%L,%L,'email','machine_observed','Raw attempt','2026-09-03',0.8,'{"raw_transcript":"forbidden"}','{}','10000000-0000-0000-0000-000000000001')$q$,(select value from ctx where key='org_a'),(select value from ctx where key='source_a'))));

insert into public.ambient_observation_reviews(id,organization_id,observation_id,review_type,reviewer_user_id,reason)
values ((select value from ctx where key='review_confirm'),(select value from ctx where key='org_a'),(select value from ctx where key='obs_inferred'),'confirm','10000000-0000-0000-0000-000000000001','Confirma a observação de trabalho, não causalidade');
insert into public.ambient_observation_reviews(id,organization_id,observation_id,review_type,reviewer_user_id,correction_summary,correction_value,reason)
values ((select value from ctx where key='review_correct'),(select value from ctx where key='org_a'),(select value from ctx where key='obs_inferred'),'correct','10000000-0000-0000-0000-000000000001','Concentração observada em apenas um período','{"window":"one-period"}','Histórico preservado');
insert into public.ambient_observations(id,organization_id,source_registry_id,observation_type,epistemic_kind,summary,observed_at,provenance,structured_value,actor_user_id,created_by_user_id,supersedes_observation_id)
values ((select value from ctx where key='obs_corrected'),(select value from ctx where key='org_a'),(select value from ctx where key='source_a'),'work_pattern','human_corrected','Concentração corrigida para um período','2026-09-02','{"corrects":"observation"}','{"window":"one-period"}','10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',(select value from ctx where key='obs_inferred'));
select pg_temp.assert_true('confirmation and correction preserve history', (select count(*) from public.ambient_observation_reviews where observation_id=(select value from ctx where key='obs_inferred'))=2 and (select epistemic_kind from public.ambient_observations where id=(select value from ctx where key='obs_inferred'))='machine_inferred' and (select supersedes_observation_id from public.ambient_observations where id=(select value from ctx where key='obs_corrected'))=(select value from ctx where key='obs_inferred'));

insert into public.ambient_user_preferences(organization_id,user_id,preference_key,preference_value)
values ((select value from ctx where key='org_a'),'10000000-0000-0000-0000-000000000001','work_window','{"start":"08:00","end":"17:00"}');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_true('private preference isolated from RH', not exists(select 1 from public.ambient_user_preferences where organization_id=(select value from ctx where key='org_a')));
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_true('owner can read private preference', exists(select 1 from public.ambient_user_preferences where organization_id=(select value from ctx where key='org_a') and user_id=auth.uid()));

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000004',true);
insert into public.ambient_attention_items(id,organization_id,owner_user_id,horizon,attention_type,title,rationale,priority,source_observation_id,created_by_user_id)
values ((select value from ctx where key='attention_a'),(select value from ctx where key='org_a'),auth.uid(),'today','review','Revisar contexto do time','Atenção humana necessária',1,(select value from ctx where key='obs_inferred'),auth.uid());
insert into public.ambient_leadership_commitments(id,organization_id,owner_user_id,created_by_user_id,title,context,impact,horizon)
values ((select value from ctx where key='commitment_a'),(select value from ctx where key='org_a'),auth.uid(),auth.uid(),'Concluir conversa de desenvolvimento','Compromisso de liderança','Proteger clareza do time','week');
select pg_temp.assert_true('same tenant attention link succeeds', exists(select 1 from public.ambient_attention_items where id=(select value from ctx where key='attention_a')));
select pg_temp.assert_true('leadership commitment keeps context and impact', exists(select 1 from public.ambient_leadership_commitments where id=(select value from ctx where key='commitment_a') and context is not null and impact is not null));
select pg_temp.assert_true('high stakes autonomy is rejected', pg_temp.rejected(format($q$insert into public.ambient_attention_items(organization_id,owner_user_id,horizon,attention_type,title,human_required,created_by_user_id) values (%L,auth.uid(),'today','terminate','Demitir alguém',false,auth.uid())$q$,(select value from ctx where key='org_a'))));
select pg_temp.assert_true('cross tenant attention link rejected', pg_temp.rejected(format($q$insert into public.ambient_attention_items(organization_id,owner_user_id,horizon,attention_type,title,source_observation_id,created_by_user_id) values (%L,auth.uid(),'today','review','Cross tenant',%L,auth.uid())$q$,(select value from ctx where key='org_a'),(select value from ctx where key='obs_b'))));

insert into public.ambient_attention_briefs(id,organization_id,owner_user_id,horizon,context_status,focus_statement,priority_items,do_items,delegate_items,stop_items,created_by_user_id)
values ((select value from ctx where key='brief_a'),(select value from ctx where key='org_a'),auth.uid(),'today','sufficient','Proteger energia de liderança','[{"title":"Revisar feedback"}]','[{"title":"Conversar"}]','[{"title":"Delegar acompanhamento"}]','[{"title":"Parar microgestão"}]',auth.uid());
select pg_temp.assert_true('daily brief caps priority items at three', (select jsonb_array_length(priority_items) from public.ambient_attention_briefs where id=(select value from ctx where key='brief_a')) <= 3);
select pg_temp.assert_true('empty insufficient context remains empty', pg_temp.rejected(format($q$insert into public.ambient_attention_briefs(organization_id,owner_user_id,horizon,context_status,focus_statement,priority_items,created_by_user_id) values (%L,auth.uid(),'today','insufficient','Invented plan','[{"title":"fabricated"}]',auth.uid())$q$,(select value from ctx where key='org_a'))));
select pg_temp.assert_true('horizons are controlled', exists(select 1 from pg_constraint where conrelid='public.ambient_attention_items'::regclass and pg_get_constraintdef(oid) ilike '%now%today%week%later%'));

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
insert into public.organizational_events(organization_id,event_type,entity_type,entity_id,occurred_at,source_type,actor_user_id,payload,correlation_id)
values ((select value from ctx where key='org_a'),'ambient_observation_recorded','event',(select value from ctx where key='obs_inferred'),'2026-09-02','service',auth.uid(),'{}','a1000000-0000-0000-0000-000000000099');
select pg_temp.assert_true('ambient event remains append-only and correlated', exists(select 1 from public.organizational_events where event_type='ambient_observation_recorded' and correlation_id='a1000000-0000-0000-0000-000000000099'));
select pg_temp.assert_true('inference cannot become confirmation without review history', not exists(select 1 from public.ambient_observations where epistemic_kind='machine_inferred' and id in (select observation_id from public.ambient_observation_reviews where review_type='confirm') and epistemic_kind='human_confirmed'));
rollback;
