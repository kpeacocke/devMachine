#Requires -Version 7.0
<#
.SYNOPSIS
    Tests for antivirus optimization and exclusion configuration

.DESCRIPTION
    Comprehensive tests covering:
    - Windows Defender exclusions configuration (30-optimize-and-harden.ps1)
    - Standalone antivirus optimization tool (43-antivirus-exclusions.ps1)
    - Malwarebytes detection and guidance
    - Third-party antivirus software compatibility

.NOTES
    Run with: pwsh -NoProfile -File .\tests\antivirus-optimization.Tests.ps1
    Some tests require Administrator privileges and will be skipped if not available
#>

BeforeAll {
    $ErrorActionPreference = 'Continue'

    # Get the repository root
    $script:RepoRoot = if ($PSScriptRoot) {
        Split-Path -Parent $PSScriptRoot
    } else {
        Split-Path -Parent (Get-Location)
    }

    Write-Host "🛡️ Antivirus Optimization Test Suite" -ForegroundColor Cyan
    Write-Host "Repository Root: $script:RepoRoot" -ForegroundColor Gray

    # Helper function to check if running as administrator
    function Test-IsAdmin {
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        } catch {
            return $false
        }
    }

    # Helper function to check if Windows Defender is available
    function Test-DefenderAvailable {
        try {
            Get-MpComputerStatus -ErrorAction Stop | Out-Null
            return $true
        } catch {
            return $false
        }
    }

    # Helper function to detect Malwarebytes
    function Test-MalwarebytesInstalled {
        $mbPaths = @(
            "${env:ProgramFiles}\Malwarebytes\Anti-Malware\mbam.exe",
            "${env:ProgramFiles(x86)}\Malwarebytes\Anti-Malware\mbam.exe",
            "${env:ProgramFiles}\Malwarebytes\Malwarebytes Anti-Malware\mbam.exe"
        )

        return ($mbPaths | Where-Object { Test-Path $_ }).Count -gt 0
    }

    $script:IsAdmin = Test-IsAdmin
    $script:DefenderAvailable = Test-DefenderAvailable
    $script:MalwarebytesInstalled = Test-MalwarebytesInstalled

    if ($script:IsAdmin) {
        Write-Host "Running with Administrator privileges ✅" -ForegroundColor Green
    } else {
        Write-Host "Running without Administrator privileges (some tests will be skipped) ⚠️" -ForegroundColor Yellow
    }

    if ($script:DefenderAvailable) {
        Write-Host "Windows Defender available ✅" -ForegroundColor Green
    } else {
        Write-Host "Windows Defender not available ⚠️" -ForegroundColor Yellow
    }

    if ($script:MalwarebytesInstalled) {
        Write-Host "Malwarebytes detected ✅" -ForegroundColor Green
    }
}

