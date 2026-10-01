# Regression tests for failures found on the Surface bootstrap.
# Run with: pwsh -NoProfile -File .\tests\devmachine-hardening-regression.Tests.ps1

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:WindowsScripts = Join-Path $script:RepoRoot 'scripts\windows'
}

Describe 'PowerShell common-parameter safety' {
    It '18-windows-containers does not redeclare built-in WhatIf' {
        $content = Get-Content (Join-Path $script:WindowsScripts '18-windows-containers.ps1') -Raw
        $content | Should -Match 'SupportsShouldProcess'
        $content | Should -Not -Match '(?m)^\s*\[switch\]\$WhatIf\s*,?\s*$'
    }
    It '41-devdrive-partition-setup does not redeclare built-in WhatIf' {
        $content = Get-Content (Join-Path $script:WindowsScripts '41-devdrive-partition-setup.ps1') -Raw
        $content | Should -Match 'SupportsShouldProcess'
        $content | Should -Not -Match '(?m)^\s*\[switch\]\$WhatIf\s*,?\s*$'
    }
}

Describe 'Dev Drive design' {
    It 'uses one valid 90 GB Dev Drive' {
        $content = Get-Content (Join-Path $script:WindowsScripts '41-devdrive-partition-setup.ps1') -Raw
        $content | Should -Match '\$DevDriveGB\s*=\s*90'
        $content | Should -Match '\$MinimumGB\s*=\s*50'
        $content | Should -Match 'Format-Volume[\s\S]*-DevDrive'
        $content | Should -Match "-NewFileSystemLabel\s+'DevCache'"
        $content | Should -Not -Match "-NewFileSystemLabel\s+'DevCode'"
    }
    It 'uses Windows supported C shrink limits and 30 percent safety floor' {
        $content = Get-Content (Join-Path $script:WindowsScripts '41-devdrive-partition-setup.ps1') -Raw
        $content | Should -Match 'Get-PartitionSupportedSize'
        $content | Should -Match 'SizeMin'
        $content | Should -Match 'projectedPct\s+-lt\s+30'
    }
    It 'does not terminate the parent setup process on successful WhatIf/idempotent paths' {
        $content = Get-Content (Join-Path $script:WindowsScripts '41-devdrive-partition-setup.ps1') -Raw
        $content | Should -Not -Match 'exit\s+0'
    }
    It 'uses documented Dev Drive trust/query operations' {
        $content = Get-Content (Join-Path $script:WindowsScripts '41-devdrive-partition-setup.ps1') -Raw
        $content | Should -Match 'fsutil\.exe'
        $content | Should -Match 'devdrv\s+trust'
        $content | Should -Match 'devdrv\s+query'
    }
}

Describe 'Windows executable resolution' {
    It 'performance tuning resolves Windows utilities explicitly' {
        $content = Get-Content (Join-Path $script:WindowsScripts '31-performance-tuning.ps1') -Raw
        $content | Should -Match 'System32\\powercfg\.exe'
        $content | Should -Match 'System32\\reg\.exe'
        $content | Should -Match 'System32\\netsh\.exe'
        $content | Should -Match 'System32\\Dism\.exe'
    }
    It 'performance tuning uses C DevCache and registers its future search exclusion' {
        $content = Get-Content (Join-Path $script:WindowsScripts '31-performance-tuning.ps1') -Raw
        $content | Should -Match "DevCachePath\s*=\s*'C:\\DevCache'"
        $content | Should -Match 'Search.*Dev Drive|Dev Drive.*search|Windows Search'
    }
}

Describe 'Cache safety' {
    It 'does not redirect TEMP/TMP or overwrite Docker Desktop daemon.json' {
        $content = Get-Content (Join-Path $script:WindowsScripts '40-devdrive-caches.ps1') -Raw
        $content | Should -Match 'TEMP/TMP were intentionally left unchanged'
        $content | Should -Match 'Docker Desktop daemon.json was intentionally left unchanged'
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
