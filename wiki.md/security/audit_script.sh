#!/usr/bin/env bash
#
# system-audit.sh — Fedora 44 / KDE Plasma 6 diagnostic audit
# Enhanced for hybrid GPU gaming laptops
#
# Produces a single, self-documenting log file intended to be read by a
# human or an LLM to diagnose stability, performance, and security issues.
#
# NOTE on set -e: intentionally NOT using -e. This script collects as much
# diagnostic info as possible even when individual commands fail (missing
# tool, no permission, transient error). Every command is guarded by run(),
# run_if_exists(), or run_sudo(), which all capture and report exit status
# without aborting the whole run.

set -uo pipefail
export LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

trap 'echo; echo "** Interrupted — partial audit file may still be usable."; exit 130' INT

AUDIT_FILE="system-audit-$(hostname)-$(date +%F_%H-%M-%S).txt"
POWERTOP_REPORT="powertop-report-$(date +%F_%H-%M-%S).html"

# ---------------------------------------------------------------------------
# Pre-flight: root access
# ---------------------------------------------------------------------------
# Rather than silently skipping every privileged command when passwordless
# sudo isn't available, ask once up front and keep the credential alive for
# the whole (long) run via a background keepalive process. This means you
# get exactly one password prompt, ever, and nothing later blocks on it.

SUDO=""
if [[ $EUID -eq 0 ]]; then
  SUDO=""
  echo "Running as root — all checks will run with full privileges."
