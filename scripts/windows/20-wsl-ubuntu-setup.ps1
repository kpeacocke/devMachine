<#
WSL Ubuntu Setup with Unattended Installation Support
Handles Ubuntu installation, initialization, and unattended user creation.
#>
$ErrorActionPreference = 'Stop'

# Load unattended mode override if available
if ($env:DEVMACHINE_UNATTENDED -eq "true" -and $env:DEVMACHINE_OVERRIDE_PATH -and (Test-Path $env:DEVMACHINE_OVERRIDE_PATH)) {
    . $env:DEVMACHINE_OVERRIDE_PATH
}

Write-Host "[WSL] Setting up Ubuntu in WSL..."

# Check if WSL is enabled. The DISM PowerShell cmdlets can fail with
# "Class not registered" in current PowerShell 7 builds, so Windows servicing
# is queried in the inbox Windows PowerShell 5.1 host.
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path $windowsPowerShell)) {
    throw "Windows PowerShell 5.1 not found at $windowsPowerShell"
}

$wslFeatureState = (& $windowsPowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command `
    "(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction Stop).State" | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Failed to query the WSL Windows feature using Windows PowerShell 5.1 (exit code $LASTEXITCODE)"
}

if ($wslFeatureState -ne 'Enabled') {
    Write-Host "  ❌ WSL feature not enabled. Run the main setup script first." -ForegroundColor Red
    return
}

# Install Ubuntu if not present
$ubuntuStatus = wsl -l -v 2>&1 | Select-String "Ubuntu"
if (-not $ubuntuStatus) {
    Write-Host "  📦 Installing Ubuntu..." -ForegroundColor Cyan

    if ($env:INSTALL_WSL_IN_VM -eq "false") {
        Write-Host "  ⚠️  WSL installation skipped (VM environment detected)" -ForegroundColor Yellow
        return
    }

    # Install Ubuntu from Microsoft Store
    try {
        wsl --install Ubuntu --no-launch
        Write-Host "  ✅ Ubuntu installed" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to install Ubuntu via wsl --install, trying winget..."
        winget install Canonical.Ubuntu --source msstore --silent --accept-source-agreements --accept-package-agreements
    }
} else {
    Write-Host "  ✅ Ubuntu is already installed" -ForegroundColor Green
}

# Check if Ubuntu has been initialized (has a user account)
Write-Host "  🔍 Checking Ubuntu initialization status..." -ForegroundColor Cyan
$ubuntuInitialized = $false

try {
    $testResult = wsl -d Ubuntu -e whoami 2>&1
    if ($LASTEXITCODE -eq 0 -and $testResult -notmatch "error\|failed\|denied") {
        $ubuntuInitialized = $true
        Write-Host "  ✅ Ubuntu is initialized with user: $testResult" -ForegroundColor Green
    }
} catch {
    Write-Host "  ℹ️  Ubuntu needs first-time setup" -ForegroundColor Yellow
}

# Handle Ubuntu initialization
if (-not $ubuntuInitialized) {
    if ($env:UNATTENDED_MODE -eq "true" -or $env:DEVMACHINE_UNATTENDED -eq "true") {
        Write-Host "  🤖 Unattended mode: Attempting automated Ubuntu setup..." -ForegroundColor Cyan

        # Try to create default user non-interactively
        $defaultUser = if ($env:WSL_DEFAULT_USER) { $env:WSL_DEFAULT_USER } else { $env:USERNAME.ToLower() }
        $defaultPass = if ($env:WSL_DEFAULT_PASSWORD) { $env:WSL_DEFAULT_PASSWORD } else { "devmachine123" }

        Write-Host "  👤 Creating user '$defaultUser' with default password..." -ForegroundColor Yellow
        Write-Host "  ⚠️  Change the password after setup: wsl -d Ubuntu passwd" -ForegroundColor Yellow

        try {
            # Create user using Ubuntu's built-in mechanism
            $userAddCommand = "useradd -m -s /bin/bash $defaultUser && printf '%s:%s\n' '$defaultUser' '$defaultPass' | chpasswd && usermod -aG sudo $defaultUser"
            wsl -d Ubuntu -u root -e bash -c $userAddCommand

            # Set default user for Ubuntu
            ubuntu config --default-user $defaultUser

            # Test the setup
            $testUser = wsl -d Ubuntu -e whoami 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Ubuntu initialized with user: $testUser" -ForegroundColor Green
                $ubuntuInitialized = $true
            }
        } catch {
            Write-Warning "Automated Ubuntu setup failed: $_"
            Write-Host "  ⚠️  Manual setup required. Run: wsl -d Ubuntu" -ForegroundColor Yellow
            Write-Host "  📋 After manual setup, re-run this script or continue with bootstrap" -ForegroundColor Yellow
            return
        }
    } else {
        Write-Host "  👤 Interactive Ubuntu Setup Required" -ForegroundColor Yellow
        Write-Host "     Ubuntu needs a username and password to be created." -ForegroundColor Yellow
        Write-Host "     This will open Ubuntu for first-time setup..." -ForegroundColor Yellow

        $proceed = Read-Host "  Continue with Ubuntu setup? (Y/N) [Default: Y]"
        if ([string]::IsNullOrWhiteSpace($proceed)) { $proceed = 'Y' }

        if ($proceed -eq 'Y') {
            Write-Host "  🚀 Opening Ubuntu for setup..." -ForegroundColor Cyan
            Write-Host "     Complete the username/password setup, then close Ubuntu." -ForegroundColor Gray

            Start-Process ubuntu -Wait

            # Verify setup completed
            try {
                $testUser = wsl -d Ubuntu -e whoami 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✅ Ubuntu setup completed with user: $testUser" -ForegroundColor Green
                    $ubuntuInitialized = $true
                } else {
                    Write-Warning "Ubuntu setup verification failed"
                    return
                }
            } catch {
                Write-Warning "Could not verify Ubuntu setup"
                return
            }
        } else {
            Write-Host "  ⚠️  Ubuntu setup skipped. Run 'ubuntu' or 'wsl -d Ubuntu' manually." -ForegroundColor Yellow
            return
        }
    }
}

# Run Ubuntu bootstrap if initialized
if ($ubuntuInitialized) {
    Write-Host "  🔧 Running Ubuntu bootstrap..." -ForegroundColor Cyan

    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $WSLScripts = Join-Path $ScriptRoot "scripts\wsl"
    $ubuntuBootstrap = Join-Path $WSLScripts "20-ubuntu-bootstrap.sh"
    $ubuntuTune = Join-Path $WSLScripts "21-wsl-tune.sh"

    if (-not (Test-Path $ubuntuBootstrap)) {
        Write-Warning "Ubuntu bootstrap script not found: $ubuntuBootstrap"
        return
    }

    try {
        # Copy scripts to WSL using stdin so Windows path syntax is never passed
        # to Linux utilities.
        wsl -d Ubuntu -e mkdir -p /tmp/setup
        $ubuntuBootstrapContent = Get-Content $ubuntuBootstrap -Raw
        $ubuntuTuneContent = Get-Content $ubuntuTune -Raw
        $ubuntuBootstrapContent | wsl -d Ubuntu -e tee /tmp/setup/20-ubuntu-bootstrap.sh > $null
        $ubuntuTuneContent | wsl -d Ubuntu -e tee /tmp/setup/21-wsl-tune.sh > $null
        wsl -d Ubuntu -e chmod +x /tmp/setup/20-ubuntu-bootstrap.sh
        wsl -d Ubuntu -e chmod +x /tmp/setup/21-wsl-tune.sh

        Write-Host "  📦 Installing development tools (this may take 15-30 minutes)..." -ForegroundColor Cyan
        wsl -d Ubuntu -e bash /tmp/setup/20-ubuntu-bootstrap.sh

        Write-Host "  ⚙️  Applying WSL optimizations..." -ForegroundColor Cyan
        wsl -d Ubuntu -e bash /tmp/setup/21-wsl-tune.sh

        Write-Host "  ✅ Ubuntu development environment ready!" -ForegroundColor Green

        Write-Host "  🔄 Shutting down WSL to apply .wslconfig changes..." -ForegroundColor Yellow
        wsl --shutdown
        Write-Host "  ✅ WSL restart complete" -ForegroundColor Green

    } catch {
        Write-Warning "Ubuntu bootstrap failed: $_"
        Write-Host "  📋 You can run the scripts manually:" -ForegroundColor Yellow
        Write-Host "     wsl -d Ubuntu -e bash $WSLScripts/20-ubuntu-bootstrap.sh" -ForegroundColor Gray
        Write-Host "     wsl -d Ubuntu -e bash $WSLScripts/21-wsl-tune.sh" -ForegroundColor Gray
    }
} else {
    Write-Host "  ⚠️  Ubuntu not properly initialized. Manual setup required." -ForegroundColor Yellow
}

Write-Host "[OK] WSL Ubuntu setup complete!" -ForegroundColor Green
