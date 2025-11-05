<#
Licensed/Paid Applications (Optional for VMs)
Installs commercial software that requires licenses:
- 1Password (password manager) - ~$36-96/year
- Microsoft 365/Office - ~$70-100/year
- GitKraken (Git GUI) - Free for public repos, ~$60-90/year for private
- Beyond Compare 4 (diff tool) - ~$60 one-time
- Scrivener 3 (writing software) - ~$50-60 one-time
- Obsidian (note-taking) - Free for personal use
- Backblaze (cloud backup) - ~$99/year
- Malwarebytes (anti-malware) - Free for manual scans, ~$40/year for real-time
- GlassWire (network monitor) - Free basic version, ~$50-100 one-time for pro

Skip this script when setting up VMs or if you don't need these tools.
#>

$ErrorActionPreference = 'Stop'

Write-Host "💰 Installing Licensed/Commercial Applications" -ForegroundColor Yellow
Write-Host "   Note: You'll need valid licenses for full functionality`n" -ForegroundColor Yellow

Write-Host "🔐 1Password (Password Manager + CLI)"
Write-Host "   License: ~$36-96/year | Trial: 30 days" -ForegroundColor Gray
winget install AgileBits.1Password 1Password.CLI `
  --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "📄 Microsoft 365 (Office)"
Write-Host "   License: ~$70-100/year | Trial: 30 days" -ForegroundColor Gray
$officeInstalled = (winget list | Select-String -SimpleMatch "Microsoft 365") -or (winget list | Select-String -SimpleMatch "Microsoft Office")
if (-not $officeInstalled) {
  foreach ($id in @("Microsoft.Office","Microsoft.Office.Desktop")) {
    try { winget install $id --source winget --silent --accept-source-agreements --accept-package-agreements; break } catch {}
  }
}

Write-Host "🌲 GitKraken (Git GUI)"
Write-Host "   License: Free for public repos, ~$60-90/year for private | Trial: 7 days" -ForegroundColor Gray
winget install Axosoft.GitKraken --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "📊 Beyond Compare 4 (File Comparison)"
Write-Host "   License: ~$60 one-time | Trial: 30 days" -ForegroundColor Gray
winget install ScooterSoftware.BeyondCompare4 --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "📝 Scrivener 3 (Writing Software)"
Write-Host "   License: ~$50-60 one-time | Trial: 30 days" -ForegroundColor Gray
winget install LiteratureAndLatte.Scrivener3 --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🧠 Obsidian (Note-Taking)"
Write-Host "   License: Free for personal use, ~$50/year for commercial" -ForegroundColor Gray
winget install Obsidian.Obsidian --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "☁️ Backblaze (Cloud Backup)"
Write-Host "   License: ~$99/year for unlimited backup | Trial: 15 days" -ForegroundColor Gray
try {
  winget install Backblaze.Backblaze --source winget --silent --accept-source-agreements --accept-package-agreements
} catch {
  Write-Warning "Backblaze install failed. Install manually from https://www.backblaze.com/download.html"
}

Write-Host "🛡️ Malwarebytes (Anti-Malware)"
Write-Host "   License: Free for manual scans, ~$40/year for real-time protection | Trial: 14 days" -ForegroundColor Gray
try {
  winget install Malwarebytes.Malwarebytes --source winget --silent --accept-source-agreements --accept-package-agreements
} catch {
  Write-Warning "Malwarebytes install failed. Install manually from https://www.malwarebytes.com/"
}

Write-Host "🌐 GlassWire (Network Monitor)"
Write-Host "   License: Free basic version, ~$50-100 one-time for pro | Trial: 7 days" -ForegroundColor Gray
try {
  winget install GlassWire.GlassWire --source winget --silent --accept-source-agreements --accept-package-agreements
} catch {
  Write-Warning "GlassWire install failed. Install manually from https://www.glasswire.com/"
}

Write-Host "💡 License Summary:" -ForegroundColor Cyan
Write-Host "   Annual Cost: ~$205-395/year (after one-time purchases)" -ForegroundColor Yellow
Write-Host "   First Year:  ~$315-505 (including one-time tools)" -ForegroundColor Yellow
Write-Host "   Free Alternatives Available:" -ForegroundColor Green
Write-Host "   - 1Password → Bitwarden (free)" -ForegroundColor Gray
Write-Host "   - Beyond Compare → WinMerge (free)" -ForegroundColor Gray
Write-Host "   - GitKraken → GitHub Desktop, Fork (free)" -ForegroundColor Gray
Write-Host "   - Backblaze → Google Drive, OneDrive (included with Microsoft 365)" -ForegroundColor Gray
Write-Host "   - Office → LibreOffice, Google Docs (free)" -ForegroundColor Gray

Write-Host "✅ Licensed applications installed. Remember to activate your licenses!" -ForegroundColor Green
