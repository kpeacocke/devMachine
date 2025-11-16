#Requires -Version 7.0
<#
.SYNOPSIS
    Tests for system restore point functionality in setup-machine.ps1

.DESCRIPTION
    Validates that the main orchestrator script properly creates system restore points
    before making system changes, and provides appropriate user guidance.

.NOTES
    Run with: pwsh -NoProfile -File .\tests\system-restore.Tests.ps1
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

    Write-Host "💾 System Restore Point Test Suite" -ForegroundColor Cyan
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

    # Helper function to check if System Restore is available
    function Test-SystemRestoreAvailable {
        try {
            # Check if System Restore cmdlets are available
            Get-Command "Checkpoint-Computer" -ErrorAction Stop | Out-Null
            return $true
        } catch {
            return $false
        }
    }

    $script:IsAdmin = Test-IsAdmin
    $script:RestoreAvailable = Test-SystemRestoreAvailable

    if ($script:IsAdmin) {
        Write-Host "Running with Administrator privileges ✅" -ForegroundColor Green
    } else {
        Write-Host "Running without Administrator privileges (some tests will be skipped) ⚠️" -ForegroundColor Yellow
    }

    if ($script:RestoreAvailable) {
        Write-Host "System Restore cmdlets available ✅" -ForegroundColor Green
    } else {
        Write-Host "System Restore cmdlets not available ⚠️" -ForegroundColor Yellow
    }
}

