#!/usr/bin/env bash
# scripts/zram-benchmark.sh
# Comprehensive ZRAM benchmarking script for Raspberry Pi
# Tests compression performance, memory efficiency, and dynamic scaling
set -euo pipefail

# --- configuration ---
: "${BENCHMARK_LOG:=/var/log/zram-benchmark.log}"
: "${TEST_DATA_SIZE:=100}"         # MB of test data
: "${COMPRESSION_ITERATIONS:=3}"   # Number of compression test iterations
: "${MEMORY_PRESSURE_TEST:=true}" # Enable memory pressure simulation
: "${SHOW_GRAPHS:=true}"          # Show ASCII graphs of results

# --- colors and formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- helpers ---
log() {
  local ts; ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo -e "${ts} ${GREEN}[BENCHMARK]${NC} $*" | tee -a "$BENCHMARK_LOG"
}

log_section() {
  echo -e "\n${BLUE}=== $* ===${NC}"
  log "$*"
}

log_result() {
  echo -e "${CYAN}📊 $*${NC}"
  log "$*"
}

log_success() {
  echo -e "${GREEN}✅ $*${NC}"
  log "$*"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $*${NC}"
  log "$*"
}

log_error() {
  echo -e "${RED}🚨 $*${NC}"
  log "$*"
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script requires root. Re-run with sudo.${NC}" >&2
    exit 2
  fi
}

