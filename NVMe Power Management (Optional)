NVMe Power Management (Optional)
Some NVMe drives aggressively enter power‑saving states, causing micro‑stutters when they wake up.
# Disable APST (Autonomous Power State Transition)
echo on | sudo tee /sys/class/nvme/nvme0/device/power/control
# To make it permanent, add to a systemd service or rc.local
Module parameters (CachyOS provides these)
You don't need to change these, they're already set by CachyOS at /usr/lib/modprobe.d/nvidia.conf:

options nvidia NVreg_UsePageAttributeTable=1
    NVreg_InitializeSystemMemoryAllocations=0
    NVreg_DynamicPowerManagement=0x02
Enable persistence daemon
Keeps the NVIDIA kernel driver loaded even with no applications using the GPU. Eliminates the ~1–3 second driver initialization delay when launching the first GPU application after boot.

sudo systemctl enable --now nvidia-persistenced
Force Full RGB over HDMI
NVIDIA defaults to Limited Range (16–235) over HDMI, causing black crush and washed‑out colors on TVs and monitors. Force Full Range (0–255) RGB.

Create /etc/X11/xorg.conf.d/20-nvidia-full-rgb.conf:

Section "Device"
    Identifier "NVIDIA"
    Driver "nvidia"
    Option "ColorSpace" "RGB"
    Option "ColorRange" "Full"
EndSection
Critical for TV users, without this, dark scenes in games and movies will look crushed and gray.

Note: If you have nvidia-settings daemon running, it might override these settings. Kill it if you see issues:

sudo pkill nvidia-settings
Environment variables
Set these system‑wide in /etc/environment:

__GL_THREADED_OPTIMIZATION=1
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
__GL_VRR_ALLOWED=0
__GL_SYNC_TO_VBLANK=0
__GL_MaxFramesAllowed=1
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
WINEDEBUG=-all
Variable	Effect	Skip if
__GL_THREADED_OPTIMIZATION=1	Multi‑threaded OpenGL pipeline	,
__GL_SHADER_DISK_CACHE=1	Persistent compiled on disk	If disk space is extremely tight
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1	Stop driver from purging cache periodically	,
__GL_VRR_ALLOWED=0	Disable VRR (GSync/FreeSync)	If you use a VRR display and want tear‑free
__GL_SYNC_TO_VBLANK=0	Disable V‑Sync at driver level	If tearing bothers you
__GL_MaxFramesAllowed=1	Pre‑rendered frames = 1 (lowest latency)	,
VK_ICD_FILENAMES	Force NVIDIA Vulkan ICD	Only if you have multiple GPUs
WINEDEBUG=-all	Suppress Wine debug output	If you're debugging Wine issues
Shader Cache Size
__GL_SHADER_DISK_CACHE=1 enables the cache, but without a size limit, the driver uses its default cap of 1 GB (increased from 128 MB in driver 460). Modern titles (especially DXVK/VKD3D) can generate 2–4 GB of shaders across your library. When the cache exceeds the limit, the driver purges older entries, forcing recompilation on next launch, causing stutter and longer load times.

Set a global size limit to prevent eviction:

mkdir -p ~/.config/environment.d
echo "__GL_SHADER_DISK_CACHE_SIZE=12000000000" > ~/.config/environment.d/shader_cache.conf
Log out and back in, or reboot. Verify with:

env | grep __GL_SHADER_DISK_CACHE_SIZE
Note: Setting __GL_SHADER_DISK_CACHE_SIZE globally ensures every application uses the same limit. If you set it per‑game and omit it on some launches, the driver reverts to the 1 GB default and wipes the cache when it exceeds the smaller limit.

Optional, clear legacy caches (old .nv path still uses 128 MB default):

rm -rf ~/.nv/GLCache ~/.cache/nvidia/GLCache
The driver will rebuild under the new XDG path (~/.cache/nvidia/GLCache) with the 4 GB cap applied.

V‑Sync and VRR Warning
Risk level: MINOR (visual)

__GL_SYNC_TO_VBLANK=0 and __GL_VRR_ALLOWED=0 disable all synchronization. You will see screen tearing, especially below your display's refresh rate. This is a latency vs. visual quality tradeoff, uncapped, unsynchronized frames produce the lowest possible input latency.

