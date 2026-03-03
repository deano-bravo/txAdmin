# syntax=docker/dockerfile:1
#
# Multi-target Dockerfile for txAdmin workspaces.
# Build a specific workspace:  docker build --target panel .
#                               docker build --target nui .
#                               docker build --target core .
# Build everything (default):  docker build .
# Build all targets in parallel: docker buildx bake

##############################################################################
# Stage: deps
# Installs all workspace dependencies. This layer is cached until any
# package manifest changes. The BuildKit npm cache persists across builds.
##############################################################################
FROM node:22-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./
COPY core/package.json ./core/
COPY panel/package.json ./panel/
COPY nui/package.json ./nui/
COPY shared/package.json ./shared/

RUN --mount=type=cache,target=/npm-cache,sharing=locked \
    npm ci --cache /npm-cache

##############################################################################
# Stage: build-panel
# Builds only the Vite React panel. Invalidated by changes to panel/ or shared/.
##############################################################################
FROM deps AS build-panel

# .env must exist for process.loadEnvFile(); TXDEV_VITE_URL has a sensible default
ARG TXDEV_VITE_URL=http://localhost:40122
RUN echo "TXDEV_VITE_URL=${TXDEV_VITE_URL}" > .env

COPY LICENSE ./
COPY shared/ ./shared/
COPY scripts/build/ ./scripts/build/
COPY panel/ ./panel/

RUN npm run build -w panel

##############################################################################
# Stage: build-nui
# Builds only the NUI bundle. Invalidated by changes to nui/ or shared/.
##############################################################################
FROM deps AS build-nui

# nui/vite.config.ts exits at config-load time when TXDEV_FXSERVER_PATH is unset
ARG TXDEV_FXSERVER_PATH=/tmp/fxserver
RUN echo "TXDEV_FXSERVER_PATH=${TXDEV_FXSERVER_PATH}" > .env

COPY LICENSE ./
COPY shared/ ./shared/
COPY scripts/build/ ./scripts/build/
COPY nui/ ./nui/

RUN npm run build -w nui

##############################################################################
# Stage: build-core
# Bundles the backend via esbuild and copies static artefacts.
# Invalidated by changes to core/, shared/, scripts/, or static files.
##############################################################################
FROM deps AS build-core

# scripts/build/publish.ts embeds this as the release version string.
# Keep the default in sync with the GITHUB_REF variable in docker-bake.hcl.
ARG GITHUB_REF=refs/tags/v9.9.9-dev
RUN echo "" > .env

COPY LICENSE ./
COPY fxmanifest.lua entrypoint.js README.md dynamicAds2.json ./
COPY docs/ ./docs/
COPY resource/ ./resource/
COPY web/ ./web/
COPY shared/ ./shared/
COPY locale/ ./locale/
COPY scripts/ ./scripts/
COPY core/ ./core/

RUN mkdir -p .github \
    && npm run build -w core

##############################################################################
# Stage: build-all
# Full monorepo build — all three workspaces in one pass.
##############################################################################
FROM deps AS build-all

ARG GITHUB_REF=refs/tags/v9.9.9-dev  # keep in sync with docker-bake.hcl
ARG TXDEV_FXSERVER_PATH=/tmp/fxserver
ARG TXDEV_VITE_URL=http://localhost:40122

RUN echo "TXDEV_FXSERVER_PATH=${TXDEV_FXSERVER_PATH}" > .env \
    && echo "TXDEV_VITE_URL=${TXDEV_VITE_URL}" >> .env

COPY . .

RUN mkdir -p .github \
    && npm run build

##############################################################################
# Output stages — minimal scratch images with only the built artefacts.
##############################################################################
FROM scratch AS panel
COPY --from=build-panel /app/dist/panel /

FROM scratch AS nui
COPY --from=build-nui /app/dist/nui /

FROM scratch AS core
COPY --from=build-core /app/dist /

FROM scratch AS all
COPY --from=build-all /app/dist /
