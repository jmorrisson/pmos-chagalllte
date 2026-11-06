# =============================================================================
# pmos-chagalllte Full Build Automation
# Builds postmarketOS for Samsung Galaxy Tab S 10.5 LTE (SM-T805/T805Y)
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$OutputDir = "$PSScriptRoot\output",

    [Parameter(Mandatory=$false)]
    [bool]$SkipChecksums = $false,

    [Parameter(Mandatory=$false)]
    [string]$Password = "1234"
)

# Configuration
$PMBOOTSTRAP_VERSION = "3.12.1"
$PMPORTS_BRANCH = "main"
$WORK_DIR = "$PSScriptRoot\.local"
$CHROOT_DIR = "$WORK_DIR\chroot_buildroot_armv7"
$APORTS_DIR = "$WORK_DIR\pmaports"
$DEVICE_APORT = "device-samsung-chagalllte"
$KERNEL_APORT = "linux-samsung-chagalllte"

# Logging
$LOG_FILE = "$OutputDir\build.log"
function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Cyan
    Add-Content -Path $LOG_FILE -Value "$timestamp $Message"
}

function LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Add-Content -Path $LOG_FILE -Value "[ERROR] $Message"
}

# =============================================================================
# STEP 0: Pre-flight checks
# =============================================================================
Write-Host ""
Write-Host "Starting pmos-chagalllte Full Build Automation v1.0"
Write-Host ""

$tools = @("pmbootstrap", "python3", "wsl")
$missingTools = @()
foreach ($tool in $tools) {
    if (!(Get-Command $tool -ErrorAction SilentlyContinue)) {
        $missingTools += $tool
    }
}

if ($missingTools.Count -gt 0) {
    Write-Host "Missing tools: $($missingTools -join ", ")" -ForegroundColor Yellow
    exit 1
}

$wsl = Get-Command wsl -ErrorAction SilentlyContinue
if (-not $wsl) {
    LogError "WSL is not installed."
    exit 1
}

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

Log "Starting full build pipeline..."
Add-Content -Path $LOG_FILE -Value "=== Full Build Pipeline Started: $(Get-Date) ==="

# =============================================================================
# STEP 1: Install pmbootstrap
# =============================================================================
Write-Host ""
Write-Host "Step 1: Installing pmbootstrap $PMBOOTSTRAP_VERSION..."

$PMBOOTSTRAP_DIR = "$WORK_DIR\pmbootstrap"
if (!(Test-Path $PMBOOTSTRAP_DIR)) {
    Log "Cloning pmbootstrap $PMBOOTSTRAP_VERSION..."
    git clone --depth=1 --branch $PMBOOTSTRAP_VERSION `
        https://gitlab.postmarketos.org/postMarketOS/pmbootstrap.git `
        "$PMBOOTSTRAP_DIR"
}

Write-Host "Installing pmbootstrap..."
python3 -m pip install --user --break-system-packages "$PMBOOTSTRAP_DIR"

$PATH_ADD = "$WORK_DIR\.local\bin"
if (!(Test-Path $PATH_ADD)) { New-Item -ItemType Directory -Force -Path $PATH_ADD | Out-Null }
[Environment]::SetEnvironmentVariable("PATH", "$env:PATH;$PATH_ADD", [System.EnvironmentVariableTarget]::User)
Write-Host "Added to PATH: $PATH_ADD"

# =============================================================================
# STEP 2: Apply binfmt patch fix
# =============================================================================
Write-Host ""
Write-Host "Step 2: Applying dash-safe binfmt patch..."

$BINFMT_PATCH = "$PSScriptRoot\ci-patch\binfmt_patch.py"
if (!(Test-Path $BINFMT_PATCH)) {
    LogError "binfmt_patch.py not found at: $BINFMT_PATCH"
    exit 1
}

Log "Applying patch to pmbootstrap binfmt.py..."
python3 "$BINFMT_PATCH" "$PMBOOTSTRAP_DIR/.local/lib/python*/site-packages/pmb/chroot/binfmt.py"

