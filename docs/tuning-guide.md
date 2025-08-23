# 🚀 Raspberry Pi ZRAM Optimizer — Tuning Guide

> **Master the art of ZRAM optimization for Raspberry Pi devices**  
> This comprehensive guide helps you configure, monitor, and fine-tune ZRAM for maximum performance and minimal resource usage.

---

## 🎯 Goals & Benefits

| Goal | Explanation | Impact |
|------|-------------|---------|
| ⚡ **Improve Performance** | ZRAM compresses swap in RAM, reducing I/O wait times | Faster system responsiveness |
| 💾 **Reduce SD Card Wear** | Avoid using microSD for swap operations | Extended storage lifespan |
| 🧠 **Efficient Memory Usage** | Optimal memory utilization while preventing OOM kills | Better resource management |
| 🌡 **Safe CPU Usage** | `lz4` compression balances CPU load and memory savings | Stable thermal performance |

---

## ⚙️ Recommended Defaults

| Setting | Value | Notes | Rationale |
|---------|-------|-------|-----------|
| **ZRAM Devices** | `1` | Default script configuration | Single device is sufficient for most use cases |
| **Compression Algorithm** | `lz4` | Fast & efficient for Pi 3B+ | Optimal balance of speed and compression ratio |
| **ZRAM Size** | 50–60% of RAM | 60% for ≤1 GiB RAM | Provides adequate swap without overwhelming system |
| **vm.swappiness** | `100` | Kernel swaps aggressively to ZRAM | Maximizes ZRAM utilization |
| **Swap Priority** | `100` | Ensures ZRAM is preferred over other swap | Prevents fallback to slower storage |

---

## 🔧 When to Adjust Settings

### 📈 Increase ZRAM Size If:

- **OOM Events** - You frequently encounter Out of Memory kills
- **Stable CPU Temperature** - CPU remains cool under normal load
- **High Memory Pressure** - System frequently hits memory limits
- **Performance Bottlenecks** - Storage I/O becomes a limiting factor

### 📉 Decrease ZRAM Size If:

- **CPU Throttling** - Temperature-based throttling occurs
- **System Unresponsiveness** - Heavy compression work impacts usability
- **Thermal Issues** - CPU temperature rises above safe thresholds
- **Performance Degradation** - Overall system performance decreases

> ⚠️ **Important:** Never set ZRAM size greater than available RAM. Monitor system stability when changing values.

---

## 📊 Monitoring & Commands

### 🔍 Basic Status Commands

```bash
# Check ZRAM devices & statistics
zramctl

# View active swap devices and priorities
swapon --show

# Memory overview and usage
free -h

# Detailed memory information
cat /proc/meminfo
```

### 📈 Live Monitoring

```bash
# Real-time ZRAM monitoring
watch -n1 zramctl

# Continuous memory monitoring
watch -n1 'free -h && echo "---" && swapon --show'

# CPU temperature monitoring (Raspberry Pi specific)
watch -n5 'vcgencmd measure_temp'
```

### 📋 System Health Check

```bash
# Comprehensive system status
echo "=== ZRAM Status ===" && zramctl
echo "=== Swap Status ===" && swapon --show
echo "=== Memory Status ===" && free -h
echo "=== CPU Temperature ===" && vcgencmd measure_temp
```

---

## 🧪 Stress Testing & Validation

### 🚀 Safe Memory Test

```bash
# Python-based memory allocation test (readable & quick)
python3 - <<'PY'
import time
import psutil

print("Starting memory stress test...")
print(f"Initial memory: {psutil.virtual_memory().percent:.1f}% used")

# Allocate ~300MB
a = bytearray(300*1024*1024)
print(f"After allocation: {psutil.virtual_memory().percent:.1f}% used")

# Hold for 20 seconds
print("Holding memory for 20 seconds...")
time.sleep(20)

print(f"Final memory: {psutil.virtual_memory().percent:.1f}% used")
print("Test completed successfully")
PY
```

### 📊 Performance Monitoring During Tests

```bash
# Monitor system resources during stress test
watch -n1 '
echo "=== ZRAM Status ==="
zramctl
echo ""
echo "=== Memory Usage ==="
free -h
echo ""
echo "=== CPU Temperature ==="
vcgencmd measure_temp
'
```

> ⚠️ **Warning:** Always monitor `zramctl` and CPU temperature while testing. Stop if system becomes unresponsive.

---

## 💾 Backing File & Writeback Configuration

### 🔄 Understanding Writeback

ZRAM can optionally **write evicted pages to a fast storage device** for additional memory management:

