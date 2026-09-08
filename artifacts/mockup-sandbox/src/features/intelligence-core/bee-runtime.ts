import type { SupabaseSession } from "../../lib/supabase";
import { readDhoContext, type DhoContextItem } from "../dho-intelligence/service";
import {
  readActions,
  readAssessmentEvidence,
  readBeeActionRequests,
  readDecisions,
  readDecisionInterventions,
  readDecisionRevisions,
  readEvidence,
  readEvidenceAssessments,
  readInterventions,
  readKnowledgeDocuments,
  readKnowledgeSources,
  readOrganizationalEvents,
  readOrganizationalMemoryRelations,
  readOrganizationalReadingHypotheses,
  readOrganizationalReadingSources,
  readOrganizationalReadings,
  readOutcomes,
  readRecommendationAssessments,
  readRecommendationEvidence,
  readRecommendationHypotheses,
  readRecommendationReadings,
  readRecommendationRevisions,
  readRecommendations,
  readSignals,
} from "./service";
import type {
  IntelligenceAction,
  IntelligenceDecision,
  IntelligenceDecisionIntervention,
  IntelligenceDecisionRevision,
  IntelligenceEvidence,
  IntelligenceEvidenceAssessment,
  IntelligenceEvidenceAssessmentEvidence,
  IntelligenceIntervention,
  IntelligenceOutcome,
  IntelligenceRecommendation,
  IntelligenceRecommendationAssessment,
  IntelligenceRecommendationEvidence,
  IntelligenceRecommendationHypothesis,
  IntelligenceRecommendationReading,
  IntelligenceRecommendationRevision,
  IntelligenceReadContext,
  IntelligenceSignal,
  IntelligenceOrganizationalReading,
  IntelligenceOrganizationalReadingHypothesis,
  IntelligenceOrganizationalReadingSource,
  KnowledgeDocument,
  KnowledgeSource,
  OrganizationalEvent,
  OrganizationalMemoryRelation,
  SignalScopeType,
  SignalSensitivity,
} from "./types";

export type BeeUserRole = "platform_admin" | "admin_youb" | "rh" | "diretoria" | "gestor" | "colaborador";
export type BeeAuthorizedScopeType = SignalScopeType | "personal";
export type BeeAuthorizedScope = {
  scopeType: BeeAuthorizedScopeType;
  scopeRefs: readonly string[];
  sensitivity: readonly SignalSensitivity[];
};
export type BeeRuntimeContext = {
  organizationId: string;
  userId: string;
  role: BeeUserRole;
  employeeId: string | null;
  authorizedScopes: readonly BeeAuthorizedScope[];
  sensitivity: readonly SignalSensitivity[];
  purpose: string;
  session: SupabaseSession;
};

export type BeeEntityKind = "FACT" | "DECLARATION" | "READING" | "HYPOTHESIS" | "EVIDENCE" | "RECOMMENDATION" | "DECISION" | "INTERVENTION" | "ACTION" | "OUTCOME";
export type BeeProvenance = { entityType: BeeEntityKind | "ASSESSMENT" | "MEMORY" | "EVENT" | "SOURCE"; entityId: string; relationship?: string; sourceEntityId?: string; };
export type BeeRuntimeFinding = {
  kind: BeeEntityKind | "ASSESSMENT";
  id: string;
  organizationId: string;
  scope: { type: string | null; ref: string | null };
  title: string;
  summary: string;
  status: string | null;
  knowledgeKind?: string | null;
  evidenceState?: string | null;
  unknowns: readonly unknown[];
  limitations: readonly unknown[];
  provenance: readonly BeeProvenance[];
  sensitivity?: SignalSensitivity | null;
  timestamps: { observedAt?: string | null; createdAt?: string | null; updatedAt?: string | null };
  links: readonly BeeProvenance[];
};
export type BeeEvidenceNode = { finding: BeeRuntimeFinding; relation: "supports" | "contradicts" | "neutral"; sourceType: string; sourceId?: string | null; };
export type BeeAssessmentNode = { finding: BeeRuntimeFinding; supportingEvidence: readonly BeeEvidenceNode[]; contradictingEvidence: readonly BeeEvidenceNode[]; };
export type BeeRecommendationNode = { finding: BeeRuntimeFinding; rationale: string | null; alternatives: readonly unknown[]; doNotRecommend: readonly unknown[]; measurementPlan: Record<string, unknown>; approvalRequired: boolean; linkedReadingIds: readonly string[]; linkedAssessmentIds: readonly string[]; linkedHypothesisIds: readonly string[]; linkedEvidence: readonly BeeEvidenceNode[]; };
export type BeeDecisionNode = { finding: BeeRuntimeFinding; recommendationId: string | null; revisionIds: readonly string[]; interventionIds: readonly string[]; };
export type BeeActionNode = { finding: BeeRuntimeFinding; interventionId: string | null; dueAt: string | null; completedAt: string | null; };
export type BeeOutcomeNode = { finding: BeeRuntimeFinding; interventionId: string | null; actionId: string | null; validationStatus: string | null; };
export type BeeInterventionNode = { finding: BeeRuntimeFinding; recommendationId: string | null; decisionId: string | null; };
export type BeeReadingBundle = { finding: BeeRuntimeFinding; readingType: string; hypotheses: readonly BeeRuntimeFinding[]; sources: readonly BeeProvenance[]; evidence: readonly BeeEvidenceNode[]; assessments: readonly BeeAssessmentNode[]; recommendations: readonly BeeRecommendationNode[]; decisions: readonly BeeDecisionNode[]; };
export type BeeMemoryRef = { entityId: string; sourceType: string; relationship: string; knowledgeKind: string; sensitivity: SignalSensitivity; provenance: BeeProvenance[]; };
export type BeeEventRef = { id: string; eventType: string; entityType: string; entityId: string; occurredAt: string; sensitivity: SignalSensitivity; provenance: BeeProvenance[]; };
export type BeeAttentionRule = "open_risk_reading" | "conflicting_evidence" | "insufficient_evidence" | "approval_required" | "decision_pending" | "action_due" | "outcome_pending_measurement";
export type BeeAttentionItem = { rule: BeeAttentionRule; finding: BeeRuntimeFinding; explanation: string; };
export type BeeRuntimeReadModel = { context: Pick<BeeRuntimeContext, "organizationId" | "userId" | "role" | "employeeId" | "purpose">; readings: readonly BeeReadingBundle[]; assessments: readonly BeeAssessmentNode[]; recommendations: readonly BeeRecommendationNode[]; decisions: readonly BeeDecisionNode[]; interventions: readonly BeeInterventionNode[]; actions: readonly BeeActionNode[]; outcomes: readonly BeeOutcomeNode[]; memory: readonly BeeMemoryRef[]; events: readonly BeeEventRef[]; dhoContext?: readonly DhoContextItem[]; attentionToday: readonly BeeAttentionItem[]; };
export type BeeExplanation = { summary: string; whatWeKnow: readonly string[]; whatWeDoNotKnow: readonly string[]; supportingEvidence: readonly BeeEvidenceNode[]; contradictingEvidence: readonly BeeEvidenceNode[]; recommendation: BeeRecommendationNode | null; decision: BeeDecisionNode | null; provenance: readonly BeeProvenance[]; nextAllowedStep: string; };

