import { useEffect, useState } from "react";
import EmployeeHome from "../mockups/EmployeeHome";
import { getEmployeeExperienceContext, restoreSession, type EmployeeExperienceContext, type SupabaseSession } from "../../lib/supabase";
import { readEmployeeHomeData } from "../../features/intelligence-core/service";
import type { EmployeeHomeContext } from "../mockups/EmployeeHome";

type RouteState = { session: SupabaseSession; context: EmployeeExperienceContext } | null;
async function safeSession(): Promise<SupabaseSession | null> { return restoreSession(); }
function displayName(session: SupabaseSession, context: EmployeeExperienceContext): string { return context.employee?.full_name || (typeof session.user.user_metadata?.full_name === "string" ? session.user.user_metadata.full_name : null) || session.user.email || "Usuário autenticado"; }

export default function EmployeeExperienceRoute() {
  const [state, setState] = useState<RouteState>(null); const [loading, setLoading] = useState(true); const [error, setError] = useState<string | null>(null); const [data, setData] = useState<Awaited<ReturnType<typeof readEmployeeHomeData>> | undefined>();
  useEffect(() => { void safeSession().then((session) => { if (!session) { setLoading(false); return; } const rawOrganization = window.localStorage.getItem("youb-organization"); const organizationId = rawOrganization ? (JSON.parse(rawOrganization) as { id?: string }).id : undefined; return getEmployeeExperienceContext(session, organizationId).then(async (context) => { if (!context) { setError("O contexto autenticado ainda não foi carregado."); return; } setState({ session, context }); if (context.employeeId) setData(await readEmployeeHomeData({ session, organizationId: context.organization.id, employeeId: context.employeeId })); }).catch(() => setError("Não foi possível carregar o contexto da organização.")).finally(() => setLoading(false)); }).catch(() => { setError("Não foi possível restaurar sua sessão."); setLoading(false); }); }, []);
  if (loading) return <RouteMessage title="Carregando sua jornada" detail="Estamos verificando sua organização, perfil e permissões disponíveis." />;
  if (error) return <RouteMessage title="Contexto indisponível" detail={error} />;
  if (!state) return <RouteMessage title="Acesse sua conta" detail="Entre na youB para visualizar sua jornada de colaborador." />;
  const name = displayName(state.session, state.context); const context: EmployeeHomeContext = { displayName: name, organizationName: state.context.organization.name, data, beeContext: { userName: name, organizationName: state.context.organization.name, role: state.context.membership.role, capabilities: state.context.capabilities, employeeLinked: Boolean(state.context.employeeId), screen: "employee-home" } };
  return <EmployeeHome context={context} />;
}
function RouteMessage({ title, detail }: { title: string; detail: string }) { return <main className="flex min-h-screen items-center justify-center bg-background px-5 text-foreground"><section className="max-w-md rounded-3xl border border-border bg-card p-8 text-center shadow-sm"><h1 className="text-xl font-bold">{title}</h1><p className="mt-3 text-sm leading-6 text-muted-foreground">{detail}</p></section></main>; }
