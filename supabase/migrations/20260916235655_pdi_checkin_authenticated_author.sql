alter table public.pdi_checkins add column author_user_id uuid references auth.users(id) on delete restrict;
alter table public.pdi_checkins alter column author_employee_id drop not null;
alter table public.pdi_checkins add constraint pdi_checkins_author_identity_required check (author_employee_id is not null or author_user_id is not null);
comment on column public.pdi_checkins.author_user_id is 'Authenticated author captured by pdi_add_checkin. Legacy records retain employee attribution. No client-provided author is accepted.';
CREATE OR REPLACE FUNCTION public.pdi_add_checkin(p_pdi_id uuid, p_progress_note text, p_next_step text DEFAULT NULL::text, p_blocker text DEFAULT NULL::text, p_evidence_reference text DEFAULT NULL::text, p_objective_id uuid DEFAULT NULL::uuid, p_action_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_p public.pdis%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'check-in requires authentication' using errcode='42501'; end if;
  select * into v_p from public.pdis where id=p_pdi_id;
  if v_p.id is null or not public.pdi_can_manage(v_p.organization_id,v_p.employee_id) or v_p.status in ('completed','cancelled') then raise exception 'check-in is outside the authorized population' using errcode='42501'; end if;
  if nullif(btrim(p_progress_note),'') is null then raise exception 'check-in progress is required' using errcode='22023'; end if;
  if p_objective_id is not null and not exists(select 1 from public.pdi_objectives where organization_id=v_p.organization_id and id=p_objective_id and pdi_id=p_pdi_id) then raise exception 'check-in objective is outside the pdi' using errcode='42501'; end if;
  if p_action_id is not null and not exists(select 1 from public.pdi_actions a join public.pdi_objectives o on o.organization_id=a.organization_id and o.id=a.objective_id where a.organization_id=v_p.organization_id and a.id=p_action_id and o.pdi_id=p_pdi_id) then raise exception 'check-in action is outside the pdi' using errcode='42501'; end if;
  insert into public.pdi_checkins(organization_id,pdi_id,objective_id,action_id,author_employee_id,author_user_id,progress_note,next_step,blocker,evidence_reference) values(v_p.organization_id,p_pdi_id,p_objective_id,p_action_id,public.pdi_actor_employee_id(v_p.organization_id),auth.uid(),btrim(p_progress_note),nullif(btrim(p_next_step),''),nullif(btrim(p_blocker),''),nullif(btrim(p_evidence_reference),'')) returning id into v_id;
  perform public.pdi_append_audit(v_p.organization_id,'checkin',v_id,'checkin_created'); return v_id;
end $function$
;