#!/usr/bin/env bash
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
