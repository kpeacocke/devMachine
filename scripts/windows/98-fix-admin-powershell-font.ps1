# PowerShell 7 Admin Console Font Fix
# Specifically addresses font issues in elevated PowerShell 7 prompts
# Run this if you still see font issues after main setup

Write-Host "[POWERSHELL 7 FONT FIX] Configuring admin console font..." -ForegroundColor Cyan

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "This script requires administrator privileges for full functionality"
    Write-Host "Please run as Administrator for best results" -ForegroundColor Yellow
}

# Function to detect best available JetBrainsMono font
function Get-BestJetBrainsFont {
    Write-Host "  Scanning for JetBrainsMono Nerd Font variants..." -ForegroundColor Gray

    $fontDirs = @("$env:windir\Fonts", "$env:LOCALAPPDATA\Microsoft\Windows\Fonts")
    $bestFont = $null

    foreach ($dir in $fontDirs) {
        if (Test-Path $dir) {
            $fonts = Get-ChildItem $dir -Filter "*JetBrains*" | Where-Object {
                $_.Name -match "(NF|Nerd.*Font).*Regular\.ttf$" -or
                $_.Name -match "JetBrainsMono.*Regular\.ttf$"
            } | Sort-Object Name

            if ($fonts) {
                foreach ($font in $fonts) {
                    Write-Host "    Found: $($font.BaseName)" -ForegroundColor Green
                    if (-not $bestFont) { $bestFont = $font }
                }
            }
        }
    }

    if ($bestFont) {
        Write-Host "  Selected best font: $($bestFont.BaseName)" -ForegroundColor Yellow
        return $bestFont.BaseName
    } else {
        Write-Warning "No JetBrainsMono Nerd Font found! Please install fonts first."
        return $null
    }
}

# Get the best available font
$selectedFont = Get-BestJetBrainsFont
if (-not $selectedFont) {
    Write-Host "`n❌ Cannot continue without JetBrainsMono Nerd Font" -ForegroundColor Red
    Write-Host "   Run: .\scripts\windows\10-windows-bootstrap.ps1" -ForegroundColor Yellow
    exit 1
}

# PowerShell console registry configuration
Write-Host "`n  Configuring PowerShell console registry..." -ForegroundColor Yellow

$consolePaths = @(
    # PowerShell 5.x
    "HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe",

    # PowerShell ISE
    "HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell_ise.exe",

    # PowerShell 7 (various possible paths)
    "HKCU:\Console\PowerShell_7",
    "HKCU:\Console\pwsh.exe",
    "HKCU:\Console\PowerShell",

    # Windows Terminal PowerShell
    "HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe",

    # Default console
    "HKCU:\Console"
)

$fontSettings = @{
    "FaceName" = $selectedFont
    "FontFamily" = 54        # Modern TrueType font family
    "FontSize" = 0x000C0000  # 12pt font (high word = height)
    "FontWeight" = 400       # Normal weight
}

$successCount = 0
$failCount = 0

foreach ($path in $consolePaths) {
    try {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }

        foreach ($setting in $fontSettings.GetEnumerator()) {
            Set-ItemProperty -Path $path -Name $setting.Key -Value $setting.Value -Force -ErrorAction Stop
        }

        Write-Host "    ✅ Configured: $($path.Split('\')[-1])" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "    ❌ Failed: $($path.Split('\')[-1]) - $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

# Additional console font registration for PowerShell 7
Write-Host "`n  Registering font for console applications..." -ForegroundColor Yellow
try {
    $consoleFontPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont"
    if (-not (Test-Path $consoleFontPath)) {
        New-Item -Path $consoleFontPath -Force | Out-Null
    }

    # Register the font for console use
    Set-ItemProperty -Path $consoleFontPath -Name "00" -Value $selectedFont -Force -ErrorAction Stop
    Write-Host "    ✅ Console font registry updated" -ForegroundColor Green
} catch {
    Write-Warning "Console font registration failed: $($_.Exception.Message)"
}

# Force refresh font cache
Write-Host "`n  Refreshing system font cache..." -ForegroundColor Yellow
try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class FontAPI {
    [DllImport("gdi32.dll")]
    public static extern int AddFontResource(string lpFileName);

    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public static readonly IntPtr HWND_BROADCAST = new IntPtr(0xFFFF);
    public static readonly uint WM_FONTCHANGE = 0x1D;
}
"@ -ErrorAction SilentlyContinue

    [FontAPI]::SendMessage([FontAPI]::HWND_BROADCAST, [FontAPI]::WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    Write-Host "    ✅ Font cache refreshed" -ForegroundColor Green
} catch {
    Write-Host "    → Font cache refresh failed (not critical)" -ForegroundColor Yellow
}

# Summary and next steps
Write-Host "`n[RESULTS]" -ForegroundColor Cyan
Write-Host "  Console configurations: $successCount successful, $failCount failed" -ForegroundColor Yellow
Write-Host "  Selected font: $selectedFont" -ForegroundColor Yellow

if ($successCount -gt 0) {
    Write-Host "`n✅ PowerShell console font configuration complete!" -ForegroundColor Green
    Write-Host "🔄 IMPORTANT: Close ALL PowerShell windows and restart to see changes" -ForegroundColor Yellow
    Write-Host "   This includes:" -ForegroundColor Gray
    Write-Host "   • Regular PowerShell windows" -ForegroundColor Gray
    Write-Host "   • Admin PowerShell windows" -ForegroundColor Gray
    Write-Host "   • VS Code integrated terminals" -ForegroundColor Gray
    Write-Host "   • Windows Terminal tabs" -ForegroundColor Gray
} else {
    Write-Host "`n❌ No console configurations were successful" -ForegroundColor Red
    Write-Host "💡 Try running as Administrator" -ForegroundColor Yellow
}

Write-Host "`n[TROUBLESHOOTING]" -ForegroundColor Cyan
Write-Host "If fonts still don't appear correctly:" -ForegroundColor Yellow
Write-Host "1. Restart your computer (sometimes required for font changes)" -ForegroundColor Gray
Write-Host "2. In PowerShell window: Right-click title bar → Properties → Font" -ForegroundColor Gray
Write-Host "3. Manually select '$selectedFont' from the font list" -ForegroundColor Gray
Write-Host "4. Ensure Windows Terminal is using the correct font in settings" -ForegroundColor Gray
