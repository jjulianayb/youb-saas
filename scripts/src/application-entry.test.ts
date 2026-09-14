import test from "node:test";
import assert from "node:assert/strict";
import { appPath } from "../../artifacts/mockup-sandbox/src/lib/app-paths";
import { commercialExperienceForRole, resolveOrganizationSelection, restoreSession, sessionFromAuth, sessionNeedsRefresh, type OrganizationSummary } from "../../artifacts/mockup-sandbox/src/lib/supabase";

const organization = (id: string): OrganizationSummary => ({ id, name: `Empresa ${id}`, slug: `empresa-${id}` });
const user = { id: "10000000-0000-0000-0000-000000000001", email: "test@example.invalid" };

type LocalStorageLike = { getItem: (key: string) => string | null; setItem: (key: string, value: string) => void; removeItem: (key: string) => void; clear: () => void };
function installLocalStorage(initial: Record<string, string> = {}) {
  const store = new Map(Object.entries(initial));
  (globalThis as typeof globalThis & { window: { localStorage: LocalStorageLike } }).window = {
    localStorage: {
      getItem: (key: string) => store.get(key) ?? null,
      setItem: (key: string, value: string) => { store.set(key, value); },
      removeItem: (key: string) => { store.delete(key); },
      clear: () => { store.clear(); },
    },
  };
  return store;
}

test("A — one organization opens the role-aware commercial entry", () => {
  assert.equal(resolveOrganizationSelection([organization("one")])?.id, "one");
  assert.equal(appPath("/commercial"), "/commercial");
});

test("B/C — multiple organizations require and preserve the explicit choice", () => {
  const organizations = [organization("one"), organization("two")];
  assert.equal(resolveOrganizationSelection(organizations), null);
  assert.equal(resolveOrganizationSelection(organizations, "two")?.id, "two");
  assert.equal(resolveOrganizationSelection(organizations, "missing"), null);
});

test("D — a valid access token is not refreshed unnecessarily", async () => {
  const session = sessionFromAuth({ access_token: "access", refresh_token: "refresh", expires_in: 3600, token_type: "bearer", user });
  assert.equal(sessionNeedsRefresh(session, Date.now()), false);
  const store = installLocalStorage({ "youb-session": JSON.stringify(session) });
  const restored = await restoreSession();
  assert.equal(restored?.access_token, "access");
  assert.equal(store.has("youb-session"), true);
});

test("E — refreshed auth response preserves refresh token, token type and expiry", () => {
  const refreshed = sessionFromAuth({ access_token: "new-access", expires_in: 1800, token_type: "Bearer", user }, "old-refresh");
  assert.equal(refreshed.access_token, "new-access");
  assert.equal(refreshed.refresh_token, "old-refresh");
  assert.equal(refreshed.token_type, "Bearer");
  assert.ok(refreshed.expires_at && refreshed.expires_at > Math.floor(Date.now() / 1000));
});

test("F — an invalid refresh fails closed and removes local session and organization", async () => {
  const store = installLocalStorage({
    "youb-session": JSON.stringify({ access_token: "expired", refresh_token: "invalid", expires_at: 1, user }),
    "youb-organization": JSON.stringify(organization("one")),
  });
  assert.equal(await restoreSession(), null);
  assert.equal(store.has("youb-session"), false);
  assert.equal(store.has("youb-organization"), false);
});

test("G — signup sessions persist the same expiry contract as login sessions", () => {
  const signup = sessionFromAuth({ access_token: "signup-access", refresh_token: "signup-refresh", expires_in: 3600, token_type: "bearer", user });
  assert.equal(signup.refresh_token, "signup-refresh");
  assert.equal(signup.token_type, "bearer");
  assert.ok(signup.expires_at && signup.expires_at > Math.floor(Date.now() / 1000));
});

test("H/I/J — Commercial V1 maps every supported role to its current journey", () => {
  assert.equal(commercialExperienceForRole("diretoria"), "executive");
  assert.equal(commercialExperienceForRole("colaborador"), "employee");
  assert.equal(commercialExperienceForRole("admin_youb"), "dashboard");
  assert.equal(commercialExperienceForRole("rh"), "dashboard");
  assert.equal(commercialExperienceForRole("gestor"), "dashboard");
});
