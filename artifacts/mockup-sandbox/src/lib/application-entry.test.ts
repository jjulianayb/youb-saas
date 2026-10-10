import test from "node:test";
import assert from "node:assert/strict";
import { appPath, resolveAppRoute } from "./app-paths";
import { authenticatedFetch, commercialExperienceForRole, refreshSession, resolveOrganizationSelection, restoreSession, sessionFromAuth, sessionNeedsRefresh, type OrganizationSummary, type SupabaseSession } from "./supabase";

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

test("A — one product entry opens login, while authenticated routes stay internal", () => {
  assert.equal(resolveAppRoute("/").kind, "onboarding");
  assert.equal(resolveAppRoute("/preview/Onboarding").kind, "onboarding");
  assert.equal(resolveAppRoute("/preview/CommercialV1Demo").kind, "onboarding");
  assert.deepEqual(resolveAppRoute("/preview/EmployeeHome"), { kind: "preview", componentPath: "EmployeeHome" });
  assert.equal(resolveAppRoute("/commercial").kind, "commercial");
  assert.equal(resolveAppRoute("/employee").kind, "employee");
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


test("K — authenticated REST calls refresh once after an expired JWT and persist the rotated session", async () => {
  const previousFetch = globalThis.fetch;
  const calls: Array<{ url: string; authorization: string | null }> = [];
  const original = sessionFromAuth({ access_token: "expired-access", refresh_token: "old-refresh", expires_in: 3600, token_type: "bearer", user });
  const store = installLocalStorage({ "youb-session": JSON.stringify(original) });
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.includes("/auth/v1/token?grant_type=refresh_token")) {
      return { ok: true, status: 200, json: async () => ({ access_token: "fresh-access", refresh_token: "rotated-refresh", expires_in: 3600, token_type: "bearer", user }) } as Response;
    }
    const authorization = new Headers(init?.headers).get("Authorization");
    calls.push({ url, authorization });
    return calls.length === 1
      ? { ok: false, status: 401, json: async () => ({ message: "JWT expired" }) } as Response
      : { ok: true, status: 200, json: async () => ([{ id: "cycle" }]) } as Response;
  }) as typeof fetch;
  try {
    const response = await authenticatedFetch(original, "https://example.supabase.co/rest/v1/cycles", { headers: { apikey: "anon" } });
    assert.equal(response.status, 200);
    assert.deepEqual(calls.map((call) => call.authorization), ["Bearer expired-access", "Bearer fresh-access"]);
    const persisted = JSON.parse(store.get("youb-session") ?? "{}") as SupabaseSession;
    assert.equal(persisted.access_token, "fresh-access");
    assert.equal(persisted.refresh_token, "rotated-refresh");
  } finally {
    globalThis.fetch = previousFetch;
  }
});
