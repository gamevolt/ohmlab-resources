W.I.P
-- THIS SCRIPT IS FAR FROM FINISHED AND IS USED AS A PLACEHOLDER AT THE MOMENT, DO NOT RUN BLINDLY - YOU WILL MOST LIKELY BREAK YOUR SETUP SINCE
I MAY ADD THINGS FROM OTHER  LEFT OVER BASH SCRIPTS I PREVIOUSLY WROTE WHICH ARE HEAVILY OUTDATED NOW.
YOU'VE BEEN WARNED 
=================================================================
 
                                    N O T E S
 
 ┌│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│┐
 │▓▓                                                                        ▓▓│
 │▓▓                                                                        ▓▓│
 └│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│┘

                                    N O T E S
 

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

echo -e "Enable tmpfs ramdisk"
sudo sed -i -e '/^\/\/tmpfs/d' /etc/fstab
echo -e "tmpfs /var/tmp tmpfs nodiratime,nodev,nosuid,mode=1777 0 0
tmpfs /var/log tmpfs nodiratime,nodev,nosuid,mode=1777 0 0
tmpfs /var/run tmpfs nodiratime,nodev,nosuid,mode=1777 0 0
tmpfs /var/lock tmpfs nodiratime,nodev,nosuid,mode=1777 0 0
tmpfs /var/cache tmpfs nodiratime,nodev,nosuid,mode=1777 0 0
tmpfs /var/volatile tmpfs nodiratime,nodev,nosuid,mode=1777 0 0
tmpfs /var/spool tmpfs nodiratime,nodev,nosuid,mode=1777 0 0
tmpfs /media tmpfs nodiratime,nodev,nosuid,mode=1777 0 0
tmpfs /dev/shm tmpfs nodiratime,nodev,nosuid,mode=1777 0 0
tmpfs /sys/fs/cgroup tmpfs nodiratime,nodev,nosuid,mode=1777 0 0" | sudo tee -a /etc/fstab

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
echo -e "Disable man-db service/timer"
sudo systemctl disable man-db.service
sudo systemctl --global disable man-db.service
sudo systemctl disable man-db.timer
sudo systemctl --global disable man-db.timer

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
