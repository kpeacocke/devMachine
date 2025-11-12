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

                # Check if it also has unattended mode handling
                if ($content -notmatch '\$env:UNATTENDED_MODE') {
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

            # Should check for CREATE_DEV_DRIVE environment variable
            $content | Should -Match '\$env:CREATE_DEV_DRIVE'
            $content | Should -Match '\$env:UNATTENDED_MODE'
        } else {
            Set-ItResult -Skipped -Because "Dev Drive script not found"
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

Describe "Environment Variable Documentation" {

    It "README should document unattended mode variables" {
        $readmePath = Join-Path $script:RepoRoot "README.md"
        if (Test-Path $readmePath) {
            $content = Get-Content -Path $readmePath -Raw

            # Should mention unattended mode
            $content | Should -Match 'UNATTENDED_MODE|unattended'
        } else {
            Set-ItResult -Skipped -Because "README.md not found"
        }
    }
}
