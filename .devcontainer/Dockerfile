# Dev container image for txAdmin.
# Provides Node 22, common dev utilities, and pre-installed workspace dependencies.
# VS Code Insiders connects to this container; extensions are declared in devcontainer.json.
FROM node:22-bookworm-slim

# Install OS-level dev utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        bash \
        procps \
        sudo \
    && rm -rf /var/lib/apt/lists/*

# Allow the built-in `node` user to use sudo without a password (devcontainer convention)
RUN echo "node ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/node \
    && chmod 0440 /etc/sudoers.d/node

WORKDIR /workspace

# Pre-install workspace dependencies (layer cached until any package manifest changes).
# BuildKit cache keeps the npm package cache between rebuilds.
COPY package.json package-lock.json ./
COPY core/package.json ./core/
COPY panel/package.json ./panel/
COPY nui/package.json ./nui/
COPY shared/package.json ./shared/

RUN --mount=type=cache,target=/npm-cache \
    npm ci --cache /npm-cache

USER node
