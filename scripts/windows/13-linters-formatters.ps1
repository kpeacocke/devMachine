<#
Installs comprehensive linting, formatting, and testing tools for all major languages.
Requires: Python (with pipx), Node.js, Go, Rust already installed.
#>
$ErrorActionPreference = 'Stop'

Write-Host "[LINTERS] Installing linters and formatters for all languages..."

# ============================================================================
# POWERSHELL
# ============================================================================
Write-Host "📘 PowerShell Linting"
try {
  # Try AllUsers first, fallback to CurrentUser if not admin
  Install-Module -Name PSScriptAnalyzer -Scope AllUsers -Force -Confirm:$false -ErrorAction Stop
  Write-Host "  ✅ PSScriptAnalyzer installed" -ForegroundColor Green
} catch {
  try {
    Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -Confirm:$false
    Write-Host "  ✅ PSScriptAnalyzer installed (current user)" -ForegroundColor Green
  } catch {
    Write-Warning "PSScriptAnalyzer installation failed: $_"
  }
}

# ============================================================================
# PYTHON
# ============================================================================
Write-Host "🐍 Python Linting & Formatting"

# Find pipx executable - could be global, in venv, or need installation
$pipxCmd = $null
$possiblePipxPaths = @(
  "pipx",                                           # Global PATH
  "$env:USERPROFILE\.local\bin\pipx.exe",          # Standard user install
  "$PWD\.venv\Scripts\pipx.exe",                   # Local venv
  "$env:USERPROFILE\AppData\Roaming\Python\Python*\Scripts\pipx.exe"  # Python user scripts
)

foreach ($path in $possiblePipxPaths) {
  if ($path -like "*`**") {
    # Handle wildcard paths
    $resolved = Get-ChildItem $path -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if ($resolved -and (Test-Path $resolved)) {
      $pipxCmd = $resolved
      break
    }
  } elseif (Get-Command $path -ErrorAction SilentlyContinue) {
    $pipxCmd = $path
    break
  }
}

if (-not $pipxCmd) {
  Write-Host "  Installing pipx first..." -ForegroundColor Yellow
  try {
    python -m pip install --user --upgrade pipx
    python -m pipx ensurepath
    # Try to find pipx again after installation
    foreach ($path in $possiblePipxPaths) {
      if (Get-Command $path -ErrorAction SilentlyContinue) {
        $pipxCmd = $path
        break
      }
    }
  } catch {
    Write-Warning "Failed to install pipx. Will use pip instead for Python tools."
    $pipxCmd = $null
  }
}

$pythonTools = @(
  "ruff",           # Modern all-in-one linter/formatter (replaces flake8, black, isort, etc.)
  "black",          # Code formatter
  "mypy",           # Static type checker
  "pylint",         # Traditional comprehensive linter
  "bandit",         # Security linter
  "pytest",         # Testing framework
  "pytest-cov",     # Coverage plugin
  "tox"             # Testing automation
)

foreach ($tool in $pythonTools) {
  try {
    Write-Host "  Installing $tool..." -NoNewline
    if ($pipxCmd) {
      & $pipxCmd install $tool --force 2>&1 | Out-Null
    } else {
      # Fallback to pip install --user if pipx is not available
      python -m pip install --user --upgrade $tool 2>&1 | Out-Null
    }
    Write-Host " ✅" -ForegroundColor Green
  } catch {
    Write-Warning "  $tool installation failed"
  }
}

# ============================================================================
# JAVASCRIPT / TYPESCRIPT / NODE
# ============================================================================
Write-Host "📦 JavaScript/TypeScript Linting & Formatting"
$npmTools = @(
  "eslint",
  "prettier",
  "@typescript-eslint/parser",
  "@typescript-eslint/eslint-plugin",
  "markdownlint-cli",
  "stylelint",
  "jshint",
  "npm-check-updates"  # Keep dependencies current
)

foreach ($tool in $npmTools) {
  try {
    Write-Host "  Installing $tool..." -NoNewline
    npm install -g $tool 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green
  } catch {
    Write-Warning "  $tool installation failed"
  }
}

# ============================================================================
# GO
# ============================================================================
Write-Host "🔵 Go Linting"
if (Get-Command go -ErrorAction SilentlyContinue) {
  try {
    Write-Host "  Installing golangci-lint..." -NoNewline
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green

    Write-Host "  Installing staticcheck..." -NoNewline
    go install honnef.co/go/tools/cmd/staticcheck@latest 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green
  } catch {
    Write-Warning "Go linter installation failed"
  }
} else {
  Write-Warning "Go not found - skipping Go linters"
}

# ============================================================================
# RUST
# ============================================================================
Write-Host "🦀 Rust Linting & Security"
if (Get-Command cargo -ErrorAction SilentlyContinue) {
  try {
    Write-Host "  Ensuring clippy is installed..." -NoNewline
    rustup component add clippy 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green

    Write-Host "  Installing cargo-audit (security)..." -NoNewline
    cargo install cargo-audit --quiet 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green

    Write-Host "  Installing cargo-outdated..." -NoNewline
    cargo install cargo-outdated --quiet 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green
  } catch {
    Write-Warning "Rust tool installation failed"
  }
} else {
  Write-Warning "Cargo not found - skipping Rust tools"
}

