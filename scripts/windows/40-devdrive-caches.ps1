<#
Move build/tool caches to a Dev Drive to save C: space and improve performance.
Default: C:\DevCache (mounted Dev Drive partition)
Alternative: Specify custom path like D:\dev\caches if using external drive
Run in pwsh (non-Admin is fine).

NOTE: Run 41-devdrive-partition-setup.ps1 first to create the C:\DevCache partition.
#>

param([string]$DevCacheRoot = "C:\DevCache")

$ErrorActionPreference = 'Stop'

Write-Host "[DEVCACHE] Configuring development tool caches on Dev Drive..." -ForegroundColor Cyan
Write-Host "  Target location: $DevCacheRoot" -ForegroundColor Gray

# Ensure Dev Drive exists
if (-not (Test-Path $DevCacheRoot)) {
    Write-Host "  ❌ Dev Drive not found at $DevCacheRoot" -ForegroundColor Red
    Write-Host "     Run 41-devdrive-partition-setup.ps1 first to create the Dev Drive" -ForegroundColor Yellow
    exit 1
}

# Create cache subdirectories
Write-Host "`n📦 Creating cache directories..." -ForegroundColor Cyan
$cacheDirs = @(
    'npm', 'pnpm', 'yarn', 'bun',                    # Node package managers
    'pip', 'pipx', 'poetry', 'uv',                   # Python package managers
    'cargo', 'rustup',                               # Rust
    'go',                                            # Go
    'gradle', 'maven',                               # Java build tools
    'nuget',                                         # .NET
    'composer',                                      # PHP
    'vcpkg',                                         # C++ package manager
    'docker',                                        # Docker
    'temp', 'ccache'                                 # Build caches
)

foreach($sub in $cacheDirs){
  $path = Join-Path $DevCacheRoot $sub
  New-Item -Force -ItemType Directory -Path $path | Out-Null
  Write-Host "  ✅ $sub" -ForegroundColor Green
}

# Node
Write-Host "`n📦 Node.js package managers..." -ForegroundColor Cyan
npm config set cache "$DevCacheRoot\npm" --location=global 2>$null
Write-Host "  ✅ npm cache → $DevCacheRoot\npm" -ForegroundColor Green

if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    pnpm config set store-dir "$DevCacheRoot\pnpm" 2>$null
    Write-Host "  ✅ pnpm store → $DevCacheRoot\pnpm" -ForegroundColor Green
}

[Environment]::SetEnvironmentVariable("YARN_CACHE_FOLDER","$DevCacheRoot\yarn","User")
Write-Host "  ✅ yarn cache → $DevCacheRoot\yarn" -ForegroundColor Green

if (Get-Command bun -ErrorAction SilentlyContinue) {
    [Environment]::SetEnvironmentVariable("BUN_INSTALL_CACHE_DIR","$DevCacheRoot\bun","User")
    Write-Host "  ✅ bun cache → $DevCacheRoot\bun" -ForegroundColor Green
}

# Python
Write-Host "`n🐍 Python package managers..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("PIP_CACHE_DIR","$DevCacheRoot\pip","User")
Write-Host "  ✅ pip cache → $DevCacheRoot\pip" -ForegroundColor Green

[Environment]::SetEnvironmentVariable("PIPX_HOME","$DevCacheRoot\pipx","User")
[Environment]::SetEnvironmentVariable("PIPX_BIN_DIR","$DevCacheRoot\pipx\bin","User")
Write-Host "  ✅ pipx home → $DevCacheRoot\pipx" -ForegroundColor Green

[Environment]::SetEnvironmentVariable("POETRY_CACHE_DIR","$DevCacheRoot\poetry","User")
Write-Host "  ✅ poetry cache → $DevCacheRoot\poetry" -ForegroundColor Green

if (Get-Command uv -ErrorAction SilentlyContinue) {
    [Environment]::SetEnvironmentVariable("UV_CACHE_DIR","$DevCacheRoot\uv","User")
    Write-Host "  ✅ uv cache → $DevCacheRoot\uv" -ForegroundColor Green
}

# Rust
Write-Host "`n🦀 Rust..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("CARGO_HOME","$DevCacheRoot\cargo","User")
[Environment]::SetEnvironmentVariable("RUSTUP_HOME","$DevCacheRoot\rustup","User")
Write-Host "  ✅ cargo home → $DevCacheRoot\cargo" -ForegroundColor Green
Write-Host "  ✅ rustup home → $DevCacheRoot\rustup" -ForegroundColor Green

# Go
Write-Host "`n🐹 Go..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("GOPATH","$DevCacheRoot\go","User")
[Environment]::SetEnvironmentVariable("GOMODCACHE","$DevCacheRoot\go\pkg\mod","User")
Write-Host "  ✅ GOPATH → $DevCacheRoot\go" -ForegroundColor Green
Write-Host "  ✅ GOMODCACHE → $DevCacheRoot\go\pkg\mod" -ForegroundColor Green

