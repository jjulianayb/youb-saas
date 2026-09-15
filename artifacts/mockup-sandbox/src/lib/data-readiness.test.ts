import test from "node:test";
import assert from "node:assert/strict";
import { CommercialSourceError, sourceStateFromError, sourceStateFromResponse, sourceStateFromRows } from "./data-readiness";

test("source readiness distinguishes empty, available, unauthorized and unavailable", () => {
  assert.deepEqual(sourceStateFromRows([]), { status: "empty" });
  assert.deepEqual(sourceStateFromRows([{ id: "1" }]), { status: "available" });
  assert.equal(sourceStateFromResponse(new Response(null, { status: 403 })).status, "unauthorized");
  assert.equal(sourceStateFromResponse(new Response(null, { status: 503 })).status, "unavailable");
  assert.equal(sourceStateFromError(new CommercialSourceError("unauthorized")).status, "unauthorized");
});

test("source readiness preserves insufficient as an explicit state", () => {
  assert.equal(sourceStateFromError({}).status, "unavailable");
  const state = { status: "insufficient" as const, reason: "employee link missing" };
  assert.equal(state.status, "insufficient");
});
