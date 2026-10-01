<#
.SYNOPSIS
    Safe Surface Pro performance tuning.

    Windows utilities use explicit System32 paths so a damaged/incomplete PATH
    cannot break the script. Dev Drive search exclusion is registered before the
    Dev Drive exists so Phase 6 does not require a second tuning pass.
#>

param(
  [switch]$SetUltimateNow,
  [string]$DevCachePath = 'C:\DevCache'
)

$ErrorActionPreference = 'Stop'
$root = $env:SystemRoot
$powercfg = Join-Path $root 'System32\powercfg.exe'
$reg = Join-Path $root 'System32\reg.exe'
$netsh = Join-Path $root 'System32\netsh.exe'
$dism = Join-Path $root 'System32\Dism.exe'

if ($DevCachePath -ieq 'D:\dev\caches') { $DevCachePath = 'C:\DevCache' }
foreach ($exe in @($powercfg,$reg,$netsh,$dism)) { if (-not (Test-Path -LiteralPath $exe)) { throw "Required Windows executable not found: $exe" } }

Write-Host '== Power plan: expose Ultimate Performance'
try { & $powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null } catch {}
if ($PSBoundParameters.ContainsKey('SetUltimateNow')) {
  $match = & $powercfg -l | Select-String -Pattern 'Ultimate Performance'
  if (-not $match) { throw 'Ultimate Performance power plan was not found.' }
  $guid = $match.ToString().Split()[3]
  & $powercfg -setactive $guid
  if ($LASTEXITCODE -ne 0) { throw "powercfg failed with exit code $LASTEXITCODE" }
}

Write-Host '== Storage Sense automation'
$key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
foreach ($pair in @(@('01','1'),@('02','2'),@('08','1'),@('32','1'),@('33','30'))) {
  & $reg add $key /v $pair[0] /t REG_DWORD /d $pair[1] /f | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Failed setting Storage Sense value $($pair[0])" }
}

Write-Host '== Search indexing: register Dev Drive cache exclusion'
$scope = 'HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex\Sites\LocalHost\Paths'
New-Item -Path $scope -Force | Out-Null
$existing = Get-ChildItem -Path $scope -ErrorAction SilentlyContinue | Where-Object {
  try { (Get-ItemProperty -LiteralPath $_.PSPath -Name Path -ErrorAction Stop).Path -ieq $DevCachePath } catch { $false }
} | Select-Object -First 1
if (-not $existing) {
  $k = (New-Guid).Guid
  New-Item -Path "$scope\$k" -Force | Out-Null
  New-ItemProperty -Path "$scope\$k" -Name Path -PropertyType String -Value $DevCachePath -Force | Out-Null
  New-ItemProperty -Path "$scope\$k" -Name Include -PropertyType DWord -Value 0 -Force | Out-Null
}

Write-Host '== File Explorer: dev-friendly toggles'
& $reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v HideFileExt /t REG_DWORD /d 0 /f | Out-Null
& $reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v Hidden /t REG_DWORD /d 1 /f | Out-Null
& $reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState' /v FullPath /t REG_DWORD /d 1 /f | Out-Null

Write-Host '== Clean Windows component store'
try {
  & $dism /Online /Cleanup-Image /StartComponentCleanup
  if ($LASTEXITCODE -ne 0) { throw "DISM exited with code $LASTEXITCODE" }
} catch { Write-Warning "Component cleanup failed: $_" }

Write-Host '== Optimize Windows Search indexing'
try {
  Set-Service WSearch -StartupType Automatic
  Start-Service WSearch -ErrorAction SilentlyContinue
} catch { Write-Warning "Could not optimize Windows Search: $_" }

Write-Host '== SSD service tuning'
try {
  Stop-Service SysMain -Force -ErrorAction SilentlyContinue
  Set-Service SysMain -StartupType Disabled
} catch { Write-Warning "Could not disable SysMain: $_" }

Write-Host '== Network optimizations'
& $reg add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' /v NetworkThrottlingIndex /t REG_DWORD /d 0xffffffff /f | Out-Null
& $netsh int tcp set global autotuninglevel=normal | Out-Null
& $netsh int tcp set global rss=enabled | Out-Null
Write-Host '✅ Performance tuning complete.'
