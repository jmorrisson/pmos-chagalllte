# Build Automation Guide

## Quick Start

```powershell
cd C:\Project\pmos-chagalllte
.\build-all.ps1 -OutputDir "C:\Project\pmos-chagalllte\output" -Password "1234"
```

This single command will:
1. Clone and install pmbootstrap 3.12.1
2. Apply the binfmt patch fix
3. Clone pmaports (edge/main channel)
4. Install the chagalllte aports overlay
5. Seed the pmbootstrap config (non-interactive)
6. Build the full image (~40–70 minutes)
7. Verify boot.img size (< 8 MB)
8. Package artifacts with SHA256 checksums

## Prerequisites

| Tool | Install Command |
|------|----------------|
| WSL (Ubuntu 24.04) | Settings → Apps → Ubuntu |
| Python 3.10+ | Already included with WSL |
| git | Via WSL: `sudo apt install git` |
| pmbootstrap 3.12.1 | Script installs automatically |

### For Windows PowerShell users:
```powershell
wsl --install
wsl -d Ubuntu-24.04 bash -c "sudo apt update && sudo apt install -y git python3"
```

## Step-by-Step Breakdown

The full automation script performs these steps in order:

### 1. Install pmbootstrap
```bash
git clone --depth=1 --branch 3.12.1 https://gitlab.postmarketos.org/postMarketOS/pmbootstrap.git $HOME/pmbootstrap
python3 -m pip install --user --break-system-packages $HOME/pmbootstrap
```

### 2. Apply binfmt patch
```bash
python3 ci-patch/binfmt_patch.py $HOME/.local/lib/python*/site-packages/pmb/chroot/binfmt.py
```

### 3. Clone pmaports
```bash
git clone --depth=1 --branch main https://gitlab.postmarketos.org/postMarketOS/pmaports.git $WORK/pmaports
```

### 4. Install aport overlay
- Copies `device-samsung-chagalllte` to `$APORTS/device/testing/`
- Copies `linux-samsung-chagalllte` to `$APORTS/linux/linux-samsung-chagalllte/`

### 5. Seed config (non-interactive)
Creates `$HOME/.config/pmbootstrap_v3.cfg` with:
```ini
[general]
device=samsung-chagalllte
kernel=downstream
ui=mate
service_manager=openrc
auto_zap_misconfigured_chroots=yes
```

### 6. Build
```bash
pmbootstrap install --android-recovery-zip --recovery-install-partition USERDATA --password 1234
```

### 7. Provide build-time deps in chroot
Copies `mkbootimg` and `msm-fb-refresher` into `$CHROOT/usr/bin/`

### 8. Verify boot.img size
Extracts the zip, finds `./boot/boot.img`, asserts `< 8 MB`.

### 9. Package artifacts
Creates `artifacts/` directory with:
- `pmos-samsung-chagalllte.zip` (TWRP recovery image)
- `boot.img`
- `SHA256SUMS`

## Individual Script Breakdowns

### build-all.ps1
Master orchestration script. Runs the entire pipeline in one go.

### build-step-1-install.ps1
Standalone: Installs pmbootstrap 3.12.1 and applies binfmt patch.

### build-step-4-overlay.ps1
Standalone: Sets up the pmaports overlay with device/kernel aports.

### build-step-6-build.ps1
Standalone: Runs `pmbootstrap install` and verifies boot.img size.

## Output Structure

```
C:\Project\pmos-chagalllte\output/
├── build.log              # Full build log
├── artifacts/
│   ├── pmos-samsung-chagalllte.zip
│   ├── boot.img
│   └── SHA256SUMS
└── temp_rootfs/           # Temporary extraction directory
```

## Troubleshooting

### "mkbootimg not found" error
The kernel aport's `downstreamkernel_package()` requires `mkbootimg` to be in `$CHROOT/usr/bin/`. The automation script copies it from the buildroot output. If your manual build doesn't include this, add:

```bash
mkdir -p $CHROOT/usr/bin
cp $CHROOT/usr/bin/mkbootimg-1.apk/unstripped/mkbootimg $CHROOT/usr/bin/
```

### "User 'user' already exists" error
The first boot creates the `user` account. If you've built before and want a fresh build, add:
```bash
pmbootstrap install --wipe-data
```

### WSL2 kernel cross-compile fails
WSL2's kernel doesn't support `MAP_FIXED_NOREPLACE` (required by qemu-arm). Use GitHub Actions instead for the full build. For local testing only, you can skip the kernel rebuild:

```bash
pmbootstrap install --no-build-kernel
```

## Flashing Instructions

After building:

```bash
# 1. Verify checksums
cd C:\Project\pmos-chagalllte\output\artifacts
sha256sum -c SHA256SUMS

# 2. Boot device into TWRP
adb reboot recovery

# 3. Unmount /data (critical — prevents overwriting pmOS during install)
adb shell umount /dev/block/mmcblk0p21

# 4. Push and flash via TWRP
adb push pmos-samsung-chagalllte.zip /sdcard/
# In TWRP: Install → select zip → Swipe

# 5. Reboot
adb reboot
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OutputDir` | `$PSScriptRoot\output` | Where artifacts are written |
| `Password` | `"1234"` | User password for the device |
| `PMBOOTSTRAP_VERSION` | `"3.12.1"` | pmbootstrap version to use |
| `PMPORTS_BRANCH` | `"main"` | pmaports branch (edge channel) |

## Security Notes

- The default password is `1234`. Change it by modifying the script or using `pmbootstrap config password <new>` before building.
- Artifacts contain a full rootfs with SSH access. Secure your device after flashing.

## License

Part of the pmos-chagalllte project — MIT licensed.
