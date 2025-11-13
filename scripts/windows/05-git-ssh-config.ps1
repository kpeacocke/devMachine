<#
Git Configuration & SSH Key Setup
Automates Git global configuration and generates SSH keys for GitHub/GitLab.
#>
$ErrorActionPreference = 'Stop'

Write-Host "[GIT] Configuring Git global settings..."

# Prompt for user info if not already set
$currentName = git config --global user.name 2>$null
$currentEmail = git config --global user.email 2>$null

if ([string]::IsNullOrWhiteSpace($currentName)) {
    if ($env:GIT_USER_NAME) {
        git config --global user.name "$env:GIT_USER_NAME"
        Write-Host "  ✅ Git user.name set from environment: $env:GIT_USER_NAME" -ForegroundColor Green
    } elseif (-not $env:UNATTENDED_MODE) {
        $userName = Read-Host "Enter your full name for Git commits"
        git config --global user.name "$userName"
    } else {
        Write-Host "  ⚠️  Git user.name not set (set GIT_USER_NAME environment variable)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✅ Git user.name already set: $currentName" -ForegroundColor Green
}

if ([string]::IsNullOrWhiteSpace($currentEmail)) {
    if ($env:GIT_USER_EMAIL) {
        git config --global user.email "$env:GIT_USER_EMAIL"
        Write-Host "  ✅ Git user.email set from environment: $env:GIT_USER_EMAIL" -ForegroundColor Green
    } elseif (-not $env:UNATTENDED_MODE) {
        $userEmail = Read-Host "Enter your email for Git commits"
        git config --global user.email "$userEmail"
    } else {
        Write-Host "  ⚠️  Git user.email not set (set GIT_USER_EMAIL environment variable)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✅ Git user.email already set: $currentEmail" -ForegroundColor Green
}

Write-Host "`n[GIT] Setting global Git preferences..."

# Core settings
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global core.editor "code --wait"
git config --global core.longpaths true

# Diff and merge tools (VS Code)
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'
git config --global diff.tool vscode
git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'

# Pull/fetch behavior
git config --global pull.rebase false
git config --global fetch.prune true
git config --global rebase.autoStash true

# Rerere (reuse recorded resolution)
git config --global rerere.enabled true

# Credential helper (Windows)
git config --global credential.helper manager

# Useful aliases
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.unstage 'reset HEAD --'
git config --global alias.last 'log -1 HEAD'
git config --global alias.lg "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
git config --global alias.branches 'branch -a'
git config --global alias.tags 'tag -l'
git config --global alias.remotes 'remote -v'

Write-Host "  ✅ Git configuration complete" -ForegroundColor Green

# SSH Key Generation
Write-Host "`n[SSH] Checking for SSH keys..."

$sshDir = "$env:USERPROFILE\.ssh"
$keyPath = "$sshDir\id_ed25519"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

if (Test-Path $keyPath) {
    Write-Host "  ✅ SSH key already exists: $keyPath" -ForegroundColor Green
    if ($env:REGENERATE_SSH_KEY -eq 'Y') {
        Write-Host "  → Regenerating SSH key (REGENERATE_SSH_KEY=Y)" -ForegroundColor Yellow
    } elseif (-not $env:UNATTENDED_MODE) {
        $regenerate = Read-Host "  Generate new SSH key? (Y/N) [Default: N]"
        if ([string]::IsNullOrWhiteSpace($regenerate)) { $regenerate = 'N' }
        if ($regenerate -ne 'Y') {
            Write-Host "  → Keeping existing SSH key" -ForegroundColor Yellow
            $skipKeyGen = $true
        }
    } else {
        Write-Host "  → Keeping existing SSH key (unattended mode)" -ForegroundColor Yellow
        $skipKeyGen = $true
    }
}

if (-not $skipKeyGen) {
    $email = git config --global user.email
    if ([string]::IsNullOrWhiteSpace($email)) {
        if ($env:GIT_USER_EMAIL) {
            $email = $env:GIT_USER_EMAIL
        } elseif (-not $env:UNATTENDED_MODE) {
            $email = Read-Host "  Enter email for SSH key"
        } else {
            $email = "user@example.com"
            Write-Host "  ⚠️  Using placeholder email for SSH key (set GIT_USER_EMAIL)" -ForegroundColor Yellow
        }
    }

    Write-Host "  Generating Ed25519 SSH key..."
    ssh-keygen -t ed25519 -C "$email" -f $keyPath -N '""' 2>$null

    Write-Host "  ✅ SSH key generated: $keyPath" -ForegroundColor Green
}

# Display and copy public key
if (Test-Path "$keyPath.pub") {
    Write-Host "[SSH] Your SSH public key:" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    $pubKey = Get-Content "$keyPath.pub"
    Write-Host $pubKey -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

    # Copy to clipboard
    $pubKey | Set-Clipboard
    Write-Host "  📋 Public key copied to clipboard!" -ForegroundColor Green
    Write-Host "  Add to GitHub: https://github.com/settings/keys" -ForegroundColor Yellow
    Write-Host "  Add to GitLab: https://gitlab.com/-/profile/keys" -ForegroundColor Yellow
    Write-Host "  Add to Azure DevOps: https://dev.azure.com/_usersSettings/keys" -ForegroundColor Yellow
}

# Configure SSH agent
Write-Host "[SSH] Configuring SSH agent..."
try {
    # Start SSH agent
    Get-Service ssh-agent | Set-Service -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service ssh-agent -ErrorAction SilentlyContinue

    # Add key to agent
    if (Test-Path $keyPath) {
        ssh-add $keyPath 2>$null
        Write-Host "  ✅ SSH key added to agent" -ForegroundColor Green
    }
} catch {
    Write-Warning "SSH agent configuration skipped: $_"
}

# GPG Signing Setup
Write-Host "`n[GPG] Configuring GPG commit signing..."

# Ensure GPG is installed (should be from 10-windows-bootstrap.ps1)
if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing GnuPG..." -ForegroundColor Cyan
    winget install GnuPG.GnuPG --source winget --silent --accept-package-agreements --accept-source-agreements
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Get Git user info
$userName = git config --global user.name
$userEmail = git config --global user.email

if (-not [string]::IsNullOrWhiteSpace($userName) -and -not [string]::IsNullOrWhiteSpace($userEmail)) {
    # Check if GPG key already exists
    $existingKey = gpg --list-secret-keys --keyid-format=long $userEmail 2>$null

    if ($existingKey) {
        Write-Host "  ✅ GPG key already exists for $userEmail" -ForegroundColor Green
        $keyId = ($existingKey | Select-String -Pattern "sec\s+\w+/(\w+)" | ForEach-Object { $_.Matches.Groups[1].Value }) | Select-Object -First 1
    } else {
        Write-Host "  Generating GPG key for $userName <$userEmail>..." -ForegroundColor Cyan

        # Create GPG key generation config (no passphrase for convenience)
        $keyGenConfig = @"
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $userName
Name-Email: $userEmail
Expire-Date: 0
"@

        $configPath = Join-Path $env:TEMP "gpg-keygen.txt"
        $keyGenConfig | Out-File -FilePath $configPath -Encoding ASCII

        # Generate key
        gpg --batch --generate-key $configPath 2>$null
        Remove-Item $configPath -Force

        # Get the key ID
        Start-Sleep -Seconds 2
        $keyOutput = gpg --list-secret-keys --keyid-format=long $userEmail
        $keyId = ($keyOutput | Select-String -Pattern "sec\s+\w+/(\w+)" | ForEach-Object { $_.Matches.Groups[1].Value }) | Select-Object -First 1

        Write-Host "  ✅ Generated GPG key: $keyId" -ForegroundColor Green
    }

    if (-not [string]::IsNullOrWhiteSpace($keyId)) {
        # Configure Git to use the key
        git config --global user.signingkey $keyId
        git config --global commit.gpgsign true
        git config --global tag.gpgsign true

        # Configure GPG program for Git (Windows path)
        $gpgPath = (Get-Command gpg -ErrorAction SilentlyContinue).Source
        if ($gpgPath) {
            $gpgPath = $gpgPath -replace '\\', '/'
            git config --global gpg.program $gpgPath
        }

        Write-Host "  ✅ GPG commit signing enabled" -ForegroundColor Green
        Write-Host "  Key ID: $keyId" -ForegroundColor Cyan

        # Export public key
        Write-Host "`n[GPG] Your GPG public key:" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        $gpgPublicKey = gpg --armor --export $keyId
        Write-Host $gpgPublicKey -ForegroundColor Yellow
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

        # Copy to clipboard
        $gpgPublicKey | Set-Clipboard
        Write-Host "  📋 GPG public key copied to clipboard!" -ForegroundColor Green
        Write-Host "  Add to GitHub: https://github.com/settings/keys" -ForegroundColor Yellow
        Write-Host "  (Choose 'New GPG key' option)" -ForegroundColor Gray
    }
} else {
    Write-Host "  ⚠️  Skipping GPG setup - Git user.name/email not configured" -ForegroundColor Yellow
}

Write-Host "`n[OK] Git, SSH, and GPG configuration complete!" -ForegroundColor Green
