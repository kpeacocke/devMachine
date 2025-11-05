# Commit Message Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning and changelog generation.

## Format

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Types

### Version Bump Types

| Type | Description | Version Bump | Example |
|------|-------------|--------------|---------|
| `feat` | New feature | **MINOR** (0.x.0) | `feat: add GlassWire installation` |
| `fix` | Bug fix | **PATCH** (0.0.x) | `fix: correct PowerShell syntax error` |
| `perf` | Performance improvement | **PATCH** | `perf: optimize Dev Drive cache relocation` |
| `docs` | Documentation only | **PATCH** | `docs: update README with license costs` |
| `refactor` | Code refactoring | **PATCH** | `refactor: simplify error handling` |
| `build` | Build system changes | **PATCH** | `build: update Pester to v5.6` |

### Breaking Changes (MAJOR)

Any commit with `BREAKING CHANGE:` in the footer or `!` after the type will trigger a **MAJOR** version bump (x.0.0):

```text
feat!: remove Windows 10 support

BREAKING CHANGE: Windows 11 is now required
```

### Non-Versioning Types

These types do NOT trigger releases:

| Type | Description | Example |
|------|-------------|---------|
| `style` | Code style/formatting | `style: fix indentation` |
| `test` | Adding/updating tests | `test: add shellcheck validation` |
| `ci` | CI/CD configuration | `ci: add release workflow` |
| `chore` | Maintenance tasks | `chore: update .gitignore` |

## Scopes (Optional)

Use scopes to specify what part of the project is affected:

* `windows` - Windows scripts
* `wsl` - WSL/Ubuntu scripts
* `security` - Security features
* `performance` - Performance optimizations
* `docs` - Documentation
* `tests` - Test files
* `ci` - CI/CD workflows

**Examples:**

```text
feat(windows): add Malwarebytes installation
fix(wsl): correct pyenv initialization script
perf(windows): optimize Defender exclusions
docs(readme): add installation instructions
```

## Examples

### Feature Addition (MINOR bump)

```git-commit
feat(windows): add automatic Defender exclusions

* Exclude Dev Drive caches from scanning
* Exclude package manager folders
* Improve build performance by 40%
```

### Bug Fix (PATCH bump)

```git-commit
fix(windows): escape ampersands in PowerShell strings

Fixes syntax errors when running setup-machine.ps1
```

### Breaking Change (MAJOR bump)

```git-commit
feat(windows)!: require PowerShell 7.4 or higher

BREAKING CHANGE: PowerShell 5.1 is no longer supported.
Users must upgrade to PowerShell 7.4+ before running scripts.
```

### Documentation (PATCH bump)

```git-commit
docs: add contribution guidelines and code of conduct
```

### Non-versioning Commit

```git-commit
ci: add automated release workflow

This change doesn't affect the scripts themselves,
so it won't trigger a new release.
```

## How It Works

1. **Push commits** to `main` branch following the convention
2. **GitHub Actions** analyzes commit messages
3. **Semantic-release** determines version bump:
   * `BREAKING CHANGE` or `!` → **v2.0.0** (MAJOR)
   * `feat` → **v1.1.0** (MINOR)
   * `fix`, `perf`, `docs`, `refactor`, `build` → **v1.0.1** (PATCH)
4. **CHANGELOG.md** is automatically updated
5. **GitHub Release** is created with release notes
6. **Release artifacts** (ZIP files) are uploaded

## Best Practices

### ✅ Good Commits

```text
feat(windows): add licensed apps separation for VM setups
fix(wsl): correct Ubuntu package installation order
perf(windows): reduce storage usage by 33-77GB
docs: document all license costs and free alternatives
refactor(windows): simplify backup configuration logic
```

### ❌ Bad Commits

```text
updated stuff
fix things
WIP
asdf
Fixed bug
```

## Manual Release

To manually trigger a release:

```bash
# In GitHub Actions UI
Actions → Release → Run workflow → Select release type
```

## Version History

* **MAJOR** (1.0.0 → 2.0.0): Breaking changes, removed features, incompatible API changes
* **MINOR** (1.0.0 → 1.1.0): New features, backwards-compatible additions
* **PATCH** (1.0.0 → 1.0.1): Bug fixes, documentation, performance improvements

## Resources

* [Conventional Commits Specification](https://www.conventionalcommits.org/)
* [Semantic Versioning](https://semver.org/)
* [Keep a Changelog](https://keepachangelog.com/)