# =============================================================================
# STEP 3: Clone pmaports
# =============================================================================
Write-Host ""
Write-Host "Step 3: Cloning pmaports ($PMPORTS_BRANCH)..."

if (!(Test-Path $APORTS_DIR)) {
    Log "Cloning pmaports from GitLab..."
    git clone --depth=1 --branch $PMPORTS_BRANCH `
        https://gitlab.postmarketos.org/postMarketOS/pmaports.git `
        "$APORTS_DIR"
}

# =============================================================================
# STEP 4: Install aport overlay
# =============================================================================
Write-Host ""
Write-Host "Step 4: Installing aports overlay..."

$DEV_APORT_DIR = "$APORTS_DIR/device/$DEVICE_APORT"
if (!(Test-Path $DEV_APORT_DIR)) {
    Log "Copying device aport to pmaports..."
    Copy-Item -Path "$PSScriptRoot\overlay\device\testing\$DEVICE_APORT" `
        -Destination "$APORTS_DIR/device/$DEVICE_APORT" -Recurse -Force
}

$KERN_APORT_DIR = "$APORTS_DIR/linux/$KERNEL_APORT"
if (!(Test-Path $KERN_APORT_DIR)) {
    Log "Copying kernel aport to pmaports..."
    mkdir -p "$KERN_APORT_DIR"
    Copy-Item -Path "$PSScriptRoot\overlay\device\testing\$KERNEL_APORT\*" `
        -Destination "$KERN_APORT_DIR\" -Recurse -Force
}

# =============================================================================
# STEP 5: Seed pmbootstrap config
# =============================================================================
Write-Host ""
Write-Host "Step 5: Seeding pmbootstrap configuration..."

$CONFIG_FILE = "$env:HOME\.config\pmbootstrap_v3.cfg"
$VERSION_FILE = "$WORK_DIR\version"

New-Item -ItemType Directory -Force -Path $env:HOME\.config | Out-Null
New-Item -ItemType Directory -Force -Path $WORK_DIR | Out-Null

python3 -c "import pmb.config; print(pmb.config.work_version)" > $VERSION_FILE

$configContent = @"
[general]
device=$DEVICE_APORT
kernel=downstream
ui=mate
service_manager=openrc
auto_zap_misconfigured_chroots=yes
"@

Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8

Write-Host "Config seeded successfully"

# =============================================================================
# STEP 6: Build
# =============================================================================
Write-Host ""
Write-Host "Step 6: Building image (this may take 40-70 minutes)..."
Log "Starting pmbootstrap install..."

$BUILD_START = Get-Date
try {
    pmbootstrap install `
        --android-recovery-zip `
        --recovery-install-partition USERDATA `
        --password $Password

    $BUILD_DURATION = [math]::Round((Get-Date - $BUILD_START).TotalMinutes, 1)
    Write-Host "Build completed in $BUILD_DURATION minutes"
} catch {
    LogError "Build failed: $_"
    exit 1
}

# =============================================================================
# STEP 7: Copy buildroot binaries
# =============================================================================
Write-Host ""
Write-Host "Step 7: Providing build-time dependencies in chroot..."

$CHROOT_BIN = "$CHROOT_DIR\usr\bin"
mkdir -p $CHROOT_BIN

if (Test-Path "$CHROOT_DIR\usr\bin\mkbootimg-1.apk\unstripped\mkbootimg") {
    Copy-Item "$CHROOT_DIR\usr\bin\mkbootimg-1.apk\unstripped\mkbootimg" `
        -Destination "$CHROOT_BIN\mkbootimg" -Force
    Write-Host "Copied mkbootimg to chroot."
} else {
    Write-Host "Warning: mkbootimg not found in buildroot output" -ForegroundColor Yellow
}

