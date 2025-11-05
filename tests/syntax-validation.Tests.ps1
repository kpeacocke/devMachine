# Syntax validation tests for all PowerShell scripts
# Run with: pwsh -NoProfile -File .\tests\syntax-validation.Tests.ps1

$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

$ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Describe "PowerShell Script Syntax Validation" {
    
    $scripts = Get-ChildItem -Path $ScriptRoot -Recurse -Filter "*.ps1" | 
        Where-Object { $_.FullName -notlike "*\node_modules\*" }
    
    It "Found PowerShell scripts to validate" {
        $scripts.Count | Should -BeGreaterThan 0
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
    
    $scripts = Get-ChildItem -Path $ScriptRoot -Recurse -Filter "*.sh" | 
        Where-Object { $_.FullName -notlike "*\node_modules\*" }
    
    It "Found Bash scripts to validate" {
        $scripts.Count | Should -BeGreaterThan 0
    }
    
    foreach ($script in $scripts) {
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
    
    $setupScript = Join-Path $ScriptRoot "setup-machine.ps1"
    
    It "setup-machine.ps1 exists" {
        Test-Path $setupScript | Should -BeTrue
    }
    
    It "setup-machine.ps1 has valid syntax" {
        { [scriptblock]::Create((Get-Content -Path $setupScript -Raw)) } | 
            Should -Not -Throw
    }
    
    It "setup-machine.ps1 defines required parameters" {
        $content = Get-Content -Path $setupScript -Raw
        $content | Should -Match '\[switch\]\$SkipBackup'
        $content | Should -Match '\[switch\]\$SkipLicensedApps'
        $content | Should -Match '\[switch\]\$SkipOptionalGoodies'
    }
    
    It "setup-machine.ps1 has no Unicode box-drawing characters" {
        $content = Get-Content -Path $setupScript -Raw
        # Check for common problematic Unicode chars
        $content | Should -Not -Match '[╔╗║╚═]'
        $content | Should -Not -Match '[☐☑✓✗]'
    }
    
    It "setup-machine.ps1 properly escapes ampersands in strings" {
        $content = Get-Content -Path $setupScript -Raw
        # This is a basic check - ampersands in strings should not cause parser errors
        { [scriptblock]::Create($content) } | Should -Not -Throw
    }
}

$config = New-PesterConfiguration
$config.Run.Path = $PSCommandPath
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
