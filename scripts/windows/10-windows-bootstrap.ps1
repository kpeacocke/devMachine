<#
Run AFTER 00-pwsh-first.ps1, in pwsh (Admin).
Installs (latest channels where possible): VS Code, Docker Desktop, WSL Ubuntu, Git+LFS+GH+GCM,
fonts, Python 3.13 (with pipx), Node CURRENT, Go, Rustup, .NET 9 SDK, Java Temurin 25,
Terraform, Packer, Vagrant, AWS/Azure/GCloud CLIs,
mise (Kotlin, Gradle, Maven, ripgrep), VS Code extensions.
#>
$ErrorActionPreference = 'Stop'
function Test-CommandExists {
    param([string]$n)
    $null -ne (Get-Command $n -ErrorAction SilentlyContinue)
}

Write-Host "🐧 WSL Foundation"
# Check if running in a VM (nested virtualization often unsupported)
try {
  $vmInfo = Get-WmiObject -Class Win32_ComputerSystem
  if ($vmInfo.Model -match "Virtual|VMware|Parallels|VirtualBox|QEMU|Hyper-V") {
    Write-Host "  ⚠️  VM detected ($($vmInfo.Model)) - WSL may not work with nested virtualization" -ForegroundColor Yellow
    if ($env:UNATTENDED_MODE -or $env:INSTALL_WSL_IN_VM -eq 'Y') {
      if ($env:INSTALL_WSL_IN_VM -eq 'Y') {
        Write-Host "  → Installing WSL in VM (INSTALL_WSL_IN_VM=Y)" -ForegroundColor Green
      } else {
        Write-Host "  → Skipping WSL installation in unattended mode" -ForegroundColor Yellow
        $skipWSL = $true
      }
    } else {
      $installWSL = Read-Host "  Install WSL anyway? (Y/N) [Default: N]"
      if ([string]::IsNullOrWhiteSpace($installWSL)) { $installWSL = 'N' }
      if ($installWSL -ne 'Y') {
        Write-Host "  → Skipping WSL installation" -ForegroundColor Yellow
        $skipWSL = $true
      }
    }
  }
} catch { }

if (-not $skipWSL) {
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
}

Write-Host "📦 Core"
winget install 7zip.7zip --source winget --silent --accept-package-agreements --accept-source-agreements
winget install JanDeDobbeleer.OhMyPosh --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🔧 Build Tools & Compilers (FIRST - needed by other tools)"
# Visual Studio Build Tools for native C/C++ compilation (needed by Rust, Python native modules, etc.)
Write-Host "  Installing Visual Studio Build Tools (C++ workload)..."
Write-Host "  This may take 5-10 minutes..." -ForegroundColor Yellow
winget install Microsoft.VisualStudio.2022.BuildTools --source winget --silent --accept-package-agreements --accept-source-agreements --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
Write-Host "  Build Tools installed - refreshing environment..." -ForegroundColor Green

# Windows Assessment and Deployment Kit (ADK) - includes oscdimg.exe for creating ISO images
Write-Host "  Installing Windows ADK (Assessment and Deployment Kit)..."
Write-Host "  Provides oscdimg.exe, Windows imaging tools, and deployment utilities..." -ForegroundColor Yellow
winget install Microsoft.WindowsADK --source winget --silent --accept-package-agreements --accept-source-agreements

# Add ADK tools to PATH
Write-Host "  Adding ADK tools to PATH..." -ForegroundColor Cyan
$adkPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg",
    "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment",
    "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Imaging and Configuration Designer\x86"
)

# Try to add to Machine PATH first (requires admin), fallback to User PATH
$currentMachinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$currentUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')

foreach ($adkPath in $adkPaths) {
    if (Test-Path $adkPath) {
        $pathAdded = $false

        # Try Machine PATH first (system-wide)
        if ($currentMachinePath -notlike "*$adkPath*") {
            try {
                [Environment]::SetEnvironmentVariable('Path', $currentMachinePath + ";$adkPath", 'Machine')
                Write-Host "    Added to system PATH: $adkPath" -ForegroundColor Green
                $currentMachinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
                $pathAdded = $true
            } catch {
                # Machine PATH failed, try User PATH
            }
        }

        # Fallback to User PATH if Machine PATH failed or isn't admin
        if (-not $pathAdded -and $currentUserPath -notlike "*$adkPath*") {
            try {
                [Environment]::SetEnvironmentVariable('Path', $currentUserPath + ";$adkPath", 'User')
                Write-Host "    Added to user PATH: $adkPath" -ForegroundColor Yellow
                $currentUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
                $pathAdded = $true
            } catch {
                Write-Warning "Could not add $adkPath to PATH"
            }
        }

        if ($pathAdded) {
            Write-Host "      oscdimg.exe will be available after restart" -ForegroundColor Gray
        }
    }
}

Write-Host "📝 Editor & Containers"
# Ensure only VS Code Insiders is installed (uninstall regular VS Code if present)
Write-Host "  Checking for VS Code editions..."
$regularVSCode = winget list --id Microsoft.VisualStudioCode --exact 2>$null
if ($regularVSCode -match "Microsoft.VisualStudioCode") {
    Write-Host "  Removing regular VS Code..." -ForegroundColor Yellow
    winget uninstall Microsoft.VisualStudioCode --silent --accept-source-agreements
    Write-Host "  ✅ Regular VS Code removed" -ForegroundColor Green
}
Write-Host "  Installing VS Code Insiders..."
winget install Microsoft.VisualStudioCode.Insiders --source winget --silent --accept-package-agreements --accept-source-agreements
Write-Host "  ✅ VS Code Insiders installed" -ForegroundColor Green

