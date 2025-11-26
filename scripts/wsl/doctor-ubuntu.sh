#!/usr/bin/env bash
set -euo pipefail

ok(){ printf "\e[32m[✓]\e[0m %s\n" "$*"; }
bad(){ printf "\e[31m[✗]\e[0m %s\n" "$*"; }
inf(){ printf "\e[36m[i]\e[0m %s\n" "$*"; }
warn(){ printf "\e[33m[!]\e[0m %s\n" "$*"; }

echo ""
inf "🏥 Dev Environment Doctor — Ubuntu (WSL)"
echo ""

need() { command -v "$1" >/dev/null 2>&1; }

ERRORS=0

# Build tools
inf "Build Tools:"
for c in gcc g++ make cmake pkg-config ninja; do
  if need "$c"; then
    ok "$c found"
  else
    bad "$c missing"
    ERRORS=$((ERRORS + 1))
  fi
done

# Rust
echo ""
inf "Rust:"
if need cargo && need rustc; then
  RUST_VERSION=$(rustc --version | cut -d' ' -f2)
  ok "Rust $RUST_VERSION found"
else
  bad "Rust missing - run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  ERRORS=$((ERRORS + 1))
fi

# Go
echo ""
inf "Go:"
if need go; then
  GO_VERSION=$(go version | awk '{print $3}')
  ok "Go $GO_VERSION found"
else
  bad "Go missing - install from https://go.dev/dl/"
  ERRORS=$((ERRORS + 1))
fi

# R
echo ""
inf "R:"
if need R; then
  R_VERSION=$(R --version | head -n1 | awk '{print $3}')
  ok "R $R_VERSION found"
  if R -q -e "library(languageserver);library(lintr);library(styler)" >/dev/null 2>&1; then
    ok "R packages: languageserver/lintr/styler"
  else
    bad "R packages missing"
    warn "Fix: R -e \"install.packages(c('languageserver','lintr','styler'), repos='https://cloud.r-project.org')\""
    ERRORS=$((ERRORS + 1))
  fi
else
  bad "R missing - install: sudo apt-get install -y r-base r-base-dev"
  ERRORS=$((ERRORS + 1))
fi

# PHP
echo ""
inf "PHP:"
if need php; then
  PHP_VERSION=$(php -v | head -n1 | awk '{print $2}')
  ok "PHP $PHP_VERSION found"
else
  bad "PHP missing - install: sudo apt-get install -y php php-cli"
  ERRORS=$((ERRORS + 1))
fi

if need composer; then
  COMPOSER_VERSION=$(composer --version 2>/dev/null | awk '{print $3}')
  ok "Composer $COMPOSER_VERSION found"

  PATHS="$HOME/.config/composer/vendor/bin"
  if [[ ":$PATH:" == *":$PATHS:"* ]]; then
    ok "Composer global bin on PATH"
  else
    bad "Composer global bin NOT on PATH"
    warn "Fix: Add to ~/.bashrc: export PATH=\"\$HOME/.config/composer/vendor/bin:\$PATH\""
    ERRORS=$((ERRORS + 1))
  fi

  for t in phpcs phpstan psalm php-cs-fixer; do
    if command -v "$t" >/dev/null 2>&1; then
      ok "$t found"
    else
      bad "$t missing"
      ERRORS=$((ERRORS + 1))
    fi
  done
else
  bad "Composer missing - run 20-ubuntu-bootstrap.sh"
  ERRORS=$((ERRORS + 1))
fi

# Ruby
echo ""
inf "Ruby:"
if need ruby; then
  RUBY_VERSION=$(ruby -v | awk '{print $2}')
  ok "Ruby $RUBY_VERSION found"
else
  bad "Ruby missing - install: sudo apt-get install -y ruby-full"
  ERRORS=$((ERRORS + 1))
fi

for g in bundler rubocop; do
  if need "$g"; then
    ok "$g found"
  else
    bad "$g missing - install: gem install $g --no-document"
    ERRORS=$((ERRORS + 1))
  fi
done

# Node.js
echo ""
inf "Node.js:"
if need node && need npm; then
  NODE_VERSION=$(node --version)
  NPM_VERSION=$(npm --version)
  ok "Node $NODE_VERSION and npm $NPM_VERSION found"
else
  bad "Node/npm missing - install nvm and run: nvm install node"
  ERRORS=$((ERRORS + 1))
fi

for n in eslint prettier markdownlint stylelint tsc; do
  if need "$n"; then
    ok "$n found"
  else
    bad "$n missing - install: npm install -g $n"
    ERRORS=$((ERRORS + 1))
  fi
done

# Docker
echo ""
inf "Docker:"
if need docker; then
  if docker info >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    ok "Docker $DOCKER_VERSION works (WSL integration)"
  else
    bad "Docker CLI cannot reach daemon"
    warn "Fix: Enable WSL integration in Docker Desktop settings"
    ERRORS=$((ERRORS + 1))
  fi
else
  bad "Docker missing - install: sudo apt-get install -y docker.io"
  ERRORS=$((ERRORS + 1))
fi

# Additional tools
echo ""
inf "Additional Tools:"
if need tflint; then
  ok "tflint found"
else
  bad "tflint missing - install: pipx install tflint"
  ERRORS=$((ERRORS + 1))
fi

if need shellcheck; then
  ok "shellcheck found"
else
  bad "shellcheck missing - install: sudo apt-get install -y shellcheck"
  ERRORS=$((ERRORS + 1))
fi

if need mise; then
  ok "mise found"
else
  bad "mise missing - run 20-ubuntu-bootstrap.sh"
  ERRORS=$((ERRORS + 1))
fi

if need pyenv; then
  ok "pyenv found"
else
  bad "pyenv missing - run 20-ubuntu-bootstrap.sh"
  ERRORS=$((ERRORS + 1))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ]; then
  ok "✅ All checks passed! Environment is ready."
else
  bad "❌ Found $ERRORS issue(s) - see suggestions above"
  echo ""
  warn "Run './scripts/wsl/20-ubuntu-bootstrap.sh' to install missing tools"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit $ERRORS
