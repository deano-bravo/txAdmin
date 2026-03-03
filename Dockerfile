# Stage 1: Install dependencies (cached until package files change)
FROM node:22-alpine AS deps

WORKDIR /app

# Copy all package manifests before source to maximise layer cache hits
COPY package.json package-lock.json ./
COPY core/package.json ./core/
COPY panel/package.json ./panel/
COPY nui/package.json ./nui/
COPY shared/package.json ./shared/

RUN npm ci

# Stage 2: Build all workspaces
FROM deps AS builder

# Used by scripts/build/publish.ts to embed the version; override with --build-arg
ARG GITHUB_REF=refs/tags/v9.9.9-dev

# Required by nui/vite.config.ts (checked at config load time)
ARG TXDEV_FXSERVER_PATH=/tmp/fxserver
# TXDEV_VITE_URL has a default in txDevEnv.ts but the .env file must exist
ARG TXDEV_VITE_URL=http://localhost:40122

# Create .env before any npm build command so process.loadEnvFile() succeeds
RUN echo "TXDEV_FXSERVER_PATH=${TXDEV_FXSERVER_PATH}" > .env \
    && echo "TXDEV_VITE_URL=${TXDEV_VITE_URL}" >> .env

# Copy source files (layer invalidated only when sources change, not on dep updates)
COPY . .

RUN npm run build

# Stage 3: Minimal output image containing only the built artefacts
FROM scratch AS output

COPY --from=builder /app/dist /
