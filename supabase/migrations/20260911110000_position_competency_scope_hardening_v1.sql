-- Commercial V1 hardening: keep position-competency reads tenant-bound
-- before applying direct-report scope. This is a forward-only RLS fix.
DROP POLICY IF EXISTS cca_position_competencies_select_scoped ON public.position_competencies;

CREATE POLICY cca_position_competencies_select_scoped
ON public.position_competencies
FOR SELECT
TO authenticated
USING (
  public.is_org_member(organization_id)
  AND (
    public.classic_is_org_admin(organization_id)
    OR public.has_org_role(organization_id, ARRAY['diretoria'])
    OR EXISTS (
      SELECT 1
      FROM public.employees e
      WHERE e.organization_id = position_competencies.organization_id
        AND e.position_id = position_competencies.position_id
        AND e.status = 'active'
        AND public.classic_is_direct_report(position_competencies.organization_id, e.id)
    )
    OR EXISTS (
      SELECT 1
      FROM public.assessment_competency_scores s
      JOIN public.assessments a
        ON a.organization_id = s.organization_id
       AND a.id = s.assessment_id
      WHERE s.organization_id = position_competencies.organization_id
        AND s.position_competency_id = position_competencies.id
        AND a.status = 'completed'
        AND public.classic_has_single_own_employee(a.organization_id, a.subject_employee_id)
    )
  )
);
