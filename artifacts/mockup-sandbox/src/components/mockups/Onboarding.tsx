import { useEffect, useState } from "react";
import type { FormEvent } from "react";

import {
  createOrganization,
  getMyOrganization,
  getMyOrganizations,
  isSupabaseConfigured,
  resolveOrganizationSelection,
  restoreSession,
  sessionFromAuth,
  signIn,
  signUp,
  type SupabaseSession,
} from "../../lib/supabase";
import { appPath } from "../../lib/app-paths";
import type { OrganizationSummary } from "../../lib/supabase";
import Dashboard from "./Dashboard";

type Mode = "login" | "signup";
type Step = "access" | "organization" | "organization-select" | "done";

const inputClassName =
  "mt-2 w-full rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900 outline-none transition placeholder:text-slate-400 focus:border-blue-500 focus:ring-4 focus:ring-blue-100";

function friendlyError(error: unknown): string {
  if (!(error instanceof Error)) return "Não foi possível concluir agora. Tente novamente.";
  if (error.message.toLowerCase().includes("invalid login credentials")) {
    return "E-mail ou senha incorretos.";
  }
  if (error.message.toLowerCase().includes("email not confirmed")) {
    return "Confirme seu e-mail antes de entrar na plataforma.";
  }
  return error.message;
}

