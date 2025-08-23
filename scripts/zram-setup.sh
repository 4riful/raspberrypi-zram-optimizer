#!/usr/bin/env bash
# scripts/zram-setup.sh
# Production-ready, dynamic ZRAM setup for Raspberry Pi 3B+
# Features dynamic scaling: default 60% RAM, scales to 100% if memory pressure high
# Includes lightweight benchmarking and intelligent optimization
set -euo pipefail

# --- defaults (override via env) ---
: "${ZRAM_DEVICES:=1}"
: "${ZRAM_COMP_ALGO:=lz4}"
: "${ZRAM_RATIO_SMALL:=60}"   # <=1GiB RAM (Pi 3B+ default)
: "${ZRAM_RATIO_MEDIUM:=50}"  # 1-2GiB RAM
: "${ZRAM_RATIO_LARGE:=50}"   # >2GiB RAM
: "${ZRAM_PRIORITY:=100}"
: "${VM_SWAPPINESS:=100}"
: "${ZRAM_LOG:=/var/log/zram-setup.log}"
: "${ZRAM_BACKING_FILE:=}"    # optional backing file (not recommended on SD)

# Dynamic scaling thresholds
: "${MEMORY_LOW_THRESHOLD:=200}"      # MB available memory triggers 100% ZRAM
: "${MEMORY_SAFE_THRESHOLD:=400}"     # MB available memory to return to safe ratio
: "${SCALING_CHECK_INTERVAL:=15}"     # seconds between scaling checks
: "${ENABLE_DYNAMIC_SCALING:=true}"   # enable/disable dynamic scaling
: "${ENABLE_BENCHMARKING:=true}"      # enable lightweight performance benchmarking

# --- helpers ---
log() {
  local ts; ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "${ts} zram-setup: $*" | tee -a "$ZRAM_LOG"
  logger -t zram-setup "$*"
}

log_scaling() {
  local level="$1"; shift
  case "$level" in
    "INFO")  log "📊 $*" ;;
    "WARN")  log "⚠️  $*" ;;
    "ERROR") log "🚨 $*" ;;
    "SUCCESS") log "✅ $*" ;;
    *)       log "$*" ;;
  esac
}

