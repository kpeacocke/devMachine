# Surface Pro (ARM64) Dev Bootstrap — **Latest Everything**

This repo contains a clean set of scripts to build, harden, and maintain your **Windows on ARM (Snapdragon)** dev machine and WSL.

## 🚀 Quick Start (Automated Setup)

**New machine? Run this ONE command:**

```powershell
# Open PowerShell as Administrator, then:
Set-ExecutionPolicy Bypass -Scope Process -Force
.\setup-machine.ps1
```

This orchestrator will:

- Install PowerShell 7 & Windows Terminal
- Install all dev tools (VS Code, Docker, Git, runtimes, cloud CLIs)
- Configure WSL 2 with Ubuntu
- Apply security hardening (Defender, BitLocker, Credential Guard, firewall)
- Optimize for 512GB storage (move caches to Dev Drive, cleanup)
- Set up backup (Backblaze, File History, System Protection)
- Configure Ubuntu with full dev stack
- Run verification tests

### Options

```powershell
# Skip optional components
.\setup-machine.ps1 -SkipBackup -SkipOptionalGoodies -SkipInsiders

# Enable .NET weekly maintenance task
.\setup-machine.ps1 -ScheduleDotNetMaintenance

# Immediately activate Ultimate Performance power plan
.\setup-machine.ps1 -SetUltimatePerformance

# Custom Dev Drive path
.\setup-machine.ps1 -DevDrivePath "E:\dev\caches"
```

---

## 📋 Manual Setup (Step-by-Step)

If you prefer to run scripts individually:

### Order of operations (Windows)

1. **PowerShell first** – make PowerShell 7 default  

   ```powershell
   scripts/windows/00-pwsh-first.ps1
   ```

2. **Windows tooling** (VS Code, Docker, runtimes, CLIs, apps)  

   ```powershell
   scripts/windows/10-windows-bootstrap.ps1
   ```

3. **Optimize + Harden** (safe defaults)  

   ```powershell
   scripts/windows/30-optimize-and-harden.ps1
   ```

4. **Performance tuning** (Ultimate plan, storage sense, indexing)  

   ```powershell
   scripts/windows/31-performance-tuning.ps1 -SetUltimateNow
   ```

5. **Auto power plan toggle** (AC→Ultimate, Battery→Balanced)  

   ```powershell
   scripts/windows/32-powerplan-auto-toggle.ps1
   ```

6. **Move caches to Dev Drive** (saves 20-50GB on C:)

   ```powershell
   scripts/windows/40-devdrive-caches.ps1
   ```

7. **Optional dev goodies** (Sysinternals, mkcert, security tools, k8s)

   ```powershell
   scripts/windows/33-optional-dev-goodies.ps1
   ```

8. **Backup setup** (Backblaze, File History, System Protection)

   ```powershell
   scripts/windows/80-backup-setup.ps1
   ```

9. **.NET maintainer** (one-off or weekly)  

   ```powershell
   scripts/windows/60-dotnet-maintain.ps1 -ScheduleWeekly
   ```

10. **Doctor check**  

    ```powershell
    scripts/windows/50-doctor.ps1 -VerboseOut
    ```

### Insider channels (optional)

- Opt-in to **Windows Canary/Dev**, **Office BetaChannel**, **VS Code Insiders**  

  ```powershell
  scripts/windows/70-insiders-optin.ps1
  scripts/windows/72-vscode-insiders-setup.ps1
  ```

- Revert to stable  

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

```powershell
pwsh -NoProfile -File .\tests\pester.Windows.Tests.ps1
```

Tests verify:

- WSL 2 installation and configuration
- Core CLIs (git, docker, node, python, go, rust, java, terraform, etc.)
- Security tools (snyk, trivy)
- Security hardening (Firewall, Defender, BitLocker, Credential Guard, UAC, HVCI)
- System services (OpenSSH, Docker)
- Storage optimization (Dev Drive, cache relocations)
- Scheduled tasks (winget upgrades, .NET maintenance)
- Backup configuration

### Ubuntu/WSL Tests

```bash
wsl -d Ubuntu -e bash ./tests/ubuntu-smoke-test.sh
```

Tests verify:

- Build tools (gcc, g++, make, cmake)
- Version managers (nvm, pyenv, mise)
- Runtimes (node, python, java, kotlin, gradle, go, rust, ruby, php)
- Linters and tools (shellcheck, eslint, phpcs, rubocop, etc.)
- Docker WSL integration
- R packages
- Security tools (pre-commit, semgrep, detect-secrets, bandit)

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

- **Editors**: VS Code (stable or Insiders)
- **Containers**: Docker Desktop
- **WSL**: Ubuntu 22.04/24.04 on WSL 2
- **VCS**: Git, Git LFS, GitHub CLI, Git Credential Manager
- **Security**: 1Password (GUI + CLI), Backblaze, GlassWire (network monitor), Malwarebytes
- **Productivity**: GitKraken, Beyond Compare, Scrivener, Obsidian
- **Fonts**: Cascadia Code, JetBrains Mono Nerd Font
- **Runtimes**: Python 3.13, Node Current, Go, Rust, .NET 9, Java Temurin (latest GA)
- **Build Tools**: Maven, Gradle, CMake, Make
- **Cloud/IaC**: Terraform, Packer, TFLint, AWS CLI, Azure CLI, Google Cloud SDK
- **Version Managers**: mise (Kotlin + Gradle latest)
- **Dev Tools**: Sysinternals, mkcert, ripgrep, fd, fzf, bat, delta, chezmoi
- **Security Scanning**: Snyk, Trivy, gitleaks, pre-commit, semgrep, detect-secrets, bandit
- **Testing/CI**: nektos/act, newman, pytest-cov, tox
- **Kubernetes** (optional): kubectl, Helm, k9s
- **Search**: Everything (replaces Windows Search)

