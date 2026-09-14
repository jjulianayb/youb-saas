export type AmbientEpistemicKind = "system_record" | "machine_observed" | "human_declared" | "machine_inferred" | "human_confirmed" | "human_corrected";
export type AmbientHorizon = "now" | "today" | "week" | "later";
export type AmbientAttentionType = "confirm" | "review" | "decide" | "converse" | "delegate" | "act" | "monitor";
export type AmbientContextStatus = "sufficient" | "insufficient";
export type AmbientRole = "platform_admin" | "admin_youb" | "rh" | "diretoria" | "gestor" | "colaborador";

export type AmbientSource = {
  id: string; organization_id: string; source_key: string; source_type: string; display_name: string;
  status: "planned" | "available" | "disabled"; capabilities: readonly string[]; owner_user_id: string | null;
  metadata: Record<string, unknown>; created_by_user_id: string; created_at: string; updated_at: string;
};
export type AmbientObservation = {
  id: string; organization_id: string; source_registry_id: string | null; observation_type: string;
  epistemic_kind: AmbientEpistemicKind; summary: string; observed_at: string; recorded_at: string;
  valid_from: string | null; valid_until: string | null; sensitivity: "standard" | "restricted" | "highly_sensitive";
  confidence: number | null; scope_type: string | null; scope_ref: string | null;
  provenance: Record<string, unknown>; structured_value: Record<string, unknown>; correlation_id: string | null;
  actor_user_id: string | null; created_by_user_id: string; supersedes_observation_id: string | null;
};
export type AmbientObservationReview = {
  id: string; organization_id: string; observation_id: string; review_type: "confirm" | "correct" | "reject";
  reviewer_user_id: string; correction_summary: string | null; correction_value: Record<string, unknown> | null;
  reason: string | null; correlation_id: string | null; created_at: string;
};
export type AmbientUserPreference = { id: string; organization_id: string; user_id: string; preference_key: string; preference_value: Record<string, unknown>; privacy: "private"; created_at: string; updated_at: string };
export type AmbientAttentionItem = {
  id: string; organization_id: string; owner_user_id: string; horizon: AmbientHorizon; attention_type: AmbientAttentionType;
  title: string; rationale: string | null; status: "open" | "completed" | "dismissed" | "snoozed"; priority: 1 | 2 | 3;
  due_at: string | null; source_observation_id: string | null; source_recommendation_id: string | null;
  context: Record<string, unknown>; human_required: true; created_by_user_id: string; created_at: string; updated_at: string;
};
export type LeadershipCommitment = {
  id: string; organization_id: string; owner_user_id: string; created_by_user_id: string; title: string;
  context: string | null; impact: string | null; horizon: AmbientHorizon; status: "planned" | "completed" | "deferred" | "cancelled";
  due_at: string | null; provenance: { epistemic_kind: "human_declared" } & Record<string, unknown>; created_at: string; updated_at: string;
};
export type AmbientAttentionBrief = {
  id?: string; organization_id: string; owner_user_id: string; horizon: AmbientHorizon; context_status: AmbientContextStatus;
  insufficiency_reason: string | null; focus_statement: string | null; priority_items: readonly Record<string, unknown>[];
  do_items: readonly Record<string, unknown>[]; delegate_items: readonly Record<string, unknown>[]; stop_items: readonly Record<string, unknown>[];
  source_observation_ids: readonly string[]; generated_by: "human_reviewed_service" | "future_planner_preview";
};
export type AmbientFoundationRead = {
  sources: readonly AmbientSource[]; observations: readonly AmbientObservation[]; reviews: readonly AmbientObservationReview[];
  preferences: readonly AmbientUserPreference[]; attention: readonly AmbientAttentionItem[];
  commitments: readonly LeadershipCommitment[]; briefs: readonly AmbientAttentionBrief[];
};
export type AmbientRuntimeContext = { organizationId: string; userId: string; role: AmbientRole; employeeId: string | null };
export type AmbientIntent = "attention_brief" | "pending_confirmations" | "leader_today" | "leader_week" | "leader_evolution";

const FORBIDDEN_CONTENT = /(raw[_ -]?(transcript|message|email|body)|full[_ -]?(transcript|message|email|body)|chain[_ -]?of[_ -]?thought|prompt|access[_ -]?token|refresh[_ -]?token|client[_ -]?secret|password|credential|api[_ -]?key)/i;
const HEALTH_DIAGNOSIS = /\b(tdah|adhd|depress[aã]o|ansiedade|bipolar|diagn[oó]stico cl[ií]nico|condi[cç][aã]o m[eé]dica)\b/i;
export function containsForbiddenAmbientContent(value: unknown): boolean { return FORBIDDEN_CONTENT.test(JSON.stringify(value)); }
export function containsHealthDiagnosis(value: unknown): boolean { return HEALTH_DIAGNOSIS.test(JSON.stringify(value)); }
export function isHighStakesAutonomy(value: unknown): boolean { return /\b(demitir|demiss[aã]o|promover|promo[cç][aã]o|remunerar|sal[aá]rio|disciplina|suspender)\b/i.test(JSON.stringify(value)); }
export function isHumanConfirmedKind(kind: AmbientEpistemicKind): boolean { return kind === "human_confirmed" || kind === "human_corrected"; }