export default function Onboarding() {
  const [mode, setMode] = useState<Mode>("login");
  const [step, setStep] = useState<Step>("access");
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [organizationName, setOrganizationName] = useState("");
  const [session, setSession] = useState<SupabaseSession | null>(null);
  const [organization, setOrganization] = useState<OrganizationSummary | null>(null);
  const [organizations, setOrganizations] = useState<OrganizationSummary[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const restoredSession = await restoreSession();
      if (cancelled || !restoredSession) return;
      setSession(restoredSession);
      const availableOrganizations = await getMyOrganizations(restoredSession);
      if (cancelled) return;
      setOrganizations(availableOrganizations);
      if (availableOrganizations.length > 1) {
        setSelectedOrganizationId(availableOrganizations[0].id);
        setStep("organization-select");
        return;
      }
      const savedOrganization = window.localStorage.getItem("youb-organization");
      const existingOrganization = resolveOrganizationSelection(availableOrganizations) ?? (savedOrganization ? JSON.parse(savedOrganization) as OrganizationSummary : await getMyOrganization(restoredSession));
      if (cancelled || !existingOrganization) return;
      setOrganization(existingOrganization);
      window.localStorage.setItem("youb-organization", JSON.stringify(existingOrganization));
      window.location.href = appPath("/commercial");
    })();
    return () => { cancelled = true; };
  }, []);

  function resetFeedback() {
    setMessage(null);
    setError(null);
  }

  async function handleAccessSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    resetFeedback();
    setSubmitting(true);

    try {
      if (mode === "signup") {
        const response = await signUp(email.trim(), password, fullName.trim());
        if (!response.access_token || !response.user) {
          setMessage("Cadastro realizado. Confira seu e-mail para confirmar o acesso e depois entre aqui.");
          setMode("login");
          setPassword("");
          return;
        }
        const nextSession = sessionFromAuth(response);
        setSession(nextSession);
        window.localStorage.setItem("youb-session", JSON.stringify(nextSession));
        setStep("organization");
        return;
      }

      const authenticatedSession = await signIn(email.trim(), password);
      setSession(authenticatedSession);
      window.localStorage.setItem("youb-session", JSON.stringify(authenticatedSession));
      const availableOrganizations = await getMyOrganizations(authenticatedSession);
      setOrganizations(availableOrganizations);
      if (availableOrganizations.length > 1) {
        setSelectedOrganizationId(availableOrganizations[0].id);
        setStep("organization-select");
      } else if (resolveOrganizationSelection(availableOrganizations)) {
        const selectedOrganization = resolveOrganizationSelection(availableOrganizations)!;
        setOrganization(selectedOrganization);
        window.localStorage.setItem("youb-organization", JSON.stringify(selectedOrganization));
        window.location.href = appPath("/commercial");
      } else {
        setStep("organization");
      }
    } catch (accessError) {
      setError(friendlyError(accessError));
    } finally {
      setSubmitting(false);
    }
  }

  function handleOrganizationSelect(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const selected = resolveOrganizationSelection(organizations, selectedOrganizationId);
    if (!selected) return;
    setOrganization(selected);
    window.localStorage.setItem("youb-organization", JSON.stringify(selected));
    window.location.href = appPath("/commercial");
  }

  async function handleOrganizationSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!session) return;
    resetFeedback();
    setSubmitting(true);

    try {
      const createdOrganization = await createOrganization(session, organizationName.trim());
      setOrganization(createdOrganization);
      window.localStorage.setItem("youb-organization", JSON.stringify(createdOrganization));
      window.location.href = appPath("/commercial");
    } catch (organizationError) {
      setError(friendlyError(organizationError));
    } finally {
      setSubmitting(false);
    }
  }

  if (step === "done" && organization && session) {
    return (
      <Dashboard
        session={session}
        organization={organization}
        onLogout={() => {
          window.localStorage.removeItem("youb-session");
          window.localStorage.removeItem("youb-organization");
          setSession(null);
          setOrganization(null);
          setStep("access");
          setPassword("");
        }}
      />
    );
  }

  return (
    <main className="min-h-screen bg-[#f5f8fc] px-5 py-10 text-slate-900 sm:px-8">
      <div className="mx-auto flex min-h-[calc(100vh-5rem)] max-w-5xl items-center justify-center">
        <section className="grid w-full overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-[0_20px_70px_rgba(30,58,110,0.12)] lg:grid-cols-[0.9fr_1.1fr]">
          <aside className="relative overflow-hidden bg-gradient-to-br from-[#102654] via-[#1e3a6e] to-[#315da0] p-8 text-white sm:p-12">
            <div className="absolute -right-20 -top-20 h-64 w-64 rounded-full bg-white/10" />
            <div className="relative">
              <div className="mb-16 flex items-baseline gap-1">
                <span className="text-3xl font-light tracking-tight text-white/80">you</span>
                <span className="text-4xl font-extrabold tracking-tight">B</span>
              </div>
              <p className="mb-3 text-xs font-bold uppercase tracking-[0.2em] text-blue-100/70">Gestão de pessoas</p>
              <h1 className="max-w-sm text-3xl font-extrabold leading-tight sm:text-4xl">
                Comece a transformar o desenvolvimento da sua equipe.
              </h1>
              <p className="mt-5 max-w-sm text-sm leading-7 text-blue-100/80">
                Um espaço seguro para avaliações, feedbacks, PDIs e decisões melhores sobre pessoas.
              </p>
              <div className="mt-12 space-y-4 text-sm text-blue-50/90">
                <p>✓ Estrutura por empresa desde o primeiro acesso</p>
                <p>✓ Dados isolados com segurança</p>
                <p>✓ Onboarding simples e sem planilhas</p>
              </div>
            </div>
          </aside>

          <div className="p-7 sm:p-12">
            <div className="mb-8 flex items-center justify-between">
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-600">Primeiro acesso</p>
                <h2 className="mt-2 text-2xl font-bold text-slate-900">
                  {step === "access" && (mode === "login" ? "Entre na sua conta" : "Crie sua conta")}
                  {step === "organization" && "Configure sua empresa"}
                  {step === "organization-select" && "Escolha sua empresa"}
                  {step === "done" && "Tudo pronto"}
                </h2>
              </div>
              <div className="rounded-full bg-blue-50 px-3 py-1 text-xs font-semibold text-blue-700">
                {step === "access" ? "1 de 2" : step === "organization-select" ? "Seleção" : step === "organization" ? "2 de 2" : "Concluído"}
              </div>
            </div>

            {!isSupabaseConfigured && step !== "done" && (
              <div className="mb-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm leading-6 text-amber-900">
                Pré-visualização: defina <strong>VITE_SUPABASE_URL</strong> e <strong>VITE_SUPABASE_ANON_KEY</strong> no ambiente da aplicação para ativar o acesso.
              </div>
            )}

            {message && <div className="mb-6 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm leading-6 text-emerald-800">{message}</div>}
            {error && <div className="mb-6 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm leading-6 text-red-800">{error}</div>}

            {step === "access" && (
              <form className="space-y-5" onSubmit={handleAccessSubmit}>
                {mode === "signup" && (
                  <label className="block text-sm font-semibold text-slate-700">
                    Seu nome
                    <input className={inputClassName} value={fullName} onChange={(event) => setFullName(event.target.value)} placeholder="Como você quer ser chamada?" required />
                  </label>
                )}
                <label className="block text-sm font-semibold text-slate-700">
                  E-mail corporativo
                  <input className={inputClassName} type="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="voce@empresa.com.br" required />
                </label>
                <label className="block text-sm font-semibold text-slate-700">
                  Senha
                  <input className={inputClassName} type="password" minLength={8} value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Mínimo de 8 caracteres" required />
                </label>
                <button className="w-full rounded-xl bg-[#1e3a6e] px-5 py-3.5 text-sm font-bold text-white transition hover:bg-[#152c57] disabled:cursor-not-allowed disabled:opacity-50" disabled={!isSupabaseConfigured || submitting} type="submit">
                  {submitting ? "Aguarde..." : mode === "login" ? "Entrar na youB" : "Criar minha conta"}
                </button>
                <p className="text-center text-sm text-slate-500">
                  {mode === "login" ? "Ainda não tem uma conta?" : "Já tem uma conta?"}{" "}
                  <button className="font-bold text-blue-700 hover:underline" type="button" onClick={() => { resetFeedback(); setMode(mode === "login" ? "signup" : "login"); }}>
                    {mode === "login" ? "Criar agora" : "Entrar"}
                  </button>
                </p>
              </form>
            )}

            {step === "organization-select" && (
              <form className="space-y-5" onSubmit={handleOrganizationSelect}>
                <p className="text-sm leading-7 text-slate-500">Seu acesso pertence a mais de uma empresa. Escolha qual espaço deseja abrir agora.</p>
                <label className="block text-sm font-semibold text-slate-700">Empresa<select className={inputClassName} value={selectedOrganizationId} onChange={(event) => setSelectedOrganizationId(event.target.value)} required><option value="">Selecione</option>{organizations.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
                <button className="w-full rounded-xl bg-[#1e3a6e] px-5 py-3.5 text-sm font-bold text-white transition hover:bg-[#152c57]" type="submit">Abrir empresa</button>
              </form>
            )}

            {step === "organization" && (
              <form className="space-y-5" onSubmit={handleOrganizationSubmit}>
                <p className="text-sm leading-7 text-slate-500">Vamos criar o espaço da sua empresa. Você poderá convidar o time e completar os dados depois.</p>
                <label className="block text-sm font-semibold text-slate-700">
                  Nome da empresa
                  <input className={inputClassName} value={organizationName} onChange={(event) => setOrganizationName(event.target.value)} placeholder="Ex.: youB Tecnologia" required />
                </label>
                <button className="w-full rounded-xl bg-[#1e3a6e] px-5 py-3.5 text-sm font-bold text-white transition hover:bg-[#152c57] disabled:cursor-not-allowed disabled:opacity-50" disabled={submitting} type="submit">
                  {submitting ? "Criando espaço..." : "Criar espaço da empresa"}
                </button>
              </form>
            )}

            {step === "done" && organization && (
              <div className="space-y-6">
                <div className="rounded-2xl bg-emerald-50 p-6 text-center">
                  <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-emerald-500 text-2xl text-white">✓</div>
                  <h3 className="text-lg font-bold text-emerald-900">Empresa criada com sucesso</h3>
                  <p className="mt-2 text-sm leading-6 text-emerald-800">{organization.name} já está pronta para receber sua equipe.</p>
                </div>
                <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
                  Identificador do espaço: <strong className="text-slate-900">{organization.slug}</strong>
                </div>
                <div>
                  <p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-600">Painel inicial</p>
                  <p className="mt-2 text-sm leading-6 text-slate-500">A estrutura da sua empresa está pronta. Os próximos módulos serão ativados aqui.</p>
                  <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
                    {["Avaliações", "Feedbacks", "PDIs", "Ciclos"].map((item) => (
                      <div key={item} className="rounded-xl border border-slate-200 bg-white p-3 text-center text-xs font-semibold text-slate-600">{item}<span className="mt-2 block text-[10px] font-normal text-slate-400">Em breve</span></div>
                    ))}
                  </div>
                </div>
                <button className="w-full rounded-xl border border-[#1e3a6e] px-5 py-3.5 text-sm font-bold text-[#1e3a6e] transition hover:bg-blue-50" type="button" onClick={() => { window.localStorage.removeItem("youb-session"); window.localStorage.removeItem("youb-organization"); setSession(null); setOrganization(null); setStep("access"); setPassword(""); }}>
                  Sair da demonstração
                </button>
              </div>
            )}
          </div>
        </section>
      </div>
    </main>
  );
}