# --- system information ---
get_system_info() {
  log_section "System Information"
  
  # Hardware info
  local model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Unknown")
  local cpu=$(grep "Model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
  local cores=$(nproc)
  local mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  local mem_available=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  
  log_result "Device: $model"
  log_result "CPU: $cpu"
  log_result "Cores: $cores"
  log_result "Total RAM: ${mem_total}MB"
  log_result "Available RAM: ${mem_available}MB"
  
  # Kernel info
  local kernel=$(uname -r)
  local zram_module=$(lsmod | grep -c '^zram' || echo "0")
  
  log_result "Kernel: $kernel"
  log_result "ZRAM Module: $zram_module device(s)"
  
  # Temperature (Raspberry Pi specific)
  if command -v vcgencmd >/dev/null 2>&1; then
    local temp=$(vcgencmd measure_temp | cut -d= -f2)
    log_result "CPU Temperature: $temp"
  fi
}

# --- ZRAM status check ---
check_zram_status() {
  log_section "ZRAM Status Check"
  
  if ! lsmod | grep -q '^zram'; then
    log_error "ZRAM module not loaded!"
    return 1
  fi
  
  # Check ZRAM devices
  if command -v zramctl >/dev/null 2>&1; then
    log_result "ZRAM Devices:"
    zramctl | while read -r line; do
      log_result "  $line"
    done
  fi
  
  # Check swap status
  log_result "Swap Status:"
  swapon --show | while read -r line; do
    log_result "  $line"
  done
  
  # Check ZRAM sysfs info
  if [[ -f /sys/block/zram0/disksize ]]; then
    local disksize=$(cat /sys/block/zram0/disksize)
    local mem_used=$(cat /sys/block/zram0/mem_used_total 2>/dev/null || echo "0")
    local compr_data=$(cat /sys/block/zram0/compr_data_size 2>/dev/null || echo "0")
    local orig_data=$(cat /sys/block/zram0/orig_data_size 2>/dev/null || echo "0")
    
    log_result "ZRAM0 Details:"
    log_result "  Disk Size: $(( disksize / 1024 / 1024 ))MB"
    log_result "  Memory Used: $(( mem_used / 1024 / 1024 ))MB"
    log_result "  Compressed Data: $(( compr_data / 1024 / 1024 ))MB"
    log_result "  Original Data: $(( orig_data / 1024 / 1024 ))MB"
    
    # Calculate compression ratio
    if [[ "$orig_data" -gt 0 && "$compr_data" -gt 0 ]]; then
      local ratio=$(echo "scale=2; $orig_data / $compr_data" | bc 2>/dev/null || echo "N/A")
      log_result "  Compression Ratio: ${ratio}:1"
    fi
  fi
}

# --- compression performance test ---
test_compression_performance() {
  log_section "Compression Performance Test"
  
  local test_data="/tmp/zram-benchmark-$$"
  local test_size_mb=$TEST_DATA_SIZE
  local test_size_bytes=$(( test_size_mb * 1024 * 1024 ))
  
  log_result "Creating ${test_size_mb}MB test data..."
  
  # Create test data with different patterns for realistic compression
  local patterns=("random" "zeros" "repeating" "mixed")
  
  for pattern in "${patterns[@]}"; do
    log_result "Testing pattern: $pattern"
    
    case "$pattern" in
      "random")
        dd if=/dev/urandom bs=1M count=$test_size_mb 2>/dev/null > "$test_data"
        ;;
      "zeros")
        dd if=/dev/zero bs=1M count=$test_size_mb 2>/dev/null > "$test_data"
        ;;
      "repeating")
        # Create repeating pattern for good compression
        yes "RASPBERRY_PI_ZRAM_OPTIMIZER_TEST_DATA_$(date +%s)" | head -c $test_size_bytes > "$test_data"
        ;;
      "mixed")
        # Mix of patterns
        dd if=/dev/urandom bs=1M count=$(( test_size_mb / 2 )) 2>/dev/null > "$test_data"
        dd if=/dev/zero bs=1M count=$(( test_size_mb / 2 )) 2>/dev/null >> "$test_data"
        ;;
    esac
    
    # Get initial ZRAM stats
    local orig_mem_used=$(cat /sys/block/zram0/mem_used_total 2>/dev/null || echo "0")
    local orig_compr_data=$(cat /sys/block/zram0/compr_data_size 2>/dev/null || echo "0")
    
    # Measure compression time
    local start_time=$(date +%s%N)
    cat "$test_data" > /dev/zram0 2>/dev/null || true
    local end_time=$(date +%s%N)
    local compression_time=$(( (end_time - start_time) / 1000000 )) # milliseconds
    
    # Get final stats
    local final_mem_used=$(cat /sys/block/zram0/mem_used_total 2>/dev/null || echo "0")
    local final_compr_data=$(cat /sys/block/zram0/compr_data_size 2>/dev/null || echo "0")
    
    # Calculate metrics
    local mem_increase=$(( final_mem_used - orig_mem_used ))
    local compr_increase=$(( final_compr_data - orig_compr_data ))
    local compression_ratio="N/A"
    
    if [[ "$compr_increase" -gt 0 ]]; then
      compression_ratio=$(echo "scale=2; $test_size_bytes / $compr_increase" | bc 2>/dev/null || echo "N/A")
    fi
    
    local throughput=$(echo "scale=2; $test_size_mb / ($compression_time / 1000)" | bc 2>/dev/null || echo "N/A")
    
    log_result "  Compression Time: ${compression_time}ms"
    log_result "  Compression Ratio: ${compression_ratio}:1"
    log_result "  Memory Increase: $(( mem_increase / 1024 / 1024 ))MB"
    log_result "  Throughput: ${throughput}MB/s"
    
    # Clean up test data
    rm -f "$test_data"
    
    # Small delay between tests
    sleep 1
  done
}

