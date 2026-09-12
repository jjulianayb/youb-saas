import test from "node:test";
import assert from "node:assert/strict";
import { buildDetailChain, buildExecutiveSnapshot, getNavigableHomeModules, listDueActionsForHome, listOpenReadingsForHome, roleCanSeeExecutiveHome } from "./ExecutiveHome";
import { buildBeeAttentionToday, type BeeAttentionItem, type BeeRuntimeReadModel } from "../../features/intelligence-core/bee-runtime";

const finding = (id: string, kind: BeeAttentionItem["finding"]["kind"], status = "open") => ({ id, kind, organizationId: "org-a", scope: { type: "organization", ref: "org-a" }, title: id, summary: id, status, knowledgeKind: "declared", unknowns: [], limitations: [], provenance: [{ entityType: kind, entityId: id }], sensitivity: null, timestamps: {}, links: [] }) as never;
const model = (overrides: Partial<BeeRuntimeReadModel> = {}): BeeRuntimeReadModel => ({ context: { organizationId: "org-a", userId: "user-a", role: "diretoria", employeeId: null, purpose: "executive_home" }, readings: [], assessments: [], recommendations: [], decisions: [], interventions: [], actions: [], outcomes: [], memory: [], events: [], attentionToday: [], ...overrides });
const reading = (id: string, status: string) => ({ finding: finding(id, "READING", status), readingType: "risk", hypotheses: [], sources: [], evidence: [], assessments: [], recommendations: [], decisions: [] }) as never;
const fullChainFixture = () => {
  const readingFinding = finding("reading-chain", "READING"); const hypothesisFinding = finding("hyp-chain", "HYPOTHESIS", "under_investigation"); const evidenceFinding = finding("evidence-chain", "EVIDENCE", "observed"); const assessmentFinding = finding("assessment-chain", "ASSESSMENT", "assessed"); const recommendationFinding = finding("rec-chain", "RECOMMENDATION", "proposed"); const decisionFinding = finding("decision-chain", "DECISION", "pending_review"); const interventionFinding = finding("int-chain", "INTERVENTION", "draft"); const actionFinding = finding("action-chain", "ACTION", "in_progress"); const outcomeFinding = finding("outcome-chain", "OUTCOME", "observed");
  const evidence = { finding: evidenceFinding, relation: "supports", sourceType: "metric" } as never; const assessment = { finding: assessmentFinding, supportingEvidence: [evidence], contradictingEvidence: [] } as never; const recommendation = { finding: recommendationFinding, recommendationId: null, linkedReadingIds: ["reading-chain"], linkedAssessmentIds: ["assessment-chain"], linkedHypothesisIds: ["hyp-chain"], linkedEvidence: [evidence], approvalRequired: true, rationale: null, alternatives: [], doNotRecommend: [], measurementPlan: {} } as never; const decision = { finding: decisionFinding, recommendationId: "rec-chain", revisionIds: [], interventionIds: ["int-chain"] } as never; const intervention = { finding: interventionFinding, recommendationId: "rec-chain", decisionId: null } as never; const action = { finding: actionFinding, interventionId: "int-chain", dueAt: null, completedAt: null } as never; const outcome = { finding: outcomeFinding, interventionId: "int-chain", actionId: "action-chain", validationStatus: "unvalidated" } as never;
  const result = model({ readings: [{ finding: readingFinding, readingType: "risk", hypotheses: [hypothesisFinding], sources: [], evidence: [evidence], assessments: [assessment], recommendations: [recommendation], decisions: [decision] }], assessments: [assessment], recommendations: [recommendation], decisions: [decision], interventions: [intervention], actions: [action], outcomes: [outcome] });
  return { result, readingFinding, assessmentFinding, decisionFinding, actionFinding, outcomeFinding };
};

test("openReadings uses one explicit collection and excludes resolved or archived readings", () => {
  const result = listOpenReadingsForHome(model({ readings: [reading("open", "open"), reading("investigating", "under_investigation"), reading("resolved", "resolved"), reading("archived", "archived")] }));
  assert.deepEqual(result.map((item) => item.finding.id), ["open", "investigating"]);
  assert.equal(buildExecutiveSnapshot(model({ readings: [reading("resolved", "resolved")] }), new Date("2026-09-02T00:00:00Z")).openReadings, 0);
});

test("due actions match the Runtime 24-hour window", () => {
  const now = new Date("2026-09-02T00:00:00Z");
  const actions = [
    { finding: finding("overdue", "ACTION", "in_progress"), dueAt: "2026-09-01T23:00:00Z", completedAt: null },
    { finding: finding("soon", "ACTION", "in_progress"), dueAt: "2026-09-02T20:00:00Z", completedAt: null },
    { finding: finding("distant", "ACTION", "in_progress"), dueAt: "2026-09-09T00:00:00Z", completedAt: null },
    { finding: finding("done", "ACTION", "completed"), dueAt: "2026-09-02T10:00:00Z", completedAt: "2026-09-01T10:00:00Z" },
  ] as never;
  assert.deepEqual(listDueActionsForHome(model({ actions }), now).map((item) => item.finding.id), ["overdue", "soon"]);
  assert.equal(buildExecutiveSnapshot(model({ actions }), now).actionsDue, 2);
});