if (Test-Path "$CHROOT_DIR\usr\bin\msm-fb-refresher-1.apk\unstripped\msm-fb-refresher") {
    Copy-Item "$CHROOT_DIR\usr\bin\msm-fb-refresher-1.apk\unstripped\msm-fb-refresher" `
        -Destination "$CHROOT_BIN\msm-fb-refresher" -Force
    Write-Host "Copied msm-fb-refresher to chroot."
}

Log "postmarketos-base-downstream-disable-udev-v4l: no binary needed (no-op package)"
Log "postmarketos-base: no binary needed (no-op package)"

# =============================================================================
# STEP 8: Verify boot image size
# =============================================================================
Write-Host ""
Write-Host "Step 8: Verifying boot.img size..."

$ZIP_FILE = Get-ChildItem "$CHROOT_DIR\var\lib\postmarketos-android-recovery-installer\pmOS-*.zip" | Select-Object -First 1
if (-not $ZIP_FILE) {
    LogError "No recovery zip found."
    exit 1
}

Write-Host "Found: $($ZIP_FILE.Name)"

$tempRoot = "$OutputDir\temp_rootfs"
if (!(Test-Path $tempRoot)) {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
}

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZIP_FILE.FullName, $tempRoot)
} catch {
    LogError "Failed to extract zip: $_"
    exit 1
}

$BOOT_IMG_PATH = "$tempRoot\boot.img"
if (!(Test-Path $BOOT_IMG_PATH)) {
    $BOOT_IMG_PATH = Get-ChildItem "$tempRoot" -Filter "boot.img" -Recurse | Select-Object -First 1 | Select-Object -ExpandProperty FullName
}

if (-not (Test-Path $BOOT_IMG_PATH)) {
    LogError "boot.img not found in extracted rootfs"
    exit 1
}

$BOOT_SIZE = (Get-Item $BOOT_IMG_PATH).Length
$BOOT_KILOBYTES = [math]::Round($BOOT_SIZE / 1024, 2)
$BOOT_MB = [math]::Round($BOOT_SIZE / 1MB, 2)

Write-Host "boot.img size: $BOOT_KILOBYTES KB ($BOOT_MB MB)" -ForegroundColor Green
if ($BOOT_SIZE -gt 8388608) {
    Write-Host "WARNING: boot.img exceeds 8 MB BOOT partition limit!" -ForegroundColor Red
} else {
    Write-Host "boot.img is within 8 MB BOOT partition limit" -ForegroundColor Green
}

# =============================================================================
# STEP 9: Package artifacts
# =============================================================================
Write-Host ""
Write-Host "Step 9: Packaging artifacts..."

$ARTIFACTS_DIR = "$OutputDir\artifacts"
New-Item -ItemType Directory -Force -Path $ARTIFACTS_DIR | Out-Null

try {
    Copy-Item $ZIP_FILE.FullName -Destination "$ARTIFACTS_DIR" -Force
    Copy-Item $BOOT_IMG_PATH -Destination "$ARTIFACTS_DIR\boot.img" -Force

    $checksumFile = "$ARTIFACTS_DIR\SHA256SUMS"
    Get-ChildItem "$ARTIFACTS_DIR" | ForEach-Object {
        $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
        Write-Host "$($hash)  $$($_.Name)"
        Add-Content -Path $checksumFile -Value "$($hash)  $$($_.Name)"
    }

    Write-Host "Artifacts packaged successfully"
    Write-Host ""
    Write-Host "Artifacts location: $ARTIFACTS_DIR"
    Write-Host ""
    Get-ChildItem "$ARTIFACTS_DIR" | Format-Table Name, Length, LastWriteTime -AutoSize

} catch {
    LogError "Failed to package artifacts: $_"
    exit 1
}

# =============================================================================
# Done
# =============================================================================
Write-Host ""
Write-Host "Build complete! Artifacts in: $ARTIFACTS_DIR" -ForegroundColor Green
Write-Host "Full log: $LOG_FILE" -ForegroundColor Cyan

Add-Content -Path $LOG_FILE -Value "=== Build Pipeline Completed: $(Get-Date) ==="

exit 0
