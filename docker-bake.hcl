# docker-bake.hcl — Orchestrates parallel workspace builds via Docker BuildKit.
#
# Usage:
#   docker buildx bake              # build all three targets in parallel
#   docker buildx bake panel        # build panel only
#   docker buildx bake nui core     # build nui and core in parallel

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

group "default" {
  targets = ["panel", "nui", "core"]
}

target "panel" {
  target = "panel"
  args = {
    TXDEV_VITE_URL = TXDEV_VITE_URL
  }
}

target "nui" {
  target = "nui"
  args = {
    TXDEV_FXSERVER_PATH = TXDEV_FXSERVER_PATH
  }
}

target "core" {
  target = "core"
  args = {
    GITHUB_REF = GITHUB_REF
  }
}
