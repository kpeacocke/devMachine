<#
.SYNOPSIS
    Configure comprehensive antivirus exclusions for development performance.

.DESCRIPTION
    Configures Windows Defender exclusions for development folders, package caches,
    build processes and temporary files. Dev Drives are deliberately NOT added as
    Defender exclusions: trusted Dev Drives use Microsoft Defender Performance Mode,
    which keeps antivirus protection enabled while making file scanning asynchronous.

.PARAMETER IncludeDevDrive
    Retained for compatibility. Dev Drive paths are no longer excluded from Defender.

.PARAMETER ShowMalwarebytesGuide
    Display detailed Malwarebytes exclusion guidance

.PARAMETER ShowAllGuides
    Display guidance for all major antivirus products
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "Retained for compatibility; trusted Dev Drives use Defender Performance Mode instead of exclusions")]
    [switch]$IncludeDevDrive,

    [Parameter(HelpMessage = "Display detailed Malwarebytes exclusion guidance")]
    [switch]$ShowMalwarebytesGuide,

    [Parameter(HelpMessage = "Display guidance for all major antivirus products")]
    [switch]$ShowAllGuides
)

$ErrorActionPreference = 'Stop'

if ($env:UNATTENDED_MODE) {
    $ConfirmPreference = 'None'
}

