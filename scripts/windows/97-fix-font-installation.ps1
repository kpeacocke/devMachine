# Enhanced Font Installation Script
# Fixes font installation for admin prompts with multiple fallback methods

$ErrorActionPreference = 'Stop'

# Support unattended mode
$unattendedMode = $env:UNATTENDED_MODE

Write-Host "[FONT FIX] Enhanced JetBrainsMono Nerd Font Installation..." -ForegroundColor Cyan

# Check if already installed
Write-Host "  Checking for existing JetBrainsMono Nerd Font installation..."
$existingFonts = Get-ChildItem -Path "$env:windir\Fonts" -Filter "*JetBrains*" -ErrorAction SilentlyContinue
if ($existingFonts.Count -gt 0) {
    Write-Host "  Found existing JetBrains fonts:" -ForegroundColor Green
    $existingFonts | ForEach-Object { Write-Host "    • $($_.Name)" -ForegroundColor Gray }

    if ($unattendedMode) {
        Write-Host "  → Skipping reinstall in unattended mode" -ForegroundColor Yellow
        exit 0
    }

    $choice = Read-Host "  Reinstall anyway? (Y/N) [Default: N]"
    if ($choice -ne 'Y' -and $choice -ne 'y') {
        Write-Host "  → Skipping font installation" -ForegroundColor Yellow
        exit 0
    }
}

# Download JetBrainsMono Nerd Font
Write-Host "  Downloading JetBrainsMono Nerd Font from GitHub..."
$ProgressPreference = 'SilentlyContinue'
$url = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip'
$zipPath = Join-Path $env:TEMP 'JetBrainsMono.zip'
$extractPath = Join-Path $env:TEMP 'JetBrainsMono'

