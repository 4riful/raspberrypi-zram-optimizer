#!/usr/bin/env bash
# /usr/local/bin/zram-setup.sh
# idempotent zram setup for low-memory systems (Raspberry Pi 3B+ friendly)
set -euo pipefail

LOG=/var/log/zram-setup.log
exec 1>>"$LOG" 2>&1

echo "=== zram-setup.sh starting: $(date) ==="

# Defaults (can override with environment variables)
: "${ZRAM_DEVICES:=1}"               # number of /dev/zramN devices (default 1)
: "${ZRAM_PRIORITY:=100}"           # swapon priority
: "${ZRAM_COMP_ALGO:=lz4}"          # default compression algorithm
: "${ZRAM_RATIO_SMALL:=60}"         # percent of RAM to use on <=1GiB systems
: "${ZRAM_RATIO_MEDIUM:=50}"        # percent for 1-2GiB
: "${ZRAM_RATIO_LARGE:=50}"         # percent for >2GiB
: "${VM_SWAPPINESS:=100}"           # sensible default for zram (tune by workload)

# If called with 'stop' argument -> disable zram and exit
if [[ "${1:-}" == "stop" ]]; then
  echo "Stopping zram swap..."
  swapoff -a || true
  # try to clear zram devices
  if lsmod | grep -q '^zram'; then
    for dev in /dev/zram*; do
      [[ -b "$dev" ]] || continue
      swapoff "$dev" || true
    done
    rmmod zram || true
  fi
  echo "zram stopped at: $(date)"
  exit 0
fi

# Detect RAM (KiB)
mem_kib=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
mem_mib=$(( mem_kib / 1024 ))

# Choose default ratio based on RAM size (Pi 3B+ uses 1024 MiB)
if (( mem_mib <= 1024 )); then
  ratio=$ZRAM_RATIO_SMALL
elif (( mem_mib <= 2048 )); then
  ratio=$ZRAM_RATIO_MEDIUM
else
  ratio=$ZRAM_RATIO_LARGE
fi

# Compute total zram size (MiB) and per-device size
zram_total_mib=$(( mem_mib * ratio / 100 ))
if (( zram_total_mib < 32 )); then zram_total_mib=32; fi
per_dev_mib=$(( zram_total_mib / ZRAM_DEVICES ))
if (( per_dev_mib < 1 )); then per_dev_mib=1; fi

echo "System RAM: ${mem_mib} MiB; allocating total ${zram_total_mib} MiB to zram (${per_dev_mib} MiB per device, ${ZRAM_DEVICES} device(s)); algorithm=${ZRAM_COMP_ALGO}"

# Disable any existing swap (safer)
echo "Disabling existing swaps..."
swapoff -a || true

# Remove existing zram instances (if any)
if lsmod | grep -q '^zram'; then
  echo "Existing zram module present. Attempting clean removal..."
  for dev in /dev/zram*; do
    [[ -b "$dev" ]] || continue
    swapoff "$dev" || true
  done
  rmmod zram || true
fi

# Load zram module with requested device count
echo "Loading zram kernel module (num_devices=${ZRAM_DEVICES})..."
modprobe zram num_devices="$ZRAM_DEVICES"

# Confirm device exist; configure each
device=0
while (( device < ZRAM_DEVICES )); do
  zdev="/sys/block/zram${device}"
  devnode="/dev/zram${device}"

  # Wait briefly for device node to appear
  for i in {1..10}; do
    [[ -e "$zdev" ]] && break
    sleep 0.05
  done

  if [[ ! -d "$zdev" ]]; then
    echo "ERROR: $zdev not present after modprobe; aborting."
    exit 1
  fi

  # set comp algorithm if available
  compfile="${zdev}/comp_algorithm"
  if [[ -w "$compfile" ]]; then
    echo "$ZRAM_COMP_ALGO" > "$compfile" || true
  else
    echo "Warning: cannot set comp_algorithm on ${zdev}"
  fi

  # set disksize in bytes
  size_bytes=$(( per_dev_mib * 1024 * 1024 ))
  echo "$size_bytes" > "${zdev}/disksize"

  # initialize swap area and enable
  mkswap -U clear "${devnode}"
  swapon --discard --priority "$ZRAM_PRIORITY" "${devnode}"

  echo "Configured ${devnode}: disksize=${per_dev_mib}MiB priority=${ZRAM_PRIORITY}"
  device=$(( device + 1 ))
done

# Tune swappiness (temporary; also recommend persistent sysctl file)
if [[ -w /proc/sys/vm/swappiness ]]; then
  echo "$VM_SWAPPINESS" > /proc/sys/vm/swappiness
  echo "Set vm.swappiness=${VM_SWAPPINESS} (runtime)"
fi

echo "zram setup finished at: $(date)"
