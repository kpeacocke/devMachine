<#<#

Licensed/Paid Applications (Optional for VMs)Licensed/Paid Applications (Optional for VMs)

Installs commercial software that requires licenses:Installs commercial software that requires licenses:

- 1Password (password manager) - ~$36-96/year- 1Password (password manager) - ~$36-96/year

- Microsoft 365/Office - ~$70-100/year- Microsoft 365/Office - ~$70-100/year

- GitKraken (Git GUI) - Free for public repos, ~$60-90/year for private- GitKraken (Git GUI) - Free for public repos, ~$60-90/year for private

- Beyond Compare 4 (diff tool) - ~$60 one-time- Beyond Compare 4 (diff tool) - ~$60 one-time

- Scrivener 3 (writing software) - ~$50-60 one-time- Scrivener 3 (writing software) - ~$50-60 one-time

- Obsidian (note-taking) - Free for personal use- Obsidian (note-taking) - Free for personal use

- Backblaze (cloud backup) - ~$99/year- Backblaze (cloud backup) - ~$99/year

- Malwarebytes (anti-malware) - Free for manual scans, ~$40/year for real-time- Malwarebytes (anti-malware) - Free for manual scans, ~$40/year for real-time

- GlassWire (network monitor) - Free basic version, ~$50-100 one-time for pro- GlassWire (network monitor) - Free basic version, ~$50-100 one-time for pro

- Postman (API testing) - Optional, Free tier, Pro ~$12-49/month- Postman (API testing) - Optional, Free tier, Pro ~$12-49/month

- Typora (markdown editor) - Optional, ~$15 one-time- Typora (markdown editor) - Optional, ~$15 one-time



Skip this script when setting up VMs or if you don't need these tools.Skip this script when setting up VMs or if you don't need these tools.

#>#>



$ErrorActionPreference = 'Stop'$ErrorActionPreference = 'Stop'



Write-Host "💰 Installing Licensed/Commercial Applications" -ForegroundColor YellowWrite-Host "💰 Installing Licensed/Commercial Applications" -ForegroundColor Yellow

Write-Host "   Note: You'll need valid licenses for full functionality`n" -ForegroundColor YellowWrite-Host "   Note: You'll need valid licenses for full functionality`n" -ForegroundColor Yellow



Write-Host "🔐 1Password (Password Manager + CLI)"Write-Host "🔐 1Password (Password Manager + CLI)"

Write-Host "   License: ~$36-96/year | Trial: 30 days" -ForegroundColor GrayWrite-Host "   License: ~$36-96/year | Trial: 30 days" -ForegroundColor Gray

winget install AgileBits.1Password 1Password.CLI `winget install AgileBits.1Password 1Password.CLI `

  --source winget --silent --accept-package-agreements --accept-source-agreements  --source winget --silent --accept-package-agreements --accept-source-agreements



Write-Host "📄 Microsoft 365 (Office)"Write-Host "📄 Microsoft 365 (Office)"

Write-Host "   License: ~$70-100/year | Trial: 30 days" -ForegroundColor GrayWrite-Host "   License: ~$70-100/year | Trial: 30 days" -ForegroundColor Gray

$officeInstalled = (winget list | Select-String -SimpleMatch "Microsoft 365") -or (winget list | Select-String -SimpleMatch "Microsoft Office")$officeInstalled = (winget list | Select-String -SimpleMatch "Microsoft 365") -or (winget list | Select-String -SimpleMatch "Microsoft Office")

if (-not $officeInstalled) {if (-not $officeInstalled) {

  foreach ($id in @("Microsoft.Office","Microsoft.Office.Desktop")) {  foreach ($id in @("Microsoft.Office","Microsoft.Office.Desktop")) {

    try { winget install $id --source winget --silent --accept-source-agreements --accept-package-agreements; break } catch {}    try { winget install $id --source winget --silent --accept-source-agreements --accept-package-agreements; break } catch {}

  }  }

}}



Write-Host "🌲 GitKraken (Git GUI)"Write-Host "🌲 GitKraken (Git GUI)"

Write-Host "   License: Free for public repos, ~$60-90/year for private | Trial: 7 days" -ForegroundColor GrayWrite-Host "   License: Free for public repos, ~$60-90/year for private | Trial: 7 days" -ForegroundColor Gray

