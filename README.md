# resources

### /ɡrimˈwär/

# 📜 collections of resources,data,scripts and files

##

W.I.P -- UNFINISHED
- - THIS SCRIPT IS FAR FROM FINISHED AND IS USED AS A PLACEHOLDER AT THE MOMENT, DO NOT RUN BLINDLY - YOU WILL MOST LIKELY BREAK YOUR SETUP SINCE
I MAY ADD THINGS FROM OTHER LEFT OVER BASH SCRIPTS I PREVIOUSLY WROTE WHICH ARE HEAVILY OUTDATED NOW.
YOU'VE BEEN WARNED
W.I.P
- - THIS SCRIPT IS FAR FROM FINISHED AND IS USED AS A PLACEHOLDER AT THE MOMENT, DO NOT RUN BLINDLY - YOU WILL MOST LIKELY BREAK YOUR SETUP SINCE
I MAY ADD THINGS FROM OTHER LEFT OVER BASH SCRIPTS I PREVIOUSLY WROTE WHICH ARE HEAVILY OUTDATED NOW.
YOU'VE BEEN WARNED

```text
=================================================================

                                    N O T E S

 ┌│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│┐
 │▓▓                                                                        ▓▓│
 │▓▓                                                                        ▓▓│
 └│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│┘

                                    N O T E S
```



Here's a reformatted version optimized for GitHub README.md:

```markdown
# grimwär

`/ɡrimˈwär/`

> **⚠️ WORK IN PROGRESS — UNFINISHED**  
> This repository is a placeholder. DO NOT run scripts blindly — you will likely break your setup.  
> Scripts may contain outdated code from previous bash files. Proceed with caution.

## Collections of Resources, Data, Scripts and Files

---

## Table of Contents

- [Security Guide: Analyze the Threat Model](#security-guide-analyze-the-threat-model)
- [Linux Files Hierarchy](#linux-files-hierarchy)
- [Kernel Hardening](#kernel-hardening)
  - [Sysctl Settings](#sysctl-settings)
  - [Boot Parameters](#boot-parameters)
- [Network Configuration](#network-configuration)
- [Service Hardening](#service-hardening)
- [Gaming Optimizations](#gaming-optimizations)
  - [Steam Launch Options](#steam-launch-options)
  - [Engine.ini Config](#engineini-config)
  - [Game Settings](#game-settings)
- [System Tweaks](#system-tweaks)
- [Additional Resources](#additional-resources)

---

## 🔍 Security Guide: Analyze the Threat Model

When approaching a system to secure, it's crucial to ask yourself the following questions:

- Why do you want to secure your server and services?
- How much security do you desire?
- How many devices, apps, software, and databases need securing?
- How much convenience are you willing to compromise for security? *(People often prefer convenience over security.)*
- What threats do you want to protect against?
- What are the specifics of your situation?
- Is physical access to your server/network a possible attack vector?
- Do you need to address known vulnerabilities in hardware, software, or libraries?
- How are you hosting it? Is it accessible from the public?
- Do you have a recovery plan if your security measures lock you out? *(e.g., disabled root login or SSH keys)*

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

## 🛡️ Service Hardening

### Disable Autostart .desktop Files

```bash
sudo sed -i -e 's/NoDisplay=true/NoDisplay=false/g' /etc/xdg/autostart/*.desktop
```

### Disable Unnecessary Services

```bash
#!/bin/bash
# Service Hardening Script

services_to_disable=(
    "telnet"
    "rsh"
    "rlogin"
    "vsftpd"
    "httpd"
    "smb"
    "nfs"
)

echo "🔒 Hardening Services"
for service in "${services_to_disable[@]}"; do
    if systemctl is-enabled "$service" 2>/dev/null; then
        echo "Disabling $service..."
        sudo systemctl disable "$service"
        sudo systemctl stop "$service"
    fi
done

security_services=("fail2ban" "firewalld" "auditd")

for service in "${security_services[@]}"; do
    if systemctl list-unit-files | grep -q "$service"; then
        echo "Enabling $service..."
        sudo systemctl enable "$service"
        sudo systemctl start "$service"
    fi
done
```

### Additional Service Disables

```bash
# Disable systemd-timesync daemon
sudo systemctl disable systemd-timesyncd.service

# Disable bluetooth autostart
sudo sed -i -e 's/AutoEnable.*/AutoEnable = false/' /etc/bluetooth/main.conf
sudo sed -i -e 's/FastConnectable.*/FastConnectable = false/' /etc/bluetooth/main.conf

