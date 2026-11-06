# =============================================================================
# Step 4: Install aports overlay (device + kernel)
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$AportsDir = "$env:USERPROFILE\.local\var\pmbootstrap\cache_git\pmaports",

    [Parameter(Mandatory=$false)]
    [string]$DeviceAport = "device-samsung-chagalllte",

    [Parameter(Mandatory=$false)]
    [string]$KernelAport = "linux-samsung-chagalllte"
)

Write-Host "=== Step 4: Install aports overlay ===" -ForegroundColor Cyan

$APORTS_DIR = $AportsDir
$DEV_APORT_SRC = "$PSScriptRoot\overlay\device\testing\$DeviceAport"
$KERN_APORT_SRC = "$PSScriptRoot\overlay\device\testing\$KernelAport"

# Verify source exists
if (!(Test-Path $DEV_APORT_SRC)) {
    throw "Device aport not found at: $DEV_APORT_SRC"
}
if (!(Test-Path $KERN_APORT_SRC)) {
    throw "Kernel aport not found at: $KERN_APORT_SRC"
}

# Remove upstream duplicates (archived versions)
$upstreamDev = "$APORTS_DIR\device\archived\$DeviceAport"
$upstreamKern = "$APORTS_DIR\linux\archived\$KernelAport"

if (Test-Path $upstreamDev) {
    Remove-Item -Recurse -Force $upstreamDev
    Write-Host "  Removed upstream duplicate: $DeviceAport" -ForegroundColor Yellow
}

if (Test-Path $upstreamKern) {
    Remove-Item -Recurse -Force $upstreamKern
    Write-Host "  Removed upstream duplicate: $KernelAport" -ForegroundColor Yellow
}

# Install device aport
$devDest = "$APORTS_DIR\device\$DeviceAport"
if (!(Test-Path $devDest)) {
    New-Item -ItemType Directory -Force -Path $devDest | Out-Null
}
Copy-Item -Path $DEV_APORT_SRC -Destination $devDest -Recurse -Force
Write-Host "  Installed: $DeviceAport" -ForegroundColor Green

# Install kernel aport (flat structure, not in a subdirectory)
$kernDest = "$APORTS_DIR\linux\$KernelAport"
if (!(Test-Path $kernDest)) {
    New-Item -ItemType Directory -Force -Path $kernDest | Out-Null
}
Copy-Item -Path $KERN_APORT_SRC\* -Destination $kernDest -Recurse -Force
Write-Host "  Installed: $KernelAport" -ForegroundColor Green

# Copy deviceinfo from archived version (testing aport lacks it)
$archivedDev = "$APORTS_DIR\device\archived\$DeviceAport\deviceinfo"
if (Test-Path $archivedDev) {
    $devDestInfo = "$devDest\deviceinfo"
    if (!(Test-Path $devDestInfo)) {
        Copy-Item -Path $archivedDev -Destination $devDestInfo -Force
        Write-Host "  Copied deviceinfo from archived version." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Step 4 complete!" -ForegroundColor Green
