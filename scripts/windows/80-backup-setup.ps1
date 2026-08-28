<#
Backup setup for Surface Pro dev machine:
- Install Backblaze for cloud backup
- Configure Windows File History
- Enable System Protection (restore points)
Run in pwsh (Admin recommended for full features)
#>

param(
  [string]$FileHistoryDrive = "D:",  # Adjust if using external drive
  [switch]$SkipFileHistory           # Skip File History if no secondary drive available
)

$ErrorActionPreference = 'Stop'

Write-Host "💡 Note: Backblaze installation moved to 11-licensed-apps.ps1" -ForegroundColor Yellow
Write-Host "   Run that script first if you want Backblaze cloud backup\n" -ForegroundColor Yellow

if (-not $SkipFileHistory) {
  Write-Host "🗂️ Configuring Windows File History"
  if (Test-Path "$FileHistoryDrive\") {
    try {
      # Enable File History
      $fhTarget = "$FileHistoryDrive\FileHistory"
      New-Item -ItemType Directory -Force -Path $fhTarget | Out-Null
      
      # Configure via registry (simplest approach)
      reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileHistory" /v Enabled /t REG_DWORD /d 1 /f | Out-Null
      
      Write-Host "✅ File History target set to $fhTarget"
      Write-Host "   Complete setup: Settings → Backup → File History"
    } catch {
      Write-Warning "File History setup failed: $_. Configure manually in Settings."
    }
  } else {
    Write-Warning "File History drive $FileHistoryDrive not found. Use -SkipFileHistory or specify correct drive."
  }
}

Write-Host "🔄 Enabling System Protection (Restore Points) for C:"
try {
  $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  if (-not (Test-Path $windowsPowerShell)) {
    throw "Windows PowerShell 5.1 not found at $windowsPowerShell"
  }

  & $windowsPowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command `
    "Enable-ComputerRestore -Drive 'C:\' -ErrorAction Stop"
  if ($LASTEXITCODE -ne 0) {
    throw "Enable-ComputerRestore failed with exit code $LASTEXITCODE"
  }

  # Set max usage to 5% of disk (on 512GB = ~25GB)
  vssadmin Resize ShadowStorage /For=C: /On=C: /MaxSize=25GB | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "vssadmin Resize ShadowStorage failed with exit code $LASTEXITCODE"
  }

  Write-Host "✅ System Protection enabled. Creating initial restore point..."
  & $windowsPowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command `
    "Checkpoint-Computer -Description 'Backup-Setup-Complete' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop"
  if ($LASTEXITCODE -ne 0) {
    throw "Checkpoint-Computer failed with exit code $LASTEXITCODE"
  }
} catch {
  Write-Warning "System Protection setup failed: $_"
}

Write-Host "💡 Backup recommendations:"
Write-Host "  - Backblaze: Sign in and verify backup is running"
Write-Host "  - File History: Verify in Settings → Backup"
Write-Host "  - Dev Drive caches: Exclude from Backblaze (Settings → Exclusions)"
Write-Host "  - Consider: Weekly backup schedule for critical projects"

Write-Host "✅ Backup setup complete."
