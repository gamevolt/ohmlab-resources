# System services. Keep ModemManager on a laptop with a mobile broadband (WWAN)
# modem, and pcscd if you use a smart card or a YubiKey's PIV/OpenPGP applet.
sudo systemctl disable --now ModemManager avahi-daemon.socket avahi-daemon pcscd.socket pcscd

# Unused services holding sockets. gssproxy must be masked, not disabled —
# auth-rpcgss-module.service pulls it back in through WantedBy.
sudo systemctl disable --now cups.service cups.socket cups.path   # no printer
sudo systemctl mask --now gssproxy.service                        # no NFS mounts

# KDE Connect binds 0.0.0.0:1716 plus random UDP ports. Remove the package rather
# than masking it — Plasma re-activates the daemon over D-Bus, and a stub D-Bus
# service makes plasmashell block for 25s per attempt and the panel disappear.
# Keep the two dependencies that are useful on their own.
sudo dnf mark user fuse-sshfs openssh-askpass
sudo dnf remove -y kde-connect

# Baloo file indexer (major CPU offender)
balooctl6 disable
kwriteconfig6 --file baloofilerc --group "Basic Settings" --key "Indexing-Enabled" false

# KDE user services. These are generated from XDG autostart files and have no
# [Install] section, so `disable` silently does nothing — they must be masked.
# Verify with `systemctl --user is-enabled <unit>`: "generated" means still active.
systemctl --user mask --now \
  app-org.kde.discover.notifier@autostart.service \
  app-org.kde.kalendarac@autostart.service \
  app-sealertauto@autostart.service \
  app-org.freedesktop.problems.applet@autostart.service \
  'app-imsettings\x2dstart@autostart.service' \
  app-vboxclient@autostart.service

# Akonadi (KDE PIM — only needed if using KMail/Kontact). It pulls in ~16 processes
# and its own MariaDB. Same reason: mask, not disable.
systemctl --user mask --now akonadi_control.service

# DrKonqi's crash pickup: KDE's own unit stops it after 30 minutes (RuntimeMaxSec), which
# systemd records as a failed unit at every login. Crashes while logged in still get their
# dialog through drkonqi-coredump-launcher.socket; only crashes from before login go unseen.
systemctl --user mask --now drkonqi-coredump-pickup.service

### Disable Autostart .desktop Files

```bash
sudo sed -i -e 's/NoDisplay=true/NoDisplay=false/g' /etc/xdg/autostart/*.desktop
```

### Additional Service Disables

```
# Disable systemd-timesync daemon
sudo systemctl disable systemd-timesyncd.service

# Disable bluetooth autostart
sudo sed -i -e 's/AutoEnable.*/AutoEnable = false/' /etc/bluetooth/main.conf
sudo sed -i -e 's/FastConnectable.*/FastConnectable = false/' /etc/bluetooth/main.conf


mkdir -p /etc/systemd/system/user-.slice.d
write /etc/systemd/system/user-.slice.d/io.conf \
"[Slice]
IOWeight=1000"


# Disable rfkill
sudo systemctl disable systemd-rfkill.service --global
sudo systemctl disable systemd-rfkill.socket --global

# Disable ModemManager
sudo systemctl disable ModemManager --global

# Disable speech-dispatcher
sudo systemctl disable speech-dispatcher --global

# Disable smartmontools
sudo systemctl disable smartmontools --global

# Disable avahi
sudo systemctl disable avahi-daemon.service --global


# Serial ports ttyS0-3 (saves 4.8s)
sudo systemctl mask serial-getty@ttyS0.service
sudo systemctl mask serial-getty@ttyS1.service
sudo systemctl mask serial-getty@ttyS2.service
sudo systemctl mask serial-getty@ttyS3.service
echo "[OK] Serial ports masked"

# Disable unused services
sudo systemctl disable systemd-hwdb-update.service 2>/dev/null
sudo systemctl disable accounts-daemon.service 2>/dev/null
sudo systemctl disable avahi-daemon.service 2>/dev/null
sudo systemctl disable cups.service 2>/dev/null
sudo systemctl disable cups-browsed.service 2>/dev/null
sudo systemctl disable geoclue.service 2>/dev/null
sudo systemctl disable power-profiles-daemon.service 2>/dev/null
sudo systemctl disable switcheroo-control.service 2>/dev/null


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
