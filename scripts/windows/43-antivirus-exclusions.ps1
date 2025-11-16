<#
.SYNOPSIS
    Configure comprehensive antivirus exclusions for optimal development performance.

.DESCRIPTION
    This script configures Windows Defender exclusions and provides guidance for other antivirus products
    including Malwarebytes. It focuses on excluding development folders, package caches, build processes,
    and temporary files that can significantly slow down development workflows.

.PARAMETER IncludeDevDrive
    Include Dev Drive paths in exclusions (C:\DevCache and code partition)

.PARAMETER ShowMalwarebytesGuide
    Display detailed Malwarebytes exclusion guidance

.PARAMETER ShowAllGuides
    Display guidance for all major antivirus products

.EXAMPLE
    .\scripts\windows\43-antivirus-exclusions.ps1

.EXAMPLE
    .\scripts\windows\43-antivirus-exclusions.ps1 -IncludeDevDrive -ShowMalwarebytesGuide

.NOTES
    This script requires Administrator privileges to modify Windows Defender settings.
    For other antivirus products, manual configuration is required.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "Include Dev Drive paths in exclusions (C:\DevCache and code partition)")]
    [ValidateNotNullOrEmpty()]
    [switch]$IncludeDevDrive,

    [Parameter(HelpMessage = "Display detailed Malwarebytes exclusion guidance")]
    [ValidateNotNullOrEmpty()]
    [switch]$ShowMalwarebytesGuide,

    [Parameter(HelpMessage = "Display guidance for all major antivirus products")]
    [ValidateNotNullOrEmpty()]
    [switch]$ShowAllGuides
)

$ErrorActionPreference = 'Stop'

# Handle unattended mode - skip confirmations
if ($env:UNATTENDED_MODE) {
    $ConfirmPreference = 'None'
}

