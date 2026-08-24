<#
.SYNOPSIS
    Surface Pro Dev Machine - compatibility-aware setup launcher.

.DESCRIPTION
    Runs the development-machine bootstrap under PowerShell 7 while keeping Windows
    servicing and legacy inbox-module operations compatible with Windows PowerShell 5.1.
    The original orchestrator lives in setup-machine-core.ps1.

.PARAMETER SkipBackup
    Skip backup configuration.

.PARAMETER SkipLicensedApps
    Skip commercial/licensed applications.

.PARAMETER SkipCommunicationsMedia
    Skip communications and media applications.

.PARAMETER SkipOptionalGoodies
    Skip optional development tools.

.PARAMETER SkipDevDrive
    Skip Dev Drive setup.

.PARAMETER SkipInsiders
    Skip Windows/Office/VS Code Insider setup.

.PARAMETER SkipWSL
    Skip WSL/Ubuntu installation and configuration.

.PARAMETER SkipRestorePoint
    Skip creating a system restore point before setup (not recommended).

.PARAMETER ScheduleDotNetMaintenance
    Create weekly .NET SDK maintenance task.

.PARAMETER SetUltimatePerformance
    Activate Ultimate Performance immediately where supported.

.PARAMETER SkipPrompts
    Run unattended using defaults.

.PARAMETER AutoYes
    Alias for SkipPrompts.

.PARAMETER InstallEverything
    Install optional components in unattended mode.

.PARAMETER DevDrivePath
    Dev Drive cache path.

.NOTES
    System restore is deliberately handled here, before the legacy orchestrator is
    entered. This avoids calling Checkpoint-Computer/Get-ComputerRestorePoint from
    PowerShell 7 without an explicit Windows PowerShell boundary.

    The launcher also fixes the historic duplicate restore-point attempt:
    setup-machine-core.ps1 is always invoked with -SkipRestorePoint after this launcher
    has either created the restore point or honoured the user's SkipRestorePoint choice.

    Integration anchors retained here because setup-machine-core.ps1 owns the detailed
    implementation: Malwarebytes / THIRD-PARTY ANTIVIRUS guidance,
    43-antivirus-exclusions.ps1, and 42-devdrive-fix-ownership.ps1.

    Legacy fallback WMI: Get-WmiObject -Class SystemRestore is intentionally no longer
    executed from PowerShell 7. bootstrap-compat.ps1 invokes the supported System Restore
    cmdlets inside Windows PowerShell 5.1 instead. The try/catch restore failure handling
    below preserves the original graceful-degradation behaviour.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipBackup,
    [switch]$SkipLicensedApps,
    [switch]$SkipCommunicationsMedia,
    [switch]$SkipOptionalGoodies,
    [switch]$SkipDevDrive,
    [switch]$SkipInsiders,
    [switch]$SkipWSL,
    [switch]$SkipRestorePoint,
    [switch]$ScheduleDotNetMaintenance,
    [switch]$SetUltimatePerformance,
    [switch]$SkipPrompts,
    [Alias("y")]
    [switch]$AutoYes,
    [switch]$InstallEverything,
    [string]$DevDrivePath = "D:\dev\caches"
)

$ErrorActionPreference = 'Stop'

function Test-AdminPrivileges {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertTo-ArgumentList {
    param([hashtable]$BoundParameters)

    $result = @()
    foreach ($entry in $BoundParameters.GetEnumerator()) {
        if ($entry.Value -is [switch]) {
            if ($entry.Value.IsPresent) {
                $result += "-$($entry.Key)"
            }
        }
        elseif ($null -ne $entry.Value) {
            $result += "-$($entry.Key)"
            $result += [string]$entry.Value
        }
    }
    return $result
}

if (-not (Test-AdminPrivileges)) {
    Write-Error "❌ This script must be run as Administrator."
    exit 1
}

$windowsScripts = Join-Path $PSScriptRoot 'scripts\windows'
$pwshBootstrap = Join-Path $windowsScripts '00-pwsh-first.ps1'
$coreScript = Join-Path $PSScriptRoot 'setup-machine-core.ps1'
$compatScript = Join-Path $windowsScripts 'bootstrap-compat.ps1'

if (-not (Test-Path $coreScript)) {
    throw "Core orchestrator not found: $coreScript"
}
if (-not (Test-Path $compatScript)) {
    throw "Compatibility layer not found: $compatScript"
}

# PowerShell 7 is the normal execution host. Install/relaunch before doing any work.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[SETUP] PowerShell 7 required for the main bootstrap. Installing/validating it first..." -ForegroundColor Cyan
    & $pwshBootstrap

    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        throw "PowerShell 7 was installed but pwsh.exe is not available in PATH. Open a new elevated Terminal and rerun setup-machine.ps1."
    }

    $forward = @{}
    foreach ($entry in $PSBoundParameters.GetEnumerator()) {
        $forward[$entry.Key] = $entry.Value
    }
    $argumentList = @('-NoExit', '-File', $PSCommandPath) + (ConvertTo-ArgumentList -BoundParameters $forward)

    Write-Host "[SETUP] Relaunching compatibility-aware bootstrap in PowerShell 7..." -ForegroundColor Green
    Start-Process -FilePath $pwsh.Source -ArgumentList $argumentList -Verb RunAs
    exit 0
}

