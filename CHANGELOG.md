## [1.8.1](https://github.com/kpeacocke/devMachine/compare/v1.8.0...v1.8.1) (2025-11-12)


### 🐛 Bug Fixes

* **10-windows-bootstrap.ps1:** update Ubuntu installation command to use default version and improve user instructions ([bb121c3](https://github.com/kpeacocke/devMachine/commit/bb121c375d30502b81daa73a134b90a047a92230))


### ♻️ Code Refactoring

* **doctor-ubuntu.sh:** improve readability by restructuring conditional checks for tool availability ([bdaee0b](https://github.com/kpeacocke/devMachine/commit/bdaee0bcc5afc18bf65bde17814b9fb83be0e6df))

## [1.8.0](https://github.com/kpeacocke/devMachine/compare/v1.7.0...v1.8.0) (2025-11-12)


### 🚀 Features

* configure VS Code terminal font settings for improved appearance ([b20b33f](https://github.com/kpeacocke/devMachine/commit/b20b33f9ffc570f4e6adbf7ef71fde85696e2687))
* enhance Dev Drive cache configuration with additional package managers and improved error handling ([109d217](https://github.com/kpeacocke/devMachine/commit/109d217c3aceac2290972a0adb539b98c9e8dd73))
* enhance PowerShell profile and bootstrap scripts for improved console configuration and PATH management ([8e33a52](https://github.com/kpeacocke/devMachine/commit/8e33a5247bf9ad6203a940dcda073f7855a29a98))
* update scripts and documentation for improved VS Code Insiders installation and OneDrive handling ([698496c](https://github.com/kpeacocke/devMachine/commit/698496cab0ac2d941eddd6f1ece4babdb06c35cd))
* update settings and scripts for improved tooling and SSL/TLS hardening ([17d07f5](https://github.com/kpeacocke/devMachine/commit/17d07f543336034886cfe1fecb84076396ee0138))

## [1.7.0](https://github.com/kpeacocke/devMachine/compare/v1.6.1...v1.7.0) (2025-11-07)


### 🚀 Features

* enhance Snyk rules documentation and update DoH configuration script for improved security and compatibility ([4cf23fd](https://github.com/kpeacocke/devMachine/commit/4cf23fd5059343de37f0b0f947d31328622423f9))

## [1.6.1](https://github.com/kpeacocke/devMachine/compare/v1.6.0...v1.6.1) (2025-11-06)


### 🐛 Bug Fixes

* update privacy and services scripts to leave location services enabled for user convenience ([44c4328](https://github.com/kpeacocke/devMachine/commit/44c4328621a551d3263a61ed2781a66721ca458b))

## [1.6.0](https://github.com/kpeacocke/devMachine/compare/v1.5.0...v1.6.0) (2025-11-06)


### 🚀 Features

* implement SSL/TLS hardening script and integrate into setup process ([71a907a](https://github.com/kpeacocke/devMachine/commit/71a907a4b351665484ac83858bd08ca54bfc7438))


### 🐛 Bug Fixes

* correct formatting and spacing in ReFS minimum size requirements ([65b04e1](https://github.com/kpeacocke/devMachine/commit/65b04e1dc8b4eca88b9168049fabf0d34ab56d86))
* improve logic for calculating shrinkable disk space in partition setup script ([fbc8902](https://github.com/kpeacocke/devMachine/commit/fbc8902f959b6119ed9cc00946848e5e464e92ec))

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Note**: From v1.1.0 onwards, this changelog is automatically generated using
> [semantic-release](https://semantic-release.gitbook.io/) based on
> [Conventional Commits](https://www.conventionalcommits.org/).
> See [COMMIT_CONVENTION.md](.github/COMMIT_CONVENTION.md) for commit message guidelines.

## [1.5.0](https://github.com/kpeacocke/devMachine/compare/v1.4.0...v1.5.0) (2025-11-06)

### 🚀 Features

* **partition:** improve C: drive shrinking logic and handle unallocated space creation ([959124d](https://github.com/kpeacocke/devMachine/commit/959124d1f05a02ac8d36ad52067a500c630d747f))
* **setup:** add InstallEverything parameter for complete unattended installation ([4b92500](https://github.com/kpeacocke/devMachine/commit/4b925006b89a474c294530b92fb71c9bfc6a7dfe))

### 🐛 Bug Fixes

* **apps:** remove unnecessary blank line before fallback installation for Malwarebytes ([b6102da](https://github.com/kpeacocke/devMachine/commit/b6102da8417888b0eb5f1db1d60ed1926d6137f4))

### 📚 Documentation

* **readme:** enhance unattended installation instructions and clarify default behaviors ([24b005a](https://github.com/kpeacocke/devMachine/commit/24b005a22394c6302e3194362d81fa51d010a8be))
> [Conventional Commits](https://www.conventionalcommits.org/).
> See [COMMIT_CONVENTION.md](.github/COMMIT_CONVENTION.md) for commit message guidelines.

## [1.4.0](https://github.com/kpeacocke/devMachine/compare/v1.3.0...v1.4.0) (2025-11-06)

### 🚀 Features

* **apps:** enhance installation script for Malwarebytes and add Zoom and Google Meet ([7d6d62c](https://github.com/kpeacocke/devMachine/commit/7d6d62ce1857315bead23e40c7a378cc5d0e91f6))

## [1.3.0](https://github.com/kpeacocke/devMachine/compare/v1.2.0...v1.3.0) (2025-11-06)

### 🚀 Features

* **changelog:** update changelog title and cleanup duplicates in release workflow ([5d82617](https://github.com/kpeacocke/devMachine/commit/5d82617c3819d19d0a39730bff59970bfdb68c51))
* **settings:** add new words to cSpell dictionary for improved spell checking ([7ef0ff2](https://github.com/kpeacocke/devMachine/commit/7ef0ff2a9b133440e2ed7cb05bfd18e82f832a54))

## [1.2.0](https://github.com/kpeacocke/devMachine/compare/v1.1.0...v1.2.0) (2025-11-06)

### 🚀 Features

* **security:** update firewall script to reflect early hardening phase and remove redundant checks ([e2cbfd8](https://github.com/kpeacocke/devMachine/commit/e2cbfd885a7d81173c256d75ffdf8a320d5dc079))
* **setup:** add early security hardening phase to setup process and update related scripts ([4f40bca](https://github.com/kpeacocke/devMachine/commit/4f40bcafcd4aad67e8af90bcbd29c088c179532e))

## [1.1.0](https://github.com/kpeacocke/devMachine/compare/v1.0.2...v1.1.0) (2025-11-06)

### 🚀 Features

* Add scripts for Windows Terminal configuration, privacy hardening, DNS security, and service optimization ([8e7811c](https://github.com/kpeacocke/devMachine/commit/8e7811c4c18a4fda99e9aa95abf3c30cbb480698))
* **setup:** add optional phase for social media and streaming app installation ([da6214c](https://github.com/kpeacocke/devMachine/commit/da6214c2ba9875d51e5907567154919e3433f9c2))
* **setup:** add optional Windows debloat phase to setup script and create debloat script ([0a2d4fe](https://github.com/kpeacocke/devMachine/commit/0a2d4fe27f096957d211dcc86478a0be471a422e))
* **setup:** add script for installing social media and streaming apps from Microsoft Store ([046f81b](https://github.com/kpeacocke/devMachine/commit/046f81bdd92c1bde63afe9fc3446664af78f2c00))
* **setup:** update README and scripts for Pester 5 installation and licensed apps management ([20e9597](https://github.com/kpeacocke/devMachine/commit/20e9597080f5081b2abca3424053d7a3fec33e5d))
* **setup:** update setup order and scripts for Windows debloat, Git configuration, and media installations ([9433873](https://github.com/kpeacocke/devMachine/commit/94338733574d352ef1a4e124f96a2f22d2ac68d4))

## [1.0.2](https://github.com/kpeacocke/devMachine/compare/v1.0.1...v1.0.2) (2025-11-05)

### 📚 Documentation

* **readme:** expand Quick Start with one-line install, VM example, manual download and setup phases ([e1547b7](https://github.com/kpeacocke/devMachine/commit/e1547b7afe427d9e79129a8d93213e8110e40ca9))

## [1.0.1](https://github.com/kpeacocke/devMachine/compare/v1.0.0...v1.0.1) (2025-11-05)

### 📚 Documentation

* normalize line wrapping in CODE_OF_CONDUCT.md and tidy CHANGELOG spacing ([7b68639](https://github.com/kpeacocke/devMachine/commit/7b6863950b6b6bb0c29fc91d09edea42c1fa6793))
* normalize list markers to asterisks and standardize fenced code blocks across repository docs ([a062349](https://github.com/kpeacocke/devMachine/commit/a0623499118c4ff714170a23feb2f45d2152fae0))

## [1.0.0](https://github.com/kpeacocke/devMachine/compare/ac90f01...v1.0.0) (2025-11-05)

### 🚀 Features

* **repo:** add GitHub workflows, templates, docs, license and split licensed apps ([ac90f01](https://github.com/kpeacocke/devMachine/commit/ac90f01fcac86b5214e33833c20c4d7016676b83))
* **setup:** add -SkipDevDrive switch and guard Dev Drive phase; update README with VM note and examples ([0ab6277](https://github.com/kpeacocke/devMachine/commit/0ab62778ea6d1827f0d0f999a8d735663c25428c))

### 🎯 Initial Release

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
