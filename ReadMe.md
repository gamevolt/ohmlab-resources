W.I.P -- UNFINISHED
- - THIS SCRIPT IS FAR FROM FINISHED AND IS USED AS A PLACEHOLDER AT THE MOMENT, DO NOT RUN BLINDLY - YOU WILL MOST LIKELY BREAK YOUR SETUP SINCE
I MAY ADD THINGS FROM OTHER  LEFT OVER BASH SCRIPTS I PREVIOUSLY WROTE WHICH ARE HEAVILY OUTDATED NOW.
YOU'VE BEEN WARNED
=================================================================

                                    N O T E S

 ┌│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│┐
 │▓▓                                                                        ▓▓│
 │▓▓                                                                        ▓▓│
 └│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│┘


                                    N O T E S

# 📜 Security Guide: Analyze the Threat Model

## Table of Contents

-

- --

# **Linux Files Hierarchy**

- [ ] Knowing your system is the  most important part. Security is not a software,services nor a patch
- [ ] It is a constant efforts and in depth knowledge of your system and which services run, which ports are used list goes on....
  
Linux kernel and its related files are in /boot directory which is by default as read-write. Changing it to read-only reduces the risk of unauthorized modification of critical boot files. We need to edit /etc/fstab file and insert the line below<

It is important to mount couple partitions with specific mount options and their own partitions
A good example would be the /tmp partition which is often used for privilege escalations

Most of hardening or security guides are spreading false hood. Those are not only lacking, they're very far to be battle-ready for internet.
|
One of the most important step of securing your battlestation is making your threat model
-- add informations about threats modelling

guideline to follow in order to get base setttings/hardening --
<https://madaidans-insecurities.github.io/guides/linux-hardening.html>

crowdsec, spoofdpi, amneziaWG , EBTABLES, ebpf & xdp , thor ( yara detections ), automating ipset blacklist , setting up bridged vlan
debloat 2 reduce attack surface .. etc

## 1. Kernel Hardening [(Section 2)](https://madaidans-insecurities.github.io/guides/linux-hardening.html#kernel)

### 1.1. Sysctl Settings (Section [2.2](https://madaidans-insecurities.github.io/guides/linux-hardening.html#sysctl), [10](https://madaidans-insecurities.github.io/guides/linux-hardening.html#tcp-timestamps), [12](https://madaidans-insecurities.github.io/guides/linux-hardening.html#core-dumps-sysctl), [13](https://madaidans-insecurities.github.io/guides/linux-hardening.html#swap), [16](https://madaidans-insecurities.github.io/guides/linux-hardening.html#ipv6-privacy))

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
- [ ] Do you have a recovery plan if your security measures lock you out of your own server? (e.g., if you disabled root login or password-
  protected GRUB and deleted your SSH public key.)
Threat Modeling Resourcesλ
Here are various threat modeling resources if you want to go deeper in threat modeling.

We recommend the LINDDUN https://www.linddun.org threat modeling method [Archive.org]:

Researchers created an online tool to help make your threat model at https://www.linddun.org/go [Archive.org].
It is synergistic with STRIDE below.
It is focused on privacy but is clearly perfectly suitable for anonymity.
It is accessible to all skill levels including beginners (providing many tutorials) but also suitable for highly skilled readers.
It is used in the making of the Threat Modeling Manifesto: https://www.threatmodelingmanifesto.org/ [Archive.org]
LINDDUN threat modeling tutorials and resources:

We recommend the following quick tutorial video from "The Hated One" YouTube channel with the approval and review from LINDDUN designers: https://www.youtube.com/watch?v=6AXkJ3dot2s [Invidious] to get started.
More resources for deeper understanding and usage:

You can read more here: A Lightweight Approach to Privacy Threat Modeling
Here are two videos from Dr. K. Wuyts (imec-DistriNet, KU Leuven) explaining the process:
Privacy & prejudice: on privacy threat modeling misconceptions [Invidious]
Privacy Threat Model Using LINDDUN [Invidious]
image59(Illustration from LINDDUN2015)

Here are alternative resources and methodologies if LINDDUN doesn't suit you:

Online Operations Security: https://github.com/devbret/online-OPSEC
Microsoft's STRIDE: https://en.wikipedia.org/wiki/STRIDE_%28security%29 [Wikiless] [Archive.org]
PASTA: https://versprite.com/tag/pasta-threat-modeling/ [Archive.org]
Threat Modeling: 12 Available Methods: https://insights.sei.cmu.edu/blog/threat-modeling-12-available-methods [Archive.org]
Threat Modelling: https://www.geeksforgeeks.org/threat-modelling/ [Archive.org]
Evil-Maid and Tampering Notesλ
Your context needs to be taken into account.

