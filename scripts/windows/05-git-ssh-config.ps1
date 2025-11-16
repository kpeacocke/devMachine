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

# Intelligent diff and merge tool detection and configuration
Write-Host "`n[GIT TOOLS] Detecting and configuring diff/merge tools..."

# Function to find installed tools
function Find-GitTool {
    param([string]$Name, [string[]]$Paths, [string]$ExecutableName)

    foreach ($path in $Paths) {
        $fullPath = Join-Path $path $ExecutableName
        if (Test-Path $fullPath) {
            Write-Host "    ✅ Found $Name at: $fullPath" -ForegroundColor Green
            return $fullPath
        }
    }
    return $null
}

# Check for Beyond Compare 5
$bcPaths = @(
    "$env:LOCALAPPDATA\Programs\Beyond Compare 5",
    "$env:ProgramFiles\Beyond Compare 5",
    "$env:ProgramFiles(x86)\Beyond Compare 5"
)
$bcPath = Find-GitTool -Name "Beyond Compare 5" -Paths $bcPaths -ExecutableName "BCompare.exe"

# Check for Beyond Compare 4 (fallback)
if (-not $bcPath) {
    $bc4Paths = @(
        "$env:LOCALAPPDATA\Programs\Beyond Compare 4",
        "$env:ProgramFiles\Beyond Compare 4",
        "$env:ProgramFiles(x86)\Beyond Compare 4"
    )
    $bcPath = Find-GitTool -Name "Beyond Compare 4" -Paths $bc4Paths -ExecutableName "BComp.exe"
}

# Check for VS Code
$vscodePaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code",
    "$env:ProgramFiles\Microsoft VS Code",
    "$env:ProgramFiles(x86)\Microsoft VS Code"
)
$vscodePath = Find-GitTool -Name "VS Code" -Paths $vscodePaths -ExecutableName "Code.exe"
if (-not $vscodePath) {
    # Check if code is in PATH
    if (Get-Command code -ErrorAction SilentlyContinue) {
        $vscodePath = "code"
        Write-Host "    ✅ Found VS Code in PATH" -ForegroundColor Green
    }
}

# Check for WinMerge
$winmergePaths = @(
    "$env:ProgramFiles\WinMerge",
    "$env:ProgramFiles(x86)\WinMerge"
)
$winmergePath = Find-GitTool -Name "WinMerge" -Paths $winmergePaths -ExecutableName "WinMergeU.exe"

# Configure the best available tool (priority: Beyond Compare > WinMerge > VS Code)
if ($bcPath) {
    Write-Host "  🏆 Configuring Beyond Compare as primary diff/merge tool..." -ForegroundColor Yellow

    git config --global diff.tool bc5
    git config --global difftool.bc5.cmd "`"$bcPath`" `"$LOCAL`" `"$REMOTE`""
    git config --global difftool.prompt false

    git config --global merge.tool bc5
    git config --global mergetool.bc5.cmd "`"$bcPath`" `"$LOCAL`" `"$REMOTE`" `"$BASE`" `"$MERGED`""
    git config --global mergetool.bc5.trustExitCode true
    git config --global mergetool.keepBackup false

    Write-Host "    ✅ Beyond Compare configured (bc5)" -ForegroundColor Green
    $primaryTool = "Beyond Compare"

} elseif ($winmergePath) {
    Write-Host "  🥈 Configuring WinMerge as primary diff/merge tool..." -ForegroundColor Yellow

    git config --global diff.tool winmerge
    git config --global difftool.winmerge.cmd "`"$winmergePath`" -u -e `"$LOCAL`" `"$REMOTE`""
    git config --global difftool.prompt false

    git config --global merge.tool winmerge
    git config --global mergetool.winmerge.cmd "`"$winmergePath`" -u -e -wl -wr `"$BASE`" `"$LOCAL`" `"$REMOTE`" -o `"$MERGED`""
    git config --global mergetool.winmerge.trustExitCode true
    git config --global mergetool.keepBackup false

    Write-Host "    ✅ WinMerge configured" -ForegroundColor Green
    $primaryTool = "WinMerge"

} elseif ($vscodePath) {
    Write-Host "  🥉 Configuring VS Code as primary diff/merge tool..." -ForegroundColor Yellow

    git config --global diff.tool vscode
    git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'
    git config --global difftool.prompt false

    git config --global merge.tool vscode
    git config --global mergetool.vscode.cmd 'code --wait $MERGED'
    git config --global mergetool.vscode.trustExitCode true
    git config --global mergetool.keepBackup false

    Write-Host "    ✅ VS Code configured" -ForegroundColor Green
    $primaryTool = "VS Code"

} else {
    Write-Host "  ⚠️  No suitable diff/merge tools found" -ForegroundColor Yellow
    Write-Host "    Consider installing: Beyond Compare, WinMerge, or VS Code" -ForegroundColor Gray
    $primaryTool = "None"
}

