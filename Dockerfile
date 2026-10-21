ARG WASP_VERSION=0.25.0
ARG NODE_IMAGE=node:24-bookworm-slim

# Stage 1: install the Wasp CLI, build the app, bundle the server.
# Debian-based image: the Wasp CLI ships glibc binaries.
FROM ${NODE_IMAGE} AS builder
ARG WASP_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates python3 build-essential \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g @wasp.sh/wasp-cli@${WASP_VERSION}
WORKDIR /app
COPY . .
RUN wasp install && wasp build
RUN cd .wasp/out/server \
 && npm install \
 && npx prisma generate --schema=../db/schema.prisma \
 && npm run bundle \
 && mkdir -p node_modules

# Stage 2: runtime. Two stages in total, which is what SnapDeploy's free Small container allows.
FROM ${NODE_IMAGE} AS runtime
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.wasp/out/sdk ./.wasp/out/sdk
COPY --from=builder /app/.wasp/out/server/node_modules ./.wasp/out/server/node_modules
COPY --from=builder /app/.wasp/out/server/bundle ./.wasp/out/server/bundle
COPY --from=builder /app/.wasp/out/server/package*.json ./.wasp/out/server/
COPY --from=builder /app/.wasp/out/db ./.wasp/out/db
WORKDIR /app/.wasp/out/server
EXPOSE 3001
ENTRYPOINT ["npm", "run", "start-production"]
