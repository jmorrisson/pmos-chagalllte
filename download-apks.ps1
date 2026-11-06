# Download missing APKs for pmbootstrap chroot
# These are build-time dependencies needed by the device aport

$DOWNLOAD_DIR = "C:\Project\pmos-chagalllte\downloads"
$CHROOT_CACHE = "C:\chroot_buildroot_armv7\var\lib\apk\cache"

# Create directories
if (!(Test-Path $DOWNLOAD_DIR)) { New-Item -ItemType Directory -Force -Path $DOWNLOAD_DIR | Out-Null }
if (!(Test-Path $CHROOT_CACHE)) { New-Item -ItemType Directory -Force -Path $CHROOT_CACHE | Out-Null }

$files = @(
    @{ name="mkbootimg-1.apk"; url="https://gitlab.com/postmarketOS/pmos-buildroot/-/raw/main/buildroot-2024.02/output/images/arm/mkbootimg" },
    @{ name="msm-fb-refresher-1.apk"; url="https://gitlab.com/postmarketOS/pmos-buildroot/-/raw/main/buildroot-2024.02/output/images/arm/msm-fb-refresher.apk" },
    @{ name="postmarketos-base-downstream-disable-udev-v4l-1.apk"; url="https://gitlab.com/postmarketOS/pmos-buildroot/-/raw/main/buildroot-2024.02/output/images/arm/postmarketos-base-downstream-disable-udev-v4l.apk" },
    @{ name="postmarketos-base-1.apk"; url="https://gitlab.com/postmarketOS/pmos-buildroot/-/raw/main/buildroot-2024.02/output/images/arm/postmarketos-base.apk" }
)

Write-Host "Downloading missing APKs..."
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($file in $files) {
    Write-Host "Downloading $($file.name)..." -NoNewline
    try {
        $response = Invoke-RestMethod -Uri $file.url -Headers @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" } -OutFile "$DOWNLOAD_DIR\$($file.name)"
        if ($response.StatusCode -eq 200) {
            $size = (Get-Item "$DOWNLOAD_DIR\$($file.name)").Length
            Write-Host " OK ($($size) bytes)"
            Copy-Item "$DOWNLOAD_DIR\$($file.name)" -Destination "$CHROOT_CACHE\$($file.name)" -Force
            $successCount++
        } else {
            Write-Host " FAILED (status: $($response.StatusCode))"
            $failCount++
        }
    } catch {
        Write-Host " ERROR: $_"
        $failCount++
    }
}

Write-Host ""
Write-Host "Download complete: $successCount succeeded, $failCount failed"
Write-Host ""
if (Test-Path $CHROOT_CACHE) {
    Write-Host "Chroot cache contents:"
    Get-ChildItem $CHROOT_CACHE | Format-Table Name, Length, LastWriteTime -AutoSize
}
