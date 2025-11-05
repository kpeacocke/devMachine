# Contributing to devMachine

Thank you for your interest in contributing to this Surface Pro development machine setup project!

## Ways to Contribute

### 🐛 Bug Reports

* Use the GitHub issue tracker
* Include your Windows version and hardware details
* Provide clear reproduction steps
* Include error messages and logs

### 💡 Feature Requests

* Check existing issues first
* Describe the use case and expected behavior
* Consider if it fits the project scope (Surface Pro dev machines)

### 🔧 Code Contributions

* Fork the repository
* Create a feature branch following naming convention: `feat/feature-name`, `fix/bug-name`
* Follow [Conventional Commits](.github/COMMIT_CONVENTION.md) for all commit messages
* Test your changes thoroughly
* Submit a pull request

## Development Setup

### Prerequisites

* Windows 11 on ARM (or VM with nested virtualization)
* PowerShell 7+
* WSL 2 with Ubuntu
* Git

### Commit Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning and changelog generation.

**Format**: `<type>[optional scope]: <description>`

**Common types**:

* `feat`: New feature (MINOR version bump)
* `fix`: Bug fix (PATCH version bump)
* `docs`: Documentation changes (PATCH version bump)
* `perf`: Performance improvement (PATCH version bump)
* `refactor`: Code refactoring (PATCH version bump)
* `test`: Adding tests (no version bump)
* `ci`: CI/CD changes (no version bump)

**Examples**:

```bash
git commit -m "feat(windows): add GlassWire installation"
git commit -m "fix(wsl): correct pyenv initialization"
git commit -m "docs: update README with license costs"
git commit -m "perf(windows): optimize Defender exclusions"
```

See [COMMIT_CONVENTION.md](.github/COMMIT_CONVENTION.md) for complete details.

### Testing Your Changes

1. **Syntax Validation**

   ```powershell
   pwsh -File .\tests\syntax-validation.Tests.ps1
   ```

2. **Windows Tests**

   ```powershell
   pwsh -File .\tests\pester.Windows.Tests.ps1
   ```

3. **Ubuntu Tests**:

   ```bash
   wsl -d Ubuntu -e bash ./tests/ubuntu-smoke-test.sh
   ```

4. **Full Integration Test**:

   ```powershell
   # In a VM (recommended)
   .\setup-machine.ps1 -SkipLicensedApps
   ```

### Code Standards

#### PowerShell

* Follow PowerShell best practices
* Use approved verbs (`Get-Verb`)
* Include error handling (`try/catch`, `$ErrorActionPreference`)
* Add parameter validation
* Use consistent formatting

#### Bash

* Follow bash best practices
* Use `set -euo pipefail` for error handling
* Quote variables properly
* Use shellcheck for linting

#### Documentation

* Update README.md for new features
* Include inline comments for complex logic
* Update license cost information when adding paid tools
* Document any breaking changes

## Pull Request Process

1. **Fork and Branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**
   * Keep commits focused and atomic
   * Write clear commit messages
   * Test thoroughly

3. **Run Tests**

   ```powershell
   # Syntax validation
   pwsh -File .\tests\syntax-validation.Tests.ps1
   
   # Windows tests (if applicable)
   pwsh -File .\tests\pester.Windows.Tests.ps1
   ```

4. **Update Documentation**
   * Update README.md if needed
   * Update license costs if adding paid software
   * Add or update tests

5. **Submit Pull Request**
   * Clear title and description
   * Reference any related issues
   * Include testing details

## Project Structure

```text
devMachine/
├── scripts/
│   ├── windows/          # Windows PowerShell scripts
│   └── wsl/             # WSL/Ubuntu bash scripts
├── tests/               # Test files
├── .github/            # GitHub configuration
├── README.md           # Main documentation
├── setup-machine.ps1   # Main orchestrator
└── LICENSE            # MIT License
```

## Contribution Guidelines

### Adding New Software

1. **Justify the addition**: Does it serve Surface Pro developers?
2. **Use official sources**: Prefer winget/apt packages
3. **Consider licensing**: Note if paid/licensed
4. **Add tests**: Include in appropriate test files
5. **Update docs**: Add to README.md tool lists

### Security Considerations

* All software should come from trusted sources
* Avoid modifying security settings without justification
* Test security changes thoroughly
* Document any security implications

### Performance Impact

* Consider 512GB storage constraints
* Prefer Dev Drive for caches when possible
* Avoid unnecessary background services
* Test on actual Surface Pro hardware when possible

## Code Review Criteria

### ✅ Good PR Checklist

* [ ] Passes all syntax validation tests
* [ ] Includes appropriate error handling
* [ ] Updates documentation
* [ ] Follows existing code patterns
* [ ] Includes tests for new functionality
* [ ] Considers storage/performance impact

### ❌ Common Issues

* Hardcoded paths that won't work across systems
* Missing error handling
* Unicode characters in PowerShell strings
* Unescaped ampersands in PowerShell strings
* Adding software without justification
* Breaking changes without documentation

## Getting Help

* **Questions**: Open a GitHub discussion
* **Bugs**: Use the issue tracker
* **Security Issues**: See SECURITY.md
* **Feature Ideas**: Open an issue first to discuss

## Recognition

Contributors will be recognized in the README.md file. Significant contributions may earn maintainer status.

Thank you for helping make Surface Pro development setup better for everyone! 🚀
