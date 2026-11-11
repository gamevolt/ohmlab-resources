#TODO W.I.P ```sudo setcap cap_sys_nice+ep "$(which gamescope)"```
```
mkdir -p /etc/systemd/system/user-.slice.d write /etc/systemd/system/user-.slice.d/io.conf
"[Slice] IOWeight=1000"```

── Systemd user drop-ins: cap RAM on the heaviest background services ─────────
These sit in the user service manager cgroup and prevent baloo / akonadi
from quietly consuming hundreds of MB while a game is running.
Users who need more headroom for mail/search can raise these in their own
```~/.config/systemd/user/ overrides.
mkdir -p /etc/systemd/user

for svc_dir in
"baloo_file.service.d"
"akonadiserver.service.d"
"kdeconnectd.service.d"
"evolution-data-server.service.d"
"tracker-miner-fs-3.service.d"
"kactivitymanagerd.service.d"
"kwalletd6.service.d" do mkdir -p "/etc/systemd/user/${svc_dir}" done```

```cat << 'DROP' > /etc/systemd/user/baloo_file.service.d/ohmlab-memcap.conf```

ohmlab OS: hard cap on Baloo file indexer
Default: unbounded. During peak indexing it can exceed 400 MB.
[Service] MemoryHigh=64M MemoryMax=128M DROP

cat << 'DROP' > /etc/systemd/user/akonadiserver.service.d/ohmlab-memcap.conf

ohmlab OS: hard cap on Akonadi PIM server
Most ohmlab users don't use KDE PIM; cap prevents runaway growth.
```[Service] MemoryHigh=128M MemoryMax=256M DROP

cat << 'DROP' > /etc/systemd/user/kdeconnectd.service.d/ohmlab-memcap.conf [Service] MemoryHigh=48M MemoryMax=96M DROP

cat << 'DROP' > /etc/systemd/user/evolution-data-server.service.d/ohmlab-memcap.conf [Service] MemoryHigh=64M MemoryMax=128M DROP

cat << 'DROP' > /etc/systemd/user/tracker-miner-fs-3.service.d/ohmlab-memcap.conf```

tracker-miner-fs-3 (GNOME file tracker) — may not exist on KDE but harmless if so.
```[Service] MemoryHigh=48M MemoryMax=96M DROP

cat << 'DROP' > /etc/systemd/user/kactivitymanagerd.service.d/ohmlab-memcap.conf
```
Activity tracking daemon — most users never use KDE Activities, but it
runs by default and its SQLite usage-tracking DB grows over time.
```[Service] MemoryHigh=48M MemoryMax=96M DROP

cat << 'DROP' > /etc/systemd/user/kwalletd6.service.d/ohmlab-memcap.conf
```
KWallet password manager daemon — cap to 48 MB; rarely needs more.
[Service] MemoryHigh=48M MemoryMax=96M DROP

NetworkManager-wait-online (saves 5.1s)
```sudo systemctl disable NetworkManager-wait-online.service echo "[OK] NetworkManager-wait-online disabled"```

Serial ports ttyS0-3 (saves 4.8s)
```sudo systemctl mask serial-getty@ttyS0.service sudo systemctl mask serial-getty@ttyS1.service sudo systemctl mask serial-getty@ttyS2.service sudo systemctl mask serial-getty@ttyS3.service echo "[OK] Serial ports masked"```

Disable unused services
```sudo systemctl disable systemd-hwdb-update.service 2>/dev/null sudo systemctl disable avahi-daemon.service 2>/dev/null sudo systemctl disable cups.service 2>/dev/null sudo systemctl disable cups-browsed.service 2>/dev/null sudo systemctl disable geoclue.service 2>/dev/null sudo systemctl disable power-profiles-daemon.service 2>/dev/null cat << 'NETSYSCTL' > /etc/sysctl.d/91-ohmlab-network.conf```

