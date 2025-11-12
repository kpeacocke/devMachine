<#
Opt into Insider/preview channels:

- Office: BetaChannel (formerly "Insider Fast")
- VS Code: install Insiders, optionally make 'code' -> 'code-insiders'

NOTE: Windows Insider enrollment has been REMOVED from this script as it's
unreliable and potentially dangerous. Use Settings > Windows Update > Windows
Insider Program manually if you need Windows preview builds.
#>

$ErrorActionPreference = 'Stop'

# === Settings you can tweak ===
$MakeCodeCLIPointToInsiders = $true # make 'code' invoke 'code-insiders'

Write-Host "🚀 Insider Channels Setup (Office & VS Code)" -ForegroundColor Cyan
Write-Host "   Note: Windows Insider enrollment removed (do manually if needed)" -ForegroundColor Gray

# 1) OFFICE INSIDER — BetaChannel
Write-Host "🧩 Office: switching to BetaChannel (Insider Fast)"
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate'
New-Item -Path $pol -Force | Out-Null
New-ItemProperty -Path $pol -Name 'updatebranch' -Type String -Value 'BetaChannel' -Force | Out-Null
New-ItemProperty -Path $pol -Name 'enabled'      -Type DWord  -Value 1            -Force | Out-Null
New-ItemProperty -Path $pol -Name 'updatesareenabled' -Type DWord -Value 1        -Force | Out-Null

$odt = "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
if (Test-Path $odt) {
  Write-Host "⏫ Asking Office Click-to-Run to update to BetaChannel..."
  Start-Process -FilePath $odt -ArgumentList "/update user" -Wait:$false
} else {
  Write-Host "ℹ️ OfficeC2RClient not found; run an Office app → Account → Update."
}

# 3) VS CODE INSIDERS
Write-Host "`n📝 VS Code Insiders Setup" -ForegroundColor Cyan

# Remove regular VS Code if present
Write-Host "  Checking for regular VS Code..."
$regularVSCode = winget list --id Microsoft.VisualStudioCode --exact 2>$null
if ($regularVSCode -match "Microsoft.VisualStudioCode") {
    Write-Host "  ⚠️  Found regular VS Code - removing..." -ForegroundColor Yellow
    try {
        winget uninstall Microsoft.VisualStudioCode --silent --accept-source-agreements
        Write-Host "  ✅ Regular VS Code removed" -ForegroundColor Green
    } catch {
        Write-Warning "Could not remove regular VS Code: $_"
    }
} else {
    Write-Host "  ✅ No regular VS Code found" -ForegroundColor Green
}

# Install Insiders
Write-Host "  Installing VS Code Insiders..."
winget install Microsoft.VisualStudioCode.Insiders --source winget --silent --accept-source-agreements --accept-package-agreements
Write-Host "  ✅ VS Code Insiders installed" -ForegroundColor Green

if ($MakeCodeCLIPointToInsiders) {
  Write-Host "🔗 Pointing 'code' CLI to 'code-insiders'"
  $bin = "$env:UserProfile\.local\bin"
  New-Item -ItemType Directory -Force -Path $bin | Out-Null
  $shim = Join-Path $bin "code.cmd"
  "@echo off
code-insiders %*" | Out-File -Encoding ascii $shim
  $uPath = [Environment]::GetEnvironmentVariable('Path','User')
  if ($uPath -notlike "*$bin*") {
    [Environment]::SetEnvironmentVariable('Path', $uPath + ";" + $bin, 'User')
  }
  Write-Host "✅ 'code' now launches VS Code Insiders (open a new terminal to pick up PATH)."
}

Write-Host "🔁 Finally, check Windows Update for Insider builds."
Start-Process "ms-settings:windowsupdate"
Write-Host "✅ Insider opt-in script finished."
