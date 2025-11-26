#!/usr/bin/env bash
set -euo pipefail

echo "🛠️ WSL Tune-ups and Optimizations"
echo ""

echo "⚙️ Configuring WSL settings..."
sudo tee /etc/wsl.conf >/dev/null <<'EOF'
[automount]
enabled = true
mountFsTab = false
options = "metadata,umask=22,fmask=11"

[interop]
enabled = true
appendWindowsPath = true

[network]
generateResolvConf = true
hostname = ubuntu-dev

[boot]
systemd = true

# Performance tuning
[wsl2]
memory = 8GB
swap = 4GB
localhostForwarding = true
EOF
echo "  ✅ WSL configuration updated"

echo ""
echo "📦 Installing quality-of-life packages..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates libnss3-tools tmux htop tree neofetch bat fd-find
echo "  ✅ Packages installed"

echo ""
echo "🔐 Installing mkcert for local TLS development..."
if ! command -v mkcert >/dev/null; then
  ARCH=$(dpkg --print-architecture)
  if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    MKCERT_ARCH="arm64"
  else
    MKCERT_ARCH="amd64"
  fi

  MKCERT_VERSION="v1.4.4"
  curl -fsSL "https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-linux-${MKCERT_ARCH}" -o mkcert
  chmod +x mkcert && sudo mv mkcert /usr/local/bin/mkcert
  echo "  ✅ mkcert installed"
else
  echo "  ✅ mkcert already installed"
fi
mkcert -install || true

echo ""
echo "🧪 Installing security and development tools..."
if command -v pipx >/dev/null; then
  pipx install pre-commit --force || true
  pipx install semgrep --force || true
  pipx install tflint --force || true
  echo "  ✅ Security tools installed"
else
  echo "  ⚠️  pipx not found - run 20-ubuntu-bootstrap.sh first"
fi

echo ""
echo "✅ WSL tune-ups complete!"
echo ""
echo "⚠️  IMPORTANT: To apply wsl.conf changes:"
echo "   1. Exit all WSL sessions"
echo "   2. From PowerShell: wsl --shutdown"
echo "   3. Reopen Ubuntu"
echo ""
echo "💡 New features enabled:"
echo "   • systemd support (for Docker, services)"
echo "   • 8GB memory limit (adjust in /etc/wsl.conf if needed)"
echo "   • Custom hostname: ubuntu-dev"
echo "   • mkcert for local HTTPS development"
