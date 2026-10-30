#!/usr/bin/env bash
set -Eeuo pipefail

# Usage:
#   ./gamingenv.sh [VAR=value ...] -- <program> [args...]
#   ./gamingenv.sh -- gamemoderun %command%
#
# Notes:
#   - Defaults are intentionally conservative.
#   - User-provided env vars always win.
#   - Custom Wine is only activated if it exists.
#   - This script is safe for both Proton and native GL/Vulkan titles.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

append_path_if_missing() {
  local dir="${1:-}"
  [[ -n "$dir" ]] || return 0
  [[ -d "$dir" ]] || return 0
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir:$PATH" ;;
  esac
}

append_env_path_if_missing() {
  local env_name="${1:-}"
  local dir="${2:-}"
  [[ -n "$env_name" && -n "$dir" ]] || return 0
  [[ -d "$dir" ]] || return 0

  local current="${!env_name:-}"
  case ":$current:" in
    *":$dir:"*) ;;
    *)
      if [[ -n "$current" ]]; then
        export "$env_name=$dir:$current"
      else
        export "$env_name=$dir"
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 0. Optional Wine tree (only for non-Steam games)
# ---------------------------------------------------------------------------

# Keep Wine custom tree off unless it is actually present.
WINE_ROOT="/opt/wine-cachyos"

append_path_if_missing "$WINE_ROOT/bin"
append_env_path_if_missing "WINEDLLPATH" "$WINE_ROOT/lib/wine"
append_env_path_if_missing "WINEDLLPATH" "$WINE_ROOT/lib32/wine"
append_env_path_if_missing "LD_LIBRARY_PATH" "$WINE_ROOT/lib"
append_env_path_if_missing "LD_LIBRARY_PATH" "$WINE_ROOT/lib32"

# ---------------------------------------------------------------------------
# 1. Diagnostics
#    Keep these OFF unless actively debugging or benchmarking.
# ---------------------------------------------------------------------------

# export DXVK_HUD="${DXVK_HUD:-fps,frametimes,gpuload}"
# export MANGOHUD="${MANGOHUD:-1}"
# export PROTON_LOG="${PROTON_LOG:-1}"

# ---------------------------------------------------------------------------
# 2. General log suppression and safe defaults
# ---------------------------------------------------------------------------

export WINEDEBUG="${WINEDEBUG:--all}"
export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
export VKD3D_DEBUG="${VKD3D_DEBUG:-none}"

# Keep this as a default only if you have tested it.
# A lot of users get better stability by leaving it unset and tuning per game.
export VKD3D_CONFIG="${VKD3D_CONFIG:-force_static_cbv}"

# ---------------------------------------------------------------------------
# 3. NVIDIA OpenGL tuning
#    These affect native OpenGL titles only. Not The Finals / DX12.
# ---------------------------------------------------------------------------

export __GL_SHADER_DISK_CACHE="${__GL_SHADER_DISK_CACHE:-1}"
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP="${__GL_SHADER_DISK_CACHE_SKIP_CLEANUP:-1}"
export __GL_THREADED_OPTIMIZATIONS="${__GL_THREADED_OPTIMIZATIONS:-1}"
export __GL_SYNC_TO_VBLANK="${__GL_SYNC_TO_VBLANK:-0}"
export __GL_MaxFramesAllowed="${__GL_MaxFramesAllowed:-2}"
# export __GL_FSAA_MODE="${__GL_FSAA_MODE:-0}"
export __GL_VRR_ALLOWED="${__GL_VRR_ALLOWED:-0}"

# ---------------------------------------------------------------------------
# 4. Vulkan / VKD3D-Proton tuning
#    This is the path that matters for The Finals / DX12 titles.
# ---------------------------------------------------------------------------

# NVAPI is usually safe to leave on. Modern Proton often enables it anyway.
export PROTON_ENABLE_NVAPI="${PROTON_ENABLE_NVAPI:-1}"

# Examples:
# export VKD3D_CONFIG="${VKD3D_CONFIG:-force_static_cbv,nodxr}"
# export VKD3D_FRAME_RATE="${VKD3D_FRAME_RATE:-0}"

# ---------------------------------------------------------------------------
# 5. Wayland
#    Enable only if a title actually needs it.
# ---------------------------------------------------------------------------

# export PROTON_ENABLE_WAYLAND="${PROTON_ENABLE_WAYLAND:-1}"

# ---------------------------------------------------------------------------
# 6. Per-user override file
#    Put game-specific values here:
#    ~/.config/ohmlab/gamingenv.local
# ---------------------------------------------------------------------------

if [[ -f "${HOME}/.config/ohmlab/gamingenv.local" ]]; then
  # shellcheck disable=SC1090
  source "${HOME}/.config/ohmlab/gamingenv.local"
fi

# ---------------------------------------------------------------------------
# 7. Allow explicit runtime overrides, e.g.:
#      ./gamingenv.sh __GL_MaxFramesAllowed=1 VKD3D_CONFIG=force_static_cbv -- game
# ---------------------------------------------------------------------------

while [[ $# -gt 0 && "${1:-}" == *=* ]]; do
  export "$1"
  shift
done

if [[ $# -gt 0 && "${1:-}" == "--" ]]; then
  shift
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 [VAR=value ...] -- <program> [args...]" >&2
  exit 1
fi

if ! command -v "$1" >/dev/null 2>&1; then
  echo "Command not found in PATH: $1" >&2
  exit 127
fi

# Forward signals correctly and keep the launched process as the foreground app.
exec -- "$@"
