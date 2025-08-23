#!/usr/bin/env bash
# scripts/zram-setup.sh
# Production-ready, idempotent zram setup script.
# Designed with Raspberry Pi 3B+ (1 GiB RAM) in mind, but configurable.
#
# Usage:
#   sudo ./zram-setup.sh [start|stop|status]
#
# Environment variables to override defaults:
#   ZRAM_DEVICES        (default 1)
#   ZRAM_COMP_ALGO      (default lz4)
#   ZRAM_RATIO_SMALL    (percent for <=1GiB RAM, default 60)
#   ZRAM_RATIO_MEDIUM   (percent for 1-2GiB RAM, default 50)
#   ZRAM_RATIO_LARGE    (percent for >2GiB RAM, default 50)
#   ZRAM_PRIORITY       (swapon priority, default 100)
#   VM_SWAPPINESS       (runtime vm.swappiness, default 100)
#   ZRAM_LOG            (log file, default /var/log/zram-setup.log)
#   ZRAM_BACKING_FILE   (optional, path to file for writeback; NOT recommended on SD card)
#
set -euo pipefail

# --- defaults (override via env) ---
: "${ZRAM_DEVICES:=1}"
: "${ZRAM_COMP_ALGO:=lz4}"
: "${ZRAM_RATIO_SMALL:=60}"
: "${ZRAM_RATIO_MEDIUM:=50}"
: "${ZRAM_RATIO_LARGE:=50}"
: "${ZRAM_PRIORITY:=100}"
: "${VM_SWAPPINESS:=100}"
: "${ZRAM_LOG:=/var/log/zram-setup.log}"
: "${ZRAM_BACKING_FILE:=}"   # empty = no backing file (writeback)

# --- helpers ---
log() {
  local ts; ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "${ts} zram-setup: $*" | tee -a "$ZRAM_LOG"
  logger -t zram-setup "$*"
}

usage() {
  cat <<-EOF
Usage: $(basename "$0") [start|stop|status]

start   Create and enable zram devices (default)
stop    Disable and remove zram swap
status  Print zram and swap status
EOF
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script requires root. Re-run with sudo." >&2
    exit 2
  fi
}

# prevent concurrent runs (simple lock)
LOCK="/var/lock/zram-setup.lock"
acquire_lock() {
  exec 9>"$LOCK"
  if ! flock -n 9; then
    echo "Another zram-setup process is running. Exiting." >&2
    exit 3
  fi
}

release_lock() {
  flock -u 9 || true
  rm -f "$LOCK" || true
}

# --- main actions ---
ACTION="${1:-start}"

require_root
mkdir -p "$(dirname "$ZRAM_LOG")" || true
acquire_lock

cleanup_and_exit() {
  release_lock
  exit "$1"
}

trap 'cleanup_and_exit $?' EXIT

if [[ "$ACTION" == "status" ]]; then
  log "STATUS"
  lsmod | grep -E '^zram' || true
  command -v zramctl >/dev/null 2>&1 && zramctl || true
  swapon --show || true
  cleanup_and_exit 0
fi

if [[ "$ACTION" == "stop" ]]; then
  log "Stopping zram swap (stop requested)..."
  # turn off swap devices safely
  if swapon --show=NAME --noheadings | grep -q '^/dev/zram'; then
    while read -r dev; do
      log "Swapping off $dev"
      swapoff "$dev" || log "Warning: swapoff failed for $dev"
    done < <(swapon --show=NAME --noheadings | grep '^/dev/zram' || true)
  fi

  # Remove any zram devices by removing module
  if lsmod | grep -q '^zram'; then
    if rmmod zram; then
      log "zram module removed"
    else
      log "Warning: could not remove zram module (in use or permissions)"
    fi
  else
    log "zram module not loaded"
  fi

  # remove potential backing file (if user used file and wants it deleted)
  if [[ -n "$ZRAM_BACKING_FILE" && -f "$ZRAM_BACKING_FILE" ]]; then
    log "Backing file exists at $ZRAM_BACKING_FILE (not automatically removed)"
  fi

  cleanup_and_exit 0
fi

# Default: start
if [[ "$ACTION" != "start" ]]; then
  usage
  cleanup_and_exit 1
fi

log "Starting zram setup..."

# Basic checks
if ! modprobe -v zram >/dev/null 2>&1; then
  log "ERROR: kernel zram module not available or modprobe failed"
  cleanup_and_exit 4
fi

# Read system RAM (KiB)
mem_kib=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [[ -z "$mem_kib" ]]; then
  log "ERROR: cannot determine MemTotal"
  cleanup_and_exit 5
fi
mem_mib=$(( mem_kib / 1024 ))

