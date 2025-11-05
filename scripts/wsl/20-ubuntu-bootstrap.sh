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
  . "$HOME/.nvm/nvm.sh"
fi
nvm install node
nvm alias default node

# mise latest + Kotlin/Gradle
curl https://mise.jdx.dev/install.sh | sh
grep -q 'mise activate bash' ~/.bashrc || echo 'eval "$(~/.local/share/mise/bin/mise activate bash)"' >> ~/.bashrc
. ~/.bashrc
mise use -g kotlin@latest
mise use -g gradle@latest

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