Preventing an evil-maid attack attack or tampering might lead to bad consequences. Your adversary might then resort to other means to obtain the key.

On the other hand, allowing the attack but detecting it will not let your adversary know that you are aware of the tampering. You can then take steps safely to not reveal information and possibly leave.

See the Some last OPSEC thoughts section for some tips.






















-------------

# randomize MAC address & disable static hostname
sudo bash -c 'cat > /etc/NetworkManager/conf.d/00-macrandomize.conf' <<-'EOF'
[main]
hostname-mode=none

[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

sudo systemctl restart NetworkManager
sudo hostnamectl hostname "localhost"

## Set realtime to unlimited
echo -e "@realtime - rtprio 99
@realtime - memlock unlimited" | sudo tee -a /etc/security/limits.conf

# ------------------------------------------------------------------------

echo -e "Disable wait online service"
echo -e "[connectivity]
enabled=false" | sudo tee /etc/NetworkManager/conf.d/20-connectivity.conf
sudo systemctl mask NetworkManager-wait-online.service >/dev/null 2>&1

# ------------------------------------------------------------------------
# ------------------------------------------------------------------------

## Don't autostart .desktop
sudo sed -i -e 's/NoDisplay=true/NoDisplay=false/g' /etc/xdg/autostart/*.desktop

# ------------------------------------------------------------------------
# ------------------------------------------------------------------------


# ------------------------------------------------------------------------
# ------------------------------------------------------------------------

echo -e "Disable systemd-timesync daemon"
sudo systemctl disable systemd-timesyncd.service
sudo system
# ------------------------------------------------------------------------

echo -e "Disable bluetooth autostart"
sudo sed -i -e 's/AutoEnable.*/AutoEnable = false/' /etc/bluetooth/main.conf
sudo sed -i -e 's/FastConnectable.*/FastConnectable = false/' /etc/bluetooth/main.conf
sudo sed -i -e 's/ReconnectAttempts.*/ReconnectAttempts = 1/' /etc/bluetooth/main.conf
sudo sed -i -e 's/ReconnectIntervals.*/ReconnectIntervals = 1/' /etc/bluetooth/main.conf

# ------------------------------------------------------------------------

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

# ------------------------------------------------------------------------

## Fix connecting local devices
sudo sed -i -e 's/hosts: .*/hosts: files mdns4_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns mdns4 mdns/' /etc/nsswitch.conf

# ------------------------------------------------------------------------

echo -e "Reduce systemd timeout"
sudo sed -i -e 's/#DefaultTimeoutStartSec.*/DefaultTimeoutStartSec=5s/g' /etc/systemd/system.conf
sudo sed -i -e 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=5s/g' /etc/systemd/system.conf

# ------------------------------------------------------------------------

echo -e "Enable NetworkManager dispatcher"
sudo systemctl enable NetworkManager-dispatcher.service
sudo systemctl --global enable NetworkManager-dispatcher.service

# ------------------------------------------------------------------------

echo -e "Disable systemd avahi daemon service"
sudo systemctl disable avahi-daemon.service
sudo systemctl --global disable avahi-daemon.service

# ------------------------------------------------------------------------

# ------------------------------------------------------------------------

## Flush bluetooth
sudo rm -rfd /var/lib/bluetooth/*

#

# ------------------------------------------------------------------------

echo -e "Disable remote-fs"
sudo systemctl mask remote-fs.target >/dev/null 2>&1

## Improve NVME
if $(find /sys/block/nvme[0-9]* | grep -q nvme); then
    echo -e "options nvme_core default_ps_max_latency_us=0" | sudo tee /etc/modprobe.d/nvme.conf
fi

# ------------------------------------------------------------------------

## Improve PCI latency
sudo setpci -v -s '*:*' latency_timer=10 >/dev/null 2>&1
sudo setpci -v -s '0:0' latency_timer=0 >/dev/null 2>&1




echo -e "Compress fonts"
woff2_compress /usr/share/fonts/opentype/*/*ttf
woff2_compress /usr/share/fonts/truetype/*/*ttf
## Optimize font cache
fc-cache -rfv
## Optimize icon cache
gtk-update-icon-cache
