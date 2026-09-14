type AuthUser = {
  id: string;
  email?: string;
  user_metadata?: Record<string, unknown>;
};

export type SupabaseSession = {
  access_token: string;
  refresh_token?: string;
  expires_at?: number;
  token_type?: string;
  user: AuthUser;
};

export type AuthResponse = {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  token_type?: string;
  user?: AuthUser;
  msg?: string;
  message?: string;
  hint?: string;
  error_description?: string;
};

const viteEnv = (import.meta as ImportMeta & { env?: Record<string, unknown> }).env ?? {};
const supabaseUrl = (viteEnv.VITE_SUPABASE_URL as string | undefined)?.replace(/\/$/, "");
const supabaseAnonKey = viteEnv.VITE_SUPABASE_ANON_KEY as string | undefined;
export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);
function getErrorMessage(body: AuthResponse): string { return body.error_description ?? body.message ?? body.msg ?? body.hint ?? "Não foi possível concluir a operação."; }
async function authRequest(path: string, payload: Record<string, unknown>): Promise<AuthResponse> { if (!isSupabaseConfigured) throw new Error("O ambiente ainda não está conectado ao Supabase."); const response = await fetch(`${supabaseUrl}/auth/v1/${path}`, { method: "POST", headers: { apikey: supabaseAnonKey!, "Content-Type": "application/json" }, body: JSON.stringify(payload) }); const body = (await response.json()) as AuthResponse; if (!response.ok) throw new Error(getErrorMessage(body)); return body; }
export function sessionFromAuth(body: AuthResponse, fallbackRefreshToken?: string): SupabaseSession {
  if (!body.access_token || !body.user) throw new Error("O login foi concluído, mas a sessão não foi retornada.");
  return { access_token: body.access_token, refresh_token: body.refresh_token ?? fallbackRefreshToken, expires_at: body.expires_in ? Math.floor(Date.now() / 1000) + body.expires_in : undefined, token_type: body.token_type ?? "bearer", user: body.user };
}
export async function signUp(email: string, password: string, fullName: string): Promise<AuthResponse> { return authRequest("signup", { email, password, data: { full_name: fullName } }); }
export async function signIn(email: string, password: string): Promise<SupabaseSession> { return sessionFromAuth(await authRequest("token?grant_type=password", { email, password })); }
type LocalStorageLike = { getItem: (key: string) => string | null; setItem: (key: string, value: string) => void; removeItem: (key: string) => void };
function localStorageOrNull(): LocalStorageLike | null { return (globalThis as typeof globalThis & { window?: { localStorage?: LocalStorageLike } }).window?.localStorage ?? null; }
export function sessionNeedsRefresh(session: SupabaseSession, now = Date.now()): boolean { return Boolean(session.refresh_token && (!session.expires_at || session.expires_at <= Math.floor(now / 1000) + 60)); }
export async function refreshSession(session: SupabaseSession): Promise<SupabaseSession> { if (!session.refresh_token) return session; return sessionFromAuth(await authRequest("token?grant_type=refresh_token", { refresh_token: session.refresh_token }), session.refresh_token); }
export async function restoreSession(): Promise<SupabaseSession | null> { const storage = localStorageOrNull(); if (!storage) return null; try { const raw = storage.getItem("youb-session"); if (!raw) return null; const saved = JSON.parse(raw) as SupabaseSession; const fresh = sessionNeedsRefresh(saved) ? await refreshSession(saved) : saved; storage.setItem("youb-session", JSON.stringify(fresh)); return fresh; } catch { storage.removeItem("youb-session"); storage.removeItem("youb-organization"); return null; } }