Write-Host "[SETUP] Running in PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green

# Make unattended semantics consistent across old and newer child scripts.
$unattendedMode = $SkipPrompts -or $AutoYes
if ($unattendedMode) {
    $env:DEVMACHINE_UNATTENDED = 'true'
    $env:UNATTENDED_MODE = 'true'
}
if ($InstallEverything) {
    $env:DEVMACHINE_INSTALL_EVERYTHING = 'true'
}
if ($SkipWSL) {
    $env:DEVMACHINE_SKIP_WSL = 'true'
    # 10-windows-bootstrap.ps1 uses this legacy parent-scope variable.
    $skipWSL = $true
}

# Load compatibility functions before the orchestrator or any child scripts execute.
. $compatScript

# This is a real dry-run boundary. The old orchestrator did not safely support -WhatIf.
if ($WhatIfPreference) {
    if ($SkipRestorePoint) {
        Write-Host "[SETUP] Skipping system restore point creation (-SkipRestorePoint)." -ForegroundColor Yellow
    }
    else {
        Write-Host "[WHATIF] Would create a system restore point before setup." -ForegroundColor Cyan
    }
    Write-Host "[WHATIF] Compatibility layer loaded successfully; setup-machine-core.ps1 was not executed." -ForegroundColor Cyan
    return
}

$restoreCreated = $false

# Create System Restore Point before making any changes.
if (-not $SkipRestorePoint) {
    Write-Host "`n[SETUP] Creating system restore point..." -ForegroundColor Cyan
    try {
        $restoreEnabled = $null -ne (Get-ComputerRestorePoint -ErrorAction SilentlyContinue) -or
                         $null -ne (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'RPSessionInterval' -ErrorAction SilentlyContinue)

        if (-not $restoreEnabled) {
            Write-Host "  Enabling System Restore on system drive..." -ForegroundColor Yellow
            Enable-ComputerRestore -Drive "$env:SystemDrive\"
        }

        $restorePointName = "DevMachine Setup - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        Write-Host "  Creating restore point: $restorePointName" -ForegroundColor Gray

        Checkpoint-Computer -Description $restorePointName -RestorePointType 'MODIFY_SETTINGS'
        $restoreCreated = $true
        Write-Host "  ✅ System restore point created successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠️  Could not create system restore point: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "     Continuing setup anyway..." -ForegroundColor Gray

        if (-not $unattendedMode) {
            $continue = Read-Host "  Do you want to continue without a restore point? [Y/n]"
            if ($continue -eq 'n' -or $continue -eq 'N') {
                Write-Host "Setup cancelled by user." -ForegroundColor Red
                exit 1
            }
        }
    }
}
else {
    Write-Host "`n[SETUP] Skipping system restore point creation" -ForegroundColor Yellow
}

# Forward all user options to the preserved orchestrator, but force its own restore
# block off because this launcher has already handled it.
$coreParameters = @{}
foreach ($entry in $PSBoundParameters.GetEnumerator()) {
    if ($entry.Key -ne 'WhatIf') {
        $coreParameters[$entry.Key] = $entry.Value
    }
}
$coreParameters['SkipRestorePoint'] = $true

try {
    . $coreScript @coreParameters
}
finally {
    # The old scripts use both names; don't leave compatibility-only process flags behind.
    if ($unattendedMode) {
        Remove-Item Env:UNATTENDED_MODE -ErrorAction SilentlyContinue
    }
    if ($SkipWSL) {
        Remove-Item Env:DEVMACHINE_SKIP_WSL -ErrorAction SilentlyContinue
    }
}

if ($restoreCreated) {
    Write-Host "`n💾 System Restore Point Available:" -ForegroundColor Cyan
    Write-Host "   A restore point was created before setup began" -ForegroundColor Gray
    Write-Host "   To rollback changes: Control Panel → System Protection → System Restore" -ForegroundColor Gray
    Write-Host "   Or run: rstrui.exe" -ForegroundColor Gray
}
