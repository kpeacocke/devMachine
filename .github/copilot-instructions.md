# GitHub Copilot Instructions

## Project Overview

This repository contains automation scripts for setting up a complete Windows development machine with WSL 2 Ubuntu
integration. The project focuses on security, performance optimization, and developer productivity.

## Code Generation Guidelines

### PowerShell Scripts

* Use PowerShell 7+ syntax and features
* Always include proper error handling with `$ErrorActionPreference = 'Stop'`
* Use `Write-Host` with color coding for user-facing messages
* Implement `-WhatIf` support for destructive operations
* Follow verb-noun naming convention for functions
* Include comment-based help for all functions
* Use approved PowerShell verbs (Get, Set, New, Remove, etc.)
* Prefer `Join-Path` over string concatenation for paths
* Use parameter validation attributes (`[ValidateNotNullOrEmpty()]`, etc.)

### Bash Scripts

* Use shebang with /usr/bin/env bash
* Always include `set -euo pipefail` for error handling
* Use `command -v` to check for required tools
* Prefer `[[` over `[` for conditionals
* Use lowercase for local variables, UPPERCASE for environment variables
* Quote all variable expansions: `"$variable"`
* Use functions for code organization
* Include usage information and examples

### General Code Standards

* Follow the conventional commits specification for all changes
* Ensure all scripts are cross-platform compatible where applicable
* Add comprehensive tests for new functionality
* Update documentation (README.md, CHANGELOG.md) for user-facing changes
* Use semantic versioning for releases

## Security Requirements

* Never hardcode credentials, API keys, or sensitive data
* Always validate user input and sanitize file paths
* Use HTTPS for all downloads and API calls
* Implement proper permission checks before system modifications
* Document security implications in commit messages

## Testing Standards

* Write Pester 5+ tests for PowerShell code
* Include syntax validation tests for all scripts
* Test both success and failure scenarios
* Verify error handling and edge cases
* Run `syntax-validation.Tests.ps1` before committing
* Ensure tests are idempotent and don't require admin privileges in CI

## Architecture Patterns

### Script Organization

* Phase-based execution (numbered prefixes: 00-, 10-, 20-, etc.)
* Separate licensed/commercial apps from free tools
* Support skip flags for optional components
* Implement doctor/validation scripts for environment verification

### Error Handling

* Use try-catch-finally blocks for critical operations
* Log errors with context (file, line, operation)
* Provide actionable error messages to users
* Implement retry logic for network operations
* Clean up partial state on failure

### User Experience

* Show progress indicators for long-running operations
* Provide clear success/failure messages with color coding
* Offer dry-run mode (`-WhatIf`) for preview
* Include examples in help text and README
* Minimize required user input with smart defaults

## Repository Conventions

### File Structure

* `scripts/windows/` - PowerShell automation for Windows
* `scripts/wsl/` - Bash scripts for WSL 2 Ubuntu
* `tests/` - Pester and bash test suites
* `.github/workflows/` - CI/CD pipelines
* `.github/instructions/` - Copilot-specific guidance

### Naming Conventions

* Scripts: `NN-description.ps1` or `NN-description.sh`
* Tests: `*.Tests.ps1` or `*-test.sh`
* Workflows: `kebab-case.yml`
* Functions: `Verb-Noun` (PowerShell), `snake_case` (bash)

### Commit Messages

Follow conventional commits:

* `feat:` - New features
* `fix:` - Bug fixes
* `docs:` - Documentation changes
* `test:` - Test additions/updates
* `refactor:` - Code refactoring
* `perf:` - Performance improvements
* `build:` - Build system changes
* `ci:` - CI/CD changes
* `chore:` - Maintenance tasks

Include scope in parentheses: `feat(setup): add Dev Drive skip option`

## Common Tasks

### Adding a New Script

1. Create script with appropriate phase number prefix
2. Add comprehensive error handling
3. Write corresponding Pester/bash tests
4. Update main orchestrator (`setup-machine.ps1`) if needed
5. Document in README.md with usage examples
6. Commit with conventional commit message

### Modifying Existing Scripts

1. Review existing tests and update as needed
2. Maintain backward compatibility or document breaking changes
3. Run syntax validation tests
4. Update CHANGELOG.md if user-facing
5. Test in clean environment (VM recommended)

### Working with Workflows

1. Test workflow changes in feature branch
2. Use workflow_dispatch for manual testing
3. Ensure proper job dependencies (`needs:`)
4. Add appropriate permissions (least privilege)
5. Validate YAML syntax before committing

## Performance Considerations

* Minimize disk I/O operations
* Cache package manager downloads when possible
* Parallelize independent operations
* Use sparse VHD for WSL 2
* Relocate caches to Dev Drive (ReFS) when available
* Disable unnecessary Windows services
* Optimize network stack settings

## Documentation Standards

* Keep README.md current with all features
* Document all parameters and switches
* Include cost information for paid tools
* Provide troubleshooting guidance
* Add examples for common use cases
* Update CHANGELOG.md for releases (automated via semantic-release)

## Tools and Technologies

* **Languages**: PowerShell 7+, Bash 5+
* **Testing**: Pester 5+, shellcheck, markdownlint
* **Security**: PSScriptAnalyzer, GitHub Advanced Security
* **CI/CD**: GitHub Actions with semantic-release
* **Package Managers**: winget, chocolatey, apt, npm, pip
* **Version Control**: Git with conventional commits

## AI Assistant Behavior

* Validate syntax before suggesting changes
* Consider cross-platform compatibility
* Prefer existing utilities over reinventing
* Ask for clarification on ambiguous requirements
* Suggest tests alongside implementation
* Reference existing patterns in codebase
* Maintain consistent code style with project