test("role, limit and module navigation remain guarded", () => {
  assert.equal(roleCanSeeExecutiveHome("colaborador"), false);
  assert.equal(roleCanSeeExecutiveHome("diretoria"), true);
  const five = Array.from({ length: 6 }, (_, index) => ({ finding: finding(`p-${index}`, "ACTION", "in_progress"), dueAt: "2026-09-02T01:00:00Z", completedAt: null })) as never;
  assert.equal(buildBeeAttentionToday({} as never, model({ actions: five }), 5, new Date("2026-09-02T00:00:00Z")).length, 5);
  assert.deepEqual(getNavigableHomeModules([{ label: "Pessoas", path: null }, { label: "Avaliações", path: "/avaliacoes" }]), [{ label: "Avaliações", path: "/avaliacoes" }]);
  assert.deepEqual(getNavigableHomeModules(), []);
});

test("detail chain follows only explicit links and reports absent links", () => {
  const readingFinding = finding("reading-a", "READING");
  const hypothesisFinding = finding("hyp-a", "HYPOTHESIS", "under_investigation");
  const evidenceFinding = finding("evidence-a", "EVIDENCE", "observed");
  const assessmentFinding = finding("assessment-a", "ASSESSMENT", "assessed");
  const recommendationFinding = finding("rec-a", "RECOMMENDATION", "proposed");
  const decisionFinding = finding("decision-a", "DECISION", "pending_review");
  const interventionFinding = finding("int-a", "INTERVENTION", "draft");
  const actionFinding = finding("action-a", "ACTION", "in_progress");
  const outcomeFinding = finding("outcome-a", "OUTCOME", "observed");
  const evidence = { finding: evidenceFinding, relation: "supports", sourceType: "metric" } as never;
  const assessment = { finding: assessmentFinding, supportingEvidence: [evidence], contradictingEvidence: [] } as never;
  const recommendation = { finding: recommendationFinding, recommendationId: null, linkedReadingIds: ["reading-a"], linkedAssessmentIds: ["assessment-a"], linkedHypothesisIds: ["hyp-a"], linkedEvidence: [evidence], approvalRequired: true, rationale: null, alternatives: [], doNotRecommend: [], measurementPlan: {} } as never;
  const decision = { finding: decisionFinding, recommendationId: "rec-a", revisionIds: [], interventionIds: ["int-a"] } as never;
  const intervention = { finding: interventionFinding, recommendationId: "rec-a", decisionId: null } as never;
  const action = { finding: actionFinding, interventionId: "int-a", dueAt: null, completedAt: null } as never;
  const outcome = { finding: outcomeFinding, interventionId: "int-a", actionId: "action-a", validationStatus: "unvalidated" } as never;
  const result = model({ readings: [{ finding: readingFinding, readingType: "risk", hypotheses: [hypothesisFinding], sources: [], evidence: [evidence], assessments: [assessment], recommendations: [recommendation], decisions: [decision] }], assessments: [assessment], recommendations: [recommendation], decisions: [decision], interventions: [intervention], actions: [action], outcomes: [outcome] });
  const chain = buildDetailChain(result, outcomeFinding);
  assert.deepEqual(Object.fromEntries(Object.entries(chain).map(([key, items]) => [key, items.map((item) => item.finding.id)])), { reading: ["reading-a"], hypothesis: ["hyp-a"], evidence: ["evidence-a"], assessment: ["assessment-a"], recommendation: ["rec-a"], decision: ["decision-a"], intervention: ["int-a"], action: ["action-a"], outcome: ["outcome-a"] });
  const unrelated = buildDetailChain(model({ readings: [reading("other", "open")] }), finding("action-unrelated", "ACTION", "in_progress"));
  assert.equal(unrelated.reading.length, 0);
  assert.equal(unrelated.recommendation.length, 0);
});

test("Decision.interventionIds resolves Intervention when intervention.decisionId is null", () => {
  const decisionFinding = finding("decision-only", "DECISION", "pending_review");
  const interventionFinding = finding("int-from-decision", "INTERVENTION", "draft");
  const decision = { finding: decisionFinding, recommendationId: null, revisionIds: [], interventionIds: ["int-from-decision"] } as never;
  const intervention = { finding: interventionFinding, recommendationId: null, decisionId: null } as never;
  const chain = buildDetailChain(model({ decisions: [decision], interventions: [intervention] }), decisionFinding);
  assert.deepEqual(chain.decision.map((item) => item.finding.id), ["decision-only"]);
  assert.deepEqual(chain.intervention.map((item) => item.finding.id), ["int-from-decision"]);
});

