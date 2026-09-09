import test from "node:test";
import assert from "node:assert/strict";
import { MAX_DHO_DIRECT_REPORTS, buildDhoContextItems, dhoPopulationMode, dhoSourceAvailability, dhoSubjectRequestPlan } from "./service";

test("DHO adapter preserves provenance and rejects no-context as evolution", () => {
  const items = buildDhoContextItems({
    organizationId: "org-a",
    employeeId: "emp-a",
    assessments: [{ id: "assessment-a", organization_id: "org-a", subject_employee_id: "emp-a", cycle_id: "cycle-a", status: "completed" }],
    scores: [{ id: "score-a", organization_id: "org-a", assessment_id: "assessment-a", competency_id: "competency-a", expected_level_snapshot: 4, score: 3 }],
    evolution: [{ source_type: "peer", round_id: "round-a", competency_id: "competency-a", competency_name: "Comunicação", expected_level_snapshot: 4, position_id: "position-a", score: 3, previous_score: null, delta: null, employee_id: "emp-a" }],
    pdis: [{ id: "pdi-a", organization_id: "org-a", employee_id: "emp-a", objective: "Desenvolver comunicação", status: "active" }],
    objectives: [{ id: "objective-a", organization_id: "org-a", pdi_id: "pdi-a", title: "Objetivo humano", success_criteria: "Critério explícito", status: "active" }],
    actions: [{ id: "action-a", organization_id: "org-a", objective_id: "objective-a", title: "Praticar escuta", status: "blocked", blocker: "Agenda", due_date: "2026-10-01" }],
    checkins: [{ id: "checkin-a", organization_id: "org-a", pdi_id: "pdi-a", progress_note: "Avanço registrado", next_step: "Próximo passo", blocker: null, checkin_at: "2026-09-08" }],
  });
  assert.ok(items.some((item) => item.kind === "ASSESSMENT" && item.provenance[0]?.sourceType === "assessment_v1"));
  assert.ok(items.some((item) => item.kind === "FEEDBACK_360" && item.unknowns.length > 0 && item.provenance[0]?.entityType === "FEEDBACK_360"));
  assert.ok(items.some((item) => item.kind === "PDI" && item.title === "Praticar escuta"));
  assert.equal(items.every((item) => item.organizationId === "org-a" && item.employeeId === "emp-a"), true);
  const serialized = JSON.stringify(items);
  assert.equal(serialized.includes("participant_id"), false);
  assert.equal(serialized.includes("evaluator_employee_id"), false);
  assert.equal(serialized.includes("comment"), false);
});

test("DHO adapter does not turn incompatible history into a positive or negative evolution", () => {
  const items = buildDhoContextItems({ organizationId: "org-a", employeeId: "emp-a", assessments: [], scores: [], evolution: [{ source_type: "assessment_v1", cycle_id: "cycle-b", competency_id: "competency-a", expected_level_snapshot: 5, position_id: "position-b", score: 5, previous_score: null, delta: null, employee_id: "emp-a" }], pdis: [], objectives: [], actions: [], checkins: [] });
  const item = items[0];
  assert.equal(item.kind, "ASSESSMENT");
  assert.match(item.summary, /não há predecessor comparável/);
  assert.equal(item.provenance[0]?.sourceType, "assessment_v1");
  assert.equal(item.provenance[0]?.entityType, "ASSESSMENT");
  assert.equal(item.provenance[0]?.entityId, "cycle-b");
});

test("DHO population is role-aware and never treats a manager's own employee as the team", () => {
  assert.equal(dhoPopulationMode("admin_youb", "admin-employee"), "tenant");
  assert.equal(dhoPopulationMode("rh", "rh-employee"), "tenant");
  assert.equal(dhoPopulationMode("diretoria", "director-employee"), "aggregate_only");
  assert.equal(dhoPopulationMode("gestor", "manager-employee"), "direct_reports");
  assert.equal(dhoPopulationMode("colaborador", "employee-a"), "self");
  assert.equal(dhoPopulationMode("gestor", null), "empty");
});

test("large populations never create one evolution RPC per tenant employee", () => {
  const employeeIds = Array.from({ length: 1000 }, (_, index) => `employee-${index}`);
  const tenant = dhoSubjectRequestPlan("rh", employeeIds);
  assert.equal(tenant.mode, "aggregate_only");
  assert.equal(tenant.evolutionRpcCalls, 0);
  assert.equal(tenant.subjectIds.length, 0);
  const manager = dhoSubjectRequestPlan("gestor", employeeIds);
  assert.equal(manager.mode, "direct_reports");
  assert.equal(manager.evolutionRpcCalls, MAX_DHO_DIRECT_REPORTS);
  assert.equal(manager.subjectIds.length, MAX_DHO_DIRECT_REPORTS);
  assert.equal(manager.bounded, true);
});

test("a failed source remains a limitation while valid sources stay available", () => {
  const availability = dhoSourceAvailability({ assessment: "available", feedback_360: "unavailable", pdi: "empty" }, { feedback_360: "Fonte indisponível; outras fontes continuam válidas." });
  assert.equal(availability.find((item) => item.source === "assessment")?.status, "available");
  assert.equal(availability.find((item) => item.source === "feedback_360")?.status, "unavailable");
  assert.match(availability.find((item) => item.source === "feedback_360")?.limitation ?? "", /outras fontes/);
  assert.equal(availability.find((item) => item.source === "pdi")?.status, "empty");
});
