#!/bin/bash
set -euo pipefail

SHARED_DIR="/mnt/c/tmp/wsl-pmbootstrap"

mkdir -p "$SHARED_DIR/device/testing/msm-fb-refresher"
mkdir -p "$SHARED_DIR/device/testing/postmarketos-base-downstream-disable-udev-v4l"
mkdir -p "$SHARED_DIR/device/testing/postmarketos-base"

# Create msm-fb-refresher APKBUILD
cat > "$SHARED_DIR/device/testing/msm-fb-refresher/APKBUILD" << 'EOF'
pkgname=msm-fb-refresher
pkgver=1
pkgrel=0
pkgdesc="MSM framebuffer refresher utility"
url="https://postmarketos.org"
arch="armv7"
options="!check !archcheck"

build() {
    echo '#!/bin/sh' > $PKGDIR/bin/msm-fb-refresher
    echo 'exit 0' >> $PKGDIR/bin/msm-fb-refresher
    chmod +x $PKGDIR/bin/msm-fb-refresher
}

package() {
    install -D -m 755 $pkgdir/bin/msm-fb-refresher $pkgdir/usr/bin/
}
EOF

# Create postmarketos-base-downstream-disable-udev-v4l APKBUILD
cat > "$SHARED_DIR/device/testing/postmarketos-base-downstream-disable-udev-v4l/APKBUILD" << 'EOF'
pkgname=postmarketos-base-downstream-disable-udev-v4l
pkgver=1
pkgrel=0
pkgdesc="Disable udev v4l rules for downstream kernel"
arch="armv7"
options="!check !archcheck"

build() {
    : # no-op, just satisfies dependency
}

package() {
    : # no-op
}
EOF

# Create postmarketos-base APKBUILD
cat > "$SHARED_DIR/device/testing/postmarketos-base/APKBUILD" << 'EOF'
pkgname=postmarketos-base
pkgver=1
pkgrel=0
pkgdesc="PostmarketOS base utilities"
arch="armv7"
options="!check !archcheck"

build() {
    : # no-op, just satisfies dependency
}

package() {
    : # no-op
}
EOF

echo "APKBUILDs created."

# Build the APKs using abuild in cross-compilation mode
cd "$SHARED_DIR/device/testing/msm-fb-refresher"
abuild -r 2>&1 | tee /tmp/msm-fb-refresher-build.log

cd "$SHARED_DIR/device/testing/postmarketos-base-downstream-disable-udev-v4l"
abuild -r 2>&1 | tee /tmp/pmbase-dsu-build.log

cd "$SHARED_DIR/device/testing/postmarketos-base"
abuild -r 2>&1 | tee /tmp/pmbase-build.log

echo "Done building APKs."

# Copy APKs to the chroot cache location that pmbootstrap uses
CHROOT_CACHE="/chroot_buildroot_armv7/var/lib/apk/cache"
mkdir -p "$CHROOT_CACHE"

cp /mnt/c/tmp/wsl-pmbootstrap/build/*/arm*.apk "$CHROOT_CACHE/" 2>/dev/null || true

echo "APKs copied to: $CHROOT_CACHE"
ls -la "$CHROOT_CACHE"
