<#
.SYNOPSIS
    Configure development package caches on the DevMachine Dev Drive.

.DESCRIPTION
    Uses C:\DevCache by default. The script is idempotent and only changes cache
    locations that have an explicit package-manager environment/configuration setting.

    It deliberately does NOT move TEMP/TMP or overwrite Docker Desktop daemon.json.
    Microsoft documents additional filter requirements and side effects for TEMP/TMP
    on a Dev Drive, and Docker Desktop manages its own data-root configuration.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$DevCacheRoot = 'C:\DevCache'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $DevCacheRoot)) {
    throw "Dev Drive not found at $DevCacheRoot. Run 41-devdrive-partition-setup.ps1 first."
}

$volume = Get-Volume -Path $DevCacheRoot -ErrorAction Stop
if ($volume.FileSystem -ne 'ReFS') {
    throw "$DevCacheRoot is not ReFS. Refusing to configure development caches on a non-Dev Drive."
}

$fsutil = Join-Path $env:SystemRoot 'System32\fsutil.exe'
if (-not (Test-Path -LiteralPath $fsutil)) { throw "fsutil.exe not found at $fsutil" }
$devStatus = & $fsutil devdrv query $DevCacheRoot 2>&1
if ($LASTEXITCODE -ne 0 -or (($devStatus | Out-String) -notmatch '(?i)developer volume')) {
    throw "$DevCacheRoot is not recognised as a Windows Dev Drive."
}

Write-Host "[DEVCACHE] Configuring development caches on $DevCacheRoot" -ForegroundColor Cyan

$cacheDirs = @(
    'npm','pnpm','yarn','bun',
    'pip','pipx','poetry','uv',
    'cargo','rustup',
    'go',
    'gradle','maven',
    'nuget',
    'composer',
    'vcpkg',
    'ccache'
)

foreach ($name in $cacheDirs) {
    New-Item -ItemType Directory -Path (Join-Path $DevCacheRoot $name) -Force | Out-Null
}

function Set-UserEnvironmentPath {
    param([Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][string]$Value)
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Set-Item -Path "Env:$Name" -Value $Value
    Write-Host "  ✅ $Name → $Value" -ForegroundColor Green
}

# Node
if (Get-Command npm -ErrorAction SilentlyContinue) {
    & npm config set cache (Join-Path $DevCacheRoot 'npm') --location=global
    if ($LASTEXITCODE -ne 0) { throw 'npm cache configuration failed.' }
    Write-Host "  ✅ npm cache → $(Join-Path $DevCacheRoot 'npm')" -ForegroundColor Green
}
if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    & pnpm config set store-dir (Join-Path $DevCacheRoot 'pnpm')
    if ($LASTEXITCODE -ne 0) { throw 'pnpm store configuration failed.' }
    Write-Host "  ✅ pnpm store → $(Join-Path $DevCacheRoot 'pnpm')" -ForegroundColor Green
}
Set-UserEnvironmentPath 'YARN_CACHE_FOLDER' (Join-Path $DevCacheRoot 'yarn')
if (Get-Command bun -ErrorAction SilentlyContinue) {
    Set-UserEnvironmentPath 'BUN_INSTALL_CACHE_DIR' (Join-Path $DevCacheRoot 'bun')
}

# Python
Set-UserEnvironmentPath 'PIP_CACHE_DIR' (Join-Path $DevCacheRoot 'pip')
Set-UserEnvironmentPath 'PIPX_HOME' (Join-Path $DevCacheRoot 'pipx')
Set-UserEnvironmentPath 'PIPX_BIN_DIR' (Join-Path $DevCacheRoot 'pipx\bin')
New-Item -ItemType Directory -Path (Join-Path $DevCacheRoot 'pipx\bin') -Force | Out-Null
Set-UserEnvironmentPath 'POETRY_CACHE_DIR' (Join-Path $DevCacheRoot 'poetry')
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Set-UserEnvironmentPath 'UV_CACHE_DIR' (Join-Path $DevCacheRoot 'uv')
}

# Rust
Set-UserEnvironmentPath 'CARGO_HOME' (Join-Path $DevCacheRoot 'cargo')
Set-UserEnvironmentPath 'RUSTUP_HOME' (Join-Path $DevCacheRoot 'rustup')

# Go
Set-UserEnvironmentPath 'GOPATH' (Join-Path $DevCacheRoot 'go')
Set-UserEnvironmentPath 'GOMODCACHE' (Join-Path $DevCacheRoot 'go\pkg\mod')
New-Item -ItemType Directory -Path (Join-Path $DevCacheRoot 'go\pkg\mod') -Force | Out-Null
$goBin = Join-Path $DevCacheRoot 'go\bin'
New-Item -ItemType Directory -Path $goBin -Force | Out-Null
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
$entries = @($userPath -split ';' | Where-Object { $_ })
if ($entries -notcontains $goBin) {
    [Environment]::SetEnvironmentVariable('Path', (($entries + $goBin) -join ';'), 'User')
}

# Java
Set-UserEnvironmentPath 'GRADLE_USER_HOME' (Join-Path $DevCacheRoot 'gradle')
$m2 = Join-Path $env:USERPROFILE '.m2'
New-Item -ItemType Directory -Path $m2 -Force | Out-Null
$settings = Join-Path $m2 'settings.xml'
$repoPath = (Join-Path $DevCacheRoot 'maven').Replace('\','/')
@"
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository>$repoPath</localRepository>
</settings>
"@ | Set-Content -LiteralPath $settings -Encoding utf8
Write-Host "  ✅ Maven local repository → $(Join-Path $DevCacheRoot 'maven')" -ForegroundColor Green

# .NET / PHP / C++
Set-UserEnvironmentPath 'NUGET_PACKAGES' (Join-Path $DevCacheRoot 'nuget')
Set-UserEnvironmentPath 'COMPOSER_HOME' (Join-Path $DevCacheRoot 'composer')
Set-UserEnvironmentPath 'COMPOSER_CACHE_DIR' (Join-Path $DevCacheRoot 'composer\cache')
Set-UserEnvironmentPath 'VCPKG_DEFAULT_BINARY_CACHE' (Join-Path $DevCacheRoot 'vcpkg')
Set-UserEnvironmentPath 'CCACHE_DIR' (Join-Path $DevCacheRoot 'ccache')

Write-Host "`n[DEVCACHE] Cache configuration complete." -ForegroundColor Green
Write-Host "  TEMP/TMP were intentionally left unchanged." -ForegroundColor Gray
Write-Host "  Docker Desktop daemon.json was intentionally left unchanged." -ForegroundColor Gray
Write-Host "  Open a new terminal for persistent environment variables." -ForegroundColor Yellow
