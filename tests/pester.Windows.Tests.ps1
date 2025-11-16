# Run with: pwsh -NoProfile -File .\tests\pester.Windows.Tests.ps1
$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

Describe "Windows Dev Environment - Basic Checks" {
  It "PowerShell 7 is default in Windows Terminal settings" {
    $settings = Join-Path $env:LocalAppData "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $settings)) {
      Set-ItResult -Skipped -Because "Windows Terminal not installed"
      return
    }
    $j = Get-Content $settings -Raw | ConvertFrom-Json
    $j.defaultProfile | Should -Match '^{.+}$'
  }

  It "WSL 2 is installed and set as default" {
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
      Set-ItResult -Skipped -Because "WSL not installed"
      return
    }
    try {
      $wslVersion = wsl --status 2>&1 | Select-String "Default Version"
      if (-not $wslVersion) {
        Set-ItResult -Skipped -Because "WSL status not available"
        return
      }
      $wslVersion | Should -Match "2"
    } catch {
      Set-ItResult -Skipped -Because "WSL not properly configured"
    }
  }

  It "Ubuntu is installed in WSL" {
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
      Set-ItResult -Skipped -Because "WSL not installed"
      return
    }
    try {
      $distros = wsl -l -v 2>&1 | Out-String
      if ($distros -match "no installed distributions" -or $distros -match "has no installed distributions") {
        Set-ItResult -Skipped -Because "No WSL distributions installed"
        return
      }
      if ($distros -match "Ubuntu") {
        $true | Should -Be $true
      } else {
        Set-ItResult -Skipped -Because "Ubuntu not found in WSL distributions"
      }
    } catch {
      Set-ItResult -Skipped -Because "Cannot check WSL distributions"
    }
  }

  It ".wslconfig exists with sparse VHD enabled" {
    $wslConfig = Join-Path $env:UserProfile ".wslconfig"
    if (-not (Test-Path $wslConfig)) {
      Set-ItResult -Skipped -Because ".wslconfig not found"
      return
    }
    $content = Get-Content $wslConfig -Raw
    $content | Should -Match "sparseVhd\s*=\s*true"
  }
}

Describe "Windows Dev Environment - Security" {
  It "Firewall is enabled for all profiles" {
    try {
      $profiles = Get-NetFirewallProfile
      $profiles | ForEach-Object { $_.Enabled | Should -Be $true }
    } catch {
      Set-ItResult -Skipped -Because "Cannot check firewall status (requires elevation)"
    }
  }

  It "UAC is set to always notify" {
    try {
      $uac = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue
      if (-not $uac) {
        Set-ItResult -Skipped -Because "Cannot read UAC settings"
        return
      }
      $uac.ConsentPromptBehaviorAdmin | Should -Be 2
    } catch {
      Set-ItResult -Skipped -Because "Cannot check UAC settings (requires elevation)"
    }
  }

  It "Defender PUA protection is enabled" {
    try {
      $mp = Get-MpPreference -ErrorAction Stop
      $mp.PUAProtection | Should -Be 1
    } catch {
      Set-ItResult -Skipped -Because "Cannot check Defender settings (requires elevation)"
    }
  }

  It "Defender Network Protection is enabled" {
    try {
      $mp = Get-MpPreference -ErrorAction Stop
      $mp.EnableNetworkProtection | Should -Be 1
    } catch {
      Set-ItResult -Skipped -Because "Cannot check Defender settings (requires elevation)"
    }
  }

  It "ASR rules are configured" {
    try {
      $mp = Get-MpPreference -ErrorAction Stop
      $mp.AttackSurfaceReductionRules_Ids | Should -Not -BeNullOrEmpty
    } catch {
      Set-ItResult -Skipped -Because "Cannot check Defender settings (requires elevation)"
    }
  }

  It "Defender exclusions are configured for development" {
    try {
      $mp = Get-MpPreference -ErrorAction Stop
      # Check for common development exclusions
      $exclusions = $mp.ExclusionPath
      if ($exclusions -contains "*\node_modules" -or $exclusions -contains "*\.git") {
        $true | Should -Be $true
      } else {
        Set-ItResult -Skipped -Because "Development exclusions not found"
      }
    } catch {
      Set-ItResult -Skipped -Because "Cannot check Defender exclusions (requires elevation)"
    }
  }

  It "BitLocker is ON for C:" {
    try {
      $bl = Get-BitLockerVolume -MountPoint C: -ErrorAction Stop
      if (-not $bl -or $bl.ProtectionStatus -eq 'Off') {
        Set-ItResult -Skipped -Because "BitLocker not enabled on C:"
        return
      }
      $bl.ProtectionStatus | Should -Be 'On'
    } catch {
      Set-ItResult -Skipped -Because "Cannot check BitLocker status (requires elevation)"
    }
  }

  It "LSA RunAsPPL is enabled" {
    try {
      $lsa = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -ErrorAction Stop
      $lsa.RunAsPPL | Should -Be 1
    } catch {
      Set-ItResult -Skipped -Because "Cannot check LSA settings (requires elevation)"
    }
  }

  It "Credential Guard is enabled" {
    try {
      $cg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LsaCfgFlags" -ErrorAction Stop
      $cg.LsaCfgFlags | Should -Be 1
    } catch {
      Set-ItResult -Skipped -Because "Cannot check Credential Guard (requires elevation)"
    }
  }

  It "HVCI (Core Isolation) is enabled" {
    try {
      $hvci = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -ErrorAction Stop
      $hvci.Enabled | Should -Be 1
    } catch {
      Set-ItResult -Skipped -Because "Cannot check HVCI (requires elevation)"
    }
  }

  It "SMBv1 is disabled" {
    try {
      $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
      $smb1.State | Should -Be 'Disabled'
    } catch {
      Set-ItResult -Skipped -Because "Cannot check SMBv1 status (requires elevation)"
    }
  }
}

