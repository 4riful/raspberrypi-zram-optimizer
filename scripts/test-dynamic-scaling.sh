#!/usr/bin/env bash
# scripts/test-dynamic-scaling.sh
# Test script to demonstrate ZRAM dynamic scaling
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 ZRAM Dynamic Scaling Test${NC}"
echo "=================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script requires root. Re-run with sudo.${NC}" >&2
    exit 1
fi

# Function to show current status
show_status() {
    echo -e "\n${GREEN}📊 Current Status:${NC}"
    echo "Memory:"
    free -h
    echo -e "\nZRAM:"
    zramctl
    echo -e "\nSwap:"
    swapon --show
    echo -e "\nTemperature:"
    vcgencmd measure_temp 2>/dev/null || echo "Temperature monitoring not available"
}

# Function to simulate memory pressure
simulate_memory_pressure() {
    local target_mb="$1"
    echo -e "\n${YELLOW}🔥 Simulating memory pressure: Allocating ${target_mb}MB...${NC}"
    
    # Create temporary files to consume memory
    local allocated=0
    local chunk_size=100  # 100MB chunks
    local temp_files=()
    
    while [[ $allocated -lt $target_mb ]]; do
        local chunk=$(( chunk_size < (target_mb - allocated) ? chunk_size : (target_mb - allocated) ))
        local temp_file="/tmp/memory-test-$$-${allocated}"
        
        echo "  Allocating ${chunk}MB chunk..."
        dd if=/dev/urandom bs=1M count=$chunk 2>/dev/null > "$temp_file"
        temp_files+=("$temp_file")
        allocated=$(( allocated + chunk ))
        
        # Show current memory status
        local current_avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
        echo "    Total allocated: ${allocated}MB, Available: ${current_avail}MB"
        
        if [[ $current_avail -lt 200 ]]; then
            echo -e "    ${RED}Memory pressure threshold reached!${NC}"
            break
        fi
        
        sleep 1
    done
    
    echo -e "\n${GREEN}✅ Memory pressure simulation complete${NC}"
    
    # Return the list of temp files for cleanup
    echo "${temp_files[@]}"
}

# Function to monitor ZRAM scaling
monitor_scaling() {
    local duration="$1"
    echo -e "\n${BLUE}👀 Monitoring ZRAM scaling for ${duration} seconds...${NC}"
    
    local start_time=$(date +%s)
    local end_time=$(( start_time + duration ))
    local mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local current_avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
        local zram_size=$(cat /sys/block/zram0/disksize 2>/dev/null || echo "0")
        local zram_mb=$(( zram_size / 1024 / 1024 ))
        local ratio=$(( zram_mb * 100 / mem_total ))
        local remaining=$(( end_time - $(date +%s) ))
        
        echo "  [${remaining}s] Available: ${current_avail}MB, ZRAM: ${zram_mb}MB (${ratio}%)"
        
        # Check if scaling occurred
        if [[ $ratio -gt 80 ]]; then
            echo -e "    ${GREEN}🎉 ZRAM successfully scaled to ${ratio}%!${NC}"
            break
        fi
        
        sleep 2
    done
}

# Main test sequence
echo -e "\n${BLUE}Step 1: Show initial status${NC}"
show_status

echo -e "\n${BLUE}Step 2: Start ZRAM with dynamic scaling${NC}"
echo "Starting ZRAM setup in background with dynamic scaling..."

# Start ZRAM setup in background with dynamic scaling enabled
(
    export ENABLE_DYNAMIC_SCALING=true
    export MEMORY_LOW_THRESHOLD=200
    export MEMORY_SAFE_THRESHOLD=400
    export SCALING_CHECK_INTERVAL=5
    export ENABLE_BENCHMARKING=false
    
    # Run the setup script
    ./zram-setup.sh start > /tmp/zram-setup.log 2>&1 &
    local pid=$!
    
    # Wait a bit for setup to complete
    sleep 10
    
    # Show status after setup
    echo -e "\n${GREEN}ZRAM setup completed. Status:${NC}"
    show_status
    
    # Keep the background process running
    wait $pid
) &

# Wait for ZRAM to be ready
echo "Waiting for ZRAM to be ready..."
sleep 15

echo -e "\n${BLUE}Step 3: Show status after ZRAM setup${NC}"
show_status

echo -e "\n${BLUE}Step 4: Simulate memory pressure${NC}"
# Simulate memory pressure by allocating memory
temp_files=$(simulate_memory_pressure 800)

echo -e "\n${BLUE}Step 5: Monitor ZRAM scaling${NC}"
# Monitor for scaling
monitor_scaling 60

echo -e "\n${BLUE}Step 6: Show final status${NC}"
show_status

echo -e "\n${BLUE}Step 7: Cleanup${NC}"
# Clean up temporary files
if [[ -n "$temp_files" ]]; then
    echo "Cleaning up temporary files..."
    for file in $temp_files; do
        rm -f "$file" 2>/dev/null || true
    done
fi

# Stop ZRAM
echo "Stopping ZRAM..."
./zram-setup.sh stop

echo -e "\n${GREEN}🎉 Dynamic scaling test completed!${NC}"
echo -e "${BLUE}Check /tmp/zram-setup.log for detailed ZRAM setup logs${NC}"
