<#
Licensed/Paid Applications
Installs commercial software with paid licenses. Skip for VMs.
#>
$ErrorActionPreference = 'Stop'

# Source the unattended mode override if it exists
if ($env:DEVMACHINE_OVERRIDE_PATH -and (Test-Path $env:DEVMACHINE_OVERRIDE_PATH)) {
    . $env:DEVMACHINE_OVERRIDE_PATH
}

# Check for unattended mode and provide appropriate messaging
if ($env:UNATTENDED_MODE) {
    Write-Host "🤖 UNATTENDED MODE: Skipping apps that require user interaction" -ForegroundColor Gray
} else {
    Write-Host "⚠️  INTERACTIVE MODE: Some licensed apps may prompt for user input" -ForegroundColor Yellow
    Write-Host "   (account setup, license agreements, trial notifications)" -ForegroundColor Yellow
    Write-Host "   Set `$env:UNATTENDED_MODE = 'true' to skip apps that require interaction" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Installing Licensed Apps..." -ForegroundColor Yellow

Write-Host "1Password..."
if ($env:UNATTENDED_MODE) {
    Write-Host "  → Skipped in unattended mode (requires account setup)" -ForegroundColor Gray
} else {
    # 1Password GUI includes CLI - install main package only
    winget install AgileBits.1Password --source winget --silent --accept-package-agreements --accept-source-agreements
    # CLI is bundled with 1Password GUI installation
    Write-Host "  → 1Password CLI bundled with GUI installation" -ForegroundColor Green
}

Write-Host "Microsoft 365..."
$officeInstalled = (winget list | Select-String -SimpleMatch "Microsoft 365") -or (winget list | Select-String -SimpleMatch "Microsoft Office")
if (-not $officeInstalled) {
  foreach ($id in @("Microsoft.Office","Microsoft.Office.Desktop")) {
    try { winget install $id --source winget --silent --accept-source-agreements --accept-package-agreements; break } catch {}
  }
}

Write-Host "GitKraken..."
if ($env:UNATTENDED_MODE) {
    Write-Host "  → Skipped in unattended mode (requires account setup)" -ForegroundColor Gray
} else {
    # GitKraken GUI includes CLI - install main package only
    winget install Axosoft.GitKraken --source winget --silent --accept-package-agreements --accept-source-agreements
    # CLI is bundled with GitKraken GUI installation
    Write-Host "  → GitKraken CLI bundled with GUI installation" -ForegroundColor Green
}

Write-Host "Beyond Compare..."
try {
  # Try Beyond Compare 5 first (latest), then fall back to v4
  $bcPackages = @("ScooterSoftware.BeyondCompare.5", "ScooterSoftware.BeyondCompare.4")
  $installed = $false
  foreach ($pkg in $bcPackages) {
    try {
      winget install $pkg --source winget --silent --accept-package-agreements --accept-source-agreements
      Write-Host "  ✅ Beyond Compare installed ($pkg)" -ForegroundColor Green
      $installed = $true
      break
    } catch {
      continue
    }
  }
  if (-not $installed) {
    Write-Warning "Beyond Compare not found - install manually from scootersoftware.com"
  }
} catch {
  Write-Warning "Beyond Compare failed - install manually"
}

Write-Host "Scrivener..."
try {
  # Try winget first, then Microsoft Store
  try {
    winget install LiteratureAndLatte.Scrivener --source winget --silent --accept-package-agreements --accept-source-agreements
    Write-Host "  ✅ Scrivener installed via winget" -ForegroundColor Green
  } catch {
    try {
      winget install XP8M0NGDB6HR07 --source msstore --silent --accept-package-agreements --accept-source-agreements
      Write-Host "  ✅ Scrivener installed via Microsoft Store" -ForegroundColor Green
    } catch {
      Write-Warning "Scrivener not found - install manually from literatureandlatte.com"
    }
  }
} catch {
  Write-Warning "Scrivener failed - install manually"
}

Write-Host "Obsidian..."
winget install Obsidian.Obsidian --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "Backblaze..."
# Backblaze Personal Backup is not available via winget - direct download required
Write-Host "  Backblaze Personal Backup requires manual installation" -ForegroundColor Yellow
Write-Host "  💡 Download from: https://www.backblaze.com/b2/sign-up.html" -ForegroundColor Cyan
Write-Host "  💡 After install, sign in with your Backblaze account" -ForegroundColor Cyan

Write-Host "Malwarebytes..."
# Try winget first - capture exit code directly
$process = Start-Process -FilePath "winget" -ArgumentList @("install", "Malwarebytes.Malwarebytes", "--source", "winget", "--silent", "--accept-source-agreements", "--accept-package-agreements") -Wait -PassThru -NoNewWindow
if ($process.ExitCode -eq 0) {
  Write-Host "  ✅ Malwarebytes installed via winget" -ForegroundColor Green
} else {
  Write-Warning "Winget installation failed (Exit code: $($process.ExitCode)). Trying alternative sources..."

  # Try chocolatey as fallback
  if (Get-Command choco -ErrorAction SilentlyContinue) {
    try {
      $chocoProcess = Start-Process -FilePath "choco" -ArgumentList @("install", "malwarebytes", "-y") -Wait -PassThru -NoNewWindow
      if ($chocoProcess.ExitCode -eq 0) {
        Write-Host "  ✅ Malwarebytes installed via Chocolatey" -ForegroundColor Green
      } else {
        Write-Warning "Chocolatey installation also failed. Please install manually from malwarebytes.com"
        Write-Host "  💡 Manual install: Download from https://www.malwarebytes.com/mwb-download" -ForegroundColor Yellow
      }
    } catch {
      Write-Warning "Chocolatey installation failed. Please install manually from malwarebytes.com"
      Write-Host "  💡 Manual install: Download from https://www.malwarebytes.com/mwb-download" -ForegroundColor Yellow
    }
  } else {
    # Try direct download as final fallback
    Write-Host "  Attempting direct download..." -ForegroundColor Yellow
    try {
      $downloadUrl = "https://data-cdn.mbamupdates.com/web/mb4-setup-consumer/MBSetup.exe"
      $downloadPath = "$env:TEMP\MBSetup.exe"
      Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
      Write-Host "  Downloaded installer to $downloadPath" -ForegroundColor Green
      Write-Host "  💡 Run manually: Start-Process '$downloadPath' -Verb RunAs" -ForegroundColor Yellow
    } catch {
      Write-Warning "All installation methods failed. Please install manually from malwarebytes.com"
      Write-Host "  💡 Manual install: Download from https://www.malwarebytes.com/mwb-download" -ForegroundColor Yellow
    }
  }
}

Write-Host "GlassWire..."
try {
  winget install GlassWire.GlassWire --source winget --silent --accept-source-agreements --accept-package-agreements
} catch {
  Write-Warning "GlassWire failed - install manually"
}

# Typora (optional - check environment variable for unattended mode)
if ($env:INSTALL_TYPORA -eq 'Y' -or $env:INSTALL_TYPORA -eq 'yes') {
    Write-Host "Typora..."
    try {
        winget install Typora.Typora --source winget --silent --accept-package-agreements --accept-source-agreements
        Write-Host "  ✅ Typora installed" -ForegroundColor Green
    } catch {
        Write-Warning "Typora installation failed - install manually from typora.io"
    }
} elseif (-not $env:UNATTENDED_MODE) {
    # Only prompt if not in unattended mode
    $opt = Read-Host "Install Typora? (Y/N) [Default: N]"
    if ([string]::IsNullOrWhiteSpace($opt)) { $opt = 'N' }

    if ($opt -eq 'Y') {
        Write-Host "Typora..."
        try {
            winget install Typora.Typora --source winget --silent --accept-package-agreements --accept-source-agreements
            Write-Host "  ✅ Typora installed" -ForegroundColor Green
        } catch {
            Write-Warning "Typora installation failed - install manually from typora.io"
        }
    }
} else {
    Write-Host "Typora skipped (unattended mode, set INSTALL_TYPORA=Y to include)" -ForegroundColor Gray
}

Write-Host "Licensed apps complete!" -ForegroundColor Green
