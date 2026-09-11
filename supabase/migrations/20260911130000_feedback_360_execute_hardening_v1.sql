-- Commercial V1 hardening: Feedback 360 application RPCs are authenticated-only.
REVOKE EXECUTE ON FUNCTION
  public.fb360_create_round(uuid,uuid,text,text),
  public.fb360_update_draft_round(uuid,text,text),
  public.fb360_add_participant(uuid,uuid,uuid,text),
  public.fb360_remove_participant(uuid),
  public.fb360_activate_round(uuid),
  public.fb360_save_score(uuid,uuid,smallint,text),
  public.fb360_submit_participation(uuid),
  public.fb360_close_round(uuid),
  public.fb360_read_subject_result(uuid,uuid,uuid),
  public.fb360_read_organization_aggregate(uuid,uuid),
  public.fb360_read_evolution(uuid,uuid,text)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
  public.fb360_create_round(uuid,uuid,text,text),
  public.fb360_update_draft_round(uuid,text,text),
  public.fb360_add_participant(uuid,uuid,uuid,text),
  public.fb360_remove_participant(uuid),
  public.fb360_activate_round(uuid),
  public.fb360_save_score(uuid,uuid,smallint,text),
  public.fb360_submit_participation(uuid),
  public.fb360_close_round(uuid),
  public.fb360_read_subject_result(uuid,uuid,uuid),
  public.fb360_read_organization_aggregate(uuid,uuid),
  public.fb360_read_evolution(uuid,uuid,text)
TO authenticated;