# Always set VS Code as the default editor (lightweight for commit messages)
if ($vscodePath) {
    git config --global core.editor "code --wait"
    Write-Host "  ✅ VS Code set as Git editor (commit messages)" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  VS Code not found - using default Git editor" -ForegroundColor Yellow
}

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
git config --global alias.config 'config --global --list'

Write-Host "  ✅ Git configuration complete" -ForegroundColor Green

# Show configured tools summary
Write-Host "`n[GIT TOOLS SUMMARY]" -ForegroundColor Cyan
Write-Host "  Primary diff/merge tool: $primaryTool" -ForegroundColor Yellow
if ($primaryTool -ne "None") {
    $configuredDiff = git config --global diff.tool 2>$null
    $configuredMerge = git config --global merge.tool 2>$null
    $configuredEditor = git config --global core.editor 2>$null

    Write-Host "  Diff tool:  $configuredDiff" -ForegroundColor Gray
    Write-Host "  Merge tool: $configuredMerge" -ForegroundColor Gray
    Write-Host "  Editor:     $configuredEditor" -ForegroundColor Gray

    Write-Host "`n  Usage commands:" -ForegroundColor Yellow
    Write-Host "    git difftool              # Compare files with $primaryTool" -ForegroundColor White
    Write-Host "    git mergetool             # Resolve conflicts with $primaryTool" -ForegroundColor White
    Write-Host "    git commit                # Write commit message in VS Code" -ForegroundColor White
}

# Global .gitignore configuration
Write-Host "`n[GITIGNORE] Setting up global .gitignore patterns..." -ForegroundColor Cyan

$globalGitignorePath = "$env:USERPROFILE\.gitignore_global"
$gitignoreContent = @'
# Global .gitignore - Common patterns across all projects
# Generated by devMachine setup

###################
# Operating System
###################
# Windows
Thumbs.db
Thumbs.db:encryptable
ehthumbs.db
ehthumbs_vista.db
*.stackdump
[Dd]esktop.ini
$RECYCLE.BIN/
*.cab
*.msi
*.msix
*.msm
*.msp
*.lnk

# macOS
.DS_Store
.AppleDouble
.LSOverride
._*
.DocumentRevisions-V100
.fseventsd
.Spotlight-V100
.TemporaryItems
.Trashes
.VolumeIcon.icns
.com.apple.timemachine.donotpresent
.AppleDB
.AppleDesktop

# Linux
*~
.fuse_hidden*
.directory
.Trash-*
.nfs*

###################
# IDEs & Editors
###################
# VS Code
.vscode/
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
*.code-workspace

# JetBrains IDEs
.idea/
*.iml
*.ipr
*.iws
out/
.idea_modules/
atlassian-ide-plugin.xml
com_crashlytics_export_strings.xml
crashlytics.properties
crashlytics-build.properties
fabric.properties

# Visual Studio
.vs/
*.rsuser
*.suo
*.user
*.userosscache
*.sln.docstates
[Bb]in/
[Oo]bj/
[Ll]og/
[Ll]ogs/
*.tmp_proj
*_wpftmp.csproj
*.log
*.tlog
*.vspscc
*.vssscc
.builds
*.pidb
*.svclog
*.scc

###################
# Development Tools
###################
# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm
.eslintcache
.node_repl_history
*.tsbuildinfo
.nyc_output

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/
.pytest_cache/
.coverage
htmlcov/
.tox/
.nox/

# Java
*.class
*.jar
*.war
*.nar
*.ear
*.zip
*.tar.gz
*.rar
hs_err_pid*
.gradle/
gradle-app.setting
!gradle-wrapper.jar
!gradle-wrapper.properties
.gradletasknamecache
target/
.mvn/

# .NET Core
project.lock.json
project.fragment.lock.json
artifacts/
**/Properties/launchSettings.json
.dotnet/
.localhistory/

# Docker
.dockerignore

# Terraform
*.tfstate
*.tfstate.*
crash.log
crash.*.log
*.tfvars
*.tfvars.json
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc

