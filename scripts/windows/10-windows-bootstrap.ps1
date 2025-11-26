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

# Add MSBuild to PATH
$msbuildPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin"
if (Test-Path $msbuildPath) {
    $currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    if ($currentPath -notlike "*$msbuildPath*") {
        [Environment]::SetEnvironmentVariable('Path', "$currentPath;$msbuildPath", 'Machine')
        $env:Path = "$msbuildPath;$env:Path"
        Write-Host "  ✅ MSBuild added to PATH" -ForegroundColor Green
    }
}

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

# Container development tools
Write-Host "  Installing container development tools..."
winget install hadolint --source winget --silent --accept-package-agreements --accept-source-agreements
Write-Host "  → hadolint (Dockerfile linter) installed" -ForegroundColor Green

Write-Host "🐧 Ubuntu for WSL"
if (-not $skipWSL) {
  # Install Ubuntu (default/latest version)
  winget install Canonical.Ubuntu --source winget --silent --accept-package-agreements --accept-source-agreements
  # Set WSL 2 as default
  wsl --set-default-version 2
  Write-Host "  Note: Launch 'Ubuntu' from Start Menu to complete first-time setup" -ForegroundColor Yellow
} else {
  Write-Host "  → Skipped (WSL not installed)" -ForegroundColor Yellow
}

Write-Host "🐙 Git toolchain"
winget install Git.Git --source winget --silent --accept-package-agreements --accept-source-agreements
winget install GitHub.GitLFS --source winget --silent --accept-package-agreements --accept-source-agreements
winget install GitHub.cli --source winget --silent --accept-package-agreements --accept-source-agreements
winget install Git.GCM --source winget --silent --accept-package-agreements --accept-source-agreements
winget install GnuPG.GnuPG --source winget --silent --accept-package-agreements --accept-source-agreements
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

