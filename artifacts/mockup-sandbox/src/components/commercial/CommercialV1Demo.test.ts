import test from "node:test";
import assert from "node:assert/strict";
import { COMMERCIAL_DEMO_ROLES, demoExperienceContentForRole, demoNavigationForRole, demoRoleLabel, mobileNavigationState } from "./CommercialV1Demo";
import { appPath, localAppPath } from "../../lib/app-paths";
import { readFileSync } from "node:fs";

const source = readFileSync(new URL("./CommercialV1Demo.tsx", import.meta.url), "utf8");

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

test("approved Commercial V1 keeps the horizontal shell and Organização Viva", () => {
  assert.match(source, /cv-topbar/);
  assert.match(source, /Navegação principal/);
  assert.match(source, /ORGANIZAÇÃO VIVA/);
  assert.match(source, /Observar → Compreender → Simular → Agir/);
  assert.doesNotMatch(source, /<aside className="w-full bg-\[var\(--youb-navy\)\]/);
});

test("collaborator journey remains personal instead of executive", () => {
  const collaboratorContent = demoExperienceContentForRole("Colaborador");
  assert.match(source, /role === "Colaborador"/);
  assert.match(source, /MINHA EVOLUÇÃO/);
  assert.equal(demoNavigationForRole("Colaborador").some((item) => item.id === "impact"), false);
  assert.equal(demoNavigationForRole("Colaborador").some((item) => item.id === "decisions"), false);
  assert.deepEqual(collaboratorContent.nextMoves.map((item) => item.title), [
    "Registrar avanço no meu objetivo",
    "Praticar a competência escolhida",
    "Preparar meu próximo check-in",
  ]);
  assert.doesNotMatch(JSON.stringify(collaboratorContent), /evidências|decisão automática/i);
});
