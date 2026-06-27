# 🚀 Raspberry Pi ZRAM Optimizer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Raspberry Pi](https://img.shields.io/badge/Platform-Raspberry%20Pi-red.svg)](https://www.raspberrypi.org/)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Architecture: ARM](https://img.shields.io/badge/Architecture-ARM-blue.svg)](https://en.wikipedia.org/wiki/ARM_architecture)

> **Production-ready ZRAM optimization for Raspberry Pi devices**
> Reduce SD card wear, improve performance, and optimize memory usage with compressed swap in RAM

---

## 📖 Table of Contents

- [✨ Features](#-features)
- [🎯 What is ZRAM?](#-what-is-zram)
- [📋 Requirements](#-requirements)
- [🚀 Quick Start](#-quick-start)
- [⚙️ Configuration](#️-configuration)
- [🔧 Commands](#-commands)
- [📊 Monitoring](#-monitoring)
- [🛠️ Troubleshooting](#️-troubleshooting)
- [📁 Project Structure](#-project-structure)
- [📄 License](#-license)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔧 **One-Command Setup** | Install and configure ZRAM with a single command — no complex configuration needed |
| 💾 **SD Card Protection** | Eliminates swap-on-microSD to prevent premature wear and extend device lifespan |
| 🚀 **Performance Boost** | Compressed swap in RAM reduces I/O wait and improves system responsiveness |
| 🎯 **Raspberry Pi Optimized** | Specifically tuned for Pi devices with 512MB+ RAM (3B+, 4, 5, Zero 2 W) |
| 🔒 **Production Ready** | Idempotent scripts with clean error handling — safe to run multiple times |
| ⚡ **Systemd Integration** | Automatic startup and management via systemd services |
| 🧩 **Minimal Dependencies** | Uses only core Linux utilities — no extra packages required |

---

## 🎯 What is ZRAM?

**ZRAM** (formerly compcache) is a Linux kernel feature that creates a compressed block device in RAM. Instead of writing swap data to your SD card (which causes wear and is slow), ZRAM keeps everything in compressed memory.

### 💡 Why Use ZRAM?

| Problem | Solution |
|---------|----------|
| **SD Card Wear** | Swap writes to SD cards reduce their lifespan. ZRAM eliminates this. |
| **Slow Swap** | SD card swap is ~100x slower than RAM. ZRAM compression is ~10x faster. |
| **Memory Pressure** | When RAM runs low, the system slows down. ZRAM provides extra virtual memory. |
| **System Stability** | Under heavy load, systems without swap can crash. ZRAM prevents this. |

### 📈 How It Works

```
┌─────────────────────────────────────────────────┐
│                  Raspberry Pi                    │
│                                                  │
│  ┌─────────────┐     ┌─────────────────────┐    │
│  │  Physical   │     │    ZRAM Device       │    │
│  │    RAM      │     │  (Compressed Swap)   │    │
│  │             │     │                      │    │
│  │  1GB Total  │     │  ~500MB Compressed   │    │
│  │             │     │  ~1.5GB Effective    │    │
│  └─────────────┘     └─────────────────────┘    │
│         │                    │                   │
│         └────────┬───────────┘                   │
│                  │                               │
│            ┌─────▼─────┐                        │
│            │  Kernel   │                        │
│            │  Memory   │                        │
│            │ Manager   │                        │
│            └───────────┘                        │
└─────────────────────────────────────────────────┘
```

---

## 📋 Requirements

| Component | Requirement | Notes |
|-----------|-------------|-------|
| 💻 **Operating System** | Linux with kernel ≥3.14 | ZRAM support included in modern kernels |
| 🏗️ **Architecture** | ARM (Raspberry Pi) | Optimized for ARM devices |
| 🧠 **RAM** | ≥512 MiB | 1 GiB or more recommended |
| 🔐 **Permissions** | Root access | Required for ZRAM setup (`sudo`) |
| 💾 **Storage** | Any Linux filesystem | microSD, USB drive, or NVMe |

### 🎮 Tested Devices

| Device | RAM | Status |
|--------|-----|--------|
| Raspberry Pi 3B+ | 1 GiB | ✅ Fully supported |
| Raspberry Pi 4 | 2-8 GiB | ✅ Fully supported |
| Raspberry Pi 5 | 4-8 GiB | ✅ Fully supported |
| Raspberry Pi Zero 2 W | 512 MiB | ✅ Fully supported |
| Raspberry Pi 3B | 1 GiB | ✅ Fully supported |

---

## 🚀 Quick Start

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/4riful/raspberrypi-zram-optimizer.git
cd raspberrypi-zram-optimizer
```

### 2️⃣ Run the Setup Script

```bash
sudo ./scripts/zram-setup.sh start
```

### 3️⃣ Verify Installation

```bash
# Check ZRAM devices
zramctl

# View active swaps
swapon --show

# Memory overview
free -h
```

### 4️⃣ Enable Auto-start at Boot (Optional)

```bash
# Copy script to system path
sudo cp scripts/zram-setup.sh /usr/local/bin/zram-setup.sh
sudo chmod +x /usr/local/bin/zram-setup.sh

# Copy and enable systemd service
sudo cp systemd/zram-setup.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable zram-setup.service
```

---

## ⚙️ Configuration

All settings are optional. The defaults work well for most Raspberry Pi models.

### 🔧 Environment Variables

| Variable | Default | Description | Options |
|----------|---------|-------------|---------|
| `ZRAM_RATIO` | `50` | Percentage of RAM to use as ZRAM | `25`-`100` |
| `ZRAM_COMP_ALGO` | `lz4` | Compression algorithm | `lz4`, `lzo`, `zstd` |
| `ZRAM_PRIORITY` | `100` | Swap priority (higher = preferred) | `0`-`32767` |
| `VM_SWAPPINESS` | `100` | Kernel swap aggressiveness | `0`-`100` |

### 💡 Usage Examples

```bash
# Default setup (50% of RAM)
sudo ./scripts/zram-setup.sh start

# Use 60% of RAM for ZRAM
sudo ZRAM_RATIO=60 ./scripts/zram-setup.sh start

# Use zstd compression (higher ratio, more CPU)
sudo ZRAM_COMP_ALGO=zstd ./scripts/zram-setup.sh start

# Conservative setup (25% of RAM)
sudo ZRAM_RATIO=25 ./scripts/zram-setup.sh start

# Aggressive setup (75% of RAM)
sudo ZRAM_RATIO=75 ./scripts/zram-setup.sh start
```

### 🎚️ Compression Algorithms

| Algorithm | Speed | Compression Ratio | CPU Usage | Best For |
|-----------|-------|-------------------|-----------|----------|
| `lz4` | ⚡ Fastest | Good (2:1) | Low | Default, general use |
| `lzo` | 🚀 Fast | Good (2:1) | Low | Legacy systems |
| `zstd` | 🐢 Slower | Best (3:1) | High | Maximum compression |

---

## 🔧 Commands

| Command | Description | Example |
|---------|-------------|---------|
| `start` | Create and enable ZRAM swap | `sudo ./scripts/zram-setup.sh start` |
| `stop` | Disable and remove ZRAM swap | `sudo ./scripts/zram-setup.sh stop` |
| `status` | Show ZRAM and memory status | `sudo ./scripts/zram-setup.sh status` |

### 📝 Command Examples

```bash
# Start ZRAM
sudo ./scripts/zram-setup.sh start

# Check status
sudo ./scripts/zram-setup.sh status

# Stop ZRAM (cleanup)
sudo ./scripts/zram-setup.sh stop
```

---

## 📊 Monitoring

### 🔍 Real-time Monitoring

```bash
# Watch ZRAM stats live
watch -n1 zramctl

# Monitor memory usage
watch -n1 free -h

# Check swap activity
watch -n1 swapon --show
```

### 📈 System Information

```bash
# View ZRAM device details
cat /sys/block/zram0/disksize

# Check compression ratio
cat /sys/block/zram0/compr_data_size

# View kernel messages
dmesg | grep -i zram

# Monitor system resources
htop
```

### 🌡️ Raspberry Pi Specific

```bash
# Check CPU temperature
vcgencmd measure_temp

# Monitor CPU frequency
vcgencmd measure_clock arm

# Check throttle status
vcgencmd get_throttled
```

---

## 🛠️ Troubleshooting

### ❌ Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| **Permission denied** | Not running as root | Run with `sudo` |
| **ZRAM module not found** | Kernel doesn't support ZRAM | Check kernel version ≥3.14 |
| **Swap not activating** | Script failed silently | Run `dmesg \| grep zram` to check errors |
| **High CPU usage** | Compression algorithm too heavy | Switch to `lz4` (default) |
| **System slowdown** | ZRAM too large | Reduce `ZRAM_RATIO` to 25-50% |

### 🔍 Debug Steps

```bash
# 1. Check if ZRAM module is loaded
lsmod | grep zram

# 2. Check kernel messages
dmesg | grep -i zram

# 3. Verify ZRAM device exists
ls -la /dev/zram*

# 4. Check current ZRAM configuration
zramctl

# 5. Review system logs
journalctl -u zram-setup.service
```

### 🆘 Getting Help

- 📝 **Issues**: [GitHub Issues](https://github.com/4riful/raspberrypi-zram-optimizer/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/4riful/raspberrypi-zram-optimizer/discussions)
- 📚 **Documentation**: Check the [Wiki](https://github.com/4riful/raspberrypi-zram-optimizer/wiki)

---

## 📁 Project Structure

```
raspberrypi-zram-optimizer/
├── 📄 README.md              # This file
├── 📄 LICENSE                # MIT License
├── 📁 scripts/
│   └── 🔧 zram-setup.sh     # Main ZRAM setup script
├── 📁 systemd/
│   └── ⚙️ zram-setup.service # Systemd service file
└── 📁 config/
    └── 📋 sysctl.conf        # Kernel parameters (optional)
```

### 📄 File Descriptions

| File | Purpose |
|------|---------|
| `scripts/zram-setup.sh` | Core script that sets up and manages ZRAM |
| `systemd/zram-setup.service` | Systemd service for automatic startup |
| `config/sysctl.conf` | Optional kernel parameter tuning |

---

## 🔒 Security Considerations

- 🔐 **Root Access Required**: ZRAM setup requires privileged access for system configuration
- 🛡️ **No Backing Files**: Avoid using microSD for ZRAM backing (default disabled)
- 📊 **Logging**: All operations are logged for audit purposes
- 🔒 **System Integration**: Service runs at boot with appropriate permissions

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. 🐛 **Report Bugs**: Open an issue with detailed reproduction steps
2. 💡 **Suggest Features**: Share your ideas for improvements
3. 📝 **Improve Documentation**: Help make our docs clearer
4. 🔧 **Submit Code**: Fix bugs or add new features
5. 🧪 **Test**: Try on different hardware and report results

### 📋 Development Setup

```bash
# Clone the repository
git clone https://github.com/4riful/raspberrypi-zram-optimizer.git
cd raspberrypi-zram-optimizer

# Create a new branch
git checkout -b feature/your-feature

# Make changes and test
# ...

# Commit and push
git commit -m "feat: add your feature"
git push origin feature/your-feature
```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2026 4riful

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software...
```

---

## 🙏 Acknowledgments

- 🐧 **Linux Kernel Team**: For ZRAM implementation
- 🍓 **Raspberry Pi Foundation**: For the amazing hardware platform
- 🌍 **Open Source Community**: For inspiration and feedback
- 👥 **Contributors**: Thanks to all contributors who helped improve this project

---

## 📞 Support

| Channel | Link |
|---------|------|
| 🐛 **Bug Reports** | [GitHub Issues](https://github.com/4riful/raspberrypi-zram-optimizer/issues) |
| 💬 **Discussions** | [GitHub Discussions](https://github.com/4riful/raspberrypi-zram-optimizer/discussions) |
| 📚 **Documentation** | [Project Wiki](https://github.com/4riful/raspberrypi-zram-optimizer/wiki) |
| ⭐ **Star the Repo** | [GitHub Stars](https://github.com/4riful/raspberrypi-zram-optimizer/stargazers) |

---

<div align="center">

**Made with ❤️ for the Raspberry Pi community**

![Raspberry Pi ZRAM Optimizer](https://img.shields.io/github/stars/4riful/raspberrypi-zram-optimizer?style=social)

*If this project helped you, please give it a ⭐ star on GitHub!*

</div>
