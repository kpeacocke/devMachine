<#
Windows Debloat Script
Removes pre-installed bloatware: Spotify, Candy Crush, etc.
Preserves Xbox Live components (Game Bar, Solitaire) for Xbox-enabled games.
Removes Microsoft Store apps that come pre-installed on Surface and other devices.
#>
$ErrorActionPreference = 'Stop'

Write-Host "[DEBLOAT] Removing Windows bloatware and pre-installed apps..." -ForegroundColor Cyan

# Appx/provisioning cmdlets are inbox Windows modules and can be unreliable when
# called from PowerShell 7 on current Windows builds. Run this servicing work in
# the actual Windows PowerShell 5.1 process rather than through compatibility shims.
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path $windowsPowerShell)) {
    throw "Windows PowerShell 5.1 not found at $windowsPowerShell"
}

# List of bloatware apps to remove (using wildcard patterns)
$bloatwareApps = @(
    # Gaming (keeping Xbox Identity Provider for game logins)
    "*Microsoft.XboxApp*"
    "*Microsoft.XboxGamingOverlay*"
    "*Microsoft.XboxGameOverlay*"
    "*Microsoft.XboxSpeechToTextOverlay*"
    "*Microsoft.Xbox.TCUI*"
    "*Microsoft.GamingApp*"

    # Games (keeping Microsoft Solitaire for Xbox login usage)
    "*Microsoft.MicrosoftMahjong*"
    "*king.com.CandyCrush*"
    "*king.com.BubbleWitch3Saga*"
    "*Microsoft.BingNews*"

    # Social/Communication (keeping Mail/Calendar and Phone Link)
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
        $escapedApp = $app.Replace("'", "''")
        $command = @"
`$ErrorActionPreference = 'Stop'
`$removed = 0

Get-AppxPackage -AllUsers '$escapedApp' -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-AppxPackage -Package `$_.PackageFullName -AllUsers -ErrorAction Stop | Out-Null
    `$removed++
}

Get-AppxProvisionedPackage -Online -ErrorAction Stop |
    Where-Object { `$_.DisplayName -like '$escapedApp' } |
    ForEach-Object {
        Remove-AppxProvisionedPackage -Online -PackageName `$_.PackageName -ErrorAction Stop | Out-Null
        `$removed++
    }

Write-Output `$removed
"@

        $output = & $windowsPowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $command 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            throw "Windows PowerShell exited with code $exitCode`: $(($output | Out-String).Trim())"
        }

        $countText = [string]($output | Select-Object -Last 1)
        $count = 0
        if (-not [int]::TryParse($countText.Trim(), [ref]$count)) {
            throw "Unexpected Appx removal result for $app`: $(($output | Out-String).Trim())"
        }

        if ($count -gt 0) {
            Write-Host "  Removed $count package(s) matching: $app" -ForegroundColor Gray
            $removedCount += $count
        }
    } catch {
        Write-Host "  ⚠️  Could not remove $app : $_" -ForegroundColor Yellow
        $failedCount++
    }
}

Write-Host "✅ Removed $removedCount bloatware packages" -ForegroundColor Green
if ($failedCount -gt 0) {
    Write-Host "⚠️  $failedCount package patterns could not be processed" -ForegroundColor Yellow
}

# Note: OneDrive is left enabled (useful for cloud backup and file sync)
Write-Host "💡 Note: OneDrive is left enabled and available" -ForegroundColor Cyan

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
    if ($env:REMOVE_WINDOWS_OLD -eq 'N') {
        Write-Host "  → Keeping Windows.old folder (REMOVE_WINDOWS_OLD=N)" -ForegroundColor Yellow
    } elseif ($env:UNATTENDED_MODE -eq 'true' -or $env:DEVMACHINE_UNATTENDED -eq 'true' -or $env:REMOVE_WINDOWS_OLD -eq 'Y') {
        Write-Host "  → Removing Windows.old folder (unattended mode)" -ForegroundColor Yellow
        $response = 'Y'
    } else {
        $response = Read-Host "  Found Windows.old folder. Remove it to free up disk space? (Y/N) [Default: Y]"
        if ([string]::IsNullOrWhiteSpace($response)) { $response = 'Y' }
    }
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
Write-Host "✅ Removed: Spotify, Candy Crush, and other bloatware" -ForegroundColor Green
Write-Host "✅ Preserved: Xbox Live components (Game Bar, Solitaire) for Xbox functionality" -ForegroundColor Green
Write-Host "✅ Disabled: Consumer features (prevents reinstall)" -ForegroundColor Green
Write-Host "✅ Kept: Microsoft Store, Photos, Calculator, Camera, Snipping Tool" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "💡 TIP: Restart Windows to ensure all changes take effect" -ForegroundColor Yellow
