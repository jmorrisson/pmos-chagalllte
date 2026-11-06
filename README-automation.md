# pmos-chagalllte — Automation Guide

## Overview

This directory contains a complete automation suite for building postmarketOS for the Samsung Galaxy Tab S 10.5 LTE (SM-T805/T805Y).

## Quick Start

```powershell
cd C:\Project\pmos-chagalllte
.\build-all.ps1 -OutputDir "C:\Project\pmos-chagalllte\output" -Password "your-password"
```

This single command performs the entire build pipeline:
- Installs pmbootstrap 3.12.1
- Clones pmaports (edge/main)
- Installs device/kernel aports
- Seeds configuration
- Builds the full image (~40–70 minutes)
- Verifies boot.img size (< 8 MB)
- Packages artifacts with checksums

## Script Catalog

| Script | Purpose |
|--------|---------|
| `build-all.ps1` | Full pipeline (recommended) |
| `build-step-1-install.ps1` | Install pmbootstrap + binfmt patch |
| `build-step-4-overlay.ps1` | Set up aports overlay |
| `build-step-6-build.ps1` | Build + verify boot.img size |

### Using scripts individually

```powershell
# Step 1 only (fast, ~30 sec)
.\build-step-1-install.ps1

# Step 4 only (fast, ~5 sec)
.\build-step-4-overlay.ps1

# Step 6 only (full build, ~70 min)
.\build-step-6-build.ps1 -SkipBuild $false
```

## Prerequisites

### Windows + WSL2 Setup

```powershell
# Install WSL if not already installed
wsl --install

# First boot setup
wsl -d Ubuntu-24.04 bash -c 'sudo apt update && sudo apt upgrade -y'

# Install build tools in WSL
wsl -d Ubuntu-24.04 bash -c 'sudo apt install -y git python3 python3-pip qemu-user-static binutils-arm-linux-gnueabihf'
```

### Required Tools

| Tool | Purpose |
|------|---------|
| WSL (Ubuntu 24.04) | Cross-compile ARM kernel |
| Python 3.10+ | pmbootstrap installation |
| git | Clone pmaports/pmbootstrap |
| pmbootstrap 3.12.1 | Build system |

## Configuration

Edit `build-all.ps1` to customize:

```powershell
param(
    [string]$OutputDir = "$PSScriptRoot\output",   # Where artifacts go
    [bool]$SkipChecksums = $false,                  # Skip SHA256 generation
    [string]$Password = "1234"                       # Device user password
)
```

## What Gets Built

| Artifact | Description |
|----------|-------------|
| `pmos-samsung-chagalllte.zip` | TWRP recovery zip containing the rootfs |
| `boot.img` | Kernel + multi-stage initramfs (~4.8 MB, fits in 8 MB BOOT) |
| `SHA256SUMS` | Checksums for verification |

## Build Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    build-all.ps1                              │
├─────────────────────────────────────────────────────────────┤
│  Step 1: Install pmbootstrap 3.12.1 + binfmt patch           │
│  Step 2: Clone pmaports (main/edge)                          │
│  Step 3: Install aports overlay                              │
│  Step 4: Seed config (non-interactive)                       │
│  Step 5: pmbootstrap install (kernel + rootfs build)         │
│  Step 6: Copy mkbootimg to chroot                            │
│  Step 7: Verify boot.img < 8 MB                              │
│  Step 8: Package artifacts                                   │
└─────────────────────────────────────────────────────────────┘
```

## Expected Runtime

| Step | Duration |
|------|----------|
| pmbootstrap install (kernel build) | ~25–35 min |
| pmbootstrap install (rootfs build) | ~15–25 min |
| Total | ~40–70 min (first run) |

Subsequent builds are faster (~15–20 min) if you skip the kernel rebuild.

## Verification

After building, verify your artifacts:

```bash
cd C:\Project\pmos-chagalllte\output\artifacts
sha256sum -c SHA256SUMS
```

## Flashing (Brief)

```bash
# 1. Boot TWRP → Terminal → umount /data
adb shell mount | grep data
adb shell umount /dev/block/mmcblk0p21

# 2. Push and flash
adb push pmos-samsung-chagalllte.zip /sdcard/
adb reboot recovery
# In TWRP: Install → select zip → Swipe

# 3. Reboot
adb reboot
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `mkbootimg not found` | Run `build-step-6-build.ps1` — it copies mkbootimg to chroot |
| `User 'user' already exists` | Add `--wipe-data` flag or remove existing user |
| Build fails on WSL2 | Use GitHub Actions (push to main triggers CI) |
| Boot.img > 8 MB | Check kernel config; reduce CONFIG_FIRMWARE_IN_KERNEL size |

## Security Notes

- Default password is `1234`. Change it before flashing.
- The device has SSH enabled by default — secure your network.
- Keep the stock firmware backup for recovery.

## License

MIT License — see LICENSE file in the main repo.
