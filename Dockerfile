# Wasp API server on SnapDeploy — builds from source on every push.
#
# SnapDeploy builds this Dockerfile on its own ARM64 builders (nothing to run locally),
# then runs the image with the environment variables you set in the dashboard:
#   DATABASE_URL, JWT_SECRET, WASP_WEB_CLIENT_URL, WASP_SERVER_URL  (PORT is injected)
#
# Stage layout mirrors the Dockerfile Wasp generates in .wasp/out, with one extra step:
# the Wasp CLI is installed and `wasp build` runs inside the image, so the repository
# can hold the app's source instead of a committed build output.

ARG WASP_VERSION=0.25.0
ARG NODE_IMAGE=node:24-bookworm-slim

# ---------- base: Debian (glibc) because the Wasp CLI ships linux-arm64/x64 glibc binaries ----------
FROM ${NODE_IMAGE} AS base
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# ---------- builder: wasp build + server bundle ----------
FROM base AS builder
ARG WASP_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 build-essential \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g @wasp.sh/wasp-cli@${WASP_VERSION}
WORKDIR /app
COPY . .
# wasp install: the project's npm dependencies (node_modules is not in the build context)
# wasp build: compiles the app into .wasp/out (installs its npm dependencies, builds the SDK)
RUN wasp install && wasp build
# Same steps as the generated Dockerfile: server deps, Prisma client, server bundle
RUN cd .wasp/out/server \
 && npm install \
 && npx prisma generate --schema=../db/schema.prisma \
 && npm run bundle \
 && mkdir -p node_modules

# ---------- runtime: only what the server needs ----------
FROM base AS runtime
ENV NODE_ENV=production
WORKDIR /app
# `wasp install` puts every dependency (Express, Prisma client + engines, the Wasp SDK as a
# symlink to .wasp/out/sdk/wasp) in the project-level node_modules; the server bundle resolves
# them by walking up from .wasp/out/server, so keep the same layout.
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.wasp/out/sdk ./.wasp/out/sdk
COPY --from=builder /app/.wasp/out/server/node_modules ./.wasp/out/server/node_modules
COPY --from=builder /app/.wasp/out/server/bundle ./.wasp/out/server/bundle
COPY --from=builder /app/.wasp/out/server/package*.json ./.wasp/out/server/
# Schema + migrations: `npm run start-production` runs `prisma migrate deploy` before starting
COPY --from=builder /app/.wasp/out/db ./.wasp/out/db
WORKDIR /app/.wasp/out/server
# Wasp's server listens on PORT (default 3001). SnapDeploy reads EXPOSE to pick the container
# port and injects PORT to match.
EXPOSE 3001
ENTRYPOINT ["npm", "run", "start-production"]
