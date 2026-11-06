# postmarketOS for Samsung Galaxy Tab S 10.5 LTE (SM-T805/T805Y, `chagalllte`)

Device + downstream-kernel packages to run [postmarketOS](https://postmarketos.org)
on the Galaxy Tab S 10.5 **LTE** (Exynos 5420 "universal5420", Mali-T628 MP6),
adapted from the official `samsung-chagallwifi` port.

Upstream pmaports has no `chagalllte` entry (only `chagallwifi`), so this repo
carries both packages:

- `overlay/device/testing/device-samsung-chagalllte`
  deviceinfo (Heimdall bootimg, 2560x1600, tablet) + downstream kernel subpackage
- `overlay/device/testing/linux-samsung-chagalllte`
  kernel 3.4.113 from
  [exynos5420/android_kernel_samsung_exynos5420](https://github.com/exynos5420/android_kernel_samsung_exynos5420)
  commit `fed1690` (lineage-16.0), config derived from the pmOS-tested
  chagallwifi config with LTE deltas:
  - `CONFIG_CHAGALL_LTE=y` (board selector, replaces `CHAGALL_WIFI`)
  - `CONFIG_TOUCHSCREEN_ATMEL_MXT1664T=y` **and**
    `CONFIG_TOUCHSCREEN_SYNAPTICS_I2C_DSX=y` — both are enabled in Samsung's
    own `lineageos_chagalllte_defconfig` (board revisions differ)
  - Intel XMM6360 modem chain (`SEC_MODEM_V2`, `LINK_DEVICE_HSIC`, `SIM_DETECT`)
  - SX9500 grip sensor
  - built with `KCFLAGS="-std=gnu89"` so a 3.4 tree compiles on modern GCC

## Why these choices

The partition layout of this tablet (read from the device):

| Partition | Device | Size |
|-----------|--------|------|
| BOOT      | `mmcblk0p9`  | **8 MB** |
| RECOVERY  | `mmcblk0p10` | 10 MB |
| SYSTEM    | `mmcblk0p18` | 2.39 GB |
| USERDATA  | `mmcblk0p21` | 11.76 GB |

- **Rootfs → USERDATA.** SYSTEM is far too small for a MATE rootfs. The TWRP
  zip creates a nested partition table inside USERDATA (`pmOS_boot` +
  `pmOS_root`); the postmarketOS initramfs finds nested layouts via
  `mount_subpartitions()` (`losetup -Pf` on partitions that contain 2
  subpartitions), so this is a supported layout.
- **BOOT is only 8 MB.** Upstream chagallwifi hit exactly this limit (11 MB
  boot.img, unflashable). The current 3.x initramfs is multi-stage, so the
  base initramfs in boot.img is small (busybox, blkid, losetup, scripts), and
  the kernel is already LZMA-compressed — the workflow still asserts
  `boot.img <= 8 MiB` and fails the build if that changes.
- **OpenRC, not systemd.** systemd cannot boot on a 3.4 kernel; the workflow
  sets `service_manager=openrc` (which also selects the non-systemd `edge`
  channel).

## Build (GitHub Actions)

Push to `main` or run the `build-pmos-chagalllte` workflow manually. On an
`ubuntu-latest` runner (real kernel, working 32-bit binfmt) it:

1. installs pmbootstrap **3.12.1** (the tag this port is validated against)
2. patches a pmbootstrap bug where the qemu binfmt registration is written
   with `sh -c echo "\x7f..."` — on dash-based hosts the escapes are literal,
   producing a broken magic (`ci-patch/binfmt_patch.py`)
3. clones the `main` (edge) pmaports branch and copies the aports overlay in,
   removing the archived upstream `chagalllte` duplicates
4. seeds `pmbootstrap_v3.cfg` and the work-folder version marker directly
   instead of running `pmbootstrap init` (init insists on an interactive
   vendor/codename prompt, which cannot be answered safely from a script)
5. runs `pmbootstrap install --android-recovery-zip --recovery-install-partition USERDATA`
6. verifies the boot.img size and uploads the TWRP zip + boot.img as artifacts

Runtime is roughly 40–70 minutes (kernel cross-compile + MATE rootfs).

## Flashing

Prerequisite: TWRP recovery on the device, and a copy of the stock SM-T805Y
firmware for Odin (already obtained) as the revert path.

1. Download the `pmos-samsung-chagalllte` artifact and verify `SHA256SUMS`
2. Boot to TWRP, then:
   ```
   adb push pmos-samsung-chagalllte.zip /sdcard/
   ```
3. **Unmount /data first** (the installer repartitions USERDATA):
   `umount /data` in the TWRP terminal, or leave Data unmounted.
4. TWRP → Install → select the zip → swipe
5. Reboot. First boot takes several minutes (no GPU acceleration).
6. Login: user `user`, password `1234` (dummy build password — change it).

The installer writes `boot.img` to BOOT and the rootfs into a nested
`pmOS_root` inside USERDATA. Keep the zip: re-flashing is the normal update
path.

### Reverting to Android

Flash the stock SM-T805Y firmware with Odin. This restores the stock partition
table, so the nested pmOS layout is removed (data is wiped).

## Expected support

Research OS on 2014 hardware with a downstream 3.4 kernel.

Working: display, backlight, touch (Atmel MXT1664T), physical buttons, USB
networking, SSH, MATE desktop (software rendering), battery reporting.

Not expected: LTE modem (XMM6360 drivers exist but no userspace support),
camera, GPU acceleration, WiFi (the LTE board uses a different chip than the
WiFi variant).