# Disable rfkill
sudo systemctl disable systemd-rfkill.service --global
sudo systemctl disable systemd-rfkill.socket --global

# Disable ModemManager
sudo systemctl disable ModemManager --global

# Disable speech-dispatcher
sudo systemctl disable speech-dispatcher --global

# Disable smartmontools
sudo systemctl disable smartmontools --global

# Disable kernel oops
sudo systemctl disable kerneloops.service --global

# Disable whoopsie
sudo systemctl disable whoopsie.service --global

# Disable avahi
sudo systemctl disable avahi-daemon.service --global

# Flush bluetooth
sudo rm -rfd /var/lib/bluetooth/*

# Disable remote-fs target
sudo systemctl mask remote-fs.target >/dev/null 2>&1
```

---

## 🔒 Kernel Hardening

### Reduce Systemd Timeout

```bash
sed -i -e 's/#DefaultTimeoutStartSec.*/DefaultTimeoutStartSec=5s/g' /etc/systemd/system.conf
sed -i -e 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=5s/g' /etc/systemd/system.conf
```

### Enable NetworkManager Dispatcher

```bash
sudo systemctl enable NetworkManager-dispatcher.service --global
```

### Security Options for Systemd Services

Common service hardening pattern:

```ini
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
DevicePolicy=closed
ProtectSystem=strict
ProtectHome=read-only
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
RestrictNamespaces=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
MemoryDenyWriteExecute=yes
LockPersonality=yes
```

Key options explained:

| Option | Purpose |
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
    └── proton.log                ← Debug output
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

> Turn debug logging off for benchmarking — logging costs frames.

### CPU Latency

```bash
powerprofilesctl set performance
# Or
cpupower frequency-set -g performance

# Kernel parameter consideration
preempt=full  # Fedora kernel supports on 6.12+
```

> `mitigations=off` buys a few percent but is a genuine security tradeoff — your call.

---

## 📚 Acknowledgements & Resources

### Inspiration Sources

- **[madaidan's Linux Hardening Guide](https://madaidans-insecurities.github.io/guides/linux-hardening.html)** - Primary inspiration
- **[Arch Wiki Security](https://wiki.archlinux.org/title/Security)**
- **[RHEL 9 Security Hardening](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/index)**
- **[CIS Red Hat Benchmark](https://www.cisecurity.org/benchmark/red_hat_linux)**
- **[OpenSCAP](https://github.com/ComplianceAsCode/content)**
- **[OpenSCAP Fedora Guide](https://static.open-scap.org/ssg-guides/ssg-fedora-guide-index.html)**
- **[k-config-hardened-check](https://github.com/a13xp0p0v/kconfig-hardened-check/)**
- **[Tommy's Desktop Linux Hardening](https://privsec.dev/posts/linux/desktop-linux-hardening/)**
- 

# 📜 Security Guide: Analyze the Threat Model

## Table of Contents

- [Analyze the Threat Model](#analyze-the-threat-model)
- [Linux Files Hierarchy](#linux-files-hierarchy)
- [Kernel Hardening](#kernel-hardening)
  - [Sysctl Settings](#sysctl-settings)
  - [Boot Parameters](#boot-parameters)

- --

## 🔍 Analyze the Threat Model

When approaching a system to secure, it's crucial to ask yourself a series of questions. Even if some of these questions seem trivial, simplifying the problem is essential for effective security.

- [ ] Why do you want to secure your server and services?
- [ ] How much security do you desire?
- [ ] How many devices, apps, software, and databases need securing?
- [ ] How much convenience are you willing to compromise for security? (People often prefer convenience over security.)
- [ ] What threats do you want to protect against?
- [ ] What are the specifics of your situation?
- [ ] Is physical access to your server/network a possible attack vector?
- [ ] Do you need to address known vulnerabilities in hardware, software, or libraries?
- [ ] How are you hosting it? Is it accessible from the public?
- [ ] Do you have a recovery plan if your security measures lock you out of your own server? (e.g., if you disabled root login or password-protected GRUB and deleted your SSH public key.)

# randomize MAC address & disable static hostname

```text
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