function Test-Command($n) { $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

function Test-MalwarebytesInstalled {
    $mbPaths = @(
        "$env:ProgramFiles\Malwarebytes",
        "$env:ProgramFiles(x86)\Malwarebytes",
        "$env:ProgramData\Malwarebytes"
    )

    foreach ($path in $mbPaths) {
        if (Test-Path $path) { return $true }
    }
    return $false
}

function Set-DefenderMalwarebytesCoexistence {
    param([switch]$WhatIf)

    $malwarebytesDetected = Test-MalwarebytesInstalled

    if ($malwarebytesDetected) {
        Write-Host "   🛡️  Malwarebytes detected - managing Defender coexistence" -ForegroundColor Yellow

        try {
            $defenderStatus = Get-MpComputerStatus -ErrorAction Stop

            if ($defenderStatus.RealTimeProtectionEnabled) {
                Write-Host "   Disabling Defender real-time protection to prevent conflicts" -ForegroundColor Gray
                if (-not $WhatIf) {
                    Set-MpPreference -DisableRealtimeMonitoring $true
                    Write-Host "   ✅ Defender real-time protection disabled" -ForegroundColor Green
                } else {
                    Write-Host "   🔍 Would disable Defender real-time protection" -ForegroundColor Cyan
                }
            } else {
                Write-Host "   ✅ Defender real-time protection already disabled" -ForegroundColor Green
            }
        } catch {
            Write-Host "   ⚠️  Could not manage Defender settings: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    return $malwarebytesDetected
}

Write-Host "🛡️  Antivirus Exclusions for Development Performance" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

try {
    $defenderStatus = Get-MpComputerStatus -ErrorAction Stop
    $defenderActive = $defenderStatus.RealTimeProtectionEnabled
} catch {
    Write-Host "⚠️  Could not check Windows Defender status" -ForegroundColor Yellow
    $defenderActive = $false
}

if ($defenderActive) {
    Write-Host "`n✅ Windows Defender is active - configuring exclusions..." -ForegroundColor Green

    if (-not $PSCmdlet.ShouldProcess("Windows Defender exclusions", "Configure development exclusions")) {
        Write-Host "🔍 WHAT-IF MODE: No antivirus changes will be made" -ForegroundColor Cyan
        exit 0
    }

    Write-Host "`n📋 Current Windows Defender exclusions:" -ForegroundColor Cyan
    try {
        $currentPrefs = Get-MpPreference -ErrorAction Stop
        Write-Host "   Current path exclusions: $($currentPrefs.ExclusionPath.Count)" -ForegroundColor Gray
        Write-Host "   Current process exclusions: $($currentPrefs.ExclusionProcess.Count)" -ForegroundColor Gray
        Write-Host "   Current extension exclusions: $($currentPrefs.ExclusionExtension.Count)" -ForegroundColor Gray
    } catch {
        Write-Host "   Could not retrieve current exclusions" -ForegroundColor Yellow
    }

    $pathExclusions = @(
        "$env:USERPROFILE\.cargo",
        "$env:USERPROFILE\.rustup",
        "$env:USERPROFILE\go",
        "$env:USERPROFILE\go\pkg\mod",
        "$env:USERPROFILE\.gradle",
        "$env:USERPROFILE\.m2",
        "$env:USERPROFILE\.nuget",
        "$env:USERPROFILE\.dotnet",
        "$env:USERPROFILE\AppData\Local\pip",
        "$env:USERPROFILE\AppData\Local\pipx",
        "$env:USERPROFILE\AppData\Roaming\npm",
        "$env:USERPROFILE\AppData\Roaming\npm-cache",
        "$env:USERPROFILE\AppData\Local\yarn",
        "$env:USERPROFILE\AppData\Local\pnpm",
        "$env:USERPROFILE\.bun",
        "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code",
        "$env:USERPROFILE\AppData\Roaming\Code",
        "$env:USERPROFILE\AppData\Local\GitHubDesktop",
        "$env:ProgramFiles\JetBrains",
        "$env:USERPROFILE\AppData\Local\JetBrains",
        "$env:USERPROFILE\AppData\Roaming\JetBrains",
        "$env:TEMP",
        "$env:TMP",
        "$env:USERPROFILE\AppData\Local\Temp",
        "$env:ProgramData\Microsoft\Windows\WER",
        "$env:USERPROFILE\source",
        "$env:USERPROFILE\repos",
        "$env:USERPROFILE\projects",
        "$env:USERPROFILE\dev",
        "C:\dev",
        "C:\code",
        "C:\projects",
        "$env:ProgramFiles\Microsoft Visual Studio",
        "$env:ProgramFiles(x86)\Microsoft Visual Studio",
        "$env:ProgramFiles\Microsoft SDKs",
        "$env:ProgramFiles(x86)\Microsoft SDKs",
        "$env:ProgramFiles\Windows Kits",
        "$env:ProgramFiles(x86)\Windows Kits",
        "$env:ProgramData\Docker",
        "$env:USERPROFILE\AppData\Local\Docker",
        "$env:LOCALAPPDATA\Docker"
    )

    Write-Host "📁 Configuring path exclusions..." -ForegroundColor Yellow
    $pathsConfigured = 0
    $pathsSkipped = 0

    foreach ($path in $pathExclusions) {
        if (Test-Path $path) {
            try {
                Add-MpPreference -ExclusionPath $path -ErrorAction Stop
                Write-Host "  ✅ $path" -ForegroundColor Green
                $pathsConfigured++
            } catch {
                Write-Host "  ❌ Failed: $path" -ForegroundColor Red
            }
        } else {
            Write-Host "  ⏭️  Skipped (not found): $path" -ForegroundColor Gray
            $pathsSkipped++
        }
    }

    Write-Host "`n🔍 Configuring pattern exclusions..." -ForegroundColor Yellow
    try {
        $patterns = @(
            "*\node_modules", "*\.git", "*\target", "*\bin", "*\obj",
            "*\target*\bin*\obj", "*\build", "*\dist", "*\out",
            "*\.venv", "*\venv", "*\__pycache__", "*\.pytest_cache",
            "*\.next", "*\.nuxt", "*\coverage", "*\.nyc_output",
            "*\bin\Debug", "*\bin\Release", "*\packages",
            "*\target\*", "*\bin\*", "*\obj\*"
        )

        foreach ($pattern in $patterns) {
            Add-MpPreference -ExclusionPath $pattern -ErrorAction Stop
        }
        Write-Host "  ✅ Configured $($patterns.Count) build/cache patterns" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Some pattern exclusions failed" -ForegroundColor Red
    }

    Write-Host "`n📄 Configuring file extension exclusions..." -ForegroundColor Yellow
    try {
        $extensions = @(".tmp", ".temp", ".log", ".cache", ".lock", ".pid", ".swp", ".swo", ".pdb", ".ilk", ".idb", ".pch")
        foreach ($ext in $extensions) {
            Add-MpPreference -ExclusionExtension $ext -ErrorAction Stop
        }
        Write-Host "  ✅ Configured $($extensions.Count) temp/debug file extensions" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Some extension exclusions failed" -ForegroundColor Red
    }

    Write-Host "`n⚙️ Configuring process exclusions..." -ForegroundColor Yellow
    try {
        $processes = @(
            "node.exe", "npm.exe", "yarn.exe", "pnpm.exe", "bun.exe",
            "cargo.exe", "rustc.exe", "rustup.exe", "go.exe", "gofmt.exe", "git.exe",
            "python.exe", "pip.exe", "pipenv.exe", "poetry.exe", "dotnet.exe", "msbuild.exe", "devenv.exe",
            "java.exe", "javac.exe", "gradle.exe", "mvn.exe", "code.exe", "code-insiders.exe", "cursor.exe",
            "docker.exe", "dockerd.exe", "wsl.exe"
        )
        foreach ($process in $processes) {
            Add-MpPreference -ExclusionProcess $process -ErrorAction Stop
        }
        Write-Host "  ✅ Configured $($processes.Count) development processes" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Some process exclusions failed" -ForegroundColor Red
    }

    Write-Host "`n🎯 Windows Defender Summary:" -ForegroundColor Cyan
    Write-Host "  • Paths configured: $pathsConfigured" -ForegroundColor Green
    Write-Host "  • Paths skipped: $pathsSkipped" -ForegroundColor Gray
    Write-Host "  • Patterns: $($patterns.Count)" -ForegroundColor Green
    Write-Host "  • Extensions: $($extensions.Count)" -ForegroundColor Green
    Write-Host "  • Processes: $($processes.Count)" -ForegroundColor Green
} else {
    Write-Host "`n❌ Windows Defender is not active or accessible" -ForegroundColor Red
    Write-Host "   Third-party antivirus may be installed" -ForegroundColor Yellow
}

Write-Host "`n🔍 Detecting other antivirus products..." -ForegroundColor Yellow
$antivirusProducts = @()

$malwarebytesDetected = Set-DefenderMalwarebytesCoexistence -WhatIf:$WhatIfPreference
if ($malwarebytesDetected) { $antivirusProducts += "Malwarebytes" }

$otherAVPaths = @{
    "Norton" = @("$env:ProgramFiles\Norton*", "$env:ProgramFiles(x86)\Norton*")
    "McAfee" = @("$env:ProgramFiles\McAfee*", "$env:ProgramFiles(x86)\McAfee*")
    "Avast" = @("$env:ProgramFiles\Avast*", "$env:ProgramFiles(x86)\Avast*")
    "AVG" = @("$env:ProgramFiles\AVG*", "$env:ProgramFiles(x86)\AVG*")
    "Bitdefender" = @("$env:ProgramFiles\Bitdefender*", "$env:ProgramFiles(x86)\Bitdefender*")
    "Kaspersky" = @("$env:ProgramFiles\Kaspersky*", "$env:ProgramFiles(x86)\Kaspersky*")
}

foreach ($av in $otherAVPaths.Keys) {
    foreach ($path in $otherAVPaths[$av]) {
        if (Get-ChildItem $path -ErrorAction SilentlyContinue) {
            $antivirusProducts += $av
            break
        }
    }
}

if ($antivirusProducts.Count -gt 0) {
    Write-Host "  Detected: $($antivirusProducts -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "  No additional antivirus products detected" -ForegroundColor Green
}

if (($ShowMalwarebytesGuide -or $ShowAllGuides) -or ($antivirusProducts -contains "Malwarebytes")) {
    Write-Host "`n📋 MALWAREBYTES EXCLUSION GUIDE" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "1. Open Malwarebytes" -ForegroundColor White
    Write-Host "2. Go to Settings → Security → Exclusions" -ForegroundColor White
    Write-Host "3. Add development folders and processes as required by your security policy." -ForegroundColor White
    Write-Host "   Do NOT broadly exclude trusted Dev Drives; use Dev Drive Performance Mode instead." -ForegroundColor Yellow
}

if ($ShowAllGuides) {
    Write-Host "`n📋 OTHER ANTIVIRUS PRODUCTS" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "Configure development exclusions using the product's documented exclusion controls." -ForegroundColor Gray
    Write-Host "For Dev Drives, retain antivirus protection and use Microsoft Defender Performance Mode where supported." -ForegroundColor Gray
}

Write-Host "`n🚀 PERFORMANCE MODEL" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "Trusted Dev Drives use Microsoft Defender Performance Mode rather than disabling scanning." -ForegroundColor White
Write-Host "Standard development caches and build locations are handled by the exclusions above." -ForegroundColor Gray
Write-Host "`n✅ Antivirus exclusion configuration complete!" -ForegroundColor Green
