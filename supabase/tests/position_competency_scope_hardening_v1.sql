-- Contract test for the tenant-bound position-competency read policy.
BEGIN;

DO $$
DECLARE
  policy_definition text;
BEGIN
  SELECT pg_get_expr(polqual, polrelid)
    INTO policy_definition
  FROM pg_policy
  WHERE polrelid = 'public.position_competencies'::regclass
    AND polname = 'cca_position_competencies_select_scoped';

  IF policy_definition IS NULL THEN
    RAISE EXCEPTION 'cca_position_competencies_select_scoped is missing';
  END IF;

  IF policy_definition NOT LIKE '%is_org_member%' THEN
    RAISE EXCEPTION 'position competency policy must require tenant membership: %', policy_definition;
  END IF;
END
$$;

ROLLBACK;