export const BEE_INTENTS = ["attention_today", "explain_reading", "explain_hypothesis", "explain_evidence", "explain_recommendation", "explain_decision", "list_unknowns", "list_open_readings", "list_actions", "explain_outcome"] as const;
export type BeeIntent = typeof BEE_INTENTS[number];

export function createBeeRuntimeContext(input: BeeRuntimeContext): BeeRuntimeContext {
  if (!input.organizationId || !input.userId || !input.purpose.trim()) throw new Error("Bee Runtime context requires organization, user and purpose.");
  if (input.userId !== input.session.user.id) throw new Error("Bee Runtime user must match the authenticated session user.");
  if (input.role === "colaborador" && !input.employeeId) throw new Error("A collaborator context requires its authorized employee.");
  if (!input.authorizedScopes.every((scope) => scope.scopeRefs.every(Boolean))) throw new Error("Bee authorized scopes must be explicit.");
  return { ...input, authorizedScopes: input.authorizedScopes.map((scope) => ({ ...scope, scopeRefs: [...scope.scopeRefs], sensitivity: [...scope.sensitivity] })), sensitivity: [...input.sensitivity] };
}

export type BeeRuntimeSource = {
  signals: IntelligenceSignal[]; evidence: IntelligenceEvidence[]; recommendations: IntelligenceRecommendation[]; interventions: IntelligenceIntervention[]; actions: IntelligenceAction[]; outcomes: IntelligenceOutcome[]; beeActionRequests: unknown[]; knowledgeSources: KnowledgeSource[]; knowledgeDocuments: KnowledgeDocument[]; organizationalMemoryRelations: OrganizationalMemoryRelation[]; organizationalEvents: OrganizationalEvent[]; decisions: IntelligenceDecision[]; decisionInterventions: IntelligenceDecisionIntervention[]; decisionRevisions: IntelligenceDecisionRevision[]; organizationalReadings: IntelligenceOrganizationalReading[]; organizationalReadingSources: IntelligenceOrganizationalReadingSource[]; organizationalReadingHypotheses: IntelligenceOrganizationalReadingHypothesis[]; evidenceAssessments: IntelligenceEvidenceAssessment[]; assessmentEvidence: IntelligenceEvidenceAssessmentEvidence[]; recommendationReadings: IntelligenceRecommendationReading[]; recommendationAssessments: IntelligenceRecommendationAssessment[]; recommendationHypotheses: IntelligenceRecommendationHypothesis[]; recommendationEvidence: IntelligenceRecommendationEvidence[]; recommendationRevisions: IntelligenceRecommendationRevision[]; dhoContext?: DhoContextItem[];
};

const emptySource = (): BeeRuntimeSource => ({ signals: [], evidence: [], recommendations: [], interventions: [], actions: [], outcomes: [], beeActionRequests: [], knowledgeSources: [], knowledgeDocuments: [], organizationalMemoryRelations: [], organizationalEvents: [], decisions: [], decisionInterventions: [], decisionRevisions: [], organizationalReadings: [], organizationalReadingSources: [], organizationalReadingHypotheses: [], evidenceAssessments: [], assessmentEvidence: [], recommendationReadings: [], recommendationAssessments: [], recommendationHypotheses: [], recommendationEvidence: [], recommendationRevisions: [], dhoContext: [] });
const safe = async <T>(loader: () => Promise<T[]>): Promise<T[]> => { try { return await loader(); } catch { return []; } };

