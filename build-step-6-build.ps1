# =============================================================================
# Step 6: Build image and verify boot.img size
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$WorkDir = "$env:USERPROFILE\.local\var\pmbootstrap",

    [Parameter(Mandatory=$false)]
    [string]$Password = "1234",

    [Parameter(Mandatory=$false)]
    [bool]$SkipBuild = $false,

    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "$PSScriptRoot\output"
)

Write-Host "=== Step 6: Build image ===" -ForegroundColor Cyan

$CHROOT_DIR = "$WorkDir\chroot_buildroot_armv7"
$ARTIFACTS_DIR = "$OutputDir\artifacts"
$tempRoot = "$OutputDir\temp_rootfs"

# Provide build-time dependencies in chroot (required by kernel aport)
Write-Host ""
Write-Host "Providing build-time dependencies..." -ForegroundColor Yellow
mkdir -p "$CHROOT_DIR\usr\bin"

if (Test-Path "$CHROOT_DIR\usr\bin\mkbootimg-1.apk\unstripped\mkbootimg") {
    Copy-Item "$CHROOT_DIR\usr\bin\mkbootimg-1.apk\unstripped\mkbootimg" `
        -Destination "$CHROOT_DIR\usr\bin\mkbootimg" -Force
    Write-Host "  Copied mkbootimg to chroot." -ForegroundColor Green
} else {
    Write-Host "  Warning: mkbootimg not found in buildroot output." -ForegroundColor Yellow
}

if (Test-Path "$CHROOT_DIR\usr\bin\msm-fb-refresher-1.apk\unstripped\msm-fb-refresher") {
    Copy-Item "$CHROOT_DIR\usr\bin\msm-fb-refresher-1.apk\unstripped\msm-fb-refresher" `
        -Destination "$CHROOT_DIR\usr\bin\msm-fb-refresher" -Force
    Write-Host "  Copied msm-fb-refresher to chroot." -ForegroundColor Green
}

# Seed config if not already present
$CONFIG_FILE = "$env:HOME\.config\pmbootstrap_v3.cfg"
if (!(Test-Path $CONFIG_FILE)) {
    New-Item -ItemType Directory -Force -Path $env:HOME\.config | Out-Null
    @"
[general]
device=samsung-chagalllte
kernel=downstream
ui=mate
service_manager=openrc
auto_zap_misconfigured_chroots=yes
" | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
    Write-Host "  Seeded pmbootstrap config." -ForegroundColor Green
}

if ($SkipBuild) {
    Write-Host "Skipping actual build (--no-build-kernel mode)." -ForegroundColor Yellow
    Write-Host "Run without --skip-build to perform full build." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Running pmbootstrap install..." -ForegroundColor Yellow
    Write-Host "(This will take 40–70 minutes on first run)" -ForegroundColor Cyan

    $buildStart = Get-Date
    try {
        pmbootstrap install `
            --android-recovery-zip `
            --recovery-install-partition USERDATA `
            --password $Password

        $duration = [math]::Round((Get-Date - $buildStart).TotalMinutes, 1)
        Write-Host "Build completed in $$duration minutes." -ForegroundColor Green
    } catch {
        Write-Host "Build failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Verify boot.img size
Write-Host ""
Write-Host "Verifying boot.img size..." -ForegroundColor Yellow

$zipFile = Get-ChildItem "$CHROOT_DIR\var\lib\postmarketos-android-recovery-installer\pmOS-*.zip" | Select-Object -First 1

if (-not $zipFile) {
    throw "No recovery zip found. Build may have failed."
}

Write-Host "Found: $($zipFile.Name)" -ForegroundColor Green

New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile.FullName, $tempRoot)
} catch {
    throw "Failed to extract zip: $_"
}

$bootImgPath = Get-ChildItem "$tempRoot\*" -Filter "boot.img" -Recurse | Select-Object -First 1 | Select-Object -ExpandProperty FullName

if (-not $bootImgPath) {
    throw "boot.img not found in extracted rootfs"
}

$bootSize = (Get-Item $bootImgPath).Length
$bootKB = [math]::Round($bootSize / 1KB, 2)
$bootMB = [math]::Round($bootSize / 1MB, 2)

Write-Host "boot.img size: $$bootKB KB ($$bootMB MB)" -ForegroundColor Green
if ($bootSize -gt 8388608) {
    Write-Host "WARNING: boot.img exceeds 8 MB BOOT partition limit!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "boot.img is within the 8 MB BOOT partition limit." -ForegroundColor Green
}

# Package artifacts
Write-Host ""
Write-Host "Packaging artifacts..." -ForegroundColor Yellow

if (!(Test-Path $ARTIFACTS_DIR)) {
    New-Item -ItemType Directory -Force -Path $ARTIFACTS_DIR | Out-Null
}

Copy-Item $zipFile.FullName -Destination "$ARTIFACTS_DIR" -Force
Copy-Item $bootImgPath -Destination "$ARTIFACTS_DIR\boot.img" -Force

$checksumFile = "$ARTIFACTS_DIR\SHA256SUMS"
Get-ChildItem "$ARTIFACTS_DIR" | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    Add-Content -Path $checksumFile -Value "$$($hash)  $$($_.Name)"
}

Write-Host "Artifacts packaged in: $$ARTIFACTS_DIR" -ForegroundColor Green
Get-ChildItem "$ARTIFACTS_DIR" | Format-Table Name, Length, LastWriteTime -AutoSize

Write-Host ""
Write-Host "Step 6 complete!" -ForegroundColor Green
