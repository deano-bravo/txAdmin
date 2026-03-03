# docker-bake.hcl — Orchestrates parallel workspace builds via Docker BuildKit.
#
# Usage:
#   docker buildx bake              # build all three targets in parallel; artefacts exported to dist/
#   docker buildx bake panel        # build panel only → dist/panel/
#   docker buildx bake nui core     # build nui and core in parallel → dist/nui/, dist/core/
#
# Each target writes compiled artefacts directly to the local dist/<workspace>/
# directory (type=local output) — no intermediate Docker image is left behind.
#
# CI registry caching (GitHub Actions / any OCI registry):
#   CACHE_SCOPE=ghcr.io/org/txadmin docker buildx bake

variable "GITHUB_REF" {
  # Fallback used for local builds. Keep in sync with ARG default in Dockerfile.
  default = "refs/tags/v9.9.9-dev"
}

variable "TXDEV_FXSERVER_PATH" {
  default = "/tmp/fxserver"
}

variable "TXDEV_VITE_URL" {
  default = "http://localhost:40122"
}

# Set to an OCI registry ref (e.g. "ghcr.io/org/txadmin") to enable cross-run
# layer caching. Leave empty for local builds (no external registry needed).
variable "CACHE_SCOPE" {
  default = ""
}

# Shared cache configuration injected into every target when CACHE_SCOPE is set.
target "_cache" {
  cache-from = CACHE_SCOPE != "" ? ["type=registry,ref=${CACHE_SCOPE}/cache"] : []
  cache-to   = CACHE_SCOPE != "" ? ["type=registry,ref=${CACHE_SCOPE}/cache,mode=max"] : []
}

group "default" {
  targets = ["panel", "nui", "core"]
}

target "panel" {
  inherits = ["_cache"]
  target = "panel"
  args = {
    TXDEV_VITE_URL = TXDEV_VITE_URL
  }
  output = ["type=local,dest=dist/panel"]
}

target "nui" {
  inherits = ["_cache"]
  target = "nui"
  args = {
    TXDEV_FXSERVER_PATH = TXDEV_FXSERVER_PATH
  }
  output = ["type=local,dest=dist/nui"]
}

target "core" {
  inherits = ["_cache"]
  target = "core"
  args = {
    GITHUB_REF = GITHUB_REF
  }
  output = ["type=local,dest=dist/core"]
}
