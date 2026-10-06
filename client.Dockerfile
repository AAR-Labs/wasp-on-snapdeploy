# Wasp web client on SnapDeploy — a second container from the same repository.
#
# In SnapDeploy's deploy form set "Dockerfile path" to client.Dockerfile and add the
# environment variable REACT_APP_API_URL=https://<your-server-container-url> BEFORE the first
# build: SnapDeploy passes REACT_APP_* variables into the build as --build-arg, and Vite bakes
# the value into the compiled JavaScript at build time (it cannot be changed at runtime).

ARG WASP_VERSION=0.25.0
ARG NODE_IMAGE=node:24-bookworm-slim

FROM ${NODE_IMAGE} AS builder
ARG WASP_VERSION
ARG REACT_APP_API_URL
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates python3 build-essential \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g @wasp.sh/wasp-cli@${WASP_VERSION}
WORKDIR /app
COPY . .
RUN wasp install && wasp build
# Build the client; output lands in .wasp/out/web-app/build (with 200.html as the SPA fallback)
RUN test -n "$REACT_APP_API_URL" || (echo "REACT_APP_API_URL is not set: add it as an environment variable before the first build" && exit 1)
RUN REACT_APP_API_URL=${REACT_APP_API_URL} npx vite build

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Drop the image's stock welcome page first: COPY merges into the directory, and the Wasp
# build ships 200.html rather than index.html, so the stock index.html would otherwise win.
RUN rm -rf /usr/share/nginx/html/*
COPY --from=builder /app/.wasp/out/web-app/build /usr/share/nginx/html
EXPOSE 80
