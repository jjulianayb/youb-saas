import type { SupabaseSession } from "../../lib/supabase";

export type IntelligenceStatus = "observed" | "investigating" | "corroborated" | "dismissed" | "resolved" | "draft" | "proposed" | "accepted" | "rejected" | "expired" | "approved" | "in_progress" | "completed" | "cancelled" | "confirmed";
export type KnowledgeAccessLevel = "organization" | "management" | "restricted";
export type KnowledgeDocumentStatus = "draft" | "published" | "archived";
export type SignalFamily = "performance" | "development" | "leadership" | "experience" | "talent" | "work" | "knowledge" | "organization";
export type SignalNature = "risk" | "opportunity" | "change" | "anomaly";
export type SignalScopeType = "employee" | "team" | "area" | "position" | "process" | "unit" | "organization";
export type SignalDirection = "improving" | "deteriorating" | "anomalous" | "mixed" | "neutral";
export type SignalPersistence = "isolated" | "recurring" | "trend";
export type SignalImpactLevel = "low" | "moderate" | "high" | "critical";
export type SignalSensitivity = "standard" | "restricted" | "highly_sensitive";
export type SignalStatus = "observed" | "investigating" | "corroborated" | "dismissed" | "resolved";
export type EvidenceType = "quantitative" | "qualitative" | "behavioral" | "operational" | "business" | "documented";
export type EvidenceRelation = "supports" | "contradicts" | "neutral";
export type RecommendationType = "investigate" | "intervene" | "maintain" | "replicate" | "monitor" | "no_action";
export type EvidenceState = "insufficient" | "moderate" | "strong";
export type RecommendationScopeType = SignalScopeType;
export type InterventionFamily = "investigation" | "learning" | "mentoring" | "coaching" | "leadership" | "process" | "work_design" | "communication" | "recognition" | "career" | "succession" | "mobility" | "structure" | "people_practice" | "consulting" | "none";
export type IntelligenceReadContext = { session: SupabaseSession; organizationId: string; employeeId?: string | null };
export type IntelligenceSignal = { id: string; organization_id: string; employee_id?: string | null; signal_type: string; signal_family?: SignalFamily | null; signal_nature?: SignalNature | null; scope_type?: SignalScopeType | null; scope_ref?: string | null; direction?: SignalDirection | null; persistence?: SignalPersistence | null; impact_level?: SignalImpactLevel | null; sensitivity?: SignalSensitivity | null; window_start?: string | null; window_end?: string | null; context: Record<string, unknown>; observed_at: string; value: Record<string, unknown>; source_type: string; source_id?: string | null; status: SignalStatus; created_by?: string | null; created_at: string; updated_at: string; };
export type IntelligenceEvidence = { id: string; organization_id: string; signal_id?: string | null; evidence_type: EvidenceType; summary: string; payload: Record<string, unknown>; source_type: string; source_id?: string | null; observed_at?: string | null; relation: EvidenceRelation; independence_group?: string | null; created_by?: string | null; created_at: string; updated_at: string; };
export type IntelligenceRecommendation = { id: string; organization_id: string; employee_id?: string | null; title: string; rationale?: string | null; status: IntelligenceStatus; source_evidence_ids: string[]; recommendation_type?: RecommendationType | null; scope_type?: RecommendationScopeType | null; scope_ref?: string | null; evidence_state?: EvidenceState | null; problem_statement?: string | null; unknowns: unknown[]; recommended_intervention_type?: string | null; alternatives: unknown[]; do_not_recommend: unknown[]; expected_outcome?: string | null; measurement_plan: Record<string, unknown>; estimated_cost?: number | null; currency?: string | null; owner_employee_id?: string | null; approval_required: boolean; approved_by?: string | null; approved_at?: string | null; follow_up_at?: string | null; context: Record<string, unknown>; created_by?: string | null; reviewed_by?: string | null; reviewed_at?: string | null; created_at: string; updated_at: string; };
export type IntelligenceIntervention = { id: string; organization_id: string; recommendation_id?: string | null; employee_id?: string | null; intervention_type: string; intervention_family?: InterventionFamily | null; title: string; plan: Record<string, unknown>; objective?: string | null; target_scope_type?: SignalScopeType | null; target_scope_ref?: string | null; success_criteria: unknown[]; measurement_plan: Record<string, unknown>; estimated_cost?: number | null; currency?: string | null; starts_at?: string | null; expected_end_at?: string | null; follow_up_at?: string | null; requires_human_approval: boolean; context: Record<string, unknown>; status: IntelligenceStatus; owner_employee_id?: string | null; created_by?: string | null; approved_by?: string | null; approved_at?: string | null; created_at: string; updated_at: string; };
export type IntelligenceAction = { id: string; organization_id: string; intervention_id?: string | null; action_type: string; title: string; details: Record<string, unknown>; status: IntelligenceStatus; assignee_employee_id?: string | null; due_at?: string | null; completed_at?: string | null; };
export type BeeActionCapabilityLevel = "observe" | "explain" | "ask" | "recommend" | "prepare" | "execute";
export type BeeActionRiskLevel = "informational" | "personal_reversible" | "operational" | "sensitive" | "prohibited_autonomous";
export type BeeActionAuthorizationRequirement = "none" | "confirmation" | "approval" | "prohibited";
export type BeeActionAuthorizationStatus = "not_required" | "awaiting_confirmation" | "awaiting_approval" | "approved" | "rejected" | "expired";
export type BeeActionExecutionStatus = "not_started" | "ready" | "executing" | "completed" | "failed" | "cancelled";
export type BeeActionRequest = { id: string; organization_id: string; requester_user_id: string; requester_employee_id?: string | null; source_recommendation_id?: string | null; source_intervention_id?: string | null; source_action_id?: string | null; action_key: string; capability_level: BeeActionCapabilityLevel; risk_level: BeeActionRiskLevel; authorization_requirement: BeeActionAuthorizationRequirement; purpose: string; target_scope_type: SignalScopeType; target_scope_ref?: string | null; target_employee_id?: string | null; sensitivity: SignalSensitivity; authorization_status: BeeActionAuthorizationStatus; execution_status: BeeActionExecutionStatus; confirmed_by?: string | null; confirmed_at?: string | null; approved_by?: string | null; approved_at?: string | null; request_payload: Record<string, unknown>; execution_payload: Record<string, unknown>; execution_result: Record<string, unknown>; failure_reason?: string | null; correlation_id: string; executed_at?: string | null; created_at: string; updated_at: string; };
export type OutcomeLevel = "execution" | "learning" | "application" | "capability" | "people" | "business" | "financial";
export type OutcomeClaimStrength = "observed" | "associated" | "contribution_supported" | "causal_validated";
export type OutcomeMeasurementKind = "measured" | "estimated";
export type OutcomeValidationStatus = "unvalidated" | "reviewed" | "validated";
export type IntelligenceOutcome = { id: string; organization_id: string; intervention_id?: string | null; action_id?: string | null; outcome_type: string; status: IntelligenceStatus; details: Record<string, unknown>; measured_at: string; outcome_level?: OutcomeLevel | null; claim_strength?: OutcomeClaimStrength | null; measurement_kind?: OutcomeMeasurementKind | null; validation_status?: OutcomeValidationStatus | null; metric_key?: string | null; metric_label?: string | null; metric_unit?: string | null; baseline_value?: number | null; observed_value?: number | null; delta_value?: number | null; baseline_at?: string | null; window_start?: string | null; window_end?: string | null; data_source_type?: string | null; data_source_id?: string | null; measurement_methodology?: string | null; attribution_note?: string | null; financial_value?: number | null; currency?: string | null; validated_by?: string | null; validated_at?: string | null; context: Record<string, unknown>; };
export type KnowledgeSource = { id: string; organization_id: string; source_type: string; name: string; owner_user_id?: string | null; access_level: KnowledgeAccessLevel; status: "active" | "archived"; };
export type KnowledgeDocument = { id: string; organization_id: string; knowledge_source_id?: string | null; document_type: string; title: string; version: string; status: KnowledgeDocumentStatus; valid_from?: string | null; valid_until?: string | null; content?: string | null; storage_path?: string | null; access_level: KnowledgeAccessLevel; owner_user_id?: string | null; };


