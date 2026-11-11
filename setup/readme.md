#TODO W.I.P 
# resources
THE README IS CURRENTLY A PLACE HOLDER AS I ORGANIZE THIS REPO -- THIS IS MEANT FOR STORING RESOURCES WHILE BUILDING + ORGANIZING 
### /ɡrimˈwär/

# 📜 collections of resources,data,scripts and files

##
# grimwär

> **⚠️ WORK IN PROGRESS — UNFINISHED**  
> This repository is a placeholder. DO NOT run scripts blindly — you will likely break your setup.  
> Scripts may contain outdated code from previous bash files. Proceed with caution.

## Collections of Resources, Data, Scripts and Files

W.I.P -- UNFINISHED
- - THIS SCRIPT IS FAR FROM FINISHED AND IS USED AS A PLACEHOLDER AT THE MOMENT, DO NOT RUN BLINDLY - YOU WILL MOST LIKELY BREAK YOUR SETUP SINCE
I MAY ADD THINGS FROM OTHER LEFT OVER BASH SCRIPTS I PREVIOUSLY WROTE WHICH ARE HEAVILY OUTDATED NOW.
YOU'VE BEEN WARNED
W.I.P
- - THIS SCRIPT IS FAR FROM FINISHED AND IS USED AS A PLACEHOLDER AT THE MOMENT, DO NOT RUN BLINDLY - YOU WILL MOST LIKELY BREAK YOUR SETUP SINCE
I MAY ADD THINGS FROM OTHER LEFT OVER BASH SCRIPTS I PREVIOUSLY WROTE WHICH ARE HEAVILY OUTDATED NOW.
YOU'VE BEEN WARNED

```
=================================================================

                                    N O T E S

 ┌│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│┐
 │▓▓                              `/ɡrimˈwär/`                              ▓▓│
 │▓▓                               ohmlab.net                               ▓▓│
 └│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│┘

```
## Table of Contents