export async function loadBeeRuntimeSource(context: BeeRuntimeContext): Promise<BeeRuntimeSource> {
  const readContext: IntelligenceReadContext = { session: context.session, organizationId: context.organizationId, employeeId: context.employeeId };
  const [signals, evidence, recommendations, interventions, actions, outcomes, beeActionRequests, knowledgeSources, knowledgeDocuments, organizationalMemoryRelations, organizationalEvents, decisions, decisionInterventions, decisionRevisions, organizationalReadings, organizationalReadingSources, organizationalReadingHypotheses, evidenceAssessments, assessmentEvidence, recommendationReadings, recommendationAssessments, recommendationHypotheses, recommendationEvidence, recommendationRevisions, dhoContext] = await Promise.all([
    safe(() => readSignals(readContext)), safe(() => readEvidence(readContext)), safe(() => readRecommendations(readContext)), safe(() => readInterventions(readContext)), safe(() => readActions(readContext)), safe(() => readOutcomes(readContext)), safe(() => readBeeActionRequests(readContext)), safe(() => readKnowledgeSources(readContext)), safe(() => readKnowledgeDocuments(readContext)), safe(() => readOrganizationalMemoryRelations(readContext)), safe(() => readOrganizationalEvents(readContext)), safe(() => readDecisions(readContext)), safe(() => readDecisionInterventions(readContext)), safe(() => readDecisionRevisions(readContext)), safe(() => readOrganizationalReadings(readContext)), safe(() => readOrganizationalReadingSources(readContext)), safe(() => readOrganizationalReadingHypotheses(readContext)), safe(() => readEvidenceAssessments(readContext)), safe(() => readAssessmentEvidence(readContext)), safe(() => readRecommendationReadings(readContext)), safe(() => readRecommendationAssessments(readContext)), safe(() => readRecommendationHypotheses(readContext)), safe(() => readRecommendationEvidence(readContext)), safe(() => readRecommendationRevisions(readContext)), safe(() => readDhoContext(readContext)),
  ]);
  return { ...emptySource(), signals, evidence, recommendations, interventions, actions, outcomes, beeActionRequests, knowledgeSources, knowledgeDocuments, organizationalMemoryRelations, organizationalEvents, decisions, decisionInterventions, decisionRevisions, organizationalReadings, organizationalReadingSources, organizationalReadingHypotheses, evidenceAssessments, assessmentEvidence, recommendationReadings, recommendationAssessments, recommendationHypotheses, recommendationEvidence, recommendationRevisions, dhoContext };
}

const sourceKey = (org: string, id: string) => `${org}:${id}`;
const scopeAllowed = (context: BeeRuntimeContext, type: string | null | undefined, ref: string | null | undefined, personalId?: string | null): boolean => {
  if (context.role === "colaborador") return type === "employee" && ref === context.employeeId;
  return context.authorizedScopes.some((scope) => (scope.scopeType === "organization" && scope.scopeRefs.includes(context.organizationId)) || (scope.scopeType === "personal" && type === "employee" && ref === context.employeeId) || (scope.scopeType === type && !!ref && scope.scopeRefs.includes(ref)));
};
const sensitivityAllowed = (context: BeeRuntimeContext, sensitivity?: SignalSensitivity | null): boolean => !sensitivity || context.sensitivity.includes(sensitivity);
const personalOnly = (context: BeeRuntimeContext) => context.role === "colaborador";
const finding = (kind: BeeEntityKind | "ASSESSMENT", id: string, org: string, scopeType: string | null, scopeRef: string | null, title: string, summary: string, status: string | null, knowledgeKind: string | null, unknowns: readonly unknown[] = [], limitations: readonly unknown[] = [], provenance: readonly BeeProvenance[] = [], sensitivity: SignalSensitivity | null = null, timestamps: BeeRuntimeFinding["timestamps"] = {}, links: readonly BeeProvenance[] = [], evidenceState: string | null = null): BeeRuntimeFinding => ({ kind, id, organizationId: org, scope: { type: scopeType, ref: scopeRef }, title, summary, status, knowledgeKind, evidenceState, unknowns, limitations, provenance, sensitivity, timestamps, links });
const readingProvenance = (reading: IntelligenceOrganizationalReading): BeeProvenance[] => [{ entityType: "READING", entityId: reading.id }];

function allowedSource(context: BeeRuntimeContext, source: { organization_id: string; sensitivity?: SignalSensitivity | null }, scopeType: string | null, scopeRef: string | null, personalId?: string | null) { return source.organization_id === context.organizationId && scopeAllowed(context, scopeType, scopeRef, personalId) && sensitivityAllowed(context, source.sensitivity); }

const entityKey = (type: string, id: string) => `${type.toLowerCase()}:${id}`;
const hasOrganizationScope = (context: BeeRuntimeContext) => context.authorizedScopes.some((scope) => scope.scopeType === "organization" && scope.scopeRefs.includes(context.organizationId));