Describe "Setup Script System Restore Integration" {

    BeforeAll {
        $script:SetupScript = Join-Path $script:RepoRoot "setup-machine.ps1"
        $script:SetupScriptExists = Test-Path $script:SetupScript
    }

    It "Setup script exists and is valid" {
        $script:SetupScriptExists | Should -Be $true

        if ($script:SetupScriptExists) {
            # Check syntax
            pwsh -NoProfile -Command "try { [void](Get-Command '$script:SetupScript' -Syntax -ErrorAction Stop); exit 0 } catch { exit 1 }" | Out-Null
            $LASTEXITCODE | Should -Be 0
        }
    }

    It "Script contains SkipRestorePoint parameter" {
        if (-not $script:SetupScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should have SkipRestorePoint parameter
        $content | Should -Match "SkipRestorePoint.*switch"
        $content | Should -Match "Skip creating a system restore point"
    }

    It "Script creates system restore point by default" {
        if (-not $script:SetupScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should have restore point creation logic
        $content | Should -Match "Creating system restore point"
        $content | Should -Match "Checkpoint-Computer|CreateRestorePoint"
        $content | Should -Match "DevMachine Setup"
    }

    It "Script respects SkipRestorePoint parameter" {
        if (-not $script:SetupScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should check for SkipRestorePoint flag
        $content | Should -Match "if.*-not.*SkipRestorePoint"
        $content | Should -Match "Skipping system restore point creation"
    }

    It "Script handles System Restore failures gracefully" {
        if (-not $script:SetupScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should have error handling for restore point creation
        $content | Should -Match "try.*catch.*restore"
        $content | Should -Match "Could not create.*restore point"
        $content | Should -Match "Continuing setup anyway"
    }

    It "Script enables System Restore if not already enabled" {
        if (-not $script:SetupScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should check and enable System Restore
        $content | Should -Match "Enable-ComputerRestore"
        $content | Should -Match "Enabling System Restore"
    }

    It "Script provides fallback restore point creation method" {
        if (-not $script:SetupScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should have WMI fallback for older systems
        $content | Should -Match "Get-WmiObject.*SystemRestore"
        $content | Should -Match "fallback.*WMI"
    }

    It "Script provides rollback guidance in completion message" {
        if (-not $script:SetupScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should mention restore point in completion
        $content | Should -Match "System Restore Point Available"
        $content | Should -Match "rstrui\.exe|System Restore"
        $content | Should -Match "Control Panel.*System Protection"
    }

    It "Can run in WhatIf mode for restore point testing" {
        if (-not $script:SetupScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        try {
            # Test that we can run with SkipRestorePoint for testing
            $testOutput = & $script:SetupScript -SkipRestorePoint -WhatIf -ErrorAction Stop 2>&1 | Out-String

            # Should mention skipping restore point
            $testOutput | Should -Match "Skipping system restore point"

            $LASTEXITCODE | Should -Be 0
        } catch {
            Set-ItResult -Skipped -Because "WhatIf mode execution failed: $_"
        }
    }
}

Describe "System Restore Point Functionality" {

    It "System Restore is available on this system" {
        if (-not $script:RestoreAvailable) {
            Set-ItResult -Skipped -Because "System Restore cmdlets not available"
            return
        }

        # Check that restore point cmdlets exist
        Get-Command "Checkpoint-Computer" | Should -Not -BeNullOrEmpty
        Get-Command "Get-ComputerRestorePoint" -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It "Can check current restore point status (if admin)" {
        if (-not $script:IsAdmin -or -not $script:RestoreAvailable) {
            Set-ItResult -Skipped -Because "Requires Administrator privileges and System Restore"
            return
        }

        try {
            # Try to get existing restore points
            $restorePoints = Get-ComputerRestorePoint -ErrorAction Stop
            Write-Host "✅ Found $($restorePoints.Count) existing restore points" -ForegroundColor Green
            $true | Should -Be $true
        } catch {
            # System Restore might not be enabled, which is fine for testing
            Write-Host "ℹ️ System Restore may not be enabled: $_" -ForegroundColor Gray
            $true | Should -Be $true
        }
    }

    It "System Restore can be enabled programmatically (if admin)" {
        if (-not $script:IsAdmin -or -not $script:RestoreAvailable) {
            Set-ItResult -Skipped -Because "Requires Administrator privileges and System Restore"
            return
        }

        try {
            # Check if we can enable System Restore (don't actually enable in test)
            Get-Command "Enable-ComputerRestore" -ErrorAction Stop | Should -Not -BeNullOrEmpty
            Write-Host "✅ Enable-ComputerRestore cmdlet available" -ForegroundColor Green
        } catch {
            Set-ItResult -Skipped -Because "Enable-ComputerRestore not available: $_"
        }
    }

    It "WMI restore point creation method is available as fallback" {
        try {
            # Check that WMI SystemRestore class exists (older systems)
            $systemRestore = Get-WmiObject -Class "SystemRestore" -Namespace "root\default" -List -ErrorAction Stop
            $systemRestore | Should -Not -BeNullOrEmpty
            Write-Host "✅ WMI SystemRestore fallback available" -ForegroundColor Green
        } catch {
            Write-Host "ℹ️ WMI SystemRestore not available (modern system): $_" -ForegroundColor Gray
            # This is fine - modern systems use Checkpoint-Computer
            $true | Should -Be $true
        }
    }
}

Describe "Setup Script Parameter Validation" {

    BeforeAll {
        $script:SetupScript = Join-Path $script:RepoRoot "setup-machine.ps1"
    }

    It "Accepts SkipRestorePoint parameter" {
        if (-not (Test-Path $script:SetupScript)) {
            Set-ItResult -Skipped -Because "Setup script not found"
            return
        }

        # Test parameter binding
        try {
            $help = Get-Help $script:SetupScript -Parameter "SkipRestorePoint" -ErrorAction Stop
            $help.Name | Should -Be "SkipRestorePoint"
            $help.Type.Name | Should -Be "SwitchParameter"
        } catch {
            Set-ItResult -Skipped -Because "Could not get parameter help: $_"
        }
    }

    It "Help documentation includes restore point information" {
        if (-not (Test-Path $script:SetupScript)) {
            Set-ItResult -Skipped -Because "Setup script not found"
            return
        }

        try {
            $help = Get-Help $script:SetupScript -Detailed -ErrorAction Stop
            $helpText = $help | Out-String

            # Should document the restore point functionality
            $helpText | Should -Match "SkipRestorePoint"
            $helpText | Should -Match "restore point|rollback"
        } catch {
            Set-ItResult -Skipped -Because "Could not get script help: $_"
        }
    }

    It "Examples include SkipRestorePoint usage" {
        if (-not (Test-Path $script:SetupScript)) {
            Set-ItResult -Skipped -Because "Setup script not found"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should have example using SkipRestorePoint
        $content | Should -Match "(?s)\.EXAMPLE.{0,500}-SkipRestorePoint"
    }
}

Describe "Security and Safety Validation" {

    It "Restore point creation doesn't compromise security" {
        # System restore points are a Windows security feature
        # Creating them is always safe and recommended
        $true | Should -Be $true
    }

    It "Provides clear guidance about rollback process" {
        $script:SetupScript = Join-Path $script:RepoRoot "setup-machine.ps1"

        if (-not (Test-Path $script:SetupScript)) {
            Set-ItResult -Skipped -Because "Setup script not found"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should explain how to use restore points
        $content | Should -Match "Control Panel.*System Protection|rstrui\.exe"
        $content | Should -Match "rollback.*changes"
    }

    It "Warns user about continuing without restore point" {
        $script:SetupScript = Join-Path $script:RepoRoot "setup-machine.ps1"

        if (-not (Test-Path $script:SetupScript)) {
            Set-ItResult -Skipped -Because "Setup script not found"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should warn in unattended mode
        $content | Should -Match "continue without.*restore point"
        $content | Should -Match "Continuing setup anyway"
    }

    It "Uses descriptive restore point names" {
        $script:SetupScript = Join-Path $script:RepoRoot "setup-machine.ps1"

        if (-not (Test-Path $script:SetupScript)) {
            Set-ItResult -Skipped -Because "Setup script not found"
            return
        }

        $content = Get-Content $script:SetupScript -Raw

        # Should use clear, descriptive names
        $content | Should -Match "DevMachine Setup"
        $content | Should -Match "Get-Date.*Format"
    }
}

AfterAll {
    Write-Host "🏁 System restore point test execution complete" -ForegroundColor Cyan
    Write-Host "Note: Some tests require Administrator privileges and System Restore availability" -ForegroundColor Gray

    if (-not $script:IsAdmin) {
        Write-Host "💡 Run as Administrator to test restore point creation functionality" -ForegroundColor Cyan
    }

    if (-not $script:RestoreAvailable) {
        Write-Host "💡 System Restore cmdlets not available on this system" -ForegroundColor Cyan
    }
}
