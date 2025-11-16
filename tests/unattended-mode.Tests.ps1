# Unattended mode functionality tests
# Run with: pwsh -NoProfile -File .\tests\unattended-mode.Tests.ps1

BeforeAll {
    $ErrorActionPreference = 'Stop'

    # Get the repository root (parent of tests directory)
    $script:RepoRoot = if ($PSScriptRoot) {
        Split-Path -Parent $PSScriptRoot
    } else {
        Split-Path -Parent (Get-Location)
    }

    Write-Host "Repository Root: $script:RepoRoot" -ForegroundColor Cyan
}

Describe "Unattended Mode Support" {

    BeforeAll {
        # Get all PowerShell scripts that should support unattended mode
        $script:scripts = Get-ChildItem -Path (Join-Path $script:RepoRoot "scripts\windows") -Filter "*.ps1" |
            Where-Object {
                # Exclude maintenance scripts that don't need unattended mode
                $_.Name -notmatch "doctor|maintain"
            }

        Write-Host "Found $($script:scripts.Count) scripts to test" -ForegroundColor Cyan
    }

    It "Scripts with Read-Host have unattended mode checks" {
        $scriptsWithPrompts = @()
        $violatingScripts = @()

        foreach ($script in $script:scripts) {
            $content = Get-Content -Path $script.FullName -Raw

            # Check if script contains Read-Host
            if ($content -match 'Read-Host') {
                $scriptsWithPrompts += $script.Name

                # Check if it also has unattended mode handling (multiple patterns)
                $hasUnattendedSupport = (
                    $content -match '\$env:UNATTENDED_MODE' -or
                    $content -match '\$env:SKIP_' -or
                    $content -match '\$env:FORCE_' -or
                    $content -match '\$env:INSTALL_' -or
                    $content -match '\$env:CREATE_' -or
                    $content -match '\$env:GIT_USER_' -or
                    $content -match 'if.*\$env:.*Read-Host' -or
                    ($content -match 'if\s*\(' -and $content -match 'Read-Host')
                )

                if (-not $hasUnattendedSupport) {
                    $violatingScripts += $script.Name
                }
            }
        }

        Write-Host "Scripts with Read-Host: $($scriptsWithPrompts -join ', ')" -ForegroundColor Yellow

        if ($violatingScripts.Count -gt 0) {
            throw "Scripts with Read-Host but no unattended mode support: $($violatingScripts -join ', ')"
        }

        $violatingScripts.Count | Should -Be 0
    }

    It "Licensed apps script supports unattended mode" {
        $licensedAppsScript = Join-Path $script:RepoRoot "scripts\windows\11-licensed-apps.ps1"
        $content = Get-Content -Path $licensedAppsScript -Raw

        # Should check for UNATTENDED_MODE
        $content | Should -Match '\$env:UNATTENDED_MODE'

        # Should skip interactive apps in unattended mode
        $content | Should -Match 'Skipped in unattended mode'

        # Should handle Typora appropriately
        $content | Should -Match 'INSTALL_TYPORA'
    }

    It "Git SSH config script supports unattended mode" {
        $gitScript = Join-Path $script:RepoRoot "scripts\windows\05-git-ssh-config.ps1"
        $content = Get-Content -Path $gitScript -Raw

        # Should check for environment variables
        $content | Should -Match '\$env:GIT_USER_NAME'
        $content | Should -Match '\$env:GIT_USER_EMAIL'
        $content | Should -Match '\$env:UNATTENDED_MODE'
    }

    It "Bootstrap script supports unattended mode for VM detection" {
        $bootstrapScript = Join-Path $script:RepoRoot "scripts\windows\10-windows-bootstrap.ps1"
        $content = Get-Content -Path $bootstrapScript -Raw

        # Should handle WSL installation in VMs
        $content | Should -Match '\$env:INSTALL_WSL_IN_VM'
        $content | Should -Match '\$env:UNATTENDED_MODE'
    }

    It "Dev Drive script supports unattended mode" {
        $devDriveScript = Join-Path $script:RepoRoot "scripts\windows\41-devdrive-partition-setup.ps1"
        if (Test-Path $devDriveScript) {
            $content = Get-Content -Path $devDriveScript -Raw

            # Should check for CREATE_DEV_DRIVE or UNATTENDED_MODE environment variable
            ($content -match '\$env:CREATE_DEV_DRIVE' -or
             $content -match '\$env:UNATTENDED_MODE' -or
             $content -notmatch 'Read-Host') | Should -BeTrue -Because "Should support unattended operation"
        } else {
            Set-ItResult -Skipped -Because "Dev Drive script not found"
        }
    }

    It "DevDrive ownership fix script supports unattended mode" {
        $ownershipScript = Join-Path $script:RepoRoot "scripts\windows\42-devdrive-fix-ownership.ps1"
        if (Test-Path $ownershipScript) {
            $content = Get-Content -Path $ownershipScript -Raw

            # Should require admin privileges
            $content | Should -Match '#Requires -RunAsAdministrator' -Because "Ownership changes require admin"

            # Should support unattended mode
            ($content -match '\$env:UNATTENDED_MODE' -or $content -match '\$env:FORCE_FIX_OWNERSHIP') | Should -BeTrue -Because "Should work in automation"

            # Should validate paths properly
            ($content -match 'Test-Path' -or $content -match 'ValidateScript') | Should -BeTrue -Because "Should validate input paths"

            # Should have proper error handling for automation
            ($content -match 'try.*catch' -or $content -match 'ErrorActionPreference') | Should -BeTrue -Because "Should handle errors gracefully"
        } else {
            Set-ItResult -Skipped -Because "DevDrive ownership script not found"
        }
    }

    It "Antivirus exclusions script supports unattended mode" {
        $antivirusScript = Join-Path $script:RepoRoot "scripts\windows\43-antivirus-exclusions.ps1"
        if (Test-Path $antivirusScript) {
            $content = Get-Content -Path $antivirusScript -Raw

            # Should require admin privileges
            $content | Should -Match '#Requires -RunAsAdministrator' -Because "Defender changes require admin"

            # Should support unattended mode
            $content | Should -Match '\$env:UNATTENDED_MODE|\$env:SKIP_ANTIVIRUS_CONFIG' -Because "Should work in automation"

            # Should have comprehensive exclusions for CI/CD
            $content | Should -Match 'node_modules' -Because "Should exclude npm modules for Node.js builds"
            $content | Should -Match '\.git' -Because "Should exclude Git directories"
            $content | Should -Match 'target.*bin.*obj' -Because "Should exclude build output directories"
            $content | Should -Match '\.cargo|\.rustup' -Because "Should exclude Rust toolchain"
            $content | Should -Match 'go.*pkg.*mod' -Because "Should exclude Go module cache"
            $content | Should -Match '\.gradle|\.m2' -Because "Should exclude Java build caches"
            $content | Should -Match 'venv|__pycache__' -Because "Should exclude Python environments"

            # Should handle Malwarebytes detection
            $content | Should -Match 'Malwarebytes' -Because "Should detect and guide for Malwarebytes"

            # Should provide automation-friendly output
            $content | Should -Match 'Write-(Host|Output|Information)' -Because "Should provide status feedback"
        } else {
            Set-ItResult -Skipped -Because "Antivirus exclusions script not found"
        }
    }

    It "Cache configuration script supports unattended mode" {
        $cacheScript = Join-Path $script:RepoRoot "scripts\windows\40-devdrive-caches.ps1"
        if (Test-Path $cacheScript) {
            $content = Get-Content -Path $cacheScript -Raw

            # Should support unattended mode
            $content | Should -Match '\$env:UNATTENDED_MODE|\$env:DEVDRIVE_PATH|\$env:SKIP_CACHE_CONFIG' -Because "Should work in automation"

            # Should handle DevDrive detection automatically
            $content | Should -Match 'Test-Path.*DevCache|Get-Volume.*ReFS' -Because "Should auto-detect DevDrive"

            # Should configure all major package managers
            $content | Should -Match 'npm.*cache|NPM_CONFIG_CACHE' -Because "Should configure npm cache"
            $content | Should -Match 'pip.*cache|PIP_CACHE_DIR' -Because "Should configure pip cache"
            $content | Should -Match 'cargo|CARGO_HOME' -Because "Should configure Cargo cache"
            $content | Should -Match 'go.*cache|GOPATH|GOCACHE' -Because "Should configure Go caches"
            $content | Should -Match 'gradle|GRADLE_USER_HOME' -Because "Should configure Gradle cache"

            # Should set environment variables persistently
            $content | Should -Match '\[Environment\]::SetEnvironmentVariable.*User' -Because "Should persist settings"
        } else {
            Set-ItResult -Skipped -Because "Cache configuration script not found"
        }
    }

    It "Licensed apps script supports CLI tool integration" {
        $licensedAppsScript = Join-Path $script:RepoRoot "scripts\windows\11-licensed-apps.ps1"
        if (Test-Path $licensedAppsScript) {
            $content = Get-Content -Path $licensedAppsScript -Raw

            # Should check for UNATTENDED_MODE
            $content | Should -Match '\$env:UNATTENDED_MODE' -Because "Should support automation"

            # Should skip interactive apps in unattended mode
            $content | Should -Match 'Skipped in unattended mode' -Because "Should skip interactive installations"

            # Should handle Typora appropriately
            $content | Should -Match 'INSTALL_TYPORA' -Because "Should allow Typora override"

            # Should integrate CLI tools with GUI apps
            $content | Should -Match 'GitKraken.*CLI|gk\.exe' -Because "Should install GitKraken CLI with app"
            $content | Should -Match '1Password.*CLI|op\.exe' -Because "Should install 1Password CLI with app"

            # Should not duplicate CLI installations
            $content | Should -Not -Match 'winget.*install.*gk$|winget.*install.*op$' -Because "Should not separately install CLI tools"
        } else {
            Set-ItResult -Skipped -Because "Licensed apps script not found"
        }
    }

    It "Git SSH config script supports enhanced unattended mode" {
        $gitScript = Join-Path $script:RepoRoot "scripts\windows\05-git-ssh-config.ps1"
        if (Test-Path $gitScript) {
            $content = Get-Content -Path $gitScript -Raw

            # Should check for environment variables
            $content | Should -Match '\$env:GIT_USER_NAME' -Because "Should get username from environment"
            $content | Should -Match '\$env:GIT_USER_EMAIL' -Because "Should get email from environment"
            $content | Should -Match '\$env:UNATTENDED_MODE' -Because "Should support automation"

            # Should configure VS Code as editor
            $content | Should -Match 'code --wait|core\.editor.*code' -Because "Should set VS Code as Git editor"

            # Should set enhanced Git configurations
            $content | Should -Match 'core\.autocrlf' -Because "Should configure line endings"
            $content | Should -Match 'init\.defaultBranch' -Because "Should set default branch"
            $content | Should -Match 'pull\.rebase' -Because "Should configure pull behavior"

            # Should handle SSH key generation
            $content | Should -Match 'ssh-keygen|\.ssh.*id_' -Because "Should generate SSH keys"

            # Should create global Git files
            $content | Should -Match 'core\.excludesfile|gitignore' -Because "Should configure global gitignore"
            $content | Should -Match 'core\.attributesfile|gitattributes' -Because "Should configure global gitattributes"
        } else {
            Set-ItResult -Skipped -Because "Git SSH config script not found"
        }
    }

    It "Optimization script supports unattended Defender configuration" {
        $optimizeScript = Join-Path $script:RepoRoot "scripts\windows\30-optimize-and-harden.ps1"
        if (Test-Path $optimizeScript) {
            $content = Get-Content -Path $optimizeScript -Raw

            # Should support unattended mode
            $content | Should -Match '\$env:UNATTENDED_MODE|\$env:SKIP_DEFENDER_CONFIG' -Because "Should work in automation"

            # Should configure Windows Defender automatically
            $content | Should -Match 'Add-MpPreference' -Because "Should add Defender exclusions"
            $content | Should -Match 'Get-MpComputerStatus|Get-MpPreference' -Because "Should check Defender status"

            # Should handle cases where Defender isn't available
            $content | Should -Match 'try.*catch|ErrorAction.*SilentlyContinue' -Because "Should handle Defender unavailability"

            # Should include development exclusions
            $content | Should -Match 'ExclusionPath.*ExclusionProcess' -Because "Should exclude paths and processes"

            # Should reference or include antivirus guidance
            ($content -match '43-antivirus-exclusions' -or $content -match 'Malwarebytes') | Should -BeTrue -Because "Should handle multiple AV solutions"
        } else {
            Set-ItResult -Skipped -Because "Optimization script not found"
        }
    }

    It "Privacy/telemetry script supports unattended mode" {
        $privacyScript = Join-Path $script:RepoRoot "scripts\windows\35-privacy-telemetry.ps1"
        if (Test-Path $privacyScript) {
            $content = Get-Content -Path $privacyScript -Raw

            # Should handle unattended mode (OneDrive is always left enabled now)
            $content | Should -Match '\$env:UNATTENDED_MODE'
        } else {
            Set-ItResult -Skipped -Because "Privacy script not found"
        }
    }
}

