#!/usr/bin/env bash
# Raspberry Pi ZRAM Setup
# Creates compressed swap in RAM to reduce SD card wear
set -euo pipefail

RATIO="${ZRAM_RATIO:-50}"
ALGO="${ZRAM_COMP_ALGO:-lz4}"
PRIORITY="${ZRAM_PRIORITY:-100}"
SWAPPINESS="${VM_SWAPPINESS:-100}"

log() { echo "zram: $*"; }
die() { echo "zram: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run with sudo"

get_ram_mb() {
    awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo
}

is_active() {
    swapon --show=NAME --noheadings 2>/dev/null | grep -q '^/dev/zram'
}

do_stop() {
    local dev
    while read -r dev; do
        swapoff "$dev" 2>/dev/null || true
    done < <(swapon --show=NAME --noheadings | grep '^/dev/zram' || true)
    rmmod zram 2>/dev/null || true
    log "stopped"
}

do_start() {
    is_active && { log "already active"; return 0; }

    local ram_mb size_mb
    ram_mb=$(get_ram_mb)
    size_mb=$(( ram_mb * RATIO / 100 ))
    (( size_mb >= 64 )) || size_mb=64

    log "setting up ${size_mb}MB from ${ram_mb}MB RAM (${RATIO}%)"

    modprobe zram num_devices=1 || die "modprobe failed"

    local tries=0
    while [[ ! -b /dev/zram0 ]] && (( tries < 50 )); do
        sleep 0.1; (( tries++ ))
    done
    [[ -b /dev/zram0 ]] || die "/dev/zram0 not found"

    echo "$ALGO" > /sys/block/zram0/comp_algorithm 2>/dev/null || true
    echo "$(( size_mb * 1024 * 1024 ))" > /sys/block/zram0/disksize

    mkswap -U clear /dev/zram0 >/dev/null
    swapon --discard --priority "$PRIORITY" /dev/zram0 || die "swapon failed"

    sysctl -w vm.swappiness="$SWAPPINESS" >/dev/null 2>&1 || true
    log "active: $(zramctl --noheadings /dev/zram0 2>/dev/null || echo 'ok')"
}

do_status() {
    echo "=== ZRAM ==="
    is_active && { zramctl; echo; swapon --show; echo; free -h; } || echo "not active"
}

case "${1:-start}" in
    start)  do_start ;;
    stop)   do_stop ;;
    status) do_status ;;
    *)      echo "Usage: $(basename "$0") [start|stop|status]"; exit 1 ;;
esac