usage() {
  cat <<-EOF
Usage: $(basename "$0") [start|stop|status|benchmark|scale]

start      Create and enable ZRAM devices with dynamic scaling (default)
stop       Disable and remove ZRAM swap
status     Print ZRAM and swap status
benchmark  Run lightweight performance benchmark
scale      Manually trigger scaling check and adjustment

Environment variables:
  ZRAM_DEVICES              Number of ZRAM devices (default: 1)
  ZRAM_COMP_ALGO           Compression algorithm (default: lz4)
  ZRAM_RATIO_SMALL         RAM percentage for <=1GiB (default: 60)
  ZRAM_RATIO_MEDIUM        RAM percentage for 1-2GiB (default: 50)
  ZRAM_RATIO_LARGE         RAM percentage for >2GiB (default: 50)
  ZRAM_PRIORITY            Swap priority (default: 100)
  VM_SWAPPINESS            Kernel swap aggressiveness (default: 100)
  ENABLE_DYNAMIC_SCALING   Enable dynamic scaling (default: true)
  ENABLE_BENCHMARKING      Enable benchmarking (default: true)
  MEMORY_LOW_THRESHOLD     MB available memory to trigger 100% ZRAM (default: 200)
  MEMORY_SAFE_THRESHOLD    MB available memory to return to safe ratio (default: 400)
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

# --- memory management ---
get_memory_info() {
  local mem_kib=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  local mem_mib=$(( mem_kib / 1024 ))
  local avail_mib=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  echo "$mem_kib $mem_mib $avail_mib"
}

get_optimal_ratio() {
  local mem_mib="$1"
  local avail_mib="$2"
  
  # Determine base ratio based on total RAM
  local base_ratio
  if (( mem_mib <= 1024 )); then
    base_ratio=$ZRAM_RATIO_SMALL
  elif (( mem_mib <= 2048 )); then
    base_ratio=$ZRAM_RATIO_MEDIUM
  else
    base_ratio=$ZRAM_RATIO_LARGE
  fi
  
  # Dynamic scaling based on available memory
  if [[ "$ENABLE_DYNAMIC_SCALING" == "true" ]]; then
    if (( avail_mib < MEMORY_LOW_THRESHOLD )); then
      echo "100"  # Emergency mode - use all available RAM
    elif (( avail_mib < MEMORY_SAFE_THRESHOLD )); then
      echo "$(( base_ratio + 20 ))"  # Moderate scaling
    else
      echo "$base_ratio"  # Safe default
    fi
  else
    echo "$base_ratio"  # Static configuration
  fi
}

# --- benchmarking ---
run_benchmark() {
  if [[ "$ENABLE_BENCHMARKING" != "true" ]]; then
    log_scaling "INFO" "Benchmarking disabled"
    return 0
  fi
  
  log_scaling "INFO" "Running lightweight ZRAM benchmark..."
  
  # Get current ZRAM stats
  local orig_size orig_used orig_comp
  if [[ -f /sys/block/zram0/disksize ]]; then
    orig_size=$(cat /sys/block/zram0/disksize)
    orig_used=$(cat /sys/block/zram0/mem_used_total)
    orig_comp=$(cat /sys/block/zram0/compr_data_size)
  fi
  
  # Simple compression test
  local test_data="/tmp/zram-benchmark-$$"
  local test_size=$(( 10 * 1024 * 1024 ))  # 10MB test
  
  # Create test data (repetitive for good compression)
  dd if=/dev/urandom bs=1M count=10 2>/dev/null | tr -d '\0' > "$test_data" 2>/dev/null || true
  
  # Measure compression time
  local start_time=$(date +%s%N)
  cat "$test_data" > /dev/zram0 2>/dev/null || true
  local end_time=$(date +%s%N)
  local compression_time=$(( (end_time - start_time) / 1000000 ))  # milliseconds
  
  # Get final stats
  local final_size final_used final_comp
  if [[ -f /sys/block/zram0/disksize ]]; then
    final_size=$(cat /sys/block/zram0/disksize)
    final_used=$(cat /sys/block/zram0/mem_used_total)
    final_comp=$(cat /sys/block/zram0/compr_data_size)
  fi
  
  # Calculate metrics
  local compression_ratio="N/A"
  if [[ -n "$final_comp" && "$final_comp" -gt 0 ]]; then
    compression_ratio=$(echo "scale=2; $test_size / $final_comp" | bc 2>/dev/null || echo "N/A")
  fi
  
  # Log benchmark results
  log_scaling "INFO" "Benchmark Results:"
  log_scaling "INFO" "  Compression Time: ${compression_time}ms"
  log_scaling "INFO" "  Compression Ratio: ${compression_ratio}:1"
  log_scaling "INFO" "  Memory Used: $(( final_used / 1024 / 1024 ))MB"
  
  # Cleanup
  rm -f "$test_data"
  
  # Store benchmark data for scaling decisions
  echo "$compression_time $compression_ratio" > /tmp/zram-benchmark-data 2>/dev/null || true
  
  log_scaling "SUCCESS" "Benchmark completed"
}

# --- ZRAM management ---
disable_zram() {
  log_scaling "INFO" "Disabling ZRAM devices..."
  
  # Turn off swap devices safely
  if swapon --show=NAME --noheadings | grep -q '^/dev/zram'; then
    while read -r dev; do
      log_scaling "INFO" "Swapping off $dev"
      swapoff "$dev" || log_scaling "WARN" "swapoff failed for $dev"
    done < <(swapon --show=NAME --noheadings | grep '^/dev/zram' || true)
  fi

  # Remove ZRAM module
  if lsmod | grep -q '^zram'; then
    if rmmod zram; then
      log_scaling "SUCCESS" "ZRAM module removed"
    else
      log_scaling "WARN" "Could not remove ZRAM module (in use or permissions)"
    fi
  else
    log_scaling "INFO" "ZRAM module not loaded"
  fi

  # Remove potential backing file (if user used file and wants it deleted)
  if [[ -n "$ZRAM_BACKING_FILE" && -f "$ZRAM_BACKING_FILE" ]]; then
    log_scaling "INFO" "Backing file exists at $ZRAM_BACKING_FILE (not automatically removed)"
  fi
}

setup_zram() {
  local ratio="$1"
  local mem_kib mem_mib avail_mib
  read -r mem_kib mem_mib avail_mib < <(get_memory_info)
  
  local total_mb=$(( mem_mib * ratio / 100 ))
  if (( total_mb < 32 )); then total_mb=32; fi  # Minimum 32MB
  local per_dev=$(( total_mb / ZRAM_DEVICES ))
  if (( per_dev < 1 )); then per_dev=1; fi

  log_scaling "INFO" "Setting up ZRAM: ${ratio}% RAM (~${total_mb}MB total, ${per_dev}MB per device)"
  
  # Disable existing ZRAM
  disable_zram

  # Load ZRAM module
  if ! modprobe zram num_devices="$ZRAM_DEVICES"; then
    log_scaling "ERROR" "Failed to load ZRAM module"
    return 1
  fi

  # Configure each device
  for (( i=0; i<ZRAM_DEVICES; i++ )); do
    local zdev="/sys/block/zram${i}"
    local devnode="/dev/zram${i}"

    # Wait for device
    local tries=0
    while [[ ! -d "$zdev" && $tries -lt 40 ]]; do
      sleep 0.05
      tries=$((tries+1))
    done
    if [[ ! -d "$zdev" ]]; then
      log_scaling "ERROR" "${zdev} not present after modprobe"
      return 1
    fi

    # Set compression algorithm
    local compfile="${zdev}/comp_algorithm"
    if [[ -w "$compfile" ]]; then
      echo "$ZRAM_COMP_ALGO" > "$compfile" || log_scaling "WARN" "Failed to write comp_algorithm"
    else
      log_scaling "WARN" "comp_algorithm file not writable for $zdev"
    fi

    # Set disksize (bytes)
    local size_bytes=$(( per_dev * 1024 * 1024 ))
    echo "$size_bytes" > "${zdev}/disksize"

    # Optional: setup backing file for writeback (disabled by default)
    if [[ -n "$ZRAM_BACKING_FILE" ]]; then
      # Create backing file if missing and properly sized
      if [[ ! -f "$ZRAM_BACKING_FILE" ]]; then
        log_scaling "INFO" "Creating backing file $ZRAM_BACKING_FILE of size ${per_dev}MB (sparse)"
        mkdir -p "$(dirname "$ZRAM_BACKING_FILE")"
        truncate -s "${per_dev}M" "$ZRAM_BACKING_FILE"
      fi
      # Attach backing file (writeback)
      if [[ -w "${zdev}/backing_dev" ]]; then
        # Find loop device for file (attach with losetup)
        local loopdev=$(losetup --show -f "$ZRAM_BACKING_FILE")
        if [[ -n "$loopdev" ]]; then
          echo "$(basename "$loopdev")" > "${zdev}/backing_dev" || log_scaling "WARN" "Failed to set backing_dev"
        fi
      else
        log_scaling "WARN" "Backing file set but backing_dev not writable on $zdev; skipping writeback"
      fi
    fi

    # Create swap and enable
    if ! mkswap -U clear "${devnode}"; then
      log_scaling "ERROR" "mkswap failed for ${devnode}"
      return 1
    fi

    if ! swapon --discard --priority "$ZRAM_PRIORITY" "${devnode}"; then
      log_scaling "ERROR" "swapon failed for ${devnode}"
      return 1
    fi
    log_scaling "SUCCESS" "Configured ${devnode}: disksize=${per_dev}MB priority=${ZRAM_PRIORITY}"
  done

  # Tune vm.swappiness at runtime
  if [[ -w /proc/sys/vm/swappiness ]]; then
    echo "$VM_SWAPPINESS" > /proc/sys/vm/swappiness || log_scaling "WARN" "Could not write vm.swappiness"
    log_scaling "INFO" "Set vm.swappiness=${VM_SWAPPINESS} (runtime)"
  else
    log_scaling "WARN" "/proc/sys/vm/swappiness not writable"
  fi
  
  log_scaling "SUCCESS" "ZRAM setup completed with ${ratio}% RAM allocation"
}

# --- scaling logic ---
check_and_scale() {
  local mem_kib mem_mib avail_mib
  read -r mem_kib mem_mib avail_mib < <(get_memory_info)
  
  local current_ratio=$(get_optimal_ratio "$mem_mib" "$avail_mib")
  local current_size
  
  # Get current ZRAM size
  if [[ -f /sys/block/zram0/disksize ]]; then
    current_size=$(cat /sys/block/zram0/disksize)
  else
    current_size=0
  fi
  
  # Calculate target size
  local target_size=$(( mem_mib * current_ratio / 100 * 1024 * 1024 ))
  
  # Check if scaling is needed
  if [[ $current_size -ne $target_size ]]; then
    local ratio_name
    case $current_ratio in
      100) ratio_name="EMERGENCY (100%)" ;;
      80)  ratio_name="HIGH (80%)" ;;
      60)  ratio_name="SAFE (60%)" ;;
      *)   ratio_name="$current_ratio%" ;;
    esac
    
    log_scaling "INFO" "Memory pressure detected: available ${avail_mib}MB, scaling ZRAM to ${ratio_name}"
    log_scaling "INFO" "Current: $(( current_size / 1024 / 1024 ))MB, Target: $(( target_size / 1024 / 1024 ))MB"
    
    if setup_zram "$current_ratio"; then
      log_scaling "SUCCESS" "ZRAM scaled successfully to ${current_ratio}%"
      
      # Run benchmark after scaling
      if [[ "$ENABLE_BENCHMARKING" == "true" ]]; then
        sleep 2  # Allow system to stabilize
        run_benchmark
      fi
    else
      log_scaling "ERROR" "Failed to scale ZRAM to ${current_ratio}%"
    fi
  else
    log_scaling "INFO" "No scaling needed: available ${avail_mib}MB, ZRAM at optimal size"
  fi
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

