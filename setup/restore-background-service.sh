#!/bin/bash
echo "=== Ohmlab: Restoring background services ==="
# ─── Indexers & system daemons ───────────────────────────────────────────────
for proc in tracker-miner tracker-store tracker3 baloo_file baloo_file_extractor \
            akonadi kded kdeconnectd gvfs zeitgeist tumblerd \
            packagekitd apt-get dpkg updatedb mlocate \
            evolution gnome-software; do
    pkill -CONT "$proc" 2>/dev/null || true
done
echo "✔ Resumed background indexers & daemons"

# ─── User apps ───────────────────────────────────────────────────────────────
for proc in firefox vesktop discord steam steamwebhelper \
            chromium chrome brave vivaldi edge opera \
            thunderbird evolution element signal slack \
            spotify telegram whatsie caprine; do
    pkill -CONT "$proc" 2>/dev/null || true
done
echo "✔ Resumed memory-heavy user apps"

# ─── IO priority reset ───────────────────────────────────────────────────────
for proc in baloo tracker zeitgeist; do
    for pid in $(pgrep -x "$proc" 2>/dev/null); do
        ionice -c 0 -p "$pid" 2>/dev/null || true
        renice 0 -p "$pid" 2>/dev/null || true
    done
done
echo "✔ Reset IO priority & niceness"

balooctl6 resume 2>/dev/null || balooctl resume 2>/dev/null || true
echo "✔ Resumed Baloo"
systemctl start snapd.service 2>/dev/null || true
systemctl start fstrim.service 2>/dev/null || true
echo 500 > /proc/sys/vm/dirty_writeback_centisecs
echo "=== Background services restored ==="