$up = [Environment]::GetEnvironmentVariable("Path","User")
if ($up -notlike "*$DevCacheRoot\go\bin*"){
    [Environment]::SetEnvironmentVariable("Path", ($up + ";$DevCacheRoot\go\bin"), "User")
    Write-Host "  ✅ Added Go bin to PATH" -ForegroundColor Green
}

# Gradle/Maven
Write-Host "`n☕ Java build tools..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("GRADLE_USER_HOME","$DevCacheRoot\gradle","User")
Write-Host "  ✅ Gradle home → $DevCacheRoot\gradle" -ForegroundColor Green

$mvndir = "$HOME\.m2"
New-Item -Force -ItemType Directory -Path $mvndir | Out-Null
$settings = @"
<settings xmlns='http://maven.apache.org/SETTINGS/1.0.0'
          xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'
          xsi:schemaLocation='http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd'>
  <localRepository>$DevCacheRoot\maven</localRepository>
</settings>
"@
$settings | Out-File -Encoding utf8 "$mvndir\settings.xml"
Write-Host "  ✅ Maven local repo → $DevCacheRoot\maven" -ForegroundColor Green

# .NET NuGet
Write-Host "`n💎 .NET NuGet..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("NUGET_PACKAGES","$DevCacheRoot\nuget","User")
Write-Host "  ✅ NuGet packages → $DevCacheRoot\nuget" -ForegroundColor Green

# Composer
Write-Host "`n🎼 PHP Composer..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("COMPOSER_HOME","$DevCacheRoot\composer","User")
[Environment]::SetEnvironmentVariable("COMPOSER_CACHE_DIR","$DevCacheRoot\composer\cache","User")
Write-Host "  ✅ Composer home → $DevCacheRoot\composer" -ForegroundColor Green

# vcpkg (C++ package manager)
Write-Host "`n📦 C++ vcpkg..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("VCPKG_DEFAULT_BINARY_CACHE","$DevCacheRoot\vcpkg","User")
Write-Host "  ✅ vcpkg cache → $DevCacheRoot\vcpkg" -ForegroundColor Green

# Build cache tools
Write-Host "`n🔨 Build caches..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("CCACHE_DIR","$DevCacheRoot\ccache","User")
Write-Host "  ✅ ccache → $DevCacheRoot\ccache" -ForegroundColor Green

[Environment]::SetEnvironmentVariable("TEMP","$DevCacheRoot\temp","User")
[Environment]::SetEnvironmentVariable("TMP","$DevCacheRoot\temp","User")
Write-Host "  ✅ TEMP/TMP → $DevCacheRoot\temp" -ForegroundColor Green

Write-Host "`n🐳 Docker data-root..." -ForegroundColor Cyan
$dockerConfigDir = "$env:ProgramData\Docker\config"
$dockerConfig = Join-Path $dockerConfigDir "daemon.json"
$dockerData = Join-Path $DevCacheRoot "docker"
New-Item -Force -ItemType Directory -Path $dockerData | Out-Null
New-Item -Force -ItemType Directory -Path $dockerConfigDir | Out-Null

# Create or update daemon.json
$daemonSettings = @{
  "data-root" = $dockerData
  "storage-driver" = "windowsfilter"
  "dns" = @("8.8.8.8", "1.1.1.1")
}

if (Test-Path $dockerConfig) {
  try {
    $existing = Get-Content $dockerConfig -Raw | ConvertFrom-Json
    $existing.'data-root' = $dockerData
    $existing | ConvertTo-Json -Depth 10 | Set-Content $dockerConfig -Encoding utf8
    Write-Host "  ✅ Updated Docker data-root → $dockerData" -ForegroundColor Green
  } catch {
    $daemonSettings | ConvertTo-Json -Depth 10 | Set-Content $dockerConfig -Encoding utf8
    Write-Host "  ✅ Created Docker config → $dockerData" -ForegroundColor Green
  }
} else {
  $daemonSettings | ConvertTo-Json -Depth 10 | Set-Content $dockerConfig -Encoding utf8
  Write-Host "  ✅ Created Docker config → $dockerData" -ForegroundColor Green
}

Write-Host "  ⚠️  Restart Docker Desktop to apply changes" -ForegroundColor Yellow

Write-Host "`n[OK] Dev Drive cache configuration complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ All caches configured to use: $DevCacheRoot" -ForegroundColor Green
Write-Host "✅ Benefits: Faster builds, less C: drive usage, better performance" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "`n💡 IMPORTANT: Open a NEW terminal to pick up environment changes!" -ForegroundColor Yellow
Write-Host "   Or run: refreshenv (requires chocolatey)" -ForegroundColor Gray
