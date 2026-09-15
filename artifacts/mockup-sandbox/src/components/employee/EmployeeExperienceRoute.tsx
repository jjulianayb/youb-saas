import { useEffect, useState } from "react";
import EmployeeHome from "../mockups/EmployeeHome";
import { contextResultMessage, employeeLinkMessage, resolveEmployeeExperienceContext, restoreSession, type EmployeeExperienceContext, type SupabaseSession } from "../../lib/supabase";
import { readEmployeeHomeData } from "../../features/intelligence-core/service";
import type { EmployeeHomeContext } from "../mockups/EmployeeHome";

type RouteState = { session: SupabaseSession; context: EmployeeExperienceContext } | null;
async function safeSession(): Promise<SupabaseSession | null> { return restoreSession(); }
function displayName(session: SupabaseSession, context: EmployeeExperienceContext): string { return context.employee?.full_name || (typeof session.user.user_metadata?.full_name === "string" ? session.user.user_metadata.full_name : null) || session.user.email || "Usuário autenticado"; }
function selectedOrganizationId(): string | undefined { const raw = window.localStorage.getItem("youb-organization"); return raw ? (JSON.parse(raw) as { id?: string }).id : undefined; }

export default function EmployeeExperienceRoute() {
  const [state, setState] = useState<RouteState>(null); const [loading, setLoading] = useState(true); const [error, setError] = useState<string | null>(null); const [data, setData] = useState<Awaited<ReturnType<typeof readEmployeeHomeData>> | undefined>();
  useEffect(() => { let cancelled = false; void safeSession().then(async (session) => { if (!session) { setLoading(false); return; } try { const result = await resolveEmployeeExperienceContext(session, selectedOrganizationId()); if (cancelled) return; if (result.status !== "ready") { setError(contextResultMessage(result)); return; } if (result.context.employeeLinkStatus !== "linked") { setError(employeeLinkMessage(result.context.employeeLinkStatus)); return; } setState({ session, context: result.context }); setData(await readEmployeeHomeData({ session, organizationId: result.context.organization.id, employeeId: result.context.employeeId! })); } catch { if (!cancelled) setError("Não foi possível carregar o contexto da organização."); } finally { if (!cancelled) setLoading(false); } }).catch(() => { if (!cancelled) { setError("Não foi possível restaurar sua sessão."); setLoading(false); } }); return () => { cancelled = true; }; }, []);
  if (loading) return <RouteMessage title="Carregando sua jornada" detail="Estamos verificando sua organização, papel e vínculo de colaborador." />;
  if (error) return <RouteMessage title="Contexto pessoal indisponível" detail={error} />;
  if (!state) return <RouteMessage title="Acesse sua conta" detail="Entre na youB para visualizar sua jornada de colaborador." />;
  const name = displayName(state.session, state.context); const context: EmployeeHomeContext = { displayName: name, organizationName: state.context.organization.name, data, beeContext: { userName: name, organizationName: state.context.organization.name, role: state.context.membership.role, capabilities: state.context.capabilities, employeeLinked: true, screen: "employee-home" } };
  return <EmployeeHome context={context} />;
}
function RouteMessage({ title, detail }: { title: string; detail: string }) { return <main className="flex min-h-screen items-center justify-center bg-background px-5 text-foreground"><section className="max-w-md rounded-3xl border border-border bg-card p-8 text-center shadow-sm"><h1 className="text-xl font-bold">{title}</h1><p className="mt-3 text-sm leading-6 text-muted-foreground">{detail}</p></section></main>; }
