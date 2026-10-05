# win11-dev VM — lag reduction steps

## One-time: VM config (host, VM powered off)

```bash
VBoxManage modifyvm win11-dev --cpus 4
VBoxManage modifyvm win11-dev --memory 16384
VBoxManage modifyvm win11-dev --large-pages on
VBoxManage modifyvm win11-dev --vm-process-priority high
# NIC interrupt coalescing (emulated 82540EM ships with Itr=disabled)
VBoxManage setextradata win11-dev VBoxInternal/Devices/e1000/0/Config/ItrEnabled 1
```

Verify after next boot:
```bash
grep -E "NumCPUs|RamSize|compiler threads|E1000#0: Chip" ~/.VirtualBox/Machines/win11-dev/Logs/VBox.log
```
Want: `NumCPUs = 4`, `RamSize = 16.0 GiB`, `Using 4 compiler threads`, `Itr=enabled`.

---

## One-time: inside Windows

**Ultimate Performance power plan** — stops vCPU parking/idling:
```bat
powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /getactivescheme
```

If the plan isn't present, unhide it first:
```bat
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
```

**Disable Windows Search indexing** (admin prompt):
```bat
sc stop WSearch
sc config WSearch start= disabled
sc qc WSearch
```
Note the space after `start=` — `sc` rejects `start=disabled`.

PowerShell equivalent:
```powershell
Stop-Service WSearch -Force
Set-Service WSearch -StartupType Disabled
Get-Service WSearch | Format-List Name,Status,StartType
```

GUI equivalent: `services.msc` → **Windows Search** → Stop → Startup type **Disabled**

---

## Every time: before starting the VM

Host must be on `performance` governor with deep C-states blocked
(`C3_ACPI` costs 1048 µs to exit; every vCPU wake-up pays it).

```bash
./vbox-lowlatency.sh on
```

Equivalent by hand:
```bash
for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance | sudo tee "$g" >/dev/null
done
sudo sh -c 'exec 3<>/dev/cpu_dma_latency; printf "\0\0\0\0" >&3; \
            echo $$ > /tmp/vbox-lowlatency.pid; while :; do sleep 3600; done' &
```

The `/dev/cpu_dma_latency` fd must stay **open** — closing it releases the block.

Restore when done:
```bash
./vbox-lowlatency.sh off
```

---

## Launch the VM

```bash
env -u DXVK_HDR -u DXVK_ENABLE_NVAPI \
    DXVK_CONFIG="dxvk.numCompilerThreads=4" \
    DXVK_STATE_CACHE_PATH="$HOME/.cache/vbox-dxvk" \
    VirtualBoxVM --startvm win11-dev
```

Save as `~/.local/bin/vbox-dev` and `chmod +x` it.

Do **not** put `DXVK_CONFIG` in `~/.config/plasma-workspace/env/` — that is
session-wide and would throttle shader compilation for Wine/Proton too.
`DXVK_HDR` / `DXVK_ENABLE_NVAPI` are unset here because your `wine.sh` and
`hdr.sh` export them globally and they leak into the VM.