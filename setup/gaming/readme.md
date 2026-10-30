
#!/usr/bin/env bash
#
# aimdinGUS TV , game launcher
# Target: CachyOS,RakuOS i7 Alder Lake-S, RTX 4060 (AD107), 16GB DDR5
#
# Usage:  ./launch.sh [VAR=value ...] -- <program> [args...]
#  WIP    ./launch.sh VKD3D_CONFIG=force_static_cbv -- %command% WIP-WONT WORK
#
# IMPORTANT: this script targets TWO different render paths.
#   - The Finals (UE5, DX12)  -> VKD3D-Proton -> Vulkan   => section 4 matters
#   - Quake Live / GL titles  -> OpenGL                   => section 3 matters
#   Sections 3 and 4 do NOT affect each other. Tune them separately.

set -uo pipefail

# ---------------------------------------------------------------------------
# 0. Optional: custom Wine tree
#    Only uncomment if you launch NON-Steam games through this script.
#    Do NOT use these when wrapping a Proton launch , mixing a standalone
#    Wine build's libs into Proton's runtime can cause subtle breakage.
# ---------------------------------------------------------------------------
export PATH="/opt/wine-cachyos/bin/:$PATH"
export WINEDLLPATH="/opt/wine-cachyos/lib/wine:/opt/wine-cachyos/lib32/wine${WINEDLLPATH:+:$WINEDLLPATH}"
export LD_LIBRARY_PATH="/opt/wine-cachyos/lib/:/opt/wine-cachyos/lib32/${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export __GL_ConformantBlitFramebufferScissor=0
# ---------------------------------------------------------------------------
# 1. Diagnostics
#    Leave OFF for competitive play , the HUD itself costs a little.
#    Turn ON when you are measuring, not playing.
# ---------------------------------------------------------------------------
# export DXVK_HUD="fps,frametimes,gpuload"
# export MANGOHUD=1
# export PROTON_LOG=1                    # writes ~/steam-<AppID>.log

# ---------------------------------------------------------------------------
# 2. Log suppression , safe, small, keep these
# ---------------------------------------------------------------------------
export WINEDEBUG="-all"
export DXVK_LOG_LEVEL="none"
export VKD3D_DEBUG="none"
export VKD3D_CONFIG=force_static_cbv
# ---------------------------------------------------------------------------
# 3. NVIDIA OpenGL driver path
#    Affects native OpenGL games ONLY (Quake Live, most idTech derivatives).
#    ZERO effect on The Finals. Safe to leave set; just don't credit it.
# ---------------------------------------------------------------------------
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1   # stop the driver pruning the cache
export __GL_THREADED_OPTIMIZATIONS=1           # NOTE: needs 'export', yours lacked it
export __GL_SYNC_TO_VBLANK=0                   # no GL VSync -> lower input lag

# A/B candidates , uncomment ONE at a time and measure:
 export __GL_MaxFramesAllowed=2             # fewer frames in flight: latency vs throughput
# export __GL_FSAA_MODE=0                      # leave AA to the game (was 2 = forced 2x MSAA)
export __GL_VRR_ALLOWED=0                   # re-enable if you have G-Sync/FreeSync

# ---------------------------------------------------------------------------
# 4. Vulkan / VKD3D-Proton path  <- THIS is what drives The Finals
# ---------------------------------------------------------------------------
export PROTON_ENABLE_NVAPI=1                   # harmless; modern Proton enables NVAPI anyway

# Documented by vkd3d-proton as an "unsafe speed hack on NVIDIA" that
# "may or may not give a significant performance uplift". Test it, don't assume:
# export VKD3D_CONFIG="force_static_cbv"

# Other VKD3D_CONFIG options worth knowing (comma-separated):
#   nodxr            disable ray tracing entirely (perf win if you don't want RT)
#   single_queue     no async compute/transfer queues (diagnostic)
#   no_upload_hvv    stop using host-visible VRAM for the upload heap

# Frame limiter , 0 is uncapped. Try ~3 below your refresh rate for pacing:
# export VKD3D_FRAME_RATE=0

# ---------------------------------------------------------------------------
# 5. Wayland , test per game, not globally
#    Some titles lose exclusive fullscreen or break under native Wayland.
# ---------------------------------------------------------------------------
# export PROTON_ENABLE_WAYLAND=1

# ---------------------------------------------------------------------------
# 6. DELIBERATELY NOT SET , and why
# ---------------------------------------------------------------------------
#   mesa_glthread / MESA_NO_ERROR / MESA_NO_DITHER / vblank_mode
#       -> Mesa-only. You run the NVIDIA proprietary driver. Inert.
#   LD_PRELOAD=""
#       -> Blunt instrument. Breaks MangoHud and gamemode injection.
#          The "fixes Steam stutter after 30 min" claim is unverified.
#   WINE_FULLSCREEN_FSR=1
#       -> Renders below native and upscales. Softer image, slight latency
#          cost. Defensible on a weak GPU, questionable on a 4060 in a
#          competitive shooter. A/B it.
#   __GL_FSAA_MODE=2
#       -> Force-enables MSAA behind the game's back. Costs FPS.
#   GBM_BACKEND / __GLX_VENDOR_LIBRARY_NAME
#       -> Your own comment says it: GTX 10 and older only. You're on Ada.

# ---------------------------------------------------------------------------
# 7. Extra VAR=value pairs supplied on the command line
# ---------------------------------------------------------------------------
while [[ "${1:-}" == *=* ]]; do
  export "$1"
  shift
done

# exec so signals (Ctrl-C, Steam shutdown) reach the game directly
exec "$@"