case "$ACTION" in
  "status")
    log_scaling "INFO" "ZRAM STATUS"
    lsmod | grep -E '^zram' || true
    command -v zramctl >/dev/null 2>&1 && zramctl || true
    swapon --show || true
    
    # Show memory info
    local mem_kib mem_mib avail_mib
    read -r mem_kib mem_mib avail_mib < <(get_memory_info)
    log_scaling "INFO" "Memory: ${mem_mib}MB total, ${avail_mib}MB available"
    
    # Show current ZRAM size
    if [[ -f /sys/block/zram0/disksize ]]; then
      local zram_size=$(cat /sys/block/zram0/disksize)
      local zram_mb=$(( zram_size / 1024 / 1024 ))
      local ratio=$(( zram_mb * 100 / mem_mib ))
      log_scaling "INFO" "ZRAM: ${zram_mb}MB (${ratio}% of RAM)"
    fi
    
    cleanup_and_exit 0
    ;;
    
  "stop")
    log_scaling "INFO" "Stopping ZRAM..."
    disable_zram
    cleanup_and_exit 0
    ;;
    
  "benchmark")
    run_benchmark
    cleanup_and_exit 0
    ;;
    
  "scale")
    log_scaling "INFO" "Manual scaling check triggered"
    check_and_scale
    cleanup_and_exit 0
    ;;
    
  "start")
    # Initial setup
    local mem_kib mem_mib avail_mib
    read -r mem_mib < <(get_memory_info | cut -d' ' -f2)
    local initial_ratio=$(get_optimal_ratio "$mem_mib" "$avail_mib")
    
    log_scaling "INFO" "Starting ZRAM setup with dynamic scaling..."
    log_scaling "INFO" "Initial allocation: ${initial_ratio}% of ${mem_mib}MB RAM"
    
    if ! setup_zram "$initial_ratio"; then
      log_scaling "ERROR" "Initial ZRAM setup failed"
      cleanup_and_exit 1
    fi
    
    # Run initial benchmark
    if [[ "$ENABLE_BENCHMARKING" == "true" ]]; then
      sleep 2  # Allow system to stabilize
      run_benchmark
    fi
    
    # Show summary
    log_scaling "SUCCESS" "ZRAM setup complete. Summary:"
    command -v zramctl >/dev/null 2>&1 && zramctl || true
    swapon --show || true
    
    # Dynamic scaling mode
    if [[ "$ENABLE_DYNAMIC_SCALING" == "true" ]]; then
      log_scaling "INFO" "Dynamic scaling enabled - monitoring memory pressure every ${SCALING_CHECK_INTERVAL}s"
      log_scaling "INFO" "Press Ctrl+C to stop monitoring and keep current ZRAM configuration"
      
      # Main monitoring loop
      while true; do
        check_and_scale
        sleep "$SCALING_CHECK_INTERVAL"
      done
    else
      log_scaling "INFO" "Dynamic scaling disabled - ZRAM configured statically"
    fi
    
    cleanup_and_exit 0
    ;;
    
  *)
    usage
    cleanup_and_exit 1
    ;;
esac
