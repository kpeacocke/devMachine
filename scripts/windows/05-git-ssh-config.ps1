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
    $userName = Read-Host "Enter your full name for Git commits"
    git config --global user.name "$userName"
} else {
    Write-Host "  ✅ Git user.name already set: $currentName" -ForegroundColor Green
}

if ([string]::IsNullOrWhiteSpace($currentEmail)) {
    $userEmail = Read-Host "Enter your email for Git commits"
    git config --global user.email "$userEmail"
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
    $regenerate = Read-Host "  Generate new SSH key? (Y/N) [Default: N]"
    if ([string]::IsNullOrWhiteSpace($regenerate)) { $regenerate = 'N' }
    if ($regenerate -ne 'Y') {
        Write-Host "  → Keeping existing SSH key" -ForegroundColor Yellow
        $skipKeyGen = $true
    }
}

if (-not $skipKeyGen) {
    $email = git config --global user.email
    if ([string]::IsNullOrWhiteSpace($email)) {
        $email = Read-Host "  Enter email for SSH key"
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

Write-Host "[OK] Git and SSH configuration complete!" -ForegroundColor Green
