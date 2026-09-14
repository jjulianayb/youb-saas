import test from "node:test";
import assert from "node:assert/strict";
import { cardsFrom } from "./EmployeeHome";

test("Employee Experience keeps a progressive four-path home", () => {
  const cards = cardsFrom({
    pdis: [{ id: "pdi", objective: "Evoluir", status: "active", due_date: null }],
    checkins: [{ id: "checkin", checkin_date: "2026-09-14", mood: 4, engagement: 4, energy: 3, workload: 3 }],
    actions: [{ id: "action", organization_id: "org", intervention_id: null, action_type: "follow_up", title: "Próximo passo", details: null, status: "planned", assignee_employee_id: "employee", due_at: null, completed_at: null }],
    assessments: [{ id: "assessment", cycle_id: "cycle", status: "completed", position_id: null, created_at: "2026-09-14" }],
    assessmentScores: [],
    competencies: [],
  });
  assert.deepEqual(cards.map((card) => card.label), ["Hoje", "Meu PDI", "Minha evolução", "Próximo passo"]);
});

test("Employee Experience has explicit empty-state language without inventing sources", () => {
  const cards = cardsFrom({ pdis: [], checkins: [], actions: [], assessments: [], assessmentScores: [], competencies: [] });
  assert.equal(cards.length, 4);
  assert.match(cards[0].detail, /Nenhuma ação/);
  assert.match(cards[3].detail, /check-in/);
});
