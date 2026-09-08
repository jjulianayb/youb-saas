import type { SupabaseSession } from "../../lib/supabase";
import type { IntelligenceReadContext } from "../intelligence-core/types";

const env = (import.meta as ImportMeta & { env?: Record<string, unknown> }).env ?? {};
const supabaseUrl = (env.VITE_SUPABASE_URL as string | undefined)?.replace(/\/$/, "");
const supabaseAnonKey = env.VITE_SUPABASE_ANON_KEY as string | undefined;

export type DhoContextKind = "ASSESSMENT" | "FEEDBACK_360" | "EVOLUTION" | "PDI";
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

type Assessment = { id: string; organization_id: string; subject_employee_id: string; cycle_id: string; position_id?: string | null; status: string; completed_at?: string | null };
type AssessmentScore = { id: string; organization_id: string; assessment_id: string; competency_id: string; expected_level_snapshot: number; score?: number | null };
type EvolutionPoint = { source_type: string; cycle_id?: string | null; round_id?: string | null; competency_id: string; competency_name?: string | null; position_id?: string | null; expected_level_snapshot: number; score?: number | null; previous_score?: number | null; delta?: number | null; distance_to_expected?: number | null; completed_at?: string | null };
type Pdi = { id: string; organization_id: string; employee_id: string; objective: string; status: string; due_date?: string | null };
type PdiObjective = { id: string; organization_id: string; pdi_id: string; title: string; success_criteria: string; status: string; due_date?: string | null };
type PdiAction = { id: string; organization_id: string; objective_id: string; title: string; status: string; blocker?: string | null; due_date?: string | null };
type PdiCheckin = { id: string; organization_id: string; pdi_id: string; progress_note: string; next_step?: string | null; blocker?: string | null; checkin_at: string };

function config(): { url: string; key: string } { if (!supabaseUrl || !supabaseAnonKey) throw new Error("O ambiente ainda não está conectado ao Supabase."); return { url: supabaseUrl, key: supabaseAnonKey }; }
function q(value: string): string { return encodeURIComponent(value); }
async function get<T>(session: SupabaseSession, table: string, select: string, filters: string): Promise<T[]> { const { url, key } = config(); const response = await fetch(`${url}/rest/v1/${table}?select=${q(select)}&${filters}`, { headers: { apikey: key, Authorization: `Bearer ${session.access_token}` } }); if (!response.ok) throw new Error(`DHO source ${table} is not available`); return (await response.json()) as T[]; }
async function rpc<T>(session: SupabaseSession, name: string, body: Record<string, unknown>): Promise<T[]> { const { url, key } = config(); const response = await fetch(`${url}/rest/v1/rpc/${name}`, { method: "POST", headers: { apikey: key, Authorization: `Bearer ${session.access_token}`, "Content-Type": "application/json" }, body: JSON.stringify(body) }); if (!response.ok) throw new Error(`DHO RPC ${name} is not available`); return (await response.json()) as T[]; }
async function safe<T>(loader: () => Promise<T[]>): Promise<T[]> { try { return await loader(); } catch { return []; } }