- **Benefits**: Allows ZRAM to exceed RAM size limits
- **Risks**: Can introduce storage bottlenecks and wear
- **Use Cases**: High-performance servers with fast storage

### ⚠️ Critical Warnings

| Storage Type | Recommendation | Reason |
|--------------|----------------|---------|
| **microSD Cards** | ❌ **Never Use** | Will wear out rapidly |
| **USB Flash Drives** | ❌ **Avoid** | Poor performance and reliability |
| **SSDs** | ✅ **Recommended** | Fast and reliable |
| **NVMe Drives** | ✅ **Excellent** | Best performance |

### 🔧 Enabling Writeback

```bash
# Only enable if you have reliable fast storage
export ZRAM_BACKING_FILE="/mnt/ssd/zram-backing"

# Run setup with backing file
sudo ZRAM_BACKING_FILE="/mnt/ssd/zram-backing" ./scripts/zram-setup.sh
```

---

## 🛠️ Logging & Troubleshooting

### 📝 Log Locations

| Log Type | Location | Purpose |
|----------|----------|---------|
| **Setup Log** | `/var/log/zram-setup.log` | Script execution details |
| **System Log** | `/var/log/syslog` | Kernel and system messages |
| **Systemd Journal** | `journalctl` | Service-specific logs |

### 🔍 Troubleshooting Commands

```bash
# View setup script logs
sudo tail -f /var/log/zram-setup.log

# Check systemd service status
sudo systemctl status zram-setup.service

# View recent kernel messages
dmesg | grep -i zram

# Check service logs
journalctl -u zram-setup.service -b
```

### 🚨 Common Issues & Solutions

| Problem | Symptoms | Solution |
|---------|----------|----------|
| **ZRAM Module Not Found** | `modprobe zram` fails | Check kernel version ≥3.14 |
| **Permission Denied** | Script exits with error 2 | Run with `sudo` |
| **Swap Not Activating** | `swapon --show` shows no ZRAM | Verify script completed successfully |
| **High CPU Usage** | System becomes unresponsive | Reduce ZRAM size or change algorithm |

---

## 🎛️ Advanced Tuning

### 🔧 Compression Algorithm Comparison

| Algorithm | Compression Ratio | CPU Usage | Memory Savings | Recommendation |
|-----------|-------------------|-----------|----------------|----------------|
| **lz4** | ~2.1:1 | Low | Good | ✅ **Default choice** |
| **lzo** | ~2.0:1 | Very Low | Good | ✅ **Low-power devices** |
| **zstd** | ~2.5:1 | Medium | Better | ⚠️ **Higher-end devices** |
| **deflate** | ~2.8:1 | High | Best | ❌ **Avoid on Pi** |

### 📊 Memory Ratio Optimization

| RAM Size | Recommended Ratio | Reasoning |
|----------|-------------------|-----------|
| **≤512 MiB** | 40-50% | Conservative approach for very limited RAM |
| **1 GiB** | 50-60% | Sweet spot for Pi 3B+ |
| **2-4 GiB** | 40-50% | More RAM available, less aggressive swap |
| **>4 GiB** | 30-40% | Plenty of RAM, minimal swap needed |

---

## 🔍 Final Recommendations

### 🚀 Getting Started

1. **Start Conservatively** - Use default settings initially
2. **Monitor for 24 Hours** - Observe under normal workload conditions
3. **Gradual Adjustments** - Make small changes and monitor impact
4. **Document Changes** - Keep track of what works for your specific use case

### 📈 Performance Optimization

- **Baseline Measurement** - Record performance metrics before changes
- **Incremental Testing** - Test one change at a time
- **Long-term Monitoring** - Watch for thermal and performance trends
- **Backup Configuration** - Save working configurations

### 🎯 Success Metrics

| Metric | Target | Monitoring Command |
|--------|--------|-------------------|
| **Memory Utilization** | 80-90% | `free -h` |
| **CPU Temperature** | <70°C | `vcgencmd measure_temp` |
| **System Responsiveness** | No lag | Subjective testing |
| **ZRAM Compression** | >2:1 ratio | `zramctl` |

> 🎉 **Pro Tip:** Using systemd auto-start ensures ZRAM is enabled immediately at boot without user intervention, providing seamless performance optimization.

---

## 📚 Additional Resources

- **[Main README](../README.md)** - Project overview and quick start
- **[Systemd Integration](../systemd/)** - Service configuration details
- **[Configuration Examples](../config/)** - Sample configuration files
- **[Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/admin-guide/blockdev/zram.html)** - Official ZRAM documentation

---

<div align="center">

**Happy optimizing! 🚀**

*This guide is designed to help you get the most out of your Raspberry Pi while maintaining system stability and longevity.*

</div>
