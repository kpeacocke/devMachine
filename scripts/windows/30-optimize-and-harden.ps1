<#
Surface Pro (ARM64) — Optimize & Harden
Safe, dev-friendly defaults: power, storage, WSL/Docker, Defender, firewall, logging, SSH (key-only), ASR (audit first).
Reboot recommended after it finishes.
#>

$ErrorActionPreference = 'Stop'
function Has-Command($n){ $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

Write-Host "== Create a system restore point (best-effort)"
try { Checkpoint-Computer -Description "Pre-Optimize-Harden" -RestorePointType "MODIFY_SETTINGS" } catch { }

# PERFORMANCE / QUALITY OF LIFE
Write-Host "== Enable NTFS long paths & Developer Mode"
reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d 1 | Out-Null

Write-Host "== Create/update .wslconfig (resource caps for battery/thermals)"
$wslCfg = @"
[wsl2]
memory=8GB
processors=6
swap=4GB
localhostForwarding=true
networkingMode=mirrored
"@
$wslPath = Join-Path $env:UserProfile ".wslconfig"
$wslCfg | Out-File -FilePath $wslPath -Encoding utf8

Write-Host "== Power plan: Expose Ultimate Performance (you can activate later)"
try { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null } catch {}
powercfg /change standby-timeout-dc 30  | Out-Null
powercfg /change standby-timeout-ac 0   | Out-Null
powercfg /change monitor-timeout-ac 30  | Out-Null

Write-Host "== Storage Sense: enable automated cleanup"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 01 /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 02 /t REG_DWORD /d 2 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 08 /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 32 /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 33 /t REG_DWORD /d 30 /f | Out-Null

Write-Host "== Fonts"
try {
  winget install Microsoft.CascadiaCode NerdFonts.JetBrainsMono --silent --accept-source-agreements --accept-package-agreements
} catch { }

# SECURITY BASELINE
Write-Host "== Firewall: ON for all profiles; inbound block"
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow

Write-Host "== Defender core settings"
Set-MpPreference -PUAProtection Enabled -MAPSReporting Advanced -SubmitSamplesConsent SendSafeSamples -EnableNetworkProtection Enabled

Write-Host "== Defender Attack Surface Reduction (ASR) — Audit mode first"
$ASR = @{
  "56a863a9-875e-4185-98a7-b882c64b5ce5" = "AuditMode" # vulnerable driver block
  "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" = "AuditMode" # LSASS credential theft
  "d4f940ab-401b-4efc-aadc-ad5f3c50688e" = "AuditMode" # Office child processes
}
$ids = $ASR.Keys -join ","
$acts = ($ASR.Values | ForEach-Object { if ($_ -eq "Enabled") {1} elseif ($_ -eq "AuditMode") {2} else {0} }) -join ","
Add-MpPreference -AttackSurfaceReductionRules_Ids $ids -AttackSurfaceReductionRules_Actions $acts

Write-Host "== SmartScreen + script scanning"
Set-MpPreference -EnableScriptBlockLogging $true -EnableControlledFolderAccess Disabled -EnableTamperProtection $true 2>$null

Write-Host "== Audit Process Creation: include command line"
New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Force | Out-Null
New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Name "ProcessCreationIncludeCmdLine_Enabled" -PropertyType DWord -Value 1 -Force | Out-Null
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null

Write-Host "== LSA protection (RunAsPPL)"
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -PropertyType DWord -Value 1 -Force | Out-Null

Write-Host "== Core Isolation (HVCI) — enable if supported"
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -PropertyType DWord -Value 1 -Force | Out-Null
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -PropertyType DWord -Value 1 -Force | Out-Null

Write-Host "== Disable SMBv1"
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null

Write-Host "== RDP disable; OpenSSH enable (key-only)"
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f | Out-Null
try {
  Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
  Set-Service -Name sshd -StartupType Automatic
  Start-Service sshd
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

Write-Host "`n✅ Optimize & Harden complete. Reboot to finalize LSA/DeviceGuard changes."
