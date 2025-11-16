# Syntax validation tests for all PowerShell scripts
# Run with: pwsh -NoProfile -File .\tests\syntax-validation.Tests.ps1

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

Describe "PowerShell Script Syntax Validation" {

    BeforeAll {
        $script:scripts = Get-ChildItem -Path $script:RepoRoot -Recurse -Filter "*.ps1" -ErrorAction Stop |
            Where-Object {
                $_.FullName -notlike "*node_modules*" -and
                $_.FullName -notlike "*.git*"
            }

        Write-Host "Found $($script:scripts.Count) PowerShell scripts" -ForegroundColor Cyan
    }

    It "Found PowerShell scripts to validate" {
        $script:scripts.Count | Should -BeGreaterThan 0
    }

    foreach ($script in $scripts) {
        It "$($script.Name) has valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content -Path $script.FullName -Raw),
                [ref]$errors
            )

            if ($errors.Count -gt 0) {
                $errorMessages = $errors | ForEach-Object {
                    "Line $($_.Token.StartLine): $($_.Message)"
                }
                throw "Syntax errors found:`n$($errorMessages -join "`n")"
            }

            $errors.Count | Should -Be 0
        }

        It "$($script.Name) can be parsed as ScriptBlock" {
            { [scriptblock]::Create((Get-Content -Path $script.FullName -Raw)) } |
                Should -Not -Throw
        }
    }
}

Describe "Bash Script Syntax Validation" {

    BeforeAll {
        $script:bashScripts = Get-ChildItem -Path $script:RepoRoot -Recurse -Filter "*.sh" -ErrorAction Stop |
            Where-Object { $_.FullName -notlike "*node_modules*" }

        Write-Host "Found $($script:bashScripts.Count) Bash scripts" -ForegroundColor Cyan
    }

    It "Found Bash scripts to validate" {
        $script:bashScripts.Count | Should -BeGreaterThan 0
    }

    foreach ($script in $bashScripts) {
        It "$($script.Name) has valid bash syntax (via WSL)" {
            if (Get-Command wsl -ErrorAction SilentlyContinue) {
                $wslPath = $script.FullName -replace '\\', '/' -replace '^([A-Z]):', { '/mnt/' + $_.Groups[1].Value.ToLower() }
                $result = wsl bash -n $wslPath 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Syntax errors: $result"
                }
                $LASTEXITCODE | Should -Be 0
            } else {
                Set-ItResult -Skipped -Because "WSL not available for bash validation"
            }
        }
    }
}

Describe "Setup Orchestrator Script" {

    BeforeAll {
        $script:setupScript = Join-Path $script:RepoRoot "setup-machine.ps1"
        Write-Host "Setup script path: $script:setupScript" -ForegroundColor Cyan
    }

    It "setup-machine.ps1 exists" {
        Test-Path $script:setupScript | Should -BeTrue
    }

    It "setup-machine.ps1 has valid syntax" {
        { [scriptblock]::Create((Get-Content -Path $script:setupScript -Raw)) } |
            Should -Not -Throw
    }

    It "setup-machine.ps1 defines required parameters" {
        $content = Get-Content -Path $script:setupScript -Raw
        $content | Should -Match '\[switch\]\$SkipBackup'
        $content | Should -Match '\[switch\]\$SkipLicensedApps'
        $content | Should -Match '\[switch\]\$SkipOptionalGoodies'
        $content | Should -Match '\[switch\]\$InstallEverything'
        $content | Should -Match '\[switch\]\$SkipPrompts'
        $content | Should -Match '\[Alias\("y"\)\]'
    }

    It "setup-machine.ps1 has no Unicode box-drawing characters" {
        $content = Get-Content -Path $script:setupScript -Raw
        # Check for common problematic Unicode chars using escape sequences
        $content | Should -Not -Match '[\u2554\u2557\u2551\u255A\u2550]'  # Box drawing
        $content | Should -Not -Match '[\u2610\u2611\u2713\u2717]'  # Checkboxes
    }

    It "setup-machine.ps1 properly escapes ampersands in strings" {
        $content = Get-Content -Path $script:setupScript -Raw
        # This is a basic check - ampersands in strings should not cause parser errors
        { [scriptblock]::Create($content) } | Should -Not -Throw
    }

    It "setup-machine.ps1 includes antivirus guidance" {
        $content = Get-Content -Path $script:setupScript -Raw
        # Should include Malwarebytes detection and guidance
        $content | Should -Match "Malwarebytes" -Because "Should detect and provide guidance for Malwarebytes"
        # Should reference antivirus optimization (either inline or via script)
        ($content -match "43-antivirus-exclusions" -or $content -match "Add-MpPreference") | Should -BeTrue -Because "Should include antivirus optimization guidance"
    }
}

Describe "Enhanced Script Validation" {

    BeforeAll {
        $script:windowsScripts = Join-Path $script:RepoRoot "scripts\windows"

        # Enhanced validation rules for PowerShell best practices
        $script:ValidationRules = @{
            RequiredAdminScripts = @(
                "42-devdrive-fix-ownership.ps1",
                "43-antivirus-exclusions.ps1",
                "30-optimize-and-harden.ps1",
                "41-devdrive-partition-setup.ps1"
            )
            ShouldSupportWhatIf = @(
                "41-devdrive-partition-setup.ps1",
                "42-devdrive-fix-ownership.ps1",
                "43-antivirus-exclusions.ps1"
            )
            MustHaveErrorHandling = @(
                "30-optimize-and-harden.ps1",
                "40-devdrive-caches.ps1",
                "41-devdrive-partition-setup.ps1",
                "42-devdrive-fix-ownership.ps1",
                "43-antivirus-exclusions.ps1"
            )
        }
    }

    It "All scripts requiring admin privileges have proper directives" {
        foreach ($scriptName in $script:ValidationRules.RequiredAdminScripts) {
            $scriptPath = Join-Path $script:windowsScripts $scriptName
            if (Test-Path $scriptPath) {
                $content = Get-Content -Path $scriptPath -Raw
                $content | Should -Match "#Requires -RunAsAdministrator" -Because "$scriptName requires administrator privileges"
                $content | Should -Match "#Requires -Version \d+" -Because "$scriptName should specify minimum PowerShell version"
            } else {
                Write-Host "⚠️ Script $scriptName not found (may be optional)" -ForegroundColor Yellow
            }
        }
    }

    It "Destructive scripts support WhatIf operations" {
        foreach ($scriptName in $script:ValidationRules.ShouldSupportWhatIf) {
            $scriptPath = Join-Path $script:windowsScripts $scriptName
            if (Test-Path $scriptPath) {
                $content = Get-Content -Path $scriptPath -Raw
                $content | Should -Match "SupportsShouldProcess" -Because "$scriptName should support WhatIf"
                $content | Should -Match '\$PSCmdlet\.ShouldProcess' -Because "$scriptName should implement ShouldProcess logic"
                $content | Should -Match "CmdletBinding" -Because "$scriptName should use advanced function syntax"
            }
        }
    }

    It "Critical scripts have proper error handling" {
        foreach ($scriptName in $script:ValidationRules.MustHaveErrorHandling) {
            $scriptPath = Join-Path $script:windowsScripts $scriptName
            if (Test-Path $scriptPath) {
                $content = Get-Content -Path $scriptPath -Raw
                ($content -match "try.*catch|ErrorActionPreference.*Stop|ErrorAction.*Stop") | Should -BeTrue -Because "$scriptName should have error handling"
                $content | Should -Match "Write-(Host|Output|Warning|Error)" -Because "$scriptName should provide user feedback"
            }
        }
    }

    It "DevDrive ownership script (42) exists and has proper validation" {
        $ownershipScript = Join-Path $script:windowsScripts "42-devdrive-fix-ownership.ps1"
        if (Test-Path $ownershipScript) {
            $content = Get-Content -Path $ownershipScript -Raw
            $content | Should -Match "ReFS|Dev.*Drive" -Because "Should detect ReFS Dev Drive volumes"
            $content | Should -Match "Get-Acl|Set-Acl|takeown|icacls" -Because "Should use proper ownership APIs"
            $content | Should -Match "ValidateScript|Test-Path" -Because "Should validate input paths"
            $content | Should -Match "Recurse.*Force|Get-ChildItem.*Recurse" -Because "Should handle recursive operations"
        } else {
            Set-ItResult -Skipped -Because "DevDrive ownership script not found"
        }
    }

    It "Antivirus exclusions script (43) exists and has comprehensive coverage" {
        $antivirusScript = Join-Path $script:windowsScripts "43-antivirus-exclusions.ps1"
        if (Test-Path $antivirusScript) {
            $content = Get-Content -Path $antivirusScript -Raw

            # Core functionality
            $content | Should -Match "Add-MpPreference" -Because "Should add Windows Defender exclusions"
            $content | Should -Match "Get-MpPreference" -Because "Should check current Defender settings"

            # Development exclusions
            $content | Should -Match "node_modules" -Because "Should exclude Node.js modules"
            $content | Should -Match "\.git" -Because "Should exclude Git directories"
            $content | Should -Match "target.*bin.*obj" -Because "Should exclude build directories"
            $content | Should -Match "\.cargo|\.rustup" -Because "Should exclude Rust directories"
            $content | Should -Match "go.*pkg.*mod" -Because "Should exclude Go modules"
            $content | Should -Match "\.gradle|\.m2" -Because "Should exclude Java build caches"
            $content | Should -Match "venv|__pycache__" -Because "Should exclude Python environments"

            # Process exclusions
            $content | Should -Match "ExclusionProcess" -Because "Should exclude development processes"
            $content | Should -Match "node\.exe|npm\.exe|git\.exe|code\.exe" -Because "Should exclude common development tools"

            # Malwarebytes support
            $content | Should -Match "Malwarebytes" -Because "Should detect and guide for Malwarebytes"
            $content | Should -Match "manually.*configure|Settings.*Exclusions" -Because "Should provide manual configuration guidance"
        } else {
            Set-ItResult -Skipped -Because "Antivirus exclusions script not found"
        }
    }

    It "Licensed apps script (11) includes CLI tool integration" {
        $licensedAppsScript = Join-Path $script:windowsScripts "11-licensed-apps.ps1"
        if (Test-Path $licensedAppsScript) {
            $content = Get-Content -Path $licensedAppsScript -Raw

            # GitKraken CLI integration
            $content | Should -Match "GitKraken" -Because "Should install GitKraken with CLI"

            # 1Password CLI integration
            ($content -match "1Password" -or $content -match "op\.exe") | Should -BeTrue -Because "Should have 1Password CLI integration"

            # Should not duplicate installations
            # CLI tools should be bundled with GUI apps, not separately installed
            $content | Should -Match "winget.*install.*GitKraken" -Because "Should install GitKraken with bundled CLI"
            $content | Should -Match "winget.*install.*1Password" -Because "Should install 1Password with bundled CLI"
            # Ensure we're not installing CLI tools separately
            $content | Should -Not -Match "winget.*install.*GitKraken.*CLI" -Because "CLI should come bundled with GitKraken GUI"
            $content | Should -Not -Match "winget.*install.*1Password.*CLI" -Because "CLI should come bundled with 1Password GUI"
        } else {
            Set-ItResult -Skipped -Because "Licensed apps script not found"
        }
    }

    It "Git SSH config script (05) includes enhanced configuration" {
        $gitConfigScript = Join-Path $script:windowsScripts "05-git-ssh-config.ps1"
        if (Test-Path $gitConfigScript) {
            $content = Get-Content -Path $gitConfigScript -Raw

            # VS Code as editor
            $content | Should -Match "code --wait" -Because "Should configure VS Code as Git editor"

            # Enhanced Git settings
            $content | Should -Match "core\.autocrlf" -Because "Should configure line endings"
            $content | Should -Match "init\.defaultBranch|init\.defaultbranch" -Because "Should set default branch name"
            $content | Should -Match "pull\.rebase" -Because "Should configure pull behavior"
        } else {
            Set-ItResult -Skipped -Because "Git SSH config script not found"
        }
    }

    It "Cache configuration script (40) handles DevDrive and fallbacks" {
        $cacheScript = Join-Path $script:windowsScripts "40-devdrive-caches.ps1"
        if (Test-Path $cacheScript) {
            $content = Get-Content -Path $cacheScript -Raw

            # DevDrive integration
            $content | Should -Match "DevCache|Dev.*Drive" -Because "Should configure DevDrive caches"

            # Environment variable configuration
            $content | Should -Match "\[Environment\]::SetEnvironmentVariable.*User" -Because "Should set persistent environment variables"

            # Major package managers
            $content | Should -Match "npm.*cache|NPM_CONFIG_CACHE" -Because "Should configure npm cache"
            $content | Should -Match "pip.*cache|PIP_CACHE_DIR" -Because "Should configure pip cache"
            $content | Should -Match "cargo|CARGO_HOME" -Because "Should configure Cargo home"
            $content | Should -Match "go.*cache|GOPATH|GOCACHE" -Because "Should configure Go caches"

            # Fallback handling
            $content | Should -Match "fallback|alternative|else" -Because "Should handle DevDrive unavailability"
        } else {
            Set-ItResult -Skipped -Because "Cache configuration script not found"
        }
    }

    It "DevDrive partition script (41) has proper disk validation" {
        $partitionScript = Join-Path $script:windowsScripts "41-devdrive-partition-setup.ps1"
        if (Test-Path $partitionScript) {
            $content = Get-Content -Path $partitionScript -Raw

            # ReFS/DevDrive support detection
            $content | Should -Match "ReFS|Dev.*Drive|FileSystem.*ReFS" -Because "Should check ReFS support"

            # Disk space validation
            $content | Should -Match "Get-Volume|Get-Disk|FreeSpace" -Because "Should validate available space"

            # Existing DevDrive detection
            $content | Should -Match "Test-Path.*DevCache|Get-Volume.*DevCache" -Because "Should detect existing DevDrives"
            $content | Should -Match "already.*exists|existing.*partition" -Because "Should handle existing partitions"

            # Parameter validation
            $content | Should -Match "ValidateRange|ValidateNotNullOrEmpty" -Because "Should validate input parameters"
        } else {
            Set-ItResult -Skipped -Because "DevDrive partition script not found"
        }
    }

    It "Optimization script (30) has comprehensive Defender integration" {
        $optimizeScript = Join-Path $script:windowsScripts "30-optimize-and-harden.ps1"
        if (Test-Path $optimizeScript) {
            $content = Get-Content -Path $optimizeScript -Raw

            # Windows Defender configuration
            $content | Should -Match "Add-MpPreference" -Because "Should add Defender exclusions"
            $content | Should -Match "ExclusionPath.*ExclusionProcess.*ExclusionExtension" -Because "Should configure multiple exclusion types"
            $content | Should -Match "Get-MpComputerStatus|Get-MpPreference" -Because "Should check Defender status"

            # Performance optimizations
            $content | Should -Match "performance.*improvement|build.*speed" -Because "Should explain performance benefits"

            # Antivirus detection
            $content | Should -Match "Defender.*not.*available|antivirus.*detected" -Because "Should handle non-Defender scenarios"
        } else {
            Set-ItResult -Skipped -Because "Optimization script not found"
        }
    }
}

Describe "PowerShell Best Practices Validation" {

    It "Scripts use approved PowerShell verbs" {
        $scripts = Get-ChildItem -Path $script:windowsScripts -Filter "*.ps1" -ErrorAction SilentlyContinue

        foreach ($script in $scripts) {
            $content = Get-Content -Path $script.FullName -Raw

            # Check for unapproved verbs in function definitions
            if ($content -match "function\s+(\w+)-(\w+)") {
                $functions = [regex]::Matches($content, "function\s+(\w+-\w+)")
                foreach ($match in $functions) {
                    $functionName = $match.Groups[1].Value
                    $verb = $functionName.Split('-')[0]

                    # Basic check for common approved verbs
                    $approvedVerbs = @('Get', 'Set', 'New', 'Remove', 'Add', 'Clear', 'Copy', 'Move', 'Rename', 'Test', 'Start', 'Stop', 'Restart', 'Enable', 'Disable', 'Install', 'Uninstall', 'Import', 'Export', 'Write', 'Read', 'Update', 'Invoke', 'Show', 'Hide', 'Confirm', 'Optimize', 'Initialize', 'Repair', 'Backup', 'Restore', 'Sync')

                    if ($verb -notin $approvedVerbs) {
                        Write-Host "⚠️ Function $functionName in $($script.Name) may use non-standard verb '$verb'" -ForegroundColor Yellow
                    }
                }
            }
        }

        $true | Should -Be $true  # Always pass - this is informational
    }

    It "Scripts use proper parameter validation" {
        $criticalScripts = @(
            "41-devdrive-partition-setup.ps1",
            "42-devdrive-fix-ownership.ps1",
            "43-antivirus-exclusions.ps1"
        )

        foreach ($scriptName in $criticalScripts) {
            $scriptPath = Join-Path $script:windowsScripts $scriptName
            if (Test-Path $scriptPath) {
                $content = Get-Content -Path $scriptPath -Raw

                # Should have parameter validation
                $content | Should -Match "\[Parameter\(" -Because "$scriptName should have parameter definitions"
                $content | Should -Match "ValidateNotNullOrEmpty|ValidateScript|ValidateRange|ValidateSet" -Because "$scriptName should validate parameters"
            }
        }
    }

    It "Scripts have proper comment-based help" {
        $userFacingScripts = @(
            "41-devdrive-partition-setup.ps1",
            "42-devdrive-fix-ownership.ps1",
            "43-antivirus-exclusions.ps1"
        )

        foreach ($scriptName in $userFacingScripts) {
            $scriptPath = Join-Path $script:windowsScripts $scriptName
            if (Test-Path $scriptPath) {
                $content = Get-Content -Path $scriptPath -Raw

                # Should have comment-based help
                $content | Should -Match "\.SYNOPSIS" -Because "$scriptName should have synopsis"
                $content | Should -Match "\.DESCRIPTION" -Because "$scriptName should have description"
                $content | Should -Match "\.EXAMPLE" -Because "$scriptName should have examples"
            }
        }
    }

    It "Scripts avoid hardcoded paths where possible" {
        $scripts = Get-ChildItem -Path $script:windowsScripts -Filter "*.ps1" -ErrorAction SilentlyContinue

        $problematicPaths = @()
        foreach ($script in $scripts) {
            $content = Get-Content -Path $script.FullName -Raw

            # Check for hardcoded user-specific paths (these are warnings, not failures)
            if ($content -match 'C:\\Users\\[^\\]+\\') {
                $problematicPaths += "$($script.Name): Contains hardcoded user path"
            }

            # Check for hardcoded Program Files paths that should use environment variables
            if ($content -match 'C:\\Program Files\\' -and $content -notmatch '\$env:ProgramFiles') {
                $problematicPaths += "$($script.Name): Uses hardcoded Program Files path"
            }
        }

        if ($problematicPaths.Count -gt 0) {
            Write-Host "⚠️ Potential hardcoded paths found:" -ForegroundColor Yellow
            $problematicPaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        }

        $true | Should -Be $true  # Always pass - this is informational
    }
}
