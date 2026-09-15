import { prepareAmbientBeeReadModel, routeAmbientIntent, selectAmbientIntent, type AmbientBeeReadModel } from "./runtime";
import type { AmbientAttentionItem, AmbientAttentionBrief, AmbientFoundationRead } from "./types";

export type AmbientLeaderPriority = {
  id: string;
  title: string;
  duration: string;
  reason: string;
  source: string;
  kind: "fazer" | "delegar" | "decidir";
  epistemic: string;
};

function itemValue(item: Record<string, unknown>, key: string): string | null {
  const value = item[key];
  return typeof value === "string" && value.trim() ? value : null;
}

function attentionKind(item: AmbientAttentionItem | Record<string, unknown>): AmbientLeaderPriority["kind"] {
  const value = item.attention_type;
  if (value === "delegate") return "delegar";
  if (value === "decide" || value === "confirm" || value === "review") return "decidir";
  return "fazer";
}

function sourceLabel(item: AmbientAttentionItem | Record<string, unknown>): string {
  const value = item.attention_type;
  if (value === "confirm") return "Confirmação pendente";
  if (value === "review") return "Revisão autorizada";
  if (value === "delegate") return "Delegação preparada";
  if (value === "decide") return "Decisão humana";
  return "Atenção ambiente autorizada";
}

export function ambientBriefPriorities(brief: AmbientAttentionBrief): AmbientLeaderPriority[] {
  if (brief.context_status !== "sufficient") return [];
  return brief.priority_items.slice(0, 3).map((item, index) => ({
    id: itemValue(item, "id") ?? `ambient-priority-${index + 1}`,
    title: itemValue(item, "title") ?? "Revisar contexto autorizado",
    duration: itemValue(item, "duration") ?? "atenção humana",
    reason: itemValue(item, "rationale") ?? "Há contexto autorizado para uma próxima decisão humana.",
    source: itemValue(item, "source") ?? "Ambient Intelligence",
    kind: (itemValue(item, "kind") as AmbientLeaderPriority["kind"] | null) ?? attentionKind(item),
    epistemic: itemValue(item, "epistemic_kind") ?? "contexto autorizado",
  }));
}

export function ambientCommitmentTitles(model: AmbientBeeReadModel): string[] {
  return model.evolution.commitments.map((commitment) => commitment.title).filter(Boolean);
}

export function ambientBucketTitles(brief: AmbientAttentionBrief): { fazer: string[]; delegar: string[]; parar: string[] } {
  const titles = (items: readonly Record<string, unknown>[]) => items.map((item) => itemValue(item, "title")).filter((item): item is string => Boolean(item));
  return { fazer: titles(brief.do_items), delegar: titles(brief.delegate_items), parar: titles(brief.stop_items) };
}

export function ambientBeeResponse(model: AmbientBeeReadModel, input: string): string {
  const intent = routeAmbientIntent(input);
  if (!intent) return "A Bee atua neste espaço com prioridades, confirmações, explicações e preparação de ação — sempre com decisão humana.";
  const selected = selectAmbientIntent(model, intent);
  if (intent === "pending_confirmations") {
    const count = Array.isArray(selected) ? selected.length : 0;
    return count ? `Preciso de alguns segundos seus: há ${count} confirmação(ões) pendente(s) para revisão.` : "Não há confirmação pendente no contexto autorizado.";
  }
  if (intent === "leader_week") {
    return Array.isArray(selected) && selected.length ? `${selected.length} compromisso(s) ou atenção(ões) estão disponíveis para a semana.` : "Ainda não há contexto autorizado suficiente para a semana.";
  }
  if (intent === "leader_evolution") {
    return model.evolution.commitments.length ? `${model.evolution.commitments.length} compromisso(s) de liderança estão registrados para acompanhamento.` : "Ainda não há compromissos de evolução autorizados.";
  }
  if (model.brief.context_status === "insufficient") return model.brief.insufficiency_reason ?? "Ainda não possuo contexto autorizado suficiente.";
  return model.brief.priority_items.length ? `Encontrei ${model.brief.priority_items.length} prioridade(s) autorizada(s), limitadas a três. A decisão continua humana.` : "Não há prioridade autorizada para agora.";
}

export function ambientAttentionById(model: AmbientBeeReadModel, id: string): AmbientAttentionItem | undefined {
  return [...model.today, ...model.week, ...model.pendingConfirmations].find((item) => item.id === id);
}

/** Preview-only fixture. Live compositions must receive the RLS-filtered read model. */
export function createAmbientDemoReadModel(): AmbientBeeReadModel {
  const foundation: AmbientFoundationRead = {
    sources: [], observations: [], reviews: [], preferences: [], briefs: [],
    attention: [
      { id: "demo-attention-1", organization_id: "demo-org", owner_user_id: "demo-user", horizon: "today", attention_type: "review", title: "Revisar uma conversa de desenvolvimento", rationale: "Há contexto autorizado para uma decisão humana.", status: "open", priority: 1, due_at: null, source_observation_id: "demo-observation-1", source_recommendation_id: null, context: {}, human_required: true, visibility_scope: "personal", authorized_roles: [], authorized_user_ids: ["demo-user"], created_by_user_id: "demo-user", created_at: "2026-09-14", updated_at: "2026-09-14" },
      { id: "demo-attention-2", organization_id: "demo-org", owner_user_id: "demo-user", horizon: "today", attention_type: "delegate", title: "Preparar uma delegação", rationale: "O item foi preparado para revisão do líder.", status: "open", priority: 2, due_at: null, source_observation_id: null, source_recommendation_id: null, context: {}, human_required: true, visibility_scope: "personal", authorized_roles: [], authorized_user_ids: ["demo-user"], created_by_user_id: "demo-user", created_at: "2026-09-14", updated_at: "2026-09-14" },
      { id: "demo-confirmation", organization_id: "demo-org", owner_user_id: "demo-user", horizon: "today", attention_type: "confirm", title: "Confirmar o próximo passo", rationale: "Confirmação humana pendente.", status: "open", priority: 3, due_at: null, source_observation_id: null, source_recommendation_id: null, context: {}, human_required: true, visibility_scope: "personal", authorized_roles: [], authorized_user_ids: ["demo-user"], created_by_user_id: "demo-user", created_at: "2026-09-14", updated_at: "2026-09-14" },
    ],
    commitments: [{ id: "demo-commitment", organization_id: "demo-org", owner_user_id: "demo-user", created_by_user_id: "demo-user", title: "Conversa de evolução com o time", context: "Preview de contrato", impact: "Acompanhamento", horizon: "week", status: "planned", due_at: "2026-09-19", provenance: { epistemic_kind: "human_declared" }, created_at: "2026-09-14", updated_at: "2026-09-14" }],
  };
  return prepareAmbientBeeReadModel({ organizationId: "demo-org", userId: "demo-user", role: "gestor", employeeId: "demo-employee" }, foundation);
}
