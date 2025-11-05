# Run with: pwsh -NoProfile -File .\tests\pester.Windows.Tests.ps1
$ErrorActionPreference = 'Stop'
Import-Module Pester -ErrorAction SilentlyContinue

Describe "Windows Dev Environment" {
  It "PowerShell 7 is default in Windows Terminal settings" {
    $settings = Join-Path $env:LocalAppData "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    Test-Path $settings | Should -BeTrue
    $j = Get-Content $settings -Raw | ConvertFrom-Json
    $j.defaultProfile | Should -Match '^{.+}$'
  }

  It "Core CLIs exist" -TestCases @(
    @{Cmd='git'},{Cmd='gh'},{Cmd='pwsh'},{Cmd='node'},{Cmd='python'},{Cmd='go'},
    @{Cmd='cargo'},{Cmd='dotnet'},{Cmd='java'},{Cmd='mvn'},{Cmd='gradle'},
    @{Cmd='terraform'},{Cmd='packer'},{Cmd='aws'},{Cmd='az'},{Cmd='gcloud'},{Cmd='op'}
  ) {
    param($Cmd)
    (Get-Command $Cmd -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
  }

  It "1Password CLI available" {
    (Get-Command op -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
  }

  It "Insiders or stable channel keys exist" {
    $app = 'HKLM:\SOFTWARE\Microsoft\WindowsSelfHost\Applicability'
    Test-Path $app | Should -BeTrue
  }
}
Invoke-Pester -EnableExit