winget install Axosoft.GitKraken --source winget --silent --accept-package-agreements --accept-source-agreementswinget install Axosoft.GitKraken --source winget --silent --accept-package-agreements --accept-source-agreements



Write-Host "📊 Beyond Compare 4 (File Comparison)"Write-Host "📊 Beyond Compare 4 (File Comparison)"

Write-Host "   License: ~$60 one-time | Trial: 30 days" -ForegroundColor GrayWrite-Host "   License: ~$60 one-time | Trial: 30 days" -ForegroundColor Gray

winget install ScooterSoftware.BeyondCompare4 --source winget --silent --accept-package-agreements --accept-source-agreementswinget install ScooterSoftware.BeyondCompare4 --source winget --silent --accept-package-agreements --accept-source-agreements



Write-Host "📝 Scrivener 3 (Writing Software)"Write-Host "📝 Scrivener 3 (Writing Software)"

Write-Host "   License: ~$50-60 one-time | Trial: 30 days" -ForegroundColor GrayWrite-Host "   License: ~$50-60 one-time | Trial: 30 days" -ForegroundColor Gray

winget install LiteratureAndLatte.Scrivener3 --source winget --silent --accept-package-agreements --accept-source-agreementswinget install LiteratureAndLatte.Scrivener3 --source winget --silent --accept-package-agreements --accept-source-agreements



Write-Host "🧠 Obsidian (Note-Taking)"Write-Host "🧠 Obsidian (Note-Taking)"

Write-Host "   License: Free for personal use, ~$50/year for commercial" -ForegroundColor GrayWrite-Host "   License: Free for personal use, ~$50/year for commercial" -ForegroundColor Gray

winget install Obsidian.Obsidian --source winget --silent --accept-package-agreements --accept-source-agreementswinget install Obsidian.Obsidian --source winget --silent --accept-package-agreements --accept-source-agreements



Write-Host "☁️ Backblaze (Cloud Backup)"Write-Host "☁️ Backblaze (Cloud Backup)"

Write-Host "   License: ~$99/year for unlimited backup | Trial: 15 days" -ForegroundColor GrayWrite-Host "   License: ~$99/year for unlimited backup | Trial: 15 days" -ForegroundColor Gray

try {try {

  winget install Backblaze.Backblaze --source winget --silent --accept-source-agreements --accept-package-agreements  winget install Backblaze.Backblaze --source winget --silent --accept-source-agreements --accept-package-agreements

} catch {} catch {

  Write-Warning "Backblaze install failed. Install manually from https://www.backblaze.com/download.html"  Write-Warning "Backblaze install failed. Install manually from https://www.backblaze.com/download.html"

}}



Write-Host "🛡️ Malwarebytes (Anti-Malware)"Write-Host "🛡️ Malwarebytes (Anti-Malware)"

Write-Host "   License: Free for manual scans, ~$40/year for real-time protection | Trial: 14 days" -ForegroundColor GrayWrite-Host "   License: Free for manual scans, ~$40/year for real-time protection | Trial: 14 days" -ForegroundColor Gray

try {try {

  winget install Malwarebytes.Malwarebytes --source winget --silent --accept-source-agreements --accept-package-agreements  winget install Malwarebytes.Malwarebytes --source winget --silent --accept-source-agreements --accept-package-agreements

} catch {} catch {

  Write-Warning "Malwarebytes install failed. Install manually from https://www.malwarebytes.com/"  Write-Warning "Malwarebytes install failed. Install manually from https://www.malwarebytes.com/"

}}



Write-Host "🌐 GlassWire (Network Monitor)"Write-Host "🌐 GlassWire (Network Monitor)"

Write-Host "   License: Free basic version, ~$50-100 one-time for pro | Trial: 7 days" -ForegroundColor GrayWrite-Host "   License: Free basic version, ~$50-100 one-time for pro | Trial: 7 days" -ForegroundColor Gray

try {try {

  winget install GlassWire.GlassWire --source winget --silent --accept-source-agreements --accept-package-agreements  winget install GlassWire.GlassWire --source winget --silent --accept-source-agreements --accept-package-agreements

} catch {} catch {

  Write-Warning "GlassWire install failed. Install manually from https://www.glasswire.com/"  Write-Warning "GlassWire install failed. Install manually from https://www.glasswire.com/"

}}



