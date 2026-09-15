import ExecutiveDesktopHome from "./ExecutiveDesktopHome";
import type { BeeRuntimeContext, BeeRuntimeFinding, BeeRuntimeReadModel, BeeAttentionItem } from "../../features/intelligence-core/bee-runtime";
import type { SupabaseSession } from "../../lib/supabase";

const session = { access_token: "qa-preview", refresh_token: "qa-preview", expires_at: Math.floor(Date.now() / 1000) + 3600, user: { id: "qa-user", email: "preview@youb.invalid" } } as SupabaseSession;
const finding = (id: string, title: string, summary: string, evidenceState?: string): BeeRuntimeFinding => ({ kind: "READING", id, organizationId: "qa-org", scope: { type: "organization", ref: "qa-org" }, title, summary, status: "open", evidenceState: evidenceState ?? "strong", unknowns: [], limitations: [], provenance: [{ entityType: "READING", entityId: id }], timestamps: { observedAt: "2026-09-14T12:00:00Z" }, links: [] });
const first = finding("qa-retention", "Risco de retenção em líderes estratégicos", "18% dos líderes estratégicos apresentam sinais de risco nos próximos 6 meses.");
const second = finding("qa-succession", "Prontidão sucessória em queda", "72% dos cargos críticos ainda não possuem sucessores prontos no curto prazo.", "moderate");
const third = finding("qa-leadership", "Capacidade de liderança em desenvolvimento", "32% da liderança apresenta oportunidade de desenvolvimento.", "moderate");
const attentionToday: BeeAttentionItem[] = [
  { rule: "open_risk_reading", finding: first, explanation: "Leitura prioritária com evidência registrada." },
  { rule: "insufficient_evidence", finding: second, explanation: "Aprofundar a leitura antes de decidir." },
  { rule: "approval_required", finding: third, explanation: "Revisão humana recomendada." },
];
const model = { context: { organizationId: "qa-org", userId: "qa-user", role: "diretoria", employeeId: null, purpose: "executive_home" }, readings: [{ finding: first, readingType: "risk", hypotheses: [], sources: [], evidence: [], assessments: [], recommendations: [], decisions: [] }], assessments: [], recommendations: [], decisions: [{ finding: { ...finding("qa-decision", "Reter líderes críticos", "Aprovar plano de retenção para líderes estratégicos.", "strong"), kind: "DECISION", status: "pending_review" }, recommendationId: null, revisionIds: [], interventionIds: [] }], interventions: [], actions: [], outcomes: [], memory: [], events: [{ id: "qa-event-1", eventType: "Aumento no risco de retenção", entityType: "READING", entityId: first.id, occurredAt: "2026-09-14T12:00:00Z", sensitivity: "standard", provenance: [] }], attentionToday } as unknown as BeeRuntimeReadModel;
const runtimeContext = { organizationId: "qa-org", userId: "qa-user", role: "diretoria", employeeId: null, authorizedScopes: [{ scopeType: "organization", scopeRefs: ["qa-org"], sensitivity: ["standard"] }], sensitivity: ["standard"], purpose: "executive_home", session } as BeeRuntimeContext;

export default function ExecutiveDesktopPreview() { return <ExecutiveDesktopHome displayName="Alex" organizationName="Organização de preview" runtimeContext={runtimeContext} model={model} onIntent={() => undefined} />; }
