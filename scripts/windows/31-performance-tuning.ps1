<#
Surface Pro (ARM64) — Performance tuning (safe)
- Expose & (optionally) switch to Ultimate Performance
- Storage Sense cleanups
- Indexing exclusions for Dev Drive caches
- File Explorer dev-friendly toggles
- Optional: Visual Effects = “Best performance” (commented)

The standard DevMachine Dev Drive is mounted at C:\DevCache.
#>

param(
  [switch]$SetUltimateNow,
  [string]$DevCachePath = "C:\DevCache"
)

$ErrorActionPreference = 'Stop'
$systemRoot = $env:SystemRoot
$powercfg = Join-Path $systemRoot 'System32\powercfg.exe'
$reg = Join-Path $systemRoot 'System32\reg.exe'
$netsh = Join-Path $systemRoot 'System32\netsh.exe'
$dism = Join-Path $systemRoot 'System32\Dism.exe'

Write-Host "== Power plan: expose Ultimate Performance"
try { & $powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null } catch {}
if ($PSBoundParameters.ContainsKey('SetUltimateNow')) {
  Write-Host "→ Activating Ultimate Performance"
  $guid = (& $powercfg -l | Select-String -Pattern "Ultimate Performance").ToString().Split()[3]
  & $powercfg -setactive $guid
} else {
  Write-Host "→ Keeping current plan (pass -SetUltimateNow to switch)"
}

Write-Host "== Storage Sense automation"
& $reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 01 /t REG_DWORD /d 1 /f | Out-Null
& $reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 02 /t REG_DWORD /d 2 /f | Out-Null
& $reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 08 /t REG_DWORD /d 1 /f | Out-Null
& $reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 32 /t REG_DWORD /d 1 /f | Out-Null
& $reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" /v 33 /t REG_DWORD /d 30 /f | Out-Null

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
& $reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f | Out-Null
& $reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f | Out-Null
& $reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v FullPath /t REG_DWORD /d 1 /f | Out-Null

Write-Host "== Clean Windows component store (WinSxS) — save ~2-5GB"
try {
  & $dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
  if ($LASTEXITCODE -ne 0) { throw "DISM exited with code $LASTEXITCODE" }
  Write-Host "→ Component cleanup complete"
} catch {
  Write-Warning "Component cleanup failed: $_"
}

Write-Host "== Optimize Windows Search indexing"
try {
  Set-Service WSearch -StartupType Automatic
  Start-Service WSearch -ErrorAction SilentlyContinue

  $searchKey = "HKLM:\SOFTWARE\Microsoft\Windows Search"
  if (!(Test-Path $searchKey)) { New-Item -Path $searchKey -Force | Out-Null }
  Set-ItemProperty -Path $searchKey -Name "ThrottleQueueSizeInKB" -Value 8192 -Type DWord -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $searchKey -Name "UseGathererService" -Value 0 -Type DWord -ErrorAction SilentlyContinue

  Write-Host "→ Windows Search optimized for performance" -ForegroundColor Green
} catch {
  Write-Warning "Could not optimize Windows Search: $_"
}

Write-Host "== Disable Superfetch/Prefetch (SSD optimization)"
try {
  Stop-Service SysMain -Force -ErrorAction SilentlyContinue
  Set-Service SysMain -StartupType Disabled
  Write-Host "→ Superfetch/Prefetch disabled"
} catch {
  Write-Warning "Could not disable SysMain: $_"
}

Write-Host "== Network optimizations"
& $reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 0xffffffff /f | Out-Null
& $netsh int tcp set global autotuninglevel=normal | Out-Null
& $netsh int tcp set global chimney=enabled | Out-Null
& $netsh int tcp set global rss=enabled | Out-Null
Write-Host "→ Network stack optimized"

# OPTIONAL: Visual Effects → Best performance
# & $reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null

Write-Host "✅ Performance tuning complete."
