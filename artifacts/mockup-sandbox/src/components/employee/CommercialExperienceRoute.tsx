import { useEffect, useState, type ReactNode } from "react";
import { commercialExperienceForRole, contextResultMessage, employeeLinkMessage, requiresEmployeeLink, resolveEmployeeExperienceContext, restoreSession, type EmployeeExperienceContext, type SupabaseSession } from "../../lib/supabase";
import Dashboard from "../mockups/Dashboard";
import EmployeeExperienceRoute from "./EmployeeExperienceRoute";
import ExecutiveHomeRoute from "./ExecutiveHomeRoute";
import { appPath } from "../../lib/app-paths";

async function safeSession(): Promise<SupabaseSession | null> { return restoreSession(); }
function Message({ title, detail, action }: { title: string; detail: string; action?: ReactNode }) { return <main className="flex min-h-screen items-center justify-center bg-[var(--youb-surface)] px-5 text-[var(--youb-ink)]"><section className="max-w-md rounded-3xl border border-slate-200 bg-white p-8 text-center shadow-sm"><div className="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-[var(--youb-navy)] text-lg font-extrabold text-white">B</div><h1 className="mt-5 text-xl font-bold">{title}</h1><p className="mt-3 text-sm leading-6 text-slate-500">{detail}</p>{action}</section></main>; }

export default function CommercialExperienceRoute() {
  const [session, setSession] = useState<SupabaseSession | null>(null); const [context, setContext] = useState<EmployeeExperienceContext | null>(null); const [loading, setLoading] = useState(true); const [error, setError] = useState<string | null>(null);
  useEffect(() => { let cancelled = false; void safeSession().then(async (saved) => { if (!saved) { setLoading(false); return; } try { const rawOrganization = window.localStorage.getItem("youb-organization"); const selectedOrganizationId = rawOrganization ? (JSON.parse(rawOrganization) as { id?: string }).id : undefined; const result = await resolveEmployeeExperienceContext(saved, selectedOrganizationId); if (cancelled) return; if (result.status !== "ready") setError(contextResultMessage(result)); else { setSession(saved); setContext(result.context); } } catch { if (!cancelled) setError("Não foi possível carregar o contexto autorizado agora."); } finally { if (!cancelled) setLoading(false); } }).catch(() => { if (!cancelled) { setError("Não foi possível restaurar sua sessão."); setLoading(false); } }); return () => { cancelled = true; }; }, []);
  if (loading) return <Message title="Preparando sua experiência" detail="Estamos reunindo apenas a organização e o papel autorizados para este acesso." />;
  if (error) return <Message title="Contexto indisponível" detail={error} action={<a className="mt-5 inline-flex rounded-full bg-[var(--youb-navy)] px-4 py-2 text-sm font-bold text-white" href={appPath("/preview/Onboarding")}>Escolher organização</a>} />;
  if (!session || !context) return <Message title="Acesse sua conta" detail="Entre na youB para abrir a Commercial V1." action={<a className="mt-5 inline-flex rounded-full bg-[var(--youb-navy)] px-4 py-2 text-sm font-bold text-white" href={appPath("/preview/Onboarding")}>Abrir acesso</a>} />;
  if (requiresEmployeeLink(context.membership.role) && context.employeeLinkStatus !== "linked") return <Message title="Vínculo de colaborador necessário" detail={employeeLinkMessage(context.employeeLinkStatus)} />;
  const experience = commercialExperienceForRole(context.membership.role);
  if (experience === "executive") return <ExecutiveHomeRoute />;
  if (experience === "employee") return <EmployeeExperienceRoute />;
  return <Dashboard session={session} organization={context.organization} onLogout={() => { window.localStorage.removeItem("youb-session"); window.localStorage.removeItem("youb-organization"); window.location.href = appPath("/preview/Onboarding"); }} />;
}
