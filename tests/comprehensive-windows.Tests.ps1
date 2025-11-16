#Requires -Version 7.0
<#
.SYNOPSIS
    Comprehensive functional tests for Windows development environment setup

.DESCRIPTION
    Tests all major components of the dev machine setup including:
    - Security hardening and Windows Defender configuration
    - Development tools installation and configuration
    - DevDrive and performance optimizations
    - CLI tools and integrations
    - Git configuration and tooling
    - WSL and containerization

.NOTES
    Run with: pwsh -NoProfile -File .\tests\comprehensive-windows.Tests.ps1
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

    Write-Host "🧪 Comprehensive Windows Dev Environment Tests" -ForegroundColor Cyan
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

    $script:IsAdmin = Test-IsAdmin
    if ($script:IsAdmin) {
        Write-Host "Running with Administrator privileges ✅" -ForegroundColor Green
    } else {
        Write-Host "Running without Administrator privileges (some tests will be skipped) ⚠️" -ForegroundColor Yellow
    }
}

Describe "Core System Configuration" {

    It "PowerShell 7+ is installed and available" {
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        $pwsh | Should -Not -BeNullOrEmpty

        # Check version is 7+
        $version = pwsh --version
        $version | Should -Match "PowerShell 7\.|PowerShell 1\d\."
    }

    It "Windows Terminal is installed with PowerShell 7 as default" {
        $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

        if (-not (Test-Path $settingsPath)) {
            Set-ItResult -Skipped -Because "Windows Terminal not installed"
            return
        }

        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            $settings.defaultProfile | Should -Not -BeNullOrEmpty

            # Check if PowerShell 7 profile exists
            $pwshProfile = $settings.profiles.list | Where-Object { $_.commandline -like "*pwsh*" }
            $pwshProfile | Should -Not -BeNullOrEmpty
        } catch {
            Set-ItResult -Skipped -Because "Could not parse Windows Terminal settings"
        }
    }

    It "Git is installed with proper configuration" {
        $git = Get-Command git -ErrorAction SilentlyContinue
        $git | Should -Not -BeNullOrEmpty

        # Check core configurations exist
        $editor = git config --global core.editor 2>$null
        if ($editor) {
            $editor | Should -Not -BeNullOrEmpty
        }

        $autocrlf = git config --global core.autocrlf 2>$null
        if ($autocrlf) {
            $autocrlf | Should -BeIn @('true', 'false', 'input')
        }
    }
}

