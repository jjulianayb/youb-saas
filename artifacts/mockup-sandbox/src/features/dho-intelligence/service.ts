import type { SupabaseSession } from "../../lib/supabase";
import type { IntelligenceReadContext } from "../intelligence-core/types";

const env = (import.meta as ImportMeta & { env?: Record<string, unknown> }).env ?? {};
const supabaseUrl = (env.VITE_SUPABASE_URL as string | undefined)?.replace(/\/$/, "");
const supabaseAnonKey = env.VITE_SUPABASE_ANON_KEY as string | undefined;

export type DhoRole = "platform_admin" | "admin_youb" | "rh" | "diretoria" | "gestor" | "colaborador";
export type DhoPopulationMode = "tenant" | "direct_reports" | "self" | "aggregate_only" | "empty";
export type DhoContextKind = "ASSESSMENT" | "FEEDBACK_360" | "EVOLUTION" | "PDI";
export type DhoSourceKey = "assessment" | "feedback_360" | "pdi";
export type DhoSourceStatus = "available" | "empty" | "unavailable" | "aggregate_only";
export type DhoSourceAvailability = { source: DhoSourceKey; status: DhoSourceStatus; limitation?: string | null };
export type DhoProvenance = { entityType: "ASSESSMENT" | "FEEDBACK_360" | "PDI"; entityId: string; sourceType: string; sourceId?: string | null; relationship?: string | null };
export type DhoContextItem = {
  id: string;
  organizationId: string;
  employeeId: string;
  kind: DhoContextKind;
  title: string;
  summary: string;
  status?: string | null;
  context: Record<string, string | number | null>;
  unknowns: readonly string[];
  limitations: readonly string[];
  provenance: readonly DhoProvenance[];
};
export type DhoContextResult = { items: DhoContextItem[]; sources: DhoSourceAvailability[]; populationMode: DhoPopulationMode; populationCount: number };
export type DhoReadContext = IntelligenceReadContext & { role: DhoRole };
export const MAX_DHO_DIRECT_REPORTS = 25;
export type DhoRequestPlan = { mode: DhoPopulationMode; subjectIds: string[]; evolutionRpcCalls: number; bounded: boolean };

type Assessment = { id: string; organization_id: string; subject_employee_id: string; cycle_id: string; position_id?: string | null; status: string; completed_at?: string | null };
type AssessmentScore = { id: string; organization_id: string; assessment_id: string; competency_id: string; expected_level_snapshot: number; score?: number | null };
type EvolutionPoint = { source_type: string; cycle_id?: string | null; round_id?: string | null; competency_id: string; competency_name?: string | null; position_id?: string | null; expected_level_snapshot: number; score?: number | null; previous_score?: number | null; delta?: number | null; distance_to_expected?: number | null; completed_at?: string | null; employee_id?: string };
type Pdi = { id: string; organization_id: string; employee_id: string; objective: string; status: string; due_date?: string | null };
type PdiObjective = { id: string; organization_id: string; pdi_id: string; title: string; success_criteria: string; status: string; due_date?: string | null };
type PdiAction = { id: string; organization_id: string; objective_id: string; title: string; status: string; blocker?: string | null; due_date?: string | null };
type PdiCheckin = { id: string; organization_id: string; pdi_id: string; progress_note: string; next_step?: string | null; blocker?: string | null; checkin_at: string };

type LoadResult<T> = { items: T[]; status: "available" | "empty" | "unavailable"; limitation?: string };
type PopulationResult = { employeeIds: string[]; mode: DhoPopulationMode; available: boolean; limitation?: string };

