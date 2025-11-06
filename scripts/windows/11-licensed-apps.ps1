<#
Licensed/Paid Applications
Installs commercial software with paid licenses. Skip for VMs.
#>
$ErrorActionPreference = 'Stop'

Write-Host "Installing Licensed Apps..." -ForegroundColor Yellow

Write-Host "1Password..."
winget install AgileBits.1Password --source winget --silent --accept-package-agreements --accept-source-agreements
winget install 1Password.CLI --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "Microsoft 365..."
$officeInstalled = (winget list | Select-String -SimpleMatch "Microsoft 365") -or (winget list | Select-String -SimpleMatch "Microsoft Office")
if (-not $officeInstalled) {
  foreach ($id in @("Microsoft.Office","Microsoft.Office.Desktop")) {
    try { winget install $id --source winget --silent --accept-source-agreements --accept-package-agreements; break } catch {}
  }
}

Write-Host "GitKraken..."
winget install Axosoft.GitKraken --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "Beyond Compare..."
winget install ScooterSoftware.BeyondCompare4 --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "Scrivener..."
winget install LiteratureAndLatte.Scrivener3 --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "Obsidian..."
winget install Obsidian.Obsidian --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "Backblaze..."
try {
  winget install Backblaze.Backblaze --source winget --silent --accept-source-agreements --accept-package-agreements
} catch {
  Write-Warning "Backblaze failed - install manually"
}

Write-Host "Malwarebytes..."
try {
  # Try winget first
  winget install Malwarebytes.Malwarebytes --source winget --silent --accept-source-agreements --accept-package-agreements
  Write-Host "  ✅ Malwarebytes installed via winget" -ForegroundColor Green
} catch {
  Write-Warning "Winget installation failed (Error 200 common). Trying alternative sources..."

  # Try msstore source as fallback
  try {
    winget install 9P0R8S0LZJX7 --source msstore --accept-package-agreements --accept-source-agreements
    Write-Host "  ✅ Malwarebytes installed via Microsoft Store" -ForegroundColor Green
  } catch {
    # Try chocolatey as final fallback
    if (Get-Command choco -ErrorAction SilentlyContinue) {
      try {
        choco install malwarebytes -y
        Write-Host "  ✅ Malwarebytes installed via Chocolatey" -ForegroundColor Green
      } catch {
        Write-Warning "All installation methods failed. Please install manually from malwarebytes.com"
        Write-Host "  💡 Manual install: Download from https://www.malwarebytes.com/mwb-download" -ForegroundColor Yellow
      }
    } else {
      Write-Warning "Malwarebytes installation failed. Install manually from malwarebytes.com"
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

$opt = Read-Host "Install Typora? (Y/N) [Default: N]"
if ([string]::IsNullOrWhiteSpace($opt)) { $opt = 'N' }

if ($opt -eq 'Y') {
    winget install Typora.Typora --source winget --silent --accept-package-agreements --accept-source-agreements
}

Write-Host "Licensed apps complete!" -ForegroundColor Green