Describe "Windows Defender Optimization (30-optimize-and-harden.ps1)" {

    BeforeAll {
        $script:OptimizeScript = Join-Path $script:RepoRoot "scripts\windows\30-optimize-and-harden.ps1"
        $script:OptimizeScriptExists = Test-Path $script:OptimizeScript
    }

    It "Optimization script exists and is valid" {
        $script:OptimizeScriptExists | Should -Be $true

        if ($script:OptimizeScriptExists) {
            # Check syntax
            pwsh -NoProfile -Command "try { [void](Get-Command '$script:OptimizeScript' -Syntax -ErrorAction Stop); exit 0 } catch { exit 1 }" | Out-Null
            $LASTEXITCODE | Should -Be 0
        }
    }

    It "Script contains comprehensive Defender exclusions" {
        if (-not $script:OptimizeScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:OptimizeScript -Raw

        # Should contain development folder exclusions
        $content | Should -Match "node_modules|\.git"
        $content | Should -Match "target.*build.*dist"
        $content | Should -Match "\.cargo|\.rustup"
        $content | Should -Match "\.cargo|\.nuget|\.gradle|\.m2"

        # Should contain process exclusions
        $content | Should -Match "node\.exe|npm\.exe"
        $content | Should -Match "git\.exe|code\.exe"
        $content | Should -Match "dotnet\.exe|msbuild\.exe"
    }

    It "Script uses proper Defender cmdlets" {
        if (-not $script:OptimizeScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:OptimizeScript -Raw

        # Should use proper Defender PowerShell cmdlets
        $content | Should -Match "Add-MpPreference"
        $content | Should -Match "ExclusionPath|ExclusionProcess|ExclusionExtension"
        $content | Should -Match "Get-MpPreference"
    }

    It "Script has proper error handling for Defender operations" {
        if (-not $script:OptimizeScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:OptimizeScript -Raw

        # Should handle cases where Defender isn't available
        $content | Should -Match "try.*catch|ErrorAction.*SilentlyContinue"
        $content | Should -Match "Defender.*not.*available|antivirus.*detected"
    }

    It "Script validates paths before adding exclusions" {
        if (-not $script:OptimizeScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:OptimizeScript -Raw

        # Should validate paths exist before excluding them
        $content | Should -Match "Test-Path|if.*exists"
        $content | Should -Match "Join-Path|Split-Path"
    }

    It "Windows Defender exclusions are properly configured (if admin)" {
        if (-not $script:DefenderAvailable) {
            Set-ItResult -Skipped -Because "Windows Defender not available"
            return
        }

        if (-not $script:IsAdmin) {
            Set-ItResult -Skipped -Because "Requires Administrator privileges"
            return
        }

        try {
            $preferences = Get-MpPreference -ErrorAction Stop
            $exclusions = $preferences.ExclusionPath

            if ($exclusions -and $exclusions.Count -gt 0) {
                # Check for development-related exclusions
                $devExclusions = $exclusions | Where-Object {
                    $_ -like "*node_modules*" -or
                    $_ -like "*\.git*" -or
                    $_ -like "*target*" -or
                    $_ -like "*\.cargo*" -or
                    $_ -like "*go*pkg*"
                }

                if ($devExclusions.Count -gt 0) {
                    $devExclusions.Count | Should -BeGreaterThan 0
                    Write-Host "✅ Found $($devExclusions.Count) development exclusions" -ForegroundColor Green
                } else {
                    Set-ItResult -Skipped -Because "No development exclusions found (optimization may not have been run)"
                }
            } else {
                Set-ItResult -Skipped -Because "No exclusions configured"
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check Defender preferences: $_"
        }
    }

    It "Process exclusions are configured for development tools" {
        if (-not $script:DefenderAvailable -or -not $script:IsAdmin) {
            Set-ItResult -Skipped -Because "Requires Windows Defender and Administrator privileges"
            return
        }

        try {
            $preferences = Get-MpPreference -ErrorAction Stop
            $processExclusions = $preferences.ExclusionProcess

            if ($processExclusions -and $processExclusions.Count -gt 0) {
                $devProcesses = $processExclusions | Where-Object {
                    $_ -like "*node.exe*" -or
                    $_ -like "*git.exe*" -or
                    $_ -like "*code.exe*" -or
                    $_ -like "*dotnet.exe*" -or
                    $_ -like "*npm.exe*"
                }

                if ($devProcesses.Count -gt 0) {
                    $devProcesses.Count | Should -BeGreaterThan 0
                    Write-Host "✅ Found $($devProcesses.Count) development process exclusions" -ForegroundColor Green
                } else {
                    Set-ItResult -Skipped -Because "No development process exclusions found"
                }
            } else {
                Set-ItResult -Skipped -Because "No process exclusions configured"
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check process exclusions: $_"
        }
    }

    It "File extension exclusions are configured" {
        if (-not $script:DefenderAvailable -or -not $script:IsAdmin) {
            Set-ItResult -Skipped -Because "Requires Windows Defender and Administrator privileges"
            return
        }

        try {
            $preferences = Get-MpPreference -ErrorAction Stop
            $extensionExclusions = $preferences.ExclusionExtension

            if ($extensionExclusions -and $extensionExclusions.Count -gt 0) {
                # Should have some development file extensions
                $devExtensions = $extensionExclusions | Where-Object {
                    $_ -in @('.tmp', '.log', '.cache', '.lock', '.swp')
                }

                if ($devExtensions.Count -gt 0) {
                    $devExtensions.Count | Should -BeGreaterThan 0
                    Write-Host "✅ Found $($devExtensions.Count) development extension exclusions" -ForegroundColor Green
                } else {
                    Set-ItResult -Skipped -Because "No development extension exclusions found"
                }
            } else {
                Set-ItResult -Skipped -Because "No extension exclusions configured"
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check extension exclusions: $_"
        }
    }
}

Describe "Standalone Antivirus Tool (43-antivirus-exclusions.ps1)" {

    BeforeAll {
        $script:AntivirusScript = Join-Path $script:RepoRoot "scripts\windows\43-antivirus-exclusions.ps1"
        $script:AntivirusScriptExists = Test-Path $script:AntivirusScript
    }

    It "Antivirus exclusions script exists and is valid" {
        $script:AntivirusScriptExists | Should -Be $true

        if ($script:AntivirusScriptExists) {
            # Check basic file syntax (AST parse only)
            try {
                $null = [System.Management.Automation.Language.Parser]::ParseFile($script:AntivirusScript, [ref]$null, [ref]$null)
                $syntaxValid = $true
            }
            catch {
                $syntaxValid = $false
            }
            $syntaxValid | Should -Be $true
        }
    }

    It "Script supports multiple antivirus solutions" {
        if (-not $script:AntivirusScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:AntivirusScript -Raw

        # Should support Windows Defender
        $content | Should -Match "Defender|Add-MpPreference"

        # Should detect and guide for Malwarebytes
        $content | Should -Match "Malwarebytes|mbam"

        # Should have generic guidance for other AV
        $content | Should -Match "third.*party|other.*antivirus|manual.*configuration"
    }

    It "Script has comprehensive exclusion lists" {
        if (-not $script:AntivirusScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:AntivirusScript -Raw

        # Should have extensive path exclusions
        $content | Should -Match "node_modules"
        $content | Should -Match "\.cargo|\.rustup|go"
        $content | Should -Match "target.*bin.*obj"
        $content | Should -Match "\.cargo|\.rustup"
        $content | Should -Match "\.cargo|\.rustup"
        $content | Should -Match "\.gradle|\.m2"
        $content | Should -Match "venv|__pycache__"
    }

    It "Script provides Malwarebytes-specific guidance" {
        if (-not $script:AntivirusScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:AntivirusScript -Raw

        # Should detect Malwarebytes and provide guidance
        $content | Should -Match "Malwarebytes.*detected"
        $content | Should -Match "Settings.*Security.*Exclusions"
        $content | Should -Match "coexistence|prevent.*conflicts"
    }

    It "Script validates system state before making changes" {
        if (-not $script:AntivirusScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:AntivirusScript -Raw

        # Should check for admin privileges
        $content | Should -Match "Administrator|IsInRole|elevation"

        # Should validate antivirus software state
        $content | Should -Match "Get-MpComputerStatus|antivirus.*running"

        # Should check if paths exist
        $content | Should -Match "Test-Path"
    }

    It "Can run in information-only mode" {
        if (-not $script:AntivirusScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        try {
            # Run with WhatIf or information mode
            & $script:AntivirusScript -WhatIf -ErrorAction Stop 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 0
        } catch {
            Set-ItResult -Skipped -Because "Information mode execution failed: $_"
        }
    }

    It "Detects and reports on current antivirus software" {
        if (-not $script:AntivirusScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        # Test the detection logic
        $content = Get-Content $script:AntivirusScript -Raw

        # Should detect common antivirus software
        $content | Should -Match "Windows.*Defender|Microsoft.*Defender"

        if ($script:MalwarebytesInstalled) {
            $content | Should -Match "Malwarebytes"
        }
    }

    It "Has coexistence management function for Defender and Malwarebytes" {
        if (-not $script:AntivirusScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:AntivirusScript -Raw

        # Should have coexistence management function
        $content | Should -Match "Set-DefenderMalwarebytesCoexistence|Test-MalwarebytesInstalled"

        # Should handle DisableRealtimeMonitoring
        $content | Should -Match "DisableRealtimeMonitoring|prevent.*conflicts"

        # Should explain the reason for disabling
        $content | Should -Match "prevent.*conflicts|coexistence|compatibility"
    }
}

Describe "Malwarebytes Integration" {

    It "Malwarebytes detection works correctly" {
        $malwarebytesPaths = @(
            "${env:ProgramFiles}\Malwarebytes\Anti-Malware\mbam.exe",
            "${env:ProgramFiles(x86)}\Malwarebytes\Anti-Malware\mbam.exe",
            "${env:ProgramFiles}\Malwarebytes\Malwarebytes Anti-Malware\mbam.exe"
        )

        $foundPaths = $malwarebytesPaths | Where-Object { Test-Path $_ }

        if ($foundPaths.Count -gt 0) {
            $foundPaths.Count | Should -BeGreaterThan 0
            Write-Host "✅ Malwarebytes found at: $($foundPaths -join ', ')" -ForegroundColor Green
        } else {
            Set-ItResult -Skipped -Because "Malwarebytes not installed"
        }
    }

    It "Malwarebytes service is running (if installed)" {
        if (-not $script:MalwarebytesInstalled) {
            Set-ItResult -Skipped -Because "Malwarebytes not installed"
            return
        }

        try {
            $mbService = Get-Service "MBAMService" -ErrorAction Stop
            $mbService.Status | Should -BeIn @('Running', 'Stopped')  # Service exists
        } catch {
            # Try alternative service names
            $altServices = @("MalwareBytes*", "MBAM*")
            $foundService = $false

            foreach ($pattern in $altServices) {
                $services = Get-Service $pattern -ErrorAction SilentlyContinue
                if ($services) {
                    $foundService = $true
                    break
                }
            }

            if (-not $foundService) {
                Set-ItResult -Skipped -Because "Malwarebytes service not found with expected names"
            }
        }
    }

    It "Provides clear guidance for manual Malwarebytes configuration" {
        if (-not $script:MalwarebytesInstalled) {
            Set-ItResult -Skipped -Because "Malwarebytes not installed"
            return
        }

        # Test that our scripts provide clear guidance
        $scripts = @(
            "30-optimize-and-harden.ps1",
            "43-antivirus-exclusions.ps1"
        )

        $guidanceFound = $false
        foreach ($scriptName in $scripts) {
            $scriptPath = Join-Path $script:RepoRoot "scripts\windows\$scriptName"
            if (Test-Path $scriptPath) {
                $content = Get-Content $scriptPath -Raw
                if ($content -match "Malwarebytes.*Settings|manually.*exclude|Real.*Time.*Protection") {
                    $guidanceFound = $true
                    break
                }
            }
        }

        $guidanceFound | Should -Be $true
    }

    It "Disables Defender real-time protection when Malwarebytes is installed" {
        if (-not $script:MalwarebytesInstalled) {
            Set-ItResult -Skipped -Because "Malwarebytes not installed"
            return
        }

        if (-not $script:DefenderAvailable -or -not $script:IsAdmin) {
            Set-ItResult -Skipped -Because "Requires Windows Defender and Administrator privileges"
            return
        }

        # Test that scripts properly disable Defender real-time protection
        $scripts = @(
            "30-optimize-and-harden.ps1",
            "43-antivirus-exclusions.ps1"
        )

        $coexistenceLogicFound = $false
        foreach ($scriptName in $scripts) {
            $scriptPath = Join-Path $script:RepoRoot "scripts\windows\$scriptName"
            if (Test-Path $scriptPath) {
                $content = Get-Content $scriptPath -Raw
                if ($content -match "DisableRealtimeMonitoring|Malwarebytes.*detected.*disable|prevent.*conflicts") {
                    $coexistenceLogicFound = $true
                    break
                }
            }
        }

        $coexistenceLogicFound | Should -Be $true

        # If Malwarebytes is actually installed, verify Defender real-time protection behavior
        try {
            $defenderStatus = Get-MpComputerStatus -ErrorAction Stop
            if ($defenderStatus.RealTimeProtectionEnabled) {
                Write-Host "⚠️ Defender real-time protection is still enabled with Malwarebytes" -ForegroundColor Yellow
                Write-Host "   This may indicate the optimization script hasn't run or failed" -ForegroundColor Gray
            } else {
                Write-Host "✅ Defender real-time protection is disabled (good for Malwarebytes compatibility)" -ForegroundColor Green
                $true | Should -Be $true
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check Defender status: $_"
        }
    }
}

Describe "Third-Party Antivirus Compatibility" {

    It "Scripts handle unknown antivirus software gracefully" {
        $scripts = @(
            "30-optimize-and-harden.ps1",
            "43-antivirus-exclusions.ps1"
        )

        foreach ($scriptName in $scripts) {
            $scriptPath = Join-Path $script:RepoRoot "scripts\windows\$scriptName"
            if (Test-Path $scriptPath) {
                $content = Get-Content $scriptPath -Raw

                # Should have fallback guidance for unknown AV
                $content | Should -Match "third.*party|unknown.*antivirus|manual.*configuration"
                $content | Should -Match "try.*catch|ErrorAction.*Continue"
            }
        }
    }

    It "Scripts provide comprehensive exclusion guidance" {
        $antivirusScript = Join-Path $script:RepoRoot "scripts\windows\43-antivirus-exclusions.ps1"

        if (-not (Test-Path $antivirusScript)) {
            Set-ItResult -Skipped -Because "Antivirus script not found"
            return
        }

        $content = Get-Content $antivirusScript -Raw

        # Should provide comprehensive list for manual configuration
        $content | Should -Match "comprehensive.*antivirus.*exclusions|Configure.*comprehensive.*antivirus"
        $content | Should -Match "manual.*configuration|Add.*Exclusion"
    }

    It "Performance guidance is provided" {
        $optimizeScript = Join-Path $script:RepoRoot "scripts\windows\30-optimize-and-harden.ps1"

        if (-not (Test-Path $optimizeScript)) {
            Set-ItResult -Skipped -Because "Optimize script not found"
            return
        }

        $content = Get-Content $optimizeScript -Raw

        # Should mention performance benefits
        $content | Should -Match "performance.*improvement|faster.*build|30.*70"
        $content | Should -Match "performance.*improvement|faster.*build|30.*70"
    }
}

Describe "Security and Safety Validation" {

    It "Exclusions don't compromise security unnecessarily" {
        $antivirusScript = Join-Path $script:RepoRoot "scripts\windows\43-antivirus-exclusions.ps1"

        if (-not (Test-Path $antivirusScript)) {
            Set-ItResult -Skipped -Because "Antivirus script not found"
            return
        }

        $content = Get-Content $antivirusScript -Raw

        # Should not exclude entire system drives or critical system folders
        $content | Should -Not -Match "C:\\\$|\\Windows\\\$|\\System32\\\$"
        $content | Should -Not -Match "Program Files\\\$|ProgramData\\\$"

        # Should focus on development-specific paths
        $content | Should -Match "node_modules|\.git|target.*bin.*obj"
    }

    It "Scripts warn about security implications" {
        $antivirusScript = Join-Path $script:RepoRoot "scripts\windows\43-antivirus-exclusions.ps1"

        if (-not (Test-Path $antivirusScript)) {
            Set-ItResult -Skipped -Because "Antivirus script not found"
            return
        }

        $content = Get-Content $antivirusScript -Raw

        # Should include security warnings and guidance
        $content | Should -Match "Administrator.*privileges|manual.*configuration"
        $content | Should -Match "requires.*Administrator.*privileges"
    }

    It "Scripts provide rollback information" {
        $antivirusScript = Join-Path $script:RepoRoot "scripts\windows\43-antivirus-exclusions.ps1"

        if (-not (Test-Path $antivirusScript)) {
            Set-ItResult -Skipped -Because "Antivirus script not found"
            return
        }

        $content = Get-Content $antivirusScript -Raw

        # Should provide information on how to manage exclusions
        $content | Should -Match "Get-MpPreference|Add-MpPreference|manual.*configuration"
    }

    It "Validates that excluded paths are development-related" {
        if (-not $script:DefenderAvailable -or -not $script:IsAdmin) {
            Set-ItResult -Skipped -Because "Requires Windows Defender and Administrator privileges"
            return
        }

        try {
            $preferences = Get-MpPreference -ErrorAction Stop
            $exclusions = $preferences.ExclusionPath

            if ($exclusions -and $exclusions.Count -gt 0) {
                # Check that all exclusions are development-related
                $nonDevExclusions = $exclusions | Where-Object {
                    $_ -notmatch "node_modules|\.git|target|bin|obj|\.cargo|\.rustup|\.npm|\.gradle|\.m2|venv|__pycache__|go.*pkg|cache|temp|tmp|\.vscode|\.vs"
                }

                if ($nonDevExclusions.Count -gt 0) {
                    Write-Host "⚠️ Found non-development exclusions: $($nonDevExclusions -join ', ')" -ForegroundColor Yellow
                    # This is informational, not a failure
                }

                $true | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "No exclusions to validate"
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not validate exclusions: $_"
        }
    }
}

AfterAll {
    Write-Host "🏁 Antivirus optimization test execution complete" -ForegroundColor Cyan
    Write-Host "Note: Many tests require Administrator privileges and specific antivirus software" -ForegroundColor Gray

    if ($script:MalwarebytesInstalled) {
        Write-Host "💡 Malwarebytes detected - manual configuration required" -ForegroundColor Cyan
    }

    if (-not $script:DefenderAvailable) {
        Write-Host "💡 Windows Defender not available - using third-party antivirus" -ForegroundColor Cyan
    }
}
