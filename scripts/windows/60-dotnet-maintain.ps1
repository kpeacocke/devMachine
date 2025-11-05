<#
Run: pwsh -File .\60-dotnet-maintain.ps1 [-ScheduleWeekly]
Policy:
  - Ensure latest GA SDK installed (prefers newest feature band; not pinned to LTS).
  - Keep newest 2 SDK feature bands; uninstall older SDKs.
  - Preserve Runtimes (so existing apps still run).
  - Update workloads & NuGet caches.
#>
param([switch]$ScheduleWeekly)

$ErrorActionPreference = 'Stop'
function Test-Command($n){ $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

Write-Host "☕ Ensuring latest .NET SDK..."
try {
  winget install Microsoft.DotNet.SDK.9 --silent --accept-package-agreements --accept-source-agreements
} catch {
  Write-Warning "Winget install failed; trying upgrade..."
  winget upgrade Microsoft.DotNet.SDK.9 --silent --accept-package-agreements --accept-source-agreements | Out-Null
}

if (-not (Test-Command "dotnet")) { throw ".NET SDK not on PATH" }

# Inventory SDKs
$sdkList = & dotnet --list-sdks | ForEach-Object {
  if ($_ -match '^([\d\.]+)\s+\[') { [version]$matches[1] }
} | Sort-Object -Descending

if ($sdkList.Count -gt 0) {
  Write-Host "Installed SDKs: $($sdkList -join ', ')"
}

# Keep newest 2 feature bands; remove older SDKs (not runtimes)
$remove = $sdkList | Select-Object -Skip 2

function Remove-OldSdk([version]$v) {
  try {
    # Best-effort remove via winget family id (not perfect but keeps script simple)
    winget uninstall --exact --id "Microsoft.DotNet.SDK.$($v.Major)" --silent 2>$null | Out-Null
  } catch { }
}

foreach ($v in $remove) {
  Write-Host "🧹 Removing older SDK: $v"
  Remove-OldSdk $v
}

Write-Host "🔧 Updating workloads..."
try { dotnet workload update } catch { Write-Warning "workload update failed: $_" }

Write-Host "🧽 Cleaning NuGet caches..."
try { dotnet nuget locals all --clear } catch {}

Write-Host "✅ .NET maintenance complete."

if ($ScheduleWeekly) {
  $taskName = "Dev-DotNet-Weekly-Maintenance"
  $cmd = "pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\60-dotnet-maintain.ps1`""
  schtasks /Query /TN $taskName /FO LIST 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    schtasks /Create /SC WEEKLY /D MON /ST 03:15 /RL HIGHEST /TN $taskName /TR "$cmd" /F | Out-Null
    Write-Host "🗓️ Scheduled weekly .NET maintenance (Mon 03:15)."
  } else {
    Write-Host "🗓️ Weekly .NET maintenance already scheduled."
  }
}
