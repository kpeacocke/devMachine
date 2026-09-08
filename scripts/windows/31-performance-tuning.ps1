<#
.SYNOPSIS
    Safe Surface Pro performance tuning.

.DESCRIPTION
    Configures power, Storage Sense, Explorer, Windows Search and network settings.
    Windows executables are invoked by absolute System32 paths so the script is not
    dependent on a damaged or incomplete PATH.

    The standard DevMachine Dev Drive is C:\DevCache. The search exclusion is written
    even when the Dev Drive has not yet been created, so the later Phase 6 creation
    is covered without requiring a second tuning pass.
#>

param(
  [switch]$SetUltimateNow,
  [string]$DevCachePath = 'C:\DevCache'
)

$ErrorActionPreference = 'Stop'
$systemRoot = $env:SystemRoot
$powercfg = Join-Path $systemRoot 'System32\powercfg.exe'
$reg = Join-Path $systemRoot 'System32\reg.exe'
$netsh = Join-Path $systemRoot 'System32\netsh.exe'
$dism = Join-Path $systemRoot 'System32\Dism.exe'

# Backwards compatibility with the old orchestrator default.
if ($DevCachePath -ieq 'D:\dev\caches') { $DevCachePath = 'C:\DevCache' }

foreach ($exe in @($powercfg, $reg, $netsh, $dism)) {
  if (-not (Test-Path -LiteralPath $exe)) { throw "Required Windows executable not found: $exe" }
}

Write-Host '== Power plan: expose Ultimate Performance'
try { & $powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null } catch {}
if ($PSBoundParameters.ContainsKey('SetUltimateNow')) {
  $plans = & $powercfg -l
  $match = $plans | Select-String -Pattern 'Ultimate Performance'
  if (-not $match) { throw 'Ultimate Performance power plan was not found after attempting to expose it.' }
  $guid = $match.ToString().Split()[3]
  & $powercfg -setactive $guid
  if ($LASTEXITCODE -ne 0) { throw "powercfg -setactive failed with exit code $LASTEXITCODE" }
} else {
  Write-Host '→ Keeping current plan (pass -SetUltimateNow to switch)'
}

Write-Host '== Storage Sense automation'
$storageKey = 'HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
& $reg add $storageKey /v 01 /t REG_DWORD /d 1 /f | Out-Null
& $reg add $storageKey /v 02 /t REG_DWORD /d 2 /f | Out-Null
& $reg add $storageKey /v 08 /t REG_DWORD /d 1 /f | Out-Null
& $reg add $storageKey /v 32 /t REG_DWORD /d 1 /f | Out-Null
& $reg add $storageKey /v 33 /t REG_DWORD /d 30 /f | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Storage Sense registry configuration failed with exit code $LASTEXITCODE" }

Write-Host '== Search indexing: exclude Dev Drive caches'
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
Write-Host "→ Windows Search exclusion registered for $DevCachePath"

Write-Host '== File Explorer: dev-friendly toggles'
& $reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v HideFileExt /t REG_DWORD /d 0 /f | Out-Null
& $reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' /v Hidden /t REG_DWORD /d 1 /f | Out-Null
& $reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState' /v FullPath /t REG_DWORD /d 1 /f | Out-Null

Write-Host '== Clean Windows component store'
try {
  & $dism /Online /Cleanup-Image /StartComponentCleanup
  if ($LASTEXITCODE -ne 0) { throw "DISM exited with code $LASTEXITCODE" }
  Write-Host '→ Component cleanup complete'
} catch {
  Write-Warning "Component cleanup failed: $_"
}

Write-Host '== Optimize Windows Search indexing'
try {
  Set-Service WSearch -StartupType Automatic
  Start-Service WSearch -ErrorAction SilentlyContinue
  $searchKey = 'HKLM:\SOFTWARE\Microsoft\Windows Search'
  if (!(Test-Path $searchKey)) { New-Item -Path $searchKey -Force | Out-Null }
  Set-ItemProperty -Path $searchKey -Name ThrottleQueueSizeInKB -Value 8192 -Type DWord -ErrorAction SilentlyContinue
  Set-ItemProperty -Path $searchKey -Name UseGathererService -Value 0 -Type DWord -ErrorAction SilentlyContinue
} catch { Write-Warning "Could not optimize Windows Search: $_" }

Write-Host '== Disable Superfetch/Prefetch (SSD optimization)'
try {
  Stop-Service SysMain -Force -ErrorAction SilentlyContinue
  Set-Service SysMain -StartupType Disabled
} catch { Write-Warning "Could not disable SysMain: $_" }

Write-Host '== Network optimizations'
& $reg add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' /v NetworkThrottlingIndex /t REG_DWORD /d 0xffffffff /f | Out-Null
& $netsh int tcp set global autotuninglevel=normal | Out-Null
& $netsh int tcp set global rss=enabled | Out-Null

Write-Host '→ Network stack optimized'
Write-Host '✅ Performance tuning complete.'
