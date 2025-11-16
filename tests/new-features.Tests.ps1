# New Features Test Suite
# Tests for antivirus optimization, DevDrive management, CLI tool integration, and Git configuration
# Run with: pwsh -NoProfile -File .\tests\new-features.Tests.ps1

$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

BeforeAll {
    # Get the repository root (parent of tests directory)
    $script:RepoRoot = if ($PSScriptRoot) {
        Split-Path -Parent $PSScriptRoot
    } else {
        Split-Path -Parent (Get-Location)
    }
    
    $script:WindowsScripts = Join-Path $script:RepoRoot "scripts\windows"
    
    Write-Host "Repository Root: $script:RepoRoot" -ForegroundColor Cyan
    Write-Host "Windows Scripts: $script:WindowsScripts" -ForegroundColor Cyan
}

Describe "Antivirus Exclusions Script - 43-antivirus-exclusions.ps1" {
    
    BeforeAll {
        $script:AntivirusScript = Join-Path $script:WindowsScripts "43-antivirus-exclusions.ps1"
    }

    It "Script file exists" {
        $script:AntivirusScript | Should -Exist
    }

    It "Requires administrator privileges" {
        if (Test-Path $script:AntivirusScript) {
            $content = Get-Content -Path $script:AntivirusScript -Raw
            $content | Should -Match "#Requires -RunAsAdministrator"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Has comprehensive path exclusions" -TestCases @(
        @{Pattern = 'node_modules'; Description = 'Node.js packages'},
        @{Pattern = '\.git'; Description = 'Git repositories'},
        @{Pattern = 'cargo'; Description = 'Rust/Cargo cache'},
        @{Pattern = '\.nuget'; Description = '.NET package cache'},
        @{Pattern = '\.gradle'; Description = 'Gradle build cache'},
        @{Pattern = 'DevCache'; Description = 'Dev Drive cache mount'}
    ) {
        param($Pattern, $Description)
        if (Test-Path $script:AntivirusScript) {
            $content = Get-Content -Path $script:AntivirusScript -Raw
            $content | Should -Match $Pattern -Because "Should exclude $Description"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Has process exclusions for development tools" -TestCases @(
        @{Process = 'node\.exe'; Description = 'Node.js runtime'},
        @{Process = 'dotnet\.exe'; Description = '.NET runtime'},
        @{Process = 'cargo\.exe'; Description = 'Rust/Cargo build tool'},
        @{Process = 'git\.exe'; Description = 'Git version control'},
        @{Process = 'code\.exe'; Description = 'Visual Studio Code'}
    ) {
        param($Process, $Description)
        if (Test-Path $script:AntivirusScript) {
            $content = Get-Content -Path $script:AntivirusScript -Raw
            $content | Should -Match $Process -Because "Should exclude $Description"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Has file extension exclusions" -TestCases @(
        @{Extension = '\.tmp'; Description = 'temporary files'},
        @{Extension = '\.lock'; Description = 'lock files'},
        @{Extension = '\.log'; Description = 'log files'},
        @{Extension = '\.cache'; Description = 'cache files'}
    ) {
        param($Extension, $Description)
        if (Test-Path $script:AntivirusScript) {
            $content = Get-Content -Path $script:AntivirusScript -Raw
            $content | Should -Match $Extension -Because "Should exclude $Description"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Uses proper Windows Defender cmdlets" {
        if (Test-Path $script:AntivirusScript) {
            $content = Get-Content -Path $script:AntivirusScript -Raw
            $content | Should -Match "Add-MpPreference" -Because "Should use Windows Defender PowerShell module"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }
}

Describe "DevDrive Ownership Script - 42-devdrive-fix-ownership.ps1" {
    
    BeforeAll {
        $script:OwnershipScript = Join-Path $script:WindowsScripts "42-devdrive-fix-ownership.ps1"
    }

    It "Script file exists" {
        $script:OwnershipScript | Should -Exist
    }

    It "Requires administrator privileges" {
        if (Test-Path $script:OwnershipScript) {
            $content = Get-Content -Path $script:OwnershipScript -Raw
            $content | Should -Match "#Requires -RunAsAdministrator"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Detects ReFS volumes" {
        if (Test-Path $script:OwnershipScript) {
            $content = Get-Content -Path $script:OwnershipScript -Raw
            $content | Should -Match "ReFS" -Because "Should identify ReFS Dev Drive volumes"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Contains ownership management commands" {
        if (Test-Path $script:OwnershipScript) {
            $content = Get-Content -Path $script:OwnershipScript -Raw
            # Should use either takeown or icacls for ownership management
            ($content -match "takeown" -or $content -match "icacls") | Should -BeTrue -Because "Should fix file ownership"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Has proper error handling" {
        if (Test-Path $script:OwnershipScript) {
            $content = Get-Content -Path $script:OwnershipScript -Raw
            # Should have try-catch or ErrorActionPreference
            ($content -match "try\s*{" -or $content -match '\$ErrorActionPreference') | Should -BeTrue -Because "Should handle errors properly"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }
}

Describe "CLI Tool Integration - Licensed Apps Script Enhancement" {
    
    BeforeAll {
        $script:LicensedAppsScript = Join-Path $script:WindowsScripts "11-licensed-apps.ps1"
    }

    It "Licensed apps script exists" {
        $script:LicensedAppsScript | Should -Exist
    }

    It "Includes GitKraken CLI installation" {
        if (Test-Path $script:LicensedAppsScript) {
            $content = Get-Content -Path $script:LicensedAppsScript -Raw
            $content | Should -Match "GitKraken" -Because "Should install GitKraken CLI alongside GUI"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Handles 1Password CLI properly" {
        if (Test-Path $script:LicensedAppsScript) {
            $content = Get-Content -Path $script:LicensedAppsScript -Raw
            # Should either install 1Password CLI here or reference it elsewhere
            ($content -match "1Password" -or $content -match "op\.exe") | Should -BeTrue -Because "Should handle 1Password CLI installation"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }
}

Describe "Git Configuration Enhancement" {
    
    BeforeAll {
        $script:GitConfigScript = Join-Path $script:WindowsScripts "05-git-ssh-config.ps1"
    }

    It "Git SSH config script exists" {
        $script:GitConfigScript | Should -Exist
    }

    It "Configures VS Code as Git editor" {
        if (Test-Path $script:GitConfigScript) {
            $content = Get-Content -Path $script:GitConfigScript -Raw
            $content | Should -Match "code --wait" -Because "Should set VS Code as Git editor"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Sets up global Git configuration" {
        if (Test-Path $script:GitConfigScript) {
            $content = Get-Content -Path $script:GitConfigScript -Raw
            $content | Should -Match "git config --global" -Because "Should configure Git globally"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }
}

Describe "Windows Defender Optimization Integration" {
    
    BeforeAll {
        $script:OptimizeScript = Join-Path $script:WindowsScripts "30-optimize-and-harden.ps1"
    }

    It "Optimize and harden script exists" {
        $script:OptimizeScript | Should -Exist
    }

    It "Includes Windows Defender exclusions" {
        if (Test-Path $script:OptimizeScript) {
            $content = Get-Content -Path $script:OptimizeScript -Raw
            $content | Should -Match "Add-MpPreference" -Because "Should add Windows Defender exclusions"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Excludes development paths" {
        if (Test-Path $script:OptimizeScript) {
            $content = Get-Content -Path $script:OptimizeScript -Raw
            $content | Should -Match "ExclusionPath" -Because "Should exclude development directories from scanning"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Has comprehensive exclusion patterns" -TestCases @(
        @{Pattern = 'node_modules'; Type = 'Path exclusion'},
        @{Pattern = '\.git'; Type = 'Path exclusion'},
        @{Pattern = 'ExclusionProcess'; Type = 'Process exclusion'},
        @{Pattern = 'ExclusionExtension'; Type = 'Extension exclusion'}
    ) {
        param($Pattern, $Type)
        if (Test-Path $script:OptimizeScript) {
            $content = Get-Content -Path $script:OptimizeScript -Raw
            $content | Should -Match $Pattern -Because "Should have $Type for development tools"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }
}

Describe "Setup Orchestrator Integration" {
    
    BeforeAll {
        $script:SetupScript = Join-Path $script:RepoRoot "setup-machine.ps1"
    }

    It "Setup orchestrator exists" {
        $script:SetupScript | Should -Exist
    }

    It "Includes Malwarebytes detection and guidance" {
        if (Test-Path $script:SetupScript) {
            $content = Get-Content -Path $script:SetupScript -Raw
            $content | Should -Match "Malwarebytes" -Because "Should detect and provide guidance for Malwarebytes"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "Provides comprehensive antivirus guidance" {
        if (Test-Path $script:SetupScript) {
            $content = Get-Content -Path $script:SetupScript -Raw
            # Should provide guidance for third-party antivirus
            ($content -match "THIRD-PARTY ANTIVIRUS" -or $content -match "Norton\|McAfee\|Avast") | Should -BeTrue -Because "Should provide third-party antivirus guidance"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }

    It "References DevDrive ownership troubleshooting" {
        if (Test-Path $script:SetupScript) {
            $content = Get-Content -Path $script:SetupScript -Raw
            $content | Should -Match "42-devdrive-fix-ownership" -Because "Should reference DevDrive ownership fix script"
        } else {
            Set-ItResult -Skipped -Because "Script not found"
        }
    }
}

Describe "Integration and Consistency Tests" {
    
    It "All new scripts have valid PowerShell syntax" {
        $newScripts = @(
            "42-devdrive-fix-ownership.ps1",
            "43-antivirus-exclusions.ps1"
        )
        
        foreach ($scriptName in $newScripts) {
            $scriptPath = Join-Path $script:WindowsScripts $scriptName
            if (Test-Path $scriptPath) {
                $parseErrors = $null
                $tokens = $null
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $scriptPath, [ref]$tokens, [ref]$parseErrors
                )
                $parseErrors | Should -BeNullOrEmpty -Because "$scriptName should have valid PowerShell syntax"
            } else {
                Set-ItResult -Skipped -Because "$scriptName not found"
            }
        }
    }

    It "Critical paths exist and are properly referenced" {
        # Check if the path is referenced in relevant scripts
        $ownershipScript = Join-Path $script:WindowsScripts "42-devdrive-fix-ownership.ps1"
        $cacheScript = Join-Path $script:WindowsScripts "40-devdrive-caches.ps1"
        
        if ((Test-Path $ownershipScript) -or (Test-Path $cacheScript)) {
            $ownershipContent = if (Test-Path $ownershipScript) { Get-Content -Path $ownershipScript -Raw } else { "" }
            $cacheContent = if (Test-Path $cacheScript) { Get-Content -Path $cacheScript -Raw } else { "" }
            
            $criticalPaths = @(
                @{Name = "DevCache mount"; Pattern = "C:\\DevCache|DevCache"},
                @{Name = "User code directory"; Pattern = "code"}
            )
            
            foreach ($path in $criticalPaths) {
                ($ownershipContent -match $path.Pattern -or 
                 $cacheContent -match $path.Pattern) | 
                    Should -BeTrue -Because "$($path.Name) should be referenced in DevDrive scripts"
            }
        } else {
            Set-ItResult -Skipped -Because "DevDrive scripts not found"
        }
    }
}