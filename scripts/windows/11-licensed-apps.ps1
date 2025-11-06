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
  winget install Malwarebytes.Malwarebytes --source winget --silent --accept-source-agreements --accept-package-agreements
} catch {
  Write-Warning "Malwarebytes failed - install manually"
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
