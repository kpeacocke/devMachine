# Test Suite Documentation

This directory contains comprehensive tests for the Windows development machine setup scripts.

## Test Categories

### PowerShell Tests (Pester Framework)

| Test File | Description | When to Run |
|-----------|-------------|-------------|
| `syntax-validation.Tests.ps1` | Validates PowerShell syntax and best practices | Always (critical) |
| `unattended-mode.Tests.ps1` | Tests unattended mode functionality | After script changes |
| `pester.Windows.Tests.ps1` | Tests Windows environment setup | After full setup |
| `ci-friendly.Tests.ps1` | CI/CD safe tests (skip instead of fail) | In CI/CD pipelines |
| `working-backup.Tests.ps1` | Tests backup functionality | After backup changes |
| `comprehensive-windows.Tests.ps1` | Full Windows environment validation | After major changes |
| `devdrive-features.Tests.ps1` | Dev Drive specific tests | After Dev Drive changes |
| `git-config.Tests.ps1` | Git configuration tests | After Git setup changes |
| `new-features.Tests.ps1` | Tests for new features | After adding features |
| `system-restore.Tests.ps1` | System restore point tests | After restore changes |
| `cli-tools.Tests.ps1` | CLI tools availability tests | After tool installations |
| `antivirus-optimization.Tests.ps1` | Antivirus configuration tests | After security changes |

### Bash Tests

| Test File | Description | When to Run |
|-----------|-------------|-------------|
| `ubuntu-smoke-test.sh` | Ubuntu WSL environment validation | After WSL setup |

## Prerequisites

### Required Software

* **PowerShell 7+** (pwsh.exe)

* **Pester 5.0+** module
* **WSL 2** with Ubuntu (for bash tests)

### Installation

```powershell
# Install Pester (if not already installed)
Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser

# Verify installation
Get-Module -Name Pester -MinimumVersion 5.0
```

## Running Tests

### Run All Tests

```powershell
# PowerShell (recommended)
.\tests\run-all-tests.ps1

# Windows Command Prompt
.\tests\run-tests.bat

# With verbose output
.\tests\run-all-tests.ps1 -Verbose
```

### Run Specific Test Categories

#### Syntax Validation Only (Fast)

```powershell
# Critical - run this first
Invoke-Pester -Path .\tests\syntax-validation.Tests.ps1
```

#### Unattended Mode Tests

```powershell
Invoke-Pester -Path .\tests\unattended-mode.Tests.ps1
```

#### Windows Environment Tests

```powershell
Invoke-Pester -Path .\tests\pester.Windows.Tests.ps1
```

#### Skip Windows Tests (WSL only)

```powershell
.\tests\run-all-tests.ps1 -SkipWindowsTests
```

#### Skip Ubuntu Tests (Windows only)

```powershell
.\tests\run-all-tests.ps1 -SkipUbuntuTests
```

#### Fast Mode (Skip syntax validation)

```powershell
.\tests\run-all-tests.ps1 -SkipSyntaxValidation
```

### CI/CD Usage

For continuous integration, use the CI-friendly tests that skip instead of fail:

```powershell
# In CI/CD pipelines
Invoke-Pester -Path .\tests\ci-friendly.Tests.ps1 -CI
```

## Test Results Interpretation

### Test States

* **✅ Passed**: Test completed successfully

* **❌ Failed**: Test found an issue that needs fixing
* **⏭️ Skipped**: Test was skipped (prerequisite not met, optional feature)

### Common Skip Reasons

* Component not installed (e.g., "Git not installed")

* Administrative privileges required
* Optional licensed software not present
* WSL not available

## Troubleshooting

### Pester Not Found

```powershell
# Install Pester
Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser

# Or for all users (requires admin)
Install-Module -Name Pester -MinimumVersion 5.0 -Force
```

### WSL Tests Failing

* Ensure WSL 2 is installed and Ubuntu is set as default

* Run `wsl --list --verbose` to check WSL status
* Ensure Ubuntu is fully set up with required tools

### Permission Issues

Some tests require administrative privileges:

* Run PowerShell as Administrator
* Or use `Start-Process pwsh -Verb RunAs` to elevate

### Test Timeouts

Some tests may take time for network operations:

* Increase timeout: `Invoke-Pester -Timeout 300`
* Run individual slow tests separately

## Development Workflow

### Before Committing

```powershell
# Always run syntax validation
Invoke-Pester -Path .\tests\syntax-validation.Tests.ps1

# Run unattended mode tests if scripts changed
Invoke-Pester -Path .\tests\unattended-mode.Tests.ps1
```

### After Setup Script Changes

```powershell
# Full test suite
.\tests\run-all-tests.ps1
```

### CI/CD Integration

```yaml
# Example GitHub Actions workflow
- name: Run Tests
  run: |
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
    .\tests\run-all-tests.ps1 -SkipUbuntuTests
  shell: pwsh
```

## Test Coverage

### What Gets Tested

* ✅ PowerShell script syntax validation

* ✅ Unattended mode functionality
* ✅ Windows environment configuration
* ✅ WSL Ubuntu environment setup
* ✅ Security settings and hardening
* ✅ Development tool installations
* ✅ Dev Drive configuration
* ✅ Git and SSH configuration
* ✅ Performance optimizations
* ✅ Backup and restore functionality

### Test Statistics

* **Total Test Files**: 13 PowerShell + 1 Bash

* **Estimated Runtime**: 2-5 minutes (full suite)
* **Fast Validation**: < 30 seconds (syntax only)

## Contributing

When adding new tests:

1. Follow Pester 5+ conventions
2. Use descriptive test names
3. Include proper setup/cleanup in `BeforeAll`/`AfterAll`
4. Handle optional components with `Set-ItResult -Skipped`
5. Add documentation to this README

## Environment Variables for Testing

Some tests check for unattended mode support. Set these to test different scenarios:

```powershell
# Enable unattended mode
$env:UNATTENDED_MODE = 'true'

# Provide required values
$env:GIT_USER_NAME = 'Your Name'
$env:GIT_USER_EMAIL = 'your.email@example.com'
$env:INSTALL_TYPORA = 'true'

# Run tests
.\tests\run-all-tests.ps1
```
