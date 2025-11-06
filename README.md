# Surface Pro (ARM64) Dev Bootstrap — **Latest Everything**

This repo contains a clean set of scripts to build, harden, and maintain your **Windows on ARM (Snapdragon)** machine.

[![Release](https://img.shields.io/github/v/release/kpeacocke/devMachine)](https://github.com/kpeacocke/devMachine/releases)
[![Tests](https://github.com/kpeacocke/devMachine/actions/workflows/syntax-validation.yml/badge.svg)](https://github.com/kpeacocke/devMachine/actions/workflows/syntax-validation.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Semantic Versioning](https://img.shields.io/badge/semver-2.0.0-blue)](https://semver.org/)

## 📦 Download

**Latest Release**: Download pre-packaged scripts from [Releases](https://github.com/kpeacocke/devMachine/releases)

* **Windows Scripts Only** (`devMachine-windows-scripts-vX.X.X.zip`) - Surface Pro setup scripts
* **WSL Scripts Only** (`devMachine-wsl-scripts-vX.X.X.zip`) - Ubuntu/WSL configuration
* **Complete Package** (`devMachine-complete-vX.X.X.zip`) - Everything including tests and docs

All releases include SHA256 checksums for verification.

## 🚀 Quick Start (Automated Setup)

### One-Line Install (Latest Release)

**Download and run the complete setup automatically:**

```powershell
# Open PowerShell as Administrator, then:
Set-ExecutionPolicy Bypass -Scope Process -Force; $release = (irm https://api.github.com/repos/kpeacocke/devMachine/releases/latest); $asset = $release.assets | Where-Object { $_.name -like '*complete*.zip' } | Select-Object -First 1; irm $asset.browser_download_url -OutFile "$env:TEMP\devMachine.zip"; Expand-Archive -Path "$env:TEMP\devMachine.zip" -DestinationPath "$env:TEMP\devMachine" -Force; & "$env:TEMP\devMachine\setup-machine.ps1"
```

**For VMs (skip licensed apps, Dev Drive, and backup):**

```powershell
# Open PowerShell as Administrator, then:
Set-ExecutionPolicy Bypass -Scope Process -Force; $release = (irm https://api.github.com/repos/kpeacocke/devMachine/releases/latest); $asset = $release.assets | Where-Object { $_.name -like '*complete*.zip' } | Select-Object -First 1; irm $asset.browser_download_url -OutFile "$env:TEMP\devMachine.zip"; Expand-Archive -Path "$env:TEMP\devMachine.zip" -DestinationPath "$env:TEMP\devMachine" -Force; & "$env:TEMP\devMachine\setup-machine.ps1" -SkipLicensedApps -SkipDevDrive -SkipBackup
```

### Manual Download

Or download from [Releases](https://github.com/kpeacocke/devMachine/releases):

* **Windows Scripts Only** (`devMachine-windows-scripts-vX.X.X.zip`) - Surface Pro setup scripts
* **WSL Scripts Only** (`devMachine-wsl-scripts-vX.X.X.zip`) - Ubuntu/WSL configuration
* **Complete Package** (`devMachine-complete-vX.X.X.zip`) - Everything including tests and docs

All releases include SHA256 checksums for verification.

After download, extract and run:

```powershell
.\setup-machine.ps1
```

### Setup Phases

This orchestrator will:

* Install PowerShell 7 & Windows Terminal
* **Apply early security hardening BEFORE app installation** (firewall, UAC, Defender, disable legacy protocols)
* Install all dev tools (VS Code, Docker, Git, runtimes, cloud CLIs)
* Configure WSL 2 with Ubuntu
* Apply advanced security hardening AFTER apps (BitLocker, Credential Guard, HVCI, LSA Protection)
* Optimize for 512GB storage (move caches to Dev Drive, cleanup)
* Set up backup (Backblaze, File History, System Protection)
* Configure Ubuntu with full dev stack
* Run verification tests

**Security-First Approach**: Network-facing applications (Docker, Node.js, Python, VS Code, Git) install into a
hardened environment with firewall enabled and legacy protocols disabled from the start. Advanced security features
requiring reboots (BitLocker, Credential Guard) apply after apps are installed.

### Options

```powershell
# Skip optional components
.\setup-machine.ps1 -SkipBackup -SkipOptionalGoodies -SkipInsiders

# For VMs (skip licensed apps and Dev Drive optimizations)
.\setup-machine.ps1 -SkipLicensedApps -SkipDevDrive -SkipBackup

# Enable .NET weekly maintenance task
.\setup-machine.ps1 -ScheduleDotNetMaintenance

# Immediately activate Ultimate Performance power plan
.\setup-machine.ps1 -SetUltimatePerformance

# Custom Dev Drive path (if not skipping Dev Drive)
.\setup-machine.ps1 -DevDrivePath "E:\dev\caches"
```

> **Note for VMs**: Use `-SkipDevDrive` to skip Dev Drive cache relocation, which requires
> ReFS support and may not work in all VM environments. Combine with `-SkipLicensedApps` and
> `-SkipBackup` for a clean VM setup.

---

## 📋 Manual Setup (Step-by-Step)

If you prefer to run scripts individually:

### Order of operations (Windows)

1. **PowerShell first** – make PowerShell 7 default  

   ```powershell
   scripts/windows/00-pwsh-first.ps1
   ```

2. **Early security hardening** – enable firewall, UAC, Defender BEFORE app installation

   ```powershell
   scripts/windows/01-early-hardening.ps1
   ```

3. **Windows tooling** (VS Code, Docker, runtimes, CLIs, apps)  

   ```powershell
   scripts/windows/10-windows-bootstrap.ps1
   ```

4. **Windows debloat** (remove Xbox, games, Spotify, bloatware)

   ```powershell
   scripts/windows/09-debloat-windows.ps1
   ```

5. **Git & SSH configuration** (global config, SSH key generation)

   ```powershell
   scripts/windows/05-git-ssh-config.ps1
   ```

6. **PowerShell profile** (Oh-My-Posh, PSReadLine, aliases, functions)

   ```powershell
   scripts/windows/06-powershell-profile.ps1
   ```

7. **Licensed apps** (optional - skip for VMs)  

   ```powershell
   scripts/windows/11-licensed-apps.ps1
   ```

8. **Browsers, communications & media** (Chrome, Firefox, Teams, VLC, etc.)

   ```powershell
   scripts/windows/12-communications-media.ps1
   ```

9. **Social media & streaming** (Facebook, Instagram, Netflix, Disney+, AU TV apps)

   ```powershell
   scripts/windows/16-social-streaming.ps1
   ```

10. **Windows Terminal configuration** (settings.json automation)

    ```powershell
    scripts/windows/15-windows-terminal-config.ps1
    ```

11. **Advanced security hardening** (BitLocker, Credential Guard, HVCI, LSA Protection - requires reboot)

    ```powershell
    scripts/windows/30-optimize-and-harden.ps1
    ```

12. **Performance tuning** (Ultimate plan, storage sense, indexing)  

    ```powershell
    scripts/windows/31-performance-tuning.ps1 -SetUltimateNow
    ```

13. **Auto power plan toggle** (AC→Ultimate, Battery→Balanced)  

    ```powershell
    scripts/windows/32-powerplan-auto-toggle.ps1
    ```

14. **Privacy & telemetry hardening** (disable telemetry, Game Mode, Cortana, etc.)

    ```powershell
    scripts/windows/35-privacy-telemetry.ps1
    ```

15. **DNS security & advanced firewall** (DNS over HTTPS, dev tool firewall rules)

    ```powershell
    scripts/windows/36-dns-firewall-advanced.ps1
    ```

16. **Services optimization** (disable unnecessary Windows services)

    ```powershell
    scripts/windows/37-services-optimization.ps1
    ```

17. **Move caches to Dev Drive** (saves 20-50GB on C:)

    ```powershell
    scripts/windows/40-devdrive-caches.ps1
    ```

18. **Linters & formatters** (ESLint, Prettier, Ruff, Stylelint, etc.)

    ```powershell
    scripts/windows/13-linters-formatters.ps1
    ```

19. **Additional dev tools** (Insomnia, DBeaver, Wireshark, Blender, Godot, etc.)

    ```powershell
    scripts/windows/14-additional-dev-tools.ps1
    ```

20. **Optional dev goodies** (Sysinternals, mkcert, security tools, k8s)

    ```powershell
    scripts/windows/33-optional-dev-goodies.ps1
    ```

21. **Backup setup** (File History, System Protection)

    ```powershell
    scripts/windows/80-backup-setup.ps1
    ```

22. **.NET maintainer** (one-off or weekly)  

    ```powershell
    scripts/windows/60-dotnet-maintain.ps1 -ScheduleWeekly
    ```

23. **Doctor check**  

    ```powershell
    scripts/windows/50-doctor.ps1 -VerboseOut
    ```

### Insider channels (optional)

* Opt-in to **Windows Canary/Dev**, **Office BetaChannel**, **VS Code Insiders**  

  ```powershell
  scripts/windows/70-insiders-optin.ps1
  scripts/windows/72-vscode-insiders-setup.ps1
  ```

* Revert to stable  

  ```powershell
  scripts/windows/71-insiders-revert.ps1
  ```

### WSL (Ubuntu) setup

1. Bootstrap languages & tools (Temurin latest, Node current, pyenv, mise for Kotlin/Gradle, R/PHP/Ruby, linters):

   ```powershell
   scripts/wsl/20-ubuntu-bootstrap.sh
   ```

2. Tune WSL (wsl.conf, mkcert trust, QoL):

   ```powershell
   scripts/wsl/21-wsl-tune.sh
   ```

3. Health check:

   ```powershell
   scripts/wsl/doctor-ubuntu.sh
   ```

---

## 🧪 Tests

Comprehensive test coverage for all installed components:

### Windows Tests (Pester)

**Note:** Pester 5+ is automatically installed during bootstrap for local test execution.

```powershell
pwsh -NoProfile -File .\tests\pester.Windows.Tests.ps1
```

Tests verify:

* WSL 2 installation and configuration
* Core CLIs (git, docker, node, python, go, rust, java, terraform, etc.)
* Security tools (snyk, trivy)
* Security hardening (Firewall, Defender, BitLocker, Credential Guard, UAC, HVCI)
* System services (OpenSSH, Docker)
* Storage optimization (Dev Drive, cache relocations)
* Scheduled tasks (winget upgrades, .NET maintenance)
* Backup configuration

### Ubuntu/WSL Tests

```bash
wsl -d Ubuntu -e bash ./tests/ubuntu-smoke-test.sh
```

Tests verify:

* Build tools (gcc, g++, make, cmake)
* Version managers (nvm, pyenv, mise)
* Runtimes (node, python, java, kotlin, gradle, go, rust, ruby, php)
* Linters and tools (shellcheck, eslint, phpcs, rubocop, etc.)
* Docker WSL integration
* R packages
* Security tools (pre-commit, semgrep, detect-secrets, bandit)

### Quick Health Check

```powershell
# Windows
pwsh -File .\scripts\windows\50-doctor.ps1 -VerboseOut

# Ubuntu  
wsl -d Ubuntu -e bash ./scripts/wsl/doctor-ubuntu.sh
```

---

## 📊 What's Installed

### Windows

* **Editors**: VS Code (stable or Insiders)
* **Containers**: Docker Desktop
* **WSL**: Ubuntu 22.04/24.04 on WSL 2
* **VCS**: Git, Git LFS, GitHub CLI, Git Credential Manager
* **Security**: 1Password (GUI + CLI), Backblaze, GlassWire (network monitor), Malwarebytes
* **Productivity**: GitKraken, Beyond Compare, Scrivener, Obsidian
* **Browsers**: Google Chrome, Mozilla Firefox
* **Communications**: Microsoft Teams, WhatsApp, Signal, Slack, Discord
* **Media Players**: VLC, HandBrake (GUI + CLI), K-Lite Mega Codec Pack, Plex
* **Social Media**: Facebook, Instagram, LinkedIn, X (Twitter), Reddit
* **Streaming**: Apple Music, Apple TV, Disney+, Netflix, Paramount+, Prime Video, Stan
* **AU Free-to-Air TV**: ABC iview, SBS On Demand, 7plus, 9Now, 10 play
* **Fonts**: Cascadia Code, JetBrains Mono Nerd Font
* **Runtimes**: Python 3.13, Node Current, Go, Rust, .NET 9, Java Temurin (latest GA)
* **Build Tools**: Maven, Gradle, CMake, Make
* **Cloud/IaC**: Terraform, Packer, TFLint, AWS CLI, Azure CLI, Google Cloud SDK
* **Version Managers**: mise (Kotlin + Gradle latest)
* **Linters/Formatters**:
  * **JavaScript/TypeScript**: ESLint, Prettier
  * **Python**: Ruff (linter + formatter), Black (fallback)
  * **CSS**: Stylelint
  * **Markdown**: markdownlint-cli2
  * **Shell**: shellcheck
  * **Docker**: hadolint
  * **YAML**: yamllint
  * **Terraform**: tflint
  * **GitHub Actions**: actionlint
  * **JSON**: jsonlint
  * **TOML**: taplo-cli
* **API Testing**: Insomnia (free REST client)
* **Databases**: DBeaver (universal client), SQL Server Management Studio
* **Network Tools**: Wireshark, nmap
* **Screen Recording**: OBS Studio (free, open-source)
* **3D & Game Dev**: Blender, Godot Engine
* **System Utilities**: PowerToys, QuickLook
* **Dev Tools**: Sysinternals, mkcert, ripgrep, fd, fzf, bat, delta, chezmoi
* **Security Scanning**: Snyk, Trivy, gitleaks, pre-commit, semgrep, detect-secrets, bandit
* **Testing/CI**: Pester 5+ (PowerShell), nektos/act (GitHub Actions), newman (Postman), pytest-cov, tox
* **Kubernetes** (optional): kubectl, Helm, k9s
* **Search**: Everything (replaces Windows Search)
* **PowerShell**: Oh-My-Posh (paradox theme), PSReadLine (predictions, history search), posh-git

### Ubuntu (WSL)

* **Build essentials**: gcc, g++, make, cmake, ninja, pkg-config
* **Java**: Temurin 25 JDK (latest GA)
* **Node**: Current (via nvm)
* **Python**: System + pyenv for version management
* **Kotlin/Gradle**: Latest (via mise)
* **Go, Rust**: Latest stable
* **R**: With languageserver, lintr, styler
* **PHP**: With Composer + tools (phpcs, phpstan, psalm, php-cs-fixer)
* **Ruby**: With bundler, rubocop
* **Linters**: shellcheck, eslint, prettier, markdownlint, stylelint
* **Security**: pre-commit, semgrep, detect-secrets, bandit
* **Dev TLS**: mkcert with trusted CA

---

## 🔒 Security Hardening Applied

### Two-Phase Security Architecture

**Phase 1: Early Hardening (BEFORE app installation)**
Network-facing applications install into a secure environment from the start. Applied via `01-early-hardening.ps1`:

* **Firewall**: Enabled on all profiles (block inbound by default)
* **Windows Defender**: PUA protection, Network Protection, cloud-delivered protection
* **UAC**: Always notify (max security, secure desktop)
* **SMBv1**: Disabled (WannaCry vulnerability)
* **RDP**: Disabled (security risk)
* **LLMNR/NetBIOS**: Disabled (prevents spoofing attacks)
* **NTFS Long Paths**: Enabled (npm, modern dev tools)
* **Developer Mode**: Enabled (symlinks, debugging)

**Phase 2: Advanced Hardening (AFTER app installation - requires reboot)**
Applied via `30-optimize-and-harden.ps1`:

* **BitLocker**: Enabled on C: with XTS-AES256
* **Credential Guard**: Enabled with UEFI lock
* **LSA Protection**: RunAsPPL enabled
* **Core Isolation (HVCI)**: Enabled
* **SSH**: Key-only authentication (password auth disabled)
* **DNS over HTTPS**: Enabled (Cloudflare/Google/Quad9 options)
* **Windows Defender ASR Rules**: Enabled (audit mode)
* **PowerShell Logging**: ScriptBlock logging, transcription
* **Firewall Rules**: Dev tools (Docker, Node.js, Python, databases, Kubernetes, WSL 2)

**Additional Privacy & Security** (optional scripts):

* **Telemetry**: Disabled (privacy hardening)
* **Cortana/Game Mode**: Disabled
* **Windows Consumer Features**: Disabled (prevents bloatware reinstall)
* **Services**: Unnecessary Windows services disabled
* **DNS Security**: Advanced firewall rules for dev tools
* **Services**: Unnecessary services disabled (Print Spooler, Remote Registry, Xbox, etc.)
* **Enhanced Audit Logging**: Process creation, logon, account lockout, file share
* **Log Sizes**: Security 500MB, System 100MB

### Security Scanning Strategy

**Multi-Layer Defense:**

* **Windows Defender** (real-time): Primary AV with automated exclusions for dev folders
* **Malwarebytes** (on-demand): Weekly deep scans for malware/PUPs
* **GlassWire** (network monitor): Real-time network activity visibility
* **Snyk/Trivy** (code/containers): Vulnerability scanning in CI/CD pipelines

**Automated Defender Exclusions** (applied during hardening):

* Dev Drive caches: `D:\dev\caches`
* Package manager caches: `.cargo`, `.rustup`, `go`, `.gradle`, `.m2`, `.nuget`, `.dotnet`, `pip`, `pipx`, `npm`
* Common build folders: `node_modules`, `.git`, `target`, `build`, `dist`, `.venv`, `venv`

These exclusions improve build performance while maintaining security on source code and downloads.

---

## ⚡ Performance Optimizations

* **WSL**: Sparse VHD (saves 10-20GB), auto memory reclaim
* **Storage**: Component cleanup (2-5GB saved), Storage Sense automation
* **Docker**: Data-root moved to Dev Drive (saves 20-50GB)
* **Caches**: npm, yarn, pnpm, cargo, go, gradle, maven, composer → Dev Drive
* **Search**: Windows Search disabled, replaced with Everything
* **Services**: Superfetch/Prefetch disabled (SSD optimization), Xbox services disabled, unnecessary services stopped
* **Network**: Bandwidth throttling disabled, TCP/IP stack optimized
* **Power**: Ultimate Performance available, auto-toggle on AC/battery
* **Indexing**: Dev Drive excluded from search indexing
* **Bloatware Removed**: Xbox apps, games (Solitaire, Candy Crush), Spotify, pre-installed bloat
* **Telemetry**: Disabled for privacy and performance
* **PowerShell**: Enhanced profile with Oh-My-Posh, PSReadLine, 20+ aliases, helper functions

**Total Storage Saved**: ~33-77GB on C:

---

## 🎯 Key Features

### Automation Scripts

* **09-debloat-windows.ps1**: Remove pre-installed bloatware (Xbox, games, Spotify, etc.)
* **05-git-ssh-config.ps1**: Automated Git global config and SSH key generation
* **06-powershell-profile.ps1**: Comprehensive PowerShell profile (Oh-My-Posh, PSReadLine, aliases, functions)
* **12-communications-media.ps1**: Browsers, Teams, WhatsApp, Signal, Slack, Discord, VLC, HandBrake
* **13-linters-formatters.ps1**: ESLint, Prettier, Ruff, Stylelint, markdownlint, Yamllint, hadolint
* **14-additional-dev-tools.ps1**: Insomnia, DBeaver, SSMS, Wireshark, nmap, OBS Studio, Blender, Godot, PowerToys
* **15-windows-terminal-config.ps1**: Automated Windows Terminal settings.json configuration
* **16-social-streaming.ps1**: Social media (Facebook, Instagram, LinkedIn, X, Reddit) and streaming services
  (Netflix, Disney+, AU TV apps)
* **35-privacy-telemetry.ps1**: Disable Windows telemetry, Game Mode, Cortana, advertising ID
* **36-dns-firewall-advanced.ps1**: DNS over HTTPS + dev tool firewall rules
* **37-services-optimization.ps1**: Disable unnecessary Windows services for performance/security

---

## 📝 Notes

* Java uses **Eclipse Temurin (rolling GA)** so it always pulls the latest major (e.g., 25 → 26 automatically when GA).
* Node uses **Current** (not LTS).
* Python uses the **3.13** stream (latest stable at time of writing).
* Kotlin/Gradle stay latest via **mise**.
* .NET maintainer keeps **latest SDK** installed, prunes extras, updates workloads, and can **self-schedule weekly**.
* **Reboot required** after hardening script to enable Credential Guard and LSA Protection.

---

## ⚙️ Post-Setup Configuration

### Malwarebytes Configuration

After installation, configure Malwarebytes for optimal dev machine performance:

1. **Open Malwarebytes** → Settings → Security
2. **Exclude Dev Folders** from scans:
   * Add: `D:\dev\caches` (entire Dev Drive)
   * Add: `C:\Users\<YourUsername>\.cargo`
   * Add: `C:\Users\<YourUsername>\.rustup`
   * Add: `C:\Users\<YourUsername>\go`
   * Add: `C:\Users\<YourUsername>\.gradle`
   * Add: `C:\Users\<YourUsername>\.m2`
   * Add: `C:\Users\<YourUsername>\.nuget`
3. **Schedule Weekly Scans**: Settings → Scheduled Scans
   * Enable scheduled scan (suggested: Sunday 2AM)
   * Scan type: Threat Scan (not full disk scan)
4. **Ransomware Protection**: Enable but add trusted applications:
   * Visual Studio Code
   * JetBrains IDEs (if installed)
   * Node.js, Python, Go, Rust (if flagged)

### GlassWire Configuration

Configure network monitoring:

1. **Open GlassWire** → Settings → Security
2. **Block Mode**: Ask to Connect (recommended for dev)
3. **Auto-allow known dev tools**:
   * Docker Desktop
   * Node.js
   * WSL/Ubuntu processes
   * VS Code
   * Git/GitHub Desktop
4. **Bandwidth Monitoring**: Enable alerts at 80% of monthly cap (if applicable)
5. **Firewall Rules**: Settings → Firewall
   * Allow: localhost connections (127.0.0.1, ::1)
   * Allow: WSL mirrored network

### Backblaze Configuration

1. **Sign in** to Backblaze account
2. **Exclusions** (Settings → Exclusions):
   * Exclude: `D:\` (entire Dev Drive - temporary build artifacts)
   * Exclude: `C:\Users\<YourUsername>\node_modules` (if not on Dev Drive)
   * Exclude: `C:\Users\<YourUsername>\AppData\Local\Docker`
3. **Threads**: Settings → Performance → Increase to 10-20 threads for faster backup
4. **Version History**: Keep default (30 days)

### 1Password Configuration

1. **Enable SSH Agent**: Settings → Developer → Use SSH Agent
2. **Enable CLI**: Settings → Developer → Set up Biometric Unlock for CLI
3. **Browser Integration**: Install extensions for Chrome/Edge/Firefox

### Git Configuration

```powershell
# Set your identity
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Use 1Password SSH agent
git config --global gpg.ssh.program "C:\Program Files\1Password\app\8\op-ssh-sign.exe"

# Default branch name
git config --global init.defaultBranch main

# Better diff/merge tools
git config --global merge.tool vscode
git config --global diff.tool vscode
```

---

## 🛠️ Troubleshooting

### WSL Issues

```powershell
# Restart WSL
wsl --shutdown

# Check WSL version
wsl --status

# Set Ubuntu to WSL 2
wsl --set-version Ubuntu 2
```

### Docker Not Starting

```powershell
# Check Docker data-root was created
Test-Path D:\dev\caches\docker

# Restart Docker Desktop
Restart-Service com.docker.service
```

### Tests Failing

```powershell
# Update PATH in new terminal
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")

# Verify specific tool
Get-Command <tool-name>
```

Happy building!

---

## 💰 License Costs

Some tools require paid licenses. These are split into a separate script (`11-licensed-apps.ps1`)
that you can skip when setting up VMs or if you prefer free alternatives.

### Core Licensed Apps (Always Installed)

| Tool | Type | Cost | Notes |
|------|------|------|-------|
| **1Password** | Password Manager | ~$36-96/year | Essential for SSH agent in this setup |
| **Microsoft 365** | Office Suite | ~$70-100/year | Productivity apps |
| **GitKraken** | Git GUI | ~$60-90/year | Free for public repos |
| **Beyond Compare 4** | Diff/Merge Tool | ~$60 one-time | 30-day trial available |
| **Scrivener 3** | Writing Software | ~$50-60 one-time | For long-form writing |
| **Obsidian** | Note-taking | Free (personal) | ~$50/year commercial |
| **Backblaze** | Cloud Backup | ~$99/year | Unlimited backup |
| **Malwarebytes** | Anti-malware | ~$40/year | Free tier for manual scans |
| **GlassWire** | Network Monitor | ~$50-100 one-time | Free tier available |

### Optional Paid Apps (Prompted During Setup)

| Tool | Type | Cost | Notes |
|------|------|------|-------|
| **Typora** | Markdown Editor | ~$15 one-time | Beautiful WYSIWYG markdown |
| **Postman Pro** | API Testing | ~$12-49/month | Free tier available (Insomnia is free alternative) |

### Free Alternatives

* **1Password** → Bitwarden (open-source, free)
* **Beyond Compare** → WinMerge (free), Meld (free)
* **GitKraken** → GitHub Desktop (free), Fork (free for evaluation)
* **Backblaze** → Google Drive, OneDrive (included with Microsoft 365)
* **Office** → LibreOffice (free), Google Docs (free)
* **Obsidian** → Notion (free), Logseq (free), Joplin (free)
* **Postman** → Insomnia (free, installed in 14-additional-dev-tools.ps1)
* **Typora** → VS Code (free, already installed), MarkText (free)

**Total Cost Estimate:**

* **First Year**: ~$315-505 (including one-time purchases)
* **Annual**: ~$205-395/year (subscriptions only)
* **Optional Add-ons**: ~$15-588/year (Typora + Postman Pro if chosen)
* **VM/Free Setup**: $0 (use alternatives and skip licensed apps script)

**Skip licensed apps**: `.\setup-machine.ps1 -SkipLicensedApps`
