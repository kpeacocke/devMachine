<#
Advanced Security Hardening & Optimization
Run AFTER app installation. Applies advanced security (BitLocker, Credential Guard, HVCI, LSA Protection)
and optimization settings. REQUIRES REBOOT after completion.
NOTE: Basic hardening (firewall, UAC, Defender) is done in 01-early-hardening.ps1 BEFORE app installation.
#>

$ErrorActionPreference = 'Stop'
function Test-Command($n){ $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

Write-Host "[ADVANCED HARDENING] Applying advanced security and optimization..." -ForegroundColor Cyan
Write-Host "   Note: This script applies settings that require a reboot" -ForegroundColor Yellow

Write-Host "`n== Create a system restore point (best-effort)"
try { Checkpoint-Computer -Description "Pre-Advanced-Harden" -RestorePointType "MODIFY_SETTINGS" } catch { }

# PERFORMANCE / QUALITY OF LIFE
Write-Host "`n== WSL Configuration"
Write-Host "   Creating/updating .wslconfig (resource caps for battery/thermals)..."
$wslCfg = @"
[wsl2]
memory=8GB
processors=6
swap=4GB
localhostForwarding=true
networkingMode=mirrored
pageReporting=true
autoProxy=true

[experimental]
sparseVhd=true
autoMemoryReclaim=gradual
"@
$wslPath = Join-Path $env:UserProfile ".wslconfig"
$wslCfg | Out-File -FilePath $wslPath -Encoding utf8
Write-Host "   ✅ .wslconfig created" -ForegroundColor Green

Write-Host "`n== Power Plan Configuration"
Write-Host "   Exposing Ultimate Performance plan (activate later if needed)..."
try { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null } catch {}
powercfg /change standby-timeout-dc 30  | Out-Null
powercfg /change standby-timeout-ac 0   | Out-Null
powercfg /change monitor-timeout-ac 30  | Out-Null
Write-Host "   ✅ Power plan configured" -ForegroundColor Green

Write-Host "`n== Storage Sense"
Write-Host "   Enabling automated cleanup..."
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 01 /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 02 /t REG_DWORD /d 2 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 08 /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 32 /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 33 /t REG_DWORD /d 30 /f | Out-Null
Write-Host "   ✅ Storage Sense enabled" -ForegroundColor Green

# ADVANCED SECURITY (requires reboot)
Write-Host "`n== Defender: Performance exclusions for dev folders"
# Exclude common dev folders and build artifacts to avoid scan overhead
$exclusions = @(
  "$env:USERPROFILE\.cargo"
  "$env:USERPROFILE\.rustup"
  "$env:USERPROFILE\go"
  "$env:USERPROFILE\.gradle"
  "$env:USERPROFILE\.m2"
  "$env:USERPROFILE\.nuget"
  "$env:USERPROFILE\.dotnet"
  "$env:USERPROFILE\AppData\Local\pip"
  "$env:USERPROFILE\AppData\Local\pipx"
  "$env:USERPROFILE\AppData\Roaming\npm"
  "D:\dev\caches" # Dev Drive caches
)
# Process exclusions
foreach ($path in $exclusions) {
  if (Test-Path $path) {
    try {
      Add-MpPreference -ExclusionPath $path
      Write-Host "  → Excluded: $path"
    } catch { Write-Warning "Failed to exclude $path" }
  }
}
# Exclude common temp/build folders by pattern (applies globally)
try {
  Add-MpPreference -ExclusionPath "*\node_modules"
  Add-MpPreference -ExclusionPath "*\.git"
  Add-MpPreference -ExclusionPath "*\target" # Rust/Maven
  Add-MpPreference -ExclusionPath "*\build" # Generic build output
  Add-MpPreference -ExclusionPath "*\dist"  # Generic dist output
  Add-MpPreference -ExclusionPath "*\.venv" # Python virtual envs
  Add-MpPreference -ExclusionPath "*\venv"
  Write-Host "  → Excluded common build/temp folders (node_modules, .git, target, build, dist, .venv)"
} catch { Write-Warning "Some folder exclusions failed" }
Write-Host "   ✅ Defender exclusions configured" -ForegroundColor Green

Write-Host "`n== Defender Attack Surface Reduction (ASR) — Audit mode first"
$ASR = @{
  "56a863a9-875e-4185-98a7-b882c64b5ce5" = "AuditMode" # vulnerable driver block
  "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" = "AuditMode" # LSASS credential theft
  "d4f940ab-401b-4efc-aadc-ad5f3c50688e" = "AuditMode" # Office child processes
}
$ids = $ASR.Keys
$acts = $ASR.Values | ForEach-Object {
  switch ($_) {
    "Enabled" { 1 }
    "AuditMode" { 2 }
    default { 0 }
  }
}
Add-MpPreference -AttackSurfaceReductionRules_Ids $ids -AttackSurfaceReductionRules_Actions $acts
Write-Host "   ✅ ASR rules enabled in audit mode" -ForegroundColor Green

Write-Host "`n== Controlled Folder Access"
Set-MpPreference -EnableControlledFolderAccess Disabled 2>$null
Write-Host "   ⚠️  Controlled Folder Access disabled (to avoid blocking dev tools)" -ForegroundColor Yellow
Write-Host "   💡 Enable manually if needed for ransomware protection" -ForegroundColor Gray

Write-Host "`n== PowerShell Script Block Logging (security auditing)"
$regPath = "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
Set-ItemProperty -Path $regPath -Name "EnableScriptBlockLogging" -Value 1 -Force
Write-Host "   ✅ PowerShell script block logging enabled" -ForegroundColor Green

Write-Host "== Audit Process Creation: include command line"
New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Force | Out-Null
New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Name "ProcessCreationIncludeCmdLine_Enabled" -PropertyType DWord -Value 1 -Force | Out-Null
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null

Write-Host "== Enhanced audit policies"
auditpol /set /subcategory:"Logon" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Account Lockout" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"File Share" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Other Object Access Events" /success:enable /failure:enable | Out-Null

Write-Host "== Increase Security log size (500MB Security, 100MB System)"
wevtutil sl Security /ms:524288000 | Out-Null
wevtutil sl System /ms:104857600 | Out-Null

Write-Host "== LSA protection (RunAsPPL)"
try {
  $lsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
  if (-not (Test-Path $lsaPath)) { New-Item -Path $lsaPath -Force | Out-Null }
  Set-ItemProperty -Path $lsaPath -Name "RunAsPPL" -Value 1 -Type DWord -Force -ErrorAction Stop
} catch {
  Write-Warning "LSA protection setting skipped (may require UEFI configuration): $_"
}

Write-Host "== Core Isolation (HVCI) — enable if supported"
try {
  $dgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
  if (-not (Test-Path $dgPath)) { New-Item -Path $dgPath -Force | Out-Null }
  Set-ItemProperty -Path $dgPath -Name "EnableVirtualizationBasedSecurity" -Value 1 -Type DWord -Force

  $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
  if (-not (Test-Path $hvciPath)) { New-Item -Path $hvciPath -Force | Out-Null }
  Set-ItemProperty -Path $hvciPath -Name "Enabled" -Value 1 -Type DWord -Force
} catch {
  Write-Warning "HVCI settings skipped (hardware may not support): $_"
}

Write-Host "== Enable Credential Guard (with UEFI lock)"
try {
  $dgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
  Set-ItemProperty -Path $dgPath -Name "RequirePlatformSecurityFeatures" -Value 3 -Type DWord -Force
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LsaCfgFlags" -Value 1 -Type DWord -Force
  Write-Host "   ✅ Credential Guard and LSA Protection enabled (requires reboot)" -ForegroundColor Green
} catch {
  Write-Warning "Credential Guard settings skipped: $_"
}

Write-Host "`n== OpenSSH Server: Enable with key-only authentication"
try {
  Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
  Set-Service -Name sshd -StartupType Automatic
  Start-Service sshd
  Write-Host "   ✅ OpenSSH Server enabled" -ForegroundColor Green
} catch { Write-Warning "OpenSSH install skipped/failed: $_" }
$sshd = "$env:ProgramData\ssh\sshd_config"
if (Test-Path $sshd) {
  (Get-Content $sshd) |
    ForEach-Object {
      $_ -replace '^\s*#?\s*PasswordAuthentication\s+yes','PasswordAuthentication no' `
         -replace '^\s*#?\s*PubkeyAuthentication\s+no','PubkeyAuthentication yes'
    } | Set-Content -Encoding ascii $sshd
  Restart-Service sshd -ErrorAction SilentlyContinue
}

Write-Host "== BitLocker: ensure protection on C:"
try {
  $osVol = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
  if ($osVol.ProtectionStatus -ne "On") {
    Enable-BitLocker -MountPoint "C:" -UsedSpaceOnly -TpmProtector -EncryptionMethod XtsAes256 -SkipHardwareTest
    Write-Host "  → BitLocker enabling (will encrypt in background). Save your recovery key!"
  } else { Write-Host "  → BitLocker already ON" }
} catch { Write-Warning "BitLocker check failed (Home edition or not provisioned?): $_" }

Write-Host "== Schedule weekly winget upgrades (Mon 3AM)"
$taskName = "Dev-Winget-Weekly-Upgrade"
schtasks /Query /TN $taskName /FO LIST 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  schtasks /Create /SC WEEKLY /D MON /TN $taskName /TR "powershell.exe -ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -Command winget upgrade --all --include-unknown --silent" /ST 03:00 /RL HIGHEST /F | Out-Null
}

Write-Host "✅ Optimize & Harden complete. Reboot to finalize LSA/DeviceGuard changes."