```text
sudo systemctl restart NetworkManager
sudo hostnamectl hostname "localhost"

```

## Set realtime to unlimited

```text
echo -e "@realtime - rtprio 99
@realtime - memlock unlimited" | sudo tee -a /etc/security/limits.conf

```

# ------------------------------------------------------------------------

```text

echo -e "Disable wait online service"
echo -e "[connectivity]
enabled=false" | sudo tee /etc/NetworkManager/conf.d/20-connectivity.conf
sudo systemctl mask NetworkManager-wait-online.service >/dev/null 2>&1

```

# ------------------------------------------------------------------------

# ------------------------------------------------------------------------

## Don't autostart .desktop

```text
sudo sed -i -e 's/NoDisplay=true/NoDisplay=false/g' /etc/xdg/autostart/*.desktop

```

# ------------------------------------------------------------------------

# ------------------------------------------------------------------------

```text

# Service Hardening Script

# Disable unnecessary services
services_to_disable=(
    "telnet"
    "rsh"
    "rlogin"
    "vsftpd"
    "httpd"  # If not needed
    "smb"
    "nfs"
)

echo "🔒 Hardening Services"
for service in "${services_to_disable[@]}"; do
    if systemctl is-enabled "$service" 2>/dev/null; then
        echo "Disabling $service..."
        sudo systemctl disable "$service"
        sudo systemctl stop "$service"
    fi
done

# Enable security-focused services
security_services=(
    "fail2ban"
    "firewalld"
    "auditd"
)

for service in "${security_services[@]}"; do
    if systemctl list-unit-files | grep -q "$service"; then
        echo "Enabling $service..."
        sudo systemctl enable "$service"
        sudo systemctl start "$service"
    fi
done

echo "✅ Service hardening completed!"
```

# ------------------------------------------------------------------------

# ------------------------------------------------------------------------

```text

echo -e "Disable systemd-timesync daemon"
sudo systemctl disable systemd-timesyncd.service
sudo system
```

# ------------------------------------------------------------------------

```text
echo -e "Disable bluetooth autostart"
sudo sed -i -e 's/AutoEnable.*/AutoEnable = false/' /etc/bluetooth/main.conf
sudo sed -i -e 's/FastConnectable.*/FastConnectable = false/' /etc/bluetooth/main.conf
sudo sed -i -e 's/ReconnectAttempts.*/ReconnectAttempts = 1/' /etc/bluetooth/main.conf
sudo sed -i -e 's/ReconnectIntervals.*/ReconnectIntervals = 1/' /etc/bluetooth/main.conf
```

# ------------------------------------------------------------------------

```text

echo -e "Disable systemd radio service/socket"
sudo systemctl disable systemd-rfkill.service
sudo systemctl --global disable systemd-rfkill.service
sudo systemctl disable systemd-rfkill.socket
sudo systemctl --global disable systemd-rfkill.socket
echo -e "Disable ModemManager"
sudo systemctl disable ModemManager
sudo systemctl --global disable ModemManager
echo -e "Disable speech-dispatcher"
sudo systemctl disable speech-dispatcher
sudo systemctl --global disable speech-dispatcher
echo -e "Disable smartmontools"
sudo systemctl disable smartmontools
sudo systemctl --global disable smartmontools
echo -e "Disable kerneloops"
sudo systemctl disable kerneloops.service
sudo systemctl --global disable kerneloops.service
echo -e "Disable whoopsie"
sudo systemctl disable whoopsie.service
sudo systemctl --global disable whoopsie.service
echo -e "Disable saned service/socket"
sudo systemctl disable saned.service
sudo systemctl --global disable saned.service
sudo systemctl disable saned.socket
sudo systemctl --global disable saned.socket
echo -e "Disable apport service/socket"
sudo systemctl disable apport.service
sudo systemctl --global disable apport.service
sudo systemctl disable apport-forward.socket
sudo systemctl --global disable apport-forward.socket
echo -e "Disable brltty"
sudo systemctl disable brltty.service
sudo systemctl --global disable brltty.service
sudo systemctl disable brltty-udev.service
sudo systemctl --global disable brltty-udev.service
```