# --- memory pressure simulation ---
simulate_memory_pressure() {
  if [[ "$MEMORY_PRESSURE_TEST" != "true" ]]; then
    log_warning "Memory pressure test disabled"
    return 0
  fi
  
  log_section "Memory Pressure Simulation"
  
  local mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  local target_usage=$(( mem_total * 80 / 100 )) # Target 80% memory usage
  local current_usage=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  current_usage=$(( current_usage - $(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo) ))
  
  log_result "Current memory usage: ${current_usage}MB"
  log_result "Target memory usage: ${target_usage}MB"
  
  if [[ $current_usage -gt $target_usage ]]; then
    log_result "Memory usage already above target, skipping simulation"
    return 0
  fi
  
  local needed_mb=$(( target_usage - current_usage ))
  local test_data="/tmp/memory-pressure-$$"
  
  log_result "Allocating ${needed_mb}MB to simulate memory pressure..."
  
  # Allocate memory in chunks to avoid overwhelming the system
  local chunk_size=50 # 50MB chunks
  local allocated=0
  
  while [[ $allocated -lt $needed_mb ]]; do
    local chunk=$(( chunk_size < (needed_mb - allocated) ? chunk_size : (needed_mb - allocated) ))
    dd if=/dev/urandom bs=1M count=$chunk 2>/dev/null > "${test_data}.${allocated}" 2>/dev/null || break
    allocated=$(( allocated + chunk ))
    
    # Check current memory usage
    local current_avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
    log_result "  Allocated: ${allocated}MB, Available: ${current_avail}MB"
    
    if [[ $current_avail -lt 200 ]]; then
      log_warning "Memory pressure threshold reached (${current_avail}MB available)"
      break
    fi
    
    sleep 0.5
  done
  
  # Monitor ZRAM scaling
  log_result "Monitoring ZRAM scaling for 30 seconds..."
  local start_time=$(date +%s)
  local end_time=$(( start_time + 30 ))
  
  while [[ $(date +%s) -lt $end_time ]]; do
    local current_avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
    local zram_size=$(cat /sys/block/zram0/disksize 2>/dev/null || echo "0")
    local zram_mb=$(( zram_size / 1024 / 1024 ))
    local ratio=$(( zram_mb * 100 / mem_total ))
    
    log_result "  Time: $(( end_time - $(date +%s) ))s, Available: ${current_avail}MB, ZRAM: ${zram_mb}MB (${ratio}%)"
    
    if [[ $ratio -gt 80 ]]; then
      log_success "ZRAM successfully scaled to ${ratio}% of RAM!"
      break
    fi
    
    sleep 2
  done
  
  # Cleanup
  log_result "Cleaning up memory pressure test data..."
  rm -f "${test_data}".*
  
  # Wait for system to stabilize
  sleep 5
  
  # Check final ZRAM status
  local final_zram_size=$(cat /sys/block/zram0/disksize 2>/dev/null || echo "0")
  local final_zram_mb=$(( final_zram_size / 1024 / 1024 ))
  local final_ratio=$(( final_zram_mb * 100 / mem_total ))
  
  log_result "Final ZRAM size: ${final_zram_mb}MB (${final_ratio}% of RAM)"
  
  if [[ $final_ratio -gt 60 ]]; then
    log_success "Dynamic scaling test PASSED - ZRAM scaled appropriately"
  else
    log_warning "Dynamic scaling test may have failed - ZRAM remained at ${final_ratio}%"
  fi
}

# --- performance comparison ---
compare_performance() {
  log_section "Performance Comparison"
  
  # Get current ZRAM stats
  local zram_mem_used=$(cat /sys/block/zram0/mem_used_total 2>/dev/null || echo "0")
  local zram_compr_data=$(cat /sys/block/zram0/compr_data_size 2>/dev/null || echo "0")
  local zram_orig_data=$(cat /sys/block/zram0/orig_data_size 2>/dev/null || echo "0")
  
  # Calculate efficiency metrics
  local compression_ratio="N/A"
  if [[ "$zram_compr_data" -gt 0 ]]; then
    compression_ratio=$(echo "scale=2; $zram_orig_data / $zram_compr_data" | bc 2>/dev/null || echo "N/A")
  fi
  
  local memory_efficiency="N/A"
  if [[ "$zram_orig_data" -gt 0 ]]; then
    memory_efficiency=$(echo "scale=2; $zram_mem_used / $zram_orig_data * 100" | bc 2>/dev/null || echo "N/A")
  fi
  
  log_result "Current ZRAM Performance:"
  log_result "  Compression Ratio: ${compression_ratio}:1"
  log_result "  Memory Efficiency: ${memory_efficiency}%"
  log_result "  Total Memory Used: $(( zram_mem_used / 1024 / 1024 ))MB"
  
  # Show ASCII performance graph
  if [[ "$SHOW_GRAPHS" == "true" ]]; then
    echo -e "\n${PURPLE}📈 Performance Graph:${NC}"
    echo "Memory Usage: [$(printf '%*s' $(( zram_mem_used / 1024 / 1024 / 10 )) '' | tr ' ' '#')] $(( zram_mem_used / 1024 / 1024 ))MB"
    echo "Compression:  [$(printf '%*s' $(( zram_compr_data / 1024 / 1024 / 10 )) '' | tr ' ' '#')] $(( zram_compr_data / 1024 / 1024 ))MB"
  fi
}

