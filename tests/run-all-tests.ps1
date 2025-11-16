# Test Runner for Dev Machine Setup
# Run all tests with: pwsh -NoProfile -File .\tests\run-all-tests.ps1

param(
    [switch]$SkipWindowsTests,
    [switch]$SkipUbuntuTests,
    [switch]$SkipSyntaxValidation,
    [switch]$FastMode,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Set verbose output if requested
if ($Verbose) {
    $VerbosePreference = 'Continue'
}

Write-Host "🧪 Dev Machine Setup - Test Runner" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Get repository root
$RepoRoot = if ($PSScriptRoot) {
    Split-Path -Parent $PSScriptRoot
} else {
    Split-Path -Parent (Get-Location)
}

# Track test results
$testResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
}

function Run-PesterTest {
    param(
        [string]$TestFile,
        [string]$Description,
        [switch]$SkipIfNotAvailable
    )

    if ($SkipIfNotAvailable -and -not (Test-Path $TestFile)) {
        Write-Host "⏭️  Skipping $Description (file not found)" -ForegroundColor Yellow
        return
    }

    Write-Host "🧪 Running $Description..." -ForegroundColor Cyan

    try {
        $config = New-PesterConfiguration
        $config.Run.Path = $TestFile
        $config.Run.PassThru = $true
        $config.Output.Verbosity = if ($Verbose) { 'Detailed' } else { 'Normal' }

        $result = Invoke-Pester -Configuration $config

        $testResults.TotalTests += $result.TotalCount
        $testResults.PassedTests += $result.PassedCount
        $testResults.FailedTests += $result.FailedCount
        $testResults.SkippedTests += $result.SkippedCount

        if ($result.FailedCount -eq 0) {
            Write-Host "✅ $Description passed ($($result.PassedCount) tests)" -ForegroundColor Green
        } else {
            Write-Host "❌ $Description failed ($($result.FailedCount) failed, $($result.PassedCount) passed)" -ForegroundColor Red
        }

        if ($Verbose -and $result.FailedCount -gt 0) {
            Write-Host "Failed tests:" -ForegroundColor Red
            $result.Failed | ForEach-Object {
                Write-Host "  - $($_.Block) > $($_.Name)" -ForegroundColor Red
            }
        }

    } catch {
        Write-Host "❌ Error running $Description`: $_" -ForegroundColor Red
        $testResults.FailedTests++
    }
}

function Run-BashTest {
    param(
        [string]$TestFile,
        [string]$Description
    )

    Write-Host "🐚 Running $Description..." -ForegroundColor Cyan

    try {
        # Check if WSL is available
        if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
            Write-Host "⏭️  Skipping $Description (WSL not available)" -ForegroundColor Yellow
            $testResults.SkippedTests++
            return
        }

        # Convert Windows path to WSL path
        $wslPath = $TestFile -replace '\\', '/' -replace '^([A-Z]):', { '/mnt/' + $_.Groups[1].Value.ToLower() }

        # Run the test via WSL
        $result = wsl bash $wslPath 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Host "✅ $Description passed" -ForegroundColor Green
            $testResults.PassedTests++
        } else {
            Write-Host "❌ $Description failed (exit code: $exitCode)" -ForegroundColor Red
            Write-Host "Output: $result" -ForegroundColor Red
            $testResults.FailedTests++
        }

    } catch {
        Write-Host "❌ Error running $Description`: $_" -ForegroundColor Red
        $testResults.FailedTests++
    }
}

# Check prerequisites
Write-Host "🔍 Checking prerequisites..." -ForegroundColor Cyan

# Check Pester
try {
    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
    Write-Host "✅ Pester 5.0+ available" -ForegroundColor Green
} catch {
    Write-Host "❌ Pester 5.0+ required. Install with: Install-Module -Name Pester -MinimumVersion 5.0 -Force" -ForegroundColor Red
    exit 1
}

# Run syntax validation first (critical)
if (-not $SkipSyntaxValidation) {
    Run-PesterTest -TestFile "$RepoRoot\tests\syntax-validation.Tests.ps1" -Description "Syntax Validation"
}

# Run Windows tests
if (-not $SkipWindowsTests) {
    Write-Host "`n🏁 Running Windows Tests..." -ForegroundColor Magenta

    # Core functionality tests
    Run-PesterTest -TestFile "$RepoRoot\tests\unattended-mode.Tests.ps1" -Description "Unattended Mode Tests"
    Run-PesterTest -TestFile "$RepoRoot\tests\pester.Windows.Tests.ps1" -Description "Windows Environment Tests"

    # Specialized tests
    $specializedTests = @(
        "ci-friendly.Tests.ps1",
        "working-backup.Tests.ps1",
        "comprehensive-windows.Tests.ps1",
        "devdrive-features.Tests.ps1",
        "git-config.Tests.ps1",
        "new-features.Tests.ps1",
        "system-restore.Tests.ps1",
        "cli-tools.Tests.ps1",
        "antivirus-optimization.Tests.ps1"
    )

    foreach ($testFile in $specializedTests) {
        $testPath = "$RepoRoot\tests\$testFile"
        if (Test-Path $testPath) {
            $description = $testFile -replace '\.Tests\.ps1$', ' Tests'
            Run-PesterTest -TestFile $testPath -Description $description -SkipIfNotAvailable
        }
    }
}

# Run Ubuntu tests
if (-not $SkipUbuntuTests) {
    Write-Host "`n🐧 Running Ubuntu Tests..." -ForegroundColor Magenta
    Run-BashTest -TestFile "$RepoRoot\tests\ubuntu-smoke-test.sh" -Description "Ubuntu WSL Smoke Tests"
}

# Summary
Write-Host "`n📊 Test Summary" -ForegroundColor Cyan
Write-Host "==============" -ForegroundColor Cyan
Write-Host "Total Tests: $($testResults.TotalTests)" -ForegroundColor White
Write-Host "Passed: $($testResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed: $($testResults.FailedTests)" -ForegroundColor Red
Write-Host "Skipped: $($testResults.SkippedTests)" -ForegroundColor Yellow

if ($testResults.FailedTests -eq 0) {
    Write-Host "`n🎉 All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Some tests failed. Check output above for details." -ForegroundColor Red
    exit 1
}
