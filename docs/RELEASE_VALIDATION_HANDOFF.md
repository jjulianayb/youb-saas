# Release validation checkpoint

This checkpoint covers the existing youB SaaS only. No new Supabase project, paid service, Commercial Experience, or hosted test fixture was created.

## Corrigido e validado localmente/CI
- Account-to-employee onboarding now uses the existing flow: the employee creates Auth first, then an authorized admin_youb/diretoria links the same email to one tenant and assigns an existing role. Cross-tenant, ambiguous, duplicate, and invalid-role links are rejected by the RPC.
- Organization selection and employee context fail closed for multiple organizations or ambiguous memberships; a saved organization is accepted only if it is in the authenticated membership list.
- PR #26 merged the onboarding correction at `664d568efcf6d7dad952646aecddc5649a9f1ed7`.
- PR #27 merged the audited RPC ACL/search_path/PDI hardening and executable regression coverage at `65a2dc1f177fa1c896cc526ab57c057fc4ad6fa3`. The required GitHub build passed, including workspace build, Bee/classic access tests, migrations, SQL/RLS suites, onboarding membership coverage, and RPC security coverage.

## Validado hospedado, somente leitura
- Existing project `youB Multiempresa` (`eqyzswhxjzzzwtwnenur`) is active/healthy. The PR #25 security migrations are present; the 22 privileged RPC ACL checks and four snapshot search_path checks returned zero violations.
- The onboarding membership migration is **not** applied to the hosted project yet: `public.link_organization_user(...)` is absent. No hosted data was written during this checkpoint.
- `public.rls_auto_enable()` remains an observed platform event-trigger function (`RETURNS event_trigger`, attached to `ensure_rls`), not a normal business RPC; it was not changed.

## Not proven hosted
- No real Auth signup/login, session restore, logout, multi-role browser journey, or end-to-end empty-state acceptance was submitted against the current production-like data. No disposable hosted environment is available, and no real account was created.

## Release decision
The code and CI gates are closed, but the hosted environment is not fully release-closed until the onboarding migration is explicitly authorized and applied to the existing project, followed by a controlled acceptance check. No claim of whole-SaaS production readiness is made here.
