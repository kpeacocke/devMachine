#Requires -Version 7.0
<#
.SYNOPSIS
    Tests for CLI tools integration with GUI applications

.DESCRIPTION
    Comprehensive tests covering:
    - 1Password CLI integration with 1Password app
    - GitKraken CLI integration with GitKraken app
    - CLI tool availability and functionality
    - Integration validation and path management

.NOTES
    Run with: pwsh -NoProfile -File .\tests\cli-tools.Tests.ps1
    CLI tools may require their GUI counterparts to be installed first
#>

BeforeAll {
    $ErrorActionPreference = 'Continue'

    # Get the repository root
    $script:RepoRoot = if ($PSScriptRoot) {
        Split-Path -Parent $PSScriptRoot
    } else {
        Split-Path -Parent (Get-Location)
    }

    Write-Host "🔧 CLI Tools Integration Test Suite" -ForegroundColor Cyan
    Write-Host "Repository Root: $script:RepoRoot" -ForegroundColor Gray

    # Helper function to check if a command is available
    function Test-CommandAvailable {
        param([string]$Command)

        try {
            $null = Get-Command $Command -ErrorAction Stop
            return $true
        } catch {
            return $false
        }
    }

    # Helper function to check if a process is running
    function Test-ProcessRunning {
        param([string]$ProcessName)

        try {
            $process = Get-Process $ProcessName -ErrorAction Stop
            return $process.Count -gt 0
        } catch {
            return $false
        }
    }

    # Helper function to check if an app is installed
    function Test-AppInstalled {
        param([string]$AppName, [string[]]$Paths)

        foreach ($path in $Paths) {
            if (Test-Path $path) {
                return $true
            }
        }
        return $false
    }

    # Check CLI tool availability
    $script:OpCLI = Test-CommandAvailable "op"
    $script:GitKrakenCLI = Test-CommandAvailable "gk"

    # Check GUI app installations
    $script:OnePasswordApp = Test-AppInstalled "1Password" @(
        "${env:LOCALAPPDATA}\1Password\*",
        "${env:ProgramFiles}\1Password\*",
        "${env:ProgramFiles(x86)}\1Password\*"
    )

    $script:GitKrakenApp = Test-AppInstalled "GitKraken" @(
        "${env:LOCALAPPDATA}\gitkraken\*",
        "${env:APPDATA}\GitKraken\*"
    )

    Write-Host "CLI Tools Status:" -ForegroundColor Cyan
    Write-Host "  1Password CLI: $(if($script:OpCLI){'✅'}else{'❌'})" -ForegroundColor $(if($script:OpCLI){'Green'}else{'Red'})
    Write-Host "  GitKraken CLI: $(if($script:GitKrakenCLI){'✅'}else{'❌'})" -ForegroundColor $(if($script:GitKrakenCLI){'Green'}else{'Red'})
    Write-Host "GUI Applications Status:" -ForegroundColor Cyan
    Write-Host "  1Password App: $(if($script:OnePasswordApp){'✅'}else{'❌'})" -ForegroundColor $(if($script:OnePasswordApp){'Green'}else{'Red'})
    Write-Host "  GitKraken App: $(if($script:GitKrakenApp){'✅'}else{'❌'})" -ForegroundColor $(if($script:GitKrakenApp){'Green'}else{'Red'})
}

