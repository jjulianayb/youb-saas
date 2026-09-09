import { useEffect, useState, type ReactNode } from "react";
import { getEmployeeExperienceContext, type EmployeeExperienceContext, type SupabaseSession } from "../../lib/supabase";
import Dashboard from "../mockups/Dashboard";
import EmployeeExperienceRoute from "./EmployeeExperienceRoute";
import ExecutiveHomeRoute from "./ExecutiveHomeRoute";
import { appPath } from "../../lib/app-paths";

function safeSession(): SupabaseSession | null { try { const raw = window.localStorage.getItem("youb-session"); return raw ? JSON.parse(raw) as SupabaseSession : null; } catch { return null; } }
function Message({ title, detail, action }: { title: string; detail: string; action?: ReactNode }) { return <main className="flex min-h-screen items-center justify-center bg-[var(--youb-surface)] px-5 text-[var(--youb-ink)]"><section className="max-w-md rounded-3xl border border-slate-200 bg-white p-8 text-center shadow-sm"><div className="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-[var(--youb-navy)] text-lg font-extrabold text-white">B</div><h1 className="mt-5 text-xl font-bold">{title}</h1><p className="mt-3 text-sm leading-6 text-slate-500">{detail}</p>{action}</section></main>; }

export default function CommercialExperienceRoute() {
  const [session, setSession] = useState<SupabaseSession | null>(null); const [context, setContext] = useState<EmployeeExperienceContext | null>(null); const [loading, setLoading] = useState(true); const [error, setError] = useState<string | null>(null);
  useEffect(() => { const saved = safeSession(); if (!saved) { setLoading(false); return; } void getEmployeeExperienceContext(saved).then((next) => { if (!next) setError("Não foi possível identificar a organização e o papel deste acesso."); else { setSession(saved); setContext(next); } }).catch(() => setError("Não foi possível carregar a experiência comercial agora.")).finally(() => setLoading(false)); }, []);
  if (loading) return <Message title="Preparando sua experiência" detail="Estamos reunindo a jornada correspondente ao seu papel." />;
  if (error) return <Message title="Experiência indisponível" detail={error} />;
  if (!session || !context) return <Message title="Acesse sua conta" detail="Entre na youB para abrir a Commercial V1." action={<a className="mt-5 inline-flex rounded-full bg-[var(--youb-navy)] px-4 py-2 text-sm font-bold text-white" href={appPath("/preview/Onboarding")}>Abrir acesso</a>} />;
  if (context.membership.role === "diretoria") return <ExecutiveHomeRoute />;
  if (context.membership.role === "colaborador") return <EmployeeExperienceRoute />;
  return <Dashboard session={session} organization={context.organization} onLogout={() => { window.localStorage.removeItem("youb-session"); window.localStorage.removeItem("youb-organization"); window.location.href = appPath("/preview/Onboarding"); }} />;
}