export type OrganizationalMemoryEntityType = "fact" | "declaration" | "reading" | "hypothesis" | "decision" | "intervention" | "outcome" | "employee" | "area" | "position" | "unit" | "organization" | "feedback" | "checkin" | "pdi" | "assessment" | "recommendation" | "action" | "event" | "evidence_assessment";
export type OrganizationalMemoryRelationshipType = "supports" | "contradicts" | "derived_from" | "declares" | "observes" | "concerns" | "manages" | "belongs_to" | "affects" | "led_to" | "requires" | "related_to";
export type OrganizationalMemoryKnowledgeKind = "fact" | "declared" | "observed" | "derived" | "interpreted" | "hypothesis";
export type OrganizationalMemorySourceType = "manual" | "system" | "service" | "bee" | "import" | "integration";
export type OrganizationalMemoryRelation = { id: string; organization_id: string; source_entity_type: OrganizationalMemoryEntityType; source_entity_id: string; target_entity_type: OrganizationalMemoryEntityType; target_entity_id: string; relationship_type: OrganizationalMemoryRelationshipType; knowledge_kind: OrganizationalMemoryKnowledgeKind; valid_from: string; valid_until?: string | null; recorded_at: string; source_type: OrganizationalMemorySourceType; source_id?: string | null; sensitivity: SignalSensitivity; context: Record<string, unknown>; created_at: string; };
export type OrganizationalEventType = "employee_created" | "employee_status_changed" | "area_changed" | "position_changed" | "manager_changed" | "feedback_recorded" | "checkin_recorded" | "pdi_created" | "pdi_updated" | "assessment_recorded" | "learning_assigned" | "learning_completed" | "organizational_reading_created" | "recommendation_created" | "decision_recorded" | "intervention_created" | "action_created" | "action_completed" | "outcome_recorded" | "training_assigned" | "training_scheduled" | "training_completed" | "training_expiring" | "training_expired" | "recertification_scheduled";
export type OrganizationalEvent = { id: string; organization_id: string; event_type: OrganizationalEventType; entity_type: OrganizationalMemoryEntityType; entity_id: string; related_entity_type?: OrganizationalMemoryEntityType | null; related_entity_id?: string | null; occurred_at: string; recorded_at: string; source_type: OrganizationalMemorySourceType; source_id?: string | null; actor_user_id?: string | null; sensitivity: SignalSensitivity; payload: Record<string, unknown>; correlation_id?: string | null; created_at: string; };

