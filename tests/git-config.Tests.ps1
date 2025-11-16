#Requires -Version 7.0
<#
.SYNOPSIS
    Tests for Git configuration, SSH setup, and development tool integration

.DESCRIPTION
    Comprehensive tests covering:
    - Git installation and core configuration (05-git-ssh-config.ps1)
    - SSH key generation and GitHub integration
    - VS Code as Git editor configuration
    - Global gitignore and gitattributes setup
    - Git diff/merge tool configuration

.NOTES
    Run with: pwsh -NoProfile -File .\tests\git-config.Tests.ps1
    Some tests may require Git to be configured with user credentials
#>

BeforeAll {
    $ErrorActionPreference = 'Continue'

    # Get the repository root
    $script:RepoRoot = if ($PSScriptRoot) {
        Split-Path -Parent $PSScriptRoot
    } else {
        Split-Path -Parent (Get-Location)
    }

    Write-Host "🔧 Git Configuration Test Suite" -ForegroundColor Cyan
    Write-Host "Repository Root: $script:RepoRoot" -ForegroundColor Gray

    # Helper function to safely run git commands
    function Invoke-GitSafely {
        param([string]$Command)

        try {
            $result = cmd /c "git $Command 2>nul"
            if ($LASTEXITCODE -eq 0) {
                return $result
            }
            return $null
        } catch {
            return $null
        }
    }

    # Helper function to check if VS Code is available
    function Test-VSCodeAvailable {
        try {
            $null = Get-Command code -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }

    $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    $script:VSCodeAvailable = Test-VSCodeAvailable

    if ($script:GitAvailable) {
        Write-Host "Git is available ✅" -ForegroundColor Green
    } else {
        Write-Host "Git not found ❌" -ForegroundColor Red
    }

    if ($script:VSCodeAvailable) {
        Write-Host "VS Code is available ✅" -ForegroundColor Green
    } else {
        Write-Host "VS Code not found (tests will adapt) ⚠️" -ForegroundColor Yellow
    }
}

Describe "Git SSH Configuration Script (05-git-ssh-config.ps1)" {

    BeforeAll {
        $script:GitConfigScript = Join-Path $script:RepoRoot "scripts\windows\05-git-ssh-config.ps1"
        $script:GitConfigScriptExists = Test-Path $script:GitConfigScript
    }

    It "Git SSH configuration script exists and is valid" {
        $script:GitConfigScriptExists | Should -Be $true

        if ($script:GitConfigScriptExists) {
            # Check syntax
            $syntaxCheck = pwsh -NoProfile -Command "try { [void](Get-Command '$script:GitConfigScript' -Syntax -ErrorAction Stop); exit 0 } catch { exit 1 }"
            $LASTEXITCODE | Should -Be 0
        }
    }

    It "Script configures VS Code as Git editor" {
        if (-not $script:GitConfigScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:GitConfigScript -Raw

        # Should configure VS Code as editor
        $content | Should -Match "code --wait" -Because "Should set VS Code as Git editor"
        $content | Should -Match "core\.editor.*code" -Because "Should use git config to set editor"
    }

    It "Script sets essential Git configurations" {
        if (-not $script:GitConfigScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:GitConfigScript -Raw

        # Core Git settings
        $content | Should -Match "core\.autocrlf" -Because "Should configure line ending handling"
        $content | Should -Match "init\.defaultBranch|init\.defaultbranch" -Because "Should set default branch name"
        $content | Should -Match "pull\.rebase" -Because "Should configure pull behavior"
        $content | Should -Match "fetch\.prune" -Because "Should enable automatic pruning"
    }

    It "Script handles SSH key generation" {
        if (-not $script:GitConfigScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:GitConfigScript -Raw

        # SSH key management
        $content | Should -Match "ssh-keygen" -Because "Should generate SSH keys"
        $content | Should -Match "\.ssh.*id_" -Because "Should use standard SSH key locations"
        $content | Should -Match "ed25519|rsa" -Because "Should specify key algorithm"
    }

    It "Script configures global gitignore" {
        if (-not $script:GitConfigScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:GitConfigScript -Raw

        # Global gitignore configuration
        $content | Should -Match "core\.excludesfile" -Because "Should set global gitignore"
        $content | Should -Match "gitignore_global|\.gitignore" -Because "Should create gitignore file"
    }

    It "Script configures global gitattributes" {
        if (-not $script:GitConfigScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:GitConfigScript -Raw

        # Global gitattributes configuration
        $content | Should -Match "core\.attributesfile" -Because "Should set global gitattributes"
        $content | Should -Match "gitattributes|\.gitattributes" -Because "Should create gitattributes file"
    }

    It "Script handles user configuration safely" {
        if (-not $script:GitConfigScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:GitConfigScript -Raw

        # Should check for existing configuration
        $content | Should -Match "git config.*--get|user\.name.*user\.email" -Because "Should check existing user config"
        $content | Should -Match "Read-Host|prompt|input" -Because "Should prompt for user information"
    }
}

Describe "Git Installation and Availability" {

    It "Git is installed and accessible" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $git = Get-Command git -ErrorAction SilentlyContinue
        $git | Should -Not -BeNullOrEmpty

        # Check version
        $version = Invoke-GitSafely "--version"
        $version | Should -Not -BeNullOrEmpty
        $version | Should -Match "git version \d+"
    }

    It "Git version is reasonably current" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $version = Invoke-GitSafely "--version"
        if ($version -match "git version (\d+)\.(\d+)\.(\d+)") {
            $majorVersion = [int]$matches[1]
            $minorVersion = [int]$matches[2]

            # Git 2.20+ recommended for modern features
            if ($majorVersion -gt 2 -or ($majorVersion -eq 2 -and $minorVersion -ge 20)) {
                $true | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "Git version $($matches[0]) is older than recommended (2.20+)"
            }
        } else {
            Set-ItResult -Skipped -Because "Could not parse Git version"
        }
    }
}

Describe "Git Core Configuration" {

    It "Git user name is configured" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $userName = Invoke-GitSafely "config --global user.name"
        if (-not $userName) {
            Set-ItResult -Skipped -Because "Git user name not configured (run Git configuration script)"
        } else {
            $userName | Should -Not -BeNullOrEmpty
            $userName.Length | Should -BeGreaterThan 0
        }
    }

    It "Git user email is configured" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $userEmail = Invoke-GitSafely "config --global user.email"
        if (-not $userEmail) {
            Set-ItResult -Skipped -Because "Git user email not configured (run Git configuration script)"
        } else {
            $userEmail | Should -Not -BeNullOrEmpty
            $userEmail | Should -Match "@" -Because "Email should contain @ symbol"
        }
    }

    It "Git editor is configured properly" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $editor = Invoke-GitSafely "config --global core.editor"
        if (-not $editor) {
            Set-ItResult -Skipped -Because "Git editor not configured"
            return
        }

        $editor | Should -Not -BeNullOrEmpty

        # If VS Code is available and configured as editor
        if ($script:VSCodeAvailable -and $editor -match "code") {
            $editor | Should -Match "--wait" -Because "VS Code should be configured with --wait flag"
        }
    }

    It "Line ending configuration is set" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $autocrlf = Invoke-GitSafely "config --global core.autocrlf"
        if ($autocrlf) {
            $autocrlf | Should -BeIn @('true', 'false', 'input') -Because "autocrlf should be a valid value"

            # On Windows, 'true' is typically recommended
            if ($IsWindows -or $env:OS -match "Windows") {
                $autocrlf | Should -Be 'true' -Because "Windows should typically use autocrlf=true"
            }
        } else {
            Set-ItResult -Skipped -Because "autocrlf not configured"
        }
    }

    It "Default branch name is configured" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $defaultBranch = Invoke-GitSafely "config --global init.defaultBranch"
        if ($defaultBranch) {
            $defaultBranch | Should -BeIn @('main', 'master', 'develop') -Because "Should use a standard default branch name"

            # Modern preference is 'main'
            if ($defaultBranch -eq 'main') {
                Write-Host "✅ Using modern default branch name 'main'" -ForegroundColor Green
            }
        } else {
            Set-ItResult -Skipped -Because "Default branch not configured"
        }
    }

    It "Pull behavior is configured" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $pullRebase = Invoke-GitSafely "config --global pull.rebase"
        if ($pullRebase) {
            $pullRebase | Should -BeIn @('true', 'false', 'merges', 'interactive') -Because "pull.rebase should be a valid value"
        } else {
            Set-ItResult -Skipped -Because "Pull rebase not configured"
        }
    }

    It "Fetch pruning is enabled" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $fetchPrune = Invoke-GitSafely "config --global fetch.prune"
        if ($fetchPrune) {
            $fetchPrune | Should -Be 'true' -Because "Automatic pruning should be enabled"
        } else {
            Set-ItResult -Skipped -Because "Fetch prune not configured"
        }
    }
}

