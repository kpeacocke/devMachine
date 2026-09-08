# Regression tests for failures found on the Surface bootstrap.
# Run with: pwsh -NoProfile -File .\tests\devmachine-hardening-regression.Tests.ps1

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:WindowsScripts = Join-Path $script:RepoRoot 'scripts\windows'
}

Describe 'PowerShell common-parameter safety' {
    It '18-windows-containers does not redeclare the built-in WhatIf parameter' {
        $content = Get-Content (Join-Path $script:WindowsScripts '18-windows-containers.ps1') -Raw
        $content | Should -Match 'SupportsShouldProcess'
        $content | Should -Not -Match '(?m)^\s*\[switch\]\$WhatIf\s*,?\s*$'
    }

    It '41-devdrive-partition-setup does not redeclare the built-in WhatIf parameter' {
        $content = Get-Content (Join-Path $script:WindowsScripts '41-devdrive-partition-setup.ps1') -Raw
        $content | Should -Match 'SupportsShouldProcess'
        $content | Should -Not -Match '(?m)^\s*\[switch\]\$WhatIf\s*,?\s*$'
    }
}

Describe 'Dev Drive design' {
    It 'uses one valid 90 GB Dev Drive and never a sub-50 GB DevCode drive' {
        $content = Get-Content (Join-Path $script:WindowsScripts '41-devdrive-partition-setup.ps1') -Raw
        $content | Should -Match '\$DevDriveGB\s*=\s*90'
        $content | Should -Match '\$MinimumGB\s*=\s*50'
        $content | Should -Match 'Format-Volume[\s\S]*-DevDrive'
        $content | Should -Match "-NewFileSystemLabel\s+'DevCache'"
        $content | Should -Not -Match "-NewFileSystemLabel\s+'DevCode'"
    }

    It 'uses the actual Windows-supported C drive shrink boundary' {
        $content = Get-Content (Join-Path $script:WindowsScripts '41-devdrive-partition-setup.ps1') -Raw
        $content | Should -Match 'Get-PartitionSupportedSize'
        $content | Should -Match 'SizeMin'
        $content | Should -Match 'projectedPct'
        $content | Should -Match 'projectedPct\s+-lt\s+30'
    }

    It 'never uses exit 0 for WhatIf/idempotent success paths' {
        $content = Get-Content (Join-Path $script:WindowsScripts '41-devdrive-partition-setup.ps1') -Raw
        $content | Should -Not -Match 'exit\s+0'
    }

    It 'uses the documented Dev Drive trust operations' {
        $content = Get-Content (Join-Path $script:WindowsScripts '41-devdrive-partition-setup.ps1') -Raw
        $content | Should -Match 'fsutil\.exe'
        $content | Should -Match 'devdrv\s+trust'
        $content | Should -Match 'devdrv\s+query'
    }
}

Describe 'Windows executable resolution' {
    It '31-performance-tuning does not depend on PATH for Windows system utilities' {
        $content = Get-Content (Join-Path $script:WindowsScripts '31-performance-tuning.ps1') -Raw
        $content | Should -Match 'System32\\powercfg\.exe'
        $content | Should -Match 'System32\\reg\.exe'
        $content | Should -Match 'System32\\netsh\.exe'
        $content | Should -Match 'System32\\Dism\.exe'
    }

    It '31-performance-tuning targets the current DevCache mount point' {
        $content = Get-Content (Join-Path $script:WindowsScripts '31-performance-tuning.ps1') -Raw
        $content | Should -Match "DevCachePath\s*=\s*'C:\\DevCache'"
        $content | Should -Not -Match 'DevCachePath\s*=\s*"D:\\dev\\caches"'
    }

    It '40-devdrive-caches does not move TEMP/TMP or overwrite Docker daemon configuration' {
        $content = Get-Content (Join-Path $script:WindowsScripts '40-devdrive-caches.ps1') -Raw
        $content | Should -Match 'TEMP/TMP were intentionally left unchanged'
        $content | Should -Match 'Docker Desktop daemon.json was intentionally left unchanged'
        $content | Should -Match 'PIP_CACHE_DIR'
        $content | Should -Match 'CARGO_HOME'
        $content | Should -Match 'GOPATH'
        $content | Should -Match 'NUGET_PACKAGES'
    }
}

Describe 'Legacy Dev Drive cleanup safety' {
    It 'repair utility does not mutate partitions' {
        $content = Get-Content (Join-Path $script:WindowsScripts '99-repair-partial-setup.ps1') -Raw
        $content | Should -Not -Match 'Remove-Partition'
        $content | Should -Not -Match 'Resize-Partition'
        $content | Should -Not -Match 'Clear-Disk'
        $content | Should -Match 'RemoveDevDriveExclusions'
    }
}
