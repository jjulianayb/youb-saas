import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { leaderBuckets, leaderHorizons, leaderPriorities, type ManagerHomeData } from "./ManagerHome";

const data: ManagerHomeData = {
  employees: [{ id: "mariana", full_name: "Mariana" }, { id: "ana", full_name: "Ana" }, { id: "leo", full_name: "Leo" }, { id: "bia", full_name: "Bia" }],
  feedbacks: [{ id: "f1", target_employee_id: "mariana", created_at: "2026-09-14", content: "Clareza" }],
  pdis: [{ id: "p1", objective: "Delegação", status: "active", employee_id: "ana", due_date: "2026-09-19" }],
  checkins: [{ id: "c1", employee_id: "leo", checkin_date: "2026-09-13", note: "Sinal recente" }],
  assessments: [{ id: "a1", subject_employee_id: "bia", created_at: "2026-09-12" }],
};

test("Manager Home exposes a distinct three-priority composition", () => {
  const priorities = leaderPriorities(data);
  assert.equal(priorities.length, 3);
  assert.deepEqual(priorities.map((item) => item.kind), ["fazer", "decidir", "fazer"]);
  assert.match(priorities[0].title, /Mariana/);
});

test("Manager Home keeps the three leadership horizons and energy buckets explicit", () => {
  assert.deepEqual(leaderHorizons, ["Hoje", "Semana", "Evolução"]);
  assert.deepEqual(leaderBuckets, ["Fazer", "Delegar", "Parar"]);
});

test("role-aware entry gives leaders and RH different primary compositions", () => {
  const dashboard = readFileSync(new URL("./Dashboard.tsx", import.meta.url), "utf8");
  assert.match(dashboard, /userRole === "gestor" \? <ManagerHome/);
  assert.match(dashboard, /userRole === "rh" \? <RhHome/);
  assert.doesNotMatch(dashboard, /userRole === "gestor" \? <Overview/);
});

test("authenticated experience uses the approved horizontal product shell", () => {
  const dashboard = readFileSync(new URL("./Dashboard.tsx", import.meta.url), "utf8");
  assert.match(dashboard, /yb-app-topbar/);
  assert.match(dashboard, /Navegação principal da youB/);
  assert.match(dashboard, /yb-app-mobile-nav/);
  assert.doesNotMatch(dashboard, /<aside className="w-full bg-\[#102654\]/);
});

test("Manager Home does not infer health or make an automatic people decision", () => {
  const priorities = leaderPriorities({ ...data, checkins: [{ ...data.checkins[0], note: "Preciso de apoio" }] });
  const copy = priorities.map((item) => `${item.title} ${item.reason}`).join(" ").toLowerCase();
  assert.doesNotMatch(copy, /tdah|depressão|condição médica/);
  assert.ok(priorities.every((item) => ["fazer", "delegar", "decidir"].includes(item.kind)));
});
