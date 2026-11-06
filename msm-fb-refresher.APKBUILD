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