### Ubuntu (WSL)

- **Build essentials**: gcc, g++, make, cmake, ninja, pkg-config
- **Java**: Temurin 25 JDK (latest GA)
- **Node**: Current (via nvm)
- **Python**: System + pyenv for version management
- **Kotlin/Gradle**: Latest (via mise)
- **Go, Rust**: Latest stable
- **R**: With languageserver, lintr, styler
- **PHP**: With Composer + tools (phpcs, phpstan, psalm, php-cs-fixer)
- **Ruby**: With bundler, rubocop
- **Linters**: shellcheck, eslint, prettier, markdownlint, stylelint
- **Security**: pre-commit, semgrep, detect-secrets, bandit
- **Dev TLS**: mkcert with trusted CA

---

## 🔒 Security Hardening Applied

- **Firewall**: Enabled on all profiles (block inbound by default)
- **Windows Defender**: PUA protection, Network Protection, ASR rules (audit mode)
- **BitLocker**: Enabled on C: with XTS-AES256
- **Credential Guard**: Enabled with UEFI lock
- **LSA Protection**: RunAsPPL enabled
- **Core Isolation (HVCI)**: Enabled
- **UAC**: Always notify (max security)
- **SSH**: Key-only authentication (password auth disabled)
- **RDP**: Disabled
- **SMBv1**: Disabled
- **Enhanced Audit Logging**: Process creation, logon, account lockout, file share
- **Log Sizes**: Security 500MB, System 100MB

### Security Scanning Strategy

**Multi-Layer Defense:**

- **Windows Defender** (real-time): Primary AV with automated exclusions for dev folders
- **Malwarebytes** (on-demand): Weekly deep scans for malware/PUPs
- **GlassWire** (network monitor): Real-time network activity visibility
- **Snyk/Trivy** (code/containers): Vulnerability scanning in CI/CD pipelines

**Automated Defender Exclusions** (applied during hardening):

- Dev Drive caches: `D:\dev\caches`
- Package manager caches: `.cargo`, `.rustup`, `go`, `.gradle`, `.m2`, `.nuget`, `.dotnet`, `pip`, `pipx`, `npm`
- Common build folders: `node_modules`, `.git`, `target`, `build`, `dist`, `.venv`, `venv`

These exclusions improve build performance while maintaining security on source code and downloads.

---

## ⚡ Performance Optimizations

- **WSL**: Sparse VHD (saves 10-20GB), auto memory reclaim
- **Storage**: Component cleanup (2-5GB saved), Storage Sense automation
- **Docker**: Data-root moved to Dev Drive (saves 20-50GB)
- **Caches**: npm, yarn, pnpm, cargo, go, gradle, maven, composer → Dev Drive
- **Search**: Windows Search disabled, replaced with Everything
- **Services**: Superfetch/Prefetch disabled (SSD optimization)
- **Network**: Bandwidth throttling disabled, TCP/IP stack optimized
- **Power**: Ultimate Performance available, auto-toggle on AC/battery
- **Indexing**: Dev Drive excluded from search indexing

**Total Storage Saved**: ~33-77GB on C:

---

## 📝 Notes

- Java uses **Eclipse Temurin (rolling GA)** so it always pulls the latest major (e.g., 25 → 26 automatically when GA).
- Node uses **Current** (not LTS).
- Python uses the **3.13** stream (latest stable at time of writing).
- Kotlin/Gradle stay latest via **mise**.
- .NET maintainer keeps **latest SDK** installed, prunes extras, updates workloads, and can **self-schedule weekly**.
- **Reboot required** after hardening script to enable Credential Guard and LSA Protection.

---

## ⚙️ Post-Setup Configuration

### Malwarebytes Configuration

After installation, configure Malwarebytes for optimal dev machine performance:

1. **Open Malwarebytes** → Settings → Security
2. **Exclude Dev Folders** from scans:
   - Add: `D:\dev\caches` (entire Dev Drive)
   - Add: `C:\Users\<YourUsername>\.cargo`
   - Add: `C:\Users\<YourUsername>\.rustup`
   - Add: `C:\Users\<YourUsername>\go`
   - Add: `C:\Users\<YourUsername>\.gradle`
   - Add: `C:\Users\<YourUsername>\.m2`
   - Add: `C:\Users\<YourUsername>\.nuget`
3. **Schedule Weekly Scans**: Settings → Scheduled Scans
   - Enable scheduled scan (suggested: Sunday 2AM)
   - Scan type: Threat Scan (not full disk scan)
4. **Ransomware Protection**: Enable but add trusted applications:
   - Visual Studio Code
   - JetBrains IDEs (if installed)
   - Node.js, Python, Go, Rust (if flagged)

### GlassWire Configuration

Configure network monitoring:

1. **Open GlassWire** → Settings → Security
2. **Block Mode**: Ask to Connect (recommended for dev)
3. **Auto-allow known dev tools**:
   - Docker Desktop
   - Node.js
   - WSL/Ubuntu processes
   - VS Code
   - Git/GitHub Desktop
4. **Bandwidth Monitoring**: Enable alerts at 80% of monthly cap (if applicable)
5. **Firewall Rules**: Settings → Firewall
   - Allow: localhost connections (127.0.0.1, ::1)
   - Allow: WSL mirrored network

### Backblaze Configuration

1. **Sign in** to Backblaze account
2. **Exclusions** (Settings → Exclusions):
   - Exclude: `D:\` (entire Dev Drive - temporary build artifacts)
   - Exclude: `C:\Users\<YourUsername>\node_modules` (if not on Dev Drive)
   - Exclude: `C:\Users\<YourUsername>\AppData\Local\Docker`
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
