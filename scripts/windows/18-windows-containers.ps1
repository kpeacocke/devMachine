<#
.SYNOPSIS
    Configure Windows container development features.

.DESCRIPTION
    Enables Windows features required for Windows containers and Hyper-V isolation,
    installs optional container tooling, and validates the result.

    Windows feature servicing runs through the inbox Windows PowerShell 5.1 host.
    This avoids the current Windows 11 / PowerShell 7 DISM provider failure:
    "Class not registered".

    WhatIf is the PowerShell common parameter supplied by SupportsShouldProcess.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipHyperV,
    [switch]$EnableBaseCaching
)

$ErrorActionPreference = 'Stop'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $windowsPowerShell)) {
    throw "Windows PowerShell 5.1 not found at $windowsPowerShell"
}

function Invoke-WindowsPowerShell51 {
    param([Parameter(Mandatory)][string]$Command)
    $output = & $windowsPowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $Command 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw "Windows PowerShell 5.1 exited with code $code.`n$(($output | Out-String).Trim())"
    }
    $output
}

function Get-WindowsFeatureState {
    param([Parameter(Mandatory)][string]$FeatureName)
    $name = $FeatureName.Replace("'", "''")
    (Invoke-WindowsPowerShell51 "(Get-WindowsOptionalFeature -Online -FeatureName '$name' -ErrorAction Stop).State" | Out-String).Trim()
}

function Enable-WindowsFeature51 {
    param([Parameter(Mandatory)][string]$FeatureName,[Parameter(Mandatory)][string]$DisplayName)
    if ((Get-WindowsFeatureState $FeatureName) -eq 'Enabled') {
        Write-Host "  → $DisplayName already enabled" -ForegroundColor Green
        return $false
    }
    if ($WhatIfPreference) {
        Write-Host "  🔍 Would enable $DisplayName" -ForegroundColor Cyan
        return $false
    }
    if (-not $PSCmdlet.ShouldProcess($DisplayName,'Enable Windows feature')) { return $false }
    $name = $FeatureName.Replace("'", "''")
    Invoke-WindowsPowerShell51 "Enable-WindowsOptionalFeature -Online -FeatureName '$name' -All -NoRestart -ErrorAction Stop | Out-Null"
    Write-Host "  ✅ $DisplayName enabled" -ForegroundColor Green
    $true
}

Write-Host '🐳 Windows Container Features Configuration' -ForegroundColor Cyan
$rebootRequired = $false
$features = @(
    @{Name='Microsoft-Windows-Subsystem-Linux';Display='Windows Subsystem for Linux'},
    @{Name='VirtualMachinePlatform';Display='Virtual Machine Platform'},
    @{Name='Containers';Display='Windows Containers'}
)
if (-not $SkipHyperV) {
    $features += @{Name='HypervisorPlatform';Display='Windows Hypervisor Platform'}
    $features += @{Name='Microsoft-Hyper-V-All';Display='Hyper-V'}
}

foreach ($feature in $features) {
    if (Enable-WindowsFeature51 $feature.Name $feature.Display) { $rebootRequired = $true }
}

$tools = @(
    @{Name='hadolint';Package='hadolint'},
    @{Name='trivy';Package='AquaSecurity.Trivy'},
    @{Name='dive';Package='wagoodman.dive'}
)
foreach ($tool in $tools) {
    if (Get-Command $tool.Name -ErrorAction SilentlyContinue) { continue }
    if ($WhatIfPreference) { Write-Host "  🔍 Would install $($tool.Name)" -ForegroundColor Cyan; continue }
    if ($PSCmdlet.ShouldProcess($tool.Name,'Install with winget')) {
        & winget install $tool.Package --source winget --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Write-Host "  ⚠️ winget failed for $($tool.Name): $LASTEXITCODE" -ForegroundColor Yellow }
    }
}

Write-Host '`n🔍 Container Environment Validation' -ForegroundColor Yellow
foreach ($feature in $features) {
    $state = Get-WindowsFeatureState $feature.Name
    if ($state -eq 'Enabled') { Write-Host "  ✅ $($feature.Display) enabled" -ForegroundColor Green }
    else { Write-Host "  ❌ $($feature.Display) state: $state" -ForegroundColor Red }
}

if ($EnableBaseCaching -and (Get-Command docker -ErrorAction SilentlyContinue)) {
    $images = @('mcr.microsoft.com/windows/nanoserver:ltsc2022','mcr.microsoft.com/windows/servercore:ltsc2022')
    if ($WhatIfPreference) {
        $images | ForEach-Object { Write-Host "  🔍 Would pull $_" -ForegroundColor Cyan }
    } elseif ($PSCmdlet.ShouldProcess('Windows container base images','Pre-cache')) {
        foreach ($image in $images) {
            & docker pull $image
            if ($LASTEXITCODE -eq 0) { Write-Host "  ✅ Cached: $image" -ForegroundColor Green }
            else { Write-Host "  ⚠️ Failed: $image" -ForegroundColor Yellow }
        }
    }
}

if ($rebootRequired) { Write-Host '`n🔄 REBOOT REQUIRED' -ForegroundColor Yellow }
else { Write-Host '`n💻 No reboot required by this script.' -ForegroundColor Green }
Write-Host '`n✅ Windows Container Configuration Complete!' -ForegroundColor Green
