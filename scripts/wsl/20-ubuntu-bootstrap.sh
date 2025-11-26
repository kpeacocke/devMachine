#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Ubuntu Bootstrap - Development Environment Setup"
echo ""

# Core build tools and utilities
echo "📦 Installing core build tools..."
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y build-essential pkg-config cmake ninja-build curl wget git \
  ca-certificates jq ripgrep unzip zip gnupg lsb-release apt-transport-https

# Java (Temurin - latest LTS)
echo ""
echo "☕ Installing Java (Eclipse Temurin)..."
if ! dpkg -l | grep -q temurin; then
  wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
  echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" \
   | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null
  sudo apt-get update -y
  # Install latest LTS (21) instead of hardcoded version
  sudo apt-get install -y temurin-21-jdk
  echo "  ✅ Java installed"
else
  echo "  ✅ Java already installed"
fi

# Node.js via nvm
echo ""
echo "📦 Installing Node.js via nvm..."
if [ ! -d "$HOME/.nvm" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  # shellcheck source=/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install node
  nvm alias default node
  echo "  ✅ Node.js installed (restart shell to use nvm)"
else
  echo "  ✅ nvm already installed"
  export NVM_DIR="$HOME/.nvm"
  # shellcheck source=/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  if ! command -v node >/dev/null; then
    nvm install node
    nvm alias default node
  fi
fi

# Install essential npm global packages
echo "  Installing npm global tools..."
npm install -g eslint prettier markdownlint-cli stylelint typescript || true

# mise - universal toolchain manager
echo ""
echo "🔧 Installing mise..."
if [ ! -f "$HOME/.local/share/mise/bin/mise" ]; then
  curl https://mise.jdx.dev/install.sh | sh
  echo "  ✅ mise installed"
else
  echo "  ✅ mise already installed"
fi

# Add to bashrc if not present
if ! grep -q 'mise activate bash' ~/.bashrc; then
  # shellcheck disable=SC2016
  echo 'eval "$(~/.local/share/mise/bin/mise activate bash)"' >> ~/.bashrc
fi

# Activate mise for current session
export PATH="$HOME/.local/share/mise/bin:$PATH"
eval "$(mise activate bash)" || true

# Install Kotlin and Gradle via mise
echo "  Installing Kotlin and Gradle via mise..."
mise use -g kotlin@latest || true
mise use -g gradle@latest || true
mise use -g maven@latest || true
echo "  ✅ JVM tools configured (restart shell to activate)"

# Rust via rustup
echo ""
echo "🦀 Installing Rust..."
if ! command -v rustc >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  # shellcheck source=/dev/null
  . "$HOME/.cargo/env"
  echo "  ✅ Rust installed"
else
  echo "  ✅ Rust already installed"
fi

# Go via official installer
echo ""
echo "🐹 Installing Go..."
if ! command -v go >/dev/null; then
  GO_VERSION="1.23.4"
  GO_ARCH=$(dpkg --print-architecture)
  wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
  rm "go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
  if ! grep -q '/usr/local/go/bin' ~/.bashrc; then
    # shellcheck disable=SC2016
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
  fi
  export PATH=$PATH:/usr/local/go/bin
  echo "  ✅ Go installed"
else
  echo "  ✅ Go already installed"
fi

# pyenv for Python version management
echo ""
echo "🐍 Installing pyenv..."
if [ ! -d "$HOME/.pyenv" ]; then
  curl https://pyenv.run | bash
  {
    # shellcheck disable=SC2016
    echo 'export PYENV_ROOT="$HOME/.pyenv"'
    # shellcheck disable=SC2016
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"'
    # shellcheck disable=SC2016
    echo 'eval "$(pyenv init -)"'
  } >> ~/.bashrc
  echo "  ✅ pyenv installed"
else
  echo "  ✅ pyenv already installed"
fi

# Upgrade pip and install pipx
echo ""
echo "  Upgrading pip and installing pipx..."
if command -v pip3 >/dev/null; then
  python3 -m pip install --upgrade pip || true
  python3 -m pip install --user pipx || true
  python3 -m pipx ensurepath || true
  # Add pipx bin to PATH for current session
  export PATH="$HOME/.local/bin:$PATH"
  echo "  ✅ pip and pipx ready"
else
  echo "  ⚠️  Python3 not found, skipping pip setup"
fi

# R / PHP / Ruby / Docker / linters
echo ""
echo "📚 Installing additional languages and tools..."
sudo apt-get install -y r-base r-base-dev php php-cli php-xml php-mbstring php-curl \
  php-zip php-gd php-intl ruby-full shellcheck docker.io

echo "  Installing R packages..."
R -q -e "install.packages(c('languageserver','lintr','styler'), repos='https://cloud.r-project.org')" || true

echo "  Installing PHP Composer..."
if ! command -v composer >/dev/null; then
  php -r "copy('https://getcomposer.org/installer','composer-setup.php');"
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer
  rm -f composer-setup.php
  echo "  ✅ Composer installed"
else
  echo "  ✅ Composer already installed"
fi

# Add composer bin to PATH if not present
if ! grep -q '.config/composer/vendor/bin' ~/.bashrc; then
  # shellcheck disable=SC2016
  echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> ~/.bashrc
fi

echo "  Installing PHP linters..."
composer global require squizlabs/php_codesniffer phpstan/phpstan vimeo/psalm friendsofphp/php-cs-fixer || true

echo "  Installing Ruby gems..."
gem install bundler rake rubocop --no-document

# Docker configuration
echo ""
echo "🐳 Configuring Docker..."
if command -v docker >/dev/null; then
  # Add user to docker group for rootless operation
  if ! groups | grep -q docker; then
    sudo usermod -aG docker "$USER"
    echo "  ✅ Added user to docker group (logout and login to apply)"
  else
    echo "  ✅ User already in docker group"
  fi

  # Enable and start docker service
  if ! systemctl is-enabled docker >/dev/null 2>&1; then
    sudo systemctl enable docker || true
    sudo systemctl start docker || true
    echo "  ✅ Docker service enabled"
  fi
fi

echo ""
echo "✅ Ubuntu bootstrap complete!"
echo ""
echo "⚠️  IMPORTANT: Close and reopen your terminal to activate:"
echo "   • nvm (Node.js version manager)"
echo "   • mise (Kotlin, Gradle, Maven)"
echo "   • Rust (cargo, rustc)"
echo "   • Go (go command)"
echo "   • pyenv (Python version manager)"
echo "   • Docker (if you were added to docker group)"
echo ""
echo "💡 Run './scripts/wsl/21-wsl-tune.sh' next for additional optimizations."