Set both to 1 if you prefer tear‑free output and don't need the absolute minimum latency.

NVIDIA Wayland Reality Check
Wayland on NVIDIA is finicky. The guide assumes nvidia_drm.modeset=1 is enough. It's necessary, but not sufficient.

Requirements for a smooth Wayland experience:

NVIDIA driver ≥ 550.xx (check with nvidia-smi --query-gpu=driver_version --format=csv,noheader)
Compositor with explicit sync support:
KDE Plasma ≥ 6.1
GNOME ≥ 46
COSMIC (latest)
If you get a black screen or flickering, switch to X11 (nvidia_drm.modeset=0 or just choose X11 session at login).
9. GPU Overclocking via LACT
LACT controls NVIDIA GPUs through the NVML API. It provides a GUI for overclocking, fan curves, and monitoring.

sudo systemctl enable --now lactd
The Clock Lock Strategy (Not "Under‑volting")
Modern NVIDIA GPUs (Turing and later) don't support traditional undervolting in Linux. Instead, use a clock lock: lock the GPU clock below the stock boost target and add a positive offset to the P8 voltage point.

Why this works: The GPU runs at a higher voltage than it naturally would at that clock, eliminating power throttling while staying cooler than stock boost behavior.

For GTX 1650 / Turing‑class GPUs:

Setting	Value	Notes
Power Limit	Max (75W for GTX 1650)	Your GPU's maximum, check with nvidia-smi -q -d POWER
GPU Min Clock	300 MHz	Stock minimum
GPU Max Clock	~100 MHz below stock boost	For GTX 1650: 1860 MHz (stock boost ~1905–1935 MHz)
GPU Offset (P8)	+100 MHz	Raises voltage at the locked clock
VRAM Offset (P8)	+500 to +900 MHz	Start at +500, test for stability, increase gradually
Finding your stock boost clock:

nvidia-smi -q -d CLOCK | grep "Max Clocks"
Texture quality overrides
These replicate NVIDIA Control Panel "High Quality" texture filtering at the application level, useful since NVIDIA Settings on Linux doesn't expose these controls per‑game.

DXVK (DirectX 9/10/11 games via Proton):
DXVK_ANISO=16 DXVK_LODBIAS=-0.5 PROTON_ENABLE_WAYLAND=1 gamemoderun %command%
__GL_LOG_ANISO=16 __GL_TEXTURE_LOD_BIAS=-0.5 SDL_VIDEODRIVER=wayland gamemoderun %command%


11. Audio: PipeWire Low Latency
Quantum tuning
Lower the PipeWire quantum (processing block size) for reduced audio latency. Create /etc/pipewire/pipewire.conf.d/10-low-latency.conf:

context.properties = {
    default.clock.rate            = 48000
    default.clock.quantum         = 128
    default.clock.min-quantum     = 128
    default.clock.max-quantum     = 512
}
Setting	Value	Effect
clock.rate	48000 Hz	Standard sample rate
quantum	128 samples	~2.67 ms processing cycle
min-quantum	128	Minimum allowed block size
max-quantum	512	Maximum allowed block size (~10.67 ms)
Latency: 128 samples / 48000 Hz ≈ 2.67 ms per cycle. Round‑trip ≈ 2× this (~5.3 ms) plus hardware conversion.

Tradeoff: Lower quantum = lower latency but higher CPU usage for audio processing. 128 samples is appropriate for competitive gaming and rhythm games. For general desktop use (media playback, voice chat, casual gaming), 256 samples (~5.3 ms) is sufficient and uses less CPU.

Apply:

systemctl --user restart pipewire
Verify:

pw-top
# Look at the QUANT column during playback
CachyOS audio stack
CachyOS provides these out of the box (you don't need to configure them):

rtkit, grants realtime scheduling to PipeWire
Audio group realtime priority, @audio - rtprio 99
CPU DMA latency device, audio group can suppress CPU C‑states
snd_hda_intel power saving disabled on AC, prevents audio crackling
HPET/RTC permissions, audio group access to high‑precision timers
