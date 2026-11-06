# postmarketOS for Samsung Galaxy Tab S 10.5 LTE (SM-T805 / `chagalllte`)

This repository carries the device + downstream-kernel packages needed to run
[postmarketOS](https://postmarketos.org) on the Galaxy Tab S 10.5 **LTE**
(SM-T805/T805Y, Exynos 5420 "universal5420", Mali-T628 MP6), adapted from the
official `samsung-chagallwifi` port.

The LTE variant is **not** in upstream pmaports; the device packages here are:

- `device/testing/device-samsung-chagalllte` — deviceinfo (Heimdall bootimg,
  2560x1600, SEAndroidenforce footer) + downstream kernel subpackage
- `device/testing/linux-samsung-chagalllte` — kernel 3.4.113 from
  [exynos5420/android_kernel_samsung_exynos5420](https://github.com/exynos5420/android_kernel_samsung_exynos5420)
  commit `fed1690` (lineage-16.0 branch), config derived from the pmOS-checked
  `chagallwifi` config with LTE deltas:
  - `CONFIG_CHAGALL_LTE=y` (board selector, replaces `CHAGALL_WIFI`)
  - `CONFIG_TOUCHSCREEN_ATMEL_MXT1664T=y` (LTE uses Atmel, not Synaptics DSX)
  - Intel XMM6360 modem chain (`SEC_MODEM_V2`, `LINK_DEVICE_HSIC`, `SIM_DETECT`)
  - SX9500 grip sensor (drivers present; userspace modem support is out of scope)
- built with `KCFLAGS="-std=gnu89"` so the 3.4 kernel compiles with modern GCC

## Build (GitHub Actions)

Push / dispatch the `build-pmos-chagalllte` workflow. It installs pmbootstrap,
applies the aports overlay, and produces a TWRP-flashable recovery zip plus
`boot.img` / rootfs images as artifacts.

`ci-patch/binfmt_patch.py` fixes a pmbootstrap bug on dash-based hosts: the
qemu binfmt registration uses `echo` with `\xHH` escapes, which dash does not
interpret, silently corrupting the binfmt magic.

## Flashing (TWRP already installed)

1. Download the workflow artifact (`pmos-samsung-chagalllte`)
2. Boot to TWRP, `adb push pmos-samsung-chagalllte.zip /sdcard/`
3. In TWRP: Install → select the zip → swipe
4. Reboot. First boot takes a while; SSH user `pmos` / password `1234`.

Returning to Android requires flashing the stock SM-T805Y firmware via Odin
(wipes data) — keep a copy of the stock ROM before flashing.

## Status / expectations

Research OS on 2014 hardware, downstream 3.4 kernel. Expected working:
display, backlight, touch (Atmel MXT1664T), buttons, USB networking, SSH,
MATE desktop (software rendering). Not expected: LTE modem, camera, GPU
acceleration.