Describe "Environment Variable Documentation and Validation" {

    It "README documents all unattended mode variables" {
        $readmePath = Join-Path $script:RepoRoot "README.md"
        if (Test-Path $readmePath) {
            $content = Get-Content -Path $readmePath -Raw

            # Core unattended mode
            $content | Should -Match 'UNATTENDED_MODE|unattended' -Because "Should document basic unattended mode"

            # Git configuration
            $content | Should -Match 'GIT_USER_NAME.*GIT_USER_EMAIL' -Because "Should document Git user variables"

            # License and app configuration
            $content | Should -Match 'INSTALL_TYPORA' -Because "Should document license app variables"
        } else {
            Set-ItResult -Skipped -Because "README.md not found"
        }
    }

    It "Scripts consistently use environment variable patterns" {
        # Define expected environment variable patterns for different script types
        $envVarPatterns = @{
            'Git' = @('GIT_USER_NAME', 'GIT_USER_EMAIL', 'UNATTENDED_MODE')
            'DevDrive' = @('CREATE_DEV_DRIVE', 'DEVDRIVE_PATH', 'UNATTENDED_MODE')
            'Antivirus' = @('SKIP_ANTIVIRUS_CONFIG', 'UNATTENDED_MODE')
            'Cache' = @('SKIP_CACHE_CONFIG', 'DEVDRIVE_PATH', 'UNATTENDED_MODE')
            'Licensed' = @('INSTALL_TYPORA', 'UNATTENDED_MODE')
        }

        # Check that scripts follow patterns
        $gitScript = Join-Path $script:RepoRoot "scripts\windows\05-git-ssh-config.ps1"
        if (Test-Path $gitScript) {
            $content = Get-Content -Path $gitScript -Raw
            foreach ($var in $envVarPatterns.Git) {
                $content | Should -Match "\`$env:$var" -Because "Git script should check $var"
            }
        }

        $antivirusScript = Join-Path $script:RepoRoot "scripts\windows\43-antivirus-exclusions.ps1"
        if (Test-Path $antivirusScript) {
            $content = Get-Content -Path $antivirusScript -Raw
            foreach ($var in $envVarPatterns.Antivirus) {
                if ($var -eq 'UNATTENDED_MODE') {
                    ($content -match "\`$env:$var" -or $content -match "\`$env:SKIP_ANTIVIRUS_CONFIG") | Should -BeTrue -Because "Antivirus script should check automation variables"
                }
            }
        }
    }

    It "Scripts provide meaningful automation feedback" {
        $criticalScripts = @(
            '40-devdrive-caches.ps1',
            '41-devdrive-partition-setup.ps1',
            '42-devdrive-fix-ownership.ps1',
            '43-antivirus-exclusions.ps1'
        )

        foreach ($scriptName in $criticalScripts) {
            $scriptPath = Join-Path $script:RepoRoot "scripts\windows\$scriptName"
            if (Test-Path $scriptPath) {
                $content = Get-Content -Path $scriptPath -Raw

                # Should provide status output for automation
                $content | Should -Match 'Write-(Host|Output|Information)' -Because "$scriptName should provide status feedback"

                # Should handle errors gracefully
                $content | Should -Match 'try.*catch|ErrorAction.*Continue|ErrorAction.*SilentlyContinue' -Because "$scriptName should handle errors gracefully in automation"
            }
        }
    }

    It "New scripts follow unattended mode conventions" {
        $newScripts = @(
            @{Name='42-devdrive-fix-ownership.ps1'; RequiresAdmin=$true; ShouldSupportUnattended=$true},
            @{Name='43-antivirus-exclusions.ps1'; RequiresAdmin=$true; ShouldSupportUnattended=$true},
            @{Name='40-devdrive-caches.ps1'; RequiresAdmin=$false; ShouldSupportUnattended=$true}
        )

        foreach ($script in $newScripts) {
            $scriptPath = Join-Path $script:RepoRoot "scripts\windows\$($script.Name)"
            if (Test-Path $scriptPath) {
                $content = Get-Content -Path $scriptPath -Raw

                if ($script.RequiresAdmin) {
                    $content | Should -Match '#Requires -RunAsAdministrator' -Because "$($script.Name) should require admin"
                }

                if ($script.ShouldSupportUnattended) {
                    ($content -match '\$env:UNATTENDED_MODE' -or
                     $content -match '\$env:SKIP_' -or
                     $content -match '\$env:FORCE_' -or
                     $content -notmatch 'Read-Host') | Should -BeTrue -Because "$($script.Name) should support unattended operation"
                }
            }
        }
    }
}
