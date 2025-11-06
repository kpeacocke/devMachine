<#
Windows Debloat Script
Removes pre-installed bloatware: Solitaire, Spotify, Xbox, Candy Crush, etc.
Removes Microsoft Store apps that come pre-installed on Surface and other devices.
#>
$ErrorActionPreference = 'Stop'

Write-Host "[DEBLOAT] Removing Windows bloatware and pre-installed apps..." -ForegroundColor Cyan

# List of bloatware apps to remove (using wildcard patterns)
$bloatwareApps = @(
    # Gaming
    "*Microsoft.XboxApp*"
    "*Microsoft.XboxGamingOverlay*"
    "*Microsoft.XboxGameOverlay*"
    "*Microsoft.XboxSpeechToTextOverlay*"
    "*Microsoft.Xbox.TCUI*"
    "*Microsoft.XboxIdentityProvider*"
    "*Microsoft.GamingApp*"

    # Games
    "*Microsoft.MicrosoftSolitaireCollection*"
    "*Microsoft.MicrosoftMahjong*"
    "*king.com.CandyCrush*"
    "*king.com.BubbleWitch3Saga*"
    "*Microsoft.BingNews*"

    # Social/Communication (keeping Mail/Calendar)
    "*Microsoft.YourPhone*"
    "*Microsoft.People*"

    # Media
    "*SpotifyAB.SpotifyMusic*"
    "*Microsoft.ZuneMusic*"
    "*Microsoft.ZuneVideo*"
    "*Microsoft.Getstarted*"

    # Mixed Reality
    "*Microsoft.MixedReality.Portal*"

    # Office (we'll install proper Office via licensed apps if needed)
    "*Microsoft.Office.OneNote*"
    "*Microsoft.MicrosoftOfficeHub*"

    # Other bloatware
    "*Microsoft.SkypeApp*"
    "*Microsoft.GetHelp*"
    "*Microsoft.Messaging*"
    "*Microsoft.549981C3F5F10*"  # Cortana
    "*Microsoft.BingWeather*"
    "*Disney*"
    "*Netflix*"
    "*Twitter*"
    "*Facebook*"
    "*Flipboard*"
    "*LinkedIn*"
    "*Duolingo*"
    "*PandoraMediaInc*"
    "*Dolby*"
    "*DrawboardPDF*"
    "*Microsoft.Advertising.Xaml*"
)

Write-Host "🗑️  Removing bloatware apps..." -ForegroundColor Yellow

$removedCount = 0
$failedCount = 0

foreach ($app in $bloatwareApps) {
    try {
        $packages = Get-AppxPackage -AllUsers $app -ErrorAction SilentlyContinue
        if ($packages) {
            foreach ($package in $packages) {
                Write-Host "  Removing: $($package.Name)" -ForegroundColor Gray
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop | Out-Null
                $removedCount++
            }
        }

        # Also remove provisioned packages (prevents reinstall on new user profiles)
        $provisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $app }
        if ($provisionedPackages) {
            foreach ($provPackage in $provisionedPackages) {
                Write-Host "  Removing provisioned: $($provPackage.DisplayName)" -ForegroundColor Gray
                Remove-AppxProvisionedPackage -Online -PackageName $provPackage.PackageName -ErrorAction Stop | Out-Null
            }
        }
    } catch {
        Write-Host "  ⚠️  Could not remove $app : $_" -ForegroundColor Yellow
        $failedCount++
    }
}

Write-Host "✅ Removed $removedCount bloatware packages" -ForegroundColor Green
if ($failedCount -gt 0) {
    Write-Host "⚠️  $failedCount packages could not be removed (may not be installed)" -ForegroundColor Yellow
}

# Optional: Remove OneDrive (ask user first - already handled in 35-privacy-telemetry.ps1)
Write-Host "💡 Note: OneDrive removal is handled in 35-privacy-telemetry.ps1" -ForegroundColor Cyan

# Disable Windows Consumer Features (prevents auto-install of apps like Candy Crush)
Write-Host "🚫 Disabling Windows Consumer Features (prevents app reinstalls)..."
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord
Write-Host "✅ Consumer features disabled - bloatware won't reinstall" -ForegroundColor Green

# Clean up Windows.old if it exists (from previous Windows updates)
Write-Host "🧹 Checking for Windows.old folder..."
if (Test-Path "C:\Windows.old") {
    $response = Read-Host "  Found Windows.old folder. Remove it to free up disk space? (Y/N) [Default: Y]"
    if ([string]::IsNullOrWhiteSpace($response)) { $response = 'Y' }
    if ($response -eq 'Y') {
        try {
            Write-Host "  Running Disk Cleanup for previous Windows installations..." -ForegroundColor Yellow
            Write-Host "  This may take a few minutes..." -ForegroundColor Yellow
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/autoclean" -Wait -NoNewWindow
            Write-Host "✅ Windows.old cleanup initiated" -ForegroundColor Green
        } catch {
            Write-Warning "Could not run disk cleanup: $_"
        }
    }
}

Write-Host "[OK] Windows debloat complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Removed: Xbox apps, games (Solitaire, etc.), Spotify, bloatware" -ForegroundColor Green
Write-Host "✅ Disabled: Consumer features (prevents reinstall)" -ForegroundColor Green
Write-Host "✅ Kept: Microsoft Store, Photos, Calculator, Camera, Snipping Tool" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "💡 TIP: Restart Windows to ensure all changes take effect" -ForegroundColor Yellow
