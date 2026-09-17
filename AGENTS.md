# Base44 Development Environment

## Project Overview

**youB** — an HR platform prototype (PNPM monorepo, originally a Replit project).

### Key packages
- `artifacts/mockup-sandbox` — Vite + React + Tailwind frontend (the preview entry point, port 3000)
- `artifacts/api-server` — Express backend with esbuild bundling (port 8000)
- `lib/db` — Drizzle ORM (PostgreSQL); schema is currently empty, not imported at runtime
- `lib/api-zod`, `lib/api-spec`, `lib/api-client-react` — shared API types and client

### Auth
The frontend uses Supabase directly (REST API) for auth. It degrades gracefully when
`VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` are not set — the Gallery page and `/preview/*`
routes work without auth; `/employee`, `/executive`, `/commercial` show a login prompt.

## Running

```bash
docker compose -f docker-compose.base44.yml up -d --build
```

- **Frontend**: http://localhost:3000 (Vite dev server with live reload)
- **API health**: http://localhost:8000/api/healthz

## How it works

1. `setup` service runs `pnpm install --frozen-lockfile` once, then exits.
2. `web` service starts the Vite dev server (`pnpm --filter @workspace/mockup-sandbox run dev`)
   with `PORT=3000` and `BASE_PATH=/`.
3. `api` service builds and starts the Express server (`pnpm --filter @workspace/api-server run dev`)
   on port 8000.

The source is bind-mounted, so edits to frontend code hot-reload via Vite.
API server changes require a service restart (it bundles with esbuild, no watcher).

## PNPM notes

- Uses pnpm 9 (lockfile version 9.0). Install with `npm install -g pnpm@9`.
- `pnpm-workspace.yaml` has `minimumReleaseAge: 1440` (a pnpm 10 feature); pnpm 9 ignores it.
- The `catalog:` protocol in package.json references version ranges defined in `pnpm-workspace.yaml`.

## Brand identity (youB purple)

The visual identity is defined once in `artifacts/mockup-sandbox/src/index.css`:
- `--youb-*` tokens (`navy`, `ink`, `teal`, `surface`, `focus`) hold the brand palette.
- A second `@theme` block **remaps Tailwind's `blue-*` scale to the brand purple**
  (`#6342e8`). The screens use `blue-*` as their accent color, so overriding the
  scale rethemes every screen at once — do not reintroduce literal `#1e3a6e`/navy hexes.
- Semantic tokens (`--primary`, `--ring`, `--accent`) are purple too, which covers the
  shadcn UI components and `BeeShell`.

### Brand assets
Extracted from the design pack into `artifacts/mockup-sandbox/public/brand/`:
`youb-logo.png`, `bee.png`, `hero-woman.png`, `avatars/*.png`, `decor/*.png`.
The pack's crops carry baked-in backgrounds, so use them with a rounded/`object-cover`
crop. The reference wordmark is text, and the pack README says repo originals prevail,
so the text `youB` logo is kept rather than the raster logo.

## Secrets

Optional Supabase credentials (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`) are delivered
via `/run/base44/app.env`. Without them the app still runs — only auth-dependent routes are affected.
