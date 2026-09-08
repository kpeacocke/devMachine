<#
.SYNOPSIS
    Configure development package caches on the DevMachine Dev Drive.

.DESCRIPTION
    Uses C:\DevCache by default. Idempotent and limited to package-manager cache
    locations. It deliberately does NOT move TEMP/TMP or overwrite Docker Desktop
    daemon.json. TEMP/TMP on a Dev Drive has additional Windows filter requirements;
    Docker Desktop manages its own data-root configuration.
#>

#Requires -Version 5.1

[CmdletBinding()]
param([string]$DevCacheRoot = 'C:\DevCache')

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $DevCacheRoot)) { throw "Dev Drive not found at $DevCacheRoot. Run 41-devdrive-partition-setup.ps1 first." }

$volume = Get-Volume -Path $DevCacheRoot -ErrorAction Stop
if ($volume.FileSystem -ne 'ReFS') { throw "$DevCacheRoot is not ReFS. Refusing to configure caches on a non-Dev Drive." }

$fsutil = Join-Path $env:SystemRoot 'System32\fsutil.exe'
if (-not (Test-Path -LiteralPath $fsutil)) { throw "fsutil.exe not found at $fsutil" }
$status = & $fsutil devdrv query $DevCacheRoot 2>&1
if ($LASTEXITCODE -ne 0 -or (($status | Out-String) -notmatch '(?i)developer volume')) { throw "$DevCacheRoot is not recognised as a Windows Dev Drive." }

Write-Host "[DEVCACHE] Configuring development caches on $DevCacheRoot" -ForegroundColor Cyan

$dirs = @('npm','pnpm','yarn','bun','pip','pipx','poetry','uv','cargo','rustup','go','gradle','maven','nuget','composer','vcpkg','ccache')
foreach ($name in $dirs) { New-Item -ItemType Directory -Path (Join-Path $DevCacheRoot $name) -Force | Out-Null }

function Set-UserEnv {
    param([Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][string]$Value)
    [Environment]::SetEnvironmentVariable($Name,$Value,'User')
    Set-Item -Path "Env:$Name" -Value $Value
    Write-Host "  ✅ $Name → $Value" -ForegroundColor Green
}

if (Get-Command npm -ErrorAction SilentlyContinue) {
    & npm config set cache (Join-Path $DevCacheRoot 'npm') --location=global
    if ($LASTEXITCODE -ne 0) { throw 'npm cache configuration failed.' }
}
if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    & pnpm config set store-dir (Join-Path $DevCacheRoot 'pnpm')
    if ($LASTEXITCODE -ne 0) { throw 'pnpm store configuration failed.' }
}
Set-UserEnv 'YARN_CACHE_FOLDER' (Join-Path $DevCacheRoot 'yarn')
if (Get-Command bun -ErrorAction SilentlyContinue) { Set-UserEnv 'BUN_INSTALL_CACHE_DIR' (Join-Path $DevCacheRoot 'bun') }

Set-UserEnv 'PIP_CACHE_DIR' (Join-Path $DevCacheRoot 'pip')
Set-UserEnv 'PIPX_HOME' (Join-Path $DevCacheRoot 'pipx')
Set-UserEnv 'PIPX_BIN_DIR' (Join-Path $DevCacheRoot 'pipx\bin')
New-Item -ItemType Directory -Path (Join-Path $DevCacheRoot 'pipx\bin') -Force | Out-Null
Set-UserEnv 'POETRY_CACHE_DIR' (Join-Path $DevCacheRoot 'poetry')
if (Get-Command uv -ErrorAction SilentlyContinue) { Set-UserEnv 'UV_CACHE_DIR' (Join-Path $DevCacheRoot 'uv') }

Set-UserEnv 'CARGO_HOME' (Join-Path $DevCacheRoot 'cargo')
Set-UserEnv 'RUSTUP_HOME' (Join-Path $DevCacheRoot 'rustup')
Set-UserEnv 'GOPATH' (Join-Path $DevCacheRoot 'go')
Set-UserEnv 'GOMODCACHE' (Join-Path $DevCacheRoot 'go\pkg\mod')
New-Item -ItemType Directory -Path (Join-Path $DevCacheRoot 'go\pkg\mod') -Force | Out-Null
$goBin = Join-Path $DevCacheRoot 'go\bin'
New-Item -ItemType Directory -Path $goBin -Force | Out-Null
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
$entries = @($userPath -split ';' | Where-Object { $_ })
if ($entries -notcontains $goBin) { [Environment]::SetEnvironmentVariable('Path',(($entries+$goBin)-join ';'),'User') }

Set-UserEnv 'GRADLE_USER_HOME' (Join-Path $DevCacheRoot 'gradle')
$m2 = Join-Path $env:USERPROFILE '.m2'
New-Item -ItemType Directory -Path $m2 -Force | Out-Null
$repoPath = (Join-Path $DevCacheRoot 'maven').Replace('\','/')
@"
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository>$repoPath</localRepository>
</settings>
"@ | Set-Content -LiteralPath (Join-Path $m2 'settings.xml') -Encoding utf8

Set-UserEnv 'NUGET_PACKAGES' (Join-Path $DevCacheRoot 'nuget')
Set-UserEnv 'COMPOSER_HOME' (Join-Path $DevCacheRoot 'composer')
Set-UserEnv 'COMPOSER_CACHE_DIR' (Join-Path $DevCacheRoot 'composer\cache')
Set-UserEnv 'VCPKG_DEFAULT_BINARY_CACHE' (Join-Path $DevCacheRoot 'vcpkg')
Set-UserEnv 'CCACHE_DIR' (Join-Path $DevCacheRoot 'ccache')

Write-Host "`n[DEVCACHE] Cache configuration complete." -ForegroundColor Green
Write-Host '  TEMP/TMP were intentionally left unchanged.' -ForegroundColor Gray
Write-Host '  Docker Desktop daemon.json was intentionally left unchanged.' -ForegroundColor Gray
Write-Host '  Open a new terminal for persistent environment variables.' -ForegroundColor Yellow