export type DecisionType = "accept_recommendation" | "select_alternative" | "request_evidence" | "defer" | "reject" | "no_action" | "maintain";
export type DecisionScopeType = SignalScopeType;
export type DecisionRiskLevel = BeeActionRiskLevel;
export type DecisionStatus = "draft" | "pending_review" | "pending_approval" | "decided" | "effective" | "superseded" | "expired" | "cancelled";
export type DecisionApproverRole = "admin_youb" | "rh" | "diretoria";
export type IntelligenceDecision = {
  id: string;
  organization_id: string;
  decision_type: DecisionType;
  scope_type: DecisionScopeType;
  scope_ref: string;
  recommendation_id?: string | null;
  decision_statement: string;
  selected_option?: string | null;
  alternatives_considered: unknown[];
  rationale?: string | null;
  evidence_snapshot: Record<string, unknown>;
  unknowns: unknown[];
  risk_level: DecisionRiskLevel;
  risk_accepted: boolean;
  status: DecisionStatus;
  owner_employee_id?: string | null;
  decision_maker_user_id?: string | null;
  approval_required: boolean;
  required_approver_role?: DecisionApproverRole | null;
  approved_by?: string | null;
  approved_at?: string | null;
  effective_at?: string | null;
  review_at?: string | null;
  supersedes_decision_id?: string | null;
  context: Record<string, unknown>;
  created_at: string;
  updated_at: string;
};
export type IntelligenceDecisionIntervention = {
  id: string;
  organization_id: string;
  decision_id: string;
  intervention_id: string;
  relationship_type: "derived_from_decision";
  context: Record<string, unknown>;
  created_at: string;
};
export type IntelligenceDecisionRevision = {
  id: string;
  organization_id: string;
  decision_id: string;
  revision_number: number;
  changed_by_user_id: string;
  change_reason: string;
  previous_snapshot: Record<string, unknown>;
  new_snapshot: Record<string, unknown>;
  created_at: string;
};