# --- system health check ---
check_system_health() {
  log_section "System Health Check"
  
  # Memory status
  local mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  local mem_available=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  local mem_used=$(( mem_total - mem_available ))
  local mem_usage_percent=$(( mem_used * 100 / mem_total ))
  
  log_result "Memory Usage: ${mem_used}MB / ${mem_total}MB (${mem_usage_percent}%)"
  
  # ZRAM utilization
  local zram_size=$(cat /sys/block/zram0/disksize 2>/dev/null || echo "0")
  local zram_mb=$(( zram_size / 1024 / 1024 ))
  local zram_ratio=$(( zram_mb * 100 / mem_total ))
  
  log_result "ZRAM Allocation: ${zram_mb}MB (${zram_ratio}% of RAM)"
  
  # Temperature check (Raspberry Pi specific)
  if command -v vcgencmd >/dev/null 2>&1; then
    local temp=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
    local temp_num=$(echo "$temp" | cut -d. -f1)
    
    if [[ $temp_num -lt 70 ]]; then
      log_success "CPU Temperature: ${temp}°C (Normal)"
    elif [[ $temp_num -lt 80 ]]; then
      log_warning "CPU Temperature: ${temp}°C (Warm)"
    else
      log_error "CPU Temperature: ${temp}°C (Hot - Consider reducing ZRAM size)"
    fi
  fi
  
  # Load average
  local load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
  log_result "Load Average: $load_avg"
  
  # Overall health assessment
  local health_score=100
  
  if [[ $mem_usage_percent -gt 90 ]]; then
    health_score=$(( health_score - 20 ))
    log_warning "High memory usage detected"
  fi
  
  if [[ $zram_ratio -gt 80 ]]; then
    health_score=$(( health_score - 10 ))
    log_warning "ZRAM using high percentage of RAM"
  fi
  
  if [[ $temp_num -gt 75 ]]; then
    health_score=$(( health_score - 15 ))
    log_warning "High CPU temperature detected"
  fi
  
  if [[ $health_score -gt 80 ]]; then
    log_success "System Health: EXCELLENT (${health_score}/100)"
  elif [[ $health_score -gt 60 ]]; then
    log_warning "System Health: GOOD (${health_score}/100)"
  else
    log_error "System Health: POOR (${health_score}/100) - Consider adjustments"
  fi
}

# --- main execution ---
main() {
  local start_time=$(date +%s)
  
  log_section "ZRAM Benchmark Suite Started"
  log_result "Benchmark started at: $(date)"
  
  # Check prerequisites
  require_root
  
  # Create log directory
  mkdir -p "$(dirname "$BENCHMARK_LOG")" || true
  
  # Run all tests
  get_system_info
  check_zram_status
  test_compression_performance
  simulate_memory_pressure
  compare_performance
  check_system_health
  
  local end_time=$(date +%s)
  local duration=$(( end_time - start_time ))
  
  log_section "Benchmark Summary"
  log_result "Total duration: ${duration} seconds"
  log_result "All tests completed successfully!"
  log_result "Check $BENCHMARK_LOG for detailed results"
  
  echo -e "\n${GREEN}🎉 Benchmark completed successfully!${NC}"
  echo -e "${BLUE}📊 Results saved to: $BENCHMARK_LOG${NC}"
}

# --- script execution ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