# ------------------------------------------------------------------------

## Fix connecting local devices

```text
sudo sed -i -e 's/hosts: .*/hosts: files mdns4_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns mdns4 mdns/' /etc/nsswitch.conf

```

# ------------------------------------------------------------------------

```text
echo -e "Reduce systemd timeout"
sudo sed -i -e 's/#DefaultTimeoutStartSec.*/DefaultTimeoutStartSec=5s/g' /etc/systemd/system.conf
sudo sed -i -e 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=5s/g' /etc/systemd/system.conf

```

# ------------------------------------------------------------------------

```text

echo -e "Enable NetworkManager dispatcher"
sudo systemctl enable NetworkManager-dispatcher.service
sudo systemctl --global enable NetworkManager-dispatcher.service
```

## **security and hardening options for systemd service units**

A common and reliable pattern in service unit files is thus:

```
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
DevicePolicy=closed
ProtectSystem=strict
ProtectHome=read-only
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
RestrictNamespaces=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
MemoryDenyWriteExecute=yes
LockPersonality=yes
```

```text

But there's so much more you can do. Here are some key option definitions which I've excerpted and abbreviated from systemd's manual pages.

* [IPAddressAllow, IPAddressDeny](https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html#IPAddressAllow=ADDRESS%5B/PREFIXLENGTH%5D%E2%80%A6)

Turn on address range network traffic filtering for IP packets sent and received over `AF_INET` and `AF_INET6` sockets. Both directives take a space separated list of IPv4 or IPv6 addresses, each optionally suffixed with an address prefix length in bits (separated by a "/" character). If the latter is omitted, the address is considered a host address, i.e. the prefix covers the whole address (32 for IPv4, 128 for IPv6).

* [DeviceAllow](https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html#DeviceAllow=)

Control access to specific device nodes by the executed processes. Takes two space-separated strings: a device node specifier followed by a combination of r, w, m to control reading, writing, or creation of the specific device node(s) by the unit (mknod), respectively.

* [DevicePolicy](https://www.kernel.org/doc/Documentation/cgroup-v1/devices.txt)

Control the policy for allowing device access:

`strict` means to only allow types of access that are explicitly specified.

`closed` in addition, allows access to standard pseudo devices including /dev/null, /dev/zero, /dev/full, /dev/random, and /dev/urandom.

`auto` in addition, allows access to all devices if no explicit DeviceAllow= is present. This is the default.

* [ConditionSecurity](https://www.freedesktop.org/software/systemd/man/systemd.unit.html#ConditionSecurity=)

May be used to check whether the given security technology is enabled on the system. Currently, the recognized values are `selinux`, `apparmor`, `tomoyo`, `ima`, `smack`, `audit` and `uefi-secureboot`. The test may be negated by prepending an exclamation mark.

* [CapabilityBoundingSet](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#CapabilityBoundingSet=)

Controls which capabilities to include in the capability bounding set for the executed process. See capabilities(7) for details. Takes a whitespace-separated list of capability names, e.g. `CAP_SYS_ADMIN`, `CAP_DAC_OVERRIDE`, `CAP_SYS_PTRACE`.

* [MemoryDenyWriteExecute](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#MemoryDenyWriteExecute=)

Takes a boolean argument. If set, attempts to create memory mappings that are writable and executable at the same time, or to change existing memory mappings to become executable, or mapping shared memory segments as executable are prohibited. Specifically, a system call filter is added that rejects [mmap](http://man7.org/linux/man-pages/man2/mmap.2.html) system calls with both `PROT_EXEC` and `PROT_WRITE` set, [mprotect](http://man7.org/linux/man-pages/man2/mprotect.2.html) or [pkey_mprotect](http://man7.org/linux/man-pages/man2/pkey_mprotect.2.html) system calls with `PROT_EXEC` set and [shmat](http://man7.org/linux/man-pages/man2/shmat.2.html) system calls with `SHM_EXEC` set. Note that this option is incompatible with programs and libraries that generate program code dynamically at runtime, including JIT execution engines, executable stacks, and code "trampoline" feature of various C compilers. This option improves service security, as it makes harder for software exploits to change running code dynamically. However, the protection can be circumvented, if the service can write to a filesystem, which is not mounted with noexec (such as /dev/shm), or it can use memfd_create(). This can be prevented by making such file systems inaccessible to the service (e.g. `InaccessiblePaths=/dev/shm`) and installing further system call filters (`SystemCallFilter=~memfd_create`).

* [NoNewPrivileges](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#NoNewPrivileges=)

Takes a boolean argument. If true, ensures that the service process and all its children can never gain new privileges through execve() (e.g. via setuid or setgid bits, or filesystem capabilities). This is the simplest and most effective way to ensure that a process and its children can never elevate privileges again. Defaults to false, but certain settings override this and ignore the value of this setting. This is the case when `SystemCallFilter=`, `SystemCallArchitectures=`, `RestrictAddressFamilies=`, `RestrictNamespaces=`, `PrivateDevices=`, `ProtectKernelTunables=`, `ProtectKernelModules=`, `MemoryDenyWriteExecute=`, `RestrictRealtime=`, `RestrictSUIDSGID=`, `DynamicUser=` or `LockPersonality=` are specified. Note that even if this setting is overridden by them, systemctl show shows the original value of this setting. See also: [No New Privileges Flag](https://www.kernel.org/doc/html/latest/userspace-api/no_new_privs.html).

* [PrivateDevices](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#PrivateDevices=)

Takes a boolean argument. If true, sets up a new /dev mount for the executed processes and only adds API pseudo devices such as */dev/null*, */dev/zero* or */dev/random* (as well as the pseudo TTY subsystem) to it, but no physical devices such as */dev/sda*, system memory */dev/mem*, system ports */dev/port* and others. This is useful to securely turn off physical device access by the executed process. Defaults to false.

* [PrivateTmp](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#PrivateTmp=)

Takes a boolean argument. If true, sets up a new file system namespace for the executed processes and mounts private */tmp* and */var/tmp* directories inside it that is not shared by processes outside of the namespace. This is useful to secure access to temporary files of the process, but makes sharing between processes via */tmp* or */var/tmp* impossible. If this is enabled, all temporary files created by a service in these directories will be removed after the service is stopped. Defaults to false.

* [PrivateUsers](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#PrivateUsers=)

Takes a boolean argument. If true, sets up a new user namespace for the executed processes and configures a minimal user and group mapping, that maps the "root" user and group as well as the unit's own user and group to themselves and everything else to the "nobody" user and group. This is useful to securely detach the user and group databases used by the unit from the rest of the system, and thus to create an effective sandbox environment. All files, directories, processes, IPC objects and other resources owned by users/groups not equaling "root" or the unit's own will stay visible from within the unit but appear owned by the "nobody" user and group. If this mode is enabled, all unit processes are run without privileges in the host user namespace (regardless if the unit's own user/group is "root" or not). Specifically this means that the process will have zero process capabilities on the host's user namespace, but full capabilities within the service's user namespace. Settings such as `CapabilityBoundingSet=` will affect only the latter, and there's no way to acquire additional capabilities in the host's user namespace. Defaults to off.

* [ProtectControlGroups](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#ProtectControlGroups=)

Takes a boolean argument. If true, the Linux Control Groups ([cgroups](http://man7.org/linux/man-pages/man7/cgroups.7.html)) hierarchies accessible through */sys/fs/cgroup* will be made read-only to all processes of the unit. Except for container managers no services should require write access to the control groups hierarchies; it is hence recommended to turn this on for most services. Defaults to off.

* [ProtectHome](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#ProtectHome=)

Takes a boolean argument or "`read-only`". If true, the directories */home*, */root* and */run/user* are made inaccessible and empty for processes invoked by this unit. If set to "`read-only`", the three directories are made read-only instead. It is recommended to enable this setting for all long-running services (in particular network-facing ones), to ensure they cannot get access to private user data, unless the services actually require access to the user's private data. This setting is implied if `DynamicUser=` is set.

* [ProtectKernelModules](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#ProtectKernelModules=)

Takes a boolean argument. If true, explicit module loading will be denied. This allows to turn off module load and unload operations on modular kernels. It is recommended to turn this on for most services that do not need special file systems or extra kernel modules to work. Default to off. Enabling this option removes `CAP_SYS_MODULE` from the capability bounding set for the unit, and installs a system call filter to block module system calls, also */usr/lib/modules* is made inaccessible. For this setting the same restrictions regarding mount propagation and privileges apply as for `ReadOnlyPaths=` and related calls, see above. Note that limited automatic module loading due to user configuration or kernel mapping tables might still happen as side effect of requested user operations, both privileged and unprivileged. To disable module auto-load feature please see [sysctl.d](https://www.freedesktop.org/software/systemd/man/sysctl.d.html#) `kernel.modules_disabled` mechanism and `/proc/sys/kernel/modules_disabled` documentation.

* [ProtectKernelTunables](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#ProtectKernelTunables=)

Takes a boolean argument. If true, kernel variables accessible through */proc/sys*, */sys*, */proc/sysrq-trigger*, */proc/latency_stats*, */proc/acpi*, */proc/timer_stats*, */proc/fs* and */proc/irq* will be made read-only to all processes of the unit. Usually, tunable kernel variables should only be written at boot-time, with the [sysctl.d](https://www.freedesktop.org/software/systemd/man/sysctl.d.html#) mechanism. Almost no services need to write to these at runtime; it is hence recommended to turn this on for most services. For this setting the same restrictions regarding mount propagation and privileges apply as for `ReadOnlyPaths=` and related calls, see above. Defaults to off. Note that this option does not prevent kernel tuning through IPC interfaces and external programs. However `InaccessiblePaths=` can be used to make some IPC file system objects inaccessible.

* [ProtectKernelLogs](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#ProtectKernelLogs=)

Takes a boolean argument. If true, access to the kernel log ring buffer will be denied. It is recommended to turn this on for most services that do not need to read from or write to the kernel log ring buffer. Enabling this option removes `CAP_SYSLOG` from the capability bounding set for this unit, and installs a system call filter to block the [syslog(2)](http://man7.org/linux/man-pages/man2/syslog.2.html) system call (not to be confused with the libc API [syslog(3)](http://man7.org/linux/man-pages/man3/syslog.3.html) for userspace logging). The kernel exposes its log buffer to userspace via `/dev/kmsg` and `/proc/kmsg`. If enabled, these are made inaccessible to all the processes in the unit.

This option is only available for system services and is not supported for services running in per-user instances of the service manager.

* [ProtectSystem](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#ProtectSystem=)

Takes a boolean argument or the special values "`full`" or "`strict`". If true, mounts the */usr* and */boot* directories read-only for processes invoked by this unit. If set to "`full`", the */etc* directory is mounted read-only, too. If set to "`strict`" the entire file system hierarchy is mounted read-only, except for the API file system subtrees */dev*, *proc* and */sys* (protect these directories using `PrivateDevices=`, `ProtectKernelTunables=`, `ProtectControlGroups=`). This setting ensures that any modification of the vendor-supplied operating system (and optionally its configuration, and local mounts) is prohibited for the service. It is recommended to enable this setting for all long-running services, unless they are involved with system updates or need to modify the operating system in other ways. If this option is used, `ReadWritePaths=` may be used to exclude specific directories from being made read-only. This setting is implied if `DynamicUser=` is set. Defaults to off.

* [ReadWritePaths](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#ReadWritePaths=), [ReadOnlyPaths](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#ReadOnlyPaths=), [InaccessiblePaths](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#InaccessiblePaths=)

Sets up a new file system namespace for executed processes. These options may be used to limit access a process might have to the file system hierarchy. Each setting takes a space-separated list of paths relative to the host's root directory (i.e. the system running the service manager). Note that if paths contain symlinks, they are resolved relative to the root directory.

Paths listed in `ReadWritePaths=` are accessible from within the namespace with the same access modes as from outside of it.

Paths listed in `ReadOnlyPaths=` are accessible for reading only, writing will be refused even if the usual file access controls would permit this.

Paths listed in `InaccessiblePaths=` will be made inaccessible for processes inside the namespace along with everything below them in the file system hierarchy.

* [RestrictAddressFamilies](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RestrictAddressFamilies=)

Restricts the set of socket address families accessible to the processes of this unit. Takes a space-separated list of address family names to whitelist, such as `AF_UNIX`, `AF_INET` or `AF_INET6`. When prefixed with `~` the listed address families will be applied as blacklist, otherwise as whitelist. Note that this restricts access to the [socket](http://man7.org/linux/man-pages/man2/socket.2.html) system call only. Sockets passed into the process by other means (for example, by using socket activation with socket units, see [systemd.socket](systemd.socket.html#)) are unaffected. Also, sockets created with `socketpair()` (which creates connected AF_UNIX sockets only) are unaffected. Note that this option has no effect on 32-bit x86 and is ignored (but works correctly on x86-64). If running in user mode, or in system mode, but without the `CAP_SYS_ADMIN` capability (e.g. setting `User=nobody`), `NoNewPrivileges=yes` is implied. By default, no restriction applies, all address families are accessible to processes. If assigned the empty string, any previous list changes are undone. Use this option to limit exposure of processes to remote systems, in particular via exotic network protocols. Note that in most cases, the local `AF_UNIX` address family should be included in the configured whitelist as it is frequently used for local communication, including for [syslog](http://man7.org/linux/man-pages/man2/syslog.2.html) logging. This does not affect commands prefixed with `+`.

* [RestrictRealtime](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RestrictRealtime=)

Takes a boolean argument. If set, any attempts to enable realtime scheduling in a process of the unit are refused. This restricts access to realtime task scheduling policies such as `SCHED_FIFO`, `SCHED_RR` or `SCHED_DEADLINE`. See [sched](http://man7.org/linux/man-pages/man7/sched.7.html) for details about these scheduling policies. If running in user mode, or in system mode, but without the `CAP_SYS_ADMIN` capability (e.g. setting `User=`), `NoNewPrivileges=yes` is implied. Realtime scheduling policies may be used to monopolize CPU time for longer periods of time, and may hence be used to lock up or otherwise trigger Denial-of-Service situations on the system. It is hence recommended to restrict access to realtime scheduling to the few programs that actually require them. Defaults to off.

* [LockPersonality](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#LockPersonality=)

Takes a boolean argument. If set, locks down the [personality](http://man7.org/linux/man-pages/man2/personality.2.html) system call so that the kernel execution domain may not be changed from the default or the personality selected with `Personality=` directive.

* [PrivateMounts](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#PrivateMounts=)

Takes a boolean parameter. If set, the processes of this unit will be run in their own private file system (mount) namespace with all mount propagation from the processes towards the host's main file system namespace turned off. This means any file system mount points established or removed by the unit's processes will be private to them and not be visible to the host.

* [PrivateNetwork](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#PrivateNetwork=)

Takes a boolean argument. If true, sets up a new network namespace for the executed processes and configures only the loopback network device "lo" inside it. No other network devices will be available to the executed process. This is useful to turn off network access by the executed process. Defaults to false.

* [ProtectHostname](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#ProtectHostname=)

Takes a boolean argument. When set, sets up a new UTS namespace for the executed processes. In addition, changing hostname or domainname is prevented. Defaults to off.

* [AmbientCapabilities](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#AmbientCapabilities=)

Controls which capabilities to include in the ambient capability set for the executed process. Takes a whitespace-separated list of capability names, e.g. `CAP_SYS_ADMIN`, `CAP_DAC_OVERRIDE`, `CAP_SYS_PTRACE`.

* [SecureBits](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#SecureBits=)

Controls the secure bits set for the executed process. Takes a space-separated combination of options from the following list: `keep-caps`, `keep-caps-locked`, `no-setuid-fixup`, `no-setuid-fixup-locked`, `noroot`, and `noroot-locked`.

* [RestrictSUIDSGID](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#RestrictSUIDSGID=)

Takes a boolean argument. If set, any attempts to set the set-user-ID (SUID) or set-group-ID (SGID) bits on files or directories will be denied (for details on these bits see [inode](http://man7.org/linux/man-pages/man7/inode.7.html).

* [SELinuxContext](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#SELinuxContext=)

Set the SELinux security context of the executed process. If set, this will override the automated domain transition. However, the policy still needs to authorize the transition. This directive is ignored if SELinux is disabled.

* [AppArmorProfile](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#AppArmorProfile=)

Takes a profile name as argument. The process executed by the unit will switch to this profile when started. Profiles must already be loaded in the kernel, or the unit will fail. This result in a non operation if AppArmor is not enabled.

* [SmackProcessLabel](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#SmackProcessLabel=)

Takes a SMACK64 security label as argument. The process executed by the unit will be started under this label and SMACK will decide whether the process is allowed to run or not, based on it.

* [SystemCallFilter](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#SystemCallFilter=)

Takes a space-separated list of system call names. If this setting is used, all system calls executed by the unit processes except for the listed ones will result in immediate process termination with the SIGSYS signal (whitelisting). If the first character of the list is "~", the effect is inverted: only the listed system calls will result in immediate process termination (blacklisting). Blacklisted system calls and system call groups may optionally be suffixed with a colon (":") and "errno" error number (between 0 and 4095) or errno name such as `EPERM`, `EACCES` or `EUCLEAN` (see [errno](http://man7.org/linux/man-pages/man3/errno.3.html) for a full list).
```