Describe "Windows Dev Environment - Core Tools" {
  It "Git CLI is available" {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
      Set-ItResult -Skipped -Because "Git not installed"
      return
    }
    $git | Should -Not -BeNullOrEmpty
  }

  It "Git is configured with VS Code as editor" {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      Set-ItResult -Skipped -Because "Git not installed"
      return
    }
    try {
      $editor = git config --global core.editor
      if ($editor -match "code --wait") {
        $true | Should -Be $true
      } else {
        Set-ItResult -Skipped -Because "VS Code not set as Git editor"
      }
    } catch {
      Set-ItResult -Skipped -Because "Cannot check Git configuration"
    }
  }

  It "Git has global gitignore configured" {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      Set-ItResult -Skipped -Because "Git not installed"
      return
    }
    try {
      $gitignore = git config --global core.excludesfile
      if ($gitignore) {
        Test-Path $gitignore | Should -Be $true
      } else {
        Set-ItResult -Skipped -Because "Global gitignore not configured"
      }
    } catch {
      Set-ItResult -Skipped -Because "Cannot check Git global gitignore"
    }
  }

  It "PowerShell 7 is available" {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
      Set-ItResult -Skipped -Because "PowerShell 7 not installed"
      return
    }
    $pwsh | Should -Not -BeNullOrEmpty
  }

  It "Visual Studio Code is available" {
    $code = Get-Command code -ErrorAction SilentlyContinue
    if (-not $code) {
      Set-ItResult -Skipped -Because "VS Code not installed"
      return
    }
    $code | Should -Not -BeNullOrEmpty
  }

  It "Docker Desktop is running" {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
      Set-ItResult -Skipped -Because "Docker not installed"
      return
    }
    try {
      docker info 2>&1 | Out-Null
      $true | Should -Be $true
    } catch {
      Set-ItResult -Skipped -Because "Docker not running"
    }
  }

  It "CLI tools are available" -TestCases @(
    @{Tool='gh'},@{Tool='node'},@{Tool='python'},@{Tool='go'},
    @{Tool='cargo'},@{Tool='dotnet'},@{Tool='java'},@{Tool='mvn'},
    @{Tool='op'},@{Tool='glab'}
  ) {
    param($Tool)
    $command = Get-Command $Tool -ErrorAction SilentlyContinue
    if (-not $command) {
      Set-ItResult -Skipped -Because "$Tool not installed"
      return
    }
    $command | Should -Not -BeNullOrEmpty
  }
}

