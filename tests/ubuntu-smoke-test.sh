#!/usr/bin/env bash
set -e

echo "🧪 Ubuntu WSL Smoke Tests"

# Core build tools
for c in gcc g++ make cmake pkg-config; do
  command -v "$c" >/dev/null || { echo "❌ MISSING: $c"; exit 1; }
  echo "✅ $c"
done

# Version managers and runtimes
for c in nvm node npm pyenv python3 pip3 java javac kotlin gradle sbt go cargo rustc; do
  command -v "$c" >/dev/null || { echo "❌ MISSING: $c"; exit 1; }
  echo "✅ $c"
done

# Mise
command -v mise >/dev/null || { echo "❌ MISSING: mise"; exit 1; }
echo "✅ mise"

# R, PHP, Ruby
for c in R php composer ruby bundle rubocop; do
  command -v "$c" >/dev/null || { echo "❌ MISSING: $c"; exit 1; }
  echo "✅ $c"
done

# Linters and tools
for c in shellcheck tflint git gh docker; do
  command -v "$c" >/dev/null || { echo "❌ MISSING: $c"; exit 1; }
  echo "✅ $c"
done

# Node global tools
for c in eslint prettier markdownlint stylelint tsc; do
  command -v "$c" >/dev/null || { echo "⚠️  WARNING: $c not found (may need 'npm install -g')"; }
done

# PHP tools
for c in phpcs phpstan psalm php-cs-fixer; do
  command -v "$c" >/dev/null || { echo "⚠️  WARNING: $c not found (may need 'composer global require')"; }
done

# Python security tools (pipx)
for c in pre-commit semgrep detect-secrets bandit; do
  command -v "$c" >/dev/null || { echo "⚠️  WARNING: $c not found (may need 'pipx install')"; }
done

# Docker connectivity
if docker info >/dev/null 2>&1; then
  echo "✅ Docker daemon reachable (WSL integration working)"
else
  echo "❌ Docker daemon not reachable - enable WSL integration in Docker Desktop"
  exit 1
fi

# R packages
if R -q -e "library(languageserver);library(lintr);library(styler)" >/dev/null 2>&1; then
  echo "✅ R packages (languageserver, lintr, styler)"
else
  echo "⚠️  WARNING: R packages missing"
fi

# Check composer global bin on PATH
if [[ ":$PATH:" == *":$HOME/.config/composer/vendor/bin:"* ]]; then
  echo "✅ Composer global bin on PATH"
else
  echo "⚠️  WARNING: Composer global bin NOT on PATH"
fi

# pyenv check
if [ -d "$HOME/.pyenv" ]; then
  echo "✅ pyenv directory exists"
else
  echo "⚠️  WARNING: pyenv not installed"
fi

# mkcert
if command -v mkcert >/dev/null; then
  echo "✅ mkcert (dev TLS)"
else
  echo "⚠️  WARNING: mkcert not found"
fi

echo ""
echo "✅ Ubuntu WSL smoke tests PASSED"