Write-Host "🔤 Developer Fonts (System-Wide Installation)"
# Check if JetBrainsMono Nerd Font is already installed (idempotent)
$existingFonts = Get-ChildItem -Path "$env:windir\Fonts" -Filter "*JetBrains*" -ErrorAction SilentlyContinue
if ($existingFonts.Count -gt 5) {
    Write-Host "  ✅ JetBrainsMono Nerd Font already installed ($($existingFonts.Count) font files)" -ForegroundColor Green
    $existingFonts | Select-Object -First 3 | ForEach-Object { Write-Host "    • $($_.Name)" -ForegroundColor Gray }
    if ($existingFonts.Count -gt 3) { Write-Host "    • ... and $($existingFonts.Count - 3) more" -ForegroundColor Gray }
} else {
    # Enhanced JetBrains Mono Nerd Font installation with multiple fallback methods
    Write-Host "  Installing JetBrainsMono Nerd Font with enhanced reliability..." -ForegroundColor Yellow
    $ProgressPreference = 'SilentlyContinue'
    $url = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip'
    $zipPath = Join-Path $env:TEMP 'JetBrainsMono.zip'
    $extractPath = Join-Path $env:TEMP 'JetBrainsMono'

    try {
        # Clean up any previous downloads
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

        # Download and extract
        Write-Host "  Downloading from GitHub..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $url -OutFile $zipPath -ErrorAction Stop
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        # Get font files (exclude Windows Compatible versions)
        $fonts = Get-ChildItem -Path $extractPath -Include '*.ttf' -Recurse | Where-Object {
            $_.Name -notmatch 'Windows Compatible'
        }

        if ($fonts.Count -eq 0) {
            throw "No suitable TTF font files found in downloaded archive"
        }

        Write-Host "  Installing $($fonts.Count) font files..." -ForegroundColor Gray
        $installed = 0
        $skipped = 0
        $failed = 0

        foreach ($font in $fonts) {
            $targetPath = Join-Path $env:windir "Fonts\$($font.Name)"
            try {
                if (-not (Test-Path $targetPath)) {
                    # Method 1: Registry-based installation (works better in admin context)
                    Copy-Item -Path $font.FullName -Destination $targetPath -Force

                    # Enhanced registry registration for better compatibility
                    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
                    $regName = "$($font.BaseName) (TrueType)"
                    Set-ItemProperty -Path $regPath -Name $regName -Value $font.Name -Force -ErrorAction SilentlyContinue

                    # Additional registry entry for console applications
                    $consoleFontPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont"
                    if (-not (Test-Path $consoleFontPath)) {
                        New-Item -Path $consoleFontPath -Force | Out-Null
                    }

                    # Register font for console use (important for PowerShell 7)
                    if ($font.BaseName -match "JetBrainsMono.*NF.*Regular|JetBrainsMono.*Nerd.*Font.*Regular") {
                        Set-ItemProperty -Path $consoleFontPath -Name "00" -Value $font.BaseName -Force -ErrorAction SilentlyContinue
                    }

                    $installed++
                    Write-Host "    ✅ Installed: $($font.BaseName)" -ForegroundColor Green
                } else {
                    $skipped++
                }
            } catch {
                # Fallback to COM method if registry method fails
                try {
                    $FONTS = 0x14
                    $fontsFolder = (New-Object -ComObject Shell.Application).Namespace($FONTS)
                    $fontsFolder.CopyHere($font.FullName, 0x10)
                    $installed++
                    Write-Host "    ✅ Installed (COM): $($font.BaseName)" -ForegroundColor Green
                } catch {
                    Write-Warning "Failed to install font $($font.Name): $_"
                    $failed++
                }
            }
        }

        # Cleanup
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

        # Force font cache refresh (makes fonts immediately available)
        Write-Host "  Refreshing font cache..." -ForegroundColor Gray
        try {
            # Notify system of font changes
            Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class Win32 { [DllImport("gdi32.dll")] public static extern int AddFontResource(string lpFileName); [DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam); }' -ErrorAction SilentlyContinue

            # Refresh font cache by broadcasting system change
            $HWND_BROADCAST = [IntPtr]0xFFFF
            $WM_FONTCHANGE = 0x1D
            [Win32]::SendMessage($HWND_BROADCAST, $WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null

            Write-Host "    ✅ Font cache refreshed" -ForegroundColor Green
        } catch {
            Write-Host "    → Font cache refresh failed, fonts will be available after restart" -ForegroundColor Yellow
        }

        if ($failed -gt 0) {
            Write-Host "  ⚠️  JetBrainsMono Nerd Font partially installed ($installed new, $skipped existed, $failed failed)" -ForegroundColor Yellow
            Write-Host "     Some font files may require different installation method" -ForegroundColor Gray
        } else {
            Write-Host "  ✅ JetBrainsMono Nerd Font installed ($installed new, $skipped already present)" -ForegroundColor Green
        }

        # Configure PowerShell 7 console font (important for admin prompts)
        Write-Host "  Configuring PowerShell 7 console font..." -ForegroundColor Gray
        try {
            # Find the best JetBrainsMono font name
            $installedFonts = Get-ChildItem "$env:windir\Fonts" -Filter "*JetBrains*" | Where-Object { $_.Name -match "NF.*Regular\.ttf$|Nerd.*Font.*Regular\.ttf$" }

            if ($installedFonts) {
                $bestFont = $installedFonts | Select-Object -First 1
                $fontBaseName = $bestFont.BaseName

                # PowerShell 7 console registry paths
                $ps7ConsolePaths = @(
                    "HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe",
                    "HKCU:\Console\PowerShell_7",
                    "HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell_ise.exe"
                )

                foreach ($path in $ps7ConsolePaths) {
                    if (-not (Test-Path $path)) {
                        New-Item -Path $path -Force | Out-Null
                    }

                    # Set font properties for PowerShell console
                    Set-ItemProperty -Path $path -Name "FaceName" -Value $fontBaseName -Type String -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $path -Name "FontFamily" -Value 54 -Type DWord -ErrorAction SilentlyContinue  # Modern font family
                    Set-ItemProperty -Path $path -Name "FontSize" -Value 0x000C0000 -Type DWord -ErrorAction SilentlyContinue  # Size 12
                    Set-ItemProperty -Path $path -Name "FontWeight" -Value 400 -Type DWord -ErrorAction SilentlyContinue  # Normal weight
                }

                Write-Host "    ✅ PowerShell console font configured: $fontBaseName" -ForegroundColor Green
                Write-Host "    💡 Restart PowerShell to see new font in admin prompts" -ForegroundColor Yellow
            } else {
                Write-Warning "Could not find suitable JetBrainsMono Nerd Font for console configuration"
            }
        } catch {
            Write-Warning "PowerShell console font configuration failed: $_"
        }
    } catch {
        Write-Warning "Font installation failed: $_"
        Write-Host "  💡 Try manually installing from: https://www.nerdfonts.com/font-downloads" -ForegroundColor Yellow
    }
}
$ProgressPreference = 'Continue'

# Note: Cascadia Code comes with Windows Terminal

Write-Host "💡 Note: Licensed apps (1Password, Office, GitKraken, etc.) moved to 11-licensed-apps.ps1"
Write-Host "   Run .\scripts\windows\11-licensed-apps.ps1 separately if needed" -ForegroundColor Yellow

Write-Host "🌐 Runtimes (latest channels)"
# Python latest (3.13 line)
winget install Python.Python.3.13 --source winget --silent --accept-package-agreements --accept-source-agreements

# Additional Python package managers
Write-Host "  Installing additional Python package managers..."
try {
  # Ensure pip is available and refresh environment
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

  # Install pipenv and poetry
  pip install --user pipenv
  pip install --user poetry

  # Verify installations
  if (Get-Command pipenv -ErrorAction SilentlyContinue) { Write-Host "  ✅ pipenv installed" -ForegroundColor Green }
  if (Get-Command poetry -ErrorAction SilentlyContinue) { Write-Host "  ✅ poetry installed" -ForegroundColor Green }

  Write-Host "  [OK] Additional Python package managers installed" -ForegroundColor Green
} catch {
  Write-Warning "Additional Python package managers installation failed: $_"
}

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

# Additional Node.js package managers
Write-Host "  Installing additional Node.js package managers..."
try {
  # Ensure npm is available and refresh environment
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

  # Install yarn, pnpm globally
  npm install -g yarn pnpm

  # Install bun using official installer (npm package doesn't work on Windows)
  if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing bun via official installer..."
    try {
      irm bun.sh/install.ps1 | iex
      Write-Host "  ✅ bun installed" -ForegroundColor Green
    } catch {
      Write-Warning "bun installation failed - install manually from https://bun.sh"
    }
  }

  # Verify installations
  if (Get-Command yarn -ErrorAction SilentlyContinue) { Write-Host "  ✅ yarn installed" -ForegroundColor Green }
  if (Get-Command pnpm -ErrorAction SilentlyContinue) { Write-Host "  ✅ pnpm installed" -ForegroundColor Green }
  if (Get-Command bun -ErrorAction SilentlyContinue) { Write-Host "  ✅ bun installed" -ForegroundColor Green }

  Write-Host "  [OK] Additional Node.js package managers installed" -ForegroundColor Green
} catch {
  Write-Warning "Additional Node.js package managers installation failed: $_"
}
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

  # Add mise shims to PATH for immediate access
  $miseShims = "$env:USERPROFILE\.local\share\mise\shims"
  if (Test-Path $miseShims) {
    $env:Path = "$miseShims;$env:Path"
  }

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