# ------------------------------------------------------------------------

```text
echo -e "Disable systemd avahi daemon service"
sudo systemctl disable avahi-daemon.service
sudo systemctl --global disable avahi-daemon.service
```

# ------------------------------------------------------------------------

# ------------------------------------------------------------------------

## Flush bluetooth

```text
sudo rm -rfd /var/lib/bluetooth/*

```

#

# ------------------------------------------------------------------------

echo -e "Disable remote-fs"

```text
sudo systemctl mask remote-fs.target >/dev/null 2>&1

```

```text
## Improve NVME
if $(find /sys/block/nvme[0-9]* | grep -q nvme); then
    echo -e "options nvme_core default_ps_max_latency_us=0" | sudo tee /etc/modprobe.d/nvme.conf
fi
```

# ------------------------------------------------------------------------

## Improve PCI latency

```text
sudo setpci -v -s '*:*' latency_timer=10 >/dev/null 2>&1
sudo setpci -v -s '0:0' latency_timer=0 >/dev/null 2>&1
```

```text

echo -e "Compress fonts"
woff2_compress /usr/share/fonts/opentype/*/*ttf
woff2_compress /usr/share/fonts/truetype/*/*ttf
## Optimize font cache
fc-cache -rfv
## Optimize icon cache
gtk-update-icon-cache
```