export function composeBeeReadModel(context: BeeRuntimeContext, source: BeeRuntimeSource, now = new Date()): BeeRuntimeReadModel {
  const readingById = new Map(source.organizationalReadings.filter((item) => allowedSource(context, item, item.scope_type, item.scope_ref)).map((item) => [item.id, item]));
  const hypothesisById = new Map(source.organizationalReadingHypotheses.filter((item) => item.organization_id === context.organizationId && readingById.has(item.reading_id)).map((item) => [item.id, item]));
  const assessmentById = new Map(source.evidenceAssessments.filter((item) => item.organization_id === context.organizationId && readingById.has(item.reading_id)).map((item) => [item.id, item]));
  const assessmentEvidence = source.assessmentEvidence.filter((item) => assessmentById.has(item.assessment_id));
  const recommendationScope = (item: IntelligenceRecommendation) => item.scope_type ?? (item.employee_id ? "employee" : "organization");
  const recommendationRef = (item: IntelligenceRecommendation) => item.scope_ref ?? item.employee_id ?? context.organizationId;
  const recById = new Map(source.recommendations.filter((item) => allowedSource(context, item, recommendationScope(item), recommendationRef(item), item.employee_id)).map((item) => [item.id, item]));
  const recReading = source.recommendationReadings.filter((item) => recById.has(item.recommendation_id) && readingById.has(item.reading_id));
  const recAssessment = source.recommendationAssessments.filter((item) => recById.has(item.recommendation_id) && assessmentById.has(item.assessment_id));
  const recHypothesis = source.recommendationHypotheses.filter((item) => recById.has(item.recommendation_id) && hypothesisById.has(item.hypothesis_id));
  const recEvidence = source.recommendationEvidence.filter((item) => recById.has(item.recommendation_id));
  const authorizedEvidenceIds = new Set<string>([
    ...source.organizationalReadingSources.filter((item) => readingById.has(item.reading_id) && !!item.evidence_id).map((item) => item.evidence_id as string),
    ...assessmentEvidence.map((item) => item.evidence_id),
    ...recEvidence.map((item) => item.evidence_id),
  ]);
  const evidenceById = new Map(source.evidence.filter((item) => item.organization_id === context.organizationId && authorizedEvidenceIds.has(item.id)).map((item) => [item.id, item]));

  const makeEvidence = (item: IntelligenceEvidence, relation: "supports" | "contradicts" | "neutral"): BeeEvidenceNode => ({ finding: finding("EVIDENCE", item.id, item.organization_id, null, null, item.summary, item.summary, null, "observed", [], [], [{ entityType: "EVIDENCE", entityId: item.id }], null, { observedAt: item.observed_at, createdAt: item.created_at, updatedAt: item.updated_at }), relation, sourceType: item.source_type, sourceId: item.source_id });
  const makeAssessment = (assessment: IntelligenceEvidenceAssessment): BeeAssessmentNode => {
    const links = assessmentEvidence.filter((link) => link.assessment_id === assessment.id);
    const support = links.filter((link) => link.evidence_relation === "supports").map((link) => evidenceById.get(link.evidence_id)).filter((item): item is IntelligenceEvidence => !!item).map((item) => makeEvidence(item, "supports"));
    const contradict = links.filter((link) => link.evidence_relation === "contradicts").map((link) => evidenceById.get(link.evidence_id)).filter((item): item is IntelligenceEvidence => !!item).map((item) => makeEvidence(item, "contradicts"));
    const reading = readingById.get(assessment.reading_id);
    const hypothesis = assessment.hypothesis_id ? hypothesisById.get(assessment.hypothesis_id) : undefined;
    return { finding: finding("ASSESSMENT", assessment.id, assessment.organization_id, reading?.scope_type ?? null, reading?.scope_ref ?? null, "Evidence Assessment", assessment.assessment_summary, assessment.status, "interpreted", assessment.unknowns, assessment.limitations, [{ entityType: "ASSESSMENT", entityId: assessment.id, relationship: "assesses", sourceEntityId: assessment.reading_id }], null, { createdAt: assessment.created_at, updatedAt: assessment.updated_at }, hypothesis ? [{ entityType: "HYPOTHESIS", entityId: hypothesis.id, relationship: "assessed" }] : [], assessment.evidence_state), supportingEvidence: support, contradictingEvidence: contradict };
  };
  const assessments = [...assessmentById.values()].map(makeAssessment);
  const makeRecommendation = (recommendation: IntelligenceRecommendation): BeeRecommendationNode => {
    const assessmentIds = recAssessment.filter((item) => item.recommendation_id === recommendation.id).map((item) => item.assessment_id);
    const evidence = recEvidence.filter((item) => item.recommendation_id === recommendation.id).map((item) => { const value = evidenceById.get(item.evidence_id); return value ? makeEvidence(value, item.evidence_relation) : null; }).filter((item): item is BeeEvidenceNode => !!item);
    return { finding: finding("RECOMMENDATION", recommendation.id, recommendation.organization_id, recommendation.scope_type ?? null, recommendation.scope_ref ?? null, recommendation.title, recommendation.rationale ?? recommendation.problem_statement ?? recommendation.title, recommendation.status, "derived", recommendation.unknowns, [], [{ entityType: "RECOMMENDATION", entityId: recommendation.id }], null, { createdAt: recommendation.created_at, updatedAt: recommendation.updated_at }, [
      ...recReading.filter((item) => item.recommendation_id === recommendation.id).map((item) => ({ entityType: "READING" as const, entityId: item.reading_id, relationship: "motivated_by" })),
      ...assessmentIds.map((id) => ({ entityType: "ASSESSMENT" as const, entityId: id, relationship: "based_on" })),
    ], recommendation.evidence_state), rationale: recommendation.rationale ?? null, alternatives: recommendation.alternatives, doNotRecommend: recommendation.do_not_recommend, measurementPlan: recommendation.measurement_plan, approvalRequired: recommendation.approval_required, linkedReadingIds: recReading.filter((item) => item.recommendation_id === recommendation.id).map((item) => item.reading_id), linkedAssessmentIds: assessmentIds, linkedHypothesisIds: recHypothesis.filter((item) => item.recommendation_id === recommendation.id).map((item) => item.hypothesis_id), linkedEvidence: evidence };
  };
  const recommendations = [...recById.values()].map(makeRecommendation);
  const makeDecision = (decision: IntelligenceDecision): BeeDecisionNode => ({ finding: finding("DECISION", decision.id, decision.organization_id, decision.scope_type, decision.scope_ref, "Decision", decision.decision_statement, decision.status, "declared", decision.unknowns, [], [{ entityType: "DECISION", entityId: decision.id }], null, { createdAt: decision.created_at, updatedAt: decision.updated_at }, decision.recommendation_id ? [{ entityType: "RECOMMENDATION", entityId: decision.recommendation_id, relationship: "based_on" }] : []), recommendationId: decision.recommendation_id ?? null, revisionIds: source.decisionRevisions.filter((item) => item.decision_id === decision.id).map((item) => item.id), interventionIds: source.decisionInterventions.filter((item) => item.decision_id === decision.id).map((item) => item.intervention_id) });
  const decisions = source.decisions.filter((item) => item.organization_id === context.organizationId && scopeAllowed(context, item.scope_type, item.scope_ref, item.owner_employee_id)).map(makeDecision);
  const interventionAllowed = (item: IntelligenceIntervention) => {
    if (item.employee_id) return scopeAllowed(context, "employee", item.employee_id, item.employee_id);
    if (item.target_scope_type && item.target_scope_ref) return scopeAllowed(context, item.target_scope_type, item.target_scope_ref);
    if (item.recommendation_id) { const rec = recById.get(item.recommendation_id); return !!rec && scopeAllowed(context, recommendationScope(rec), recommendationRef(rec), rec.employee_id); }
    return hasOrganizationScope(context);
  };
  const interventionNodes = source.interventions.filter((item) => item.organization_id === context.organizationId && interventionAllowed(item)).map((item) => {
    const rec = item.recommendation_id ? recById.get(item.recommendation_id) : undefined;
    const scopeType = item.employee_id ? "employee" : item.target_scope_type ?? rec?.scope_type ?? null;
    const scopeRef = item.employee_id ?? item.target_scope_ref ?? rec?.scope_ref ?? null;
    return { finding: finding("INTERVENTION", item.id, item.organization_id, scopeType, scopeRef, item.title, item.objective ?? item.title, item.status, "derived", [], [], [{ entityType: "INTERVENTION", entityId: item.id }], null, { createdAt: item.created_at, updatedAt: item.updated_at }, item.recommendation_id ? [{ entityType: "RECOMMENDATION", entityId: item.recommendation_id, relationship: "derived_from" }] : []), recommendationId: item.recommendation_id ?? null, decisionId: null };
  });
  const interventionIds = new Set(interventionNodes.map((item) => item.finding.id));
  const actionAllowed = (item: IntelligenceAction) => item.assignee_employee_id ? scopeAllowed(context, "employee", item.assignee_employee_id, item.assignee_employee_id) : hasOrganizationScope(context);
  const actions = source.actions.filter((item) => item.organization_id === context.organizationId && actionAllowed(item)).map((item) => ({ finding: finding("ACTION", item.id, item.organization_id, item.assignee_employee_id ? "employee" : null, item.assignee_employee_id ?? null, item.title, item.title, item.status, "declared", [], [], [{ entityType: "ACTION", entityId: item.id }], null, { createdAt: item.due_at, updatedAt: item.completed_at }, item.intervention_id ? [{ entityType: "INTERVENTION", entityId: item.intervention_id, relationship: "derived_from" }] : []), interventionId: item.intervention_id ?? null, dueAt: item.due_at ?? null, completedAt: item.completed_at ?? null }));
  const actionIds = new Set(actions.map((item) => item.finding.id));
  const outcomes = source.outcomes.filter((item) => item.organization_id === context.organizationId && (item.action_id ? actionIds.has(item.action_id) : item.intervention_id ? interventionIds.has(item.intervention_id) : false)).map((item) => ({ finding: finding("OUTCOME", item.id, item.organization_id, null, null, item.outcome_type, item.details?.summary ? String(item.details.summary) : item.outcome_type, item.status, "observed", [], [], [{ entityType: "OUTCOME", entityId: item.id }], null, { observedAt: item.measured_at, createdAt: item.measured_at }), interventionId: item.intervention_id ?? null, actionId: item.action_id ?? null, validationStatus: item.validation_status ?? null }));
  const readings = [...readingById.values()].map((reading) => {
    const readingHypotheses = [...hypothesisById.values()].filter((item) => item.reading_id === reading.id).map((item) => finding("HYPOTHESIS", item.id, item.organization_id, reading.scope_type, reading.scope_ref, "Hypothesis", item.hypothesis_statement, item.status, item.knowledge_kind, [], [], [{ entityType: "HYPOTHESIS", entityId: item.id, relationship: "investigates", sourceEntityId: reading.id }], null, { createdAt: item.created_at, updatedAt: item.updated_at }));
    const readingAssessments = assessments.filter((item) => assessmentById.get(item.finding.id)?.reading_id === reading.id);
    const readingRecommendations = recommendations.filter((item) => item.linkedReadingIds.includes(reading.id));
    const readingEvidence = readingAssessments.flatMap((item) => [...item.supportingEvidence, ...item.contradictingEvidence]);
    const readingDecisions = decisions.filter((item) => item.recommendationId && readingRecommendations.some((rec) => rec.finding.id === item.recommendationId));
    const sourceRefs = source.organizationalReadingSources.filter((item) => item.reading_id === reading.id).map((item) => item.evidence_id ? ({ entityType: "EVIDENCE" as const, entityId: item.evidence_id, relationship: item.relationship_type }) : item.organizational_event_id ? ({ entityType: "EVENT" as const, entityId: item.organizational_event_id, relationship: item.relationship_type }) : ({ entityType: "SOURCE" as const, entityId: item.knowledge_source_id ?? item.knowledge_document_id ?? item.memory_relation_id ?? item.id, relationship: item.relationship_type }));
    return { finding: finding("READING", reading.id, reading.organization_id, reading.scope_type, reading.scope_ref, reading.title, reading.description, reading.status, reading.knowledge_kind, [], [], readingProvenance(reading), null, { observedAt: reading.detected_at, createdAt: reading.created_at, updatedAt: reading.updated_at }), readingType: reading.reading_type, hypotheses: readingHypotheses, sources: sourceRefs, evidence: readingEvidence, assessments: readingAssessments, recommendations: readingRecommendations, decisions: readingDecisions };
  });
  const authorizedEntityKeys = new Set<string>([
    ...readings.map((item) => entityKey("reading", item.finding.id)), ...readings.flatMap((item) => item.hypotheses.map((hypothesis) => entityKey("hypothesis", hypothesis.id))),
    ...assessments.map((item) => entityKey("evidence_assessment", item.finding.id)), ...[...evidenceById.keys()].map((id) => entityKey("evidence", id)), ...recommendations.map((item) => entityKey("recommendation", item.finding.id)), ...decisions.map((item) => entityKey("decision", item.finding.id)), ...interventionNodes.map((item) => entityKey("intervention", item.finding.id)), ...actions.map((item) => entityKey("action", item.finding.id)), ...outcomes.map((item) => entityKey("outcome", item.finding.id)),
  ]);
  if (hasOrganizationScope(context)) authorizedEntityKeys.add(entityKey("organization", context.organizationId));
  if (context.employeeId) authorizedEntityKeys.add(entityKey("employee", context.employeeId));
  const memory = source.organizationalMemoryRelations.filter((item) => item.organization_id === context.organizationId && sensitivityAllowed(context, item.sensitivity) && authorizedEntityKeys.has(entityKey(item.source_entity_type, item.source_entity_id)) && authorizedEntityKeys.has(entityKey(item.target_entity_type, item.target_entity_id))).map((item) => ({ entityId: item.source_entity_id, sourceType: item.source_type, relationship: item.relationship_type, knowledgeKind: item.knowledge_kind, sensitivity: item.sensitivity, provenance: [{ entityType: "MEMORY" as const, entityId: item.source_entity_id, relationship: item.relationship_type }] }));
  const events = source.organizationalEvents.filter((item) => item.organization_id === context.organizationId && sensitivityAllowed(context, item.sensitivity) && authorizedEntityKeys.has(entityKey(item.entity_type, item.entity_id))).map((item) => ({ id: item.id, eventType: item.event_type, entityType: item.entity_type, entityId: item.entity_id, occurredAt: item.occurred_at, sensitivity: item.sensitivity, provenance: [{ entityType: "EVENT" as const, entityId: item.id }] }));
  const dhoContext = (source.dhoContext ?? []).filter((item) => item.organizationId === context.organizationId && (!context.employeeId || item.employeeId === context.employeeId));
  const model: BeeRuntimeReadModel = { context: { organizationId: context.organizationId, userId: context.userId, role: context.role, employeeId: context.employeeId, purpose: context.purpose }, readings, assessments, recommendations, decisions, interventions: interventionNodes, actions, outcomes, memory, events, dhoContext, attentionToday: [] };
  return { ...model, attentionToday: buildBeeAttentionToday(context, model, 5, now) };
}

