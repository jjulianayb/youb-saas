# Release validation checkpoint

No new infrastructure or paid service was provisioned. Lovable visual files were not changed.

## Applied and verified on existing database
- Fixed search_path on four snapshot helpers. All four returned JSON for null composite inputs.
- Removed anonymous EXECUTE from 22 business RPCs, preserving authenticated and service_role grants. Verified zero anonymous permissions and zero missing authenticated grants for the exact target list.
- Fixed new-admin PDI checkin failure: an admin without an employee record now writes author_user_id from auth.uid(). Existing employee attribution is preserved; authorization and tenant scope checks unchanged.
- Ran rollback-only SQL fixture test with two synthetic auth users and organizations: organization creation, employee creation, cycle creation, PDI creation/activation/objective/action/checkin/completion; second tenant cannot read employee/PDI or create PDI in first tenant. Verified author identity and no residual QA auth users.
- Four mutable search_path advisor warnings cleared. One anonymous SECURITY DEFINER warning remains for platform event trigger rls_auto_enable; 76 authenticated SECURITY DEFINER advisories require contextual review, not blanket revocation. Leaked password protection remains disabled; no paid upgrade enabled.

## Important scope correction
Seven Ambient tables are absent on hosted database AND Ambient is absent in main c174836a681823abc9b0fe8d00450d732f2509e0. This is an unintegrated feature, not evidence that current main is missing its migrations. Do not deploy Ambient merely to clear a dashboard warning.

## Remaining release gates
1. Confirm the exact Lovable integration branch and test its UI with real sign-in, refresh, logout and role accounts. SQL role simulation is NOT an Auth/browser E2E test.
2. Validate the complete assessment-to-PDI UI journey and displayed results; current new regression tests cycle creation, not full assessment completion.
3. Review PR #25 CI before merge; database migrations already applied and recorded by matching hosted version numbers. Do not reapply hosted migrations or merge visual branches blindly.
4. Validate emails/invites using approved test inboxes; do not send to customers.

No claim that the entire SaaS is ready for production is made at this checkpoint.