# Choose allocation ratio based on memory size
if (( mem_mib <= 1024 )); then
  ratio=$ZRAM_RATIO_SMALL
elif (( mem_mib <= 2048 )); then
  ratio=$ZRAM_RATIO_MEDIUM
else
  ratio=$ZRAM_RATIO_LARGE
fi

# compute sizes
zram_total_mib=$(( mem_mib * ratio / 100 ))
if (( zram_total_mib < 32 )); then zram_total_mib=32; fi
per_dev_mib=$(( zram_total_mib / ZRAM_DEVICES ))
if (( per_dev_mib < 1 )); then per_dev_mib=1; fi

log "Detected RAM: ${mem_mib}MiB. Allocating total ${zram_total_mib}MiB to zram (${per_dev_mib}MiB per device × ${ZRAM_DEVICES}). Algo=${ZRAM_COMP_ALGO}"

# Safely disable non-zram swaps (we keep zram logic controlled here)
log "Disabling all current swap devices..."
swapoff -a || log "Warning: swapoff -a returned non-zero"

# If zram module present, try to remove to start clean
if lsmod | grep -q '^zram'; then
  log "Existing zram module present; removing to reset"
  rmmod zram || log "Warning: rmmod zram failed (maybe in use)"
fi

# Load zram with device count
log "Loading zram module with ${ZRAM_DEVICES} device(s)"
if ! modprobe zram num_devices="$ZRAM_DEVICES"; then
  log "ERROR: modprobe zram failed"
  cleanup_and_exit 6
fi

# Configure each device
for (( i=0; i<ZRAM_DEVICES; i++ )); do
  zdev="/sys/block/zram${i}"
  devnode="/dev/zram${i}"

  # wait for device
  tries=0
  while [[ ! -d "$zdev" && $tries -lt 40 ]]; do
    sleep 0.05
    tries=$((tries+1))
  done
  if [[ ! -d "$zdev" ]]; then
    log "ERROR: ${zdev} not present after modprobe"
    cleanup_and_exit 7
  fi

  # set compression algorithm
  compfile="${zdev}/comp_algorithm"
  if [[ -w "$compfile" ]]; then
    echo "$ZRAM_COMP_ALGO" > "$compfile" || log "Warning: failed to write comp_algorithm"
  else
    log "Warning: comp_algorithm file not writable or missing for $zdev"
  fi

  # set disksize (bytes)
  size_bytes=$(( per_dev_mib * 1024 * 1024 ))
  echo "$size_bytes" > "${zdev}/disksize"

  # optional: setup backing file for writeback (disabled by default)
  if [[ -n "$ZRAM_BACKING_FILE" ]]; then
    # create backing file if missing and properly sized
    if [[ ! -f "$ZRAM_BACKING_FILE" ]]; then
      log "Creating backing file $ZRAM_BACKING_FILE of size ${per_dev_mib}MiB (sparse)"
      mkdir -p "$(dirname "$ZRAM_BACKING_FILE")"
      truncate -s "${per_dev_mib}M" "$ZRAM_BACKING_FILE"
    fi
    # attach backing file (writeback)
    if [[ -w "${zdev}/backing_dev" ]]; then
      # find loop device for file (attach with losetup)
      loopdev=$(losetup --show -f "$ZRAM_BACKING_FILE")
      if [[ -n "$loopdev" ]]; then
        echo "$(basename "$loopdev")" > "${zdev}/backing_dev" || log "Warning: failed to set backing_dev"
      fi
    else
      log "Backing file set but backing_dev not writable on $zdev; skipping writeback"
    fi
  fi

  # create swap and enable
  if ! mkswap -U clear "${devnode}"; then
    log "ERROR: mkswap failed for ${devnode}"
    cleanup_and_exit 8
  fi

  if ! swapon --discard --priority "$ZRAM_PRIORITY" "${devnode}"; then
    log "ERROR: swapon failed for ${devnode}"
    cleanup_and_exit 9
  fi
  log "Configured ${devnode}: disksize=${per_dev_mib}MiB priority=${ZRAM_PRIORITY}"
done

# Tune vm.swappiness at runtime (persist via sysctl.d recommended separately)
if [[ -w /proc/sys/vm/swappiness ]]; then
  echo "$VM_SWAPPINESS" > /proc/sys/vm/swappiness || log "Warning: could not write vm.swappiness"
  log "Set vm.swappiness=${VM_SWAPPINESS} (runtime)"
else
  log "Warning: /proc/sys/vm/swappiness not writable"
fi

log "zram setup complete. Summary:"
command -v zramctl >/dev/null 2>&1 && zramctl || true
swapon --show || true

# done — lock will be released by trap on exit
cleanup_and_exit 0