export async function readBeeRuntime(context: BeeRuntimeContext, now = new Date()): Promise<BeeRuntimeReadModel> { return composeBeeReadModel(context, await loadBeeRuntimeSource(context), now); }

const statusDate = (finding: BeeRuntimeFinding) => finding.timestamps.observedAt ?? finding.timestamps.updatedAt ?? finding.timestamps.createdAt ?? "";
export function buildBeeAttentionToday(context: BeeRuntimeContext, model: BeeRuntimeReadModel, limit = 5, now = new Date()): BeeAttentionItem[] {
  const items: BeeAttentionItem[] = [];
  for (const reading of model.readings) if ((reading.finding.status === "open" || reading.finding.status === "under_investigation") && reading.readingType === "risk") items.push({ rule: "open_risk_reading", finding: reading.finding, explanation: "Leitura de risco aberta requer atenção." });
  for (const assessment of model.assessments) if (assessment.finding.evidenceState === "conflicting") items.push({ rule: "conflicting_evidence", finding: assessment.finding, explanation: "Há evidências relevantes em direções diferentes." });
  for (const assessment of model.assessments) if (assessment.finding.evidenceState === "insufficient" && assessment.finding.status === "under_investigation") items.push({ rule: "insufficient_evidence", finding: assessment.finding, explanation: "Ainda não há evidência suficiente para uma Recommendation pronta." });
  for (const recommendation of model.recommendations) if (recommendation.approvalRequired && (recommendation.finding.status === "proposed" || recommendation.finding.status === "accepted")) items.push({ rule: "approval_required", finding: recommendation.finding, explanation: "Há uma Recommendation preparada que exige aprovação humana." });
  for (const decision of model.decisions) if (decision.finding.status === "pending_review" || decision.finding.status === "pending_approval") items.push({ rule: "decision_pending", finding: decision.finding, explanation: "Há uma Decision pendente de revisão ou aprovação; ela não é uma ação executada." });
  for (const action of model.actions) if (action.dueAt && new Date(action.dueAt).getTime() <= now.getTime() + 24 * 60 * 60 * 1000 && !action.completedAt) items.push({ rule: "action_due", finding: action.finding, explanation: "Há uma Action existente vencida ou próxima do vencimento." });
  for (const outcome of model.outcomes) if (outcome.validationStatus === "unvalidated") items.push({ rule: "outcome_pending_measurement", finding: outcome.finding, explanation: "Há um Outcome existente ainda não validado." });
  const order: Record<BeeAttentionRule, number> = { open_risk_reading: 1, conflicting_evidence: 2, insufficient_evidence: 3, approval_required: 4, decision_pending: 5, action_due: 6, outcome_pending_measurement: 7 };
  return items.sort((a, b) => order[a.rule] - order[b.rule] || statusDate(b.finding).localeCompare(statusDate(a.finding)) || a.finding.id.localeCompare(b.finding.id)).slice(0, Math.min(5, Math.max(1, Math.floor(limit))));
}