# ============================================================================
# SHELL / BASH
# ============================================================================
Write-Host "🐚 Shell Script Linting"
try {
  Write-Host "  Installing shellcheck..."
  winget install koalaman.shellcheck --source winget --silent --accept-package-agreements --accept-source-agreements
  Write-Host "  ✅ shellcheck installed" -ForegroundColor Green
} catch {
  Write-Warning "shellcheck installation failed"
}

# ============================================================================
# DOCKER / YAML / MISC
# ============================================================================
Write-Host "🐳 Docker, YAML, and Config Linting"

# Hadolint (Dockerfile linter)
try {
  Write-Host "  Installing hadolint (Dockerfile)..."
  winget install Hadolint.Hadolint --source winget --silent --accept-package-agreements --accept-source-agreements
  Write-Host "  ✅ hadolint installed" -ForegroundColor Green
} catch {
  Write-Warning "hadolint installation failed"
}

# yamllint
try {
  Write-Host "  Installing yamllint..." -NoNewline
  if ($pipxCmd) {
    & $pipxCmd install yamllint --force 2>&1 | Out-Null
  } else {
    python -m pip install --user --upgrade yamllint 2>&1 | Out-Null
  }
  Write-Host " ✅" -ForegroundColor Green
} catch {
  Write-Warning "  yamllint installation failed"
}

# actionlint (GitHub Actions)
if (Get-Command go -ErrorAction SilentlyContinue) {
  try {
    Write-Host "  Installing actionlint (GitHub Actions)..." -NoNewline
    go install github.com/rhysd/actionlint/cmd/actionlint@latest 2>&1 | Out-Null
    Write-Host " ✅" -ForegroundColor Green
  } catch {
    Write-Warning "  actionlint installation failed"
  }
}

# ============================================================================
# JSON / TOML / EDITORCONFIG
# ============================================================================
Write-Host "📄 Config File Linting"
try {
  Write-Host "  Installing jsonlint..." -NoNewline
  npm install -g jsonlint 2>&1 | Out-Null
  Write-Host " ✅" -ForegroundColor Green

  Write-Host "  Installing taplo (TOML)..." -NoNewline
  cargo install taplo-cli --quiet 2>&1 | Out-Null
  Write-Host " ✅" -ForegroundColor Green
} catch {
  Write-Warning "Config linter installation failed"
}

# ============================================================================
# SECURITY / PRE-COMMIT
# ============================================================================
Write-Host "🔒 Security and Git Hooks"
$securityTools = @(
  "pre-commit",      # Git hook framework
  "detect-secrets",  # Prevent secrets in commits
  "semgrep"          # Static analysis security scanner
)

foreach ($tool in $securityTools) {
  try {
    Write-Host "  Installing $tool..." -NoNewline
    if ($pipxCmd) {
      & $pipxCmd install $tool --force 2>&1 | Out-Null
    } else {
      python -m pip install --user --upgrade $tool 2>&1 | Out-Null
    }
    Write-Host " ✅" -ForegroundColor Green
  } catch {
    Write-Warning "  $tool installation failed"
  }
}

# ============================================================================
# PATH REFRESH
# ============================================================================
Write-Host "♻️ Refreshing PATH environment..."
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + `
            [System.Environment]::GetEnvironmentVariable("Path","User")

# Ensure Go bin is in PATH
$gobin = "$env:USERPROFILE\go\bin"
if ((Test-Path $gobin) -and ($env:PATH -notlike "*$gobin*")) {
  [Environment]::SetEnvironmentVariable('Path', $env:Path + ";$gobin", 'User')
  Write-Host "  Added Go bin to PATH" -ForegroundColor Yellow
}

# Ensure pipx bin is in PATH
$pipxbin = "$env:USERPROFILE\.local\bin"
if ((Test-Path $pipxbin) -and ($env:PATH -notlike "*$pipxbin*")) {
  [Environment]::SetEnvironmentVariable('Path', $env:Path + ";$pipxbin", 'User')
  Write-Host "  Added pipx bin to PATH" -ForegroundColor Yellow
}

Write-Host "[OK] Linters and formatters installed!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ PowerShell:  PSScriptAnalyzer" -ForegroundColor Green
Write-Host "✅ Python:      ruff, black, mypy, pylint, bandit, pytest" -ForegroundColor Green
Write-Host "✅ JavaScript:  eslint, prettier, markdownlint" -ForegroundColor Green
Write-Host "✅ Go:          golangci-lint, staticcheck" -ForegroundColor Green
Write-Host "✅ Rust:        clippy, cargo-audit, cargo-outdated" -ForegroundColor Green
Write-Host "✅ Shell:       shellcheck" -ForegroundColor Green
Write-Host "✅ Docker:      hadolint" -ForegroundColor Green
Write-Host "✅ YAML:        yamllint" -ForegroundColor Green
Write-Host "✅ GitHub:      actionlint" -ForegroundColor Green
Write-Host "✅ Security:    pre-commit, detect-secrets, semgrep" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "💡 Restart your terminal to ensure all tools are in PATH" -ForegroundColor Yellow
