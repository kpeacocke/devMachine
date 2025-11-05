<#
Surface Pro (ARM64) — Performance tuning (safe)
- Expose & (optionally) switch to Ultimate Performance
- Storage Sense cleanups
- Indexing exclusions for Dev Drive caches
- File Explorer dev-friendly toggles
- Optional: Visual Effects = “Best performance” (commented)
#>

param(
  [switch]$SetUltimateNow,      # if passed, switches to Ultimate immediately
  [string]$DevCachePath = "D:\dev\caches"  # adjust if your Dev Drive letter differs
)

$ErrorActionPreference = 'Stop'

Write-Host "== Power plan: expose Ultimate Performance"
try { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null } catch {}
if ($PSBoundParameters.ContainsKey('SetUltimateNow')) {
  Write-Host "→ Activating Ultimate Performance"
  $guid = (powercfg -l | Select-String -Pattern "Ultimate Performance").ToString().Split()[3]
  powercfg -setactive $guid
} else {
  Write-Host "→ Keeping current plan (pass -SetUltimateNow to switch)"
}

Write-Host "== Storage Sense automation"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 01 /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 02 /t REG_DWORD /d 2 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 08 /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 32 /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 33 /t REG_DWORD /d 30 /f | Out-Null

Write-Host "== Search indexing: exclude Dev Drive caches"
if (Test-Path $DevCachePath) {
  $scope = "HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex\Sites\LocalHost\Paths"
  New-Item -Path $scope -Force | Out-Null
  $k = (New-Guid).Guid
  New-Item -Path "$scope\$k" -Force | Out-Null
  New-ItemProperty -Path "$scope\$k" -Name "Path" -PropertyType String -Value $DevCachePath -Force | Out-Null
  New-ItemProperty -Path "$scope\$k" -Name "Include" -PropertyType DWord -Value 0 -Force | Out-Null
} else {
  Write-Host "→ Dev cache path not found: $DevCachePath (skip)"
}

Write-Host "== File Explorer: dev-friendly toggles"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v FullPath /t REG_DWORD /d 1 /f | Out-Null

Write-Host "== Clean Windows component store (WinSxS) — save ~2-5GB"
try {
  Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
  Write-Host "→ Component cleanup complete"
} catch {
  Write-Warning "Component cleanup failed: $_"
}

Write-Host "== Disable Windows Search service (install Everything for faster search)"
try {
  Stop-Service WSearch -Force -ErrorAction SilentlyContinue
  Set-Service WSearch -StartupType Disabled
  Write-Host "→ Windows Search disabled"
} catch {
  Write-Warning "Could not disable Windows Search: $_"
}
winget install voidtools.Everything --silent --accept-source-agreements --accept-package-agreements

Write-Host "== Disable Superfetch/Prefetch (SSD optimization)"
try {
  Stop-Service SysMain -Force -ErrorAction SilentlyContinue
  Set-Service SysMain -StartupType Disabled
  Write-Host "→ Superfetch/Prefetch disabled"
} catch {
  Write-Warning "Could not disable SysMain: $_"
}

Write-Host "== Network optimizations"
# Disable bandwidth throttling
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 0xffffffff /f | Out-Null
# Optimize TCP/IP stack
netsh int tcp set global autotuninglevel=normal | Out-Null
netsh int tcp set global chimney=enabled | Out-Null
netsh int tcp set global rss=enabled | Out-Null
Write-Host "→ Network stack optimized"

# OPTIONAL: Visual Effects → Best performance
# reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null

Write-Host "✅ Performance tuning complete."
