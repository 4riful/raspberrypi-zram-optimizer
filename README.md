# 🚀 Raspberry Pi ZRAM Optimizer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Raspberry Pi](https://img.shields.io/badge/Platform-Raspberry%20Pi-red.svg)](https://www.raspberrypi.org/)
[![Architecture: ARM](https://img.shields.io/badge/Architecture-ARM-blue.svg)](https://en.wikipedia.org/wiki/ARM_architecture)

> **Production-ready ZRAM optimization for Raspberry Pi devices**  
> Reduce SD card wear, improve performance, and optimize memory usage with compressed swap in RAM

---

## ✨ Features

- 🔧 **Automatic ZRAM Setup** - One-command installation and configuration
- 🎯 **Raspberry Pi Optimized** - Specifically tuned for Pi 3B+ (1 GiB RAM) and similar devices
- 🚀 **Performance Boost** - Compressed swap in RAM reduces I/O wait and improves responsiveness
- 💾 **SD Card Protection** - Eliminates swap-on-microSD to prevent premature wear
- 🧠 **Smart Memory Management** - Intelligent RAM sizing based on device capabilities
- 🔒 **Production Ready** - Idempotent scripts with proper error handling and logging
- ⚡ **Systemd Integration** - Automatic startup and management via systemd services

---

## 🎯 What is ZRAM?

**ZRAM** (formerly called compcache) is a Linux kernel feature that creates a compressed block device in RAM. It's perfect for:

- **Memory-constrained devices** like Raspberry Pi
- **Reducing storage I/O** by keeping swap in compressed RAM
- **Improving system responsiveness** during memory pressure
- **Extending SD card lifespan** by avoiding swap writes

---

## 📋 Requirements

| Component | Requirement | Notes |
|-----------|-------------|-------|
| **OS** | Linux with kernel ≥3.14 | ZRAM support included |
| **Architecture** | ARM (Raspberry Pi) | Optimized for ARM devices |
| **RAM** | ≥512 MiB | 1 GiB recommended |
| **Permissions** | Root access | Required for ZRAM setup |
| **Storage** | Any Linux filesystem | Avoid microSD for backing files |

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/raspberrypi-zram-optimizer.git
cd raspberrypi-zram-optimizer
```

### 2. Run the Setup Script

```bash
sudo ./scripts/zram-setup.sh
```

### 3. Verify Installation

```bash
# Check ZRAM status
zramctl

# View active swaps
swapon --show

# Monitor memory usage
free -h
```

---

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ZRAM_DEVICES` | `1` | Number of ZRAM devices to create |
| `ZRAM_COMP_ALGO` | `lz4` | Compression algorithm (lz4, lzo, zstd) |
| `ZRAM_RATIO_SMALL` | `60` | RAM percentage for ≤1 GiB devices |
| `ZRAM_RATIO_MEDIUM` | `50` | RAM percentage for 1-2 GiB devices |
| `ZRAM_RATIO_LARGE` | `50` | RAM percentage for >2 GiB devices |
| `ZRAM_PRIORITY` | `100` | Swap priority (higher = preferred) |
| `VM_SWAPPINESS` | `100` | Kernel swap aggressiveness |

### Custom Configuration Example

```bash
# Set custom ZRAM size (50% of RAM)
export ZRAM_RATIO_SMALL=50

# Use zstd compression (higher compression, more CPU)
export ZRAM_COMP_ALGO=zstd

# Run with custom settings
sudo ZRAM_RATIO_SMALL=50 ZRAM_COMP_ALGO=zstd ./scripts/zram-setup.sh
```

---

## 🔧 Advanced Setup

### Systemd Service Installation

```bash
# Copy service file
sudo cp systemd/zram-setup.service /etc/systemd/system/

# Copy script to system path
sudo cp scripts/zram-setup.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/zram-setup.sh

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable zram-setup.service
sudo systemctl start zram-setup.service
```

### Persistent Sysctl Settings

```bash
# Copy sysctl configuration
sudo cp config/sysctl.conf /etc/sysctl.d/99-zram.conf

# Apply settings
sudo sysctl --system
```

---

## 📊 Monitoring & Management

### Status Commands

```bash
# Check ZRAM status
sudo ./scripts/zram-setup.sh status

# View ZRAM devices
zramctl

# Monitor swap usage
swapon --show

# Memory overview
free -h
```

### Live Monitoring

```bash
# Watch ZRAM in real-time
watch -n1 zramctl

# Monitor system resources
htop

# Check CPU temperature (Raspberry Pi)
vcgencmd measure_temp
```

---

## 🧪 Testing & Validation

### Memory Stress Test

```bash
# Safe memory allocation test
python3 - <<'PY'
import time
a = bytearray(300*1024*1024)  # Allocate ~300MB
print("Memory allocated successfully")
time.sleep(20)
print("Test completed")
PY
```

### Performance Monitoring

```bash
# Monitor during stress test
watch -n1 'zramctl && echo "---" && free -h'
```

---

## 📚 Documentation

- **[Tuning Guide](docs/tuning-guide.md)** - Detailed configuration and optimization guide
- **[Systemd Integration](systemd/)** - Service files and system integration
- **[Configuration Examples](config/)** - Sample configuration files
- **[Scripts](scripts/)** - Installation and management scripts

---

## 🛠️ Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| **Permission denied** | Run with `sudo` |
| **ZRAM module not found** | Check kernel version ≥3.14 |
| **Swap not activating** | Verify script completed successfully |
| **High CPU usage** | Reduce ZRAM size or change compression algorithm |

### Logs and Debugging

```bash
# View setup logs
sudo tail -f /var/log/zram-setup.log

# Check systemd service status
sudo systemctl status zram-setup.service

# View kernel messages
dmesg | grep -i zram
```

---

## 🔒 Security Considerations

- **Root Access Required** - ZRAM setup requires privileged access
- **No Backing Files** - Avoid using microSD for ZRAM backing (default disabled)
- **System Integration** - Service runs at boot with appropriate permissions
- **Logging** - All operations are logged for audit purposes

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

```bash
# Clone with submodules
git clone --recursive https://github.com/yourusername/raspberrypi-zram-optimizer.git

# Install development dependencies
# (Add any development tools here)
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Linux Kernel Team** - For ZRAM implementation
- **Raspberry Pi Foundation** - For the amazing hardware platform
- **Open Source Community** - For inspiration and feedback

---

## 📞 Support

- **Issues** - [GitHub Issues](https://github.com/yourusername/raspberrypi-zram-optimizer/issues)
- **Discussions** - [GitHub Discussions](https://github.com/yourusername/raspberrypi-zram-optimizer/discussions)
- **Wiki** - [Project Wiki](https://github.com/yourusername/raspberrypi-zram-optimizer/wiki)

---

<div align="center">

**Made with ❤️ for the Raspberry Pi community**

[![Star on GitHub](https://img.shields.io/github/stars/yourusername/raspberrypi-zram-optimizer?style=social)](https://github.com/yourusername/raspberrypi-zram-optimizer)
[![Fork on GitHub](https://img.shields.io/github/forks/yourusername/raspberrypi-zram-optimizer?style=social)](https://github.com/yourusername/raspberrypi-zram-optimizer)

</div>
