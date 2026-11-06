# =============================================================================
# Step 1: Install pmbootstrap and apply binfmt patch fix
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$PmbootstrapVersion = "3.12.1",

    [Parameter(Mandatory=$false)]
    [string]$WorkDir = "$env:USERPROFILE\.local\var\pmbootstrap"
)

Write-Host "=== Step 1: Install pmbootstrap $PmbootstrapVersion ===" -ForegroundColor Cyan

$PMBOOTSTRAP_DIR = "$WorkDir\pmbootstrap"
$BINFMT_PATCH = "$PSScriptRoot\ci-patch\binfmt_patch.py"

# Clone pmbootstrap
if (!(Test-Path $PMBOOTSTRAP_DIR)) {
    Write-Host "Cloning pmbootstrap $PmbootstrapVersion..." -ForegroundColor Yellow
    git clone --depth=1 --branch $PmbootstrapVersion `
        https://gitlab.postmarketos.org/postMarketOS/pmbootstrap.git "$PMBOOTSTRAP_DIR"
} else {
    Write-Host "pmbootstrap already installed, skipping." -ForegroundColor Green
}

# Install pmbootstrap
Write-Host "Installing pmbootstrap..." -ForegroundColor Yellow
python3 -m pip install --user --break-system-packages "$PMBOOTSTRAP_DIR"

# Add to PATH
$PATH_ADD = "$WorkDir\.local\bin"
if (!(Test-Path $PATH_ADD)) { New-Item -ItemType Directory -Force -Path $PATH_ADD | Out-Null }
$env:PATH += ";$PATH_ADD"

# Verify installation
Write-Host "Verifying pmbootstrap..." -ForegroundColor Yellow
$version = & "$PMBOOTSTRAP_DIR\.local\bin\pmbootstrap" --version
Write-Host "  pmbootstrap version: $version" -ForegroundColor Green

# Apply binfmt patch fix
Write-Host ""
Write-Host "Applying dash-safe binfmt patch..." -ForegroundColor Yellow
if (Test-Path $BINFMT_PATCH) {
    python3 "$BINFMT_PATCH" "$PMBOOTSTRAP_DIR\.local\lib\python*/site-packages/pmb/chroot/binfmt.py"
    Write-Host "  Binfmt patch applied." -ForegroundColor Green
} else {
    Write-Host "  Warning: binfmt_patch.py not found, skipping." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 1 complete!" -ForegroundColor Green
