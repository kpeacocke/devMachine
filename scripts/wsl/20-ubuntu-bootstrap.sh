#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y build-essential pkg-config cmake ninja-build curl wget git ca-certificates jq ripgrep unzip zip

# Java (Temurin latest GA)
sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" \
 | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null
sudo apt-get update -y && sudo apt-get install -y temurin-25-jdk

# Node current via nvm
if ! command -v nvm >/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  # shellcheck source=/dev/null
  . "$HOME/.nvm/nvm.sh"
fi
nvm install node
nvm alias default node

# mise latest + Kotlin/Gradle
curl https://mise.jdx.dev/install.sh | sh
# shellcheck disable=SC2016
grep -q 'mise activate bash' ~/.bashrc || echo 'eval "$(~/.local/share/mise/bin/mise activate bash)"' >> ~/.bashrc
# shellcheck source=/dev/null
. ~/.bashrc
mise use -g kotlin@latest
# shellcheck source=/dev/null
mise use -g gradle@latest

# pyenv for Python version management
echo "🐍 pyenv for Python version management"
if ! command -v pyenv >/dev/null; then
  curl https://pyenv.run | bash
  {
    # shellcheck disable=SC2016
    echo 'export PYENV_ROOT="$HOME/.pyenv"'
    # shellcheck disable=SC2016
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"'
    # shellcheck disable=SC2016
    echo 'eval "$(pyenv init -)"'
  } >> ~/.bashrc
  # shellcheck source=/dev/null
  . ~/.bashrc
fi

# R / PHP / Ruby / linters
sudo apt-get install -y r-base r-base-dev php php-cli php-xml php-mbstring php-curl php-zip php-gd php-intl ruby-full shellcheck docker.io
R -q -e "install.packages(c('languageserver','lintr','styler'), repos='https://cloud.r-project.org')" || true

if ! command -v composer >/dev/null; then
  php -r "copy('https://getcomposer.org/installer','composer-setup.php');"
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer
  rm -f composer-setup.php
fi
composer global require squizlabs/php_codesniffer phpstan/phpstan vimeo/psalm friendsofphp/php-cs-fixer || true

gem install bundler rake rubocop --no-document