export type OrganizationalReadingType = "movement" | "pattern" | "anomaly" | "risk" | "opportunity" | "tension" | "gap" | "evolution";
export type OrganizationalReadingStatus = "open" | "under_investigation" | "supported" | "dismissed" | "resolved" | "archived";
export type OrganizationalReadingKnowledgeKind = "interpreted";
export type OrganizationalReadingSourceType = "evidence" | "knowledge_source" | "knowledge_document" | "organizational_event" | "memory_relation";
export type OrganizationalReadingSourceRelationship = "supports" | "contradicts" | "contextualizes" | "derived_from" | "observed_in";
export type OrganizationalReadingHypothesisStatus = "proposed" | "under_investigation" | "supported" | "dismissed";
export type IntelligenceOrganizationalReading = {
  id: string; organization_id: string; reading_type: OrganizationalReadingType; scope_type: SignalScopeType; scope_ref: string; title: string; description: string; status: OrganizationalReadingStatus; knowledge_kind: OrganizationalReadingKnowledgeKind; observation_window_start: string; observation_window_end: string; detected_at: string; source_summary: string; context: Record<string, unknown>; created_at: string; updated_at: string;
};
export type IntelligenceOrganizationalReadingSource = {
  id: string; organization_id: string; reading_id: string; source_type: OrganizationalReadingSourceType; evidence_id?: string | null; knowledge_source_id?: string | null; knowledge_document_id?: string | null; organizational_event_id?: string | null; memory_relation_id?: string | null; relationship_type: OrganizationalReadingSourceRelationship; provenance_note?: string | null; context: Record<string, unknown>; created_at: string;
};
export type IntelligenceOrganizationalReadingHypothesis = {
  id: string; organization_id: string; reading_id: string; hypothesis_statement: string; status: OrganizationalReadingHypothesisStatus; knowledge_kind: "hypothesis"; context: Record<string, unknown>; created_by?: string | null; created_at: string; updated_at: string;
};
export type IntelligenceOrganizationalReadingRevision = {
  id: string; organization_id: string; reading_id: string; revision_number: number; changed_by_user_id: string; change_reason: string; previous_snapshot: Record<string, unknown>; new_snapshot: Record<string, unknown>; created_at: string;
};


export type EvidenceAssessmentStatus = "draft" | "under_investigation" | "assessed" | "archived";
export type OperationalEvidenceState = "insufficient" | "weak" | "moderate" | "strong" | "conflicting";
export type EvidenceAssessmentRelation = "supports" | "contradicts";
export type IntelligenceEvidenceAssessment = { id: string; organization_id: string; reading_id: string; hypothesis_id?: string | null; status: EvidenceAssessmentStatus; evidence_state: OperationalEvidenceState; supporting_evidence_count: number; contradicting_evidence_count: number; unknowns: unknown[]; limitations: unknown[]; assessment_summary: string; assessed_by_user_id?: string | null; assessed_at?: string | null; context: Record<string, unknown>; created_at: string; updated_at: string; };
export type IntelligenceEvidenceAssessmentEvidence = { id: string; organization_id: string; assessment_id: string; evidence_id: string; evidence_relation: EvidenceAssessmentRelation; provenance_note?: string | null; context: Record<string, unknown>; created_at: string; };
export type IntelligenceEvidenceAssessmentRevision = { id: string; organization_id: string; assessment_id: string; revision_number: number; changed_by_user_id: string; change_reason: string; previous_snapshot: Record<string, unknown>; new_snapshot: Record<string, unknown>; created_at: string; };
export type RecommendationEvidenceRelation = "supports" | "contradicts";
export type IntelligenceRecommendationReading = { id: string; organization_id: string; recommendation_id: string; reading_id: string; relationship_type: "motivated_by"; context: Record<string, unknown>; created_at: string; };
export type IntelligenceRecommendationAssessment = { id: string; organization_id: string; recommendation_id: string; assessment_id: string; relationship_type: "based_on"; context: Record<string, unknown>; created_at: string; };
export type IntelligenceRecommendationHypothesis = { id: string; organization_id: string; recommendation_id: string; hypothesis_id: string; relationship_type: "considers"; context: Record<string, unknown>; created_at: string; };
export type IntelligenceRecommendationEvidence = { organization_id: string; recommendation_id: string; evidence_id: string; evidence_relation: RecommendationEvidenceRelation; context: Record<string, unknown>; created_at: string; };
export type IntelligenceRecommendationRevision = { id: string; organization_id: string; recommendation_id: string; revision_number: number; changed_by_user_id: string; change_reason: string; previous_snapshot: Record<string, unknown>; new_snapshot: Record<string, unknown>; created_at: string; };
