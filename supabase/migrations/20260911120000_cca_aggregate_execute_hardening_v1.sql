-- Commercial V1 hardening: aggregate assessment RPC is authenticated-only.
-- Preserve the RPC contract; tighten execution privileges forward-only.
REVOKE EXECUTE
ON FUNCTION public.cca_read_assessment_aggregate(uuid, uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.cca_read_assessment_aggregate(uuid, uuid)
TO authenticated;