export type EmployeeExperienceContext = { organization: { id: string; name: string; slug: string }; membership: { role: "admin_youb" | "diretoria" | "rh" | "gestor" | "colaborador" }; employee: { id: string; full_name: string; email?: string | null } | null; employeeId: string | null; capabilities: string[] };
export function commercialExperienceForRole(role: EmployeeExperienceContext["membership"]["role"]): "executive" | "employee" | "dashboard" { if (role === "diretoria") return "executive"; if (role === "colaborador") return "employee"; return "dashboard"; }
const roleCapabilities: Record<EmployeeExperienceContext["membership"]["role"], string[]> = { admin_youb: ["read:organization", "manage:organization", "read:intelligence"], diretoria: ["read:organization", "decide:intelligence", "read:published-knowledge"], rh: ["read:organization", "manage:people", "read:published-knowledge"], gestor: ["read:team-scope", "manage:team-scope", "read:published-knowledge"], colaborador: ["read:own-context", "read:published-knowledge"] };
export type OrganizationSummary = { id: string; name: string; slug: string };
export function resolveOrganizationSelection(organizations: readonly OrganizationSummary[], selectedId?: string): OrganizationSummary | null { if (selectedId) return organizations.find((item) => item.id === selectedId) ?? null; return organizations.length === 1 ? organizations[0] : null; }
export async function getMyOrganizations(session: SupabaseSession): Promise<OrganizationSummary[]> { if (!isSupabaseConfigured) return []; const headers = { apikey: supabaseAnonKey!, Authorization: `Bearer ${session.access_token}` }; const membershipResponse = await fetch(`${supabaseUrl}/rest/v1/memberships?select=organization_id&user_id=eq.${encodeURIComponent(session.user.id)}`, { headers }); if (!membershipResponse.ok) return []; const memberships = (await membershipResponse.json()) as Array<{ organization_id?: string }>; const ids = [...new Set(memberships.map((item) => item.organization_id).filter((id): id is string => Boolean(id)))]; if (!ids.length) return []; const organizationResponse = await fetch(`${supabaseUrl}/rest/v1/organizations?select=id,name,slug&id=in.(${ids.map(encodeURIComponent).join(",")})&order=name`, { headers }); if (!organizationResponse.ok) return []; const organizations = (await organizationResponse.json()) as Array<{ id?: string; name?: string; slug?: string }>; return organizations.filter((item): item is OrganizationSummary => Boolean(item.id && item.name && item.slug)).map((item) => ({ id: item.id, name: item.name, slug: item.slug })); }
export async function getEmployeeExperienceContext(session: SupabaseSession, organizationId?: string): Promise<EmployeeExperienceContext | null> { if (!isSupabaseConfigured) return null; const headers = { apikey: supabaseAnonKey!, Authorization: `Bearer ${session.access_token}` }; const organizationFilter = organizationId ? `&organization_id=eq.${encodeURIComponent(organizationId)}` : ""; const membershipResponse = await fetch(`${supabaseUrl}/rest/v1/memberships?select=organization_id,role&user_id=eq.${encodeURIComponent(session.user.id)}${organizationFilter}&limit=1`, { headers }); if (!membershipResponse.ok) return null; const memberships = (await membershipResponse.json()) as Array<{ organization_id?: string; role?: EmployeeExperienceContext["membership"]["role"] }>; const membership = memberships[0]; if (!membership?.organization_id || !membership.role || !(membership.role in roleCapabilities)) return null; const organizationResponse = await fetch(`${supabaseUrl}/rest/v1/organizations?select=id,name,slug&id=eq.${encodeURIComponent(membership.organization_id)}&limit=1`, { headers }); if (!organizationResponse.ok) return null; const organizations = (await organizationResponse.json()) as Array<{ id?: string; name?: string; slug?: string }>; const organization = organizations[0]; if (!organization?.id || !organization.name || !organization.slug) return null; const employeeResponse = await fetch(`${supabaseUrl}/rest/v1/employees?select=id,full_name,email&organization_id=eq.${encodeURIComponent(organization.id)}&auth_user_id=eq.${encodeURIComponent(session.user.id)}&limit=1`, { headers }); const employees = employeeResponse.ok ? (await employeeResponse.json()) as Array<{ id?: string; full_name?: string; email?: string | null }> : []; const employee = employees[0]?.id && employees[0].full_name ? { id: employees[0].id, full_name: employees[0].full_name, email: employees[0].email } : null; return { organization: { id: organization.id, name: organization.name, slug: organization.slug }, membership: { role: membership.role }, employee, employeeId: employee?.id ?? null, capabilities: roleCapabilities[membership.role] }; }

export function slugify(value: string): string { const normalized = value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); return normalized || "minha-empresa"; }
export async function createOrganization(session: SupabaseSession, name: string): Promise<{ id: string; name: string; slug: string }> { if (!isSupabaseConfigured) throw new Error("O ambiente ainda não está conectado ao Supabase."); const response = await fetch(`${supabaseUrl}/rest/v1/rpc/create_organization`, { method: "POST", headers: { apikey: supabaseAnonKey!, Authorization: `Bearer ${session.access_token}`, "Content-Type": "application/json", Prefer: "return=representation" }, body: JSON.stringify({ p_name: name, p_slug: slugify(name) }) }); const body = (await response.json()) as { id?: string; name?: string; slug?: string; message?: string; hint?: string }; if (!response.ok || !body.id || !body.name || !body.slug) throw new Error(getErrorMessage(body)); return { id: body.id, name: body.name, slug: body.slug }; }
export async function getMyOrganization(session: SupabaseSession): Promise<{ id: string; name: string; slug: string } | null> { const context = await getEmployeeExperienceContext(session); return context?.organization ?? null; }
