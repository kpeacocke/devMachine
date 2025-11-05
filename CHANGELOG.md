# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
