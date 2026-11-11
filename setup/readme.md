#TODO W.I.P
sudo setcap cap_sys_nice+ep "$(which gamescope)"

### tmpfs on /tmp

```
tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0
```

Places `/tmp` in RAM, reduces SSD writes and speeds up applications that use temporary files. On a 16 GB system, the typical `/tmp` usage is negligible compared to total RAM.

### F2FS for secondary/scratch SSDs

If you have a second SSD used for downloads, extraction scratch space, or disposable data, consider formatting it as **F2FS** instead of ext4/XFS. F2FS is a flash‑optimized filesystem that excels at sequential write workloads. It's ideal for drives where data integrity isn't critical (temp downloads, game library mirroring).

```
# Format (DESTRUCTIVE: wipes the drive)
sudo mkfs.f2fs -f /dev/sdX

# Mount
UUID=... /mount/point f2fs defaults,noatime,nofail 0 0
```

### IO Scheduler: switch to ADIOS

CachyOS defaults are `mq-deadline` (SATA SSD), `kyber` (NVMe), and `bfq` (HDD). For a single‑user desktop with mixed workloads, **ADIOS** (Adaptive Disk I/O Scheduler, a CachyOS kernel feature) provides better all‑around performance.

ADIOS uses per‑CPU dispatch queues with adaptive batching. It balances throughput and latency better than mq-deadline (which can hurt latency with aggressive merges) and kyber (which targets fixed latency at the cost of throughput).

Create `/etc/udev/rules.d/60-ioschedulers.rules`:

```
# HDD: BFQ remains the right choice
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", \
    ATTR{queue/scheduler}="bfq"

# SSD: use ADIOS instead of mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="adios"

# NVMe: use ADIOS instead of kyber
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="adios"
```

Apply:

```
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Verify:

```
cat /sys/block/sdX/queue/scheduler
# Should show [adios] for SSDs, [bfq] for HDDs
```

### NVMe Power Management (Optional)

Some NVMe drives aggressively enter power‑saving states, causing micro‑stutters when they wake up.

```
# Disable APST (Autonomous Power State Transition)
echo on | sudo tee /sys/class/nvme/nvme0/device/power/control
# To make it permanent, add to a systemd service or rc.local
```

## 8. GPU: NVIDIA

### Module parameters (CachyOS provides these)

You don't need to change these, they're already set by CachyOS at `/usr/lib/modprobe.d/nvidia.conf`:

```
options nvidia NVreg_UsePageAttributeTable=1
    NVreg_InitializeSystemMemoryAllocations=0
    NVreg_DynamicPowerManagement=0x02
```

### Enable persistence daemon

Keeps the NVIDIA kernel driver loaded even with no applications using the GPU. Eliminates the ~1–3 second driver initialization delay when launching the first GPU application after boot.

```
sudo systemctl enable --now nvidia-persistenced
```

### Force Full RGB over HDMI

NVIDIA defaults to Limited Range (16–235) over HDMI, causing black crush and washed‑out colors on TVs and monitors. Force Full Range (0–255) RGB.

Create `/etc/X11/xorg.conf.d/20-nvidia-full-rgb.conf`:

```
Section "Device"
    Identifier "NVIDIA"
    Driver "nvidia"
    Option "ColorSpace" "RGB"
    Option "ColorRange" "Full"
EndSection
```

**Critical for TV users**, without this, dark scenes in games and movies will look crushed and gray.

**Note:** If you have `nvidia-settings` daemon running, it might override these settings. Kill it if you see issues:

```
sudo pkill nvidia-settings
```

### Environment variables

Set these system‑wide in `/etc/environment`:

```
__GL_THREADED_OPTIMIZATION=1
__GL_SHADER_DISK_CACHE=1
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
__GL_VRR_ALLOWED=0
__GL_SYNC_TO_VBLANK=0
__GL_MaxFramesAllowed=1
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
WINEDEBUG=-all
```

### OptiScaler

For DLSS‑style upscaling on non‑RTX hardware (GTX 1650, 1660, etc.), [OptiScaler](https://github.com/optiscaler/OptiScaler) injects FSR/XeSS into games that only support DLSS. Install as a Wine DLL override and configure per‑game.

### OnlineFix / cracked game support

For games using OnlineFix multiplayer patches, add these Wine DLL overrides:

```
onlinefix64=n;winmm=n,b;steam_api64=n;version=n,b
```

Reference: [onlinefix-linux](https://github.com/ZzEdovec/onlinefix-linux)

## 11. Audio: PipeWire Low Latency

### Quantum tuning

Lower the PipeWire quantum (processing block size) for reduced audio latency. Create `/etc/pipewire/pipewire.conf.d/10-low-latency.conf`:

```
context.properties = {
    default.clock.rate            = 48000
    default.clock.quantum         = 128
    default.clock.min-quantum     = 128
    default.clock.max-quantum     = 512
}
```

| Setting | Value | Effect |
|---|---|---|
| `clock.rate` | 48000 Hz | Standard sample rate |
| `quantum` | 128 samples | ~2.67 ms processing cycle |
| `min-quantum` | 128 | Minimum allowed block size |
| `max-quantum` | 512 | Maximum allowed block size (~10.67 ms) |

**Latency:** 128 samples / 48000 Hz ≈ 2.67 ms per cycle. Round‑trip ≈ 2× this (~5.3 ms) plus hardware conversion.

**Tradeoff:** Lower quantum = lower latency but higher CPU usage for audio processing. 128 samples is appropriate for competitive gaming and rhythm games. For general desktop use (media playback, voice chat, casual gaming), 256 samples (~5.3 ms) is sufficient and uses less CPU.

Apply:

```
systemctl --user restart pipewire
