# Raspberry Pi ZRAM Optimizer

Compressed swap in RAM. Reduces SD card wear, improves performance under memory pressure.

## Install

```bash
git clone https://github.com/4riful/raspberrypi-zram-optimizer.git
cd raspberrypi-zram-optimizer
sudo ./scripts/zram-setup.sh start
```

## Auto-start at boot

```bash
sudo cp scripts/zram-setup.sh /usr/local/bin/zram-setup.sh
sudo cp systemd/zram-setup.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable zram-setup.service
```

## Commands

```bash
sudo ./scripts/zram-setup.sh start    # create ZRAM swap
sudo ./scripts/zram-setup.sh stop     # disable ZRAM
sudo ./scripts/zram-setup.sh status   # show status
```

## Configuration

Optional environment variables:

| Variable | Default | Description |
|---|---|---|
| `ZRAM_RATIO` | `50` | % of RAM for ZRAM |
| `ZRAM_COMP_ALGO` | `lz4` | Compression algorithm |
| `ZRAM_PRIORITY` | `100` | Swap priority |
| `VM_SWAPPINESS` | `100` | Kernel swappiness |

```bash
sudo ZRAM_RATIO=60 ./scripts/zram-setup.sh start
```

## Requirements

- Linux kernel 3.14+
- Root access