export function routeBeeIntent(input: string): BeeIntent | null { const value = input.trim().toLowerCase().replace(/[?!.]/g, "").replace(/\s+/g, "_"); if ((BEE_INTENTS as readonly string[]).includes(value)) return value as BeeIntent; const aliases: Record<string, BeeIntent> = { "what_deserves_my_attention_today": "attention_today", "explain_a_reading": "explain_reading", "open_readings": "list_open_readings", "unknowns": "list_unknowns", "actions": "list_actions", "explain_a_hypothesis": "explain_hypothesis", "explain_evidence": "explain_evidence", "explain_a_recommendation": "explain_recommendation", "explain_a_decision": "explain_decision", "explain_an_outcome": "explain_outcome" }; return aliases[value] ?? null; }

function hypothesisStatement(hypothesis: BeeRuntimeFinding) { return `Hipótese em investigação: ${hypothesis.summary}`; }
function safeStatement(finding: BeeRuntimeFinding) { if (finding.kind === "HYPOTHESIS") return hypothesisStatement(finding); if (finding.kind === "READING") return `Leitura organizacional registrada: ${finding.summary}`; if (finding.kind === "RECOMMENDATION") return `Recommendation preparada: ${finding.summary}`; if (finding.kind === "DECISION") return `Decision registrada: ${finding.summary}`; if (finding.kind === "ACTION") return finding.status === "completed" ? `Action registrada como concluída: ${finding.summary}` : `Action registrada, sem indicar execução pela Bee: ${finding.summary}`; return finding.summary; }
const emptyExplanation = (summary: string): BeeExplanation => ({ summary, whatWeKnow: [], whatWeDoNotKnow: [], supportingEvidence: [], contradictingEvidence: [], recommendation: null, decision: null, provenance: [], nextAllowedStep: "Nenhuma ação é executada pelo Bee Runtime." });

