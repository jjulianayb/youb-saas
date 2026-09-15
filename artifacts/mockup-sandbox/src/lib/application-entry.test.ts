import test from "node:test";
import assert from "node:assert/strict";
import { appPath } from "./app-paths";
import { commercialExperienceForRole, refreshSession, resolveOrganizationSelection, restoreSession, sessionFromAuth, sessionNeedsRefresh, type OrganizationSummary } from "./supabase";

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

test("E — expired access token refreshes and preserves the returned session contract", async () => {
  const previousFetch = globalThis.fetch;
  globalThis.fetch = (async () => ({ ok: true, json: async () => ({ access_token: "new-access", expires_in: 1800, token_type: "Bearer", user }) })) as typeof fetch;
  try {
    const refreshed = await refreshSession({ access_token: "expired", refresh_token: "old-refresh", expires_at: 1, user });
    assert.equal(refreshed.access_token, "new-access");
    assert.equal(refreshed.refresh_token, "old-refresh");
    assert.equal(refreshed.token_type, "Bearer");
    assert.ok(refreshed.expires_at && refreshed.expires_at > Math.floor(Date.now() / 1000));
  } finally {
    globalThis.fetch = previousFetch;
  }
});

test("F — an invalid refresh fails closed and removes local session and organization", async () => {
  const previousFetch = globalThis.fetch;
  globalThis.fetch = (async () => { throw new Error("invalid refresh"); }) as typeof fetch;
  const store = installLocalStorage({
    "youb-session": JSON.stringify({ access_token: "expired", refresh_token: "invalid", expires_at: 1, user }),
    "youb-organization": JSON.stringify(organization("one")),
  });
  try {
    assert.equal(await restoreSession(), null);
    assert.equal(store.has("youb-session"), false);
    assert.equal(store.has("youb-organization"), false);
  } finally {
    globalThis.fetch = previousFetch;
  }
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

test("K — scope-dependent roles require an explicit employee link", async () => {
  const supabase = await import("./supabase");
  assert.equal(supabase.requiresEmployeeLink("gestor"), true);
  assert.equal(supabase.requiresEmployeeLink("colaborador"), true);
  assert.equal(supabase.requiresEmployeeLink("rh"), false);
  assert.match(supabase.employeeLinkMessage("ambiguous"), /mais de um colaborador/);
  assert.match(supabase.employeeLinkMessage("unlinked"), /não está vinculado/);
});