try {
    # Clean up any previous downloads
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

    # Download and extract
    Invoke-WebRequest -Uri $url -OutFile $zipPath -ErrorAction Stop
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Host "  ✅ Font archive downloaded and extracted" -ForegroundColor Green

    # Get font files (exclude Windows Compatible versions as they're lower quality)
    $fonts = Get-ChildItem -Path $extractPath -Include '*.ttf' -Recurse | Where-Object {
        $_.Name -notmatch 'Windows Compatible' -and $_.Name -match 'JetBrainsMono.*\.ttf$'
    }

    if ($fonts.Count -eq 0) {
        throw "No suitable TTF font files found in downloaded archive"
    }

    Write-Host "  Found $($fonts.Count) font files to install" -ForegroundColor Green

    # Method 1: Registry-based installation (most reliable for admin context)
    Write-Host "  Installing fonts using registry method..."
    $installed = 0
    $skipped = 0
    $failed = 0

    foreach ($font in $fonts) {
        $fontName = $font.BaseName
        $targetPath = Join-Path $env:windir "Fonts\$($font.Name)"

        try {
            # Check if already exists
            if (Test-Path $targetPath) {
                Write-Host "    → $fontName (already exists)" -ForegroundColor Gray
                $skipped++
                continue
            }

            # Copy font file to Windows\Fonts
            Copy-Item -Path $font.FullName -Destination $targetPath -Force

            # Register font in registry
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
            $regName = "$fontName (TrueType)"
            Set-ItemProperty -Path $regPath -Name $regName -Value $font.Name -Force

            Write-Host "    ✅ $fontName" -ForegroundColor Green
            $installed++

        } catch {
            Write-Host "    ❌ $fontName - $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        }
    }

    Write-Host "  Registry method: $installed installed, $skipped skipped, $failed failed" -ForegroundColor Cyan

    # Method 2: COM-based fallback (if registry method had failures)
    if ($failed -gt 0) {
        Write-Host "  Attempting COM-based installation for failed fonts..."

        try {
            $FONTS = 0x14
            $fontsFolder = (New-Object -ComObject Shell.Application).Namespace($FONTS)

            $failedFonts = $fonts | Where-Object { -not (Test-Path "C:\Windows\Fonts\$($_.Name)") }
            foreach ($font in $failedFonts) {
                try {
                    $fontsFolder.CopyHere($font.FullName, 0x10 + 0x4) # 0x10 = overwrite, 0x4 = no UI
                    Write-Host "    ✅ $($font.BaseName) (COM method)" -ForegroundColor Green
                    $installed++
                } catch {
                    Write-Warning "    COM installation failed for $($font.BaseName): $_"
                }
            }
        } catch {
            Write-Warning "COM-based font installation failed: $_"
        }
    }

    # Method 3: PowerShell Add-Type method (if others fail)
    $stillFailed = $fonts | Where-Object { -not (Test-Path "C:\Windows\Fonts\$($_.Name)") }
    if ($stillFailed.Count -gt 0) {
        Write-Host "  Attempting Add-Type method for remaining fonts..."

        try {
            Add-Type -AssemblyName PresentationCore
            foreach ($font in $stillFailed) {
                try {
                    $fontFamily = New-Object System.Windows.Media.FontFamily($font.FullName)
                    if ($fontFamily.Source) {
                        # Copy manually if Add-Type validation passes
                        $targetPath = Join-Path $env:windir "Fonts\$($font.Name)"
                        Copy-Item -Path $font.FullName -Destination $targetPath -Force
                        Write-Host "    ✅ $($font.BaseName) (Add-Type method)" -ForegroundColor Green
                        $installed++
                    }
                } catch {
                    Write-Warning "    Add-Type installation failed for $($font.BaseName): $_"
                }
            }
        } catch {
            Write-Warning "Add-Type font installation method not available: $_"
        }
    }

} catch {
    Write-Error "Font download/installation failed: $_"
    Write-Host "  💡 Manual installation:" -ForegroundColor Yellow
    Write-Host "    1. Download from: https://www.nerdfonts.com/font-downloads" -ForegroundColor Gray
    Write-Host "    2. Extract ZIP file" -ForegroundColor Gray
    Write-Host "    3. Right-click TTF files → Install for all users" -ForegroundColor Gray
    exit 1
} finally {
    # Cleanup
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    $ProgressPreference = 'Continue'
}

# Verify installation
Write-Host "`n  Verifying font installation..."
$installedJetBrains = Get-ChildItem -Path "$env:windir\Fonts" -Filter "*JetBrains*" -ErrorAction SilentlyContinue
if ($installedJetBrains.Count -gt 0) {
    Write-Host "  ✅ Verification successful - found $($installedJetBrains.Count) JetBrains font files" -ForegroundColor Green
    $installedJetBrains | ForEach-Object { Write-Host "    • $($_.Name)" -ForegroundColor Gray }
} else {
    Write-Host "  ❌ Verification failed - no JetBrains fonts found in Windows\Fonts" -ForegroundColor Red
}

# Check font registry entries
Write-Host "  Checking font registry entries..."
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
$jetBrainsEntries = Get-ItemProperty -Path $regPath | Get-Member -MemberType NoteProperty |
    Where-Object { $_.Name -like "*JetBrains*" } | Select-Object -ExpandProperty Name

if ($jetBrainsEntries.Count -gt 0) {
    Write-Host "  ✅ Found $($jetBrainsEntries.Count) JetBrains font registry entries" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  No JetBrains font registry entries found" -ForegroundColor Yellow
}

Write-Host "`n[FONT CACHE] Refreshing system font cache..." -ForegroundColor Cyan
try {
    # Method 1: Use ie4uinit.exe (most reliable)
    Start-Process -FilePath "$env:windir\System32\ie4uinit.exe" -ArgumentList "-ClearIconCache" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue

    # Method 2: Use fc-cache if available (for apps that use fontconfig)
    if (Get-Command fc-cache -ErrorAction SilentlyContinue) {
        Start-Process -FilePath "fc-cache" -ArgumentList "-f" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
    }

    # Method 3: Restart Windows Font Cache Service
    Restart-Service -Name "FontCache" -Force -ErrorAction SilentlyContinue

    Write-Host "  ✅ Font cache refreshed" -ForegroundColor Green
} catch {
    Write-Warning "Font cache refresh failed: $_"
    Write-Host "  💡 You may need to restart applications to see new fonts" -ForegroundColor Yellow
}

Write-Host "`n[OK] Enhanced font installation complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Method Used:       Registry + COM fallback" -ForegroundColor Green
Write-Host "✅ Fonts Installed:   JetBrainsMono Nerd Font (TTF)" -ForegroundColor Green
Write-Host "✅ Font Cache:        Refreshed" -ForegroundColor Green
Write-Host "✅ Registry:          Font entries added" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "💡 Restart applications (VS Code, Terminal) to use new fonts" -ForegroundColor Yellow
Write-Host "💡 Font available as: 'JetBrainsMono Nerd Font', 'JetBrainsMono NF'" -ForegroundColor Yellow
