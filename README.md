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
