#!/usr/bin/env bash
#
# Maintain Python environment: upgrade pip and update all installed packages.
# Run periodically to keep your Python environment up to date.
#
set -euo pipefail

echo "🐍 Python Environment Maintenance"

# Check if Python is installed
if ! command -v python3 >/dev/null; then
    echo "  ❌ Python3 not found. Please run 20-ubuntu-bootstrap.sh first."
    exit 1
fi

# Display current Python version
PYTHON_VERSION=$(python3 --version)
echo "  Current Python: $PYTHON_VERSION"

# Upgrade pip
echo ""
echo "📦 Upgrading pip..."
if python3 -m pip install --upgrade pip; then
    PIP_VERSION=$(python3 -m pip --version)
    echo "  [OK] $PIP_VERSION"
else
    echo "  ❌ Failed to upgrade pip"
    exit 1
fi

# List outdated packages
echo ""
echo "📋 Checking for outdated packages..."
OUTDATED=$(python3 -m pip list --outdated --format=json)
OUTDATED_COUNT=$(echo "$OUTDATED" | jq length)

if [ "$OUTDATED_COUNT" -eq 0 ]; then
    echo "  ✅ All packages are up to date!"
else
    echo "  Found $OUTDATED_COUNT outdated package(s):"
    echo "$OUTDATED" | jq -r '.[] | "    • \(.name): \(.version) → \(.latest_version)"'

    # Ask user if they want to update all packages
    read -rp "  Update all packages? (Y/N) [Default: Y]: " response
    response=${response:-Y}

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        echo "  Updating packages..."
        while IFS= read -r pkg; do
            echo "    Updating $pkg..."
            if python3 -m pip install --upgrade "$pkg"; then
                echo "      [OK] $pkg updated"
            else
                echo "      [WARN] Failed to update $pkg"
            fi
        done < <(echo "$OUTDATED" | jq -r '.[].name')
        echo ""
        echo "  ✅ Package updates complete!"
    else
        echo "  → Skipped package updates"
    fi
fi

# Update pyenv if installed
if command -v pyenv >/dev/null; then
    echo ""
    echo "🔧 Updating pyenv..."
    if cd "$HOME/.pyenv" && git pull; then
        echo "  [OK] pyenv updated"
    else
        echo "  [WARN] Failed to update pyenv"
    fi
fi

# Update pip for all pyenv Python versions
if command -v pyenv >/dev/null; then
    echo ""
    echo "🐍 Updating pip for all pyenv Python versions..."
    # shellcheck disable=SC2016
    PYENV_VERSIONS=$(pyenv versions --bare)
    if [ -n "$PYENV_VERSIONS" ]; then
        while IFS= read -r version; do
            echo "    Updating pip for Python $version..."
            if pyenv shell "$version" && python -m pip install --upgrade pip 2>/dev/null; then
                echo "      [OK] pip updated for $version"
            else
                echo "      [WARN] Failed to update pip for $version"
            fi
        done <<< "$PYENV_VERSIONS"
        pyenv shell --unset 2>/dev/null || true
    else
        echo "    ℹ️  No pyenv Python versions installed"
    fi
fi

echo ""
echo "✅ Python maintenance complete!"
