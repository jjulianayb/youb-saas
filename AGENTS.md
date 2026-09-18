# Base44 Dev Environment

## What this is

A pnpm workspace monorepo (TypeScript). The user-facing app is `artifacts/mockup-sandbox` — a Vite 7 + React 19 "Mockup Canvas" for the youB HR platform. A separate Express 5 API server lives in `artifacts/api-server` but the frontend talks to Supabase directly (not the API server), so the API server is not needed for the preview.

## Running the app

```bash
docker compose -f docker-compose.base44.yml up -d
```

The `web` service runs `pnpm install` then `pnpm --filter @workspace/mockup-sandbox run dev`. Vite listens on 5173 inside the container, mapped to host port 3000.

Required env vars (set in compose `environment:`):
- `PORT=5173` — Vite dev server port (vite.config.ts throws without it)
- `BASE_PATH=/` — Vite base path (vite.config.ts throws without it)
- `__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS` — passed bare from the platform

## External service: Supabase

The frontend uses Supabase for auth and data (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`). Without these the app boots and shows the gallery/landing page, but data-dependent routes (`/employee`, `/executive`, `/commercial`) and mockups that fetch data will show "not configured" states. The code checks `isSupabaseConfigured` before making requests.

These are delivered via `/run/base44/app.env` (env_file, last entry — always wins). Provide them through the Base44 secrets dashboard.

## pnpm install notes

- `pnpm install --frozen-lockfile` fails with `ERR_PNPM_LOCKFILE_CONFIG_MISMATCH` (the overrides in `pnpm-workspace.yaml` don't match the committed lockfile). The compose command falls back to `pnpm install` automatically.
- `pnpm-workspace.yaml` has `minimumReleaseAge: 1440` (1-day supply-chain defense). This doesn't block the fallback install.
- pnpm 9 is installed via `npm install -g pnpm@9` at container startup (lockfileVersion 9.0).

## Key routes

- `/` — Gallery landing page (links to demos and authenticated routes)
- `/preview/Onboarding` — Login/onboarding mockup
- `/preview/CommercialV1Demo` — Commercial V1 demo
- `/preview/<ComponentName>` — Any mockup in `src/components/mockups/`
- `/employee` — Employee experience (needs Supabase)
- `/executive` — Executive home (needs Supabase)
- `/commercial` — Commercial experience (needs Supabase)

## Verifying it works

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/   # should be 200
curl -s http://localhost:3000/src/main.tsx | head -5            # should show transformed TS
```