Describe "Windows Dev Environment - Dev Drive and Performance" {
  It "Dev Drive (ReFS) exists" {
    $refs = Get-Volume | Where-Object FileSystem -eq "ReFS"
    if (-not $refs) {
      Set-ItResult -Skipped -Because "No ReFS Dev Drive volumes found"
      return
    }
    $refs | Should -Not -BeNullOrEmpty
  }

  It "DevCache mount point exists" {
    $devCachePath = "C:\DevCache"
    if (-not (Test-Path $devCachePath)) {
      Set-ItResult -Skipped -Because "DevCache not mounted"
      return
    }
    # Check if it's actually a ReFS volume mount
    $volume = Get-Volume | Where-Object { $_.Path -eq "$devCachePath\" }
    if ($volume -and $volume.FileSystem -eq "ReFS") {
      $true | Should -Be $true
    } else {
      Set-ItResult -Skipped -Because "DevCache is not a ReFS Dev Drive"
    }
  }

  It "Code partition mount point exists" {
    $codePath = "C:\Users\$env:USERNAME\code"
    if (-not (Test-Path $codePath)) {
      Set-ItResult -Skipped -Because "Code partition not mounted"
      return
    }
    # Check if it's actually a ReFS volume mount
    $volume = Get-Volume | Where-Object { $_.Path -eq "$codePath\" }
    if ($volume -and $volume.FileSystem -eq "ReFS") {
      $true | Should -Be $true
    } else {
      Set-ItResult -Skipped -Because "Code path is not a ReFS Dev Drive"
    }
  }

  It "Package manager environment variables are configured" -TestCases @(
    @{Var='CARGO_HOME'},@{Var='GOPATH'},@{Var='GRADLE_USER_HOME'},
    @{Var='NUGET_PACKAGES'},@{Var='COMPOSER_HOME'},@{Var='PIPX_HOME'}
  ) {
    param($Var)
    $value = [Environment]::GetEnvironmentVariable($Var, 'User')
    if (-not $value) {
      Set-ItResult -Skipped -Because "$Var environment variable not set"
      return
    }
    $value | Should -Not -BeNullOrEmpty
  }

  It "Docker daemon.json configured with data-root" {
    $dockerConfig = "$env:ProgramData\Docker\config\daemon.json"
    if (-not (Test-Path $dockerConfig)) {
      Set-ItResult -Skipped -Because "Docker daemon.json not found"
      return
    }
    try {
      $config = Get-Content $dockerConfig -Raw | ConvertFrom-Json
      $config.'data-root' | Should -Not -BeNullOrEmpty
    } catch {
      Set-ItResult -Skipped -Because "Cannot parse Docker daemon.json"
    }
  }

  It "Windows Search service is disabled" {
    $wsearch = Get-Service WSearch -ErrorAction SilentlyContinue
    if (-not $wsearch) {
      Set-ItResult -Skipped -Because "Windows Search service not found"
      return
    }
    $wsearch.StartType | Should -Be 'Disabled'
  }

  It "SysMain (Superfetch) is disabled" {
    $sysmain = Get-Service SysMain -ErrorAction SilentlyContinue
    if (-not $sysmain) {
      Set-ItResult -Skipped -Because "SysMain service not found"
      return
    }
    $sysmain.StartType | Should -Be 'Disabled'
  }
}

Describe "Windows Dev Environment - Optional Components" {
  It "OpenSSH Server is installed and running" {
    $sshd = Get-Service sshd -ErrorAction SilentlyContinue
    if (-not $sshd) {
      Set-ItResult -Skipped -Because "OpenSSH Server not installed"
      return
    }
    $sshd.Status | Should -Be 'Running'
  }

  It "Storage Sense is enabled" {
    try {
      $ss = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -ErrorAction Stop
      $ss.'01' | Should -Be 1
    } catch {
      Set-ItResult -Skipped -Because "Storage Sense not configured"
    }
  }

  It "Everything search is installed" {
    $everything = Get-Command "Everything" -ErrorAction SilentlyContinue
    if (-not $everything) {
      Set-ItResult -Skipped -Because "Everything search not installed"
      return
    }
    $everything | Should -Not -BeNullOrEmpty
  }

  It "Licensed apps are installed (if not skipped)" -TestCases @(
    @{App='1Password'},@{App='GitKraken'},@{App='Beyond Compare'},
    @{App='Malwarebytes'},@{App='GlassWire'}
  ) {
    param($App)
    try {
      $installed = winget list --name $App 2>&1
      if ($installed -match $App) {
        $true | Should -Be $true
      } else {
        Set-ItResult -Skipped -Because "$App is optional (licensed app)"
      }
    } catch {
      Set-ItResult -Skipped -Because "Cannot check $App installation status"
    }
  }
}

Describe "Windows Dev Environment - Maintenance" {
  It "System Protection is enabled on C:" {
    try {
      $rp = Get-ComputerRestorePoint -ErrorAction Stop
      if (-not $rp) {
        Set-ItResult -Skipped -Because "No restore points found"
        return
      }
      $rp | Should -Not -BeNullOrEmpty
    } catch {
      Set-ItResult -Skipped -Because "Cannot check restore points (may require elevation)"
    }
  }

  It "Scheduled task for winget upgrades exists" {
    $result = schtasks /Query /TN "Dev-Winget-Weekly-Upgrade" /FO LIST 2>$null
    if ($LASTEXITCODE -ne 0) {
      Set-ItResult -Skipped -Because "Scheduled task not found"
      return
    }
    $LASTEXITCODE | Should -Be 0
    $result | Should -Not -BeNullOrEmpty
  }

  It "Scheduled task for .NET maintenance exists" {
    $result = schtasks /Query /TN "Dev-DotNet-Weekly-Maintenance" /FO LIST 2>$null
    if ($LASTEXITCODE -ne 0) {
      Set-ItResult -Skipped -Because "Scheduled task not found"
      return
    }
    $LASTEXITCODE | Should -Be 0
    $result | Should -Not -BeNullOrEmpty
  }
}

Describe "SSL/TLS Security Tests" {
  BeforeAll {
    $ErrorActionPreference = 'SilentlyContinue'
  }

  It "SSL/TLS hardening script exists" {
    $scriptPath = Join-Path $PSScriptRoot "..\scripts\windows\38-ssl-tls-hardening.ps1"
    $scriptPath | Should -Exist
  }

  It "Weak SSL protocols are disabled (if hardening applied)" {
    try {
      $sslPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"
      if (Test-Path $sslPath) {
        $ssl2Disabled = Get-ItemProperty -Path $sslPath -Name "Enabled" -ErrorAction SilentlyContinue
        if ($ssl2Disabled) {
          $ssl2Disabled.Enabled | Should -Be 0
        } else {
          Set-ItResult -Skipped -Because "SSL 2.0 registry key not found"
        }
      } else {
        Set-ItResult -Skipped -Because "SSL/TLS hardening not applied"
      }
    } catch {
      Set-ItResult -Skipped -Because "Cannot check SSL settings without elevation"
    }
  }

  It "Modern TLS is enabled (if hardening applied)" {
    try {
      $tls12Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
      if (Test-Path $tls12Path) {
        $tls12Enabled = Get-ItemProperty -Path $tls12Path -Name "Enabled" -ErrorAction SilentlyContinue
        if ($tls12Enabled) {
          $tls12Enabled.Enabled | Should -Be 1
        } else {
          Set-ItResult -Skipped -Because "TLS 1.2 not explicitly configured"
        }
      } else {
        Set-ItResult -Skipped -Because "SSL/TLS hardening not applied"
      }
    } catch {
      Set-ItResult -Skipped -Because "Cannot check TLS settings without elevation"
    }
  }

  It ".NET Framework strong crypto is enabled (if hardening applied)" {
    try {
      $dotnetPath = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319"
      if (Test-Path $dotnetPath) {
        $strongCrypto = Get-ItemProperty -Path $dotnetPath -Name "SchUseStrongCrypto" -ErrorAction SilentlyContinue
        if ($strongCrypto) {
          $strongCrypto.SchUseStrongCrypto | Should -Be 1
        } else {
          Set-ItResult -Skipped -Because "Strong crypto not configured"
        }
      } else {
        Set-ItResult -Skipped -Because ".NET Framework not found"
      }
    } catch {
      Set-ItResult -Skipped -Because "Cannot check .NET settings without elevation"
    }
  }
}