else
  echo "This audit includes checks that require root (SMART data, suspend/resume"
  echo "service status, some journal entries, SELinux booleans, etc)."
  read -rp "Authenticate with sudo now so those checks aren't skipped? (Y/n): " want_sudo
  if [[ ! "$want_sudo" =~ ^[Nn]$ ]]; then
    if sudo -v; then
      SUDO="sudo"
      # Keep sudo timestamp alive for the duration of the script.
      ( while true; do sudo -n true 2>/dev/null; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
      SUDO_KEEPALIVE_PID=$!
      trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
    else
      echo "sudo authentication failed or was cancelled — continuing without root."
    fi
  else
    echo "Continuing without root — privileged checks will be flagged as skipped."
  fi
fi
echo

# ---------------------------------------------------------------------------
# Pre-flight: optional diagnostic tools
# ---------------------------------------------------------------------------
# Best-effort binary -> Fedora package name mapping. Some names may need
# adjusting if a package has been renamed/split in your Fedora release.

declare -A TOOL_PKG=(
  [mokutil]=mokutil
  [dkms]=dkms
  [akmods]=akmods
  [sensors]=lm_sensors
  [inxi]=inxi
  [glxinfo]=glx-utils
  [vulkaninfo]=vulkan-tools
  [powertop]=powertop
  [switcherooctl]=switcheroo-control
  [coredumpctl]=systemd-udev
  [fwupdmgr]=fwupd
  [smartctl]=smartmontools
  [zramctl]=util-linux
  [semanage]=policycoreutils-python-utils
  [balooctl6]=baloo6
  [gamemoded]=gamemode
  [sysbench]=sysbench
  [bc]=bc
)

missing_pkgs=()
missing_bins=()
for bin in "${!TOOL_PKG[@]}"; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    missing_bins+=("$bin")
    missing_pkgs+=("${TOOL_PKG[$bin]}")
  fi
done

if (( ${#missing_pkgs[@]} > 0 )); then
  echo "Optional diagnostic tools not installed: ${missing_bins[*]}"
  read -rp "Install the corresponding packages now via dnf? (y/N): " install_ans
  if [[ "$install_ans" =~ ^[Yy]$ ]]; then
    if [[ -n "$SUDO" ]]; then
      # Deduplicate package list (some tools share a package).
      readarray -t uniq_pkgs < <(printf '%s\n' "${missing_pkgs[@]}" | sort -u)
      $SUDO dnf install -y "${uniq_pkgs[@]}" || echo "Some packages failed to install — affected checks will be skipped/flagged."
    else
      echo "No sudo access available — cannot install packages. Affected checks will be skipped."
    fi
  else
    echo "Continuing without installing — affected checks will be marked [skipped]."
  fi
fi
echo

# ---------------------------------------------------------------------------
# Pre-flight: stray diagnostic processes from earlier manual sessions
# ---------------------------------------------------------------------------
# If you've been manually poking at GPU/power issues (e.g. `nvidia-smi dmon`
# left running in another terminal, or a previous powertop run that didn't
# exit cleanly), those processes add their own CPU/GPU wakeups and will
# skew this run's numbers — especially the powertop wakeup-source report.
# This script itself never starts anything in a looping/monitor mode, so
# anything caught here is left over from something run by hand.

stray="$( { pgrep -af -- '-dmon|nvidia-smi.*(-l |-lms|--loop)'; pgrep -af 'powertop'; } 2>/dev/null | sed '/^$/d' )"
if [ -n "$stray" ]; then
  echo "Found lingering monitoring processes from an earlier manual session (not started by this script):"
  echo "$stray"
  read -rp "Kill these before starting? (y/N): " kill_ans
  if [[ "$kill_ans" =~ ^[Yy]$ ]]; then
    echo "$stray" | awk '{print $1}' | xargs -r kill 2>/dev/null
    echo "Sent SIGTERM to the above PIDs."
  fi
  echo
fi

# ---------------------------------------------------------------------------
# Pre-flight: optional performance benchmarks
# ---------------------------------------------------------------------------
# The Performance Baselines section actively loads the CPU, memory, and
# disk (sysbench, bc, dd) to get throughput numbers. That's useful data in
# its own right, but it works against the rest of this audit, which is
# largely trying to characterize idle/light-load behavior (fan noise,
# throttling, wakeups). Off by default; opt in if you specifically want
# benchmark numbers alongside everything else.

read -rp "Also run active CPU/memory/disk benchmarks (adds load + time, skip if investigating idle fan/thermal behavior)? (y/N): " bench_ans
if [[ "$bench_ans" =~ ^[Yy]$ ]]; then
  RUN_BENCHMARKS="y"
else
  RUN_BENCHMARKS="n"
fi
echo

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

section() {
  {
    echo -e "\n=================================================="
    echo "===== $1 ====="
    echo "=================================================="
  } | tee -a /dev/null
}

# Prints the literal command before executing it, and an explicit
# STATUS: OK / STATUS: FAILED line after, so the resulting file is both
# self-documenting and grep-able for failures without needing the script
# alongside it.
run() {
  printf "\n>>> %s\n" "$1" | tee /dev/tty >/dev/null
  echo "\$ $1"
  # pipefail is turned off for the duration of this eval only: with it on,
  # any "cmd | head -n N" pattern reports a false failure (exit 141/SIGPIPE)
  # the moment head closes the pipe early, even though the output is
  # complete and correct. Genuine failures of the last command in a pipeline
  # still get caught below.
  set +o pipefail
  eval "$1"
  local ec=$?
  set -o pipefail
  if [ $ec -eq 0 ]; then
    echo "[STATUS: OK]"
  else
    echo "[STATUS: FAILED exit=$ec]"
  fi
  echo
}

run_if_exists() {
  local bin
  bin=$(echo "$1" | awk '{print $1}')
  if command -v "$bin" >/dev/null 2>&1; then
    run "$1"
  else
    echo "\$ $1"
    echo "[SKIPPED: '$bin' not installed]"
    echo
  fi
}

run_sudo() {
  # Runs a privileged command if sudo access was granted at startup;
  # otherwise reports it as explicitly skipped (never silently omitted).
  local cmd="$1"
  local bin
  bin=$(echo "$cmd" | awk '{print $1}')
  echo "\$ sudo $cmd"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "[SKIPPED: '$bin' not installed]"
    echo
    return
  fi
  if [ -n "$SUDO" ]; then
    set +o pipefail
    # Use bash -c to handle pipes/redirections properly
    $SUDO bash -c "$cmd"
    local ec=$?
    set -o pipefail
    if [ $ec -eq 0 ]; then
      echo "[STATUS: OK]"
    else
      echo "[STATUS: FAILED exit=$ec]"
    fi
  else
    echo "[SKIPPED: no root access granted for this run]"
  fi
  echo
}

# LLM-friendly markers
section_start() {
    echo ""
    echo "##SECTION_START: $1##"
    echo "=================================================="
    echo "===== $1 ====="
    echo "=================================================="
}

section_end() {
    echo "##SECTION_END: $1##"
    echo ""
}

add_key_value() {
    echo "KEYVALUE: $1=$2"
}

# ---------------------------------------------------------------------------
# Header: machine-readable system fingerprint
# ---------------------------------------------------------------------------
# Written first so a human or LLM reading the file has the machine's
# identity anchored before wading into hundreds of lines of raw output.

{
echo "# SYSTEM_AUDIT_START"
echo "# Generated: $(date)"
echo "# Hostname: $(hostname)"
echo "# Kernel: $(uname -r)"
echo "# OS: $(source /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
echo "# SYSTEM_AUDIT_CONFIG"
echo "# - Fedora 44 / KDE Plasma 6 focus"
echo "# - Hybrid NVIDIA GPU gaming laptop"
echo "# - Enhanced stability, performance, security audit"
echo "# SYSTEM_AUDIT_CONFIG_END"
echo ""
echo "=================================================="
echo "SYSTEM AUDIT SUMMARY"
echo "=================================================="
echo "Generated:        $(date)"
echo "Hostname:         $(hostname)"
echo "Product:          $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown) $(cat /sys/class/dmi/id/product_version 2>/dev/null || true)"
echo "BIOS/UEFI ver:    $(cat /sys/class/dmi/id/bios_version 2>/dev/null || echo unknown)"
echo "OS:               $(source /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
echo "Kernel:           $(uname -r)"
echo "CPU:              $(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo | sed 's/^ //')"
echo "CPU cores/threads: $(nproc)"
echo "RAM total:        $(awk '/MemTotal/{printf "%.1f GiB\n", $2/1024/1024}' /proc/meminfo)"
echo "GPU(s):           $(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | cut -d: -f3- | sed 's/^ *//' | paste -sd '; ')"
echo "Desktop:          $(echo "${XDG_SESSION_DESKTOP:-unknown}") / session type: $(echo "${XDG_SESSION_TYPE:-unknown}")"
echo "Plasma version:   $(plasmashell --version 2>/dev/null || echo 'plasmashell not found')"
echo "Ran as root:      $([[ $EUID -eq 0 ]] && echo yes || echo no)"
echo "Sudo obtained:    $([[ -n "$SUDO" ]] && echo yes || echo no)"
echo "=================================================="
} > "$AUDIT_FILE"

echo "Writing audit to: $AUDIT_FILE"
echo "This will take a while — extensive checks are intentional."
echo

# ---------------------------------------------------------------------------
# Main audit body
# ---------------------------------------------------------------------------
{

section_start "System Basics"
run "date"
run "uptime"
run "cat /proc/loadavg"
run "timedatectl status"
section_end "System Basics"

section_start "Fedora Release & OS Info"
run "cat /etc/fedora-release"
run "cat /etc/os-release"
add_key_value "FEDORA_VERSION" "$(rpm -E %fedora)"
section_end "Fedora Release & OS Info"

section_start "Kernel & Boot Configuration"
run "uname -a"
run "cat /proc/cmdline"
run "cat /proc/version"
run "cat /proc/sys/kernel/tainted"
run_sudo "dmesg | tail -n 200"

# Kernel parameters critical for NVIDIA
run "cat /proc/cmdline | grep -o 'nvidia-drm.modeset=[01]' || echo 'nvidia-drm.modeset not set in cmdline'"
run "cat /proc/cmdline | grep -o 'nvidia.NVreg_EnableGpuFirmware=[01]' || echo 'nvidia.NVreg_EnableGpuFirmware not set'"
run "cat /proc/cmdline | grep -o 'nvidia.NVreg_PreserveVideoMemoryAllocations=[01]' || echo 'nvidia.NVreg_PreserveVideoMemoryAllocations not set'"
add_key_value "KERNEL_CMDLINE" "$(cat /proc/cmdline 2>/dev/null)"
section_end "Kernel & Boot Configuration"

section_start "Fedora 44 Specific - DNF5 Migration"
run "dnf --version | head -n 3"
run "rpm -q dnf5 dnf5-plugins 2>/dev/null || echo 'DNF5 packages not installed'"
run "systemctl status packagekit --no-pager 2>/dev/null | head -n 10"
run "rpm -qa | grep -E 'dnf|packagekit' | sort"
add_key_value "DNF_BACKEND" "$(dnf --version 2>/dev/null | head -1)"
section_end "Fedora 44 Specific - DNF5 Migration"

section_start "Boot Performance"
run "systemd-analyze"
run "systemd-analyze critical-chain"
run "systemd-analyze blame | head -n 200"
add_key_value "BOOT_TIME" "$(systemd-analyze 2>/dev/null | awk '/Startup finished/ {print $0}')"
section_end "Boot Performance"

section_start "Needs-restarting (stale libs/services)"
run "dnf needs-restarting -r"
run "dnf needs-restarting -s"
section_end "Needs-restarting (stale libs/services)"

section_start "Secure Boot / MOK status"
run_if_exists "mokutil --sb-state"
run_if_exists "mokutil --list-enrolled"
run_sudo "dmesg | grep -Ei 'secure ?boot|lockdown'"
run_sudo "ls -la /etc/pki/akmods/certs/ 2>/dev/null || echo 'No akmods certs directory'"
section_end "Secure Boot / MOK status"

section_start "DKMS / akmod status (RPM Fusion)"
run_if_exists "dkms status"
run_sudo "akmods --status || akmods"
run "rpm -qa | grep -i '^kmod-nvidia' | sort"
run "find /lib/modules/\$(uname -r)/extra /lib/modules/\$(uname -r)/weak-updates -iname '*nvidia*' 2>/dev/null"
run "find /var/cache/akmods -iname '*nvidia*.log' -mtime -30 -exec sh -c 'echo \"-- {} --\"; tail -n 30 {}' \\; 2>/dev/null"
run "journalctl -u akmods -u akmods-shutdown --no-pager 2>/dev/null | tail -n 100"
section_end "DKMS / akmod status (RPM Fusion)"

section_start "CPU Information"
run "lscpu"
run "cat /proc/cpuinfo | head -n 80"
run "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | head -20"
add_key_value "CPU_GOVERNOR" "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown)"
section_end "CPU Information"

section_start "CPU Thermal Throttling Counters"
run "for f in /sys/devices/system/cpu/cpu*/thermal_throttle/core_throttle_count 2>/dev/null; do echo \"\$f: \$(cat \"\$f\" 2>/dev/null)\"; done"
run "for f in /sys/devices/system/cpu/cpu*/thermal_throttle/package_throttle_count 2>/dev/null; do echo \"\$f: \$(cat \"\$f\" 2>/dev/null)\"; done"
section_end "CPU Thermal Throttling Counters"

section_start "Intel RAPL Power Limits (PL1/PL2)"
run 'for d in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl:0:0 /sys/class/powercap/intel-rapl:0:1; do [ -d "$d" ] || continue; name=$(cat "$d/name" 2>/dev/null || echo unknown); pl1_uw=$(cat "$d/constraint_0_power_limit_uw" 2>/dev/null); pl2_uw=$(cat "$d/constraint_1_power_limit_uw" 2>/dev/null); pl1="n/a"; pl2="n/a"; [ -n "$pl1_uw" ] && pl1="$((pl1_uw/1000000))W"; [ -n "$pl2_uw" ] && pl2="$((pl2_uw/1000000))W"; echo "$d [$name]: PL1=$pl1 PL2=$pl2"; done'
run "cat /sys/devices/system/cpu/intel_pstate/max_perf_pct 2>/dev/null || true"
run "cat /sys/devices/system/cpu/intel_pstate/min_perf_pct 2>/dev/null || true"
run "cpupower frequency-info 2>/dev/null | head -50"
section_end "Intel RAPL Power Limits (PL1/PL2)"

section_start "Memory Information"
run "free -h"
run "cat /proc/meminfo | head -n 80"
run "vmstat 1 5"
run "swapon --show"
run_if_exists "zramctl"
run "cat /proc/sys/vm/swappiness"
run "cat /proc/sys/vm/vfs_cache_pressure"
add_key_value "SWAPPINESS" "$(cat /proc/sys/vm/swappiness 2>/dev/null)"
section_end "Memory Information"

section_start "System Pressure (PSI)"
run "cat /proc/pressure/cpu"
run "cat /proc/pressure/memory"
run "cat /proc/pressure/io"
section_end "System Pressure (PSI)"

section_start "Live Process Snapshot (CPU / Memory Hogs)"
run "ps aux --sort=-%cpu | head -n 25"
run "ps aux --sort=-%mem | head -n 25"
run_if_exists "systemd-cgtop -b -n 1"
section_end "Live Process Snapshot (CPU / Memory Hogs)"

section_start "Storage Overview"
run "df -hT"
run "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL"
run "findmnt"
run "df -h /boot"
section_end "Storage Overview"

section_start "Filesystem - Extended Health Checks"
run_sudo "dmesg | grep -E 'EXT4-fs error|XFS: error|BTRFS.*error' | tail -20 || echo 'No filesystem errors found'"
run "systemctl is-enabled fstrim.timer"
run "systemctl status fstrim.timer --no-pager"
run_sudo "fstrim -av 2>&1 | head -20"
section_end "Filesystem - Extended Health Checks"

section_start "Btrfs Health (if applicable)"
run "findmnt -no FSTYPE / 2>/dev/null"
run_if_exists "btrfs filesystem usage / 2>/dev/null || echo 'Not a btrfs filesystem'"
run_if_exists "btrfs scrub status / 2>/dev/null || echo 'Scrub not available'"
run_if_exists "btrfs device stats / 2>/dev/null || echo 'Device stats not available'"
run_if_exists "btrfs subvolume list / 2>/dev/null"
run_if_exists "btrfs balance status / 2>/dev/null || echo 'Balance not running'"
run "rpm -q btrfsmaintenance 2>/dev/null || echo 'btrfsmaintenance package not installed — no automatic scrub/balance/trim/defrag timers'"
run "systemctl list-timers 2>/dev/null | grep -i btrfs || echo 'No btrfsmaintenance timers active'"
section_end "Btrfs Health (if applicable)"

section_start "Encrypted Volumes"
run "lsblk -o NAME,FSTYPE | grep -i crypto_LUKS || echo 'No LUKS volumes detected'"
run 'for dev in $(lsblk -rno NAME,FSTYPE | awk "\$2==\"crypto_LUKS\"{print \$1}" 2>/dev/null); do echo "-- $dev --"; cryptsetup status "$dev" 2>&1; done'
section_end "Encrypted Volumes"

section_start "Disk SMART Health"
run 'for disk in /dev/nvme*n1 /dev/sd?; do [ -e "$disk" ] && echo "---- SMART: $disk ----"; done'
for disk in /dev/nvme*n1 /dev/sd?; do
  if [ -e "$disk" ]; then
    run_sudo "smartctl -a $disk 2>&1 | head -100"
    run_sudo "smartctl -l error $disk 2>&1 | head -20"
  fi
done
section_end "Disk SMART Health"

section_start "PCI / Hardware Topology"
run "lspci -nnk"
run "lsusb"
run "rfkill list"
section_end "PCI / Hardware Topology"

section_start "Kernel Modules"
run "lsmod | head -n 200"
run "lsmod | grep -E 'nvidia|nouveau|amdgpu|i915'"
section_end "Kernel Modules"

section_start "ntsync (Wine/Proton) Module"
run "lsmod | grep -i ntsync || echo 'ntsync module not loaded'"
run "ls -l /dev/ntsync 2>/dev/null || echo '/dev/ntsync not found'"
run "rpm -qa | grep ntsync || echo 'ntsync package not installed'"
section_end "ntsync (Wine/Proton) Module"

# ================================================================
# ENHANCED GPU / HYBRID GRAPHICS SECTION
# ================================================================

section_start "Graphics Environment"
run_if_exists "inxi -Gxx"
run "printenv | sort | grep -E 'GBM|GLX|EGL|NVIDIA|VK|WAYLAND|MESA|LIBVA|PRIME|__GL|__NV|PROTON|DXVK|VKD3D'"
section_end "Graphics Environment"

section_start "Display Session"
run "echo \"XDG_SESSION_TYPE=\${XDG_SESSION_TYPE:-unknown}\""
run "echo \"XDG_SESSION_DESKTOP=\${XDG_SESSION_DESKTOP:-unknown}\""
run "echo \"WAYLAND_DISPLAY=\${WAYLAND_DISPLAY:-none}\""
run "echo \"DISPLAY=\${DISPLAY:-none}\""
run "loginctl show-session \"\${XDG_SESSION_ID:-}\" -p Type -p Desktop 2>/dev/null || echo 'loginctl failed'"
run "echo \"QT_QPA_PLATFORM=\${QT_QPA_PLATFORM:-unset}\""
run "echo \"QT_QPA_PLATFORMTHEME=\${QT_QPA_PLATFORMTHEME:-unset}\""
run "echo \"MOZ_ENABLE_WAYLAND=\${MOZ_ENABLE_WAYLAND:-unset}\""
section_end "Display Session"

section_start "Wayland / X11 Diagnostics"
run "loginctl show-session \"\${XDG_SESSION_ID:-}\" -p Type -p Desktop 2>/dev/null"
run "echo \"QT_QPA_PLATFORM=\${QT_QPA_PLATFORM:-unset}\""
run "echo \"MOZ_ENABLE_WAYLAND=\${MOZ_ENABLE_WAYLAND:-unset}\""
run "echo \"GDK_BACKEND=\${GDK_BACKEND:-unset}\""
section_end "Wayland / X11 Diagnostics"

section_start "Display Manager (Plasma Login Manager / Legacy SDDM)"
run "systemctl status display-manager --no-pager 2>/dev/null | head -20"
run "readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || echo 'display-manager symlink not found'"
run "rpm -q sddm plasma-login-manager 2>/dev/null || echo 'SDDM/PLM packages not found'"
run "ls /etc/sddm.conf.d/ 2>/dev/null || echo 'No SDDM config directory'"
run "ls /etc/plasma-login-manager.conf* 2>/dev/null || echo 'No PLM config'"
section_end "Display Manager (Plasma Login Manager / Legacy SDDM)"

section_start "KDE / Plasma"
run_if_exists "plasmashell --version"
run "rpm -q plasma-desktop plasma-workspace 2>/dev/null"
run "kwin_wayland --version 2>/dev/null || kwin_x11 --version 2>/dev/null || echo 'kwin not found'"
run "plasmashell --version | grep -i plasma6 || echo 'Plasma6 not detected'"
add_key_value "PLASMA_VERSION" "$(plasmashell --version 2>/dev/null | awk '{print $2}')"
section_end "KDE / Plasma"

section_start "KDE Wayland - Explicit Sync Status"
run "echo 'KDE_WAYLAND_FORCE_SYNC: ${KDE_WAYLAND_FORCE_SYNC:-unset}'"
run "echo 'KWIN_DRM_NO_AMS: ${KWIN_DRM_NO_AMS:-unset}'"
run "echo 'KWIN_COMPOSE: ${KWIN_COMPOSE:-unset}'"
run "echo 'KWIN_DRM_USE_AMS: ${KWIN_DRM_USE_AMS:-unset}'"
run "kwin_wayland --version 2>&1 | grep -i sync || echo 'Explicit sync flag not found in kwin version'"
run "journalctl --user -b 2>/dev/null | grep -i kwin | grep -E 'sync|presentation|tearing' | tail -50"
section_end "KDE Wayland - Explicit Sync Status"

section_start "KDE - Compositor & Input Issues"
run "systemctl --user status kwin_wayland --no-pager 2>/dev/null | head -20"
run "systemctl --user status plasma-kwin_wayland --no-pager 2>/dev/null | head -20"
run "coredumpctl list 2>/dev/null | grep -i kwin | head -20"
run "journalctl --user -b 2>/dev/null | grep -E 'kwin_crashed|compositor.*crash' | tail -30"
run_if_exists "kreadconfig5 --group Compositing --key OpenGLIsUnsafe"
run "qdbus org.kde.KWin /KWin supportInformation 2>/dev/null | grep -i -E 'render|frame|sync|latency' | head -200"
section_end "KDE - Compositor & Input Issues"

section_start "KDE File Indexer (Baloo) - Common Silent Fan/CPU Cause"
run_if_exists "balooctl6 status"
run_if_exists "balooctl6 indexSize"
run "balooctl6 monitor 2>&1 | head -10 || echo 'baloo monitor failed'"
section_end "KDE File Indexer (Baloo) - Common Silent Fan/CPU Cause"

section_start "KDE Config Files / Legacy Leftovers"
run "ls ~/.config/plasma* ~/.config/kde* 2>/dev/null | head -20"
run "find ~/.config -name '*plasma4*' -o -name '*kde4*' 2>/dev/null | head -20 || echo 'No KDE4 configs found'"
run "find ~/.config -name '*plasma5*' -o -name '*kde5*' 2>/dev/null | head -20 || echo 'No Plasma5 configs found'"
run "ls -la /etc/X11/xorg.conf.d/ 2>/dev/null || echo 'No Xorg config directory'"
section_end "KDE Config Files / Legacy Leftovers"

# ================================================================
# NVIDIA DRIVER SECTION
# ================================================================

section_start "NVIDIA Driver Diagnostics"
run_if_exists "nvidia-smi"
run_if_exists "nvidia-smi -L"
run "nvidia-smi dmon -s u 1 5 2>/dev/null || echo 'dmon unavailable'"
run_if_exists "nvidia-smi --query-gpu=name,driver_version,pstate,temperature.gpu,power.draw,clocks.current.graphics --format=csv"
run_if_exists "nvidia-smi --query-gpu=pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max --format=csv"
run "cat /proc/driver/nvidia/version 2>/dev/null || echo 'NVIDIA version not available'"
add_key_value "NVIDIA_DRIVER" "$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)"
section_end "NVIDIA Driver Diagnostics"

section_start "NVIDIA Per-Process GPU Usage"
run_if_exists "nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv"
run_if_exists "nvidia-smi pmon -c 1"
section_end "NVIDIA Per-Process GPU Usage"

section_start "Dynamic Boost / power arbitration"
run "nvidia-smi -q | grep -i 'Dynamic Boost' -A5 || true"
run "cat /sys/bus/pci/devices/*/power/control 2>/dev/null | grep -E 'auto|on' || true"
run "journalctl -b | grep -i 'dynamic boost' | tail -50"
run_sudo "cat /proc/driver/nvidia/gpus/*/power_policy 2>/dev/null || true"
section_end  "Dynamic Boost / power arbitration"

section_start "NVIDIA Persistent & Power Services"
run "systemctl is-active nvidia-persistenced 2>/dev/null || echo 'nvidia-persistenced not active'"
run "systemctl is-active nvidia-powerd 2>/dev/null || echo 'nvidia-powerd not active'"
run "systemctl status nvidia-powerd --no-pager 2>/dev/null | head -20"
run "journalctl -b -u nvidia-powerd --no-pager 2>/dev/null | tail -50"
run "echo \"nvidia-powerd ERROR lines this boot: \$(journalctl -b -u nvidia-powerd --no-pager 2>/dev/null | grep -c ERROR)\""
run_sudo "cat /proc/driver/nvidia/gpus/*/power 2>/dev/null | head -20"
section_end "NVIDIA Persistent & Power Services"

section_start "NVIDIA Package Consistency (RPM Fusion)"
run "rpm -qa | grep -Ei '^(akmod-nvidia|kmod-nvidia|xorg-x11-drv-nvidia|nvidia-settings|nvidia-persistenced|nvidia-gpu-firmware)' | sort"
run "find / -maxdepth 4 -iname '*NVIDIA-Linux*' -o -iname '*.run' 2>/dev/null | grep -i nvidia | head -10"
run "rpm -qa | grep -Ei 'negativo17|nvidia' | grep -v -E '^(akmod-nvidia|kmod-nvidia|xorg-x11-drv-nvidia|nvidia-settings|nvidia-persistenced|nvidia-gpu-firmware)' | head -20"
section_end "NVIDIA Package Consistency (RPM Fusion)"

# ================================================================
# HYBRID GPU SECTION
# ================================================================

section_start "Hybrid GPU - Prime Render Offload Configuration"
run_if_exists "switcherooctl list"
run "cat /etc/environment 2>/dev/null | grep -E 'prime|nvidia|offload' || echo 'No Prime env vars in /etc/environment'"
run "cat ~/.config/environment.d/*.conf 2>/dev/null | grep -E 'prime|nvidia|offload' || echo 'No Prime env vars in ~/.config/environment.d/'"
run_if_exists "xrandr --listproviders"
run "glxinfo 2>/dev/null | grep -E 'OpenGL renderer|OpenGL vendor' | head -5"
run "__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo -B 2>/dev/null | grep -E 'OpenGL renderer|OpenGL vendor' | head -5 || echo 'Prime offload test failed'"
add_key_value "PRIME_PROVIDER" "$(switcherooctl list 2>/dev/null | grep -E 'provider|GPU' | head -1)"
section_end "Hybrid GPU - Prime Render Offload Configuration"

section_start "Hybrid GPU - NVIDIA Modeset & DRM"
run_sudo "cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo 'nvidia_drm not loaded'"
run_sudo "cat /sys/module/nvidia/parameters/NVreg_EnableGpuFirmware 2>/dev/null || echo 'NVreg_EnableGpuFirmware not available'"
run_sudo "cat /sys/module/nvidia/parameters/NVreg_PreserveVideoMemoryAllocations 2>/dev/null || echo 'NVreg_PreserveVideoMemoryAllocations not available'"
run "ls -la /dev/nvidia* 2>/dev/null"
run "cat /proc/driver/nvidia/gpus/*/bus 2>/dev/null"
section_end "Hybrid GPU - NVIDIA Modeset & DRM"

section_start "Hybrid GPU - Power Management Conflicts"
run "cat /sys/bus/pci/devices/*/power/control 2>/dev/null | grep -v 'on' | head -5 || echo 'All PCI devices in auto power state or no devices found'"
run "systemctl status switcheroo-control.service --no-pager 2>/dev/null | head -15"
run "journalctl -b 2>/dev/null | grep -E 'nvidia.*modeset|nvidia.*fb|nvidia.*drm|switcheroo' | tail -50"
run "nvidia-smi --query-gpu=power.limit,power.draw,utilization.gpu,memory.used --format=csv 2>/dev/null"
run "cat /sys/bus/pci/devices/*/power/runtime_status 2>/dev/null | sort | uniq -c"
run "cat /sys/bus/pci/devices/*/power/runtime_usage 2>/dev/null || true"
section_end "Hybrid GPU - Power Management Conflicts"

section_start "Hybrid GPU - Suspend/Resume Diagnostics"
run "cat /sys/power/mem_sleep"
run "systemctl status systemd-suspend.service --no-pager 2>/dev/null | head -20"
run "rpm -q xorg-x11-drv-nvidia-power 2>/dev/null || echo 'nvidia-power package not installed'"
run 'for svc in nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service; do systemctl is-enabled "$svc" 2>/dev/null && systemctl status "$svc" --no-pager 2>/dev/null | head -5; done'
run "cat /proc/driver/nvidia/suspend 2>/dev/null || echo 'NVIDIA suspend info not available'"
run "journalctl -b 2>/dev/null | grep -Ei 'suspend|resum|PM: hibernation|freeze|nvidia.*resume' | tail -100"
section_end "Hybrid GPU - Suspend/Resume Diagnostics"

# ================================================================
# GAMING SECTION
# ================================================================

section_start "Gaming Performance - Latency & Tuning"
run "sysctl kernel.sched_rt_runtime_us"
run "cat /proc/sys/kernel/threads-max"
run "ulimit -a | head -20"
run_if_exists "gamemoded -s"
run "systemctl --user is-active gamemoded 2>/dev/null || echo 'gamemoded not running'"
run "gamemoderun true 2>&1 || echo 'gamemode not functional'"
add_key_value "GAMEMODE_STATUS" "$(systemctl --user is-active gamemoded 2>/dev/null || echo inactive)"
section_end "Gaming Performance - Latency & Tuning"

section_start "Gaming Performance - Wine/Proton/DXVK/VKD3D"
run_if_exists "wine --version"
run_if_exists "proton --version"
run "echo 'PROTON_USE_WINED3D: ${PROTON_USE_WINED3D:-unset}'"
run "echo 'PROTON_HIDE_NVIDIA_GPU: ${PROTON_HIDE_NVIDIA_GPU:-unset}'"
run "echo 'DXVK_HUD: ${DXVK_HUD:-unset}'"
run "echo 'VKD3D_CONFIG: ${VKD3D_CONFIG:-unset}'"
run "rpm -qa | grep -E 'wine|proton|lutris|heroic|steam' | sort"
section_end "Gaming Performance - Wine/Proton/DXVK/VKD3D"

section_start "Gaming Performance - Vsync/Tearing"
run "cat /sys/kernel/debug/dri/*/vblank* 2>/dev/null | head -20 || echo 'vblank stats not available'"
run "echo 'vblank_mode: ${vblank_mode:-unset}'"
run "echo '__GL_SYNC_DISPLAY_DEVICE: ${__GL_SYNC_DISPLAY_DEVICE:-unset}'"
run "echo '__GL_VRR_ALLOWED: ${__GL_VRR_ALLOWED:-unset}'"
section_end "Gaming Performance - Vsync/Tearing"

section_start "Gaming Stack - Flatpak vs RPM"
run_if_exists "rpm -q steam"
run "flatpak list 2>/dev/null | grep -i steam"
run 'command -v flatpak >/dev/null 2>&1 && flatpak list --app --columns=application 2>/dev/null | tail -n +1 | while read -r app; do short=$(echo "$app" | awk -F. "{print \$NF}"); rpm -qa 2>/dev/null | grep -qi "^${short}-" && echo "Possible duplicate: Flatpak $app alongside an RPM package named $short"; done'
section_end "Gaming Stack - Flatpak vs RPM"

# ================================================================
# THERMAL & POWER SECTION
# ================================================================

section_start "Thermal Management - Temperature & Throttling"
run_if_exists "sensors"
run "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null"
run "cat /sys/class/thermal/thermal_zone*/type 2>/dev/null"
run_sudo "journalctl -b 2>/dev/null | grep -E 'throttle|thermal|temperature|overheat' | tail -50"
section_end "Thermal Management - Temperature & Throttling"

section_start "Thermal Management - Fan Control"
run "ls -la /sys/class/hwmon/*/pwm* 2>/dev/null | head -10 || echo 'No pwm fan controls found'"
run "cat /sys/class/hwmon/*/name 2>/dev/null | sort -u"
run "systemctl is-active nvidia-fancontrol 2>/dev/null || echo 'nvidia-fancontrol not active'"
run "nvidia-settings -q fans 2>/dev/null | head -20 || echo 'nvidia-settings not available'"
run "ls -la /etc/nvidia-fancontrol.conf 2>/dev/null || echo 'No system nvidia fan config'"
run "ls -la ~/.config/nvidia-fancontrol.conf 2>/dev/null || echo 'No user nvidia fan config'"
section_end "Thermal Management - Fan Control"

section_start "Thermald & Power Management Services"
run "systemctl is-enabled thermald 2>/dev/null || echo 'thermald not enabled'"
run "systemctl status thermald --no-pager 2>/dev/null | head -15"
if systemctl is-enabled thermald 2>/dev/null | grep -q masked; then
    echo "WARNING: thermald is installed but masked."
fi
run "systemctl list-unit-files 2>/dev/null | grep -E 'tlp|tuned|thermald|power-profiles|auto-cpufreq'"
run 'if systemctl is-enabled tlp.service 2>/dev/null >/dev/null && systemctl is-enabled power-profiles-daemon.service 2>/dev/null >/dev/null; then echo "CONFLICT WARNING: both tlp.service and power-profiles-daemon.service appear enabled - these fight for control and should not both be active."; else echo "No conflict detected between tlp.service and power-profiles-daemon.service."; fi'
section_end "Thermald & Power Management Services"

section_start "Power Management - Profiles & Battery"
run_if_exists "powerprofilesctl get"
run_if_exists "powerprofilesctl list"
run_if_exists "tlp-stat -s"
run "systemctl status tlp tlp-sleep power-profiles-daemon --no-pager 2>/dev/null | head -30"
run 'upower -i "$(upower -e 2>/dev/null | grep BAT | head -n1)" 2>/dev/null || echo "No battery found"'
add_key_value "POWER_PROFILE" "$(powerprofilesctl get 2>/dev/null || echo unknown)"
section_end "Power Management - Profiles & Battery"

section_start "Fan / Wakeup Source Investigation (powertop)"
if command -v powertop >/dev/null 2>&1; then
  echo "\$ sudo powertop --html=$POWERTOP_REPORT --time=10"
  if [ -n "$SUDO" ]; then
    $SUDO powertop --html="$POWERTOP_REPORT" --time=10 >/dev/null 2>&1
    ec=$?
    if [ $ec -eq 0 ] && [ -f "$POWERTOP_REPORT" ]; then
      echo "[STATUS: OK] Report written to: $POWERTOP_REPORT"
    else
      echo "[STATUS: FAILED exit=$ec]"
    fi
  else
    echo "[SKIPPED: no root access granted for this run]"
  fi
else
  echo "\$ sudo powertop --html=$POWERTOP_REPORT --time=10"
  echo "[SKIPPED: 'powertop' not installed]"
fi
echo
run "systemctl --user status pipewire pipewire-pulse wireplumber --no-pager"
run "pactl list short sinks"
section_end "Fan / Wakeup Source Investigation (powertop)"

section_start "GPU Power Management"
run "cat /sys/class/drm/card*/device/power_dpm_state 2>/dev/null | head -5"
run "cat /sys/class/drm/card*/device/power/control 2>/dev/null | head -5"
run "cat /sys/bus/pci/devices/*/power/runtime_status 2>/dev/null | head -10"
section_end "GPU Power Management"

# ================================================================
# SERVICE CONFLICTS & LEGACY CONFIGS
# ================================================================

section_start "Service Conflicts - Legacy KDE/SDDM"
run "systemctl list-unit-files 2>/dev/null | grep -E 'sddm|plasma-login-manager|display-manager'"
run "ls -la /etc/sddm.conf.d/ 2>/dev/null || echo 'No SDDM config directories'"
run "ls -la /etc/plasma-login-manager.conf* 2>/dev/null || echo 'No PLM config'"
run "rpm -q sddm plasma-login-manager 2>/dev/null"
add_key_value "DISPLAY_MANAGER" "$(systemctl status display-manager 2>/dev/null | grep -E 'loaded|active' | head -1)"
section_end "Service Conflicts - Legacy KDE/SDDM"

section_start "Service Conflicts - Power Management"
run "powerprofilesctl list 2>/dev/null || echo 'power-profiles-daemon not functional'"
run "ls -la /etc/udev/rules.d/*nvidia* 2>/dev/null || echo 'No NVIDIA udev rules'"
run "ls -la /etc/udev/rules.d/*power* 2>/dev/null || echo 'No power udev rules'"
section_end "Service Conflicts - Power Management"

# ================================================================
# OPENGL & VULKAN
# ================================================================

section_start "OpenGL"
run_if_exists "glxinfo -B"
run "glxinfo -B 2>/dev/null | grep -E 'OpenGL renderer|OpenGL version|OpenGL vendor' | head -10"
add_key_value "GL_RENDERER" "$(glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer string/ {print $2}')"
section_end "OpenGL"

section_start "Vulkan"
run_if_exists "vulkaninfo --summary"
run "vulkaninfo --summary 2>/dev/null | grep -E 'GPU|driver|apiVersion|deviceName' | head -20"
section_end "Vulkan"

# ================================================================
# REPOSITORY & PACKAGE MANAGEMENT
# ================================================================

section_start "Repository & Package Management Issues"
run "dnf repolist --enabled"
run "dnf repolist --all | grep -E 'rpmfusion|negativo|epel|copr' | head -20"
run "dnf repoquery --duplicates | head -20"
run "dnf repoquery --extras | head -20"
run "dnf repoquery --unneeded | head -20"
run "dnf check | head -30"
run "dnf autoremove --assumeno | head -10"
add_key_value "TOTAL_PACKAGES" "$(rpm -qa | wc -l)"
section_end "Repository & Package Management Issues"

section_start "DNF History"
run "dnf history list | head -n 20"
run "dnf history | grep -E 'undo|rollback|revert' | head -10"
section_end "DNF History"

section_start "Orphaned / Old Kernels"
run "rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort -V"
run "echo \"Currently running: \$(uname -r)\""
run "df -h /boot"
run "rpm -qa kernel-core | wc -l"
section_end "Orphaned / Old Kernels"

section_start "RPM Integrity"
run_sudo "rpm -Va --nomtime --nosize --nomd5 | head -n 200"
section_end "RPM Integrity"

section_start "Kernel & Driver Versions"
run "uname -r"
run "rpm -qa | grep -E 'kernel|nvidia' | sort"
section_end "Kernel & Driver Versions"

# ================================================================
# NETWORK & FIREWALL
# ================================================================

section_start "Network"
run "ip a"
run "ip r"
run "resolvectl status 2>/dev/null | head -30"
run "ss -tulpen"
section_end "Network"

section_start "Firewall"
run "systemctl is-active firewalld"
run_sudo "firewall-cmd --list-all"
run "iptables -L -n -v 2>/dev/null | head -30 || echo 'iptables not available'"
section_end "Firewall"

# ================================================================
# FIRMWARE UPDATES
# ================================================================

section_start "Firmware Updates"
run_if_exists "fwupdmgr get-devices"
run_if_exists "fwupdmgr get-updates"
run "fwupdmgr get-devices 2>/dev/null | grep -E 'Device|Version|GUID' | head -30"
section_end "Firmware Updates"

# ================================================================
# SYSTEM SERVICES & ERRORS
# ================================================================

section_start "System Service Failures"
run "systemctl --failed"
run "systemctl list-units --state=failed"
section_end "System Service Failures"

section_start "Journal Warnings (System)"
run "journalctl -b -p warning..alert --no-pager | tail -n 300"
section_end "Journal Warnings (System)"

section_start "Journal Errors (System)"
run "journalctl -b -p err..alert -x --no-pager | tail -n 300"
section_end "Journal Errors (System)"

section_start "Journal Warnings/Errors (User Session)"
run "journalctl --user -b -p warning..alert --no-pager | tail -n 300"
section_end "Journal Warnings/Errors (User Session)"

section_start "GPU / Driver Kernel Errors"
run "journalctl -b | grep -Ei 'nvrm|nvidia|drm|gpu|i915|amdgpu|xe|vulkan|hang|reset|timeout|pcie|xid' | tail -100"
section_end "GPU / Driver Kernel Errors"

section_start "Hardware Errors"
run "journalctl -b | grep -Ei 'oom|out of memory|mce|edac|hardware error|segfault' | tail -50"
section_end "Hardware Errors"

section_start "Crash / Core Dumps"
run_if_exists "coredumpctl list --no-pager"
run "coredumpctl list --no-pager 2>/dev/null | head -30"
section_end "Crash / Core Dumps"

# ================================================================
# SECURITY SECTION
# ================================================================

section_start "SELinux"
run "getenforce"
run "sestatus"
run_sudo "semanage boolean -l --noheading | head -30"
run_sudo "ausearch -m AVC,USER_AVC -ts recent | head -n 50"
section_end "SELinux"

section_start "Security - AppArmor/Firejail"
run_if_exists "aa-status"
run_if_exists "firejail --list"
section_end "Security - AppArmor/Firejail"

section_start "Security - Failed Logins & SSH Attempts"
run "lastb 2>/dev/null | head -20"
run "journalctl -b 2>/dev/null | grep -i 'failed password' | tail -20"
section_end "Security - Failed Logins & SSH Attempts"

section_start "Security - Kernel Security Modules"
run "cat /sys/kernel/security/lsm 2>/dev/null || echo 'LSM info not available'"
run "cat /proc/sys/kernel/tainted 2>/dev/null"
run "sysctl kernel.randomize_va_space"
section_end "Security - Kernel Security Modules"

section_start "Security - UID 0 Users Other Than Root"
run "awk -F: '(\$3 == 0 && \$1 != \"root\"){print}' /etc/passwd"
section_end "Security - UID 0 Users Other Than Root"

section_start "Security - Password Aging Policy"
run 'while IFS=: read -r user _; do chage -l "$user" 2>/dev/null | sed "s/^/[$user] /"; done < /etc/passwd | head -n 200'
section_end "Security - Password Aging Policy"

section_start "Security - SUID / SGID Binaries"
run "find / -xdev \\( -perm -4000 -o -perm -2000 \\) -type f 2>/dev/null | head -50"
section_end "Security - SUID / SGID Binaries"

section_start "Security - World-Writable Files"
run "find / -xdev -type f -perm -0002 2>/dev/null | head -20"
section_end "Security - World-Writable Files"

section_start "Security - Dangerous Dotfiles"
run "find /home /root -maxdepth 2 \\( -name .rhosts -o -name .netrc -o -name .forward \\) 2>/dev/null"
section_end "Security - Dangerous Dotfiles"

section_start "Security - SSH Configuration"
run "cat /etc/ssh/sshd_config 2>/dev/null | grep -v '^#' | grep -v '^$'"
run "ls /etc/ssh/sshd_config.d/ 2>/dev/null"
section_end "Security - SSH Configuration"

section_start "Security - Core Sysctl Security Parameters"
run "sysctl kernel.randomize_va_space"
run "sysctl net.ipv4.conf.all.accept_redirects"
run "sysctl net.ipv4.conf.all.rp_filter"
run "sysctl net.ipv4.ip_forward"
section_end "Security - Core Sysctl Security Parameters"

# ================================================================
# PERFORMANCE BASELINES (opt-in — see prompt at script start)
# ================================================================

if [ "$RUN_BENCHMARKS" = "y" ]; then
  section_start "Performance - CPU Baseline Test"
  run "time (echo 'scale=10000; 4*a(1)' | bc -l 2>/dev/null) 2>&1 | head -5 || echo 'bc not installed'"
  run "sysbench cpu --threads=1 run 2>&1 | grep -E 'events per second|total time' | head -5 || echo 'sysbench not installed'"
  section_end "Performance - CPU Baseline Test"

  section_start "Performance - Memory Bandwidth Test"
  run "sysbench memory --memory-total-size=1G run 2>&1 | grep -E 'total time|MiB' | head -10 || echo 'sysbench not installed'"
  section_end "Performance - Memory Bandwidth Test"

  section_start "Performance - I/O Test"
  run "dd if=/dev/zero of=/tmp/test bs=1M count=100 conv=fdatasync 2>&1 | tail -1"
  run "rm -f /tmp/test 2>/dev/null"
  run "cat /sys/block/*/queue/scheduler 2>/dev/null | head -5"
  section_end "Performance - I/O Test"
else
  echo
  echo "(Performance Baselines skipped — declined at start, or these are load-generating"
  echo " tests that would distort the idle-state CPU/thermal/power data collected above.)"
  echo
fi

section_start "Performance - System Responsiveness"
run "top -b -n 1 | head -20"
run "systemctl --user status --no-pager 2>/dev/null | head -20"
section_end "Performance - System Responsiveness"

# ================================================================
# END OF AUDIT
# ================================================================

section_start "Audit Complete"
echo "Audit complete: $(date)"
echo "# SYSTEM_AUDIT_END"
section_end "Audit Complete"

} >> "$AUDIT_FILE" 2>&1

# ---------------------------------------------------------------------------
# Findings summary — auto-generated recap appended at the end so a human or
# LLM doesn't have to scan the entire file to see what actually looks wrong.
# ---------------------------------------------------------------------------
{
echo -e "\n=================================================="
echo "===== FINDINGS SUMMARY (auto-generated) ====="
echo "=================================================="

echo -e "\n--- Failed commands ---"
grep -n '\[STATUS: FAILED' "$AUDIT_FILE" | sed 's/^/  /' || echo "  none"

echo -e "\n--- Warnings / conflicts flagged inline ---"
grep -nE 'WARNING:|CONFLICT WARNING:' "$AUDIT_FILE" | sed 's/^/  /' || echo "  none"

echo -e "\n--- Skipped checks (missing tool or no root access) ---"
grep -n '\[SKIPPED:' "$AUDIT_FILE" | sed 's/^/  /' || echo "  none"

echo -e "\n--- Key system values ---"
grep '^KEYVALUE:' "$AUDIT_FILE" | sed 's/^/  /' || echo "  none"

echo -e "\n--- Critical GPU/Driver errors ---"
grep -n -E 'nvidia|drm|gpu|modeset|xid' "$AUDIT_FILE" | grep -i error | head -10 | sed 's/^/  /' || echo "  none"

echo -e "\n--- Service conflicts ---"
grep -n -E 'conflict|fight|both.*enabled' "$AUDIT_FILE" | sed 's/^/  /' || echo "  none"

echo
echo "Full details for each item above are in the corresponding section earlier in this file."
echo "For LLM analysis: Look for STATUS:FAILED, WARNING:, and CONFLICT WARNING: markers."
} >> "$AUDIT_FILE"

echo
echo "System audit saved to: $AUDIT_FILE"
[ -f "$POWERTOP_REPORT" ] && echo "Powertop wakeup-source report saved to: $POWERTOP_REPORT"
echo
echo "Audit complete! The output file is ready for analysis."