function config(): { url: string; key: string } { if (!supabaseUrl || !supabaseAnonKey) throw new Error("O ambiente ainda não está conectado ao Supabase."); return { url: supabaseUrl, key: supabaseAnonKey }; }
function q(value: string): string { return encodeURIComponent(value); }
async function get<T>(session: SupabaseSession, table: string, select: string, filters: string): Promise<T[]> { const { url, key } = config(); const response = await fetch(`${url}/rest/v1/${table}?select=${q(select)}&${filters}`, { headers: { apikey: key, Authorization: `Bearer ${session.access_token}` } }); if (!response.ok) throw new Error(`DHO source ${table} is not available`); return (await response.json()) as T[]; }
async function rpc<T>(session: SupabaseSession, name: string, body: Record<string, unknown>): Promise<T[]> { const { url, key } = config(); const response = await fetch(`${url}/rest/v1/rpc/${name}`, { method: "POST", headers: { apikey: key, Authorization: `Bearer ${session.access_token}`, "Content-Type": "application/json" }, body: JSON.stringify(body) }); if (!response.ok) throw new Error(`DHO RPC ${name} is not available`); return (await response.json()) as T[]; }
async function load<T>(loader: () => Promise<T[]>): Promise<LoadResult<T>> { try { const items = await loader(); return { items, status: items.length ? "available" : "empty" }; } catch { return { items: [], status: "unavailable", limitation: "Fonte DHO indisponível ou sem autorização para esta leitura." }; } }
function inFilter(ids: readonly string[]): string { return ids.length ? `in.(${ids.map(q).join(",")})` : "eq.00000000-0000-0000-0000-000000000000"; }

export function dhoPopulationMode(role: DhoRole | null, employeeId: string | null): DhoPopulationMode {
  if (role === "colaborador") return employeeId ? "self" : "empty";
  if (role === "gestor") return employeeId ? "direct_reports" : "empty";
  if (role === "diretoria") return "aggregate_only";
  if (role === "admin_youb" || role === "rh" || role === "platform_admin") return "tenant";
  return "empty";
}
export function dhoPopulationPlan(role: DhoRole | null, employeeId: string | null): { mode: DhoPopulationMode; employeeId: string | null } { return { mode: dhoPopulationMode(role, employeeId), employeeId: role === "colaborador" ? employeeId : null }; }
export function dhoSubjectRequestPlan(role: DhoRole | null, employeeIds: readonly string[]): DhoRequestPlan {
  if (role === "admin_youb" || role === "rh" || role === "platform_admin" || role === "diretoria") return { mode: "aggregate_only", subjectIds: [], evolutionRpcCalls: 0, bounded: true };
  if (role === "gestor") { const subjectIds = [...employeeIds].slice(0, MAX_DHO_DIRECT_REPORTS); return { mode: "direct_reports", subjectIds, evolutionRpcCalls: subjectIds.length, bounded: employeeIds.length > MAX_DHO_DIRECT_REPORTS }; }
  if (role === "colaborador") { const subjectIds = [...employeeIds].slice(0, 1); return { mode: subjectIds.length ? "self" : "empty", subjectIds, evolutionRpcCalls: subjectIds.length, bounded: true }; }
  return { mode: "empty", subjectIds: [], evolutionRpcCalls: 0, bounded: true };
}
export function dhoSourceAvailability(statuses: Record<DhoSourceKey, DhoSourceStatus>, limitations: Partial<Record<DhoSourceKey, string>> = {}): DhoSourceAvailability[] { return (["assessment", "feedback_360", "pdi"] as DhoSourceKey[]).map((source) => ({ source, status: statuses[source], limitation: limitations[source] ?? null })); }

async function resolvePopulation(context: DhoReadContext): Promise<PopulationResult> {
  const mode = dhoPopulationMode(context.role, context.employeeId ?? null);
  if (mode === "aggregate_only") return { employeeIds: [], mode, available: true, limitation: "Diretoria recebe somente agregados seguros; contexto individual não é disponibilizado." };
  if (mode === "tenant") return { employeeIds: [], mode: "aggregate_only", available: true, limitation: "A Home Executiva recebe contexto DHO agregado/bounded; não carrega contexto individual de todo o tenant." };
  if (mode === "empty") return { employeeIds: [], mode, available: true, limitation: "Não há uma população DHO autorizada para este contexto." };
  const org = q(context.organizationId);
  if (mode === "self") {
    const result = await load(() => get<{ id: string }>(context.session, "employees", "id", `organization_id=eq.${org}&id=eq.${q(context.employeeId!)}&auth_user_id=eq.${q(context.session.user.id)}&status=eq.active`));
    return { employeeIds: result.items.map((item) => item.id), mode, available: result.status !== "unavailable", limitation: result.limitation };
  }
  const filter = mode === "direct_reports" ? `manager_employee_id=eq.${q(context.employeeId!)}&status=eq.active` : "status=eq.active";
  const result = await load(() => get<{ id: string }>(context.session, "employees", "id", `organization_id=eq.${org}&${filter}`));
  const plan = dhoSubjectRequestPlan(context.role, result.items.map((item) => item.id));
  const limitNote = context.role === "gestor" && plan.bounded ? `População de gestor limitada a ${MAX_DHO_DIRECT_REPORTS} sujeitos por carregamento; selecione um sujeito para aprofundar.` : undefined;
  return { employeeIds: plan.subjectIds, mode: plan.mode, available: result.status !== "unavailable", limitation: [result.limitation, limitNote].filter(Boolean).join(" ") || undefined };
}

