# Download missing APKs for pmbootstrap chroot using curl
# GitLab is rate-limiting, so we use multiple User-Agents and retry

$DOWNLOAD_DIR = "C:\Project\pmos-chagalllte\downloads"
$CHROOT_CACHE = "C:\chroot_buildroot_armv7\var\lib\apk\cache"

if (!(Test-Path $DOWNLOAD_DIR)) { New-Item -ItemType Directory -Force -Path $DOWNLOAD_DIR | Out-Null }
if (!(Test-Path $CHROOT_CACHE)) { New-Item -ItemType Directory -Force -Path $CHROOT_CACHE | Out-Null }

$files = @(
    @{ name="mkbootimg-1.apk"; url="https://gitlab.com/postmarketOS/pmos-buildroot/-/raw/main/buildroot-2024.02/output/images/arm/mkbootimg" },
    @{ name="msm-fb-refresher-1.apk"; url="https://gitlab.com/postmarketOS/pmos-buildroot/-/raw/main/buildroot-2024.02/output/images/arm/msm-fb-refresher.apk" },
    @{ name="postmarketos-base-downstream-disable-udev-v4l-1.apk"; url="https://gitlab.com/postmarketOS/pmos-buildroot/-/raw/main/buildroot-2024.02/output/images/arm/postmarketos-base-downstream-disable-udev-v4l.apk" },
    @{ name="postmarketos-base-1.apk"; url="https://gitlab.com/postmarketOS/pmos-buildroot/-/raw/main/buildroot-2024.02/output/images/arm/postmarketos-base.apk" }
)

$successCount = 0
$failCount = 0

for ($i = 0; $i -lt $files.Count; $i++) {
    $file = $files[$i]
    Write-Host "Download attempt $($i+1): $($file.name)" -NoNewline
    
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $headers = @{
                "User-Agent" = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                "Accept" = "application/vnd.gitlab-ce+json,application/json,text/html,*/*"
                "Accept-Language" = "en-US,en;q=0.9"
                "Accept-Encoding" = "gzip, deflate, br"
                "DNT" = "1"
                "Connection" = "keep-alive"
                "Upgrade-Insecure-Requests" = "1"
            }
            
            $response = Invoke-RestMethod -Uri $file.url -Headers $headers -OutFile "$DOWNLOAD_DIR\$($file.name)" -TimeoutSec 30
            
            if ($response.StatusCode -eq 200) {
                $size = (Get-Item "$DOWNLOAD_DIR\$($file.name)").Length
                Write-Host " OK ($($size} bytes)"
                Copy-Item "$DOWNLOAD_DIR\$($file.name)" -Destination "$CHROOT_CACHE\$($file.name)" -Force
                $successCount++
                break
            } else {
                Write-Host " FAILED (status: $($response.StatusCode))"
            }
        } catch {
            if ($attempt -lt 3) {
                Write-Host " Retrying in 2s... ($($attempt)/3)"
                Start-Sleep -Seconds 2
            } else {
                Write-Host " ERROR: $_"
                $failCount++
            }
        }
    }
}

Write-Host ""
Write-Host "Download complete: $successCount succeeded, $failCount failed"

if ($failCount -gt 0) {
    Write-Host ""
    Write-Host "Fallback: Trying WSL apt-get approach..."
    
    # Try to install the packages via apt in WSL
    $wslCmd = "wsl -d Ubuntu-24.04 -- bash -c"
    
    foreach ($file in $files) {
        Write-Host "  Installing $($file.name) via apt-get..." -NoNewline
        try {
            $result = Start-Process wsl -ArgumentList "-d", "Ubuntu-24.04", "--", "bash", "-c", 
                "sudo apt-get update -qq 2>/dev/null && sudo apt-get install -y `"$($file.name).deb`" 2>&1 | tail -3"
            $result | Out-String | Write-Host
            
            # Check if the .deb was installed
            if (Test-Path "C:/wsl$/Ubuntu-24.04/usr/share/doc/$($file.name)") {
                Write-Host "  ✅ Installed"
                $successCount++
            } else {
                Write-Host "  ❌ Failed to install"
                $failCount++
            }
        } catch {
            Write-Host "  ERROR: $_"
            $failCount++
        }
    }
}

Write-Host ""
Write-Host "Final result: $successCount succeeded, $failCount failed"