Describe "SSH Configuration" {

    It "SSH directory exists" {
        $sshDir = Join-Path $env:USERPROFILE ".ssh"
        Test-Path $sshDir | Should -Be $true -Because ".ssh directory should exist"

        if (Test-Path $sshDir) {
            # Check permissions (should be restricted)
            try {
                $acl = Get-Acl $sshDir
                $access = $acl.Access | Where-Object { $_.IdentityReference -match $env:USERNAME }
                $access | Should -Not -BeNullOrEmpty -Because "User should have access to .ssh directory"
            } catch {
                # Permissions check failed - this is informational
                Write-Host "ℹ️ Could not check .ssh directory permissions" -ForegroundColor Cyan
            }
        }
    }

    It "SSH key pair exists" {
        $sshDir = Join-Path $env:USERPROFILE ".ssh"
        if (-not (Test-Path $sshDir)) {
            Set-ItResult -Skipped -Because ".ssh directory does not exist"
            return
        }

        # Look for common SSH key types
        $keyTypes = @('id_ed25519', 'id_rsa', 'id_ecdsa')
        $foundKeys = @()

        foreach ($keyType in $keyTypes) {
            $privateKey = Join-Path $sshDir $keyType
            $publicKey = "$privateKey.pub"

            if ((Test-Path $privateKey) -and (Test-Path $publicKey)) {
                $foundKeys += $keyType
            }
        }

        if ($foundKeys.Count -eq 0) {
            Set-ItResult -Skipped -Because "No SSH key pairs found (run SSH configuration script)"
        } else {
            $foundKeys.Count | Should -BeGreaterThan 0
            Write-Host "✅ Found SSH keys: $($foundKeys -join ', ')" -ForegroundColor Green
        }
    }

    It "SSH config file exists and is properly configured" {
        $sshConfig = Join-Path $env:USERPROFILE ".ssh\config"

        if (Test-Path $sshConfig) {
            $configContent = Get-Content $sshConfig -Raw

            # Basic validation - should have some host configurations
            $configContent | Should -Not -BeNullOrEmpty

            # Check for GitHub configuration
            if ($configContent -match "Host.*github\.com") {
                Write-Host "✅ GitHub SSH configuration found" -ForegroundColor Green
                $configContent | Should -Match "HostName github\.com" -Because "Should have GitHub hostname"
                $configContent | Should -Match "User git" -Because "Should specify git user for GitHub"
            }
        } else {
            Set-ItResult -Skipped -Because "SSH config file not found"
        }
    }
}