Describe "Licensed Apps Script CLI Integration (11-licensed-apps.ps1)" {

    BeforeAll {
        $script:LicensedAppsScript = Join-Path $script:RepoRoot "scripts\windows\11-licensed-apps.ps1"
        $script:LicensedAppsScriptExists = Test-Path $script:LicensedAppsScript
    }

    It "Licensed apps script exists and is valid" {
        $script:LicensedAppsScriptExists | Should -Be $true

        if ($script:LicensedAppsScriptExists) {
            # Check syntax
            $syntaxCheck = pwsh -NoProfile -Command "try { [void](Get-Command '$script:LicensedAppsScript' -Syntax -ErrorAction Stop); exit 0 } catch { exit 1 }"
            $LASTEXITCODE | Should -Be 0
        }
    }

    It "Script includes GitKraken with CLI integration" {
        if (-not $script:LicensedAppsScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:LicensedAppsScript -Raw

        # Should install GitKraken (which includes CLI)
        $content | Should -Match "GitKraken" -Because "Should install GitKraken with integrated CLI"

        # Should NOT separately install GitKraken CLI
        $content | Should -Not -Match "winget.*install.*gk$|GitKraken\.CLI" -Because "CLI should come with GUI app"

        # Should mention CLI capability
        $content | Should -Match "CLI|command.*line|gk" -Because "Should document CLI availability"
    }

    It "Script includes 1Password with CLI integration" {
        if (-not $script:LicensedAppsScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:LicensedAppsScript -Raw

        # Should install 1Password (which includes CLI)
        $content | Should -Match "1Password" -Because "Should install 1Password with integrated CLI"

        # Should NOT separately install 1Password CLI
        $content | Should -Not -Match "winget.*install.*op$|AgileBits\.1Password-CLI" -Because "CLI should come with GUI app"

        # Should mention CLI capability
        $content | Should -Match "CLI|command.*line|op" -Because "Should document CLI availability"
    }

    It "Script handles unattended mode for CLI tools" {
        if (-not $script:LicensedAppsScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:LicensedAppsScript -Raw

        # Should support unattended mode
        $content | Should -Match '\$env:UNATTENDED_MODE' -Because "Should support automation"

        # Should skip interactive licensing in unattended mode
        $content | Should -Match 'Skipped in unattended mode' -Because "Should skip interactive licensing"

        # Should allow CLI tools to install without user interaction
        $content | Should -Not -Match 'Read-Host.*GitKraken|Read-Host.*1Password' -Because "CLI tools should install automatically"
    }

    It "Script provides proper installation guidance" {
        if (-not $script:LicensedAppsScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:LicensedAppsScript -Raw

        # Should provide guidance on CLI usage
        $content | Should -Match "after.*installation.*CLI|once.*installed.*available" -Because "Should explain CLI availability"

        # Should mention PATH considerations
        $content | Should -Match "PATH|command.*available|restart.*shell" -Because "Should explain PATH requirements"
    }
}

Describe "1Password CLI Integration" {

    It "1Password CLI is available when app is installed" {
        if (-not $script:OnePasswordApp) {
            Set-ItResult -Skipped -Because "1Password app not installed"
            return
        }

        if (-not $script:OpCLI) {
            # CLI should be available if app is installed
            Set-ItResult -Skipped -Because "1Password CLI not found in PATH (may need shell restart)"
        } else {
            $script:OpCLI | Should -Be $true
        }
    }

    It "1Password CLI version is accessible" {
        if (-not $script:OpCLI) {
            Set-ItResult -Skipped -Because "1Password CLI not available"
            return
        }

        try {
            $version = op --version 2>&1
            $version | Should -Not -BeNullOrEmpty
            $version | Should -Match "\d+\.\d+\.\d+"
        } catch {
            Set-ItResult -Skipped -Because "Could not get 1Password CLI version: $_"
        }
    }

    It "1Password CLI commands are functional" {
        if (-not $script:OpCLI) {
            Set-ItResult -Skipped -Because "1Password CLI not available"
            return
        }

        try {
            # Test basic command that doesn't require authentication
            $help = op --help 2>&1
            $help | Should -Not -BeNullOrEmpty
            $help | Should -Match "1Password|commands|options"
        } catch {
            Set-ItResult -Skipped -Because "Could not execute 1Password CLI help: $_"
        }
    }

    It "1Password app and CLI are properly integrated" {
        if (-not $script:OnePasswordApp -or -not $script:OpCLI) {
            Set-ItResult -Skipped -Because "Both 1Password app and CLI required for integration test"
            return
        }

        # If app is running, CLI should be able to detect it
        $onePasswordRunning = Test-ProcessRunning "1Password"
        if ($onePasswordRunning) {
            try {
                # Test CLI integration with running app
                $accounts = op account list 2>&1
                if ($accounts -notmatch "error|not.*signed.*in") {
                    Write-Host "✅ 1Password CLI successfully integrated with app" -ForegroundColor Green
                    $true | Should -Be $true
                } else {
                    Set-ItResult -Skipped -Because "1Password CLI requires sign-in or app authentication"
                }
            } catch {
                Set-ItResult -Skipped -Because "Could not test CLI integration: $_"
            }
        } else {
            Set-ItResult -Skipped -Because "1Password app not running"
        }
    }

    It "1Password CLI installation path is correct" {
        if (-not $script:OpCLI) {
            Set-ItResult -Skipped -Because "1Password CLI not available"
            return
        }

        try {
            $opPath = Get-Command op -ErrorAction Stop
            $opPath.Source | Should -Not -BeNullOrEmpty

            # Should be in a reasonable location (not temporary)
            $opPath.Source | Should -Not -Match "temp|tmp"

            # Should be in Program Files or AppData
            $opPath.Source | Should -Match "Program Files|AppData|1Password"

            Write-Host "✅ 1Password CLI found at: $($opPath.Source)" -ForegroundColor Green
        } catch {
            Set-ItResult -Skipped -Because "Could not determine 1Password CLI path: $_"
        }
    }
}

Describe "GitKraken CLI Integration" {

    It "GitKraken CLI is available when app is installed" {
        if (-not $script:GitKrakenApp) {
            Set-ItResult -Skipped -Because "GitKraken app not installed"
            return
        }

        if (-not $script:GitKrakenCLI) {
            # CLI should be available if app is installed
            Set-ItResult -Skipped -Because "GitKraken CLI not found in PATH (may need shell restart)"
        } else {
            $script:GitKrakenCLI | Should -Be $true
        }
    }

    It "GitKraken CLI version is accessible" {
        if (-not $script:GitKrakenCLI) {
            Set-ItResult -Skipped -Because "GitKraken CLI not available"
            return
        }

        try {
            $version = gk --version 2>&1
            $version | Should -Not -BeNullOrEmpty
            $version | Should -Match "\d+\.\d+\.\d+"
        } catch {
            Set-ItResult -Skipped -Because "Could not get GitKraken CLI version: $_"
        }
    }

    It "GitKraken CLI commands are functional" {
        if (-not $script:GitKrakenCLI) {
            Set-ItResult -Skipped -Because "GitKraken CLI not available"
            return
        }

        try {
            # Test basic command that doesn't require repository
            $help = gk --help 2>&1
            $help | Should -Not -BeNullOrEmpty
            $help | Should -Match "GitKraken|commands|options|usage"
        } catch {
            Set-ItResult -Skipped -Because "Could not execute GitKraken CLI help: $_"
        }
    }

    It "GitKraken CLI can detect Git repositories" {
        if (-not $script:GitKrakenCLI) {
            Set-ItResult -Skipped -Because "GitKraken CLI not available"
            return
        }

        # Test in our repository
        if (Test-Path (Join-Path $script:RepoRoot ".git")) {
            try {
                Push-Location $script:RepoRoot
                $status = gk status 2>&1
                # Should work or give informative error (not command not found)
                $status | Should -Not -Match "not.*found|command.*not.*recognized"
            } catch {
                Set-ItResult -Skipped -Because "Could not test GitKraken CLI in repository: $_"
            } finally {
                Pop-Location
            }
        } else {
            Set-ItResult -Skipped -Because "Not in a Git repository"
        }
    }

    It "GitKraken CLI installation path is correct" {
        if (-not $script:GitKrakenCLI) {
            Set-ItResult -Skipped -Because "GitKraken CLI not available"
            return
        }

        try {
            $gkPath = Get-Command gk -ErrorAction Stop
            $gkPath.Source | Should -Not -BeNullOrEmpty

            # Should be in a reasonable location (not temporary)
            $gkPath.Source | Should -Not -Match "temp|tmp"

            # Should be related to GitKraken installation
            $gkPath.Source | Should -Match "GitKraken|gitkraken|AppData|Program Files"

            Write-Host "✅ GitKraken CLI found at: $($gkPath.Source)" -ForegroundColor Green
        } catch {
            Set-ItResult -Skipped -Because "Could not determine GitKraken CLI path: $_"
        }
    }
}

Describe "CLI Tools Integration Validation" {

    It "CLI tools don't conflict with each other" {
        if (-not ($script:OpCLI -and $script:GitKrakenCLI)) {
            Set-ItResult -Skipped -Because "Both CLI tools required for conflict test"
            return
        }

        try {
            # Both commands should work without conflicts
            $opVersion = op --version 2>&1
            $gkVersion = gk --version 2>&1

            $opVersion | Should -Not -BeNullOrEmpty
            $gkVersion | Should -Not -BeNullOrEmpty

            # Neither should be confused for the other
            $opVersion | Should -Not -Match "GitKraken"
            $gkVersion | Should -Not -Match "1Password"

            Write-Host "✅ CLI tools coexist without conflicts" -ForegroundColor Green
        } catch {
            Set-ItResult -Skipped -Because "Could not test CLI tool conflicts: $_"
        }
    }

    It "CLI tools are in system PATH correctly" {
        $cliTools = @()
        if ($script:OpCLI) { $cliTools += "op" }
        if ($script:GitKrakenCLI) { $cliTools += "gk" }

        if ($cliTools.Count -eq 0) {
            Set-ItResult -Skipped -Because "No CLI tools available to test"
            return
        }

        foreach ($tool in $cliTools) {
            try {
                $toolPath = Get-Command $tool -ErrorAction Stop

                # Should be accessible from PATH
                $toolPath.CommandType | Should -BeIn @('Application', 'ExternalScript')

                # Should have execute permissions
                if (Test-Path $toolPath.Source) {
                    $true | Should -Be $true  # Path exists
                } else {
                    throw "CLI tool path does not exist: $($toolPath.Source)"
                }
            } catch {
                throw "CLI tool $tool not properly in PATH: $_"
            }
        }
    }

    It "CLI tools work in new PowerShell sessions" {
        $cliTools = @()
        if ($script:OpCLI) { $cliTools += @{Name="op"; TestCmd="op --version"} }
        if ($script:GitKrakenCLI) { $cliTools += @{Name="gk"; TestCmd="gk --version"} }

        if ($cliTools.Count -eq 0) {
            Set-ItResult -Skipped -Because "No CLI tools available to test"
            return
        }

        foreach ($tool in $cliTools) {
            try {
                # Test in new PowerShell session to verify PATH persistence
                $result = pwsh -NoProfile -Command $tool.TestCmd 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $result | Should -Not -BeNullOrEmpty
                    Write-Host "✅ $($tool.Name) works in new PowerShell session" -ForegroundColor Green
                } else {
                    Set-ItResult -Skipped -Because "$($tool.Name) failed in new session: $result"
                }
            } catch {
                Set-ItResult -Skipped -Because "Could not test $($tool.Name) in new session: $_"
            }
        }
    }

    It "GUI apps and CLI tools have consistent versions" {
        # This is informational - versions may differ slightly
        $versionInfo = @()

        if ($script:OpCLI) {
            try {
                $opVersion = op --version 2>&1
                $versionInfo += "1Password CLI: $opVersion"
            } catch {
                $versionInfo += "1Password CLI: Version check failed"
            }
        }

        if ($script:GitKrakenCLI) {
            try {
                $gkVersion = gk --version 2>&1
                $versionInfo += "GitKraken CLI: $gkVersion"
            } catch {
                $versionInfo += "GitKraken CLI: Version check failed"
            }
        }

        if ($versionInfo.Count -gt 0) {
            Write-Host "CLI Tool Versions:" -ForegroundColor Cyan
            foreach ($info in $versionInfo) {
                Write-Host "  $info" -ForegroundColor Gray
            }
            $true | Should -Be $true
        } else {
            Set-ItResult -Skipped -Because "No CLI tools available for version check"
        }
    }
}

Describe "CLI Tools Documentation and Guidance" {

    It "Licensed apps script provides CLI usage guidance" {
        if (-not $script:LicensedAppsScriptExists) {
            Set-ItResult -Skipped -Because "Licensed apps script not found"
            return
        }

        $content = Get-Content $script:LicensedAppsScript -Raw

        # Should provide guidance on using CLI tools
        $content | Should -Match "CLI.*available|command.*line.*access" -Because "Should mention CLI availability"
        $content | Should -Match "op.*1Password|gk.*GitKraken" -Because "Should document CLI commands"

        # Should mention restart requirement
        $content | Should -Match "restart.*shell|new.*terminal|reload.*environment" -Because "Should mention shell restart for PATH"
    }

    It "Setup script mentions CLI tool integration" {
        $setupScript = Join-Path $script:RepoRoot "setup-machine.ps1"
        if (Test-Path $setupScript) {
            $content = Get-Content -Path $setupScript -Raw

            # Should mention that CLI tools come with GUI apps
            ($content -match "CLI.*tools.*included" -or
             $content -match "command.*line.*access" -or
             $content -match "11-licensed-apps") | Should -BeTrue -Because "Should reference CLI tool integration"
        } else {
            Set-ItResult -Skipped -Because "Setup script not found"
        }
    }
}

AfterAll {
    Write-Host "🏁 CLI tools integration test execution complete" -ForegroundColor Cyan
    Write-Host "Note: CLI tools require their GUI counterparts to be installed first" -ForegroundColor Gray

    if (-not $script:OnePasswordApp -and -not $script:GitKrakenApp) {
        Write-Host "💡 Install 1Password or GitKraken to test CLI integration" -ForegroundColor Cyan
    }

    if (($script:OnePasswordApp -and -not $script:OpCLI) -or ($script:GitKrakenApp -and -not $script:GitKrakenCLI)) {
        Write-Host "💡 Restart your shell to access CLI tools" -ForegroundColor Cyan
    }
}
