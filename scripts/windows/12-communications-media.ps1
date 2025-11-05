<#
Run optionally for communications and media applications.
Installs: Chrome, Firefox, Teams, WhatsApp, Signal, Slack, Discord, VLC, HandBrake (GUI + CLI), K-Lite Mega Codec Pack
#>
$ErrorActionPreference = 'Stop'

Write-Host "[BROWSERS] Web Browsers"

Write-Host "🌐 Browsers"
Write-Host "  Installing Google Chrome..."
try {
  # Chrome sometimes has hash mismatches due to rapid updates
  winget install Google.Chrome --source winget --silent --accept-package-agreements --accept-source-agreements
  Write-Host "  ✅ Chrome installed" -ForegroundColor Green
} catch {
  Write-Warning "Chrome installation failed (hash mismatch common - try manual install from google.com/chrome)"
}

Write-Host "  Installing Mozilla Firefox..."
winget install Mozilla.Firefox --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n[COMMS] Communications & Media Applications"

Write-Host "💬 Communications Apps"
Write-Host "  Installing Teams..."
winget install Microsoft.Teams --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "  Installing WhatsApp..."
winget install 9NKSQGP7F2NH --source msstore --accept-package-agreements --accept-source-agreements

Write-Host "  Installing Signal..."
winget install OpenWhisperSystems.Signal --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "  Installing Slack..."
winget install SlackTechnologies.Slack --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "  Installing Discord..."
winget install Discord.Discord --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n🎬 Media Applications"
Write-Host "  Installing VLC media player..."
winget install VideoLAN.VLC --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "  Installing HandBrake (GUI)..."
winget install HandBrake.HandBrake --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "  Installing HandBrake CLI..."
winget install HandBrake.HandBrake.CLI --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "  Installing K-Lite Mega Codec Pack..."
winget install CodecGuide.K-LiteCodecPack.Mega --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n[OK] Communications & Media complete."
Write-Host "Installed: Chrome, Firefox, Teams, WhatsApp, Signal, Slack, Discord, VLC, HandBrake (GUI + CLI), K-Lite Mega" -ForegroundColor Green
