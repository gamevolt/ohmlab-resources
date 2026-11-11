cat << 'TRIMMER' > /usr/bin/ohmlab-trim-background.sh
#!/bin/bash
echo "=== ohmlab Background Trimmer ==="
sync
# 3 = drop page caches + dentries + inodes (1 = page only, 2 = dentry/inode only)
echo 3 > /proc/sys/vm/drop_caches
echo "✔ Dropped page/dentry/inode caches"
echo 1 > /proc/sys/vm/compact_memory 2>/dev/null || true
echo "✔ Compacted memory"

# ─── Indexers & system daemons ───────────────────────────────────────────────
BACKGROUND_PROCS=(
    "tracker-miner" "tracker-store" "tracker3"
    "baloo_file" "baloo_file_extractor" "akonadi"
    "kdeconnectd" "zeitgeist"
    "tumblerd" "packagekitd" "apt-get" "dpkg"
    "updatedb" "mlocate" "snapd" "unattended-upgrade"
    "evolution" "gnome-software"
)
for proc in "${BACKGROUND_PROCS[@]}"; do
    /usr/lib/ohmlab/safe-signal STOP "$proc"
done
echo "✔ Paused background indexers"

for proc in baloo tracker zeitgeist; do
    for pid in $(pgrep -x "$proc" 2>/dev/null); do
        ionice -c 3 -p "$pid" 2>/dev/null || true
        renice +15 -p "$pid" 2>/dev/null || true
    done
done
echo "✔ IO-niced & re-niced indexers"

# ─── Memory-heavy user apps (best-effort) ────────────────────────────────────
# These are suspended by name pattern. They restart gracefully on resume.
# Deliberately empty. Freezing browsers/chat/Steam made them look like they
# "fail to open": relaunching a single-instance app hands off to the frozen
# copy. Memory is reclaimed by cgroup limits (cortex-helper) instead.
USER_BACKGROUND_APPS=()
for proc in "${USER_BACKGROUND_APPS[@]}"; do
    /usr/lib/ohmlab/safe-signal STOP "$proc"
done
echo "✔ Paused memory-heavy user apps"

if systemctl is-active snapd &>/dev/null; then
    systemctl stop snapd.service 2>/dev/null || true
    echo "✔ Stopped snapd"
fi

# kbuildsycoca6 --invalidate removed: deletes the sycoca cache so the final
# image ships with no cache, causing blank launcher categories on first login.
# Cache is rebuilt at session start by the ohmlab-sycoca-rebuild.service autostart.
balooctl6 suspend 2>/dev/null || balooctl suspend 2>/dev/null || true
echo "✔ Suspended Baloo indexer"

systemctl stop fstrim.service 2>/dev/null || true
echo 6000 > /proc/sys/vm/dirty_writeback_centisecs
echo "interactive" > /sys/kernel/debug/sched/tunable 2>/dev/null || true

echo ""
echo "=== Background trim complete. Start your game now. ==="
echo "Run 'ohmlab-restore-background.sh' after gaming to resume services."
TRIMMER
chmod +x /usr/bin/ohmlab-trim-background.sh
