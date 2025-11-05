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

Write-Host "`n🐧 WSL Foundation"
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

Write-Host "`n📦 Core"
winget install 7zip.7zip JanDeDobbeleer.OhMyPosh --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n📝 Editor & Containers"
winget install Microsoft.VisualStudioCode Docker.DockerDesktop `
  --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n🐧 Ubuntu for WSL"
winget install Canonical.Ubuntu --silent --accept-package-agreements --accept-source-agreements
# Set Ubuntu as WSL 2 explicitly
wsl --set-version Ubuntu 2

Write-Host "`n🐙 Git toolchain"
winget install Git.Git Git.GitLFS GitHub.cli Microsoft.GitCredentialManagerCore `
  --silent --accept-package-agreements --accept-source-agreements
try { Install-Module posh-git -Scope AllUsers -Force -Confirm:$false } catch {}

Write-Host "`n🔐 1Password"
winget install AgileBits.1Password 1Password.CLI `
  --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n🔤 Developer Fonts"
winget install Microsoft.CascadiaCode NerdFonts.JetBrainsMono `
  --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n🧠 Productivity"
winget install Axosoft.GitKraken ScooterSoftware.BeyondCompare4 LiteratureAndLatte.Scrivener3 Obsidian.Obsidian `
  --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n📄 Microsoft 365 (Office)"
$officeInstalled = (winget list | Select-String -SimpleMatch "Microsoft 365") -or (winget list | Select-String -SimpleMatch "Microsoft Office")
if (-not $officeInstalled) {
  foreach ($id in @("Microsoft.Office","Microsoft.Office.Desktop")) {
    try { winget install $id --silent --accept-source-agreements --accept-package-agreements; break } catch {}
  }
}

Write-Host "`n🌐 Runtimes (latest channels)"
# Python latest (3.13 line)
winget install Python.Python.3.13 --silent --accept-package-agreements --accept-source-agreements
# Node current (not LTS)
winget install OpenJS.NodeJS -e --silent --accept-package-agreements --accept-source-agreements
# Go + Rust + .NET (latest SDK channels)
winget install GoLang.Go Rustlang.Rustup Microsoft.DotNet.SDK.9 `
  --silent --accept-package-agreements --accept-source-agreements
# Java: rolling Temurin (latest GA, auto-upgrades to next GA)
winget install EclipseAdoptium.Temurin.JDK `
  --silent --accept-package-agreements --accept-source-agreements
# Build tools
winget install Apache.Maven Gradle.Gradle Kitware.CMake GnuWin32.Make `
  --silent --accept-package-agreements --accept-source-agreements

Write-Host "`n☁️ Cloud & IaC"
winget install HashiCorp.Terraform HashiCorp.Packer Amazon.AWSCLI Microsoft.AzureCLI Google.CloudSDK `
  --silent --accept-package-agreements --accept-source-agreements

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

Write-Host "`n⚙️ mise (universal toolchain manager)"
winget install jdx.mise --silent --accept-package-agreements --accept-source-agreements
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
if (-not (Get-Content $PROFILE | Select-String -SimpleMatch 'mise activate powershell')) {
  Add-Content $PROFILE 'if (Get-Command mise -ErrorAction SilentlyContinue) { eval "$(mise activate powershell)" }'
}
# Keep Kotlin/Gradle latest via mise
try { mise use -g kotlin@latest; mise use -g gradle@latest } catch {}

Write-Host "`n🧩 VS Code extensions (abbrev)"
foreach ($e in @(
  "EditorConfig.EditorConfig","streetsidesoftware.code-spell-checker","streetsidesoftware.code-spell-checker-australian-english",
  "eamodio.gitlens","ms-azuretools.vscode-docker","ms-vscode-remote.remote-wsl",
  "ms-python.python","ms-python.vscode-pylance","rust-lang.rust-analyzer","golang.Go",
  "ms-dotnettools.csharp","vscjava.vscode-java-pack","dbaeumer.vscode-eslint","esbenp.prettier-vscode",
  "redhat.vscode-yaml","ms-vscode.powershell","yzhang.markdown-all-in-one","HashiCorp.terraform"
)) { try { code --install-extension $e --force | Out-Null } catch {} }

Write-Host "`n✅ Windows bootstrap complete."
