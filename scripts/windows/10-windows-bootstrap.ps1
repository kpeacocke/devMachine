<#
Run AFTER 00-pwsh-first.ps1, in pwsh (Admin).
Installs (latest channels where possible): VS Code, Docker Desktop, WSL Ubuntu, Git+LFS+GH+GCM,
1Password (GUI+CLI), Obsidian, GitKraken, Beyond Compare, Scrivener, fonts,
Python 3.13, Node CURRENT, Go, Rustup, .NET 9 SDK, Java Temurin (rolling GA), Maven, Gradle,
Terraform, Packer, AWS/Azure/GCloud CLIs, mise (Kotlin+Gradle latest), VS Code extensions.
#>
$ErrorActionPreference = 'Stop'
function Test-CommandExists {
    param([string]$n)
    $null -ne (Get-Command $n -ErrorAction SilentlyContinue)
}

Write-Host "🐧 WSL Foundation"
# Install WSL with no distribution first, then explicitly install Ubuntu
try {
  wsl --install --no-distribution
} catch {
  # Fallback: enable features manually
  dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
  dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
}
# Ensure WSL 2 is the default
wsl --set-default-version 2

Write-Host "📦 Core"
winget install 7zip.7zip --source winget --silent --accept-package-agreements --accept-source-agreements
winget install JanDeDobbeleer.OhMyPosh --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🔧 Build Tools & Compilers (FIRST - needed by other tools)"
# Visual Studio Build Tools for native C/C++ compilation (needed by Rust, Python native modules, etc.)
Write-Host "  Installing Visual Studio Build Tools (C++ workload)..."
Write-Host "  This may take 5-10 minutes..." -ForegroundColor Yellow
winget install Microsoft.VisualStudio.2022.BuildTools --source winget --silent --accept-package-agreements --accept-source-agreements --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
Write-Host "  Build Tools installed - refreshing environment..." -ForegroundColor Green

Write-Host "📝 Editor & Containers"
winget install Microsoft.VisualStudioCode --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Docker.DockerDesktop --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🐧 Ubuntu for WSL"
winget install Canonical.Ubuntu --source winget --silent --accept-package-agreements --accept-source-agreements
# Set Ubuntu as WSL 2 explicitly
wsl --set-version Ubuntu 2

Write-Host "🐙 Git toolchain"
winget install Git.Git --source winget --silent --accept-package-agreements --accept-source-agreements
winget install GitHub.GitLFS --source winget --silent --accept-package-agreements --accept-source-agreements
winget install GitHub.cli --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Git.GCM --source winget --silent --accept-package-agreements --accept-source-agreements
try { Install-Module posh-git -Scope AllUsers -Force -Confirm:$false } catch {}

Write-Host "🔤 Developer Fonts"
winget install DEVCOM.JetBrainsMonoNerdFont --source winget `
  --silent --accept-package-agreements --accept-source-agreements
# Note: Cascadia Code comes with Windows Terminal

Write-Host "💡 Note: Licensed apps (1Password, Office, GitKraken, etc.) moved to 11-licensed-apps.ps1"
Write-Host "   Run .\scripts\windows\11-licensed-apps.ps1 separately if needed" -ForegroundColor Yellow

Write-Host "🌐 Runtimes (latest channels)"
# Python latest (3.13 line)
winget install Python.Python.3.13 --source winget --silent --accept-package-agreements --accept-source-agreements
# Node current (not LTS)
winget install OpenJS.NodeJS --source winget -e --silent --accept-package-agreements --accept-source-agreements
# Go + Rust + .NET (latest SDK channels)
winget install GoLang.Go --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Rustlang.Rustup --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Microsoft.DotNet.SDK.9 --source winget --silent --accept-package-agreements --accept-source-agreements
# Java: rolling Temurin (latest GA, auto-upgrades to next GA)
winget install EclipseAdoptium.Temurin.JDK --source winget `
  --silent --accept-package-agreements --accept-source-agreements
# Build tools
winget install Apache.Maven --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Gradle.Gradle --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Kitware.CMake --source winget --silent --accept-package-agreements --accept-source-agreements
winget install GnuWin32.Make --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "☁️ Cloud & IaC"
winget install HashiCorp.Terraform --source winget --silent --accept-package-agreements --accept-source-agreements
winget install HashiCorp.Packer --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Amazon.AWSCLI --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Microsoft.AzureCLI --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Google.CloudSDK --source winget --silent --accept-package-agreements --accept-source-agreements

# TFLint (winget + fallback)
function Install-TFLint {
  if (Test-CommandExists "tflint") { return }
  try { winget install Terraform-Linters.tflint --silent --accept-source-agreements --accept-package-agreements; if (Test-CommandExists "tflint"){return} } catch {}
  try {
    $rel = Invoke-RestMethod https://api.github.com/repos/terraform-linters/tflint/releases/latest
    $asset = $rel.assets | Where-Object { $_.name -match 'windows_amd64.zip' } | Select-Object -First 1
    if ($asset) {
      $zip = Join-Path $env:TEMP $asset.name
      Invoke-WebRequest $asset.browser_download_url -OutFile $zip
      $dest = "$env:ProgramFiles\TFLint"; New-Item -ItemType Directory -Path $dest -Force | Out-Null
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest, $true)
      $p=[Environment]::GetEnvironmentVariable('Path','Machine'); if ($p -notlike "*$dest*"){[Environment]::SetEnvironmentVariable('Path',$p+';'+$dest,'Machine')}
    }
  } catch { Write-Warning "TFLint fallback failed: $_" }
}
Install-TFLint

Write-Host "[SETUP] mise (universal toolchain manager)"
winget install jdx.mise --silent --accept-package-agreements --accept-source-agreements
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
if (-not (Get-Content $PROFILE | Select-String -SimpleMatch 'mise activate powershell')) {
  Add-Content $PROFILE 'if (Get-Command mise -ErrorAction SilentlyContinue) { eval "$(mise activate powershell)" }'
}
# Keep Kotlin/Gradle latest via mise
try { mise use -g kotlin@latest; mise use -g gradle@latest } catch {}

Write-Host "🧩 VS Code extensions (abbrev)"
foreach ($e in @(
  "EditorConfig.EditorConfig","streetsidesoftware.code-spell-checker","streetsidesoftware.code-spell-checker-australian-english",
  "eamodio.gitlens","ms-azuretools.vscode-docker","ms-vscode-remote.remote-wsl",
  "ms-python.python","ms-python.vscode-pylance","rust-lang.rust-analyzer","golang.Go",
  "ms-dotnettools.csharp","vscjava.vscode-java-pack","dbaeumer.vscode-eslint","esbenp.prettier-vscode",
  "redhat.vscode-yaml","ms-vscode.powershell","yzhang.markdown-all-in-one","HashiCorp.terraform"
)) { try { code --install-extension $e --force | Out-Null } catch {} }

Write-Host "✅ Windows bootstrap complete."