export function buildDhoContextItems(input: { organizationId: string; employeeId?: string; employeeIds?: readonly string[]; assessments: Assessment[]; scores: AssessmentScore[]; evolution: EvolutionPoint[]; pdis: Pdi[]; objectives: PdiObjective[]; actions: PdiAction[]; checkins: PdiCheckin[] }): DhoContextItem[] {
  const employeeIds = new Set(input.employeeIds ?? (input.employeeId ? [input.employeeId] : []));
  const items: DhoContextItem[] = [];
  const assessments = input.assessments.filter((item) => item.organization_id === input.organizationId && employeeIds.has(item.subject_employee_id) && item.status === "completed");
  const assessmentById = new Map(assessments.map((item) => [item.id, item]));
  for (const score of input.scores.filter((item) => item.organization_id === input.organizationId && assessmentById.has(item.assessment_id) && item.score != null)) {
    const assessment = assessmentById.get(score.assessment_id)!;
    items.push({ id: `assessment:${score.id}`, organizationId: input.organizationId, employeeId: assessment.subject_employee_id, kind: "ASSESSMENT", title: "Competência avaliada", summary: `Score válido ${score.score}/5 em competência ${score.competency_id}.`, context: { competencyId: score.competency_id, expectedLevelSnapshot: score.expected_level_snapshot }, unknowns: [], limitations: ["Score não determina diagnóstico nem prescrição."], provenance: [{ entityType: "ASSESSMENT", entityId: score.assessment_id, sourceType: "assessment_v1", sourceId: score.id }] });
  }
  for (const point of input.evolution.filter((item) => item.employee_id && employeeIds.has(item.employee_id) && item.competency_id && item.score != null)) {
    const sourceType = point.source_type === "assessment_v1" ? "assessment_v1" : "feedback_360";
    const entityType = sourceType === "assessment_v1" ? "ASSESSMENT" : "FEEDBACK_360";
    const safeSourceId = point.round_id ?? point.cycle_id ?? point.competency_id;
    const comparable = point.previous_score != null && point.delta != null;
    items.push({ id: `evolution:${sourceType}:${safeSourceId}:${point.competency_id}:${point.employee_id}`, organizationId: input.organizationId, employeeId: point.employee_id!, kind: comparable ? "EVOLUTION" : (sourceType === "assessment_v1" ? "ASSESSMENT" : "FEEDBACK_360"), title: point.competency_name ?? "Evolução entre ciclos", summary: comparable ? `Evolução comparável: ${point.previous_score} → ${point.score} (${point.delta! > 0 ? "+" : ""}${point.delta}).` : `Ponto contextual ${point.score}/5; não há predecessor comparável.`, context: { sourceType, competencyId: point.competency_id, expectedLevelSnapshot: point.expected_level_snapshot, positionIdSnapshot: point.position_id ?? null, distanceToExpected: point.distance_to_expected ?? null }, unknowns: comparable ? [] : ["Não há predecessor histórico comparável neste ponto."], limitations: [sourceType === "assessment_v1" ? "O contrato de evolução não retornou assessment_id; ciclo/source contract é o identificador seguro disponível." : "Contexto seguro do contrato DHO; não é diagnóstico causal."], provenance: [{ entityType, entityId: safeSourceId, sourceType, sourceId: point.round_id ?? point.cycle_id, relationship: point.source_type }] });
  }
  const pdis = input.pdis.filter((item) => item.organization_id === input.organizationId && employeeIds.has(item.employee_id));
  for (const pdi of pdis) {
    items.push({ id: `pdi:${pdi.id}`, organizationId: input.organizationId, employeeId: pdi.employee_id, kind: "PDI", title: "PDI em acompanhamento", summary: pdi.objective, status: pdi.status, context: { dueDate: pdi.due_date ?? null }, unknowns: [], limitations: ["PDI permanece sob decisão e alteração humana."], provenance: [{ entityType: "PDI", entityId: pdi.id, sourceType: "pdi", sourceId: pdi.id }] });
    for (const objective of input.objectives.filter((item) => item.organization_id === input.organizationId && item.pdi_id === pdi.id)) {
      items.push({ id: `pdi-objective:${objective.id}`, organizationId: input.organizationId, employeeId: pdi.employee_id, kind: "PDI", title: objective.title, summary: `Critério de sucesso: ${objective.success_criteria}`, status: objective.status, context: { dueDate: objective.due_date ?? null }, unknowns: [], limitations: ["A Bee não pode criar, alterar ou concluir este objetivo."], provenance: [{ entityType: "PDI", entityId: pdi.id, sourceType: "pdi_objective", sourceId: objective.id }] });
      for (const action of input.actions.filter((item) => item.organization_id === input.organizationId && item.objective_id === objective.id)) items.push({ id: `pdi-action:${action.id}`, organizationId: input.organizationId, employeeId: pdi.employee_id, kind: "PDI", title: action.title, summary: action.blocker ? `Ação ${action.status}; bloqueio: ${action.blocker}` : `Ação ${action.status}.`, status: action.status, context: { dueDate: action.due_date ?? null }, unknowns: [], limitations: ["Responsável e lifecycle permanecem humanos."], provenance: [{ entityType: "PDI", entityId: pdi.id, sourceType: "pdi_action", sourceId: action.id }] });
    }
    for (const checkin of input.checkins.filter((item) => item.organization_id === input.organizationId && item.pdi_id === pdi.id).slice(0, 5)) items.push({ id: `pdi-checkin:${checkin.id}`, organizationId: input.organizationId, employeeId: pdi.employee_id, kind: "PDI", title: "Check-in de PDI", summary: checkin.progress_note, context: { nextStep: checkin.next_step ?? null, blocker: checkin.blocker ?? null, checkinAt: checkin.checkin_at }, unknowns: [], limitations: ["Check-in é contexto de acompanhamento, não evidência causal."], provenance: [{ entityType: "PDI", entityId: pdi.id, sourceType: "pdi_checkin", sourceId: checkin.id }] });
  }
  return items;
}