export function explainReading(model: BeeRuntimeReadModel, readingId: string): BeeExplanation | null { const bundle = model.readings.find((item) => item.finding.id === readingId); if (!bundle) return null; return { summary: safeStatement(bundle.finding), whatWeKnow: [bundle.finding.summary, ...bundle.hypotheses.map(hypothesisStatement), ...bundle.assessments.map((item) => `${item.finding.evidenceState ?? "Estado não informado"}: ${item.finding.summary}`)], whatWeDoNotKnow: [...bundle.assessments.flatMap((item) => item.finding.unknowns.map(String)), ...bundle.assessments.flatMap((item) => item.finding.limitations.map(String))], supportingEvidence: bundle.evidence.filter((item) => item.relation === "supports"), contradictingEvidence: bundle.evidence.filter((item) => item.relation === "contradicts"), recommendation: bundle.recommendations[0] ?? null, decision: bundle.decisions[0] ?? null, provenance: [{ entityType: "READING", entityId: readingId }, ...bundle.sources], nextAllowedStep: bundle.assessments.some((item) => item.finding.evidenceState === "insufficient") ? "Investigar os unknowns e limitations antes de preparar uma Recommendation pronta." : "Revisão humana da Recommendation, se houver, sem execução automática." }; }
export function explainHypothesis(model: BeeRuntimeReadModel, hypothesisId: string): BeeExplanation | null { for (const reading of model.readings) { const hypothesis = reading.hypotheses.find((item) => item.id === hypothesisId); if (hypothesis) return { ...emptyExplanation(hypothesisStatement(hypothesis)), whatWeKnow: [hypothesisStatement(hypothesis)], whatWeDoNotKnow: ["A hipótese não é uma conclusão nem causa confirmada."], recommendation: reading.recommendations[0] ?? null, decision: reading.decisions[0] ?? null, provenance: [{ entityType: "HYPOTHESIS", entityId: hypothesisId }, { entityType: "READING", entityId: reading.finding.id }], nextAllowedStep: "Investigar evidências supporting e contradicting; não tratar a hipótese como fato." }; } return null; }
export function explainEvidence(model: BeeRuntimeReadModel, evidenceId: string): BeeExplanation | null { const matches = model.readings.flatMap((reading) => reading.evidence.filter((item) => item.finding.id === evidenceId)); if (!matches.length) return null; return { ...emptyExplanation(matches[0].finding.summary), whatWeKnow: [matches[0].finding.summary], supportingEvidence: matches.filter((item) => item.relation === "supports"), contradictingEvidence: matches.filter((item) => item.relation === "contradicts"), provenance: matches.flatMap((item) => item.finding.provenance), nextAllowedStep: "Interpretar a evidência dentro do contexto e da avaliação, sem concluir causalidade automaticamente." }; }
export function explainRecommendation(model: BeeRuntimeReadModel, recommendationId: string): BeeExplanation | null { const recommendation = model.recommendations.find((item) => item.finding.id === recommendationId); if (!recommendation) return null; return { summary: safeStatement(recommendation.finding), whatWeKnow: [recommendation.finding.summary, `Alternativas consideradas: ${recommendation.alternatives.length}`, `Plano de medição: ${Object.keys(recommendation.measurementPlan).length ? "presente" : "não informado"}`], whatWeDoNotKnow: recommendation.finding.unknowns.map(String), supportingEvidence: recommendation.linkedEvidence.filter((item) => item.relation === "supports"), contradictingEvidence: recommendation.linkedEvidence.filter((item) => item.relation === "contradicts"), recommendation, decision: model.decisions.find((item) => item.recommendationId === recommendationId) ?? null, provenance: recommendation.finding.links, nextAllowedStep: recommendation.approvalRequired ? "Aguardar aprovação humana; a Recommendation não é uma Decision." : "Revisão humana posterior; nenhuma execução é feita pelo Bee Runtime." }; }
export function explainDecision(model: BeeRuntimeReadModel, decisionId: string): BeeExplanation | null { const decision = model.decisions.find((item) => item.finding.id === decisionId); if (!decision) return null; return { ...emptyExplanation(`Decision registrada: ${decision.finding.summary}`), whatWeKnow: ["Decision registrada", decision.finding.summary], whatWeDoNotKnow: decision.finding.unknowns.map(String), decision, recommendation: decision.recommendationId ? model.recommendations.find((item) => item.finding.id === decision.recommendationId) ?? null : null, provenance: decision.finding.provenance, nextAllowedStep: "Verificar separadamente Intervention, Action e Outcome; Decision não significa ação executada." }; }
export function listUnknowns(model: BeeRuntimeReadModel): readonly string[] { return [...new Set([...model.assessments.flatMap((item) => item.finding.unknowns.map(String)), ...model.recommendations.flatMap((item) => item.finding.unknowns.map(String))])]; }
export function listOpenReadings(model: BeeRuntimeReadModel): readonly BeeReadingBundle[] { return model.readings.filter((item) => item.finding.status === "open" || item.finding.status === "under_investigation"); }
export function listActions(model: BeeRuntimeReadModel): readonly BeeActionNode[] { return model.actions; }
export function explainOutcome(model: BeeRuntimeReadModel, outcomeId: string): BeeExplanation | null { const outcome = model.outcomes.find((item) => item.finding.id === outcomeId); if (!outcome) return null; return { ...emptyExplanation(`Outcome registrado: ${outcome.finding.summary}`), whatWeKnow: [outcome.finding.summary], whatWeDoNotKnow: outcome.validationStatus === "unvalidated" ? ["Outcome ainda não validado."] : [], provenance: outcome.finding.provenance, nextAllowedStep: "Medir e validar o Outcome conforme o contrato existente; não atribuir causalidade automaticamente." }; }