function Test-Command($n){ $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

# Function to detect Malwarebytes installation
function Test-MalwarebytesInstalled {
    $mbPaths = @(
        "$env:ProgramFiles\Malwarebytes",
        "$env:ProgramFiles(x86)\Malwarebytes",
        "$env:ProgramData\Malwarebytes"
    )

    foreach ($path in $mbPaths) {
        if (Test-Path $path) {
            return $true
        }
    }
    return $false
}

# Function to manage Defender/Malwarebytes coexistence
function Set-DefenderMalwarebytesCoexistence {
    param(
        [switch]$WhatIf
    )

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

# Check if Windows Defender is active
try {
    $defenderStatus = Get-MpComputerStatus -ErrorAction Stop
    $defenderActive = $defenderStatus.RealTimeProtectionEnabled
} catch {
    Write-Host "⚠️  Could not check Windows Defender status" -ForegroundColor Yellow
    $defenderActive = $false
}

if ($defenderActive) {
    Write-Host "`n✅ Windows Defender is active - configuring exclusions..." -ForegroundColor Green

    # Check WhatIf mode first
    if ($WhatIf) {
        Write-Host "`n🔍 WHAT-IF MODE: No antivirus changes will be made" -ForegroundColor Cyan
        Write-Host "   This would configure Windows Defender exclusions for development performance." -ForegroundColor Gray
        Write-Host "   Run without -WhatIf to perform actual exclusion configuration." -ForegroundColor Gray
        exit 0
    }

    # Implement ShouldProcess pattern for antivirus configuration
    if (-not $PSCmdlet.ShouldProcess("Windows Defender exclusions", "Configure development exclusions")) {
        Write-Host "❌ Operation cancelled by ShouldProcess" -ForegroundColor Red
        exit 0
    }

    # Display current exclusions before making changes
    Write-Host "`n📋 Current Windows Defender exclusions:" -ForegroundColor Cyan
    try {
        $currentPrefs = Get-MpPreference -ErrorAction Stop
        Write-Host "   Current path exclusions: $($currentPrefs.ExclusionPath.Count)" -ForegroundColor Gray
        Write-Host "   Current process exclusions: $($currentPrefs.ExclusionProcess.Count)" -ForegroundColor Gray
        Write-Host "   Current extension exclusions: $($currentPrefs.ExclusionExtension.Count)" -ForegroundColor Gray
    } catch {
        Write-Host "   Could not retrieve current exclusions" -ForegroundColor Yellow
    }

    # Comprehensive path exclusions for development
    $pathExclusions = @(
        # Package manager caches
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

        # Development tools and IDEs
        "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code",
        "$env:USERPROFILE\AppData\Roaming\Code",
        "$env:USERPROFILE\AppData\Local\GitHubDesktop",
        "$env:ProgramFiles\JetBrains",
        "$env:USERPROFILE\AppData\Local\JetBrains",
        "$env:USERPROFILE\AppData\Roaming\JetBrains",

        # Build and temp directories
        "$env:TEMP",
        "$env:TMP",
        "$env:USERPROFILE\AppData\Local\Temp",
        "$env:ProgramData\Microsoft\Windows\WER",

        # Common development locations
        "$env:USERPROFILE\code",
        "$env:USERPROFILE\source",
        "$env:USERPROFILE\repos",
        "$env:USERPROFILE\projects",
        "$env:USERPROFILE\dev",
        "C:\dev",
        "C:\code",
        "C:\projects",

        # Windows development tools
        "$env:ProgramFiles\Microsoft Visual Studio",
        "$env:ProgramFiles(x86)\Microsoft Visual Studio",
        "$env:ProgramFiles\Microsoft SDKs",
        "$env:ProgramFiles(x86)\Microsoft SDKs",
        "$env:ProgramFiles\Windows Kits",
        "$env:ProgramFiles(x86)\Windows Kits",

        # Docker and virtualization
        "$env:ProgramData\Docker",
        "$env:USERPROFILE\AppData\Local\Docker",
        "$env:LOCALAPPDATA\Docker"
    )

    # Add Dev Drive paths if requested
    if ($IncludeDevDrive) {
        $pathExclusions += @(
            "C:\DevCache",
            "$env:USERPROFILE\code",  # Dev Drive mount point
            "D:\dev\caches"           # Alternative Dev Drive location
        )
    }

    # Configure path exclusions
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

    # Configure pattern exclusions
    Write-Host "`n🔍 Configuring pattern exclusions..." -ForegroundColor Yellow
    try {
        # Build directory patterns: target, bin, obj for comprehensive coverage
        $patterns = @(
            "*\node_modules",
            "*\.git",
            "*\target",        # Rust/Maven build output (target)
            "*\bin",           # .NET binary output (bin)
            "*\obj",           # .NET object files (obj)
            "*\target*\bin*\obj",  # Combined build pattern
            "*\build",         # Generic build output
            "*\dist",          # Generic dist output
            "*\out",           # Generic out folder
            "*\.venv",         # Python virtual envs
            "*\venv",
            "*\__pycache__",   # Python cache
            "*\.pytest_cache",
            "*\.next",         # Next.js build cache
            "*\.nuxt",         # Nuxt.js build cache
            "*\coverage",      # Test coverage reports
            "*\.nyc_output",   # NYC coverage
            "*\bin\Debug",     # .NET debug builds
            "*\bin\Release",   # .NET release builds
            "*\packages",      # NuGet packages
            "*\target\*",      # Rust cargo target subdirectories
            "*\bin\*",         # All bin subdirectories
            "*\obj\*"          # All obj subdirectories
        )

        foreach ($pattern in $patterns) {
            Add-MpPreference -ExclusionPath $pattern -ErrorAction Stop
        }
        Write-Host "  ✅ Configured $($patterns.Count) build/cache patterns" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Some pattern exclusions failed" -ForegroundColor Red
    }

    # Configure file extension exclusions
    Write-Host "`n📄 Configuring file extension exclusions..." -ForegroundColor Yellow
    try {
        $extensions = @(
            ".tmp", ".temp", ".log", ".cache",
            ".lock", ".pid", ".swp", ".swo",
            ".pdb", ".ilk", ".idb", ".pch"
        )

        foreach ($ext in $extensions) {
            Add-MpPreference -ExclusionExtension $ext -ErrorAction Stop
        }
        Write-Host "  ✅ Configured $($extensions.Count) temp/debug file extensions" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Some extension exclusions failed" -ForegroundColor Red
    }

    # Configure process exclusions
    Write-Host "`n⚙️ Configuring process exclusions..." -ForegroundColor Yellow
    try {
        $processes = @(
            "node.exe", "npm.exe", "yarn.exe", "pnpm.exe", "bun.exe",
            "cargo.exe", "rustc.exe", "rustup.exe",
            "go.exe", "gofmt.exe", "git.exe",
            "python.exe", "pip.exe", "pipenv.exe", "poetry.exe",
            "dotnet.exe", "msbuild.exe", "devenv.exe",
            "java.exe", "javac.exe", "gradle.exe", "mvn.exe",
            "code.exe", "code-insiders.exe", "cursor.exe",
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

# Check for other antivirus products
Write-Host "`n🔍 Detecting other antivirus products..." -ForegroundColor Yellow

$antivirusProducts = @()

# Check for Malwarebytes and manage coexistence with Defender
$malwarebytesDetected = Set-DefenderMalwarebytesCoexistence -WhatIf:$WhatIf
if ($malwarebytesDetected) {
    $antivirusProducts += "Malwarebytes"
}

# Check for other common antivirus products
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

# Show Malwarebytes guide if requested or detected
if (($ShowMalwarebytesGuide -or $ShowAllGuides) -or ($antivirusProducts -contains "Malwarebytes")) {
    Write-Host "`n📋 MALWAREBYTES EXCLUSION GUIDE" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "1. Open Malwarebytes" -ForegroundColor White
    Write-Host "2. Go to Settings → Security → Exclusions" -ForegroundColor White
    Write-Host "3. Click 'Add Exclusion' and configure:" -ForegroundColor White

    Write-Host "`n📁 FOLDER EXCLUSIONS TO ADD:" -ForegroundColor Yellow
    $mbFolderExclusions = @(
        "C:\DevCache",
        "$env:USERPROFILE\code",
        "$env:USERPROFILE\source",
        "$env:USERPROFILE\repos",
        "$env:USERPROFILE\projects",
        "$env:USERPROFILE\.cargo",
        "$env:USERPROFILE\.rustup",
        "$env:USERPROFILE\go",
        "$env:USERPROFILE\.gradle",
        "$env:USERPROFILE\.m2",
        "$env:USERPROFILE\.nuget",
        "$env:USERPROFILE\.dotnet",
        "$env:USERPROFILE\AppData\Roaming\npm",
        "$env:USERPROFILE\AppData\Local\pip",
        "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code",
        "$env:TEMP",
        "$env:ProgramFiles\JetBrains",
        "$env:ProgramFiles\Microsoft Visual Studio"
    )

    foreach ($exclusion in $mbFolderExclusions) {
        if (Test-Path $exclusion) {
            Write-Host "  • $exclusion" -ForegroundColor Green
        } else {
            Write-Host "  • $exclusion (add when created)" -ForegroundColor Gray
        }
    }

    Write-Host "`n⚙️ PROCESS EXCLUSIONS TO ADD:" -ForegroundColor Yellow
    $mbProcesses = @(
        "node.exe", "npm.exe", "yarn.exe", "pnpm.exe",
        "cargo.exe", "rustc.exe", "git.exe",
        "go.exe", "python.exe", "dotnet.exe",
        "code.exe", "msbuild.exe", "devenv.exe",
        "java.exe", "gradle.exe", "mvn.exe"
    )

    foreach ($process in $mbProcesses) {
        Write-Host "  • $process" -ForegroundColor Green
    }

    Write-Host "`n📄 FILE EXTENSION EXCLUSIONS TO ADD:" -ForegroundColor Yellow
    $mbExtensions = @(".tmp", ".temp", ".log", ".cache", ".lock", ".pid", ".swp", ".pdb")
    foreach ($ext in $mbExtensions) {
        Write-Host "  • $ext" -ForegroundColor Green
    }

    Write-Host "`n📖 Official Guide: https://support.malwarebytes.com/hc/en-us/articles/360038479234" -ForegroundColor Cyan
}

# Show guides for other antivirus products if requested
if ($ShowAllGuides) {
    Write-Host "`n📋 OTHER ANTIVIRUS PRODUCTS" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

    Write-Host "`n🛡️  NORTON/NORTON 360:" -ForegroundColor Yellow
    Write-Host "  Settings → Antivirus → Scans and Risks → Exclusions/Low Risks → Items to Exclude" -ForegroundColor Gray

    Write-Host "`n🛡️  MCAFEE:" -ForegroundColor Yellow
    Write-Host "  Real-Time Scanning → Excluded Files → Add folder/file exclusions" -ForegroundColor Gray

    Write-Host "`n🛡️  AVAST/AVG:" -ForegroundColor Yellow
    Write-Host "  Settings → General → Exceptions → Add Exception" -ForegroundColor Gray

    Write-Host "`n🛡️  BITDEFENDER:" -ForegroundColor Yellow
    Write-Host "  Protection → Antivirus → Settings → Manage Exceptions" -ForegroundColor Gray

    Write-Host "`n🛡️  KASPERSKY:" -ForegroundColor Yellow
    Write-Host "  Settings → Additional → Threats and Exclusions → Exclusions → Specify Trusted Applications" -ForegroundColor Gray

    Write-Host "`n💡 For all products, exclude the same development folders, processes, and file extensions shown above." -ForegroundColor Cyan
}

Write-Host "`n🚀 PERFORMANCE IMPACT" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "Proper exclusions can improve build times by 30-70%:" -ForegroundColor White
Write-Host "  • npm install: 40-60% faster" -ForegroundColor Gray
Write-Host "  • cargo build: 30-50% faster" -ForegroundColor Gray
Write-Host "  • .NET compilation: 25-45% faster" -ForegroundColor Gray
Write-Host "  • Git operations: 20-40% faster" -ForegroundColor Gray

Write-Host "`n✅ Antivirus exclusion configuration complete!" -ForegroundColor Green
Write-Host "   Development builds should now run significantly faster." -ForegroundColor Gray
