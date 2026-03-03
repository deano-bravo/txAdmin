# Stage 1: Install dependencies (cached until package files change)
FROM node:22-alpine AS deps

WORKDIR /app

# Copy all workspace manifests so npm workspaces resolution works correctly
COPY package.json package-lock.json ./
COPY core/package.json ./core/
COPY panel/package.json ./panel/
COPY nui/package.json ./nui/
COPY shared/package.json ./shared/

RUN npm ci

# Stage 2: Build the core workspace
FROM deps AS builder

# Passed through by CI (e.g. GITHUB_REF=refs/tags/v7.9.0); falls back to a dev version
ARG GITHUB_REF=refs/tags/v9.9.9-dev

# Create an empty .env so any process.loadEnvFile() calls in build scripts don't throw
RUN echo "" > .env

# Copy only the files required by the core build and publish script
COPY LICENSE ./
COPY fxmanifest.lua entrypoint.js README.md dynamicAds2.json ./
COPY docs/ ./docs/
COPY resource/ ./resource/
COPY web/ ./web/
COPY shared/ ./shared/
COPY scripts/ ./scripts/
COPY core/ ./core/

RUN npm run build -w core

# Stage 3: Minimal output image containing only the built core and static artefacts
FROM scratch AS output

COPY --from=builder /app/dist /
