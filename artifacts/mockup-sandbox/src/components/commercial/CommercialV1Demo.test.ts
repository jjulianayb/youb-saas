import test from "node:test";
import assert from "node:assert/strict";
import { COMMERCIAL_DEMO_ROLES, demoNavigationForRole, demoRoleLabel } from "./CommercialV1Demo";

test("Commercial V1 demo exposes bounded role journeys without cross-role navigation", () => {
  assert.deepEqual(COMMERCIAL_DEMO_ROLES, ["RH", "Gestor", "Colaborador", "Diretoria"]);
  assert.ok(demoNavigationForRole("RH").some((item) => item.id === "people"));
  assert.ok(demoNavigationForRole("Gestor").some((item) => item.id === "pdi"));
  assert.ok(demoNavigationForRole("Colaborador").some((item) => item.id === "feedback"));
  assert.ok(demoNavigationForRole("Diretoria").some((item) => item.id === "impact"));
  assert.equal(demoNavigationForRole("Colaborador").some((item) => item.id === "people"), false);
  assert.equal(demoRoleLabel("Diretoria"), "Diretoria");
});

test("Commercial V1 demo is explicitly synthetic", () => {
  const serialized = JSON.stringify({ roles: COMMERCIAL_DEMO_ROLES, nav: COMMERCIAL_DEMO_ROLES.map(demoNavigationForRole) });
  assert.match(serialized, /Diretoria/);
  assert.equal(serialized.includes("participant_id"), false);
  assert.equal(serialized.includes("evaluator_employee_id"), false);
});
