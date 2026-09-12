import { useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import type { SupabaseSession } from "../../lib/supabase";
import { pdiRpc } from "../../features/pdi-development/service";

type Organization = { id: string; name: string };
type Employee = { id: string; full_name: string; manager_employee_id?: string | null };
type Pdi = { id: string; objective: string; status: string; due_date?: string | null; employee_id: string; version?: number | null };
type Objective = { id: string; title: string; description?: string | null; success_criteria: string; responsible_employee_id?: string | null; due_date?: string | null; status: string; version: number };
type Action = { id: string; objective_id: string; title: string; responsible_employee_id: string; due_date?: string | null; status: string; blocker?: string | null; version: number };
type Checkin = { id: string; objective_id?: string | null; action_id?: string | null; checkin_at: string; progress_note: string; next_step?: string | null; blocker?: string | null; evidence_reference?: string | null };
type SourceLink = { id: string; source_kind: string; relationship_type?: string | null; safe_aggregate_score?: number | null; context_note?: string | null };
type AuditEvent = { id: string; event_type: string; created_at: string; reason?: string | null };

type Props = {
  session: SupabaseSession;
  organization: Organization;
  employees: Employee[];
  pdis: Pdi[];
  userRole: string;
  onRefresh: () => Promise<void> | void;
  onNotice: (message: string) => void;
  onError: (message: string) => void;
};

const supabaseUrl = (import.meta.env.VITE_SUPABASE_URL as string | undefined)?.replace(/\/$/, "");
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
const inputClassName = "mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none focus:border-blue-500 focus:ring-4 focus:ring-blue-100";
const buttonClassName = "rounded-xl bg-[#1e3a6e] px-4 py-2.5 text-sm font-bold text-white transition hover:bg-[#152c57] disabled:cursor-not-allowed disabled:opacity-50";
const secondaryButtonClassName = "rounded-xl border border-slate-200 px-4 py-2.5 text-sm font-bold text-slate-700 transition hover:border-blue-300 hover:bg-blue-50 disabled:cursor-not-allowed disabled:opacity-50";

async function rest<T>(session: SupabaseSession, path: string): Promise<T> {
  if (!supabaseUrl || !supabaseAnonKey) throw new Error("O ambiente ainda não está conectado ao Supabase.");
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}`, { headers: { apikey: supabaseAnonKey, Authorization: `Bearer ${session.access_token}` } });
  const body = await response.json().catch(() => null);
  if (!response.ok) throw new Error(body?.message ?? "Não foi possível carregar o PDI.");
  return body as T;
}

function dateLabel(value?: string | null): string { return value ? new Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "short", year: "numeric" }).format(new Date(`${value.slice(0, 10)}T12:00:00`)) : "Sem prazo"; }
function statusLabel(value: string): string { return ({ draft: "Rascunho", proposed: "Proposto", active: "Ativo", paused: "Pausado", completed: "Concluído", cancelled: "Cancelado", planned: "Planejada", in_progress: "Em andamento", blocked: "Bloqueada" } as Record<string, string>)[value] ?? value; }

export default function PdiDevelopment({ session, organization, employees, pdis, userRole, onRefresh, onNotice, onError }: Props) {
  const [selectedId, setSelectedId] = useState("");
  const [objectives, setObjectives] = useState<Objective[]>([]);
  const [actions, setActions] = useState<Action[]>([]);
  const [checkins, setCheckins] = useState<Checkin[]>([]);
  const [links, setLinks] = useState<SourceLink[]>([]);
  const [audit, setAudit] = useState<AuditEvent[]>([]);
  const [busy, setBusy] = useState(false);
  const [objectiveTitle, setObjectiveTitle] = useState("");
  const [successCriteria, setSuccessCriteria] = useState("");
  const [objectiveDue, setObjectiveDue] = useState("");
  const [actionTitle, setActionTitle] = useState("");
  const [actionObjective, setActionObjective] = useState("");
  const [actionDue, setActionDue] = useState("");
  const [actionResponsible, setActionResponsible] = useState("");
  const [progress, setProgress] = useState("");
  const [nextStep, setNextStep] = useState("");
  const [blocker, setBlocker] = useState("");
  const [evidenceReference, setEvidenceReference] = useState("");
  const [contextNote, setContextNote] = useState("");

  const selected = pdis.find((pdi) => pdi.id === (selectedId || pdis[0]?.id));
  const employeeNames = useMemo(() => new Map(employees.map((employee) => [employee.id, employee.full_name])), [employees]);
  const canControlLifecycle = userRole === "admin_youb" || userRole === "rh" || userRole === "gestor";

  async function loadDetail(pdiId: string) {
    if (!pdiId) return;
    try {
      const [nextObjectives, nextActions, nextCheckins, nextLinks, nextAudit] = await Promise.all([
        rest<Objective[]>(session, `pdi_objectives?select=id,title,description,success_criteria,responsible_employee_id,due_date,status,version&organization_id=eq.${organization.id}&pdi_id=eq.${pdiId}&order=created_at`),
        rest<Action[]>(session, `pdi_actions?select=id,objective_id,title,responsible_employee_id,due_date,status,blocker,version&organization_id=eq.${organization.id}&order=created_at`),
        rest<Checkin[]>(session, `pdi_checkins?select=id,objective_id,action_id,checkin_at,progress_note,next_step,blocker,evidence_reference&organization_id=eq.${organization.id}&pdi_id=eq.${pdiId}&order=checkin_at.desc`),
        rest<SourceLink[]>(session, `pdi_source_links?select=id,source_kind,relationship_type,safe_aggregate_score,context_note&organization_id=eq.${organization.id}&pdi_id=eq.${pdiId}&order=created_at.desc`),
        rest<AuditEvent[]>(session, `pdi_audit_events?select=id,event_type,created_at,reason&organization_id=eq.${organization.id}&entity_type=eq.pdi&entity_id=eq.${pdiId}&order=created_at.desc`),
      ]);
      setObjectives(nextObjectives); setActions(nextActions.filter((action) => nextObjectives.some((objective) => objective.id === action.objective_id))); setCheckins(nextCheckins); setLinks(nextLinks); setAudit(nextAudit);
      if (!actionObjective && nextObjectives[0]) setActionObjective(nextObjectives[0].id);
      if (!actionResponsible && selected) setActionResponsible(selected.employee_id);
    } catch (error) { onError(error instanceof Error ? error.message : "Não foi possível carregar o detalhe do PDI."); }
  }

  useEffect(() => { const id = selectedId || pdis[0]?.id || ""; if (id !== selectedId) setSelectedId(id); if (id) void loadDetail(id); }, [selectedId, pdis.length]);

  async function run(action: () => Promise<unknown>, success: string) {
    setBusy(true); onError("");
    try { await action(); onNotice(success); await onRefresh(); if (selected) await loadDetail(selected.id); } catch (error) { onError(error instanceof Error ? error.message : "Não foi possível atualizar o PDI."); } finally { setBusy(false); }
  }

  async function addObjective(event: FormEvent<HTMLFormElement>) { event.preventDefault(); if (!selected) return; await run(() => pdiRpc(session, "pdi_add_objective", { p_pdi_id: selected.id, p_title: objectiveTitle.trim(), p_description: null, p_success_criteria: successCriteria.trim(), p_responsible_employee_id: selected.employee_id, p_due_date: objectiveDue || null }), "Objetivo adicionado."); setObjectiveTitle(""); setSuccessCriteria(""); setObjectiveDue(""); }
  async function addAction(event: FormEvent<HTMLFormElement>) { event.preventDefault(); if (!actionObjective) return; await run(() => pdiRpc(session, "pdi_add_action", { p_objective_id: actionObjective, p_title: actionTitle.trim(), p_description: null, p_responsible_employee_id: actionResponsible || selected?.employee_id, p_due_date: actionDue || null }), "Ação adicionada."); setActionTitle(""); setActionDue(""); }
  async function addCheckin(event: FormEvent<HTMLFormElement>) { event.preventDefault(); if (!selected) return; await run(() => pdiRpc(session, "pdi_add_checkin", { p_pdi_id: selected.id, p_progress_note: progress.trim(), p_next_step: nextStep.trim() || null, p_blocker: blocker.trim() || null, p_evidence_reference: evidenceReference.trim() || null, p_objective_id: actionObjective || null, p_action_id: null }), "Check-in registrado."); setProgress(""); setNextStep(""); setBlocker(""); setEvidenceReference(""); }
  async function addManualLink(event: FormEvent<HTMLFormElement>) { event.preventDefault(); if (!selected) return; await run(() => pdiRpc(session, "pdi_add_source_link", { p_pdi_id: selected.id, p_source_kind: "manual", p_context_note: contextNote.trim(), p_objective_id: actionObjective || null }), "Contexto vinculado."); setContextNote(""); }

  if (!selected) return <div className="rounded-2xl border border-dashed border-slate-200 bg-white p-8 text-sm text-slate-500">Nenhum PDI disponível para esta população.</div>;
  const currentVersion = selected.version ?? 1;
  const objectiveById = new Map(objectives.map((objective) => [objective.id, objective]));

  return <div className="grid gap-6 lg:grid-cols-[0.34fr_0.66fr]">
    <aside className="space-y-3">
      <div className="rounded-2xl border border-slate-200 bg-white p-5"><p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-600">Jornada de desenvolvimento</p><h2 className="mt-2 text-lg font-extrabold">Planos</h2><p className="mt-1 text-sm text-slate-500">Contexto humano, ações e próximos passos.</p></div>
      {pdis.map((pdi) => <button key={pdi.id} type="button" onClick={() => setSelectedId(pdi.id)} className={`w-full rounded-2xl border p-4 text-left transition ${pdi.id === selected.id ? "border-blue-300 bg-blue-50" : "border-slate-200 bg-white hover:border-blue-200"}`}><p className="font-bold text-slate-800">{pdi.objective}</p><p className="mt-1 text-xs text-slate-500">{employeeNames.get(pdi.employee_id) ?? "Pessoa"} · {dateLabel(pdi.due_date)}</p><span className="mt-3 inline-flex rounded-full bg-slate-100 px-2.5 py-1 text-xs font-bold text-slate-600">{statusLabel(pdi.status)}</span></button>)}
    </aside>
    <section className="space-y-6">
      <div className="rounded-2xl border border-slate-200 bg-white p-6"><div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start"><div><p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-600">PDI · {employeeNames.get(selected.employee_id) ?? "Pessoa"}</p><h2 className="mt-2 text-2xl font-extrabold text-slate-900">{selected.objective}</h2><p className="mt-2 text-sm text-slate-500">Prazo: {dateLabel(selected.due_date)} · versão {currentVersion}</p></div><span className="rounded-full bg-blue-50 px-3 py-1 text-xs font-bold text-blue-700">{statusLabel(selected.status)}</span></div><div className="mt-5 flex flex-wrap gap-2">{selected.status === "draft" && <button className={buttonClassName} disabled={busy} onClick={() => void run(() => pdiRpc(session, "pdi_propose", { p_pdi_id: selected.id, p_expected_version: currentVersion }), "PDI proposto para revisão.")} type="button">Propor PDI</button>}{selected.status === "proposed" && canControlLifecycle && <button className={buttonClassName} disabled={busy} onClick={() => void run(() => pdiRpc(session, "pdi_activate", { p_pdi_id: selected.id, p_expected_version: currentVersion }), "PDI ativado.")} type="button">Ativar e aprovar</button>}{selected.status === "active" && canControlLifecycle && <><button className={secondaryButtonClassName} disabled={busy} onClick={() => void run(() => pdiRpc(session, "pdi_transition", { p_pdi_id: selected.id, p_next_status: "paused", p_expected_version: currentVersion, p_reason: "Pausa registrada na jornada." }), "PDI pausado.")} type="button">Pausar</button><button className={secondaryButtonClassName} disabled={busy} onClick={() => void run(() => pdiRpc(session, "pdi_transition", { p_pdi_id: selected.id, p_next_status: "cancelled", p_expected_version: currentVersion, p_reason: "Cancelamento confirmado." }), "PDI cancelado.")} type="button">Cancelar</button></>}{selected.status === "paused" && canControlLifecycle && <button className={buttonClassName} disabled={busy} onClick={() => void run(() => pdiRpc(session, "pdi_transition", { p_pdi_id: selected.id, p_next_status: "active", p_expected_version: currentVersion, p_reason: "Retomada confirmada." }), "PDI retomado.")} type="button">Retomar</button>}{selected.status === "active" && canControlLifecycle && <button className={buttonClassName} disabled={busy} onClick={() => void run(() => pdiRpc(session, "pdi_transition", { p_pdi_id: selected.id, p_next_status: "completed", p_expected_version: currentVersion, p_reason: "Conclusão confirmada por pessoa autorizada." }), "PDI concluído.")} type="button">Concluir</button>}</div></div>
      {(selected.status === "draft" || selected.status === "proposed" || selected.status === "active" || selected.status === "paused") && <div className="grid gap-6 xl:grid-cols-2"><form className="rounded-2xl border border-slate-200 bg-white p-5" onSubmit={addObjective}><h3 className="font-bold">Novo objetivo</h3><label className="mt-4 block text-xs font-bold text-slate-600">Objetivo<input className={inputClassName} value={objectiveTitle} onChange={(event) => setObjectiveTitle(event.target.value)} required /></label><label className="mt-3 block text-xs font-bold text-slate-600">Critério de sucesso<textarea className={inputClassName} rows={2} value={successCriteria} onChange={(event) => setSuccessCriteria(event.target.value)} required /></label><label className="mt-3 block text-xs font-bold text-slate-600">Prazo<input className={inputClassName} type="date" value={objectiveDue} onChange={(event) => setObjectiveDue(event.target.value)} /></label><button className={`${buttonClassName} mt-4`} disabled={busy} type="submit">Adicionar objetivo</button></form><form className="rounded-2xl border border-slate-200 bg-white p-5" onSubmit={addAction}><h3 className="font-bold">Nova ação</h3><label className="mt-4 block text-xs font-bold text-slate-600">Objetivo<select className={inputClassName} value={actionObjective} onChange={(event) => setActionObjective(event.target.value)} required><option value="">Selecione</option>{objectives.map((objective) => <option key={objective.id} value={objective.id}>{objective.title}</option>)}</select></label><label className="mt-3 block text-xs font-bold text-slate-600">Ação<input className={inputClassName} value={actionTitle} onChange={(event) => setActionTitle(event.target.value)} required /></label><label className="mt-3 block text-xs font-bold text-slate-600">Responsável<select className={inputClassName} value={actionResponsible || selected.employee_id} onChange={(event) => setActionResponsible(event.target.value)}>{employees.map((employee) => <option key={employee.id} value={employee.id}>{employee.full_name}</option>)}</select></label><label className="mt-3 block text-xs font-bold text-slate-600">Prazo<input className={inputClassName} type="date" value={actionDue} onChange={(event) => setActionDue(event.target.value)} /></label><button className={`${buttonClassName} mt-4`} disabled={busy} type="submit">Adicionar ação</button></form></div>}
      <div className="rounded-2xl border border-slate-200 bg-white p-6"><div className="flex items-center justify-between gap-3"><div><h3 className="font-bold">Objetivos e ações</h3><p className="mt-1 text-sm text-slate-500">Critérios e responsáveis ficam explícitos.</p></div><span className="text-xs font-bold text-slate-400">{objectives.length} objetivo(s)</span></div><div className="mt-5 space-y-4">{objectives.length === 0 ? <p className="text-sm text-slate-500">Ainda não há objetivos normalizados.</p> : objectives.map((objective) => <article className="rounded-xl border border-slate-200 p-4" key={objective.id}><div className="flex flex-wrap items-start justify-between gap-2"><div><h4 className="font-bold">{objective.title}</h4><p className="mt-1 text-sm text-slate-600">Sucesso: {objective.success_criteria}</p></div><span className="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-bold text-slate-600">{statusLabel(objective.status)}</span></div><div className="mt-3 space-y-2">{actions.filter((action) => action.objective_id === objective.id).map((action) => <div className="rounded-lg bg-slate-50 p-3 text-sm" key={action.id}><div className="flex justify-between gap-2"><span className="font-semibold">{action.title}</span><span className="text-xs text-slate-500">{statusLabel(action.status)}</span></div><p className="mt-1 text-xs text-slate-500">{employeeNames.get(action.responsible_employee_id) ?? "Responsável"} · {dateLabel(action.due_date)}</p>{action.blocker && <p className="mt-1 text-xs font-semibold text-amber-700">Bloqueio: {action.blocker}</p>}</div>)}</div></article>)}</div></div>
      <div className="grid gap-6 xl:grid-cols-2"><form className="rounded-2xl border border-slate-200 bg-white p-5" onSubmit={addCheckin}><h3 className="font-bold">Novo check-in</h3><textarea className={inputClassName} rows={3} value={progress} onChange={(event) => setProgress(event.target.value)} placeholder="O que avançou?" required /><input className={inputClassName} value={nextStep} onChange={(event) => setNextStep(event.target.value)} placeholder="Próximo passo" /><input className={inputClassName} value={blocker} onChange={(event) => setBlocker(event.target.value)} placeholder="Bloqueio, se houver" /><input className={inputClassName} value={evidenceReference} onChange={(event) => setEvidenceReference(event.target.value)} placeholder="Referência simples opcional" /><button className={`${buttonClassName} mt-3`} disabled={busy} type="submit">Registrar check-in</button></form><form className="rounded-2xl border border-slate-200 bg-white p-5" onSubmit={addManualLink}><h3 className="font-bold">Origem contextual segura</h3><p className="mt-1 text-xs leading-5 text-slate-500">Contexto manual não é diagnóstico nem prescrição.</p><textarea className={inputClassName} rows={4} value={contextNote} onChange={(event) => setContextNote(event.target.value)} placeholder="Contexto confirmado por uma pessoa" required /><button className={`${buttonClassName} mt-3`} disabled={busy} type="submit">Vincular contexto</button></form></div>
      <div className="grid gap-6 xl:grid-cols-2"><div className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-bold">Check-ins recentes</h3><div className="mt-4 space-y-3">{checkins.length === 0 ? <p className="text-sm text-slate-500">Nenhum check-in registrado.</p> : checkins.slice(0, 5).map((checkin) => <div className="rounded-lg bg-slate-50 p-3 text-sm" key={checkin.id}><p className="font-semibold">{checkin.progress_note}</p><p className="mt-1 text-xs text-slate-500">{dateLabel(checkin.checkin_at)}{checkin.next_step ? ` · Próximo: ${checkin.next_step}` : ""}</p>{checkin.blocker && <p className="mt-1 text-xs font-semibold text-amber-700">Bloqueio: {checkin.blocker}</p>}</div>)}</div></div><div className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-bold">Histórico essencial</h3><div className="mt-4 space-y-3">{audit.length === 0 ? <p className="text-sm text-slate-500">Nenhum evento ainda.</p> : audit.slice(0, 8).map((event) => <div className="flex justify-between gap-3 text-sm" key={event.id}><span className="font-semibold">{statusLabel(event.event_type)}</span><span className="text-xs text-slate-500">{dateLabel(event.created_at)}</span></div>)}<p className="mt-4 text-xs text-slate-400">{links.length} contexto(s) seguro(s) vinculado(s).</p></div></div></div>
    </section>
  </div>;
}
