<#
.SYNOPSIS
Disable VS Code shell integration to prevent profile loading errors.

.DESCRIPTION
VS Code's automatic shell integration injects code that can cause harmless but
annoying errors during PowerShell profile loading. This script disables the
automatic injection since manual shell integration is already configured in the profile.

Run this if you see errors like:
- "Exception calling GetHistoryItems with 0 argument(s)"
- "The term 'vscode' is not recognized"
#>
$ErrorActionPreference = 'Stop'

Write-Host "🔧 VS Code Shell Integration Fix" -ForegroundColor Cyan
Write-Host ""

$settingsPath = "$env:APPDATA\Code - Insiders\User\settings.json"
$regularSettingsPath = "$env:APPDATA\Code\User\settings.json"

function Update-VSCodeSettings {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Host "  Creating new settings file: $Path" -ForegroundColor Gray
        $parentDir = Split-Path $Path -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        @{
            "terminal.integrated.shellIntegration.enabled" = $false
        } | ConvertTo-Json | Set-Content $Path -Encoding UTF8
        return $true
    }

    $settings = Get-Content $Path -Raw | ConvertFrom-Json

    if ($settings.'terminal.integrated.shellIntegration.enabled' -eq $false) {
        Write-Host "  ✅ Shell integration already disabled" -ForegroundColor Green
        return $false
    }

    $settings | Add-Member -NotePropertyName 'terminal.integrated.shellIntegration.enabled' -NotePropertyValue $false -Force
    $settings | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
    Write-Host "  ✅ Shell integration disabled" -ForegroundColor Green
    return $true
}

# Check VS Code Insiders
Write-Host "📝 VS Code Insiders" -ForegroundColor Cyan
if (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders") {
    $changed = Update-VSCodeSettings -Path $settingsPath
    if ($changed) {
        Write-Host "  💡 Restart VS Code Insiders to apply changes" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ℹ️  VS Code Insiders not installed" -ForegroundColor Gray
}

# Check regular VS Code
Write-Host ""
Write-Host "📝 VS Code (Regular)" -ForegroundColor Cyan
if (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code") {
    $changed = Update-VSCodeSettings -Path $regularSettingsPath
    if ($changed) {
        Write-Host "  💡 Restart VS Code to apply changes" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ℹ️  VS Code not installed" -ForegroundColor Gray
}

Write-Host ""
Write-Host "✅ VS Code shell integration configuration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 What this does:" -ForegroundColor Cyan
Write-Host "   - Disables VS Code's automatic shell integration injection" -ForegroundColor Gray
Write-Host "   - Prevents harmless but annoying PowerShell profile errors" -ForegroundColor Gray
Write-Host "   - Manual shell integration in your profile still works" -ForegroundColor Gray
Write-Host ""