test("Decision chain continues through explicit Intervention → Action → Outcome links", () => {
  const decisionFinding = finding("decision-downstream", "DECISION", "pending_review");
  const interventionFinding = finding("int-a", "INTERVENTION", "draft");
  const actionFinding = finding("action-a", "ACTION", "in_progress");
  const outcomeFinding = finding("outcome-a", "OUTCOME", "observed");
  const decision = { finding: decisionFinding, recommendationId: null, revisionIds: [], interventionIds: ["int-a"] } as never;
  const intervention = { finding: interventionFinding, recommendationId: null, decisionId: null } as never;
  const action = { finding: actionFinding, interventionId: "int-a", dueAt: null, completedAt: null } as never;
  const outcome = { finding: outcomeFinding, interventionId: "int-a", actionId: "action-a", validationStatus: "unvalidated" } as never;
  const chain = buildDetailChain(model({ decisions: [decision], interventions: [intervention], actions: [action], outcomes: [outcome] }), decisionFinding);
  assert.deepEqual(chain.decision.map((item) => item.finding.id), ["decision-downstream"]);
  assert.deepEqual(chain.intervention.map((item) => item.finding.id), ["int-a"]);
  assert.deepEqual(chain.action.map((item) => item.finding.id), ["action-a"]);
  assert.deepEqual(chain.outcome.map((item) => item.finding.id), ["outcome-a"]);
  const withoutAction = buildDetailChain(model({ decisions: [decision], interventions: [intervention], outcomes: [outcome] }), decisionFinding);
  assert.deepEqual(withoutAction.action, []);
  assert.deepEqual(withoutAction.outcome.map((item) => item.finding.id), ["outcome-a"]);
});

test("Reading selection continues through every explicitly linked downstream node", () => {
  const fixture = fullChainFixture();
  const chain = buildDetailChain(fixture.result, fixture.readingFinding);
  assert.deepEqual(chain.reading.map((item) => item.finding.id), ["reading-chain"]);
  assert.deepEqual(chain.hypothesis.map((item) => item.finding.id), ["hyp-chain"]);
  assert.deepEqual(chain.evidence.map((item) => item.finding.id), ["evidence-chain"]);
  assert.deepEqual(chain.assessment.map((item) => item.finding.id), ["assessment-chain"]);
  assert.deepEqual(chain.recommendation.map((item) => item.finding.id), ["rec-chain"]);
  assert.deepEqual(chain.decision.map((item) => item.finding.id), ["decision-chain"]);
  assert.deepEqual(chain.intervention.map((item) => item.finding.id), ["int-chain"]);
  assert.deepEqual(chain.action.map((item) => item.finding.id), ["action-chain"]);
  assert.deepEqual(chain.outcome.map((item) => item.finding.id), ["outcome-chain"]);
});

test("Assessment selection resolves Recommendation through linkedAssessmentIds", () => {
  const fixture = fullChainFixture();
  const chain = buildDetailChain(fixture.result, fixture.assessmentFinding);
  assert.deepEqual(chain.assessment.map((item) => item.finding.id), ["assessment-chain"]);
  assert.deepEqual(chain.recommendation.map((item) => item.finding.id), ["rec-chain"]);
  assert.deepEqual(chain.decision.map((item) => item.finding.id), ["decision-chain"]);
  assert.deepEqual(chain.intervention.map((item) => item.finding.id), ["int-chain"]);
  assert.deepEqual(chain.action.map((item) => item.finding.id), ["action-chain"]);
  assert.deepEqual(chain.outcome.map((item) => item.finding.id), ["outcome-chain"]);
});

test("Action selection resolves Decision without inventing Recommendation", () => {
  const fixture = fullChainFixture();
  const decisionOnlyInterventions = fixture.result.interventions.map((item) => ({ ...item, recommendationId: null })) as never;
  const actionOnly = model({ decisions: fixture.result.decisions, interventions: decisionOnlyInterventions, actions: fixture.result.actions, outcomes: fixture.result.outcomes });
  const chain = buildDetailChain(actionOnly, fixture.actionFinding);
  assert.deepEqual(chain.decision.map((item) => item.finding.id), ["decision-chain"]);
  assert.deepEqual(chain.intervention.map((item) => item.finding.id), ["int-chain"]);
  assert.deepEqual(chain.action.map((item) => item.finding.id), ["action-chain"]);
  assert.deepEqual(chain.outcome.map((item) => item.finding.id), ["outcome-chain"]);
  assert.deepEqual(chain.recommendation, []);
});

test("Outcome selection follows explicit Action and Intervention links without inventing Recommendation", () => {
  const fixture = fullChainFixture();
  const decisionOnlyInterventions = fixture.result.interventions.map((item) => ({ ...item, recommendationId: null })) as never;
  const outcomeOnly = model({ decisions: fixture.result.decisions, interventions: decisionOnlyInterventions, actions: fixture.result.actions, outcomes: fixture.result.outcomes });
  const chain = buildDetailChain(outcomeOnly, fixture.outcomeFinding);
  assert.deepEqual(chain.decision.map((item) => item.finding.id), ["decision-chain"]);
  assert.deepEqual(chain.intervention.map((item) => item.finding.id), ["int-chain"]);
  assert.deepEqual(chain.action.map((item) => item.finding.id), ["action-chain"]);
  assert.deepEqual(chain.outcome.map((item) => item.finding.id), ["outcome-chain"]);
  assert.deepEqual(chain.recommendation, []);
});