- [gamingenv.sh: bash script to apply env variable from steam launch option](#gamingenv.sh)
- [placeholdmepl0x](#placeholder)
- [Lorem  Ipsum](#loremipsum)
  - [Sysctl Settings](#sysctl-settings)
  - [Boot Parameters](#boot-parameters)
- [Gaming Optimizations](#gaming-optimizations)
  - [Steam Launch Options](#steam-launch-options)
  - [Engine.ini Config](#engineini-config)
  - [Game Settings](#game-settings)
- [System Tweaks](#system-tweaks)
- [Additional Resources](#additional-resources)


```


## gamingenv.sh


---

## 📡 Network Configuration

### Randomize MAC Address & Disable Static Hostname

```bash
sudo bash -c 'cat > /etc/NetworkManager/conf.d/00-macrandomize.conf' <<-'EOF'
[main]
hostname-mode=none

[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF
```

```bash
sudo systemctl restart NetworkManager
sudo hostnamectl hostname "localhost"
```

### Disable Connectivity Checks & Wait Online Service

```bash
echo -e "[connectivity]
enabled=false" | sudo tee /etc/NetworkManager/conf.d/20-connectivity.conf
sudo systemctl mask NetworkManager-wait-online.service >/dev/null 2>&1
```

### Fix Local Device Connection Issues

```bash
sudo sed -i -e 's/hosts: .*/hosts: files mdns4_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns mdns4 mdns/' /etc/nsswitch.conf
```

---

## ⚙️ Realtime Priority Settings

```bash
echo -e "@realtime - rtprio 99
@realtime - memlock unlimited" | sudo tee -a /etc/security/limits.conf
```

---


Key options explained:

| Option | Purpose |#!/usr/bin/env bash
# =============================================================
# ohmlab OS — Gaming optimisation installer
# Run as root: sudo ./install.sh
# Target: CachyOS / Arch-based with KDE
# =============================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[ERR] This script must be run as root (sudo ./install.sh)" >&2
    exit 1
fi

echo "==> ohmlab OS gaming optimisation installer"

# ── 1. Gamescope capability ─────────────────────────────────
if command -v gamescope &>/dev/null; then
    setcap cap_sys_nice+ep "$(command -v gamescope)"
    echo "[OK] gamescope granted cap_sys_nice"
else
    echo "[SKIP] gamescope not installed"
fi

# ── 2. User slice I/O priority ───────────────────────────────
mkdir -p /etc/systemd/system/user-.slice.d
cat > /etc/systemd/system/user-.slice.d/io.conf << 'EOF'
[Slice]
IOWeight=1000
EOF
echo "[OK] user slice IOWeight=1000"

# ── 3. Memory caps on heavy background services ──────────────
mkdir -p /etc/systemd/user

declare -A MEMCAPS=(
    [baloo_file.service.d]="64M 128M"
    [akonadiserver.service.d]="128M 256M"
    [kdeconnectd.service.d]="48M 96M"
    [evolution-data-server.service.d]="64M 128M"
    [tracker-miner-fs-3.service.d]="48M 96M"
    [kactivitymanagerd.service.d]="48M 96M"
    [kwalletd6.service.d]="48M 96M"
)

for svc_dir in "${!MEMCAPS[@]}"; do
    read -r memhigh memmax <<< "${MEMCAPS[$svc_dir]}"
    mkdir -p "/etc/systemd/user/${svc_dir}"
    cat > "/etc/systemd/user/${svc_dir}/ohmlab-memcap.conf" << EOF
# ohmlab OS: memory cap
[Service]
MemoryHigh=${memhigh}
MemoryMax=${memmax}
EOF
    echo "[OK] capped ${svc_dir%.service.d} (${memhigh}/${memmax})"
done
unset MEMCAPS

# ── 4. Boot time optimisations ────────────────────────────────
systemctl disable NetworkManager-wait-online.service 2>/dev/null \
    && echo "[OK] NetworkManager-wait-online disabled"
for i in 0 1 2 3; do
    systemctl mask "serial-getty@ttyS${i}.service" 2>/dev/null
done
echo "[OK] serial-getty@ttyS0-3 masked"

for svc in systemd-hwdb-update.service avahi-daemon.service \
           cups.service cups-browsed.service geoclue.service \
           power-profiles-daemon.service; do
    systemctl disable "${svc}" 2>/dev/null \
        && echo "[OK] disabled ${svc}" \
        || echo "[SKIP] ${svc} not present"
done

# ── 5. Network sysctl tuning ─────────────────────────────────
cat > /etc/sysctl.d/91-ohmlab-network.conf << 'EOF'
# ohmlab OS: network gaming optimisation
net.core.rmem_max                  = 134217728
net.core.wmem_max                  = 134217728
net.core.rmem_default              = 262144
net.core.wmem_default              = 262144
net.ipv4.tcp_rmem                  = 4096 262144 134217728
net.ipv4.tcp_wmem                  = 4096 262144 134217728
net.ipv4.udp_rmem_min              = 8192
net.ipv4.udp_wmem_min              = 8192
net.core.default_qdisc             = cake
net.ipv4.tcp_congestion_control    = bbr
net.ipv4.tcp_fastopen              = 3
net.ipv4.tcp_tw_reuse              = 1
net.ipv4.tcp_fin_timeout           = 15
net.ipv4.tcp_max_tw_buckets        = 1440000
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save       = 1
net.core.netdev_max_backlog        = 50000
net.core.netdev_budget             = 600
net.core.netdev_budget_usecs       = 8000
net.core.somaxconn                 = 65535
net.ipv4.neigh.default.gc_thresh1  = 4096
net.ipv4.neigh.default.gc_thresh2  = 8192
net.ipv4.neigh.default.gc_thresh3  = 16384
net.ipv4.ip_local_port_range       = 1024 65535
net.core.busy_read                 = 50
net.core.busy_poll                 = 50
fs.file-max                        = 2097152
EOF
sysctl --system >/dev/null
echo "[OK] network sysctls applied"

# ── 6. I/O schedulers (ADIOS for SSD/NVMe, BFQ for HDD) ──────
mkdir -p /etc/udev/rules.d
cat > /etc/udev/rules.d/60-ioschedulers.rules << 'EOF'
# HDD: BFQ remains the right choice
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", \
    ATTR{queue/scheduler}="bfq"

# SSD: use ADIOS instead of mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="adios"

# NVMe: use ADIOS instead of kyber
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="adios"
EOF
udevadm control --reload-rules
udevadm trigger
echo "[OK] udev I/O scheduler rules applied"

# ── 7. tmpfs on /tmp ──────────────────────────────────────────
if ! grep -qs '^[[:space:]]*tmpfs[[:space:]].*/tmp' /etc/fstab; then
    echo 'tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0' >> /etc/fstab
    echo "[OK] tmpfs on /tmp added to fstab (effective on next mount/boot)"
else
    echo "[SKIP] /tmp already in fstab"
fi

# ── 8. NVIDIA persistence daemon ──────────────────────────────
if systemctl list-unit-files nvidia-persistenced.service &>/dev/null; then
    systemctl enable --now nvidia-persistenced
    echo "[OK] nvidia-persistenced enabled"
else
    echo "[SKIP] nvidia-persistenced not present (non-NVIDIA?)"
fi

# ── 9. NVIDIA environment variables ──────────────────────────
ENV_FILE=/etc/environment
ENV_VARS=(
    "__GL_THREADED_OPTIMIZATION=1"
    "__GL_SHADER_DISK_CACHE=1"
    "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1"
    "__GL_VRR_ALLOWED=0"
    "__GL_SYNC_TO_VBLANK=0"
    "__GL_MaxFramesAllowed=1"
    "VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json"
    "WINEDEBUG=-all"
)
for var in "${ENV_VARS[@]}"; do
    key="${var%%=*}"
    if grep -qs "^${key}=" "${ENV_FILE}"; then
        echo "[SKIP] ${key} already set in ${ENV_FILE}"
    else
        echo "${var}" >> "${ENV_FILE}"
        echo "[OK] ${key} added to ${ENV_FILE}"
    fi
done

# ── 10. NVIDIA Full RGB over HDMI ─────────────────────────────
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/20-nvidia-full-rgb.conf << 'EOF'
Section "Device"
    Identifier "NVIDIA"
    Driver "nvidia"
    Option "ColorSpace" "RGB"
    Option "ColorRange" "Full"
EndSection
EOF
echo "[OK] xorg full-range RGB config written"

# ── 11. PipeWire low latency ──────────────────────────────────
mkdir -p /etc/pipewire/pipewire.conf.d
cat > /etc/pipewire/pipewire.conf.d/10-low-latency.conf << 'EOF'
context.properties = {
    default.clock.rate            = 48000
    default.clock.quantum         = 128
    default.clock.min-quantum     = 128
    default.clock.max-quantum     = 512
}
EOF
echo "[OK] PipeWire low-latency config written (restart pipewire as your user:"
echo "     systemctl --user restart pipewire pipewire-pulse)"

echo
echo "==> Done. Reboot to apply everything (fstab, udev, session env)."
echo "    Verify schedulers with: cat /sys/block/*/queue/scheduler"

|--------|---------|
| `NoNewPrivileges` | Prevents privilege escalation via `execve()` |
| `PrivateTmp` | Creates isolated `/tmp` and `/var/tmp` namespace |
| `PrivateDevices` | Removes physical device access except API pseudos |
| `ProtectSystem=strict` | Mounts entire filesystem read-only except `/dev`, `/proc`, `/sys` |
| `MemoryDenyWriteExecute` | Prevents W^X memory mappings (exploit mitigation) |
| `RestrictAddressFamilies` | Whitelists/blacklists socket families |
| `SystemCallFilter` | Allows/denies specific syscalls |

---

## 🎮 Gaming Optimizations

### Steam Launch Options

```
PROTON_ENABLE_NVAPI=1 \
DXVK_ENABLE_NVAPI=1 \
PROTON_VKD3D_HEAP=1 \
DXVK_NVAPI_LOW_LATENCY=1 \
VKD3D_CONFIG="force_host_cached,force_static_cbv,descriptor_heap" \
DXVK_SHADER_OPTIMIZE=1 \
DXVK_SPIRV_OPT=ON \
__GL_MaxFramesAllowed=2 \
DXVK_ASYNC=1 \
DXVK_HUD=fps,frametime \
%command%
```

#### Variable Breakdown

| Variable | Purpose |
|----------|---------|
| `PROTON_ENABLE_NVAPI=1` | Enables DLSS, Reflex, NVIDIA features |
| `DXVK_ENABLE_NVAPI=1` | DXVK NVIDIA API hooks for better performance |
| `PROTON_VKD3D_HEAP=1` | Uses VKD3D descriptor heap extension (reduces stutter) |
| `VKD3D_CONFIG` | Forces cached shaders, static constant buffer views |
| `DXVK_SHADER_OPTIMIZE=1` | Enables SPIR-V shader optimization |
| `__GL_MaxFramesAllowed=2` | Reduces input latency, caps NVIDIA queue depth |
| `DXVK_ASYNC=1` | Async shader compilation (massive stutter reduction) |
| `DXVK_HUD` | Optional FPS/frametime overlay |

### Engine.ini Config

Location: `~/.steam/steam/steamapps/compatdata/<app_id>/pfx/drive_c/users/steamuser/AppData/Local/FactoryGame/Saved/Config/LinuxServer/`

```ini
[/Script/Engine.RendererSettings]
r.DefaultFeature.AutoExposure=False
r.DefaultFeature.AutoExposure.Method=0
r.DefaultFeature.MotionBlur=False
r.DefaultFeature.AmbientOcclusion=False
r.DefaultFeature.AmbientOcclusionStaticFraction=0
r.AntiAliasingMethod=0
r.TSR.History.ScreenPercentage=100
r.TSR.ShadingRejection.Flickering=0

[/Script/Engine.ScalabilitySettings]
Scalability.QualityLevel=0

[/Script/Engine.UserInterfaceSettings]
UIScaleRule=ShortestSide
UIScaleCurve=(EditorFormatString="0",RuntimeFormatString="0")
LocalUIScale=1.0

[/SystemSettings]

[/Script/Engine.GarbageCollectionSettings]
gc.MaxObjectsNotConsideredByGC=1
gc.SizeOfPermanentObjectPool=0
gc.TimeBetweenPurgingPendingKillObjects=0

[rhi]
r.D3D12.CommandBuffer.AllocationSize=33554432
r.D3D12.ResourceHeapsPerCommandQueue=16
r.D3D12.SubmitPerFrameBudgetInMs=10.0
```

### Game Settings (In-Game Menu)

| Setting | Recommended Value |
|---------|-------------------|
| Display Mode | Fullscreen Exclusive |
| Resolution | Native (or 1600×900 for max FPS) |
| VSync | OFF |
| Motion Blur | OFF |
| Lens Distortion | OFF |
| Film Grain | OFF |
| Chromatic Aberration | OFF |
| Depth of Field | OFF |
| Shadow Quality | Low/Medium |
| Texture Quality | Medium (VRAM dependent) |
| Effects Quality | Low |
| Post Process | Low |
| View Distance | Medium |
| Volumetric Fog | OFF |
| Global Illumination | Screen Space |
| Ray Tracing | OFF |
| DLSS | Quality/Balanced |
| Frame Generation | Depends on GPU |

### Testing Notes

- Proton Experimental generally works better than Proton 8 for *The Finals*
- The `-dx11` flag fixes some rendering bugs but may cause performance degradation
- DLSS works when `PROTON_ENABLE_NVAPI=1` is set
- Frame pacing is significantly better with VKD3D heap enabled

### File Structure Summary

```
~/.steam/steam/steamapps/compatdata/2073850/
├── pfx/
│   └── drive_c/users/steamuser/AppData/Local/FactoryGame/Saved/Config/
│       └── LinuxServer/
│           ├── Engine.ini        ← Main config
│           └── GameUserSettings.ini
└── logs/
    └── proton.log                ← Debug output#!/usr/bin/env bash
# =============================================================
# ohmlab OS — Gaming optimisation installer
# Run as root: sudo ./install.sh
# Target: CachyOS / Arch-based with KDE
# =============================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[ERR] This script must be run as root (sudo ./install.sh)" >&2
    exit 1
fi

echo "==> ohmlab OS gaming optimisation installer"

# ── 1. Gamescope capability ─────────────────────────────────
if command -v gamescope &>/dev/null; then
    setcap cap_sys_nice+ep "$(command -v gamescope)"
    echo "[OK] gamescope granted cap_sys_nice"
else
    echo "[SKIP] gamescope not installed"
fi

# ── 2. User slice I/O priority ───────────────────────────────
mkdir -p /etc/systemd/system/user-.slice.d
cat > /etc/systemd/system/user-.slice.d/io.conf << 'EOF'
[Slice]
IOWeight=1000
EOF
echo "[OK] user slice IOWeight=1000"

# ── 3. Memory caps on heavy background services ──────────────
mkdir -p /etc/systemd/user

declare -A MEMCAPS=(
    [baloo_file.service.d]="64M 128M"
    [akonadiserver.service.d]="128M 256M"
    [kdeconnectd.service.d]="48M 96M"
    [evolution-data-server.service.d]="64M 128M"
    [tracker-miner-fs-3.service.d]="48M 96M"
    [kactivitymanagerd.service.d]="48M 96M"
    [kwalletd6.service.d]="48M 96M"
)

for svc_dir in "${!MEMCAPS[@]}"; do
    read -r memhigh memmax <<< "${MEMCAPS[$svc_dir]}"
    mkdir -p "/etc/systemd/user/${svc_dir}"
    cat > "/etc/systemd/user/${svc_dir}/ohmlab-memcap.conf" << EOF
# ohmlab OS: memory cap
[Service]
MemoryHigh=${memhigh}
MemoryMax=${memmax}
EOF
    echo "[OK] capped ${svc_dir%.service.d} (${memhigh}/${memmax})"
done
unset MEMCAPS

# ── 4. Boot time optimisations ────────────────────────────────
systemctl disable NetworkManager-wait-online.service 2>/dev/null \
    && echo "[OK] NetworkManager-wait-online disabled"
for i in 0 1 2 3; do
    systemctl mask "serial-getty@ttyS${i}.service" 2>/dev/null
done
echo "[OK] serial-getty@ttyS0-3 masked"

for svc in systemd-hwdb-update.service avahi-daemon.service \
           cups.service cups-browsed.service geoclue.service \
           power-profiles-daemon.service; do
    systemctl disable "${svc}" 2>/dev/null \
        && echo "[OK] disabled ${svc}" \
        || echo "[SKIP] ${svc} not present"
done

# ── 5. Network sysctl tuning ─────────────────────────────────
cat > /etc/sysctl.d/91-ohmlab-network.conf << 'EOF'
# ohmlab OS: network gaming optimisation
net.core.rmem_max                  = 134217728
net.core.wmem_max                  = 134217728
net.core.rmem_default              = 262144
net.core.wmem_default              = 262144
net.ipv4.tcp_rmem                  = 4096 262144 134217728
net.ipv4.tcp_wmem                  = 4096 262144 134217728
net.ipv4.udp_rmem_min              = 8192
net.ipv4.udp_wmem_min              = 8192
net.core.default_qdisc             = cake
net.ipv4.tcp_congestion_control    = bbr
net.ipv4.tcp_fastopen              = 3
net.ipv4.tcp_tw_reuse              = 1
net.ipv4.tcp_fin_timeout           = 15
net.ipv4.tcp_max_tw_buckets        = 1440000
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save       = 1
net.core.netdev_max_backlog        = 50000
net.core.netdev_budget             = 600
net.core.netdev_budget_usecs       = 8000
net.core.somaxconn                 = 65535
net.ipv4.neigh.default.gc_thresh1  = 4096
net.ipv4.neigh.default.gc_thresh2  = 8192
net.ipv4.neigh.default.gc_thresh3  = 16384
net.ipv4.ip_local_port_range       = 1024 65535
net.core.busy_read                 = 50
net.core.busy_poll                 = 50
fs.file-max                        = 2097152
EOF
sysctl --system >/dev/null
echo "[OK] network sysctls applied"

# ── 6. I/O schedulers (ADIOS for SSD/NVMe, BFQ for HDD) ──────
mkdir -p /etc/udev/rules.d
cat > /etc/udev/rules.d/60-ioschedulers.rules << 'EOF'
# HDD: BFQ remains the right choice
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", \
    ATTR{queue/scheduler}="bfq"

# SSD: use ADIOS instead of mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="adios"

# NVMe: use ADIOS instead of kyber
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
    ATTR{queue/scheduler}="adios"
EOF
udevadm control --reload-rules
udevadm trigger
echo "[OK] udev I/O scheduler rules applied"

# ── 7. tmpfs on /tmp ──────────────────────────────────────────
if ! grep -qs '^[[:space:]]*tmpfs[[:space:]].*/tmp' /etc/fstab; then
    echo 'tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0' >> /etc/fstab
    echo "[OK] tmpfs on /tmp added to fstab (effective on next mount/boot)"
else
    echo "[SKIP] /tmp already in fstab"
fi

# ── 8. NVIDIA persistence daemon ──────────────────────────────
if systemctl list-unit-files nvidia-persistenced.service &>/dev/null; then
    systemctl enable --now nvidia-persistenced
    echo "[OK] nvidia-persistenced enabled"
else
    echo "[SKIP] nvidia-persistenced not present (non-NVIDIA?)"
fi

# ── 9. NVIDIA environment variables ──────────────────────────
ENV_FILE=/etc/environment
ENV_VARS=(
    "__GL_THREADED_OPTIMIZATION=1"
    "__GL_SHADER_DISK_CACHE=1"
    "__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1"
    "__GL_VRR_ALLOWED=0"
    "__GL_SYNC_TO_VBLANK=0"
    "__GL_MaxFramesAllowed=1"
    "VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json"
    "WINEDEBUG=-all"
)
for var in "${ENV_VARS[@]}"; do
    key="${var%%=*}"
    if grep -qs "^${key}=" "${ENV_FILE}"; then
        echo "[SKIP] ${key} already set in ${ENV_FILE}"
    else
        echo "${var}" >> "${ENV_FILE}"
        echo "[OK] ${key} added to ${ENV_FILE}"
    fi
done

# ── 10. NVIDIA Full RGB over HDMI ─────────────────────────────
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/20-nvidia-full-rgb.conf << 'EOF'
Section "Device"
    Identifier "NVIDIA"
    Driver "nvidia"
    Option "ColorSpace" "RGB"
    Option "ColorRange" "Full"
EndSection
EOF
echo "[OK] xorg full-range RGB config written"

# ── 11. PipeWire low latency ──────────────────────────────────
mkdir -p /etc/pipewire/pipewire.conf.d
cat > /etc/pipewire/pipewire.conf.d/10-low-latency.conf << 'EOF'
context.properties = {
    default.clock.rate            = 48000
    default.clock.quantum         = 128
    default.clock.min-quantum     = 128
    default.clock.max-quantum     = 512
}
EOF
echo "[OK] PipeWire low-latency config written (restart pipewire as your user:"
echo "     systemctl --user restart pipewire pipewire-pulse)"

echo
echo "==> Done. Reboot to apply everything (fstab, udev, session env)."
echo "    Verify schedulers with: cat /sys/block/*/queue/scheduler"

```

> **Important:** Backup your configs before editing. Test changes incrementally and monitor temps/fps with `mangohud`. Results vary by hardware—adjust `r.Nanite.Streaming.StreamingPoolSize` and texture quality based on available VRAM.

---

## 🔧 System Tweaks

### NVIDIA Driver Settings

```bash
sudo nvidia-settings -a InitialPositionX=0 -a InitialPositionY=0
```

**NVIDIA Control Panel Settings:**

| Setting | Value |
|---------|-------|
| Low Latency Mode | Ultra |
| Power Management | Prefer Maximum Performance |
| Threaded Optimization | On |
| Vertical Sync | Off |
| Shader Cache Size | Unlimited |

### CPU Scheduler (Optional)

```bash
# Install cpufrequtils
sudo apt install cpufrequtils
sudo systemctl stop cpufrequtils

# Set performance governor
echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### NVMe Improvements

```bash
if $(find /sys/block/nvme[0-9]* | grep -q nvme); then
    echo -e "options nvme_core default_ps_max_latency_us=0" | sudo tee /etc/modprobe.d/nvme.conf
fi
```

### PCI Latency Improvement

```bash
sudo setpci -v -s '*:*' latency_timer=10 >/dev/null 2>&1
sudo setpci -v -s '0:0' latency_timer=0 >/dev/null 2>&1
```

### Font Optimization

```bash
# Compress fonts
woff2_compress /usr/share/fonts/opentype/*/*ttf
woff2_compress /usr/share/fonts/truetype/*/*ttf

# Optimize font cache
fc-cache -rfv

# Optimize icon cache
gtk-update-icon-cache
```

---

## 🖥️ Debian/Nobara Specific Tweaks

### Debloating Without Breaking dnf

Nobara is already fairly lean, so resist the urge to rip out packages. The real wins on KDE are background indexers, not package removal.

```bash
# Kill Baloo file indexing — biggest single win on KDE
balooctl6 disable && balooctl6 purge
kwriteconfig6 --file baloofilerc --group "Basic Settings" --key "Indexing-Enabled" false

# Mask Akonadi if you don't use Kontact/KMail/PIM
systemctl --user mask akonadi.service akonadiserver.service

# Services you probably don't need on a gaming desktop
sudo systemctl disable --now bluetooth.service cups.service avahi-daemon.service ModemManager.service

# Trim journal growth
sudo mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nSystemMaxUse=200M\n' | sudo tee /etc/systemd/journald.conf.d/size.conf
sudo systemctl restart systemd-journald

# Flatpak leftovers
flatpak uninstall --unused
```

> ⚠️ **Warning:** Do not remove Python, Perl, or glib2-adjacent packages — dnf depends on them and you'll end up with a broken transaction database. Also leave `systemd-oomd` and `zram` alone unless you're actually memory-starved.

### NVIDIA Stack Verification

```bash
cat /proc/cmdline      # Want nvidia-drm.modeset=1
nvidia-smi             # Confirm driver version and render device
```

For driver 550+:

```bash
nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1"
```

```bash
# Persist settings
nvidia-settings --load-config-only
```

Or bake into modprobe config:

```bash
NVreg_RegistryDwords="OverrideMaxPerf=0x1"
```

### Shader Cache Configuration

```bash
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SIZE=10737418240
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
```

> Put `~/.nv` on your fastest SSD. UE5's traversal stutter is largely shader-compile stutter, and a warm cache is the only real mitigation on NVIDIA.

### Plasma / KWin via kwriteconfig6

```bash
# Allow tearing in fullscreen
kwriteconfig6 --file kwinrc --group Compositing --key AllowTearing true

# Unlock compositor frame limiter
kwriteconfig6 --file kwinrc --group Compositing --key MaxFPS 0

# Lowest-latency scheduling policy
kwriteconfig6 --file kwinrc --group Compositing --key LatencyPolicy Low

# Strip compositor effects
for fx in blur contrast kwin4_effect_fadedesktop magiclamp slide slidingpopups; do
  kwriteconfig6 --file kwinrc --group Plugins --key ${fx}Enabled false
done

# Instant UI transitions
kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0

# Apply
qdbus6 org.kde.KWin /KWin reconfigure
```

> ⚠️ **Note:** If chasing absolute minimum latency and don't care about screen tearing, use the nuclear option: `kwriteconfig6 --file kwinrc --group Compositing --key Enabled false` + `qdbus6 org.kde.KWin /Compositor suspend`. This breaks some window behavior.

### Display Scaling

> Set display scaling to exactly 100%. Fractional scaling on NVIDIA is a measurable frame-time cost.

### vkd3d-proton Environment for DX12 / UE5

```bash
PROTON_ENABLE_NVAPI=1
DXVK_ENABLE_NVAPI=1
VKD3D_FEATURE_LEVEL=12_2
VKD3D_CONFIG=""
```

Experimental knobs for UE5 titles (test separately):

```bash
VKD3D_CONFIG=no_upload_hvv     # Avoids host-visible upload heap path
VKD3D_CONFIG=force_static_cbv
```

For upscaling:

```bash
WINE_FULLSCREEN_FSR=1 WINE_FULLSCREEN_FSR_STRENGTH=2
PROTON_DLSS_UPGRADE=1
```

### Gamescope Integration

```bash
gamemoderun gamescope -f --adaptive-sync --force-grab-cursor -- %command%
```

Add `-r <refresh>` to cap. For G-Sync/VRR, cap a few frames below refresh (e.g., 237 on 240Hz panel).

### Measure, Don't Guess

```bash
# Install mangohud and goverlay
# Watch frametime graphs rather than averages

DXVK_HUD=full
VKD3D_DEBUG=warn
```


```sudo setcap cap_sys_nice+ep "$(which gamescope)"```
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
```[Service] MemoryHigh=48M MemoryMax=96M DROP```

NetworkManager-wait-online (saves 5.1s)
```sudo systemctl disable NetworkManager-wait-online.service echo "[OK] NetworkManager-wait-online disabled"```

Serial ports ttyS0-3 (saves 4.8s)
```sudo systemctl mask serial-getty@ttyS0.service sudo systemctl mask serial-getty@ttyS1.service sudo systemctl mask serial-getty@ttyS2.service sudo systemctl mask serial-getty@ttyS3.service echo "[OK] Serial ports masked"```

Disable unused services
```sudo systemctl disable systemd-hwdb-update.service 2>/dev/null sudo systemctl disable avahi-daemon.service 2>/dev/null sudo systemctl disable cups.service 2>/dev/null sudo systemctl disable cups-browsed.service 2>/dev/null sudo systemctl disable geoclue.service 2>/dev/null sudo systemctl disable power-profiles-daemon.service 2>/dev/null cat << 'NETSYSCTL' > /etc/sysctl.d/91-ohmlab-network.conf```


cat /sys/block/sdX/queue/scheduler
# Should show [adios] for SSDs, [bfq] for HDDs

NVMe Power Management (Optional)
Some NVMe drives aggressively enter power‑saving states, causing micro‑stutters when they wake up.

# Disable APST (Autonomous Power State Transition)
```echo on | sudo tee /sys/class/nvme/nvme0/device/power/control```
# To make it permanent, add to a systemd service or rc.local

8. GPU: NVIDIA
Module parameters (CachyOS provides these)
You don't need to change these, they're already set by CachyOS at /usr/lib/modprobe.d/nvidia.conf:
```
options nvidia NVreg_UsePageAttributeTable=1
    NVreg_InitializeSystemMemoryAllocations=0
    NVreg_DynamicPowerManagement=0x02
```
Enable persistence daemon
Keeps the NVIDIA kernel driver loaded even with no applications using the GPU. Eliminates the ~1–3 second driver initialization delay when launching the first GPU application after boot.
```
sudo systemctl enable --now nvidia-persistenced
```
