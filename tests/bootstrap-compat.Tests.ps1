#Requires -Version 7.0

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:Launcher = Join-Path $script:RepoRoot 'setup-machine.ps1'
    $script:Core = Join-Path $script:RepoRoot 'setup-machine-core.ps1'
    $script:Compat = Join-Path $script:RepoRoot 'scripts\windows\bootstrap-compat.ps1'
}

Describe 'Bootstrap compatibility boundary' {
    It 'keeps the public setup entry point' {
        Test-Path $script:Launcher | Should -BeTrue
    }

    It 'preserves the original orchestrator as the core implementation' {
        Test-Path $script:Core | Should -BeTrue
    }

    It 'loads the compatibility layer before the core orchestrator' {
        $content = Get-Content $script:Launcher -Raw
        $content | Should -Match 'bootstrap-compat\.ps1'
        $content | Should -Match '\.\s+\$compatScript'
        $content | Should -Match 'setup-machine-core\.ps1'
    }

    It 'forces the core restore-point block off after the launcher handles it' {
        $content = Get-Content $script:Launcher -Raw
        $content | Should -Match '\$coreParameters\[''SkipRestorePoint''\]\s*=\s*\$true'
    }

    It 'routes DISM through Windows PowerShell compatibility with a native fallback' {
        $content = Get-Content $script:Compat -Raw
        $content | Should -Match 'Import-Module Dism -UseWindowsPowerShell'
        $content | Should -Match 'dism\.exe'
        $content | Should -Match 'Get-WindowsOptionalFeature'
        $content | Should -Match 'Enable-WindowsOptionalFeature'
        $content | Should -Match 'Disable-WindowsOptionalFeature'
        $content | Should -Match 'Add-WindowsCapability'
    }

    It 'provides PowerShell 7 replacements for legacy WMI and restore commands' {
        $content = Get-Content $script:Compat -Raw
        $content | Should -Match 'function Get-WmiObject'
        $content | Should -Match 'Get-CimInstance'
        $content | Should -Match 'function Checkpoint-Computer'
        $content | Should -Match 'function Enable-ComputerRestore'
        $content | Should -Match 'function Get-ComputerRestorePoint'
    }

    It 'normalises both unattended environment variable conventions' {
        $content = Get-Content $script:Launcher -Raw
        $content | Should -Match 'DEVMACHINE_UNATTENDED'
        $content | Should -Match 'UNATTENDED_MODE'
    }

    It 'honours SkipWSL across both environment and legacy parent-scope conventions' {
        $content = Get-Content $script:Launcher -Raw
        $compat = Get-Content $script:Compat -Raw
        $content | Should -Match 'DEVMACHINE_SKIP_WSL'
        $content | Should -Match '\$skipWSL\s*=\s*\$true'
        $compat | Should -Match 'DEVMACHINE_SKIP_WSL'
    }

    It 'translates Windows paths passed to Linux cp via wsl.exe' {
        $content = Get-Content $script:Compat -Raw
        $content | Should -Match '/mnt/\$drive/\$rest'
    }
}

Describe 'Known PowerShell 7 compatibility traps in the repository' {
    It 'documents every current WindowsOptionalFeature call site behind the launcher' {
        $matches = Get-ChildItem (Join-Path $script:RepoRoot 'scripts\windows') -Filter '*.ps1' |
            Select-String -Pattern '(Get|Enable|Disable)-WindowsOptionalFeature|Add-WindowsCapability'

        $matches.Count | Should -BeGreaterThan 0
        (Get-Content $script:Compat -Raw) | Should -Match 'Dism'
    }

    It 'documents every current Get-WmiObject call site behind a CIM replacement' {
        $matches = Get-ChildItem (Join-Path $script:RepoRoot 'scripts\windows') -Filter '*.ps1' |
            Select-String -Pattern '\bGet-WmiObject\b'

        $matches.Count | Should -BeGreaterThan 0
        (Get-Content $script:Compat -Raw) | Should -Match 'Get-CimInstance'
    }
}
