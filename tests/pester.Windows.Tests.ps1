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

  It "WSL 2 is installed and set as default" {
    $wslVersion = wsl --status 2>&1 | Select-String "Default Version"
    $wslVersion | Should -Match "2"
  }

  It "Ubuntu is installed in WSL" {
    $distros = wsl -l -v 2>&1
    $distros | Should -Match "Ubuntu"
  }

  It ".wslconfig exists with sparse VHD enabled" {
    $wslConfig = Join-Path $env:UserProfile ".wslconfig"
    Test-Path $wslConfig | Should -BeTrue
    $content = Get-Content $wslConfig -Raw
    $content | Should -Match "sparseVhd\s*=\s*true"
  }

  It "Core CLIs exist" -TestCases @(
    @{Cmd='git'},{Cmd='gh'},{Cmd='pwsh'},{Cmd='node'},{Cmd='python'},{Cmd='go'},
    @{Cmd='cargo'},{Cmd='dotnet'},{Cmd='java'},{Cmd='mvn'},{Cmd='gradle'},
    @{Cmd='terraform'},{Cmd='packer'},{Cmd='tflint'},{Cmd='aws'},{Cmd='az'},
    @{Cmd='gcloud'},{Cmd='op'},{Cmd='code'},{Cmd='docker'}
  ) {
    param($Cmd)
    (Get-Command $Cmd -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
  }

  It "Security scanning tools exist" -TestCases @(
    @{Cmd='snyk'},{Cmd='trivy'}
  ) {
    param($Cmd)
    (Get-Command $Cmd -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
  }

  It "1Password CLI available" {
    (Get-Command op -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
  }

  It "Docker Desktop is running" {
    { docker info 2>&1 | Out-Null } | Should -Not -Throw
  }

  It "Firewall is enabled for all profiles" {
    $profiles = Get-NetFirewallProfile
    $profiles | ForEach-Object { $_.Enabled | Should -Be $true }
  }

  It "Defender PUA protection is enabled" {
    $mp = Get-MpPreference
    $mp.PUAProtection | Should -Be 1
  }

  It "Defender Network Protection is enabled" {
    $mp = Get-MpPreference
    $mp.EnableNetworkProtection | Should -Be 1
  }

  It "ASR rules are configured" {
    $mp = Get-MpPreference
    $mp.AttackSurfaceReductionRules_Ids | Should -Not -BeNullOrEmpty
  }

  It "BitLocker is ON for C:" {
    $bl = Get-BitLockerVolume -MountPoint C: -ErrorAction SilentlyContinue
    $bl.ProtectionStatus | Should -Be 'On'
  }

  It "LSA RunAsPPL is enabled" {
    $lsa = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -ErrorAction SilentlyContinue
    $lsa.RunAsPPL | Should -Be 1
  }

  It "Credential Guard is enabled" {
    $cg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LsaCfgFlags" -ErrorAction SilentlyContinue
    $cg.LsaCfgFlags | Should -Be 1
  }

  It "UAC is set to always notify" {
    $uac = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue
    $uac.ConsentPromptBehaviorAdmin | Should -Be 2
  }

  It "HVCI (Core Isolation) is enabled" {
    $hvci = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -ErrorAction SilentlyContinue
    $hvci.Enabled | Should -Be 1
  }

  It "SMBv1 is disabled" {
    $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
    $smb1.State | Should -Be 'Disabled'
  }

  It "OpenSSH Server is installed and running" {
    $sshd = Get-Service sshd -ErrorAction SilentlyContinue
    $sshd.Status | Should -Be 'Running'
  }

  It "Storage Sense is enabled" {
    $ss = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -ErrorAction SilentlyContinue
    $ss.'01' | Should -Be 1
  }

  It "Dev Drive (ReFS) exists" {
    $refs = Get-Volume | Where-Object FileSystem -eq "ReFS"
    $refs | Should -Not -BeNullOrEmpty
  }

  It "Docker daemon.json configured with data-root" {
    $dockerConfig = "$env:ProgramData\Docker\config\daemon.json"
    if (Test-Path $dockerConfig) {
      $config = Get-Content $dockerConfig -Raw | ConvertFrom-Json
      $config.'data-root' | Should -Not -BeNullOrEmpty
    }
  }

  It "Cache environment variables are set" -TestCases @(
    @{Var='GRADLE_USER_HOME'},{Var='GOPATH'},{Var='CARGO_HOME'},
    @{Var='COMPOSER_HOME'},{Var='PIPX_HOME'}
  ) {
    param($Var)
    [Environment]::GetEnvironmentVariable($Var, 'User') | Should -Not -BeNullOrEmpty
  }

  It "Backblaze is installed" {
    # Backblaze may not have CLI in PATH, check winget instead
    # NOTE: This is optional (in 11-licensed-apps.ps1), so don't fail if missing
    $installed = winget list --id Backblaze.Backblaze 2>&1
    if ($installed -match "Backblaze") {
      $true | Should -Be $true
    } else {
      Set-ItResult -Skipped -Because "Backblaze is optional (licensed app)"
    }
  }

  It "GlassWire is installed" {
    # GlassWire is a GUI/network monitor; check winget for presence
    # NOTE: This is optional (in 11-licensed-apps.ps1), so don't fail if missing
    $gw = winget list --name GlassWire 2>&1
    if ($gw -match "GlassWire") {
      $true | Should -Be $true
    } else {
      Set-ItResult -Skipped -Because "GlassWire is optional (licensed app)"
    }
  }

  It "Malwarebytes is installed" {
    # Malwarebytes anti-malware; check winget for presence
    # NOTE: This is optional (in 11-licensed-apps.ps1), so don't fail if missing
    $mb = winget list --name Malwarebytes 2>&1
    if ($mb -match "Malwarebytes") {
      $true | Should -Be $true
    } else {
      Set-ItResult -Skipped -Because "Malwarebytes is optional (licensed app)"
    }
  }

  It "System Protection is enabled on C:" {
    $rp = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
    # At least one restore point should exist
    $rp | Should -Not -BeNullOrEmpty
  }

  It "Windows Search service is disabled" {
    $wsearch = Get-Service WSearch -ErrorAction SilentlyContinue
    $wsearch.StartType | Should -Be 'Disabled'
  }

  It "Everything search is installed" {
    $everything = Get-Command "Everything" -ErrorAction SilentlyContinue
    $everything | Should -Not -BeNullOrEmpty
  }

  It "SysMain (Superfetch) is disabled" {
    $sysmain = Get-Service SysMain -ErrorAction SilentlyContinue
    $sysmain.StartType | Should -Be 'Disabled'
  }

  It "Scheduled task for winget upgrades exists" {
    $result = schtasks /Query /TN "Dev-Winget-Weekly-Upgrade" /FO LIST 2>$null
    $LASTEXITCODE | Should -Be 0
    $result | Should -Not -BeNullOrEmpty
  }

  It "Scheduled task for .NET maintenance exists" {
    $result = schtasks /Query /TN "Dev-DotNet-Weekly-Maintenance" /FO LIST 2>$null
    $LASTEXITCODE | Should -Be 0
    $result | Should -Not -BeNullOrEmpty
  }
}

Invoke-Pester -EnableExit