# Acknowledgements

recommendations from these sources:

- [madaidan's Linux Hardening Guide](https://madaidans-insecurities.github.io/guides/linux-hardening.html) - the initial inspiration for this project
- [Arch Wiki](https://wiki.archlinux.org/title/Security)
- [Red Hat Enterprise Linux 9 Security Hardening Documentations](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/index)
- [Center for Internet Security's Red Hat Benchmark](https://www.cisecurity.org/benchmark/red_hat_linux)
- [OpenSCAP](https://github.com/ComplianceAsCode/content)
- [OpenSCAP Fedora Guide](https://static.open-scap.org/ssg-guides/ssg-fedora-guide-index.html)
- [k-config-hardened-check](https://github.com/a13xp0p0v/kconfig-hardened-check/)
- [Tommy's Desktop Linux Hardening Guide](https://privsec.dev/posts/linux/desktop-linux-hardening/)

# Introductory resources

If you're relatively new to the infosec (information security) world, then the following resources come recommended:

🎥 **YouTube channels**

- [NBTV, with Naomi Brockwell](https://www.youtube.com/@NaomiBrockwellTV)
- [The New Oil](https://www.youtube.com/channel/UCH5DsMZAgdx5Fkk9wwMNwCA)
- [Side of Burritos](https://www.youtube.com/@sideofburritos)
- [Techlore](https://www.youtube.com/@techlore)

🎧 **Podcasts**

- [Malwarebytes Podcast](https://www.malwarebytes.com/blog/category/podcast)
- [Surveillance Report](https://surveillancereport.tech/)

👀 **Websites & guides**

- [National Cyber Security Centre (UK)](https://www.ncsc.gov.uk/section/advice-guidance/all-topics)
- [The New Oil](https://thenewoil.org/)
- [Privacy Guides](https://www.privacyguides.org/en/)

- --

## 🗂️ ---
