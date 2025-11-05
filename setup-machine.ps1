<#
.SYNOPSIS
    Surface Pro Dev Machine - Complete Setup Orchestrator

.DESCRIPTION
    Runs all setup scripts in the correct order to fully configure a new Surface Pro
    development machine. Handles Windows setup, WSL/Ubuntu, hardening, optimization,
    and optional components.

.PARAMETER SkipBackup
    Skip backup configuration (Backblaze, File History)

.PARAMETER SkipOptionalGoodies
    Skip optional dev tools (Sysinternals, mkcert, k8s tools, etc.)

.PARAMETER SkipInsiders
    Skip Windows/Office/VSCode Insider channel setup

.PARAMETER ScheduleDotNetMaintenance
    Create weekly scheduled task for .NET SDK maintenance

.PARAMETER SetUltimatePerformance
    Immediately activate Ultimate Performance power plan

.PARAMETER DevDrivePath
    Path to Dev Drive for caches (default: D:\dev\caches)

.EXAMPLE
    .\setup-machine.ps1
    Run full setup with defaults

.EXAMPLE
    .\setup-machine.ps1 -SkipInsiders -ScheduleDotNetMaintenance
    Skip Insider channels, enable .NET weekly maintenance
#>

[CmdletBinding()]
param(
    [switch]$SkipBackup,
    [switch]$SkipOptionalGoodies,
    [switch]$SkipInsiders,
    [switch]$ScheduleDotNetMaintenance,
    [switch]$SetUltimatePerformance,
    [string]$DevDrivePath = "D:\dev\caches"
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = $PSScriptRoot
$WindowsScripts = Join-Path $ScriptRoot "scripts\windows"
$WSLScripts = Join-Path $ScriptRoot "scripts\wsl"

function Write-Step {
    param([string]$Message)
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $($Message.PadRight(60)) ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

function Invoke-Script {
    param(
        [string]$Path,
        [string]$Description,
        [hashtable]$Arguments = @{}
    )
    
    Write-Step $Description
    
    if (-not (Test-Path $Path)) {
        Write-Warning "Script not found: $Path - SKIPPING"
        return
    }
    
    try {
        if ($Arguments.Count -gt 0) {
            & $Path @Arguments
        } else {
            & $Path
        }
        Write-Host "✅ $Description - COMPLETED" -ForegroundColor Green
    } catch {
        Write-Error "❌ $Description - FAILED: $_"
        $continue = Read-Host "Continue with remaining steps? (Y/N)"
        if ($continue -ne 'Y') { exit 1 }
    }
}

function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

Write-Host @"

╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║     Surface Pro Dev Machine - Complete Setup Orchestrator            ║
║                                                                       ║
║     This will configure your Surface Pro as a fully-featured         ║
║     development machine with security hardening and optimization     ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

if (-not (Test-AdminPrivileges)) {
    Write-Error "❌ This script must be run as Administrator. Right-click PowerShell and 'Run as Administrator'"
    exit 1
}

Write-Host "✅ Running with Administrator privileges`n" -ForegroundColor Green

# Estimate time
Write-Host "⏱️  Estimated time: 45-90 minutes (depending on download speeds)" -ForegroundColor Yellow
Write-Host "📦 This will install ~30GB of software and tools`n" -ForegroundColor Yellow

$confirm = Read-Host "Ready to begin? (Y/N)"
if ($confirm -ne 'Y') {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

# ============================================================================
# PHASE 1: POWERSHELL & TERMINAL FOUNDATION
# ============================================================================

Write-Step "PHASE 1: PowerShell 7 & Windows Terminal"
Invoke-Script -Path (Join-Path $WindowsScripts "00-pwsh-first.ps1") `
    -Description "Install PowerShell 7 and configure Windows Terminal"

Write-Host "`n⚠️  IMPORTANT: Close this window and open a NEW Windows Terminal (Admin)" -ForegroundColor Yellow
Write-Host "   Then re-run this script to continue.`n" -ForegroundColor Yellow
$continue = Read-Host "Press Enter when you've opened a new PowerShell 7 terminal, or Ctrl+C to exit"

# ============================================================================
# PHASE 2: CORE WINDOWS TOOLING
# ============================================================================

Write-Step "PHASE 2: Core Development Tools"
Invoke-Script -Path (Join-Path $WindowsScripts "10-windows-bootstrap.ps1") `
    -Description "Install VS Code, Docker, WSL, Git, runtimes, cloud CLIs"

# ============================================================================
# PHASE 3: OPTIMIZE & HARDEN
# ============================================================================

Write-Step "PHASE 3: Security Hardening & Optimization"
Invoke-Script -Path (Join-Path $WindowsScripts "30-optimize-and-harden.ps1") `
    -Description "Firewall, Defender, BitLocker, Credential Guard, WSL config"

# ============================================================================
# PHASE 4: PERFORMANCE TUNING
# ============================================================================

Write-Step "PHASE 4: Performance Tuning"
$perfArgs = @{}
if ($SetUltimatePerformance) {
    $perfArgs['SetUltimateNow'] = $true
}
if ($DevDrivePath) {
    $perfArgs['DevCachePath'] = $DevDrivePath
}
Invoke-Script -Path (Join-Path $WindowsScripts "31-performance-tuning.ps1") `
    -Description "Storage cleanup, indexing, Windows Search, network tuning" `
    -Arguments $perfArgs

# ============================================================================
# PHASE 5: POWER PLAN AUTO-TOGGLE
# ============================================================================

Write-Step "PHASE 5: Power Plan Automation"
Invoke-Script -Path (Join-Path $WindowsScripts "32-powerplan-auto-toggle.ps1") `
    -Description "Auto-switch: AC→Ultimate, Battery→Balanced"

# ============================================================================
# PHASE 6: DEV DRIVE CACHE RELOCATION
# ============================================================================

Write-Step "PHASE 6: Dev Drive Cache Setup"
Invoke-Script -Path (Join-Path $WindowsScripts "40-devdrive-caches.ps1") `
    -Description "Move npm/cargo/go/maven/docker to Dev Drive"

# ============================================================================
# PHASE 7: OPTIONAL GOODIES
# ============================================================================

if (-not $SkipOptionalGoodies) {
    Write-Step "PHASE 7: Optional Dev Tools"
    Invoke-Script -Path (Join-Path $WindowsScripts "33-optional-dev-goodies.ps1") `
        -Description "Sysinternals, mkcert, ripgrep, security tools, k8s CLIs"
}

# ============================================================================
# PHASE 8: .NET MAINTENANCE
# ============================================================================

Write-Step "PHASE 8: .NET SDK Maintenance"
$dotnetArgs = @{}
if ($ScheduleDotNetMaintenance) {
    $dotnetArgs['ScheduleWeekly'] = $true
}
Invoke-Script -Path (Join-Path $WindowsScripts "60-dotnet-maintain.ps1") `
    -Description "Install latest .NET SDK, clean old versions" `
    -Arguments $dotnetArgs

# ============================================================================
# PHASE 9: BACKUP SETUP
# ============================================================================

if (-not $SkipBackup) {
    Write-Step "PHASE 9: Backup Configuration"
    Invoke-Script -Path (Join-Path $WindowsScripts "80-backup-setup.ps1") `
        -Description "Backblaze, File History, System Protection"
}

# ============================================================================
# PHASE 10: INSIDER CHANNELS (OPTIONAL)
# ============================================================================

if (-not $SkipInsiders) {
    Write-Host "`n⚠️  Windows Insider Program Setup" -ForegroundColor Yellow
    Write-Host "   This will configure Canary/Dev channels for Windows, Office, and VS Code" -ForegroundColor Yellow
    $insider = Read-Host "   Enable Insider channels? (Y/N)"
    
    if ($insider -eq 'Y') {
        Write-Step "PHASE 10: Insider Channels"
        Invoke-Script -Path (Join-Path $WindowsScripts "70-insiders-optin.ps1") `
            -Description "Windows Canary, Office Beta, VS Code Insiders"
        
        Invoke-Script -Path (Join-Path $WindowsScripts "72-vscode-insiders-setup.ps1") `
            -Description "VS Code Insiders profile & extensions"
    }
}

# ============================================================================
# PHASE 11: WSL/UBUNTU SETUP
# ============================================================================

Write-Host "`n⚠️  WSL/Ubuntu Setup" -ForegroundColor Yellow
Write-Host "   The next steps will configure Ubuntu in WSL" -ForegroundColor Yellow
Write-Host "   First, let's ensure Ubuntu is initialized..." -ForegroundColor Yellow

# Check if Ubuntu needs first-run setup
try {
    $ubuntuStatus = wsl -l -v 2>&1 | Select-String "Ubuntu"
    if ($ubuntuStatus) {
        Write-Host "✅ Ubuntu is installed" -ForegroundColor Green
        
        # Test if Ubuntu has been initialized
        wsl -d Ubuntu -e whoami 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "`n⚠️  Ubuntu needs first-time setup (create username/password)" -ForegroundColor Yellow
            Write-Host "   Opening Ubuntu... complete the setup, then close it and press Enter here`n" -ForegroundColor Yellow
            Start-Process wsl -ArgumentList "-d Ubuntu"
            Read-Host "Press Enter after Ubuntu setup is complete"
        }
        
        Write-Step "PHASE 11: Ubuntu Bootstrap"
        Write-Host "Copying Ubuntu bootstrap script to WSL..." -ForegroundColor Cyan
        
        $ubuntuBootstrap = Join-Path $WSLScripts "20-ubuntu-bootstrap.sh"
        $ubuntuTune = Join-Path $WSLScripts "21-wsl-tune.sh"
        
        # Copy scripts to WSL
        wsl -d Ubuntu -e mkdir -p /tmp/setup
        wsl -d Ubuntu -e cp (Resolve-Path $ubuntuBootstrap).Path /tmp/setup/
        wsl -d Ubuntu -e cp (Resolve-Path $ubuntuTune).Path /tmp/setup/
        wsl -d Ubuntu -e chmod +x /tmp/setup/20-ubuntu-bootstrap.sh
        wsl -d Ubuntu -e chmod +x /tmp/setup/21-wsl-tune.sh
        
        Write-Host "Running Ubuntu bootstrap (this will take 15-30 minutes)..." -ForegroundColor Cyan
        wsl -d Ubuntu -e bash /tmp/setup/20-ubuntu-bootstrap.sh
        
        Write-Host "`nRunning WSL tune-ups..." -ForegroundColor Cyan
        wsl -d Ubuntu -e bash /tmp/setup/21-wsl-tune.sh
        
        Write-Host "✅ Ubuntu setup complete" -ForegroundColor Green
        
        Write-Host "`n⚠️  Shutting down WSL to apply .wslconfig changes..." -ForegroundColor Yellow
        wsl --shutdown
        Write-Host "✅ WSL shutdown complete. It will restart automatically when needed." -ForegroundColor Green
    }
} catch {
    Write-Warning "WSL/Ubuntu setup encountered an issue: $_"
    Write-Host "You can manually run the Ubuntu scripts later:" -ForegroundColor Yellow
    Write-Host "  wsl -d Ubuntu -e bash $WSLScripts/20-ubuntu-bootstrap.sh" -ForegroundColor Yellow
    Write-Host "  wsl -d Ubuntu -e bash $WSLScripts/21-wsl-tune.sh" -ForegroundColor Yellow
}

# ============================================================================
# FINAL STEPS & VERIFICATION
# ============================================================================

Write-Step "PHASE 12: Final Configuration"

Write-Host "`n📋 Post-Setup Checklist:" -ForegroundColor Cyan
Write-Host "  ☐ Configure Malwarebytes exclusions (see README Post-Setup section)" -ForegroundColor Yellow
Write-Host "  ☐ Configure GlassWire firewall rules (see README Post-Setup section)" -ForegroundColor Yellow
Write-Host "  ☐ Sign into Backblaze and configure exclusions (see README)" -ForegroundColor Yellow
Write-Host "  ☐ Restart Docker Desktop (Settings → data-root change)" -ForegroundColor Yellow
Write-Host "  ☐ Open 1Password and enable SSH agent (see README)" -ForegroundColor Yellow
Write-Host "  ☐ Configure VS Code settings sync" -ForegroundColor Yellow
Write-Host "  ☐ Add SSH keys to ~/.ssh/ and GitHub" -ForegroundColor Yellow
Write-Host "  ☐ Configure git identity (see README Post-Setup section)" -ForegroundColor Yellow

Write-Host "`n🧪 Run verification tests:" -ForegroundColor Cyan
Write-Host "  Windows: pwsh -File .\tests\pester.Windows.Tests.ps1" -ForegroundColor White
Write-Host "  Ubuntu:  wsl -d Ubuntu -e bash ./tests/ubuntu-smoke-test.sh" -ForegroundColor White
Write-Host "  Doctor:  pwsh -File .\scripts\windows\50-doctor.ps1 -VerboseOut" -ForegroundColor White

Write-Host "`n⚠️  REBOOT REQUIRED" -ForegroundColor Yellow
Write-Host "   Several security features require a reboot:" -ForegroundColor Yellow
Write-Host "   - Credential Guard" -ForegroundColor Yellow
Write-Host "   - LSA Protection (RunAsPPL)" -ForegroundColor Yellow
Write-Host "   - Core Isolation (HVCI)" -ForegroundColor Yellow

$reboot = Read-Host "`nReboot now? (Y/N)"
if ($reboot -eq 'Y') {
    Write-Host "`n✅ Rebooting in 10 seconds..." -ForegroundColor Green
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host "`n⚠️  Remember to reboot before running production workloads!" -ForegroundColor Yellow
}

Write-Host "`n╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                       ║" -ForegroundColor Green
Write-Host "║     🎉 Setup Complete! Your Surface Pro is ready for development     ║" -ForegroundColor Green
Write-Host "║                                                                       ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
