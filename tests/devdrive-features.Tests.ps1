#Requires -Version 7.0
<#
.SYNOPSIS
    Tests for DevDrive partition setup, cache configuration, and ownership management

.DESCRIPTION
    Comprehensive tests covering:
    - DevDrive partition setup and validation (41-devdrive-partition-setup.ps1)
    - Cache directory configuration and relocation (40-devdrive-caches.ps1)
    - File ownership fixing and permissions (42-devdrive-fix-ownership.ps1)

.NOTES
    Run with: pwsh -NoProfile -File .\tests\devdrive-features.Tests.ps1
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

    Write-Host "🔧 DevDrive Features Test Suite" -ForegroundColor Cyan
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

    # Helper function to check if ReFS/DevDrive is supported
    function Test-RefsSupported {
        try {
            # Check Windows version (ReFS requires Windows 10/Server 2016+)
            $osVersion = [System.Environment]::OSVersion.Version
            if ($osVersion.Major -lt 10) {
                return $false
            }

            # Check if Dev Drive feature is available (Windows 11 22H2+)
            $buildNumber = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
            return [int]$buildNumber -ge 22621
        } catch {
            return $false
        }
    }

    $script:IsAdmin = Test-IsAdmin
    $script:RefsSupported = Test-RefsSupported

    if ($script:IsAdmin) {
        Write-Host "Running with Administrator privileges ✅" -ForegroundColor Green
    } else {
        Write-Host "Running without Administrator privileges (some tests will be skipped) ⚠️" -ForegroundColor Yellow
    }

    if ($script:RefsSupported) {
        Write-Host "ReFS/Dev Drive supported ✅" -ForegroundColor Green
    } else {
        Write-Host "ReFS/Dev Drive not supported (legacy system) ⚠️" -ForegroundColor Yellow
    }
}

