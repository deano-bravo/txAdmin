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

# Stage 2: Build the nui workspace
FROM deps AS builder

# nui/vite.config.ts checks TXDEV_FXSERVER_PATH at config-load time (even in production mode)
ARG TXDEV_FXSERVER_PATH=/tmp/fxserver

RUN echo "TXDEV_FXSERVER_PATH=${TXDEV_FXSERVER_PATH}" > .env

# Copy only the files required by the nui build (changes here won't invalidate deps layer)
COPY LICENSE ./
COPY shared/ ./shared/
COPY scripts/build/ ./scripts/build/
COPY nui/ ./nui/

RUN npm run build -w nui

# Stage 3: Minimal output image containing only the built NUI assets
FROM scratch AS output

COPY --from=builder /app/dist/nui /