###################
# Security & Secrets
###################
# Environment files
.env
.env.local
.env.*.local
.envrc

# Certificate files
*.pem
*.key
*.crt
*.p12
*.pfx

# Database
*.db
*.sqlite
*.sqlite3

# Logs
*.log
logs/
log/

###################
# Build & Cache
###################
# General build directories
build/
dist/
out/
target/

# Cache directories
.cache/
.tmp/
tmp/

# Package manager lock files (include these in most projects)
# package-lock.json
# yarn.lock
# Pipfile.lock

###################
# Backup & Temp Files
###################
*.bak
*.backup
*.swp
*.swo
*~
.#*
\#*\#
.*.swp
.*.swo

# Archive files (usually not needed in repos)
*.7z
*.dmg
*.gz
*.iso
*.rar
*.tar
*.zip
'@

# Create the global gitignore file
try {
    $gitignoreContent | Out-File -FilePath $globalGitignorePath -Encoding UTF8 -Force

    # Configure Git to use the global gitignore
    git config --global core.excludesfile "$globalGitignorePath"

    Write-Host "  ✅ Global .gitignore created: $globalGitignorePath" -ForegroundColor Green
    Write-Host "    Contains patterns for: OS files, IDEs, Node.js, Python, Java, .NET, Docker, Terraform" -ForegroundColor Gray
    Write-Host "    Security: Excludes .env files, certificates, databases" -ForegroundColor Gray

    # Add useful gitignore aliases
    git config --global alias.ignore '!gi() { curl -sL "https://www.toptal.com/developers/gitignore/api/$@"; }; gi'
    git config --global alias.showignored 'ls-files -o -i --exclude-standard'

    Write-Host "  ✅ Added gitignore aliases:" -ForegroundColor Green
    Write-Host "    git ignore '<language>'     # Generate gitignore for language/framework" -ForegroundColor Gray
    Write-Host "    git showignored           # Show currently ignored files" -ForegroundColor Gray

} catch {
    Write-Warning "Failed to create global gitignore: $($_.Exception.Message)"
}

# Global .gitattributes configuration
Write-Host "`n  Setting up global .gitattributes..." -ForegroundColor Gray

$globalGitattributesPath = "$env:USERPROFILE\.gitattributes_global"
$gitattributesContent = @'
# Global .gitattributes - File handling patterns across all projects
# Generated by devMachine setup

###############################################################################
# Set default behavior for handling line endings
###############################################################################
# Automatically normalize line endings for all text files
* text=auto

###############################################################################
# Language-specific line ending handling
###############################################################################
# Force LF for shell scripts (important for WSL/Linux compatibility)
*.sh text eol=lf
*.bash text eol=lf
*.zsh text eol=lf

# Force LF for configuration files that expect Unix line endings
*.yml text eol=lf
*.yaml text eol=lf
Dockerfile* text eol=lf
*.dockerfile text eol=lf

# Web files - consistent LF endings for cross-platform development
*.js text eol=lf
*.jsx text eol=lf
*.ts text eol=lf
*.tsx text eol=lf
*.vue text eol=lf
*.json text eol=lf
*.html text eol=lf
*.css text eol=lf
*.scss text eol=lf
*.sass text eol=lf
*.less text eol=lf

# Python files
*.py text eol=lf
*.pyx text eol=lf
*.pyi text eol=lf

# Windows-specific files - force CRLF where expected
*.cmd text eol=crlf
*.bat text eol=crlf
*.ps1 text eol=crlf
*.psm1 text eol=crlf

###############################################################################
# File types that should always be treated as text
###############################################################################
*.txt text
*.md text
*.markdown text
*.rst text
*.tex text
*.rtf text
*.csv text
*.tsv text
*.sql text
*.xml text
*.xhtml text
*.svg text

# Configuration files
*.ini text
*.cfg text
*.conf text
*.config text
*.toml text
*.lock text
*.log text

# Source code files
*.c text
*.cpp text
*.cxx text
*.cc text
*.h text
*.hpp text
*.hxx text
*.java text
*.kt text
*.scala text
*.go text
*.rs text
*.rb text
*.php text
*.pl text
*.r text
*.R text
*.m text
*.mm text

# Markup and documentation
*.adoc text
*.asciidoc text
*.mustache text

###############################################################################
# Binary files (explicitly marked to prevent text processing)
###############################################################################
# Images
*.jpg binary
*.jpeg binary
*.png binary
*.gif binary
*.ico binary
*.svg binary
*.bmp binary
*.tiff binary
*.tga binary
*.webp binary

