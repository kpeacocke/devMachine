#!/usr/bin/env bash
set -euo pipefail

echo "🛠️ WSL tune-ups"

sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[automount]
enabled = true
mountFsTab = false

[interop]
appendWindowsPath = true

[network]
generateResolvConf = true
EOF

echo "🔧 QoL packages"
sudo apt-get update -y
sudo apt-get install -y ca-certificates libnss3-tools tmux htop tree

echo "🔐 mkcert trust (for dev TLS in Linux)"
if ! command -v mkcert >/dev/null; then
  curl -fsSL https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-linux-arm64 -o mkcert
  chmod +x mkcert && sudo mv mkcert /usr/local/bin/mkcert
fi
mkcert -install || true

echo "🧪 Security hygiene"
pipx install pre-commit --force || true
pipx install semgrep --force || true

echo "🔁 Apply wsl.conf changes: run 'wsl.exe --shutdown' from Windows, then reopen Ubuntu."
echo "✅ WSL tune-ups done."
