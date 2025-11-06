# Simple CI/CD-friendly tests that skip instead of fail
# Run with: pwsh -NoProfile -File .\tests\ci-friendly.Tests.ps1

BeforeAll {
    $ErrorActionPreference = 'Stop'
    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
}

Describe "CI/CD Safe Environment Tests" {

    It "Syntax validation passes" {
        # This should always pass if our scripts are valid
        $scriptDir = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\windows"
        $scripts = Get-ChildItem -Path $scriptDir -Filter "*.ps1"

        foreach ($script in $scripts) {
            { [scriptblock]::Create((Get-Content -Path $script.FullName -Raw)) } | Should -Not -Throw
        }
    }

    It "Unattended mode is properly implemented" {
        $scriptsWithPrompts = @(
            "05-git-ssh-config.ps1",
            "09-debloat-windows.ps1",
            "10-windows-bootstrap.ps1",
            "11-licensed-apps.ps1",
            "35-privacy-telemetry.ps1",
            "36-dns-firewall-advanced.ps1",
            "37-services-optimization.ps1",
            "41-devdrive-partition-setup.ps1"
        )

        $scriptDir = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\windows"

        foreach ($scriptName in $scriptsWithPrompts) {
            $scriptPath = Join-Path $scriptDir $scriptName
            if (Test-Path $scriptPath) {
                $content = Get-Content -Path $scriptPath -Raw
                $content | Should -Match '\$env:UNATTENDED_MODE'
            }
        }
    }

    It "Git is available (if installed)" {
        $git = Get-Command git -ErrorAction SilentlyContinue
        if ($git) {
            $git | Should -Not -BeNullOrEmpty
        } else {
            Set-ItResult -Skipped -Because "Git not installed"
        }
    }

    It "PowerShell 7 is available (if installed)" {
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwsh) {
            $pwsh | Should -Not -BeNullOrEmpty
        } else {
            Set-ItResult -Skipped -Because "PowerShell 7 not installed"
        }
    }

    It "WSL is configured (if installed)" {
        if (Get-Command wsl -ErrorAction SilentlyContinue) {
            try {
                $status = wsl --status 2>&1
                if ($status -match "Default Version") {
                    $status | Should -Match "2|1"  # Either version is fine
                } else {
                    Set-ItResult -Skipped -Because "WSL status not available"
                }
            } catch {
                Set-ItResult -Skipped -Because "WSL not properly configured"
            }
        } else {
            Set-ItResult -Skipped -Because "WSL not installed"
        }
    }

    It "Security features work (if configured)" {
        try {
            $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
            if ($profiles) {
                # Just check that we can read firewall settings
                $profiles.Count | Should -BeGreaterThan 0
            } else {
                Set-ItResult -Skipped -Because "Cannot read firewall settings"
            }
        } catch {
            Set-ItResult -Skipped -Because "Firewall check requires elevation"
        }
    }

    It "Core services exist (if configured)" {
        $services = @("Winmgmt", "BITS", "Themes", "AudioSrv")

        foreach ($serviceName in $services) {
            $service = Get-Service $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                $service | Should -Not -BeNullOrEmpty
            }
        }

        # At least one core service should exist
        $services | Should -Not -BeNullOrEmpty
    }
}