# Audio
*.mp3 binary
*.wav binary
*.flac binary
*.ogg binary
*.m4a binary

# Video
*.mp4 binary
*.avi binary
*.mov binary
*.wmv binary
*.flv binary
*.webm binary

# Documents
*.pdf binary
*.doc binary
*.docx binary
*.xls binary
*.xlsx binary
*.ppt binary
*.pptx binary
*.odt binary

# Archives
*.zip binary
*.tar binary
*.gz binary
*.7z binary
*.rar binary
*.bz2 binary

# Executables and libraries
*.exe binary
*.dll binary
*.so binary
*.dylib binary
*.a binary
*.lib binary
*.obj binary
*.o binary

# Fonts
*.ttf binary
*.otf binary
*.eot binary
*.woff binary
*.woff2 binary

###############################################################################
# Git LFS (Large File Storage) patterns - common large files
###############################################################################
# Uncomment these if using Git LFS
# *.psd filter=lfs diff=lfs merge=lfs -text
# *.ai filter=lfs diff=lfs merge=lfs -text
# *.sketch filter=lfs diff=lfs merge=lfs -text
# *.fig filter=lfs diff=lfs merge=lfs -text

###############################################################################
# Language-specific filters and diff drivers
###############################################################################
# .NET assembly info (prevent merge conflicts in auto-generated version info)
**/AssemblyInfo.cs merge=ours
**/AssemblyVersionInfo.cs merge=ours

# Package manager files (often auto-generated, use ours strategy)
package-lock.json merge=ours
yarn.lock merge=ours
Pipfile.lock merge=ours

# Database files
*.db binary
*.sqlite binary
*.sqlite3 binary

###############################################################################
# Export-ignore (files/folders not included in git archive)
###############################################################################
# Development and CI files that shouldn't be in releases
.gitignore export-ignore
.gitattributes export-ignore
.github/ export-ignore
.vscode/ export-ignore
.idea/ export-ignore
tests/ export-ignore
test/ export-ignore
spec/ export-ignore
__tests__/ export-ignore
*.test.* export-ignore
*.spec.* export-ignore
*.md export-ignore
LICENSE export-ignore
README* export-ignore
CHANGELOG* export-ignore
CONTRIBUTING* export-ignore

###############################################################################
# Diff drivers for better readability
###############################################################################
# Better diffs for common file types
*.cs diff=csharp
*.java diff=java
*.php diff=php
*.py diff=python
*.rb diff=ruby
*.pl diff=perl

# Image diffs (show file info instead of binary diff)
*.png diff=exif
*.jpg diff=exif
*.jpeg diff=exif
*.gif diff=exif
'@

try {
    $gitattributesContent | Out-File -FilePath $globalGitattributesPath -Encoding UTF8 -Force

    # Configure Git to use the global gitattributes
    git config --global core.attributesfile "$globalGitattributesPath"

    Write-Host "    ✅ Global .gitattributes created: $globalGitattributesPath" -ForegroundColor Green
    Write-Host "      Line endings: Auto-normalize, Unix for scripts/web, Windows for .ps1/.cmd" -ForegroundColor Gray
    Write-Host "      File types: Proper text/binary classification for all major formats" -ForegroundColor Gray
    Write-Host "      Export-ignore: Development files excluded from git archive" -ForegroundColor Gray

} catch {
    Write-Warning "Failed to create global gitattributes: $($_.Exception.Message)"
}

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

Write-Host "`n[OK] Git, SSH, GPG, .gitignore, and .gitattributes configuration complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Default branch:      main" -ForegroundColor Green
Write-Host "✅ Diff/merge tool:     $primaryTool" -ForegroundColor Green
Write-Host "✅ Global .gitignore:   OS, IDEs, languages, security" -ForegroundColor Green
Write-Host "✅ Global .gitattributes: Line endings, file types, export rules" -ForegroundColor Green
Write-Host "✅ SSH keys:            Generated and configured" -ForegroundColor Green
Write-Host "✅ GPG signing:         Configured (if available)" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "💡 Global gitignore:    $env:USERPROFILE\.gitignore_global" -ForegroundColor Yellow
Write-Host "💡 Global gitattributes: $env:USERPROFILE\.gitattributes_global" -ForegroundColor Yellow
Write-Host "💡 Use 'git ignore <language>' to generate specific patterns" -ForegroundColor Yellow
