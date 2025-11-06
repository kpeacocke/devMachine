<#
.SYNOPSIS
    Maintain Python environment: upgrade pip and update all installed packages.

.DESCRIPTION
    This script upgrades pip to the latest version and updates all installed Python packages.
    Run periodically to keep your Python environment up to date.

.EXAMPLE
    .\scripts\windows\61-python-maintain.ps1
#>
$ErrorActionPreference = 'Stop'

Write-Host "🐍 Python Environment Maintenance" -ForegroundColor Cyan

# Check if Python is installed
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "  ❌ Python not found. Please run 10-windows-bootstrap.ps1 first." -ForegroundColor Red
    exit 1
}

# Display current Python version
$pythonVersion = python --version
Write-Host "  Current Python: $pythonVersion" -ForegroundColor Green

# Upgrade pip
Write-Host "`n📦 Upgrading pip..."
try {
    python -m pip install --upgrade pip
    $pipVersion = python -m pip --version
    Write-Host "  [OK] $pipVersion" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Failed to upgrade pip: $_" -ForegroundColor Red
    exit 1
}

# List outdated packages
Write-Host "`n📋 Checking for outdated packages..."
try {
    $outdated = python -m pip list --outdated --format=json | ConvertFrom-Json

    if ($outdated.Count -eq 0) {
        Write-Host "  ✅ All packages are up to date!" -ForegroundColor Green
    } else {
        Write-Host "  Found $($outdated.Count) outdated package(s):" -ForegroundColor Yellow
        foreach ($pkg in $outdated) {
            Write-Host "    • $($pkg.name): $($pkg.version) → $($pkg.latest_version)" -ForegroundColor Yellow
        }

        # Ask user if they want to update all packages
        $response = Read-Host "`n  Update all packages? (Y/N) [Default: Y]"
        if ([string]::IsNullOrWhiteSpace($response)) { $response = 'Y' }

        if ($response -eq 'Y') {
            Write-Host "`n  Updating packages..." -ForegroundColor Cyan
            foreach ($pkg in $outdated) {
                Write-Host "    Updating $($pkg.name)..." -ForegroundColor Gray
                try {
                    python -m pip install --upgrade $pkg.name
                    Write-Host "      [OK] $($pkg.name) updated" -ForegroundColor Green
                } catch {
                    Write-Host "      [WARN] Failed to update $($pkg.name): $_" -ForegroundColor Yellow
                }
            }
            Write-Host "`n  ✅ Package updates complete!" -ForegroundColor Green
        } else {
            Write-Host "  → Skipped package updates" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  ❌ Failed to check for outdated packages: $_" -ForegroundColor Red
    exit 1
}

# Update pipx packages if pipx is installed
if (Get-Command pipx -ErrorAction SilentlyContinue) {
    Write-Host "`n🔧 Updating pipx-managed tools..."
    try {
        pipx upgrade-all
        Write-Host "  [OK] pipx tools updated" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Failed to upgrade pipx tools: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n  ℹ️  pipx not installed - skipping pipx updates" -ForegroundColor Gray
}

Write-Host "`n✅ Python maintenance complete!" -ForegroundColor Green
