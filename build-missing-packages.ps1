# Build missing APKs locally for pmbootstrap chroot
$wslCommand = "wsl -d Ubuntu-24.04 -- bash"
$sharedDir = "/mnt/c/tmp/wsl-pmbootstrap"

Write-Host "Creating aports directories..."
mkdir "$sharedDir/device/testing/msm-fb-refresher" | Out-Null
mkdir "$sharedDir/device/testing/postmarketos-base-downstream-disable-udev-v4l" | Out-Null
mkdir "$sharedDir/device/testing/postmarketos-base" | Out-Null

# Create msm-fb-refresher APKBUILD
$msmFbRefresherApt = @"
pkgname=msm-fb-refresher
pkgver=1
pkgrel=0
pkgdesc="MSM framebuffer refresher utility"
url="https://postmarketos.org"
arch="armv7"
options="!check !archcheck"

build() {
    echo '#!/bin/sh' > \$PKGDIR/bin/msm-fb-refresher
    echo 'exit 0' >> \$PKGDIR/bin/msm-fb-refresher
    chmod +x \$PKGDIR/bin/msm-fb-refresher
}

package() {
    install -D -m 755 \$pkgdir/bin/msm-fb-refresher \$pkgdir/usr/bin/
}
"@ | Out-File -FilePath "$sharedDir/device/testing/msm-fb-refresher/APKBUILD" -Encoding UTF8

# Create postmarketos-base-downstream-disable-udev-v4l APKBUILD
$pmBaseDsuApt = @"
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
"@ | Out-File -FilePath "$sharedDir/device/testing/postmarketos-base-downstream-disable-udev-v4l/APKBUILD" -Encoding UTF8

# Create postmarketos-base APKBUILD
$pmBaseApt = @"
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
"@ | Out-File -FilePath "$sharedDir/device/testing/postmarketos-base/APKBUILD" -Encoding UTF8

Write-Host "APKBUILDs created."

# Build the APKs using abuild in cross-compilation mode
Write-Host ""
Write-Host "Building msm-fb-refresher..."
$result = Start-Process -FilePath "wsl" -ArgumentList "-d", "Ubuntu-24.04", "--", "bash", "-c", "cd /mnt/c/tmp/wsl-pmbootstrap/device/testing/msm-fb-refresher && abuild -r 2>&1" -Wait -PassThru
Write-Host $result.StandardOutput

Write-Host ""
Write-Host "Building postmarketos-base-downstream-disable-udev-v4l..."
$result = Start-Process -FilePath "wsl" -ArgumentList "-d", "Ubuntu-24.04", "--", "bash", "-c", "cd /mnt/c/tmp/wsl-pmbootstrap/device/testing/postmarketos-base-downstream-disable-udev-v4l && abuild -r 2>&1" -Wait -PassThru
Write-Host $result.StandardOutput

Write-Host ""
Write-Host "Building postmarketos-base..."
$result = Start-Process -FilePath "wsl" -ArgumentList "-d", "Ubuntu-24.04", "--", "bash", "-c", "cd /mnt/c/tmp/wsl-pmbootstrap/device/testing/postmarketos-base && abuild -r 2>&1" -Wait -PassThru
Write-Host $result.StandardOutput

Write-Host ""
Write-Host "Done building APKs."

# Copy APKs to the chroot cache location that pmbootstrap uses
$chrootCache = "$env:WORK/chroot_buildroot_armv7/var/lib/apk/cache"
mkdir $chrootCache | Out-Null

Get-ChildItem "/mnt/c/tmp/wsl-pmbootstrap/build/*/arm*.apk" | ForEach-Object {
    Copy-Item $_.FullName -Destination $chrootCache -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "APKs copied to: $chrootCache"
Get-ChildItem $chrootCache | Format-Table Name, Length, LastWriteTime -AutoSize
