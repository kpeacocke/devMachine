<#
.SYNOPSIS
    Surface Pro Dev Machine - Complete Setup Orchestrator

.DESCRIPTION
    Runs all setup scripts in the correct order to fully configure a new Surface Pro
    development machine. Handles Windows setup, WSL/Ubuntu, hardening, optimization,
    and optional components.

.PARAMETER SkipBackup
    Skip backup configuration (File History, System Protection)

.PARAMETER SkipLicensedApps
    Skip commercial/licensed applications (1Password, Office, GitKraken, Beyond Compare,
    Scrivener, Obsidian, Backblaze, Malwarebytes, GlassWire).
    Use this for VMs or when you don't have licenses.

.PARAMETER SkipCommunicationsMedia
    Skip communications and media applications (Teams, WhatsApp, Signal, Slack, Discord,
    VLC, HandBrake, K-Lite Mega Codec Pack)

.PARAMETER SkipOptionalGoodies
    Skip optional dev tools (Sysinternals, mkcert, k8s tools, etc.)

.PARAMETER SkipDevDrive
    Skip Dev Drive cache relocation (for VMs or systems without ReFS support)

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

.PARAMETER SkipWSL
    Skip WSL/Ubuntu installation (use for VMs where nested virtualization isn't supported)

.EXAMPLE
    .\setup-machine.ps1 -SkipInsiders -ScheduleDotNetMaintenance
    Skip Insider channels, enable .NET weekly maintenance

.EXAMPLE
    .\setup-machine.ps1 -SkipLicensedApps -SkipDevDrive -SkipBackup -SkipWSL
    Minimal VM setup: no licensed apps, dev drive, backup, or WSL
#>

[CmdletBinding()]
param(
    [switch]$SkipBackup,
    [switch]$SkipLicensedApps,
    [switch]$SkipCommunicationsMedia,
    [switch]$SkipOptionalGoodies,
    [switch]$SkipDevDrive,
    [switch]$SkipInsiders,
    [switch]$SkipWSL,
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
    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
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
        $continue = Read-Host "Continue with remaining steps? (Y/N) [Default: Y]"
        if ([string]::IsNullOrWhiteSpace($continue)) { $continue = 'Y' }
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

========================================================================

     Surface Pro Dev Machine - Complete Setup Orchestrator

     This will configure your Surface Pro as a fully-featured
     development machine with security hardening and optimization

========================================================================

"@ -ForegroundColor Cyan

if (-not (Test-AdminPrivileges)) {
    Write-Error "❌ This script must be run as Administrator. Right-click PowerShell and 'Run as Administrator'"
    exit 1
}

Write-Host "✅ Running with Administrator privileges`n" -ForegroundColor Green

# Estimate time
Write-Host "⏱️  Estimated time: 45-90 minutes (depending on download speeds)" -ForegroundColor Yellow
Write-Host "📦 This will install ~30GB of software and tools`n" -ForegroundColor Yellow

$confirm = Read-Host "Ready to begin? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = 'Y' }
if ($confirm -ne 'Y') {
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

# ============================================================================
# PHASE 1: POWERSHELL & TERMINAL FOUNDATION
# ============================================================================

# Check if we're already running in PowerShell 7+
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Step "PHASE 1: PowerShell 7 and Windows Terminal"
    Invoke-Script -Path (Join-Path $WindowsScripts "00-pwsh-first.ps1") `
        -Description "Install PowerShell 7 and configure Windows Terminal"

    # Auto-relaunch in PowerShell 7
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        Write-Host "`n[OK] Relaunching in PowerShell 7..." -ForegroundColor Green
        $params = $PSBoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key)" }
        $argList = @('-NoExit', '-File', $MyInvocation.MyCommand.Path) + $params
        Start-Process -FilePath $pwsh.Source -ArgumentList $argList -Verb RunAs
        exit 0
    } else {
        Write-Host "`n⚠️  PowerShell 7 installed but not in PATH yet" -ForegroundColor Yellow
        Write-Host "   Close this window, open a NEW Windows Terminal (Admin), and re-run this script" -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "`n[OK] Running in PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green
}

# ============================================================================
# PHASE 2: CORE WINDOWS TOOLING
# ============================================================================

Write-Step "PHASE 2: Core Development Tools"
Invoke-Script -Path (Join-Path $WindowsScripts "10-windows-bootstrap.ps1") `
    -Description "Install VS Code, Docker, WSL, Git, runtimes, cloud CLIs"

# ============================================================================
# PHASE 2.05: WINDOWS DEBLOAT (OPTIONAL)
# ============================================================================

Write-Host "`n🗑️  Windows Debloat" -ForegroundColor Yellow
Write-Host "   Remove pre-installed bloatware: Xbox, Solitaire, Spotify, Candy Crush, etc.`n" -ForegroundColor Yellow
$debloatWindows = Read-Host "Remove Windows bloatware? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($debloatWindows)) { $debloatWindows = 'Y' }

if ($debloatWindows -eq 'Y') {
    Write-Step "PHASE 2.05: Windows Debloat"
    Invoke-Script -Path (Join-Path $WindowsScripts "09-debloat-windows.ps1") `
        -Description "Remove pre-installed bloatware and unnecessary apps"
} else {
    Write-Host "   ⭐  Skipped Windows debloat" -ForegroundColor Yellow
}

# ============================================================================
# PHASE 2.1: GIT & SSH CONFIGURATION
# ============================================================================

Write-Step "PHASE 2.1: Git & SSH Configuration"
Write-Host "🔑 Git Global Config & SSH Key Generation" -ForegroundColor Yellow
Write-Host "   This will configure Git global settings and generate SSH keys`n" -ForegroundColor Yellow
$configureGit = Read-Host "Configure Git & SSH? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($configureGit)) { $configureGit = 'Y' }

if ($configureGit -eq 'Y') {
    Invoke-Script -Path (Join-Path $WindowsScripts "05-git-ssh-config.ps1") `
        -Description "Configure Git global settings and generate SSH keys"
} else {
    Write-Host "   ⭐  Skipped Git/SSH configuration" -ForegroundColor Yellow
}

# ============================================================================
# PHASE 2.2: POWERSHELL PROFILE ENHANCEMENT
# ============================================================================

Write-Step "PHASE 2.2: PowerShell Profile Enhancement"
Write-Host "⚡ Enhanced PowerShell Profile" -ForegroundColor Yellow
Write-Host "   Oh-My-Posh, PSReadLine, posh-git, mise, aliases, helper functions`n" -ForegroundColor Yellow
$configurePowerShell = Read-Host "Configure PowerShell profile? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($configurePowerShell)) { $configurePowerShell = 'Y' }

if ($configurePowerShell -eq 'Y') {
    Invoke-Script -Path (Join-Path $WindowsScripts "06-powershell-profile.ps1") `
        -Description "Create comprehensive PowerShell profile with productivity enhancements"
} else {
    Write-Host "   ⭐  Skipped PowerShell profile configuration" -ForegroundColor Yellow
}

# ============================================================================
# PHASE 2.5: LICENSED/COMMERCIAL APPS (OPTIONAL)
# ============================================================================

if (-not $SkipLicensedApps) {
    Write-Host "💰 Commercial/Licensed Applications" -ForegroundColor Yellow
    Write-Host "   These require paid licenses or subscriptions" -ForegroundColor Yellow
    Write-Host "   Estimated cost: ~$315-505 first year, ~$205-395/year after`n" -ForegroundColor Yellow
    $installLicensed = Read-Host "Install licensed apps? (Y/N) [Default: N]"
    if ([string]::IsNullOrWhiteSpace($installLicensed)) { $installLicensed = 'N' }

    if ($installLicensed -eq 'Y') {
        Write-Step "PHASE 2.5: Licensed Applications"
        Invoke-Script -Path (Join-Path $WindowsScripts "11-licensed-apps.ps1") `
            -Description "Install 1Password, Office, GitKraken, Beyond Compare, etc."
    } else {
        Write-Host "   ⭐  Skipped licensed apps installation" -ForegroundColor Yellow
    }
} else {
    Write-Host "⭐  Skipping licensed apps (use -SkipLicensedApps:`$false to enable)" -ForegroundColor Yellow
}

# ============================================================================
# PHASE 2.6: COMMUNICATIONS & MEDIA (OPTIONAL)
# ============================================================================

if (-not $SkipCommunicationsMedia) {
    Write-Host "`n💬 Browsers, Communications & Media" -ForegroundColor Yellow
    Write-Host "   Chrome, Firefox, Teams, WhatsApp, Signal, Slack, Discord, VLC, HandBrake, K-Lite Mega`n" -ForegroundColor Yellow
    $installComms = Read-Host "Install browsers, communications & media apps? (Y/N) [Default: N]"
    if ([string]::IsNullOrWhiteSpace($installComms)) { $installComms = 'N' }

    if ($installComms -eq 'Y') {
        Write-Step "PHASE 2.6: Browsers, Communications & Media"
        Invoke-Script -Path (Join-Path $WindowsScripts "12-communications-media.ps1") `
            -Description "Install Chrome, Firefox, Teams, WhatsApp, Signal, Slack, Discord, VLC, HandBrake, K-Lite"
    } else {
        Write-Host "   ⭐  Skipped browsers/communications/media installation" -ForegroundColor Yellow
    }
} else {
    Write-Host "⭐  Skipping browsers/communications/media (use -SkipCommunicationsMedia:`$false to enable)" -ForegroundColor Yellow
}

# ============================================================================
# PHASE 2.65: SOCIAL MEDIA & STREAMING (OPTIONAL)
# ============================================================================

Write-Host "`n📱 Social Media & Streaming Services" -ForegroundColor Yellow
Write-Host "   Facebook, LinkedIn, X, Reddit, Apple Music/TV, Netflix, Disney+, AU TV apps, etc.`n" -ForegroundColor Yellow
$installSocialStreaming = Read-Host "Install social media & streaming apps? (Y/N) [Default: N]"
if ([string]::IsNullOrWhiteSpace($installSocialStreaming)) { $installSocialStreaming = 'N' }

if ($installSocialStreaming -eq 'Y') {
    Write-Step "PHASE 2.65: Social Media & Streaming"
    Invoke-Script -Path (Join-Path $WindowsScripts "16-social-streaming.ps1") `
        -Description "Install Facebook, LinkedIn, X, Reddit, Netflix, Disney+, AU TV apps, Plex"
} else {
    Write-Host "   ⭐  Skipped social media & streaming installation" -ForegroundColor Yellow
}

# ============================================================================
# PHASE 2.7: WINDOWS TERMINAL CONFIGURATION
# ============================================================================

Write-Step "PHASE 2.7: Windows Terminal Configuration"
Write-Host "🎨 Windows Terminal Settings" -ForegroundColor Yellow
Write-Host "   Auto-configure settings.json with optimal dev settings`n" -ForegroundColor Yellow
$configureTerminal = Read-Host "Configure Windows Terminal? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($configureTerminal)) { $configureTerminal = 'Y' }

if ($configureTerminal -eq 'Y') {
    Invoke-Script -Path (Join-Path $WindowsScripts "15-windows-terminal-config.ps1") `
        -Description "Configure Windows Terminal with JetBrainsMono, color scheme, keyboard shortcuts"
} else {
    Write-Host "   ⭐  Skipped Windows Terminal configuration" -ForegroundColor Yellow
}

# ============================================================================
# PHASE 3: OPTIMIZE & HARDEN
# ============================================================================

Write-Step "PHASE 3: Security Hardening and Optimization"
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

if (-not $SkipDevDrive) {
    Write-Step "PHASE 6: Dev Drive Cache Setup"
    Invoke-Script -Path (Join-Path $WindowsScripts "40-devdrive-caches.ps1") `
        -Description "Move npm/cargo/go/maven/docker to Dev Drive"
}

# ============================================================================
# PHASE 7: OPTIONAL GOODIES
# ============================================================================

if (-not $SkipOptionalGoodies) {
    Write-Step "PHASE 7: Optional Dev Tools"
    Invoke-Script -Path (Join-Path $WindowsScripts "33-optional-dev-goodies.ps1") `
        -Description "Sysinternals, mkcert, ripgrep, security tools, k8s CLIs"
}

# ============================================================================
# PHASE 7.5: LINTERS & FORMATTERS
# ============================================================================

Write-Step "PHASE 7.5: Linters & Formatters"
Write-Host "📋 Code Quality Tools" -ForegroundColor Yellow
Write-Host "   Comprehensive linting and formatting for all languages" -ForegroundColor Yellow
Write-Host "   (PSScriptAnalyzer, ruff, eslint, prettier, shellcheck, hadolint, etc.)`n" -ForegroundColor Yellow
$installLinters = Read-Host "Install linters and formatters? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($installLinters)) { $installLinters = 'Y' }

if ($installLinters -eq 'Y') {
    Invoke-Script -Path (Join-Path $WindowsScripts "13-linters-formatters.ps1") `
        -Description "Install comprehensive linting/formatting tools"
} else {
    Write-Host "   ⭐  Skipped linters/formatters installation" -ForegroundColor Yellow
}

# ============================================================================
# PHASE 7.6: ADDITIONAL DEVELOPMENT TOOLS
# ============================================================================

Write-Step "PHASE 7.6: Additional Development Tools"
Write-Host "🛠️  Supplementary Dev Tools" -ForegroundColor Yellow
Write-Host "   Postman, DBeaver, Wireshark, draw.io, ScreenToGif, PowerToys, etc.`n" -ForegroundColor Yellow
$installDevTools = Read-Host "Install additional dev tools? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($installDevTools)) { $installDevTools = 'Y' }

if ($installDevTools -eq 'Y') {
    Invoke-Script -Path (Join-Path $WindowsScripts "14-additional-dev-tools.ps1") `
        -Description "Install API testing, database clients, network tools, diagrams, utilities"
} else {
    Write-Host "   ⭐  Skipped additional dev tools installation" -ForegroundColor Yellow
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
# PHASE 8.5: PRIVACY & TELEMETRY HARDENING
# ============================================================================

Write-Step "PHASE 8.5: Privacy & Telemetry Hardening"
Write-Host "🔒 Privacy & Telemetry Settings" -ForegroundColor Yellow
Write-Host "   Disable Windows telemetry, Game Mode, Cortana, advertising, etc.`n" -ForegroundColor Yellow
$hardenPrivacy = Read-Host "Disable privacy-invasive features? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($hardenPrivacy)) { $hardenPrivacy = 'Y' }

if ($hardenPrivacy -eq 'Y') {
    Invoke-Script -Path (Join-Path $WindowsScripts "35-privacy-telemetry.ps1") `
        -Description "Disable telemetry, Game Mode, Cortana, advertising, location tracking"
} else {
    Write-Host "   ⭐  Skipped privacy hardening" -ForegroundColor Yellow
}

# ============================================================================
# PHASE 8.6: DNS SECURITY & FIREWALL RULES
# ============================================================================

Write-Step "PHASE 8.6: DNS Security & Advanced Firewall"
Write-Host "🛡️  DNS over HTTPS & Dev Tool Firewall Rules" -ForegroundColor Yellow
Write-Host "   Configure encrypted DNS and allow dev server ports`n" -ForegroundColor Yellow
$configureDnsFirewall = Read-Host "Configure DNS & firewall? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($configureDnsFirewall)) { $configureDnsFirewall = 'Y' }

if ($configureDnsFirewall -eq 'Y') {
    Invoke-Script -Path (Join-Path $WindowsScripts "36-dns-firewall-advanced.ps1") `
        -Description "Configure DNS over HTTPS, create firewall rules for Docker, Node.js, Python, databases"
} else {
    Write-Host "   ⭐  Skipped DNS & firewall configuration" -ForegroundColor Yellow
}

# ============================================================================
# PHASE 8.7: SERVICES OPTIMIZATION
# ============================================================================

Write-Step "PHASE 8.7: Windows Services Optimization"
Write-Host "⚙️  Service Optimization" -ForegroundColor Yellow
Write-Host "   Disable unnecessary Windows services for performance & security`n" -ForegroundColor Yellow
$optimizeServices = Read-Host "Optimize Windows services? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($optimizeServices)) { $optimizeServices = 'Y' }

if ($optimizeServices -eq 'Y') {
    Invoke-Script -Path (Join-Path $WindowsScripts "37-services-optimization.ps1") `
        -Description "Disable Print Spooler, telemetry, Xbox services, legacy services"
} else {
    Write-Host "   ⭐  Skipped services optimization" -ForegroundColor Yellow
}

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
    Write-Host "⚠️  Windows Insider Program Setup" -ForegroundColor Yellow
    Write-Host "   This will configure Canary/Dev channels for Windows, Office, and VS Code" -ForegroundColor Yellow
    $insider = Read-Host "   Enable Insider channels? (Y/N) [Default: N]"
    if ([string]::IsNullOrWhiteSpace($insider)) { $insider = 'N' }

    if ($insider -eq 'Y') {
        Write-Step "PHASE 10: Insider Channels"
        Invoke-Script -Path (Join-Path $WindowsScripts "70-insiders-optin.ps1") `
            -Description "Windows Canary, Office Beta, VS Code Insiders"

        Invoke-Script -Path (Join-Path $WindowsScripts "72-vscode-insiders-setup.ps1") `
            -Description "VS Code Insiders profile and extensions"
    }
}

# ============================================================================
# PHASE 11: WSL/UBUNTU SETUP
# ============================================================================

Write-Host "⚠️  WSL/Ubuntu Setup" -ForegroundColor Yellow
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
            Write-Host "⚠️  Ubuntu needs first-time setup (create username/password)" -ForegroundColor Yellow
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

        Write-Host "⚠️  Shutting down WSL to apply .wslconfig changes..." -ForegroundColor Yellow
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

Write-Host "📋 Post-Setup Checklist:" -ForegroundColor Cyan
Write-Host "  [ ] Configure Malwarebytes exclusions (see README Post-Setup section)" -ForegroundColor Yellow
Write-Host "  [ ] Configure GlassWire firewall rules (see README Post-Setup section)" -ForegroundColor Yellow
Write-Host "  [ ] Sign into Backblaze and configure exclusions (see README)" -ForegroundColor Yellow
Write-Host "  [ ] Restart Docker Desktop (Settings -> data-root change)" -ForegroundColor Yellow
Write-Host "  [ ] Open 1Password and enable SSH agent (see README)" -ForegroundColor Yellow
Write-Host "  [ ] Configure VS Code settings sync" -ForegroundColor Yellow
Write-Host "  [ ] Add SSH keys to ~/.ssh/ and GitHub" -ForegroundColor Yellow
Write-Host "  [ ] Configure git identity (see README Post-Setup section)" -ForegroundColor Yellow

Write-Host "🧪 Run verification tests:" -ForegroundColor Cyan
Write-Host "  Windows: pwsh -File .\tests\pester.Windows.Tests.ps1" -ForegroundColor White
Write-Host "  Ubuntu:  wsl -d Ubuntu -e bash ./tests/ubuntu-smoke-test.sh" -ForegroundColor White
Write-Host "  Doctor:  pwsh -File .\scripts\windows\50-doctor.ps1 -VerboseOut" -ForegroundColor White

Write-Host "⚠️  REBOOT REQUIRED" -ForegroundColor Yellow
Write-Host "   Several security features require a reboot:" -ForegroundColor Yellow
Write-Host "   - Credential Guard" -ForegroundColor Yellow
Write-Host "   - LSA Protection (RunAsPPL)" -ForegroundColor Yellow
Write-Host "   - Core Isolation (HVCI)" -ForegroundColor Yellow

$reboot = Read-Host "`nReboot now? (Y/N) [Default: N]"
if ([string]::IsNullOrWhiteSpace($reboot)) { $reboot = 'N' }
if ($reboot -eq 'Y') {
    Write-Host "Rebooting in 10 seconds..." -ForegroundColor Green
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host "Remember to reboot before running production workloads!" -ForegroundColor Yellow
}

Write-Host "`n========================================================================" -ForegroundColor Green
Write-Host "" -ForegroundColor Green
Write-Host "     Setup Complete! Your Surface Pro is ready for development" -ForegroundColor Green
Write-Host "" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green