Describe "Global Git Files Configuration" {

    It "Global gitignore exists and has reasonable content" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $globalIgnore = Invoke-GitSafely "config --global core.excludesfile"
        if (-not $globalIgnore) {
            Set-ItResult -Skipped -Because "Global gitignore not configured"
            return
        }

        Test-Path $globalIgnore | Should -Be $true -Because "Global gitignore file should exist"

        $ignoreContent = Get-Content $globalIgnore -Raw
        $ignoreContent | Should -Not -BeNullOrEmpty

        # Should contain common patterns
        $ignoreContent | Should -Match "\.env" -Because "Should ignore environment files"
        $ignoreContent | Should -Match "\.log|logs/" -Because "Should ignore log files"
        $ignoreContent | Should -Match "node_modules|\.DS_Store|Thumbs\.db" -Because "Should ignore common system/build files"
    }

    It "Global gitattributes exists and configures line endings" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $globalAttributes = Invoke-GitSafely "config --global core.attributesfile"
        if (-not $globalAttributes) {
            Set-ItResult -Skipped -Because "Global gitattributes not configured"
            return
        }

        Test-Path $globalAttributes | Should -Be $true -Because "Global gitattributes file should exist"

        $attributeContent = Get-Content $globalAttributes -Raw
        $attributeContent | Should -Not -BeNullOrEmpty

        # Should configure text handling
        $attributeContent | Should -Match "text=auto" -Because "Should enable automatic text detection"
    }
}

