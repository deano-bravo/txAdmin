# ============================================================================
# txAdmin — Multi-stage Docker build with NVIDIA CUDA runtime baked in
# All dependencies precompiled and cached as layers for instant subsequent builds
# ============================================================================
# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Stage 1: deps — Install ALL dependencies (cached until package files change)
# ---------------------------------------------------------------------------
FROM nvidia/cuda:12.5.1-cudnn-runtime-ubuntu22.04 AS deps

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js 22.x, build tools for native modules, and system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        build-essential \
        python3 \
        git \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy ONLY package manifests first — maximizes Docker layer cache.
# This layer only rebuilds when dependencies change.
COPY package.json package-lock.json ./
COPY core/package.json ./core/
COPY nui/package.json ./nui/
COPY panel/package.json ./panel/
COPY shared/package.json ./shared/

# Install all dependencies (including devDependencies needed for build).
# BuildKit cache mount keeps the npm cache across builds for faster reinstalls.
RUN --mount=type=cache,target=/root/.npm \
    npm ci --include=dev

# ---------------------------------------------------------------------------
# Stage 2: builder — Precompile EVERYTHING (cached until source changes)
# ---------------------------------------------------------------------------
FROM deps AS builder

# Copy full source tree on top of cached deps
COPY . .

# The nui and panel vite configs call process.loadEnvFile('../.env') and check
# for TXDEV_FXSERVER_PATH. Production builds don't use the path, but the
# top-level guard exits if the var is missing. Provide a stub .env so the
# build proceeds.
RUN echo 'TXDEV_FXSERVER_PATH=/tmp' > .env

# Run the full monorepo build:
#   1. nui   (Vite → dist/nui/)
#   2. panel (Vite → dist/panel/)
#   3. core  (esbuild → dist/core/index.js)
#   4. license file generation
# GITHUB_REF sets the version string baked into the build artifacts.
ARG TX_VERSION=v0.0.0-docker
RUN GITHUB_REF="refs/tags/${TX_VERSION}" npm run build

# ---------------------------------------------------------------------------
# Stage 3: runtime — Slim production image with NVIDIA runtime pre-baked
# ---------------------------------------------------------------------------
FROM nvidia/cuda:12.5.1-cudnn-runtime-ubuntu22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Install only Node.js runtime + tini (PID 1 init) — no compilers, no dev headers
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        tini \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user for runtime security
RUN groupadd -r txadmin && useradd -r -g txadmin -d /app -s /sbin/nologin txadmin

# NVIDIA runtime environment — ensures GPU is visible and CUDA libs are on path
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

# txAdmin runtime configuration defaults
ENV TXHOST_DATA_PATH=/txdata \
    TXHOST_TXA_PORT=40120 \
    TXHOST_FXS_PORT=30120 \
    TXHOST_INTERFACE=0.0.0.0

WORKDIR /app

# Copy precompiled build output from builder stage
COPY --from=builder --chown=txadmin:txadmin /app/dist ./dist

# Copy runtime package manifests and install production-only deps
COPY --from=builder --chown=txadmin:txadmin /app/package.json /app/package-lock.json ./
COPY --from=builder --chown=txadmin:txadmin /app/core/package.json ./core/
COPY --from=builder --chown=txadmin:txadmin /app/nui/package.json ./nui/
COPY --from=builder --chown=txadmin:txadmin /app/panel/package.json ./panel/
COPY --from=builder --chown=txadmin:txadmin /app/shared/package.json ./shared/

RUN --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev --ignore-scripts 2>/dev/null || true

# Copy shared utilities (runtime imports)
COPY --from=builder --chown=txadmin:txadmin /app/shared ./shared

# Create persistent data directory with correct ownership
RUN mkdir -p /txdata && chown txadmin:txadmin /txdata

# Expose txAdmin web panel + FXServer game port
EXPOSE 40120
EXPOSE 30120/tcp
EXPOSE 30120/udp

# Healthcheck: verify txAdmin web panel is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -sf http://localhost:40120/ || exit 1

# Switch to non-root user
USER txadmin

# Run from the dist directory where entrypoint.js lives
WORKDIR /app/dist

# tini handles signal forwarding and zombie process reaping as PID 1
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "entrypoint.js"]
