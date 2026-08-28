<#
Purpose: Install/upgrade latest PowerShell 7 and make it the default shell/terminal.
Run:  PowerShell (Admin) → .\00-pwsh-first.ps1
      (Script will handle execution policy automatically)
#>
$ErrorActionPreference = 'Stop'

# Ensure script execution is allowed for subsequent scripts
Write-Host "[PWSH] Checking PowerShell execution policy..." -ForegroundColor Cyan
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
    Write-Host "  Setting execution policy to RemoteSigned for CurrentUser scope..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Write-Host "  ✅ Execution policy set to RemoteSigned" -ForegroundColor Green
    } catch {
        Write-Warning "Could not set execution policy. You may need to run as Administrator."
        Write-Host "  💡 Manual fix: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned" -ForegroundColor Yellow
        Write-Host "  💡 Or run this script as: PowerShell (Admin) → Set-ExecutionPolicy Bypass -Scope Process -Force; .\00-pwsh-first.ps1" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✅ Execution policy is already permissive: $currentPolicy" -ForegroundColor Green
}

Write-Host "[SETUP] Ensuring latest PowerShell 7 from the winget source..."
$existingPwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($existingPwsh) {
    Write-Host "  Existing PowerShell 7: $($existingPwsh.Source)" -ForegroundColor Gray
    # `winget install` does not reliably upgrade an existing installation. Use
    # upgrade explicitly, and pin the source so we get the normal winget/MSI
    # package rather than relying on source selection.
    winget upgrade --id Microsoft.PowerShell --exact --source winget --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        # A non-zero result commonly means there is no applicable upgrade. Do not
        # fail bootstrap solely for that; verify pwsh exists after PATH refresh.
        Write-Host "  ℹ️  PowerShell upgrade returned exit code $LASTEXITCODE; continuing with installed version" -ForegroundColor Gray
    }
} else {
    winget install --id Microsoft.PowerShell --exact --source winget --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "PowerShell 7 installation failed with winget exit code $LASTEXITCODE"
    }
}

# Refresh PATH in-session
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
             [Environment]::GetEnvironmentVariable('Path','User')

$pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwshCommand) {
    throw "PowerShell 7 installation completed but pwsh.exe is not available in PATH"
}
Write-Host "  ✅ PowerShell 7 available: $($pwshCommand.Source)" -ForegroundColor Green

# Ensure Windows Terminal is installed (as default terminal host)
Write-Host "[SETUP] Ensuring Windows Terminal is present..."
try { winget install --id Microsoft.WindowsTerminal --exact --source winget --silent --accept-source-agreements --accept-package-agreements } catch {}

# Make Windows Terminal the default terminal application (Windows 11 setting)
try {
  reg add "HKCU\Console\%%Startup" /v DelegationConsole /t REG_DWORD /d 1 /f | Out-Null
  reg add "HKCU\Console\%%Startup" /v DelegationTerminal /t REG_DWORD /d 1 /f | Out-Null
  Write-Host "[OK] Windows Terminal set as default terminal host"
} catch { Write-Warning "Could not set Windows Terminal as default terminal host: $_" }

# Set PowerShell 7 as default profile inside Windows Terminal settings.json
$settingsPath = Join-Path $env:LocalAppData "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $settingsPath)) {
  # New installs create the file on first launch; seed a minimal config if missing
  New-Item -ItemType Directory -Force -Path (Split-Path $settingsPath) | Out-Null
  '{"$schema":"https://aka.ms/terminal-profiles-schema","defaultProfile":"{00000000-0000-0000-0000-000000000000}","profiles":{"list":[]}}' |
    Out-File -Encoding utf8 $settingsPath
}

# Load & patch JSON (minimal, robust)
$json = Get-Content $settingsPath -Raw | ConvertFrom-Json
if (-not $json.profiles) { $json | Add-Member -Name profiles -MemberType NoteProperty -Value (@{ list = @() }) }

# Find/create a pwsh profile entry
$pwshPath = $pwshCommand.Source
$pwshId   = [guid]::NewGuid().Guid
$pwshProf = @{
  name = "PowerShell 7"
  commandline = $pwshPath
  guid = "{${pwshId}}"
  startingDirectory = "%USERPROFILE%"
}
# If one exists, reuse its guid; else append
$existing = $json.profiles.list | Where-Object { $_.commandline -like "*pwsh*" }
if ($existing) { $pwshProf.guid = $existing.guid; $pwshProf.name = $existing.name }

if (-not $existing) { $json.profiles.list += $pwshProf }
$json.defaultProfile = $pwshProf.guid

# Save back
($json | ConvertTo-Json -Depth 10) | Out-File -Encoding utf8 $settingsPath
Write-Host "[OK] PowerShell 7 set as the default shell in Windows Terminal."

Write-Host "Done. Open a new Windows Terminal window - it should start in PowerShell 7."
