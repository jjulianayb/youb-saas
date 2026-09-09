import test from "node:test";
import assert from "node:assert/strict";
import { COMMERCIAL_DEMO_ROLES, demoNavigationForRole, demoRoleLabel, mobileNavigationState } from "./CommercialV1Demo";
import { appPath, localAppPath } from "../../lib/app-paths";

test("Commercial V1 demo exposes bounded role journeys without cross-role navigation", () => {
  assert.deepEqual(COMMERCIAL_DEMO_ROLES, ["RH", "Gestor", "Colaborador", "Diretoria"]);
  assert.ok(demoNavigationForRole("RH").some((item) => item.id === "people"));
  assert.ok(demoNavigationForRole("Gestor").some((item) => item.id === "pdi"));
  assert.ok(demoNavigationForRole("Colaborador").some((item) => item.id === "feedback"));
  assert.ok(demoNavigationForRole("Diretoria").some((item) => item.id === "impact"));
  assert.equal(demoNavigationForRole("Colaborador").some((item) => item.id === "people"), false);
  assert.equal(demoRoleLabel("Diretoria"), "Diretoria");
});

test("mobile navigation has a real controlled menu state", () => {
  assert.deepEqual(mobileNavigationState(false), { ariaExpanded: false, visibility: "hidden" });
  assert.deepEqual(mobileNavigationState(true), { ariaExpanded: true, visibility: "visible" });
});

test("preview links remain inside the configured subpath", () => {
  assert.equal(appPath("/preview/Onboarding", "/workspace/"), "/workspace/preview/Onboarding");
  assert.equal(localAppPath("/workspace/preview/Onboarding", "/workspace/"), "/preview/Onboarding");
});

test("Commercial V1 demo is explicitly synthetic", () => {
  const serialized = JSON.stringify({ roles: COMMERCIAL_DEMO_ROLES, nav: COMMERCIAL_DEMO_ROLES.map(demoNavigationForRole) });
  assert.match(serialized, /Diretoria/);
  assert.equal(serialized.includes("participant_id"), false);
  assert.equal(serialized.includes("evaluator_employee_id"), false);
});