ohmlab OS: network gaming optimisation
net.core.rmem_max = 134217728 net.core.wmem_max = 134217728 net.core.rmem_default = 262144 net.core.wmem_default = 262144 net.ipv4.tcp_rmem = 4096 262144 134217728 net.ipv4.tcp_wmem = 4096 262144 134217728 net.ipv4.udp_rmem_min = 8192 net.ipv4.udp_wmem_min = 8192 net.core.default_qdisc = cake net.ipv4.tcp_congestion_control = bbr net.ipv4.tcp_fastopen = 3 net.ipv4.tcp_tw_reuse = 1 net.ipv4.tcp_fin_timeout = 15 net.ipv4.tcp_max_tw_buckets = 1440000 net.ipv4.tcp_slow_start_after_idle = 0 net.ipv4.tcp_no_metrics_save = 1 net.core.netdev_max_backlog = 50000 net.core.netdev_budget = 600 net.core.netdev_budget_usecs = 8000 net.core.somaxconn = 65535 net.ipv4.neigh.default.gc_thresh1 = 4096 net.ipv4.neigh.default.gc_thresh2 = 8192 net.ipv4.neigh.default.gc_thresh3 = 16384 net.ipv4.ip_local_port_range = 1024 65535

Socket busy-polling: spin up to 50 µs before sleeping when waiting for
incoming data. Eliminates the wakeup round-trip for low-latency UDP game
traffic (position updates, voice). Only applies to sockets that opt in.
net.core.busy_read = 50 net.core.busy_poll = 50

Maximum open file descriptors — large open-world games and heavily modded
titles can exhaust the default 1 M limit on big mod lists.
fs.file-max = 2097152 NETSYSCTL

tmpfs on /tmp
tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0

Places /tmp in RAM, reduces SSD writes and speeds up applications that use temporary files. On a 16 GB system, the typical /tmp usage is negligible compared to total RAM.

F2FS for secondary/scratch SSDs
If you have a second SSD used for downloads, extraction scratch space, or disposable data, consider formatting it as F2FS instead of ext4/XFS. F2FS is a flash‑optimized filesystem that excels at sequential write workloads. It's ideal for drives where data integrity isn't critical (temp downloads, game library mirroring).

# Format (DESTRUCTIVE: wipes the drive)
sudo mkfs.f2fs -f /dev/sdX

# Mount
UUID=... /mount/point f2fs defaults,noatime,nofail 0 0

IO Scheduler: switch to ADIOS
CachyOS defaults are mq-deadline (SATA SSD), kyber (NVMe), and bfq (HDD). For a single‑user desktop with mixed workloads, ADIOS (Adaptive Disk I/O Scheduler, a CachyOS kernel feature) provides better all‑around performance.

ADIOS uses per‑CPU dispatch queues with adaptive batching. It balances throughput and latency better than mq-deadline (which can hurt latency with aggressive merges) and kyber (which targets fixed latency at the cost of throughput).

Create /etc/udev/rules.d/60-ioschedulers.rules:

# HDD: BFQ remains the right choice
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", \
    ATTR{queue/scheduler}="bfq"

# SSD: use ADIOS instead of mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="adios"

# NVMe: use ADIOS instead of kyber
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="adios"

Apply:

sudo udevadm control --reload-rules && sudo udevadm trigger

Verify:

cat /sys/block/sdX/queue/scheduler
# Should show [adios] for SSDs, [bfq] for HDDs

NVMe Power Management (Optional)
Some NVMe drives aggressively enter power‑saving states, causing micro‑stutters when they wake up.

# Disable APST (Autonomous Power State Transition)
echo on | sudo tee /sys/class/nvme/nvme0/device/power/control
# To make it permanent, add to a systemd service or rc.local

8. GPU: NVIDIA
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

OptiScaler
For DLSS‑style upscaling on non‑RTX hardware (GTX 1650, 1660, etc.), OptiScaler injects FSR/XeSS into games that only support DLSS. Install as a Wine DLL override and configure per‑game.

OnlineFix / cracked game support
For games using OnlineFix multiplayer patches, add these Wine DLL overrides:

onlinefix64=n;winmm=n,b;steam_api64=n;version=n,b

Reference: onlinefix-linux

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