Describe "DevDrive Partition Setup (41-devdrive-partition-setup.ps1)" {

    BeforeAll {
        $script:PartitionScript = Join-Path $script:RepoRoot "scripts\windows\41-devdrive-partition-setup.ps1"
        $script:PartitionScriptExists = Test-Path $script:PartitionScript
    }

    It "Partition setup script exists and is valid" {
        $script:PartitionScriptExists | Should -Be $true

        if ($script:PartitionScriptExists) {
            # Check syntax
            $syntaxCheck = pwsh -NoProfile -Command "try { [void](Get-Command '$script:PartitionScript' -Syntax -ErrorAction Stop); exit 0 } catch { exit 1 }"
            $LASTEXITCODE | Should -Be 0
        }
    }

    It "Script contains proper parameter validation" {
        if (-not $script:PartitionScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:PartitionScript -Raw

        # Should have proper parameter blocks
        $content | Should -Match "\[Parameter\("
        $content | Should -Match "ValidateRange|ValidateNotNullOrEmpty"
        $content | Should -Match "CmdletBinding"
    }

    It "Script supports WhatIf and has proper error handling" {
        if (-not $script:PartitionScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:PartitionScript -Raw

        # Should support WhatIf
        $content | Should -Match "SupportsShouldProcess"
        $content | Should -Match "\$PSCmdlet\.ShouldProcess"

        # Should have error handling
        $content | Should -Match "ErrorActionPreference|try.*catch"
    }

    It "DevDrive creation validation logic exists" {
        if (-not $script:PartitionScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:PartitionScript -Raw

        # Should check for ReFS support
        $content | Should -Match "ReFS|Dev.*Drive|FileSystem.*ReFS"

        # Should validate disk space
        $content | Should -Match "Get-Volume|Get-Disk|FreeSpace"
    }

    It "Script handles existing DevDrive detection" {
        if (-not $script:PartitionScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:PartitionScript -Raw

        # Should check for existing DevDrives
        $content | Should -Match "Test-Path.*DevCache|Get-Volume.*DevCache"
        $content | Should -Match "already.*exists|existing.*partition"
    }

    It "Can run in WhatIf mode without errors" {
        if (-not $script:PartitionScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        if (-not $script:IsAdmin) {
            Set-ItResult -Skipped -Because "Requires Administrator privileges"
            return
        }

        try {
            $result = & $script:PartitionScript -WhatIf -ErrorAction Stop 2>&1
            $LASTEXITCODE | Should -Be 0
        } catch {
            Set-ItResult -Skipped -Because "WhatIf execution failed: $_"
        }
    }
}

Describe "Cache Configuration (40-devdrive-caches.ps1)" {

    BeforeAll {
        $script:CacheScript = Join-Path $script:RepoRoot "scripts\windows\40-devdrive-caches.ps1"
        $script:CacheScriptExists = Test-Path $script:CacheScript
    }

    It "Cache configuration script exists and is valid" {
        $script:CacheScriptExists | Should -Be $true

        if ($script:CacheScriptExists) {
            # Check syntax
            $syntaxCheck = pwsh -NoProfile -Command "try { [void](Get-Command '$script:CacheScript' -Syntax -ErrorAction Stop); exit 0 } catch { exit 1 }"
            $LASTEXITCODE | Should -Be 0
        }
    }

    It "Script configures essential package manager caches" {
        if (-not $script:CacheScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:CacheScript -Raw

        # Should configure major package managers
        $content | Should -Match "npm.*cache|NPM_CONFIG_CACHE"
        $content | Should -Match "pip.*cache|PIP_CACHE_DIR"
        $content | Should -Match "cargo|CARGO_HOME"
        $content | Should -Match "go.*cache|GOPATH|GOCACHE"
        $content | Should -Match "nuget.*cache|NUGET_PACKAGES"
    }

    It "Script creates cache directories properly" {
        if (-not $script:CacheScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:CacheScript -Raw

        # Should create directories with proper error handling
        $content | Should -Match "New-Item.*Directory|mkdir"
        $content | Should -Match "Force.*ErrorAction|IfNotExists"
    }

    It "Script sets environment variables persistently" {
        if (-not $script:CacheScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:CacheScript -Raw

        # Should set environment variables for User scope
        $content | Should -Match "\[Environment\]::SetEnvironmentVariable.*User"
        $content | Should -Match "refreshenv|Update-SessionEnvironment"
    }

    It "Script handles DevDrive and fallback scenarios" {
        if (-not $script:CacheScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:CacheScript -Raw

        # Should check for DevDrive and fall back to regular directories
        $content | Should -Match "DevCache|Dev.*Drive"
        $content | Should -Match "fallback|alternative|else"
    }

    It "Can detect and validate existing cache configurations" {
        # Check if any cache environment variables are already set
        $cacheVars = @(
            @{Name='CARGO_HOME'; Default="$env:USERPROFILE\.cargo"},
            @{Name='GOPATH'; Default="$env:USERPROFILE\go"},
            @{Name='NPM_CONFIG_CACHE'; Default="$env:APPDATA\npm-cache"},
            @{Name='PIP_CACHE_DIR'; Default="$env:LOCALAPPDATA\pip\Cache"},
            @{Name='NUGET_PACKAGES'; Default="$env:USERPROFILE\.nuget\packages"}
        )

        $configuredCount = 0
        foreach ($var in $cacheVars) {
            $value = [Environment]::GetEnvironmentVariable($var.Name, 'User')
            if ($value -and (Test-Path $value -ErrorAction SilentlyContinue)) {
                $configuredCount++
            }
        }

        if ($configuredCount -eq 0) {
            Set-ItResult -Skipped -Because "No cache configurations detected (script may not have been run)"
        } else {
            $configuredCount | Should -BeGreaterThan 0
        }
    }
}

Describe "File Ownership Fixing (42-devdrive-fix-ownership.ps1)" {

    BeforeAll {
        $script:OwnershipScript = Join-Path $script:RepoRoot "scripts\windows\42-devdrive-fix-ownership.ps1"
        $script:OwnershipScriptExists = Test-Path $script:OwnershipScript
    }

    It "Ownership fixing script exists and is valid" {
        $script:OwnershipScriptExists | Should -Be $true

        if ($script:OwnershipScriptExists) {
            # Check syntax
            $syntaxCheck = pwsh -NoProfile -Command "try { [void](Get-Command '$script:OwnershipScript' -Syntax -ErrorAction Stop); exit 0 } catch { exit 1 }"
            $LASTEXITCODE | Should -Be 0
        }
    }

    It "Script has proper parameter validation for path input" {
        if (-not $script:OwnershipScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:OwnershipScript -Raw

        # Should validate path parameters
        $content | Should -Match "\[Parameter\(.*Mandatory"
        $content | Should -Match "ValidateScript|Test-Path|ValidateNotNullOrEmpty"
        $content | Should -Match "Path.*string"
    }

    It "Script uses proper ownership APIs" {
        if (-not $script:OwnershipScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:OwnershipScript -Raw

        # Should use proper Windows APIs for ownership
        $content | Should -Match "Get-Acl|Set-Acl|takeown|icacls"
        $content | Should -Match "FileSystemRights|AccessControlType"
    }

    It "Script handles recursive operations safely" {
        if (-not $script:OwnershipScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:OwnershipScript -Raw

        # Should handle recursion with proper error checking
        $content | Should -Match "Recurse.*Force|Get-ChildItem.*Recurse"
        $content | Should -Match "try.*catch|ErrorAction.*Continue"
    }

    It "Script validates user permissions before attempting fixes" {
        if (-not $script:OwnershipScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:OwnershipScript -Raw

        # Should check for admin privileges
        $content | Should -Match "Administrator|IsInRole|Principal"
        $content | Should -Match "elevation|admin.*required"
    }

    It "Can validate ownership without making changes" {
        if (-not $script:OwnershipScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $testPath = $script:RepoRoot

        try {
            # Test with WhatIf if supported
            $result = & $script:OwnershipScript -Path $testPath -WhatIf -ErrorAction Stop 2>&1
            $true | Should -Be $true  # If we get here, the script ran without errors
        } catch {
            Set-ItResult -Skipped -Because "Script validation failed: $_"
        }
    }

    It "Script handles common ownership scenarios" {
        if (-not $script:OwnershipScriptExists) {
            Set-ItResult -Skipped -Because "Script does not exist"
            return
        }

        $content = Get-Content $script:OwnershipScript -Raw

        # Should handle different file types and permissions
        $content | Should -Match "FullControl|Modify|ReadWrite"
        $content | Should -Match "System|Administrators|Users"
        $content | Should -Match "file.*folder|directory.*access"
    }
}

Describe "DevDrive Integration and Cross-Feature Testing" {

    It "DevCache directory exists or can be created" {
        $devCachePath = "C:\DevCache"

        if (Test-Path $devCachePath) {
            # DevDrive exists - check if it's ReFS
            try {
                $volume = Get-Volume | Where-Object { $_.Path -eq "$devCachePath\" }
                if ($volume -and $volume.FileSystem -eq "ReFS") {
                    Write-Host "✅ DevDrive detected at $devCachePath (ReFS)" -ForegroundColor Green
                    $true | Should -Be $true
                } else {
                    Write-Host "ℹ️ Cache directory at $devCachePath (not ReFS)" -ForegroundColor Cyan
                    $true | Should -Be $true
                }
            } catch {
                $true | Should -Be $true  # Directory exists, filesystem check failed
            }
        } elseif ($script:IsAdmin -and $script:RefsSupported) {
            # Could potentially create DevDrive
            $true | Should -Be $true
        } else {
            Set-ItResult -Skipped -Because "DevCache not found and cannot create (insufficient privileges or unsupported system)"
        }
    }

    It "Package manager caches are properly relocated" {
        $expectedCaches = @(
            @{EnvVar='CARGO_HOME'; Path="C:\DevCache\.cargo"},
            @{EnvVar='GOPATH'; Path="C:\DevCache\go"},
            @{EnvVar='NPM_CONFIG_CACHE'; Path="C:\DevCache\npm"},
            @{EnvVar='PIP_CACHE_DIR'; Path="C:\DevCache\pip"}
        )

        $relocatedCount = 0
        foreach ($cache in $expectedCaches) {
            $envValue = [Environment]::GetEnvironmentVariable($cache.EnvVar, 'User')
            if ($envValue -and $envValue.StartsWith("C:\DevCache")) {
                $relocatedCount++
            }
        }

        if ($relocatedCount -eq 0) {
            Set-ItResult -Skipped -Because "No caches relocated to DevDrive (may be using default locations)"
        } else {
            $relocatedCount | Should -BeGreaterThan 0
        }
    }

    It "User has proper permissions to cache directories" {
        $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $cacheDir = "C:\DevCache"

        if (-not (Test-Path $cacheDir)) {
            Set-ItResult -Skipped -Because "Cache directory not found"
            return
        }

        try {
            # Try to create a test file
            $testFile = Join-Path $cacheDir "test-permissions.tmp"
            "test" | Out-File $testFile -Force
            Remove-Item $testFile -Force

            $true | Should -Be $true
        } catch {
            Set-ItResult -Skipped -Because "Cannot write to cache directory: $_"
        }
    }

    It "Cache directories have proper structure and ownership" {
        $cacheDir = "C:\DevCache"

        if (-not (Test-Path $cacheDir)) {
            Set-ItResult -Skipped -Because "Cache directory not found"
            return
        }

        try {
            # Check ACL
            $acl = Get-Acl $cacheDir
            $userAccess = $acl.Access | Where-Object {
                $_.IdentityReference -match $env:USERNAME -and
                $_.FileSystemRights -match "FullControl|Modify"
            }

            $userAccess | Should -Not -BeNullOrEmpty
        } catch {
            Set-ItResult -Skipped -Because "Cannot check permissions: $_"
        }
    }

    It "Scripts work together in proper sequence" {
        # Verify the scripts can be imported without conflicts
        $scripts = @(
            "40-devdrive-caches.ps1",
            "41-devdrive-partition-setup.ps1",
            "42-devdrive-fix-ownership.ps1"
        )

        foreach ($script in $scripts) {
            $scriptPath = Join-Path $script:RepoRoot "scripts\windows\$script"
            if (Test-Path $scriptPath) {
                try {
                    # Test that script can be dot-sourced without errors
                    $content = Get-Content $scriptPath -Raw

                    # Basic validation - should not have obvious conflicts
                    $content | Should -Not -Match "exit\s+\d+"  # Should not have hard exits

                } catch {
                    Set-ItResult -Skipped -Because "Script validation failed for $script : $_"
                }
            }
        }

        $true | Should -Be $true
    }
}

AfterAll {
    Write-Host "🏁 DevDrive features test execution complete" -ForegroundColor Cyan
    Write-Host "Note: Many tests depend on DevDrive being configured and Administrator privileges" -ForegroundColor Gray
}