winget install Docker.DockerDesktop --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🐧 Ubuntu for WSL"
if (-not $skipWSL) {
  # Install Ubuntu 24.04 LTS (latest)
  winget install Canonical.Ubuntu.2404 --source winget --silent --accept-package-agreements --accept-source-agreements
  # Set WSL 2 as default
  wsl --set-default-version 2
  Write-Host "  Note: Launch 'Ubuntu 24.04 LTS' from Start Menu to complete first-time setup" -ForegroundColor Yellow
} else {
  Write-Host "  → Skipped (WSL not installed)" -ForegroundColor Yellow
}

Write-Host "🐙 Git toolchain"
winget install Git.Git --source winget --silent --accept-package-agreements --accept-source-agreements
winget install GitHub.GitLFS --source winget --silent --accept-package-agreements --accept-source-agreements
winget install GitHub.cli --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Git.GCM --source winget --silent --accept-package-agreements --accept-source-agreements
try { Install-Module posh-git -Scope AllUsers -Force -Confirm:$false } catch {}

Write-Host "🧪 Testing Framework"
# Install Pester 5 for running tests (replaces old Windows-bundled Pester 3)
try {
  $pesterVersion = (Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1).Version
  if ($pesterVersion -lt [Version]"5.0") {
    Write-Host "  Installing Pester 5+ (replacing bundled Pester 3)..."
    Install-Module -Name Pester -Force -Scope AllUsers -SkipPublisherCheck -MinimumVersion 5.0 -AllowClobber
  } else {
    Write-Host "  Pester $pesterVersion already installed"
  }
} catch {
  Write-Host "  Installing Pester 5+..."
  Install-Module -Name Pester -Force -Scope AllUsers -SkipPublisherCheck -MinimumVersion 5.0 -AllowClobber
}

Write-Host "🔤 Developer Fonts"
winget install DEVCOM.JetBrainsMonoNerdFont --source winget `
  --silent --accept-package-agreements --accept-source-agreements
# Note: Cascadia Code comes with Windows Terminal

Write-Host "💡 Note: Licensed apps (1Password, Office, GitKraken, etc.) moved to 11-licensed-apps.ps1"
Write-Host "   Run .\scripts\windows\11-licensed-apps.ps1 separately if needed" -ForegroundColor Yellow

Write-Host "🌐 Runtimes (latest channels)"
# Python latest (3.13 line)
winget install Python.Python.3.13 --source winget --silent --accept-package-agreements --accept-source-agreements

# Upgrade pip to latest version
Write-Host "  Upgrading pip to latest version..."
try {
  python -m pip install --upgrade pip
  Write-Host "  [OK] pip upgraded" -ForegroundColor Green
} catch {
  Write-Warning "pip upgrade failed - will retry after environment refresh"
}

# Install pipx for isolated Python tool management
Write-Host "  Installing pipx for Python CLI tools..."
try {
  python -m pip install --user --upgrade pipx
  python -m pipx ensurepath
  Write-Host "  [OK] pipx installed" -ForegroundColor Green
} catch {
  Write-Warning "pipx installation failed - will retry after environment refresh"
}

# Node current (not LTS)
winget install OpenJS.NodeJS --source winget -e --silent --accept-package-agreements --accept-source-agreements
# Go + Rust + .NET (latest SDK channels)
winget install GoLang.Go --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Rustlang.Rustup --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Microsoft.DotNet.SDK.9 --source winget --silent --accept-package-agreements --accept-source-agreements
# Java: Temurin 25 (latest GA)
winget install EclipseAdoptium.Temurin.25.JDK --source winget `
  --silent --accept-package-agreements --accept-source-agreements
# Build tools (CMake via winget, Maven/Gradle via mise below)
winget install Kitware.CMake --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "☁️ Cloud & IaC"
winget install HashiCorp.Terraform --source winget --silent --accept-package-agreements --accept-source-agreements
winget install HashiCorp.Packer --source winget --silent --accept-package-agreements --accept-source-agreements
winget install HashiCorp.Vagrant --source winget --silent --accept-package-agreements --accept-source-agreements
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

Write-Host "🔧 mise (universal toolchain manager)"
Write-Host "  Installing mise..."
winget install jdx.mise --source winget --silent --accept-package-agreements --accept-source-agreements

# Note: mise activation is now handled by 06-powershell-profile.ps1

# Install development tools via mise (better version management than winget)
Write-Host "  Installing JVM tools via mise (Kotlin, Gradle, Maven)..."
try {
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
  mise use -g kotlin@latest 2>$null
  mise use -g gradle@latest 2>$null
  mise use -g maven@latest 2>$null
  Write-Host "  [OK] Kotlin, Gradle, Maven installed via mise" -ForegroundColor Green
} catch {
  Write-Warning "  mise tool installation will complete on next shell restart"
}

Write-Host "🧩 VS Code extensions (abbrev)"
foreach ($e in @(
  "EditorConfig.EditorConfig","streetsidesoftware.code-spell-checker","streetsidesoftware.code-spell-checker-australian-english",
  "eamodio.gitlens","ms-azuretools.vscode-docker","ms-vscode-remote.remote-wsl",
  "ms-python.python","ms-python.vscode-pylance","charliermarsh.ruff",
  "rust-lang.rust-analyzer","golang.Go",
  "ms-dotnettools.csharp","vscjava.vscode-java-pack",
  "dbaeumer.vscode-eslint","esbenp.prettier-vscode",
  "redhat.vscode-yaml","DavidAnson.vscode-markdownlint",
  "timonwong.shellcheck","exiasr.hadolint",
  "ms-vscode.powershell","yzhang.markdown-all-in-one","HashiCorp.terraform"
)) { try { code --install-extension $e --force | Out-Null } catch {} }

Write-Host "✅ Windows bootstrap complete."
