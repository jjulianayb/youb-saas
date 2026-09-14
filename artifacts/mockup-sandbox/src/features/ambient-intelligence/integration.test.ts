import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { filterAmbientObservations, prepareAmbientBeeReadModel } from "./runtime";
import { ambientBeeResponse, ambientBriefPriorities, createAmbientDemoReadModel } from "./ux-integration";
import type { AmbientFoundationRead } from "./types";

const context = { organizationId: "org-a", userId: "user-a", role: "gestor" as const, employeeId: "employee-a" };
const empty: AmbientFoundationRead = { sources: [], observations: [], reviews: [], preferences: [], attention: [], commitments: [], briefs: [] };
const observation = (overrides: Record<string, unknown> = {}) => ({ id: "obs-a", organization_id: "org-a", source_registry_id: "source-a", observation_type: "pattern", epistemic_kind: "machine_inferred" as const, summary: "Possível padrão de trabalho", observed_at: "2026-09-14", recorded_at: "2026-09-14", valid_from: null, valid_until: null, sensitivity: "standard" as const, confidence: 0.4, scope_type: "team", scope_ref: "team-a", subject_type: "team" as const, subject_ref: "team-a", subject_owner_user_id: null, visibility_scope: "subject" as const, authorized_roles: ["gestor"], authorized_user_ids: ["user-a"], provenance: { basis: ["checkin"] }, structured_value: {}, correlation_id: null, actor_user_id: null, created_by_user_id: "user-a", supersedes_observation_id: null, ...overrides });

const dashboard = () => readFileSync(new URL("../../components/mockups/Dashboard.tsx", import.meta.url), "utf8");
const manager = () => readFileSync(new URL("../../components/mockups/ManagerHome.tsx", import.meta.url), "utf8");
const app = () => readFileSync(new URL("../../App.tsx", import.meta.url), "utf8");

// A. Leader Home consumes the Ambient read model.
test("integration wires Dashboard to the Ambient read model", () => {
  assert.match(dashboard(), /readAmbientFoundation/);
  assert.match(dashboard(), /prepareAmbientBeeReadModel/);
  assert.match(dashboard(), /ambient={ambientModel/);
  assert.match(manager(), /ambientBriefPriorities/);
});

// B/C/D. Today, week and evolution are separate contracts.
test("leader today is capped at three while week and evolution remain separate", () => {
  const model = createAmbientDemoReadModel();
  assert.equal(ambientBriefPriorities(model.brief).length, 3);
  assert.ok(model.today.length >= 3);
  assert.deepEqual(model.week.map((item) => item.id), []);
  assert.equal(model.evolution.commitments.length, 1);
});

// E. Pending confirmation is a microinteraction, not a form.
test("pending confirmation is represented as a focused Bee response", () => {
  const model = createAmbientDemoReadModel();
  assert.equal(model.pendingConfirmations.length, 1);
  assert.match(ambientBeeResponse(model, "confirmations"), /segundos|confirmação/i);
  assert.match(manager(), /Confirmação pendente/);
});

// F. Empty context does not fabricate a priority.
test("empty Ambient context keeps Leader Home insufficient", () => {
  const model = prepareAmbientBeeReadModel(context, empty);
  assert.equal(model.brief.context_status, "insufficient");
  assert.deepEqual(model.brief.priority_items, []);
  assert.match(ambientBeeResponse(model, "today"), /contexto autorizado suficiente/i);
});

// G. Private preferences remain owner-only.
test("private preferences do not cross into another role context", () => {
  const preference = { id: "p", organization_id: "org-a", user_id: "user-a", preference_key: "work_window", preference_value: { start: "08:00" }, privacy: "private" as const, created_at: "", updated_at: "" };
  const owner = prepareAmbientBeeReadModel(context, { ...empty, preferences: [preference] });
  const rh = prepareAmbientBeeReadModel({ ...context, userId: "rh-user", role: "rh" }, { ...empty, preferences: [preference] });
  assert.equal(owner.evolution.preferences.length, 1);
  assert.equal(rh.evolution.preferences.length, 0);
});

// H. Unauthorized observations are filtered before composition.
test("unauthorized observations do not reach the Ambient composition", () => {
  const allowed = observation();
  const unauthorized = observation({ id: "obs-b", authorized_roles: ["rh"], authorized_user_ids: ["rh-user"], subject_owner_user_id: "employee-b" });
  assert.deepEqual(filterAmbientObservations(context, [allowed, unauthorized]).map((item) => item.id), ["obs-a"]);
});

// I/J. Epistemic distinctions remain visible in the adapter and UI.
test("inferred and human-declared content are not rewritten as facts", () => {
  const model = createAmbientDemoReadModel();
  const priority = ambientBriefPriorities(model.brief)[0];
  assert.equal(priority.epistemic, "contexto autorizado");
  assert.match(manager(), /Proveniência/);
  assert.doesNotMatch(ambientBeeResponse(model, "today"), /inferir condição de saúde|tdah|diagnóstico/i);
});

// K/L. Bee can prepare/explain, but not execute or diagnose.
test("Bee integration rejects high-stakes autonomy and diagnosis language", () => {
  const model = createAmbientDemoReadModel();
  assert.match(ambientBeeResponse(model, "demitir alguém"), /decisão humana|contextual/i);
  assert.doesNotMatch(ambientBeeResponse(model, "o que fazer agora"), /demitir|promover|diagnóstico|tdah/i);
});

// M. Role-specific compositions remain separate.
test("manager and RH compositions remain distinct", () => {
  const source = dashboard();
  assert.match(source, /userRole === "gestor" \? <ManagerHome/);
  assert.match(source, /userRole === "rh" \? <RhHome/);
  assert.doesNotMatch(source, /userRole === "gestor" \? <RhHome/);
});

// N-Q. Existing product surfaces remain reachable.
test("Commercial, Classic DHO, Employee and Executive surfaces remain present", () => {
  const source = app();
  assert.match(source, /CommercialExperienceRoute/);
  assert.match(source, /EmployeeExperienceRoute/);
  assert.match(source, /ExecutiveHomeRoute/);
  assert.match(manager(), /Classic|Ambient|Bee|Chief of Staff/i);
});

// R/S/T. Existing regression suites and Ambient hardening remain in the integration contract.
test("integration keeps the approved regression commands and SQL suites", () => {
  const packageJson = readFileSync(new URL("../../../../../scripts/package.json", import.meta.url), "utf8");
  const sqlScript = readFileSync(new URL("../../../../../scripts/test-sql.sh", import.meta.url), "utf8");
  assert.match(packageJson, /ambient-intelligence\/foundation.test/);
  assert.match(packageJson, /ambient-intelligence\/integration.test/);
  assert.match(sqlScript, /ambient_intelligence_foundation_v1/);
  assert.match(sqlScript, /data_architecture_p0/);
});

test("integrated Leader Home keeps responsive and basic accessibility contracts", () => {
  const source = manager();
  assert.match(source, /sm:|md:|lg:/);
  assert.match(source, /focus-visible:ring/);
  assert.match(source, /aria-live/);
  assert.match(source, /type=\"button\"/);
});
