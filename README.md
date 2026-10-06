# Wasp on SnapDeploy

The [Wasp](https://wasp.sh) "basic" template (tasks + tags, username/password auth, PostgreSQL) with two Dockerfiles that let [SnapDeploy](https://snapdeploy.dev) build and run it straight from this repository — no `wasp build` on your machine, no committed build output.

| Container | Dockerfile | What it is |
|---|---|---|
| **server** | `Dockerfile` | the Wasp API server (Node.js, port 3001) — installs the Wasp CLI, runs `wasp build`, bundles the server, runs Prisma migrations on start |
| **client** | `client.Dockerfile` | the React client built with Vite and served by nginx (port 80), with the SPA fallback |

The only change to the template: username + password auth instead of email auth, so the server needs no email provider to run in production. Everything else is what `wasp new` generates (Wasp 0.25).

## Deploy on SnapDeploy

Full guide: https://snapdeploy.dev/deploy-wasp-app

1. **Database** — create a PostgreSQL add-on (the $1 DB Sprint Pack is enough to try it). Copy its `DATABASE_URL`.
2. **Server** — Deploy from GitHub → this repository → branch `main` → Dockerfile path `Dockerfile`. Environment variables before the first build:
   - `DATABASE_URL` — from step 1
   - `JWT_SECRET` — any random string of at least 32 characters
   - `WASP_SERVER_URL` — the server container's URL (shown in the dashboard, `https://<name>.containers.snapdeploy.app`)
   - `WASP_WEB_CLIENT_URL` — the client container's URL; set it after step 3 (a placeholder is fine for the first build)
   SnapDeploy injects `PORT` to match the container port (3001).
3. **Client** — Deploy from GitHub → same repository → Dockerfile path `client.Dockerfile`. Environment variable before the first build:
   - `REACT_APP_API_URL` — the server URL from step 2. SnapDeploy passes `REACT_APP_*` variables into the build; Vite bakes the value into the JavaScript.
4. Go back to the server container, set `WASP_WEB_CLIENT_URL` to the client URL, redeploy. Open the client URL, sign up, add a task.

Every push to `main` rebuilds both containers. New Prisma migrations (`wasp db migrate-dev` locally, commit `migrations/`) are applied by the server on its next start.

## Run locally

```bash
wasp start db        # dockerised PostgreSQL for development
wasp db migrate-dev
wasp start
```
