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

# Stage 2: Build the panel workspace
FROM deps AS builder

# TXDEV_VITE_URL has a default in txDevEnv.ts, but .env must exist for process.loadEnvFile()
ARG TXDEV_VITE_URL=http://localhost:40122

RUN echo "TXDEV_VITE_URL=${TXDEV_VITE_URL}" > .env

# Copy only the files required by the panel build (changes here won't invalidate deps layer)
COPY LICENSE ./
COPY shared/ ./shared/
COPY scripts/build/ ./scripts/build/
COPY panel/ ./panel/

RUN npm run build -w panel

# Stage 3: Minimal output image containing only the built panel assets
FROM scratch AS output

COPY --from=builder /app/dist/panel /