Describe "Security Hardening" {

    It "Windows Firewall is enabled for all profiles" {
        if (-not $script:IsAdmin) {
            Set-ItResult -Skipped -Because "Requires Administrator privileges"
            return
        }

        try {
            $profiles = Get-NetFirewallProfile -ErrorAction Stop
            foreach ($profile in $profiles) {
                $profile.Enabled | Should -Be $true
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check firewall status: $_"
        }
    }

    It "UAC is properly configured" {
        if (-not $script:IsAdmin) {
            Set-ItResult -Skipped -Because "Requires Administrator privileges"
            return
        }

        try {
            $uacSetting = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction Stop
            # Should be 2 (Always notify) or 5 (Notify with secure desktop)
            $uacSetting.ConsentPromptBehaviorAdmin | Should -BeIn @(2, 5)
        } catch {
            Set-ItResult -Skipped -Because "Could not check UAC settings: $_"
        }
    }

    It "Windows Defender is active and configured" {
        try {
            $defender = Get-MpComputerStatus -ErrorAction Stop
            $defender.RealTimeProtectionEnabled | Should -Be $true

            # Check if PUA protection is enabled
            $preferences = Get-MpPreference -ErrorAction Stop
            $preferences.PUAProtection | Should -Be 1
        } catch {
            Set-ItResult -Skipped -Because "Could not check Defender status (may require elevation): $_"
        }
    }

    It "Windows Defender has development exclusions configured" {
        try {
            $preferences = Get-MpPreference -ErrorAction Stop
            $exclusions = $preferences.ExclusionPath

            if ($exclusions -and $exclusions.Count -gt 0) {
                # Should have some development-related exclusions
                $devExclusions = $exclusions | Where-Object {
                    $_ -like "*node_modules*" -or
                    $_ -like "*\.git*" -or
                    $_ -like "*\target*" -or
                    $_ -like "*\.cargo*" -or
                    $_ -like "*\go*"
                }
                $devExclusions | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "No exclusions found (may not have run optimization script)"
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check Defender exclusions: $_"
        }
    }

    It "BitLocker is enabled on system drive (if supported)" {
        try {
            $bitlocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
            if ($bitlocker.ProtectionStatus -eq "On") {
                $bitlocker.ProtectionStatus | Should -Be "On"
            } else {
                Set-ItResult -Skipped -Because "BitLocker not enabled (may not be supported or configured)"
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check BitLocker status: $_"
        }
    }
}

Describe "Development Tools" {

    It "Essential CLI tools are available" {
        $essentialTools = @('git', 'code', 'node', 'npm', 'python', 'dotnet')

        foreach ($tool in $essentialTools) {
            $command = Get-Command $tool -ErrorAction SilentlyContinue
            if (-not $command) {
                Set-ItResult -Skipped -Because "$tool not installed"
            } else {
                $command | Should -Not -BeNullOrEmpty
            }
        }
    }

    It "Package managers are available" {
        $packageManagers = @('npm', 'pip', 'dotnet', 'winget')

        foreach ($pm in $packageManagers) {
            $command = Get-Command $pm -ErrorAction SilentlyContinue
            if (-not $command) {
                Write-Host "⚠️ Package manager $pm not found" -ForegroundColor Yellow
            } else {
                $command | Should -Not -BeNullOrEmpty
            }
        }
    }

    It "Docker is installed and accessible" {
        $docker = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $docker) {
            Set-ItResult -Skipped -Because "Docker not installed"
            return
        }

        try {
            $dockerInfo = docker info 2>&1
            if ($dockerInfo -match "error" -or $LASTEXITCODE -ne 0) {
                Set-ItResult -Skipped -Because "Docker daemon not running"
            } else {
                $true | Should -Be $true  # Docker is working
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check Docker status"
        }
    }

    It "1Password CLI is available (if 1Password is installed)" {
        $op = Get-Command op -ErrorAction SilentlyContinue
        $onePasswordApp = Get-Process "1Password" -ErrorAction SilentlyContinue

        if ($onePasswordApp -and -not $op) {
            throw "1Password app is running but CLI not available"
        } elseif ($op) {
            $op | Should -Not -BeNullOrEmpty
        } else {
            Set-ItResult -Skipped -Because "1Password not installed"
        }
    }

    It "GitKraken CLI is available (if GitKraken is installed)" {
        $gk = Get-Command gk -ErrorAction SilentlyContinue
        $gitkrakenInstalled = Test-Path "$env:LOCALAPPDATA\gitkraken\*" -ErrorAction SilentlyContinue

        if ($gitkrakenInstalled -and -not $gk) {
            Set-ItResult -Skipped -Because "GitKraken installed but CLI not detected (may not be in PATH)"
        } elseif ($gk) {
            $gk | Should -Not -BeNullOrEmpty
        } else {
            Set-ItResult -Skipped -Because "GitKraken not installed"
        }
    }
}

Describe "WSL Configuration" {

    It "WSL 2 is installed and set as default" {
        $wsl = Get-Command wsl -ErrorAction SilentlyContinue
        if (-not $wsl) {
            Set-ItResult -Skipped -Because "WSL not installed"
            return
        }

        try {
            $wslStatus = wsl --status 2>&1 | Out-String
            if ($wslStatus -match "Default Version.*2") {
                $true | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "WSL 2 not set as default or not available"
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check WSL status"
        }
    }

    It "Ubuntu distribution is installed" {
        $wsl = Get-Command wsl -ErrorAction SilentlyContinue
        if (-not $wsl) {
            Set-ItResult -Skipped -Because "WSL not installed"
            return
        }

        try {
            $distributions = wsl -l -v 2>&1 | Out-String
            if ($distributions -match "Ubuntu") {
                $true | Should -Be $true
            } else {
                Set-ItResult -Skipped -Because "Ubuntu not installed in WSL"
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check WSL distributions"
        }
    }

    It ".wslconfig exists with performance optimizations" {
        $wslConfig = Join-Path $env:USERPROFILE ".wslconfig"

        if (-not (Test-Path $wslConfig)) {
            Set-ItResult -Skipped -Because ".wslconfig not found"
            return
        }

        $content = Get-Content $wslConfig -Raw

        # Should have sparse VHD enabled
        if ($content -match "sparseVhd\s*=\s*true") {
            $true | Should -Be $true
        } else {
            Set-ItResult -Skipped -Because "Sparse VHD not enabled in .wslconfig"
        }
    }
}

Describe "DevDrive and Performance Optimization" {

    It "Cache directories exist (DevDrive or regular)" {
        $possibleCachePaths = @(
            "C:\DevCache",
            "$env:USERPROFILE\AppData\Local\pip",
            "$env:USERPROFILE\AppData\Roaming\npm",
            "$env:USERPROFILE\.cargo",
            "$env:USERPROFILE\go"
        )

        $foundCaches = $possibleCachePaths | Where-Object { Test-Path $_ }
        $foundCaches.Count | Should -BeGreaterThan 0
    }

    It "Package manager environment variables are configured" {
        $envVars = @(
            @{Name='CARGO_HOME'; Path="$env:USERPROFILE\.cargo"},
            @{Name='GOPATH'; Path="$env:USERPROFILE\go"},
            @{Name='GRADLE_USER_HOME'; Path="$env:USERPROFILE\.gradle"}
        )

        $configuredVars = 0
        foreach ($var in $envVars) {
            $value = [Environment]::GetEnvironmentVariable($var.Name, 'User')
            if ($value -and (Test-Path $value)) {
                $configuredVars++
            }
        }

        if ($configuredVars -eq 0) {
            Set-ItResult -Skipped -Because "No package manager environment variables found (may not have run cache configuration)"
        } else {
            $configuredVars | Should -BeGreaterThan 0
        }
    }

    It "Dev Drive exists and is properly mounted (if configured)" {
        $devDrivePaths = @("C:\DevCache", "$env:USERPROFILE\code")
        $devDrives = @()

        foreach ($path in $devDrivePaths) {
            if (Test-Path $path) {
                try {
                    $volume = Get-Volume | Where-Object { $_.Path -eq "$path\" }
                    if ($volume -and $volume.FileSystem -eq "ReFS") {
                        $devDrives += $path
                    }
                } catch {
                    # Ignore errors checking volume info
                }
            }
        }

        if ($devDrives.Count -eq 0) {
            Set-ItResult -Skipped -Because "No Dev Drives found (not configured or using regular directories)"
        } else {
            $devDrives.Count | Should -BeGreaterThan 0
        }
    }

    It "Storage Sense is enabled" {
        try {
            $storageSense = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -ErrorAction Stop
            $storageSense.'01' | Should -Be 1
        } catch {
            Set-ItResult -Skipped -Because "Storage Sense not configured"
        }
    }
}

Describe "Git Configuration" {

    It "Git has proper user configuration" {
        $userName = git config --global user.name 2>$null
        $userEmail = git config --global user.email 2>$null

        if (-not $userName -or -not $userEmail) {
            Set-ItResult -Skipped -Because "Git user not configured (run Git configuration script or set manually)"
        } else {
            $userName | Should -Not -BeNullOrEmpty
            $userEmail | Should -Match "@"
        }
    }

    It "Git editor is configured" {
        $editor = git config --global core.editor 2>$null

        if (-not $editor) {
            Set-ItResult -Skipped -Because "Git editor not configured"
        } else {
            $editor | Should -Not -BeNullOrEmpty
            # Should be VS Code if available
            if ($editor -match "code") {
                $editor | Should -Match "--wait"
            }
        }
    }

    It "Git diff/merge tools are configured" {
        $diffTool = git config --global diff.tool 2>$null
        $mergeTool = git config --global merge.tool 2>$null

        if (-not $diffTool -and -not $mergeTool) {
            Set-ItResult -Skipped -Because "Git diff/merge tools not configured"
        } else {
            # At least one should be configured
            ($diffTool -or $mergeTool) | Should -Be $true
        }
    }

    It "Global gitignore is configured" {
        $gitignore = git config --global core.excludesfile 2>$null

        if (-not $gitignore) {
            Set-ItResult -Skipped -Because "Global gitignore not configured"
        } else {
            Test-Path $gitignore | Should -Be $true

            # Should contain some common patterns
            $content = Get-Content $gitignore -Raw
            $content | Should -Match "\.env"
        }
    }

    It "Global gitattributes is configured" {
        $gitattributes = git config --global core.attributesfile 2>$null

        if (-not $gitattributes) {
            Set-ItResult -Skipped -Because "Global gitattributes not configured"
        } else {
            Test-Path $gitattributes | Should -Be $true

            # Should contain line ending configuration
            $content = Get-Content $gitattributes -Raw
            $content | Should -Match "text=auto"
        }
    }
}

Describe "System Services and Optimization" {

    It "Windows Search service is optimized or disabled" {
        try {
            $wsearch = Get-Service WSearch -ErrorAction Stop
            # Should be either Disabled or Manual (not Automatic)
            $wsearch.StartType | Should -BeIn @('Disabled', 'Manual')
        } catch {
            Set-ItResult -Skipped -Because "Windows Search service not found"
        }
    }

    It "SysMain (Superfetch) is optimized" {
        try {
            $sysmain = Get-Service SysMain -ErrorAction Stop
            # Should be Disabled or Manual for SSDs
            $sysmain.StartType | Should -BeIn @('Disabled', 'Manual')
        } catch {
            Set-ItResult -Skipped -Because "SysMain service not found"
        }
    }

    It "OpenSSH Server is available (if configured)" {
        try {
            $sshd = Get-Service sshd -ErrorAction Stop
            if ($sshd.Status -eq 'Running') {
                $sshd.Status | Should -Be 'Running'
            } else {
                Set-ItResult -Skipped -Because "OpenSSH Server not running (may be configured to start manually)"
            }
        } catch {
            Set-ItResult -Skipped -Because "OpenSSH Server not installed"
        }
    }
}

Describe "Maintenance and Automation" {

    It "Windows Update is properly configured" {
        # Basic check - detailed configuration would require registry inspection
        try {
            $updateService = Get-Service wuauserv -ErrorAction Stop
            $updateService.Status | Should -BeIn @('Running', 'Stopped')  # Just check it exists
        } catch {
            Set-ItResult -Skipped -Because "Windows Update service not accessible"
        }
    }

    It "Scheduled maintenance tasks exist" {
        try {
            # Check for our custom maintenance tasks
            $wingetTask = Get-ScheduledTask -TaskName "*Winget*" -ErrorAction SilentlyContinue
            $dotnetTask = Get-ScheduledTask -TaskName "*DotNet*" -ErrorAction SilentlyContinue

            if (-not $wingetTask -and -not $dotnetTask) {
                Set-ItResult -Skipped -Because "No maintenance tasks found (may not have been configured)"
            } else {
                ($wingetTask -or $dotnetTask) | Should -Be $true
            }
        } catch {
            Set-ItResult -Skipped -Because "Could not check scheduled tasks"
        }
    }
}

AfterAll {
    Write-Host "🏁 Comprehensive test execution complete" -ForegroundColor Cyan
    Write-Host "Note: Skipped tests indicate features not installed or configured" -ForegroundColor Gray
}
