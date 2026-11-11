

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
Terminal
Tool	Source
Kitty	sw.kovidgoyal.net/kitty
Fish	fishshell.com
ble.sh	github.com/akinomyoga/ble.sh
Starship	starship.rs
Zoxide	github.com/ajeetdsouza/zoxide
Lazygit	github.com/jesseduffield/lazygit
Yazi	github.com/sxyazi/yazi
mise	mise.jdx.dev
fzf	github.com/junegunn/fzf
ripgrep	github.com/BurntSushi/ripgrep
bat	github.com/sharkdp/bat
eza	github.com/eza-community/eza
JetBrainsMono NF	github.com/ryanoasis/nerd-fonts
Rice / Desktop
Tool	Source
Conky	github.com/brndnmtthws/conky
Kvantum	github.com/tsujan/Kvantum
Layan KDE	github.com/vinceliuice/Layan-kde
Panel Colorizer	github.com/luisbocanegra/plasma-panel-colorizer
Wallpaper	Made for this repo, no third-party source; covered by the MIT license like the rest of it
Gaming
Tool	Source
Steam	store.steampowered.com
ProtonUp-Qt	github.com/DavidoTek/ProtonUp-Qt
Heroic Games Launcher	heroicgameslauncher.com
Lutris	lutris.net
Bottles	usebottles.com
Prism Launcher	prismlauncher.org
GOverlay	github.com/benjamimgois/goverlay
EasyEffects	github.com/wwmm/easyeffects
MangoHud	github.com/flightlessmango/MangoHud
GameMode	github.com/FeralInteractive/gamemode
Gamescope	github.com/ValveSoftware/gamescope
Gaming Guides
Guide	Source
Linux Gaming Optimization	github.com/theyareonit/linux-gaming-optimization
Linux Gaming Guide (AdelKS)	github.com/AdelKS/LinuxGamingGuide
Linux Gaming Wiki	linux-gaming.kwindu.eu
Security
Tool	Source
kernel-hardening-checker	github.com/a13xp0p0v/kernel-hardening-checker


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
