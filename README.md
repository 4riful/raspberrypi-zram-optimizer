# 🚀 Raspberry Pi ZRAM Optimizer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Raspberry Pi](https://img.shields.io/badge/Platform-Raspberry%20Pi-red.svg)](https://www.raspberrypi.org/)

> **Lightweight ZRAM optimization for Raspberry Pi**
> Compressed swap in RAM — faster, no SD card wear, works under memory pressure

---

## ✨ Features

- 🔧 **One-Command Setup** — Install and configure ZRAM instantly
- 💾 **SD Card Protection** — Eliminates swap-on-microSD to prevent wear
- 🚀 **Performance Boost** — Compressed swap in RAM reduces I/O wait
- 🎯 **Raspberry Pi Optimized** — Tuned for Pi devices with 512MB+ RAM
- 🔒 **Production Ready** — Idempotent, clean error handling
- ⚡ **Systemd Integration** — Auto-start at boot

---

## 🎯 What is ZRAM?

**ZRAM** creates a compressed block device in RAM. Instead of writing swap to your SD card (which wears it out), swap lives in compressed memory. Perfect for memory-constrained devices like Raspberry Pi.

---

## 📋 Requirements

| Component | Requirement |
|-----------|-------------|
| **OS** | Linux with kernel ≥3.14 |
| **RAM** | ≥512 MiB |
| **Permissions** | Root access (sudo) |

---

## 🚀 Quick Start

### 1. Clone and Run

```bash
git clone https://github.com/4riful/raspberrypi-zram-optimizer.git
cd raspberrypi-zram-optimizer
sudo ./scripts/zram-setup.sh start
```

### 2. Verify

```bash
zramctl          # check ZRAM devices
swapon --show    # view active swaps
free -h          # memory overview
```

### 3. Auto-start at Boot (Optional)

```bash
sudo cp scripts/zram-setup.sh /usr/local/bin/zram-setup.sh
sudo cp systemd/zram-setup.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable zram-setup.service
```

---

## ⚙️ Configuration

All settings are optional. Defaults work well for most Pi models.

```bash
sudo ZRAM_RATIO=60 ZRAM_COMP_ALGO=zstd ./scripts/zram-setup.sh start
```

| Variable | Default | Description |
|----------|---------|-------------|
| `ZRAM_RATIO` | `50` | % of RAM to use as ZRAM |
| `ZRAM_COMP_ALGO` | `lz4` | Compression algorithm (`lz4`, `lzo`, `zstd`) |
| `ZRAM_PRIORITY` | `100` | Swap priority (higher = preferred) |
| `VM_SWAPPINESS` | `100` | Kernel swap aggressiveness (0-100) |

---

## 🔧 Commands

```bash
sudo ./scripts/zram-setup.sh start    # create and enable ZRAM swap
sudo ./scripts/zram-setup.sh stop     # disable and remove ZRAM swap
sudo ./scripts/zram-setup.sh status   # show ZRAM and memory status
```

---

## 📊 Monitoring

```bash
watch -n1 zramctl         # live ZRAM stats
watch -n1 free -h         # live memory usage
dmesg | grep -i zram      # kernel messages
```

---

## 🛠️ Troubleshooting

| Problem | Solution |
|---------|----------|
| **Permission denied** | Run with `sudo` |
| **ZRAM module not found** | Check kernel version ≥3.14 |
| **Swap not activating** | Run `dmesg \| grep zram` to check errors |

---

## 📄 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">

**Made with ❤️ for the Raspberry Pi community**

[![Star on GitHub](https://img.shields.io/github/stars/4riful/raspberrypi-zram-optimizer?style=social)](https://github.com/4riful/raspberrypi-zram-optimizer)

</div>
