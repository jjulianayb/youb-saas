-- Commercial V1 hardening: keep application DML grants aligned with the
-- authenticated RLS policies. RLS remains the authorization boundary.
GRANT SELECT, INSERT
ON public.intelligence_recommendations, public.intelligence_interventions
TO authenticated;

GRANT SELECT, INSERT
ON public.intelligence_recommendation_evidence
TO authenticated;