Write-Host "`n📝 Optional: Markdown Editor & API Testing"Write-Host "`n� Optional: Markdown Editor & API Testing"

$installOptionalTools = Read-Host "  Install Typora (markdown editor, $15) or Postman (API testing, free tier)? (1=Typora, 2=Postman, 3=Both, N=Skip) [Default: N]"$installOptionalTools = Read-Host "  Install Typora (markdown editor, $15) or Postman (API testing, free tier)? (1=Typora, 2=Postman, 3=Both, N=Skip) [Default: N]"

if ([string]::IsNullOrWhiteSpace($installOptionalTools)) { $installOptionalTools = 'N' }if ([string]::IsNullOrWhiteSpace($installOptionalTools)) { $installOptionalTools = 'N' }



switch ($installOptionalTools) {switch ($installOptionalTools) {

    '1' {    '1' {

        Write-Host "📝 Typora (Markdown Editor)"        Write-Host "� Typora (Markdown Editor)"

        Write-Host "   License: ~$15 one-time" -ForegroundColor Gray        Write-Host "   License: ~$15 one-time" -ForegroundColor Gray

        winget install Typora.Typora --source winget --silent --accept-package-agreements --accept-source-agreements        winget install Typora.Typora --source winget --silent --accept-package-agreements --accept-source-agreements

    }    }

    '2' {    '2' {

        Write-Host "🔌 Postman (API Testing)"        Write-Host "🛠️ JetBrains Toolbox (IDE Manager)"

        Write-Host "   License: Free tier (limited), Pro ~$12-49/month | Trial: 14 days Pro" -ForegroundColor Gray        Write-Host "   License: ~$149-249/year per tool | Trial: 30 days" -ForegroundColor Gray

        winget install Postman.Postman --source winget --silent --accept-package-agreements --accept-source-agreements        winget install JetBrains.Toolbox --source winget --silent --accept-package-agreements --accept-source-agreements

    }    }

    '3' {    '3' {

        Write-Host "📝 Typora (Markdown Editor)"        Write-Host "� Postman (API Testing)"

        Write-Host "   License: ~$15 one-time" -ForegroundColor Gray        Write-Host "   License: Free tier (limited), Pro ~$12-49/month | Trial: 14 days Pro" -ForegroundColor Gray

        winget install Typora.Typora --source winget --silent --accept-package-agreements --accept-source-agreements        winget install Postman.Postman --source winget --silent --accept-package-agreements --accept-source-agreements



        Write-Host "🔌 Postman (API Testing)"        Write-Host "🛠️ JetBrains Toolbox (IDE Manager)"

        Write-Host "   License: Free tier (limited), Pro ~$12-49/month | Trial: 14 days Pro" -ForegroundColor Gray        Write-Host "   License: ~$149-249/year per tool | Trial: 30 days" -ForegroundColor Gray

        winget install Postman.Postman --source winget --silent --accept-package-agreements --accept-source-agreements        winget install JetBrains.Toolbox --source winget --silent --accept-package-agreements --accept-source-agreements

    }    }

    default {    default {

        Write-Host "  → Skipped optional tools (use Insomnia for free API testing, VS Code for markdown)" -ForegroundColor Yellow        Write-Host "  → Skipped optional dev tools" -ForegroundColor Yellow

    }    }

}}



Write-Host "`n💡 License Summary:" -ForegroundColor CyanWrite-Host "🎨 Optional: Design & Editing Tools"

Write-Host "   Annual Cost: ~$205-395/year (after one-time purchases)" -ForegroundColor Yellow$installDesignTools = Read-Host "  Install Figma, Typora, or Sublime Text? (1=Figma, 2=Typora, 3=Sublime, 4=All, N=Skip) [Default: N]"

Write-Host "   First Year:  ~$315-505 (including one-time tools)" -ForegroundColor Yellowif ([string]::IsNullOrWhiteSpace($installDesignTools)) { $installDesignTools = 'N' }

Write-Host "   + Optional: Postman Pro (~$144-588/year), Typora (~$15 one-time)" -ForegroundColor Yellow