Describe "Git Diff and Merge Tools" {

    It "Diff tool is configured" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $diffTool = Invoke-GitSafely "config --global diff.tool"
        if ($diffTool) {
            $diffTool | Should -Not -BeNullOrEmpty

            # Common diff tools
            $commonDiffTools = @('vscode', 'code', 'vimdiff', 'meld', 'kdiff3', 'p4merge')
            if ($diffTool -in $commonDiffTools) {
                Write-Host "✅ Using diff tool: $diffTool" -ForegroundColor Green
            }

            # If VS Code is configured, validate the command
            if ($script:VSCodeAvailable -and $diffTool -match "vscode|code") {
                $diffCmd = Invoke-GitSafely "config --global difftool.$diffTool.cmd"
                if ($diffCmd) {
                    $diffCmd | Should -Match "code.*--wait.*--diff" -Because "VS Code diff should use proper flags"
                }
            }
        } else {
            Set-ItResult -Skipped -Because "Diff tool not configured"
        }
    }

    It "Merge tool is configured" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $mergeTool = Invoke-GitSafely "config --global merge.tool"
        if ($mergeTool) {
            $mergeTool | Should -Not -BeNullOrEmpty

            # Common merge tools
            $commonMergeTools = @('vscode', 'code', 'vimdiff', 'meld', 'kdiff3', 'p4merge')
            if ($mergeTool -in $commonMergeTools) {
                Write-Host "✅ Using merge tool: $mergeTool" -ForegroundColor Green
            }

            # If VS Code is configured, validate the command
            if ($script:VSCodeAvailable -and $mergeTool -match "vscode|code") {
                $mergeCmd = Invoke-GitSafely "config --global mergetool.$mergeTool.cmd"
                if ($mergeCmd) {
                    $mergeCmd | Should -Match "code.*--wait" -Because "VS Code merge should use --wait flag"
                }
            }
        } else {
            Set-ItResult -Skipped -Because "Merge tool not configured"
        }
    }

    It "Merge tool trust setting is configured" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $mergeTool = Invoke-GitSafely "config --global merge.tool"
        if ($mergeTool) {
            $trustExitCode = Invoke-GitSafely "config --global mergetool.$mergeTool.trustExitCode"
            if ($trustExitCode) {
                $trustExitCode | Should -BeIn @('true', 'false') -Because "Trust exit code should be boolean"
            } else {
                # This is optional configuration
                Write-Host "ℹ️ Merge tool trust exit code not configured" -ForegroundColor Cyan
            }
        }
    }
}

Describe "Git Performance and Security" {

    It "Git credential helper is configured" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $credHelper = Invoke-GitSafely "config --global credential.helper"
        if ($credHelper) {
            $credHelper | Should -Not -BeNullOrEmpty

            # Windows should typically use manager or manager-core
            if ($IsWindows -or $env:OS -match "Windows") {
                $credHelper | Should -Match "manager|wincred" -Because "Windows should use credential manager"
            }

            Write-Host "✅ Using credential helper: $credHelper" -ForegroundColor Green
        } else {
            Set-ItResult -Skipped -Because "Credential helper not configured"
        }
    }

    It "Git has reasonable performance settings" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        # Check for performance-related settings
        $preloadIndex = Invoke-GitSafely "config --global core.preloadindex"
        if ($preloadIndex) {
            $preloadIndex | Should -Be 'true' -Because "Preload index improves performance"
        }

        $fscache = Invoke-GitSafely "config --global core.fscache"
        if ($fscache) {
            $fscache | Should -Be 'true' -Because "Filesystem cache improves performance"
        }
    }

    It "Git protocol version is configured" {
        if (-not $script:GitAvailable) {
            Set-ItResult -Skipped -Because "Git not installed"
            return
        }

        $protocolVersion = Invoke-GitSafely "config --global protocol.version"
        if ($protocolVersion) {
            $protocolVersion | Should -BeIn @('0', '1', '2') -Because "Protocol version should be valid"

            # Version 2 is preferred for performance
            if ($protocolVersion -eq '2') {
                Write-Host "✅ Using Git protocol v2 (optimal)" -ForegroundColor Green
            }
        } else {
            Set-ItResult -Skipped -Because "Git protocol version not explicitly set"
        }
    }
}

AfterAll {
    Write-Host "🏁 Git configuration test execution complete" -ForegroundColor Cyan
    Write-Host "Note: Some tests require Git to be configured with user credentials and SSH keys" -ForegroundColor Gray

    if (-not $script:GitAvailable) {
        Write-Host "💡 Git not found - install Git and run configuration scripts" -ForegroundColor Cyan
    }

    if (-not $script:VSCodeAvailable) {
        Write-Host "💡 VS Code not found - install for enhanced Git integration" -ForegroundColor Cyan
    }
}
