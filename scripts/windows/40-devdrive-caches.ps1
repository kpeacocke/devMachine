<#
Move build/tool caches to a Dev Drive to save C: space and improve performance.
Default: D:\dev\caches
Run in pwsh (non-Admin is fine).
#>

param([string]$DevCacheRoot = "D:\dev\caches")

$ErrorActionPreference = 'Stop'
New-Item -Force -ItemType Directory -Path $DevCacheRoot | Out-Null

foreach($sub in 'npm','pnpm','yarn','pipx','poetry','cargo','go','gradle','maven','composer'){
  New-Item -Force -ItemType Directory -Path (Join-Path $DevCacheRoot $sub) | Out-Null
}

# Node
npm config set cache "$DevCacheRoot\npm" --location=global 2>$null
pnpm config set store-dir "$DevCacheRoot\pnpm" 2>$null
[Environment]::SetEnvironmentVariable("YARN_CACHE_FOLDER","$DevCacheRoot\yarn","User")

# Python
[Environment]::SetEnvironmentVariable("PIPX_HOME","$DevCacheRoot\pipx","User")
[Environment]::SetEnvironmentVariable("PIPX_BIN_DIR","$DevCacheRoot\pipx\bin","User")
[Environment]::SetEnvironmentVariable("POETRY_CACHE_DIR","$DevCacheRoot\poetry","User")

# Rust
[Environment]::SetEnvironmentVariable("CARGO_HOME","$DevCacheRoot\cargo","User")
[Environment]::SetEnvironmentVariable("RUSTUP_HOME","$DevCacheRoot\cargo\rustup","User")

# Go
[Environment]::SetEnvironmentVariable("GOPATH","$DevCacheRoot\go","User")
$up = [Environment]::GetEnvironmentVariable("Path","User")
if ($up -notlike "*$DevCacheRoot\go\bin*"){ [Environment]::SetEnvironmentVariable("Path", ($up + ";$DevCacheRoot\go\bin"), "User") }

# Gradle/Maven
[Environment]::SetEnvironmentVariable("GRADLE_USER_HOME","$DevCacheRoot\gradle","User")
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

# Composer
[Environment]::SetEnvironmentVariable("COMPOSER_HOME","$DevCacheRoot\composer","User")
[Environment]::SetEnvironmentVariable("COMPOSER_CACHE_DIR","$DevCacheRoot\composer\cache","User")

Write-Host "✅ Cache locations set to $DevCacheRoot. Open a NEW terminal to pick up PATH and env vars."