Write-Host "   Free Alternatives Available:" -ForegroundColor Greenswitch ($installDesignTools) {

Write-Host "   - 1Password → Bitwarden (free)" -ForegroundColor Gray    '1' {

Write-Host "   - Beyond Compare → WinMerge (free)" -ForegroundColor Gray        Write-Host "🎨 Figma (Design & Mockups)"

Write-Host "   - GitKraken → GitHub Desktop, Fork (free)" -ForegroundColor Gray        Write-Host "   License: Free tier (limited), Professional ~$12/editor/month" -ForegroundColor Gray

Write-Host "   - Backblaze → Google Drive, OneDrive (included with Microsoft 365)" -ForegroundColor Gray        winget install Figma.Figma --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "   - Office → LibreOffice, Google Docs (free)" -ForegroundColor Gray    }

Write-Host "   - Postman Pro → Insomnia (free, in 14-additional-dev-tools.ps1)" -ForegroundColor Gray    '2' {

Write-Host "   - Typora → VS Code with Markdown extensions (free)" -ForegroundColor Gray        Write-Host "📝 Typora (Markdown Editor)"

        Write-Host "   License: ~$15 one-time" -ForegroundColor Gray

Write-Host "✅ Licensed applications installed. Remember to activate your licenses!" -ForegroundColor Green        winget install Typora.Typora --source winget --silent --accept-package-agreements --accept-source-agreements

    }
    '3' {
        Write-Host "📝 Sublime Text (Text Editor)"
        Write-Host "   License: ~$99 one-time (free trial indefinite with nag screen)" -ForegroundColor Gray
        winget install SublimeHQ.SublimeText.4 --source winget --silent --accept-package-agreements --accept-source-agreements
    }
    '4' {
        Write-Host "🎨 Figma (Design & Mockups)"
        Write-Host "   License: Free tier (limited), Professional ~$12/editor/month" -ForegroundColor Gray
        winget install Figma.Figma --source winget --silent --accept-package-agreements --accept-source-agreements

        Write-Host "📝 Typora (Markdown Editor)"
        Write-Host "   License: ~$15 one-time" -ForegroundColor Gray
        winget install Typora.Typora --source winget --silent --accept-package-agreements --accept-source-agreements

        Write-Host "📝 Sublime Text (Text Editor)"
        Write-Host "   License: ~$99 one-time (free trial indefinite with nag screen)" -ForegroundColor Gray
        winget install SublimeHQ.SublimeText.4 --source winget --silent --accept-package-agreements --accept-source-agreements
    }
    default {
        Write-Host "  → Skipped design & editing tools" -ForegroundColor Yellow
    }
}

Write-Host "�💡 License Summary:" -ForegroundColor Cyan
Write-Host "   Annual Cost: ~$205-395/year (after one-time purchases)" -ForegroundColor Yellow
Write-Host "   First Year:  ~$315-505 (including one-time tools)" -ForegroundColor Yellow
Write-Host "   + Optional: Postman Pro (~$144-588/year), Figma Pro (~$144/year), JetBrains (~$149-249/year)" -ForegroundColor Yellow
Write-Host "   Free Alternatives Available:" -ForegroundColor Green
Write-Host "   - 1Password → Bitwarden (free)" -ForegroundColor Gray
Write-Host "   - Beyond Compare → WinMerge (free)" -ForegroundColor Gray
Write-Host "   - GitKraken → GitHub Desktop, Fork (free)" -ForegroundColor Gray
Write-Host "   - Backblaze → Google Drive, OneDrive (included with Microsoft 365)" -ForegroundColor Gray
Write-Host "   - Office → LibreOffice, Google Docs (free)" -ForegroundColor Gray
Write-Host "   - Postman Pro → Insomnia (free, in 14-additional-dev-tools.ps1)" -ForegroundColor Gray
Write-Host "   - Figma Pro → draw.io, Penpot (free)" -ForegroundColor Gray
Write-Host "   - Typora → Mark Text, ghostwriter (free)" -ForegroundColor Gray
Write-Host "   - Sublime Text → VS Code, Notepad++ (free)" -ForegroundColor Gray
Write-Host "   - JetBrains → VS Code with extensions (free)" -ForegroundColor Gray

Write-Host "✅ Licensed applications installed. Remember to activate your licenses!" -ForegroundColor Green