export async function readDhoContext(context: DhoReadContext): Promise<DhoContextResult> {
  const population = await resolvePopulation(context).catch(() => ({ employeeIds: [], mode: dhoPopulationMode(context.role, context.employeeId ?? null), available: false, limitation: "População DHO indisponível para esta leitura." }));
  if (population.mode === "aggregate_only") return { items: [], populationMode: population.mode, populationCount: 0, sources: dhoSourceAvailability({ assessment: "aggregate_only", feedback_360: "aggregate_only", pdi: "aggregate_only" }, { assessment: population.limitation ?? "Agregado seguro", feedback_360: population.limitation ?? "Agregado seguro", pdi: population.limitation ?? "Agregado seguro" }) };
  if (!population.employeeIds.length) { const status = population.available ? "empty" : "unavailable"; return { items: [], populationMode: population.mode, populationCount: 0, sources: dhoSourceAvailability({ assessment: status, feedback_360: status, pdi: status }, { assessment: population.limitation, feedback_360: population.limitation, pdi: population.limitation }) }; }
  const organization = q(context.organizationId); const employees = inFilter(population.employeeIds);
  const assessmentLoad = await load(() => get<Assessment>(context.session, "assessments", "id,organization_id,subject_employee_id,cycle_id,position_id,status,completed_at", `organization_id=eq.${organization}&subject_employee_id=${employees}&status=eq.completed`));
  const scoresLoad = assessmentLoad.items.length ? await load(() => get<AssessmentScore>(context.session, "assessment_competency_scores", "id,organization_id,assessment_id,competency_id,expected_level_snapshot,score", `organization_id=eq.${organization}&assessment_id=${inFilter(assessmentLoad.items.map((item) => item.id))}`)) : { items: [], status: "empty" as const };
  const evolutionLoads = await Promise.all(population.employeeIds.map(async (employeeId) => ({ employeeId, result: await load(() => rpc<EvolutionPoint>(context.session, "fb360_read_evolution", { p_organization_id: context.organizationId, p_subject_employee_id: employeeId, p_origin_filter: null })) })));
  const evolution = evolutionLoads.flatMap(({ employeeId, result }) => result.items.map((item) => ({ ...item, employee_id: employeeId })));
  const feedbackUnavailable = evolutionLoads.some(({ result }) => result.status === "unavailable");
  const feedbackEmpty = evolution.length === 0 && !feedbackUnavailable;
  const pdiLoad = await load(() => get<Pdi>(context.session, "pdis", "id,organization_id,employee_id,objective,status,due_date", `organization_id=eq.${organization}&employee_id=${employees}`));
  const pdiIds = pdiLoad.items.map((item) => item.id);
  const objectivesLoad = pdiIds.length ? await load(() => get<PdiObjective>(context.session, "pdi_objectives", "id,organization_id,pdi_id,title,success_criteria,status,due_date", `organization_id=eq.${organization}&pdi_id=${inFilter(pdiIds)}`)) : { items: [], status: "empty" as const };
  const objectiveIds = objectivesLoad.items.map((item) => item.id);
  const actionsLoad = objectiveIds.length ? await load(() => get<PdiAction>(context.session, "pdi_actions", "id,organization_id,objective_id,title,status,blocker,due_date", `organization_id=eq.${organization}&objective_id=${inFilter(objectiveIds)}`)) : { items: [], status: "empty" as const };
  const checkinsLoad = pdiIds.length ? await load(() => get<PdiCheckin>(context.session, "pdi_checkins", "id,organization_id,pdi_id,progress_note,next_step,blocker,checkin_at", `organization_id=eq.${organization}&pdi_id=${inFilter(pdiIds)}&order=checkin_at.desc&limit=20`)) : { items: [], status: "empty" as const };
  const items = buildDhoContextItems({ organizationId: context.organizationId, employeeIds: population.employeeIds, assessments: assessmentLoad.items, scores: scoresLoad.items, evolution, pdis: pdiLoad.items, objectives: objectivesLoad.items, actions: actionsLoad.items, checkins: checkinsLoad.items });
  const assessmentDependencyUnavailable = scoresLoad.status === "unavailable";
  const assessmentStatus: DhoSourceStatus = assessmentLoad.status === "unavailable" || assessmentDependencyUnavailable ? "unavailable" : assessmentLoad.status;
  const assessmentLimitation = [population.limitation, assessmentLoad.limitation, assessmentDependencyUnavailable ? "Scores de Assessment indisponíveis; os itens dependentes não foram considerados completos." : undefined].filter(Boolean).join(" ");
  const pdiDependency = [objectivesLoad, actionsLoad, checkinsLoad].find((result) => result.status === "unavailable");
  const pdiStatus: DhoSourceStatus = pdiLoad.status === "unavailable" || !!pdiDependency ? "unavailable" : pdiLoad.status;
  const pdiLimitation = [population.limitation, pdiLoad.limitation, pdiDependency?.limitation, pdiDependency ? "Parte do contexto de PDI está indisponível; os dados válidos foram preservados." : undefined].filter(Boolean).join(" ");
  const feedbackStatus: DhoSourceStatus = feedbackUnavailable ? "unavailable" : (feedbackEmpty ? "empty" : "available");
  const feedbackLimitation = feedbackUnavailable ? "Uma ou mais leituras de Feedback 360 estão indisponíveis; resultados válidos permanecem parciais." : population.limitation;
  return { items, populationMode: population.mode, populationCount: population.employeeIds.length, sources: dhoSourceAvailability({ assessment: assessmentStatus, feedback_360: feedbackStatus, pdi: pdiStatus }, { assessment: assessmentLimitation, feedback_360: feedbackLimitation, pdi: pdiLimitation }) };
}
