type AuthUser = {
  id: string;
  email?: string;
  user_metadata?: Record<string, unknown>;
};

export type SupabaseSession = {
  access_token: string;
  refresh_token?: string;
  user: AuthUser;
};

type AuthResponse = {
  access_token?: string;
  refresh_token?: string;
  user?: AuthUser;
  msg?: string;
  message?: string;
  hint?: string;
  error_description?: string;
};

const supabaseUrl = (import.meta.env.VITE_SUPABASE_URL as string | undefined)?.replace(/\/$/, "");
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);
function getErrorMessage(body: AuthResponse): string { return body.error_description ?? body.message ?? body.msg ?? body.hint ?? "Não foi possível concluir a operação."; }
async function authRequest(path: string, payload: Record<string, unknown>): Promise<AuthResponse> { if (!isSupabaseConfigured) throw new Error("O ambiente ainda não está conectado ao Supabase."); const response = await fetch(`${supabaseUrl}/auth/v1/${path}`, { method: "POST", headers: { apikey: supabaseAnonKey!, "Content-Type": "application/json" }, body: JSON.stringify(payload) }); const body = (await response.json()) as AuthResponse; if (!response.ok) throw new Error(getErrorMessage(body)); return body; }
export async function signUp(email: string, password: string, fullName: string): Promise<AuthResponse> { return authRequest("signup", { email, password, data: { full_name: fullName } }); }
export async function signIn(email: string, password: string): Promise<SupabaseSession> { const body = await authRequest("token?grant_type=password", { email, password }); if (!body.access_token || !body.user) throw new Error("O login foi concluído, mas a sessão não foi retornada."); return { access_token: body.access_token, refresh_token: body.refresh_token, user: body.user }; }

export type EmployeeExperienceContext = { organization: { id: string; name: string; slug: string }; membership: { role: "admin_youb" | "diretoria" | "rh" | "gestor" | "colaborador" }; employee: { id: string; full_name: string; email?: string | null } | null; employeeId: string | null; capabilities: string[] };
const roleCapabilities: Record<EmployeeExperienceContext["membership"]["role"], string[]> = { admin_youb: ["read:organization", "manage:organization", "read:intelligence"], diretoria: ["read:organization", "decide:intelligence", "read:published-knowledge"], rh: ["read:organization", "manage:people", "read:published-knowledge"], gestor: ["read:team-scope", "manage:team-scope", "read:published-knowledge"], colaborador: ["read:own-context", "read:published-knowledge"] };
export async function getEmployeeExperienceContext(session: SupabaseSession): Promise<EmployeeExperienceContext | null> { if (!isSupabaseConfigured) return null; const headers = { apikey: supabaseAnonKey!, Authorization: `Bearer ${session.access_token}` }; const membershipResponse = await fetch(`${supabaseUrl}/rest/v1/memberships?select=organization_id,role&user_id=eq.${encodeURIComponent(session.user.id)}&limit=1`, { headers }); if (!membershipResponse.ok) return null; const memberships = (await membershipResponse.json()) as Array<{ organization_id?: string; role?: EmployeeExperienceContext["membership"]["role"] }>; const membership = memberships[0]; if (!membership?.organization_id || !membership.role || !(membership.role in roleCapabilities)) return null; const organizationResponse = await fetch(`${supabaseUrl}/rest/v1/organizations?select=id,name,slug&id=eq.${encodeURIComponent(membership.organization_id)}&limit=1`, { headers }); if (!organizationResponse.ok) return null; const organizations = (await organizationResponse.json()) as Array<{ id?: string; name?: string; slug?: string }>; const organization = organizations[0]; if (!organization?.id || !organization.name || !organization.slug) return null; const employeeResponse = await fetch(`${supabaseUrl}/rest/v1/employees?select=id,full_name,email&organization_id=eq.${encodeURIComponent(organization.id)}&auth_user_id=eq.${encodeURIComponent(session.user.id)}&limit=1`, { headers }); const employees = employeeResponse.ok ? (await employeeResponse.json()) as Array<{ id?: string; full_name?: string; email?: string | null }> : []; const employee = employees[0]?.id && employees[0].full_name ? { id: employees[0].id, full_name: employees[0].full_name, email: employees[0].email } : null; return { organization: { id: organization.id, name: organization.name, slug: organization.slug }, membership: { role: membership.role }, employee, employeeId: employee?.id ?? null, capabilities: roleCapabilities[membership.role] }; }

export function slugify(value: string): string { const normalized = value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); return normalized || "minha-empresa"; }
export async function createOrganization(session: SupabaseSession, name: string): Promise<{ id: string; name: string; slug: string }> { if (!isSupabaseConfigured) throw new Error("O ambiente ainda não está conectado ao Supabase."); const response = await fetch(`${supabaseUrl}/rest/v1/rpc/create_organization`, { method: "POST", headers: { apikey: supabaseAnonKey!, Authorization: `Bearer ${session.access_token}`, "Content-Type": "application/json", Prefer: "return=representation" }, body: JSON.stringify({ p_name: name, p_slug: slugify(name) }) }); const body = (await response.json()) as { id?: string; name?: string; slug?: string; message?: string; hint?: string }; if (!response.ok || !body.id || !body.name || !body.slug) throw new Error(getErrorMessage(body)); return { id: body.id, name: body.name, slug: body.slug }; }
export async function getMyOrganization(session: SupabaseSession): Promise<{ id: string; name: string; slug: string } | null> { const context = await getEmployeeExperienceContext(session); return context?.organization ?? null; }
