# Install pmbootstrap 3.12.1 from GitLab and apply the dash-safe binfmt patch fix

Write-Host "Installing pmbootstrap 3.12.1..." -ForegroundColor Cyan

$WORK_DIR = "$env:USERPROFILE\.local"
New-Item -ItemType Directory -Force -Path $WORK_DIR | Out-Null

$PMBOOTSTRAP_DIR = "$WORK_DIR\pmbootstrap"

# Clone pmbootstrap from GitLab (not PyPI)
git clone --depth=1 --branch 3.12.1 `
    https://gitlab.nura.eco/postMarketOS/pmbootstrap.git `
    "$PMBOOTSTRAP_DIR"

Write-Host "Installing pmbootstrap..." -ForegroundColor Cyan
# Use the full path to python from the local installation
$PYTHON_EXE = "C:\Users\ADAM\AppData\Local\Programs\Python\Python315\python.exe"
& $PYTHON_EXE -m pip install --user --break-system-packages "$PMBOOTSTRAP_DIR"

# Add to PATH immediately (affects current session)
$PATH_ADD = ";$env:USERPROFILE\.local\bin;C:\Users\ADAM\AppData\Roaming\Python\Python315\Scripts"
$env:PATH += $PATH_ADD

Write-Host "Added to PATH:" -ForegroundColor Yellow
Write-Host "  $env:USERPROFILE\.local\bin" -ForegroundColor Cyan
Write-Host "  C:\Users\ADAM\AppData\Roaming\Python\Python315\Scripts" -ForegroundColor Cyan

# Verify pmbootstrap is available
Write-Host ""
Write-Host "Verifying pmbootstrap..." -ForegroundColor Yellow
if (Get-Command pmbootstrap -ErrorAction SilentlyContinue) {
    Write-Host "pmbootstrap found: $(Get-Command pmbootstrap).Source" -ForegroundColor Green
} else {
    Write-Host "WARNING: pmbootstrap not found in PATH!" -ForegroundColor Red
    exit 1
}

# Apply binfmt patch fix using full python path
$BINFMT_PATCH = "$PSScriptRoot\ci-patch\binfmt_patch.py"
if (Test-Path $BINFMT_PATCH) {
    & $PYTHON_EXE "$BINFMT_PATCH" "$PMBOOTSTRAP_DIR/.local/lib/python*/site-packages/pmb/chroot/binfmt.py"
    Write-Host "Binfmt patch applied." -ForegroundColor Green
}

Write-Host ""
Write-Host "pmbootstrap installed successfully!" -ForegroundColor Green
Write-Host "Version: $(pmbootstrap --version)" -ForegroundColor Green

# Now run the full build
Write-Host ""
Write-Host "Starting full build pipeline..." -ForegroundColor Cyan
& "$PSScriptRoot\build-all.ps1" -OutputDir "$PSScriptRoot\output" -Password "1234"
