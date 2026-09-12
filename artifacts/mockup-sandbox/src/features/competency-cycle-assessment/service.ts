import type { SupabaseSession } from "../../lib/supabase";
import { employeeQueryFilters, type ClassicDhoQueryContext } from "../classic-dho-access";

export type CcaRole = "admin_youb" | "diretoria" | "rh" | "gestor" | "colaborador";
export type CcaEmployee = { id: string; full_name: string; email?: string | null; position_id?: string | null; manager_employee_id?: string | null; auth_user_id?: string | null };
export type CcaCompetency = { id: string; name: string; description?: string | null; active: boolean };
export type CcaPosition = { id: string; name: string; level?: string | null };
export type CcaMapping = { id: string; position_id: string; competency_id: string; expected_level: number; active: boolean };
export type CcaCycle = { id: string; name: string; starts_at?: string | null; ends_at?: string | null; status: "draft" | "active" | "closed" };
export type CcaAssessment = { id: string; cycle_id: string; subject_employee_id: string; evaluator_employee_id?: string | null; position_id?: string | null; status: "draft" | "in_progress" | "submitted" | "completed"; created_at: string; completed_at?: string | null };
export type CcaScore = { id: string; assessment_id: string; competency_id: string; position_competency_id: string; expected_level_snapshot: number; score?: number | null; evidence_note?: string | null };
export type CcaAggregate = { cycle_id: string; competency_id: string; competency_name: string; position_id: string; position_name: string; assessment_count: number; average_score: number };
export type CcaData = { employees: CcaEmployee[]; competencies: CcaCompetency[]; positions: CcaPosition[]; mappings: CcaMapping[]; cycles: CcaCycle[]; assessments: CcaAssessment[] };

const baseUrl = ((import.meta.env.VITE_SUPABASE_URL as string | undefined) ?? "").replace(/\/$/, "");
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
function config() { if (!baseUrl || !anonKey) throw new Error("O ambiente ainda não está conectado ao Supabase."); return { baseUrl, anonKey }; }
function enc(value: string): string { return encodeURIComponent(value); }
async function request<T>(session: SupabaseSession, path: string, options: RequestInit = {}): Promise<T> { const c = config(); const response = await fetch(`${c.baseUrl}/rest/v1/${path}`, { ...options, headers: { apikey: c.anonKey, Authorization: `Bearer ${session.access_token}`, "Content-Type": "application/json", ...(options.headers ?? {}) } }); const body = await response.json().catch(() => null); if (!response.ok) throw new Error((body && typeof body === "object" && ((body as { message?: string }).message || (body as { details?: string }).details)) || "Não foi possível concluir a operação."); return body as T; }
export async function rpc<T>(session: SupabaseSession, name: string, payload: Record<string, unknown>): Promise<T> { return request<T>(session, `rpc/${name}`, { method: "POST", body: JSON.stringify(payload) }); }

export async function readCcaData(session: SupabaseSession, organizationId: string, context: ClassicDhoQueryContext): Promise<CcaData> {
  const org = enc(organizationId);
  const employeesFilter = employeeQueryFilters(context);
  const [employees, competencies, positions, mappings, cycles, assessments] = await Promise.all([
    request<CcaEmployee[]>(session, `employees?select=id,full_name,email,position_id,manager_employee_id,auth_user_id&organization_id=eq.${org}&${employeesFilter}&order=full_name`),
    request<CcaCompetency[]>(session, `competencies?select=id,name,description,active&organization_id=eq.${org}&order=name`),
    request<CcaPosition[]>(session, `positions?select=id,name,level&organization_id=eq.${org}&order=name`),
    request<CcaMapping[]>(session, `position_competencies?select=id,position_id,competency_id,expected_level,active&organization_id=eq.${org}&order=position_id,competency_id`),
    request<CcaCycle[]>(session, `cycles?select=id,name,starts_at,ends_at,status&organization_id=eq.${org}&order=created_at.desc`),
    request<CcaAssessment[]>(session, `assessments?select=id,cycle_id,subject_employee_id,evaluator_employee_id,position_id,status,created_at,completed_at&organization_id=eq.${org}&order=created_at.desc`),
  ]);
  return { employees, competencies, positions, mappings, cycles, assessments };
}

export async function readAssessmentScores(session: SupabaseSession, organizationId: string, assessmentId: string): Promise<CcaScore[]> { return request<CcaScore[]>(session, `assessment_competency_scores?select=id,assessment_id,competency_id,position_competency_id,expected_level_snapshot,score,evidence_note&organization_id=eq.${enc(organizationId)}&assessment_id=eq.${enc(assessmentId)}&order=competency_id`); }
export async function readAggregate(session: SupabaseSession, organizationId: string, cycleId: string): Promise<CcaAggregate[]> { return rpc<CcaAggregate[]>(session, "cca_read_assessment_aggregate", { p_organization_id: organizationId, p_cycle_id: cycleId }); }
