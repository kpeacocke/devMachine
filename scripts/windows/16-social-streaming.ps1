<#
Social Media & Streaming Apps
Installs social media apps and streaming services from Microsoft Store
NOTE: Most streaming services are web-based or Microsoft Store apps
#>
$ErrorActionPreference = 'Stop'

Write-Host "[SOCIAL & STREAMING] Installing social media and streaming apps..." -ForegroundColor Cyan

# Helper function to install Microsoft Store apps
function Install-StoreApp {
    param(
        [string]$AppId,
        [string]$Name
    )
    try {
        Write-Host "  Installing $Name..." -ForegroundColor Gray
        winget install --id $AppId --source msstore --silent --accept-package-agreements --accept-source-agreements
    } catch {
        Write-Warning "Could not install $Name - may need manual install from Microsoft Store"
    }
}

Write-Host "📱 Social Media Apps"
# Facebook
Install-StoreApp -AppId "9WZDNCRFJ2WL" -Name "Facebook"
# Instagram
Install-StoreApp -AppId "9NBLGGH5L9XT" -Name "Instagram"
# Facebook Messenger (not available as standalone Windows app - web-based)
Write-Host "  ℹ️  Facebook Messenger: Use web version at messenger.com" -ForegroundColor Yellow
# LinkedIn
Install-StoreApp -AppId "9WZDNCRFJ35Q" -Name "LinkedIn"
# X (Twitter)
Install-StoreApp -AppId "9NBLGGH4S3T0" -Name "X (Twitter)"
# Bluesky (no official Windows app yet)
Write-Host "  ℹ️  Bluesky: No official Windows app - use web version at bsky.app" -ForegroundColor Yellow
# Reddit (official Microsoft Store app)
Install-StoreApp -AppId "9NBLGGH4S1SP" -Name "Reddit"

Write-Host "🎵 Music & Entertainment"
# Apple Music
Install-StoreApp -AppId "9PFHDD62MXS1" -Name "Apple Music"
# Apple TV
Install-StoreApp -AppId "9NM4T8B9JQZ1" -Name "Apple TV"
# Disney+
Install-StoreApp -AppId "9NXQXXLFST89" -Name "Disney+"
# Netflix
Install-StoreApp -AppId "9WZDNCRFJ3TJ" -Name "Netflix"
# Paramount+
Install-StoreApp -AppId "9PH88KGTCMNQ" -Name "Paramount+"
# Prime Video
Install-StoreApp -AppId "9P6RC76MSMMJ" -Name "Prime Video"
# Stan
Install-StoreApp -AppId "9NBLGGH5XXXZ" -Name "Stan"
# Binge
Write-Host "  ℹ️  Binge: No official Windows app - use web version at binge.com.au" -ForegroundColor Yellow

Write-Host "📺 Media Players & TV Streaming"
# Plex (player, not server)
winget install Plex.Plex --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🇦🇺 Australian Free-to-Air TV Apps"
# ABC iview
Install-StoreApp -AppId "9NBLGGH5XV1Q" -Name "ABC iview"
# SBS On Demand
Install-StoreApp -AppId "9NBLGGH5XV3X" -Name "SBS On Demand"
# 7plus
Install-StoreApp -AppId "9WZDNCRFJ2CR" -Name "7plus"
# 9Now
Install-StoreApp -AppId "9NBLGGH5XV7M" -Name "9Now"
# 10 play
Install-StoreApp -AppId "9WZDNCRFJ2FQ" -Name "10 play"

Write-Host "🎮 Gaming & Specialty Streaming"
# YouTube (no official 1st party Windows app - best alternatives)
Write-Host "  ℹ️  YouTube: No official Windows app from Google" -ForegroundColor Yellow
Write-Host "     Recommended: Use web browser or install 'YouTube' from Microsoft Store (3rd party)" -ForegroundColor Yellow
# Warhammer TV (no dedicated Windows app)
Write-Host "  ℹ️  Warhammer+: No official Windows app - use web version at warhammerplus.com" -ForegroundColor Yellow

Write-Host "[OK] Social & streaming apps installation complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Social Media:    Facebook, Instagram, LinkedIn, X, Reddit" -ForegroundColor Green
Write-Host "✅ Music:           Apple Music, Apple TV" -ForegroundColor Green
Write-Host "✅ Streaming:       Disney+, Netflix, Paramount+, Prime Video, Stan" -ForegroundColor Green
Write-Host "✅ AU Free-to-Air:  ABC iview, SBS On Demand, 7plus, 9Now, 10 play" -ForegroundColor Green
Write-Host "✅ Media Player:    Plex" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "💡 Web-only services:" -ForegroundColor Yellow
Write-Host "   • Facebook Messenger: messenger.com" -ForegroundColor Gray
Write-Host "   • Bluesky: bsky.app" -ForegroundColor Gray
Write-Host "   • Binge: binge.com.au" -ForegroundColor Gray
Write-Host "   • Warhammer+: warhammerplus.com" -ForegroundColor Gray
Write-Host "   • YouTube: youtube.com (or 3rd party app from Microsoft Store)" -ForegroundColor Gray
