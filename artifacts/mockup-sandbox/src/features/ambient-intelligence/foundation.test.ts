import test from "node:test";
import assert from "node:assert/strict";
import { buildInsufficientBrief, valueBeforeInput } from "./service";
import { AMBIENT_BEE_INTENTS, prepareAmbientBeeReadModel, routeAmbientIntent, selectAmbientIntent } from "./runtime";
import { containsForbiddenAmbientContent, containsHealthDiagnosis, isHighStakesAutonomy, type AmbientFoundationRead } from "./types";

const context = { organizationId: "org-a", userId: "user-a", role: "gestor" as const, employeeId: "employee-a" };
const base: AmbientFoundationRead = { sources: [], observations: [], reviews: [], preferences: [], attention: [], commitments: [], briefs: [] };
const attention = (overrides: Record<string, unknown> = {}) => ({ id: "attention-a", organization_id: "org-a", owner_user_id: "user-a", horizon: "today" as const, attention_type: "review" as const, title: "Revisar feedback", rationale: "Há fonte autorizada", status: "open" as const, priority: 1 as const, due_at: null, source_observation_id: "obs-a", source_recommendation_id: null, context: {}, human_required: true as const, created_by_user_id: "user-a", created_at: "2026-09-01", updated_at: "2026-09-01", ...overrides });

test("Ambient intents route to attention_brief, confirmations and three leader horizons", () => {
  assert.deepEqual(AMBIENT_BEE_INTENTS, ["attention_brief", "pending_confirmations", "leader_today", "leader_week", "leader_evolution"]);
  assert.equal(routeAmbientIntent("what needs confirmation?"), "pending_confirmations");
  assert.equal(routeAmbientIntent("leader week"), "leader_week");
  assert.equal(routeAmbientIntent("evolution"), "leader_evolution");
});

test("empty context explicitly returns insufficient context and fabricates no priority", () => {
  const model = prepareAmbientBeeReadModel(context, base);
  assert.equal(model.brief.context_status, "insufficient");
  assert.equal(model.brief.priority_items.length, 0);
  assert.match(model.limitations[0], /insufficient/i);
  assert.equal(selectAmbientIntent(model, "leader_today"), model.brief);
});

test("daily brief is capped at three and horizons remain separate", () => {
  const foundation: AmbientFoundationRead = { ...base, attention: [1, 2, 3, 4].map((n) => attention({ id: `attention-${n}`, priority: (n > 3 ? 3 : n) as 1 | 2 | 3 })), commitments: [] };
  const model = prepareAmbientBeeReadModel(context, foundation);
  assert.equal(model.brief.priority_items.length, 3);
  assert.equal(model.today.length, 4);
  assert.equal(model.week.length, 0);
});

test("private preferences influence only the authorized owner", () => {
  const model = prepareAmbientBeeReadModel(context, { ...base, preferences: [{ id: "p", organization_id: "org-a", user_id: "user-a", preference_key: "work_window", preference_value: { start: "08:00" }, privacy: "private", created_at: "", updated_at: "" }] });
  assert.equal(model.evolution.preferences.length, 1);
  const other = prepareAmbientBeeReadModel({ ...context, userId: "user-b" }, { ...base, preferences: [{ id: "p", organization_id: "org-a", user_id: "user-a", preference_key: "work_window", preference_value: { start: "08:00" }, privacy: "private", created_at: "", updated_at: "" }] });
  assert.equal(other.evolution.preferences.length, 0);
});

test("value-before-input suppresses a question when a system record already exists", () => {
  assert.deepEqual(valueBeforeInput({ systemRecord: { startsAt: "08:00" }, question: "Quando você começa?" }), { shouldAsk: false, value: { startsAt: "08:00" }, message: "A youB já encontrou esse contexto em uma fonte autorizada." });
  assert.equal(valueBeforeInput({ systemRecord: null, question: "Quando você começa?" }).shouldAsk, true);
});

test("inference is not a fact and rejected inference cannot become confirmation implicitly", () => {
  const foundation: AmbientFoundationRead = { ...base, observations: [{ id: "obs", organization_id: "org-a", source_registry_id: null, observation_type: "pattern", epistemic_kind: "machine_inferred", summary: "Possível padrão", observed_at: "", recorded_at: "", valid_from: null, valid_until: null, sensitivity: "standard", confidence: 0.4, scope_type: "team", scope_ref: "team-a", provenance: { basis: ["record"] }, structured_value: {}, correlation_id: null, actor_user_id: null, created_by_user_id: "user-a", supersedes_observation_id: null }], reviews: [] };
  const model = prepareAmbientBeeReadModel(context, foundation);
  assert.equal(model.brief.context_status, "insufficient");
  assert.equal(foundation.observations[0].epistemic_kind, "machine_inferred");
});

test("raw communication, diagnosis and high-stakes autonomy are blocked by helpers", () => {
  assert.equal(containsForbiddenAmbientContent({ summary: "raw transcript" }), true);
  assert.equal(containsForbiddenAmbientContent({ access_token: "secret" }), true);
  assert.equal(containsHealthDiagnosis("inferir TDAH"), true);
  assert.equal(isHighStakesAutonomy("promover automaticamente"), true);
  assert.equal(isHighStakesAutonomy("preparar feedback"), false);
});

test("insufficient brief has no focus, action or priority", () => {
  const brief = buildInsufficientBrief("org-a", "user-a", "today");
  assert.deepEqual(brief.priority_items, []);
  assert.deepEqual(brief.do_items, []);
  assert.deepEqual(brief.delegate_items, []);
  assert.deepEqual(brief.stop_items, []);
  assert.equal(brief.focus_statement, null);
});
