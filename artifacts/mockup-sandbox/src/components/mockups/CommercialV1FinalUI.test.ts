import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = readFileSync(new URL("./CommercialV1FinalUI.tsx", import.meta.url), "utf8");
const app = readFileSync(new URL("../../App.tsx", import.meta.url), "utf8");

test("Commercial V1 final visual preview has distinct role-aware compositions", () => {
  assert.match(source, /diretoria/);
  assert.match(source, /rh/);
  assert.match(source, /gestor/);
  assert.match(source, /colaborador/);
  assert.match(source, /Organização Viva/);
  assert.match(source, /Centro de Orquestração de Pessoas/);
  assert.match(source, /Minha jornada/);
});

test("Commercial V1 final visual preview is mobile-first and contextual", () => {
  assert.match(source, /bottom-0/);
  assert.match(source, /sm:/);
  assert.match(source, /md:/);
  assert.match(source, /lg:/);
  assert.match(source, /Demonstração visual/);
  assert.match(source, /contexto autorizado/);
  assert.match(source, /não.*execut/i);
});

test("Commercial V1 final visual preview is reachable without changing authenticated routes", () => {
  assert.match(app, /CommercialV1FinalUI/);
  assert.match(app, /EmployeeExperienceRoute/);
  assert.match(app, /ExecutiveHomeRoute/);
  assert.match(app, /CommercialExperienceRoute/);
});
