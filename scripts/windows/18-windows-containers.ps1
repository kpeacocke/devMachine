<#
.SYNOPSIS
    Configure Windows container development features.

.DESCRIPTION
    Enables the Windows features required for Windows containers and Hyper-V
    isolation, installs optional container tooling, and validates the result.

    Windows feature servicing is deliberately executed by the inbox Windows
    PowerShell 5.1 host. Current Windows 11 builds can throw "Class not
    registered" when the DISM PowerShell provider is invoked from PowerShell 7.

    This script uses PowerShell's built-in -WhatIf common parameter. It does NOT
    declare a second WhatIf parameter.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "Skip Hyper-V and Hypervisor Platform features")]
    [switch]$SkipHyperV,

    [Parameter(HelpMessage = "Enable Windows container base image pre-caching")]
    [switch]$EnableBaseCaching
)

$ErrorActionPreference = 'Stop'

$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $windowsPowerShell)) {
    throw "Windows PowerShell 5.1 not found at $windowsPowerShell"
}

function Test-CommandAvailable {
    param([Parameter(Mandatory)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-WindowsPowerShell51 {
    param([Parameter(Mandatory)][string]$Command)

    $output = & $windowsPowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $Command 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Windows PowerShell 5.1 exited with code $exitCode.`n$(($output | Out-String).Trim())"
    }
    return $output
}

function Get-WindowsFeatureState {
    param([Parameter(Mandatory)][string]$FeatureName)

    $escaped = $FeatureName.Replace("'", "''")
    $output = Invoke-WindowsPowerShell51 -Command "(Get-WindowsOptionalFeature -Online -FeatureName '$escaped' -ErrorAction Stop).State"
    return (($output | Out-String).Trim())
}

function Enable-WindowsFeature51 {
    param(
        [Parameter(Mandatory)][string]$FeatureName,
        [Parameter(Mandatory)][string]$DisplayName
    )

    $state = Get-WindowsFeatureState -FeatureName $FeatureName
    if ($state -eq 'Enabled') {
        Write-Host "  → $DisplayName already enabled" -ForegroundColor Green
        return $false
    }

    if ($WhatIfPreference) {
        Write-Host "  🔍 Would enable $DisplayName" -ForegroundColor Cyan
        return $false
    }

    if (-not $PSCmdlet.ShouldProcess($DisplayName, 'Enable Windows feature')) {
        return $false
    }

    $escaped = $FeatureName.Replace("'", "''")
    Invoke-WindowsPowerShell51 -Command "Enable-WindowsOptionalFeature -Online -FeatureName '$escaped' -All -NoRestart -ErrorAction Stop | Out-Null"
    Write-Host "  ✅ $DisplayName enabled" -ForegroundColor Green
    return $true
}

Write-Host "🐳 Windows Container Features Configuration" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($WhatIfPreference) {
    Write-Host "`n🔍 WHAT-IF MODE: no changes will be made" -ForegroundColor Cyan
}

$rebootRequired = $false

$features = @(
    @{ Name = 'Microsoft-Windows-Subsystem-Linux'; Display = 'Windows Subsystem for Linux' },
    @{ Name = 'VirtualMachinePlatform'; Display = 'Virtual Machine Platform' },
    @{ Name = 'Containers'; Display = 'Windows Containers' }
)

if (-not $SkipHyperV) {
    $features += @{ Name = 'HypervisorPlatform'; Display = 'Windows Hypervisor Platform' }
    $features += @{ Name = 'Microsoft-Hyper-V-All'; Display = 'Hyper-V' }
}

Write-Host "`n📦 Windows Container Features" -ForegroundColor Yellow
foreach ($feature in $features) {
    try {
        if (Enable-WindowsFeature51 -FeatureName $feature.Name -DisplayName $feature.Display) {
            $rebootRequired = $true
        }
    }
    catch {
        throw "Failed configuring $($feature.Display): $($_.Exception.Message)"
    }
}

Write-Host "`n🔧 Container Development Tools" -ForegroundColor Yellow
$containerTools = @(
    @{ Name = 'hadolint'; Package = 'hadolint'; Description = 'Dockerfile linter' },
    @{ Name = 'trivy'; Package = 'AquaSecurity.Trivy'; Description = 'Container vulnerability scanner' },
    @{ Name = 'dive'; Package = 'wagoodman.dive'; Description = 'Docker image layer analyser' }
)

foreach ($tool in $containerTools) {
    if (Test-CommandAvailable -Name $tool.Name) {
        Write-Host "  → $($tool.Description) already installed" -ForegroundColor Green
        continue
    }

    if ($WhatIfPreference) {
        Write-Host "  🔍 Would install $($tool.Description)" -ForegroundColor Cyan
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($tool.Description, 'Install with winget')) {
        continue
    }

    try {
        & winget install $tool.Package --source winget --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ $($tool.Description) installed" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠️  winget returned exit code $LASTEXITCODE for $($tool.Description)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ⚠️  Failed to install $($tool.Description): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`n🔍 Container Environment Validation" -ForegroundColor Yellow
foreach ($feature in $features) {
    $state = Get-WindowsFeatureState -FeatureName $feature.Name
    if ($state -eq 'Enabled') {
        Write-Host "  ✅ $($feature.Display) enabled" -ForegroundColor Green
    }
    else {
        Write-Host "  ❌ $($feature.Display) state: $state" -ForegroundColor Red
    }
}

foreach ($tool in $containerTools) {
    if (Test-CommandAvailable -Name $tool.Name) {
        Write-Host "  ✅ $($tool.Name) available" -ForegroundColor Green
    }
    else {
        Write-Host "  ⚠️  $($tool.Name) not found" -ForegroundColor Yellow
    }
}

if ($EnableBaseCaching) {
    Write-Host "`n📥 Container Base Image Pre-caching" -ForegroundColor Yellow
    $baseImages = @(
        'mcr.microsoft.com/windows/nanoserver:ltsc2022',
        'mcr.microsoft.com/windows/servercore:ltsc2022',
        'mcr.microsoft.com/dotnet/runtime:8.0-nanoserver-ltsc2022',
        'mcr.microsoft.com/dotnet/aspnet:8.0-nanoserver-ltsc2022'
    )

    if (-not (Test-CommandAvailable -Name 'docker')) {
        Write-Host '  ⚠️  Docker not available; skipping image cache.' -ForegroundColor Yellow
    }
    elseif ($WhatIfPreference) {
        foreach ($image in $baseImages) {
            Write-Host "  🔍 Would pull $image" -ForegroundColor Cyan
        }
    }
    elseif ($PSCmdlet.ShouldProcess('Windows container base images', 'Pre-cache')) {
        foreach ($image in $baseImages) {
            & docker pull $image
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Cached: $image" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠️  Failed to cache: $image" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host "`n📖 Container Guidance" -ForegroundColor Cyan
Write-Host '  • Linux containers remain the normal Docker Desktop default.' -ForegroundColor Gray
Write-Host '  • Switch Docker Desktop to Windows containers only when required.' -ForegroundColor Gray
Write-Host '  • Use a Dev Drive for project files and caches where appropriate.' -ForegroundColor Gray

if ($rebootRequired) {
    Write-Host "`n🔄 REBOOT REQUIRED" -ForegroundColor Yellow
    Write-Host '   One or more Windows features were newly enabled.' -ForegroundColor Gray
}
else {
    Write-Host "`n💻 No reboot required by this script." -ForegroundColor Green
}

Write-Host "`n✅ Windows Container Configuration Complete!" -ForegroundColor Green