export type BeeIntentResult = { intent: BeeIntent; attention?: readonly BeeAttentionItem[]; explanation?: BeeExplanation | null; readings?: readonly BeeReadingBundle[]; actions?: readonly BeeActionNode[]; unknowns?: readonly string[]; };
export function handleBeeIntent(model: BeeRuntimeReadModel, intent: BeeIntent, targetId?: string): BeeIntentResult { switch (intent) { case "attention_today": return { intent, attention: model.attentionToday }; case "list_open_readings": return { intent, readings: listOpenReadings(model) }; case "list_actions": return { intent, actions: listActions(model) }; case "list_unknowns": return { intent, unknowns: listUnknowns(model) }; case "explain_reading": return { intent, explanation: targetId ? explainReading(model, targetId) : null }; case "explain_hypothesis": return { intent, explanation: targetId ? explainHypothesis(model, targetId) : null }; case "explain_evidence": return { intent, explanation: targetId ? explainEvidence(model, targetId) : null }; case "explain_recommendation": return { intent, explanation: targetId ? explainRecommendation(model, targetId) : null }; case "explain_decision": return { intent, explanation: targetId ? explainDecision(model, targetId) : null }; case "explain_outcome": return { intent, explanation: targetId ? explainOutcome(model, targetId) : null }; } return { intent }; }
