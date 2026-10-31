```tmpfs Quota Fix (/tmp + /dev/shm)
systemd 256+ mounts /tmp and /dev/shm with an automatic per-user quota (~12 GB on 30 GB RAM). Heavy temp use (Chrome, large extractions) hits it and fails with "Disk quota exceeded" long before the tmpfs is full. Pointless on a single-user box.

# /tmp — drop-in removes usrquota (keeps nosuid/nodev/size)
sudo mkdir -p /etc/systemd/system/tmp.mount.d
sudo cp system/tmp-mount-override.conf /etc/systemd/system/tmp.mount.d/override.conf

# /dev/shm — mounted before any unit exists, and remount cannot drop tmpfs quota.
# The limit is (re)applied by systemd-user-runtime-dir at every login, so clear it
# right after, from the unit that sets it.
sudo mkdir -p /etc/systemd/system/user-runtime-dir@.service.d
sudo cp system/user-runtime-dir-noquota.conf \
        /etc/systemd/system/user-runtime-dir@.service.d/noquota.conf
sudo systemctl daemon-reload
/tmp takes effect on reboot; /dev/shm from the next login. An /etc/fstab entry for /dev/shm does not work — verified live, the quota survives it.```
