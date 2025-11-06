# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0](https://github.com/kpeacocke/devMachine/compare/v1.1.0...v1.2.0) (2025-11-06)


### 🚀 Features

* **security:** update firewall script to reflect early hardening phase and remove redundant checks ([e2cbfd8](https://github.com/kpeacocke/devMachine/commit/e2cbfd885a7d81173c256d75ffdf8a320d5dc079))
* **setup:** add early security hardening phase to setup process and update related scripts ([4f40bca](https://github.com/kpeacocke/devMachine/commit/4f40bcafcd4aad67e8af90bcbd29c088c179532e))

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0](https://github.com/kpeacocke/devMachine/compare/v1.0.2...v1.1.0) (2025-11-06)

### 🚀 Features

* Add scripts for Windows Terminal configuration, privacy hardening, DNS security, and service optimization ([8e7811c](https://github.com/kpeacocke/devMachine/commit/8e7811c4c18a4fda99e9aa95abf3c30cbb480698))
* **setup:** add optional phase for social media and streaming app installation ([da6214c](https://github.com/kpeacocke/devMachine/commit/da6214c2ba9875d51e5907567154919e3433f9c2))
* **setup:** add optional Windows debloat phase to setup script and create debloat script ([0a2d4fe](https://github.com/kpeacocke/devMachine/commit/0a2d4fe27f096957d211dcc86478a0be471a422e))
* **setup:** add script for installing social media and streaming apps from Microsoft Store ([046f81b](https://github.com/kpeacocke/devMachine/commit/046f81bdd92c1bde63afe9fc3446664af78f2c00))
* **setup:** update README and scripts for Pester 5 installation and licensed apps management ([20e9597](https://github.com/kpeacocke/devMachine/commit/20e9597080f5081b2abca3424053d7a3fec33e5d))
* **setup:** update setup order and scripts for Windows debloat, Git configuration, and media installations ([9433873](https://github.com/kpeacocke/devMachine/commit/94338733574d352ef1a4e124f96a2f22d2ac68d4))

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2](https://github.com/kpeacocke/devMachine/compare/v1.0.1...v1.0.2) (2025-11-05)

### 📚 Documentation

* **readme:** expand Quick Start with one-line install, VM example, manual download and setup phases ([e1547b7](https://github.com/kpeacocke/devMachine/commit/e1547b7afe427d9e79129a8d93213e8110e40ca9))

## [1.0.1](https://github.com/kpeacocke/devMachine/compare/v1.0.0...v1.0.1) (2025-11-05)

### 📚 Documentation

* normalize line wrapping in CODE_OF_CONDUCT.md and tidy CHANGELOG spacing ([7b68639](https://github.com/kpeacocke/devMachine/commit/7b6863950b6b6bb0c29fc91d09edea42c1fa6793))
* normalize list markers to asterisks and standardize fenced code blocks across repository docs ([a062349](https://github.com/kpeacocke/devMachine/commit/a0623499118c4ff714170a23feb2f45d2152fae0))

## 1.0.0 (2025-11-05)

### 🚀 Features

* **repo:** add GitHub workflows, templates, docs, license and split licensed apps ([ac90f01](https://github.com/kpeacocke/devMachine/commit/ac90f01fcac86b5214e33833c20c4d7016676b83))
* **setup:** add -SkipDevDrive switch and guard Dev Drive phase; update README with VM note and examples ([0ab6277](https://github.com/kpeacocke/devMachine/commit/0ab62778ea6d1827f0d0f999a8d735663c25428c))

> **Note**: From v1.1.0 onwards, this changelog is automatically generated using
> [semantic-release](https://semantic-release.gitbook.io/) based on
> [Conventional Commits](https://www.conventionalcommits.org/).
> See [COMMIT_CONVENTION.md](.github/COMMIT_CONVENTION.md) for commit message guidelines.

## [Unreleased]

### Added

* Complete GitHub repository infrastructure (issue templates, PR template, workflows)
* Comprehensive security policy and contributing guidelines
* Syntax validation tests for all PowerShell and bash scripts
* Integration testing workflow with scheduled runs
* Automated release workflow that publishes GitHub releases on version tags
* Release artifacts with Windows scripts, WSL scripts, and complete archives
* SHA256 checksums for all release downloads
* License costs documentation with free alternatives

### Changed

* Split licensed/commercial applications into separate script (`11-licensed-apps.ps1`)
* Updated orchestrator to prompt for licensed apps installation
* Improved PowerShell syntax compatibility (fixed Unicode issues)
* Enhanced error handling and validation across all scripts

### Security

* Added automated security scanning with Trivy
* Implemented checks for hardcoded secrets in CI
* Validated all download sources are from trusted origins
* Enhanced security documentation and reporting process

## [1.0.0] - 2025-11-05

### Added

* Complete Surface Pro ARM64 development machine setup
* Windows PowerShell 7 automation scripts
* WSL 2 Ubuntu configuration and toolchain installation
* Security hardening (Defender, BitLocker, Credential Guard, firewall)
* Performance optimization for 512GB storage constraints
* Dev Drive cache relocation (saves 20-50GB on C:)
* Multi-layer security scanning strategy
* Comprehensive backup configuration
* Power management automation
* Complete test coverage (Windows + Ubuntu)
* Licensed application cost analysis and alternatives

### Security

* Windows Defender with automated exclusions for dev performance
* Multi-factor authentication setup (1Password + SSH)
* Network monitoring with GlassWire
* Malware protection with Malwarebytes
* Enhanced audit logging and system protection
* BitLocker encryption with XTS-AES256
* Credential Guard with UEFI lock
* LSA Protection (RunAsPPL)
* Core Isolation (HVCI)

### Performance

* WSL 2 sparse VHD optimization
* Docker data-root moved to Dev Drive
* Package manager caches relocated
* Windows Search replaced with Everything
* Superfetch/Prefetch disabled for SSD optimization
* Network stack tuning
* Component store cleanup (WinSxS)
* Storage Sense automation

### Tools Included

* **Development**: VS Code, Docker Desktop, Git ecosystem
* **Runtimes**: Python 3.13, Node Current, Go, Rust, .NET 9, Java Temurin
* **Cloud/IaC**: AWS CLI, Azure CLI, Google Cloud SDK, Terraform, Packer
* **Security**: Snyk, Trivy, pre-commit, semgrep, detect-secrets, bandit
* **Build Tools**: Maven, Gradle, CMake, Make, mise
* **Version Managers**: nvm, pyenv, mise
* **Productivity**: GitKraken, Beyond Compare, Scrivener, Obsidian
* **Utilities**: Sysinternals, ripgrep, fd, fzf, bat, delta, chezmoi

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
