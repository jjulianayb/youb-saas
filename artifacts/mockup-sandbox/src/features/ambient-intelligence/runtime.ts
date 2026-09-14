import { containsHealthDiagnosis, isHighStakesAutonomy, type AmbientAttentionBrief, type AmbientAttentionItem, type AmbientFoundationRead, type AmbientHorizon, type AmbientIntent, type AmbientRuntimeContext, type LeadershipCommitment } from "./types";

export const AMBIENT_BEE_INTENTS = ["attention_brief", "pending_confirmations", "leader_today", "leader_week", "leader_evolution"] as const;
export function routeAmbientIntent(input: string): AmbientIntent | null {
  const normalized = input.trim().toLowerCase().replace(/[?!.]/g, "").replace(/\s+/g, "_");
  const aliases: Record<string, AmbientIntent> = {
    attention: "attention_brief", attention_brief: "attention_brief", pending_confirmations: "pending_confirmations",
    confirmations: "pending_confirmations", what_needs_confirmation: "pending_confirmations", leader_today: "leader_today", today: "leader_today", leader_week: "leader_week",
    week: "leader_week", leader_evolution: "leader_evolution", evolution: "leader_evolution",
  };
  return aliases[normalized] ?? null;
}

export type AmbientBeeReadModel = {
  context: AmbientRuntimeContext;
  brief: AmbientAttentionBrief;
  pendingConfirmations: readonly AmbientAttentionItem[];
  today: readonly AmbientAttentionItem[];
  week: readonly AmbientAttentionItem[];
  evolution: { commitments: readonly LeadershipCommitment[]; preferences: readonly Record<string, unknown>[] };
  limitations: readonly string[];
};

function emptyBrief(context: AmbientRuntimeContext, horizon: AmbientHorizon, reason: string): AmbientAttentionBrief {
  return { organization_id: context.organizationId, owner_user_id: context.userId, horizon, context_status: "insufficient", insufficiency_reason: reason, focus_statement: null, priority_items: [], do_items: [], delegate_items: [], stop_items: [], source_observation_ids: [], generated_by: "human_reviewed_service", visibility_scope: "personal", authorized_roles: [], authorized_user_ids: [context.userId] };
}
function allowedItems(context: AmbientRuntimeContext, items: readonly AmbientAttentionItem[]): AmbientAttentionItem[] {
  return items.filter((item) => item.organization_id === context.organizationId && item.owner_user_id === context.userId && item.human_required === true && !isHighStakesAutonomy(item));
}
function briefFromItems(context: AmbientRuntimeContext, items: readonly AmbientAttentionItem[], horizon: AmbientHorizon): AmbientAttentionBrief {
  const selected = allowedItems(context, items).filter((item) => item.horizon === horizon && item.status === "open").sort((a, b) => a.priority - b.priority).slice(0, 3);
  if (selected.length === 0) return emptyBrief(context, horizon, "Não há contexto autorizado suficiente para preparar prioridades.");
  return { organization_id: context.organizationId, owner_user_id: context.userId, horizon, context_status: "sufficient", insufficiency_reason: null, focus_statement: null, priority_items: selected.map((item) => ({ id: item.id, title: item.title, attention_type: item.attention_type, rationale: item.rationale, priority: item.priority })), do_items: selected.filter((item) => ["act", "review", "converse", "decide", "confirm"].includes(item.attention_type)).map((item) => ({ id: item.id, title: item.title })), delegate_items: selected.filter((item) => item.attention_type === "delegate").map((item) => ({ id: item.id, title: item.title })), stop_items: [], source_observation_ids: selected.flatMap((item) => item.source_observation_id ? [item.source_observation_id] : []), generated_by: "human_reviewed_service", visibility_scope: "personal", authorized_roles: [], authorized_user_ids: [context.userId] };
}
export function prepareAmbientBeeReadModel(context: AmbientRuntimeContext, foundation: AmbientFoundationRead): AmbientBeeReadModel {
  const observations = foundation.observations.filter((item) => item.organization_id === context.organizationId);
  const attention = allowedItems(context, foundation.attention);
  const commitments = foundation.commitments.filter((item) => item.organization_id === context.organizationId && item.owner_user_id === context.userId);
  const preferences = foundation.preferences.filter((item) => item.organization_id === context.organizationId && item.user_id === context.userId).map((item) => item.preference_value);
  const limitations = observations.length === 0 && attention.length === 0 && commitments.length === 0 ? ["Ambient context is insufficient; no priorities were fabricated."] : [];
  return { context, brief: briefFromItems(context, attention, "today"), pendingConfirmations: attention.filter((item) => item.attention_type === "confirm" && item.status === "open"), today: attention.filter((item) => item.horizon === "today"), week: attention.filter((item) => item.horizon === "week"), evolution: { commitments, preferences }, limitations };
}
export function selectAmbientIntent(model: AmbientBeeReadModel, intent: AmbientIntent): AmbientAttentionBrief | readonly AmbientAttentionItem[] | AmbientBeeReadModel["evolution"] {
  if (intent === "attention_brief" || intent === "leader_today") return model.brief;
  if (intent === "pending_confirmations") return model.pendingConfirmations;
  if (intent === "leader_week") return model.week;
  return model.evolution;
}
export function canPersistAmbientText(value: unknown): boolean { return !containsHealthDiagnosis(value) && !isHighStakesAutonomy(value); }