export function buildDhoContextItems(input: { organizationId: string; employeeId: string; assessments: Assessment[]; scores: AssessmentScore[]; evolution: EvolutionPoint[]; pdis: Pdi[]; objectives: PdiObjective[]; actions: PdiAction[]; checkins: PdiCheckin[] }): DhoContextItem[] {
  const items: DhoContextItem[] = [];
  const assessments = input.assessments.filter((item) => item.organization_id === input.organizationId && item.subject_employee_id === input.employeeId && item.status === "completed");
  const assessmentIds = new Set(assessments.map((item) => item.id));
  for (const score of input.scores.filter((item) => item.organization_id === input.organizationId && assessmentIds.has(item.assessment_id) && item.score != null)) {
    items.push({ id: `assessment:${score.id}`, organizationId: input.organizationId, employeeId: input.employeeId, kind: "ASSESSMENT", title: "Competência avaliada", summary: `Score válido ${score.score}/5 em competência ${score.competency_id}.`, context: { competencyId: score.competency_id, expectedLevelSnapshot: score.expected_level_snapshot }, unknowns: [], limitations: ["Score não determina diagnóstico nem prescrição."], provenance: [{ entityType: "ASSESSMENT", entityId: score.assessment_id, sourceType: "assessment_v1", sourceId: score.id }] });
  }
  for (const point of input.evolution.filter((item) => item.competency_id && item.score != null)) {
    const sourceType = point.source_type === "assessment_v1" ? "assessment_v1" : "feedback_360";
    items.push({ id: `evolution:${sourceType}:${point.round_id ?? point.cycle_id ?? point.competency_id}:${point.competency_id}`, organizationId: input.organizationId, employeeId: input.employeeId, kind: point.previous_score == null || point.delta == null ? (sourceType === "assessment_v1" ? "ASSESSMENT" : "FEEDBACK_360") : "EVOLUTION", title: point.competency_name ?? "Evolução entre ciclos", summary: point.previous_score == null || point.delta == null ? `Ponto contextual ${point.score}/5; não há predecessor comparável.` : `Evolução comparável: ${point.previous_score} → ${point.score} (${point.delta > 0 ? "+" : ""}${point.delta}).`, context: { sourceType, competencyId: point.competency_id, expectedLevelSnapshot: point.expected_level_snapshot, positionIdSnapshot: point.position_id ?? null, distanceToExpected: point.distance_to_expected ?? null }, unknowns: point.previous_score == null || point.delta == null ? ["Não há predecessor histórico comparável neste ponto."] : [], limitations: ["Contexto seguro do contrato DHO; não é diagnóstico causal."], provenance: [{ entityType: "FEEDBACK_360", entityId: point.round_id ?? point.cycle_id ?? point.competency_id, sourceType, sourceId: point.round_id ?? point.cycle_id, relationship: point.source_type }] });
  }
  const pdis = input.pdis.filter((item) => item.organization_id === input.organizationId && item.employee_id === input.employeeId);
  for (const pdi of pdis) {
    items.push({ id: `pdi:${pdi.id}`, organizationId: input.organizationId, employeeId: input.employeeId, kind: "PDI", title: "PDI em acompanhamento", summary: pdi.objective, status: pdi.status, context: { dueDate: pdi.due_date ?? null }, unknowns: [], limitations: ["PDI permanece sob decisão e alteração humana."], provenance: [{ entityType: "PDI", entityId: pdi.id, sourceType: "pdi", sourceId: pdi.id }] });
    for (const objective of input.objectives.filter((item) => item.pdi_id === pdi.id)) {
      items.push({ id: `pdi-objective:${objective.id}`, organizationId: input.organizationId, employeeId: input.employeeId, kind: "PDI", title: objective.title, summary: `Critério de sucesso: ${objective.success_criteria}`, status: objective.status, context: { dueDate: objective.due_date ?? null }, unknowns: [], limitations: ["A Bee não pode criar, alterar ou concluir este objetivo."], provenance: [{ entityType: "PDI", entityId: pdi.id, sourceType: "pdi_objective", sourceId: objective.id }] });
      for (const action of input.actions.filter((item) => item.objective_id === objective.id)) items.push({ id: `pdi-action:${action.id}`, organizationId: input.organizationId, employeeId: input.employeeId, kind: "PDI", title: action.title, summary: action.blocker ? `Ação ${action.status}; bloqueio: ${action.blocker}` : `Ação ${action.status}.`, status: action.status, context: { dueDate: action.due_date ?? null }, unknowns: [], limitations: ["Responsável e lifecycle permanecem humanos."], provenance: [{ entityType: "PDI", entityId: pdi.id, sourceType: "pdi_action", sourceId: action.id }] });
    }
    for (const checkin of input.checkins.filter((item) => item.pdi_id === pdi.id).slice(0, 5)) items.push({ id: `pdi-checkin:${checkin.id}`, organizationId: input.organizationId, employeeId: input.employeeId, kind: "PDI", title: "Check-in de PDI", summary: checkin.progress_note, context: { nextStep: checkin.next_step ?? null, blocker: checkin.blocker ?? null, checkinAt: checkin.checkin_at }, unknowns: [], limitations: ["Check-in é contexto de acompanhamento, não evidência causal."], provenance: [{ entityType: "PDI", entityId: pdi.id, sourceType: "pdi_checkin", sourceId: checkin.id }] });
  }
  return items;
}

export async function readDhoContext(context: IntelligenceReadContext): Promise<DhoContextItem[]> {
  if (!context.employeeId) return [];
  const employee = q(context.employeeId); const organization = q(context.organizationId);
  const assessments = await safe(() => get<Assessment>(context.session, "assessments", "id,organization_id,subject_employee_id,cycle_id,position_id,status,completed_at", `organization_id=eq.${organization}&subject_employee_id=eq.${employee}&status=eq.completed`));
  const ids = assessments.map((item) => item.id);
  const scores = ids.length ? await safe(() => get<AssessmentScore>(context.session, "assessment_competency_scores", "id,organization_id,assessment_id,competency_id,expected_level_snapshot,score", `organization_id=eq.${organization}&assessment_id=in.(${ids.map(q).join(",")})`)) : [];
  const evolution = await safe(() => rpc<EvolutionPoint>(context.session, "fb360_read_evolution", { p_organization_id: context.organizationId, p_subject_employee_id: context.employeeId, p_origin_filter: null }));
  const pdis = await safe(() => get<Pdi>(context.session, "pdis", "id,organization_id,employee_id,objective,status,due_date", `organization_id=eq.${organization}&employee_id=eq.${employee}`));
  const pdiIds = pdis.map((item) => item.id); const objectives = pdiIds.length ? await safe(() => get<PdiObjective>(context.session, "pdi_objectives", "id,organization_id,pdi_id,title,success_criteria,status,due_date", `organization_id=eq.${organization}&pdi_id=in.(${pdiIds.map(q).join(",")})`)) : [];
  const objectiveIds = objectives.map((item) => item.id); const actions = objectiveIds.length ? await safe(() => get<PdiAction>(context.session, "pdi_actions", "id,organization_id,objective_id,title,status,blocker,due_date", `organization_id=eq.${organization}&objective_id=in.(${objectiveIds.map(q).join(",")})`)) : [];
  const checkins = pdiIds.length ? await safe(() => get<PdiCheckin>(context.session, "pdi_checkins", "id,organization_id,pdi_id,progress_note,next_step,blocker,checkin_at", `organization_id=eq.${organization}&pdi_id=in.(${pdiIds.map(q).join(",")})&order=checkin_at.desc&limit=20`)) : [];
  return buildDhoContextItems({ organizationId: context.organizationId, employeeId: context.employeeId, assessments, scores, evolution, pdis, objectives, actions, checkins });
}
