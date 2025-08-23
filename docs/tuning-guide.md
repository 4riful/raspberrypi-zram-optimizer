# ZRAM Tuning Guide

## Why ZRAM?
ZRAM compresses swap in RAM, reducing I/O pressure on SD cards and improving performance.

---

## Recommended Settings
- Use **50% of RAM** for zram swap.
- Compression algorithm: **zstd** for best speed/ratio.

---

## Monitor Usage
Check stats:
```bash
cat /sys/block/zram0/mm_stat
```
