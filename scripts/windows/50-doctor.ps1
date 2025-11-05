Param([switch]$VerboseOut)

$ok  = "[✓]"
$bad = "[✗]"
$inf = "[i]"

function Test-Command($n){ $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }
function Note($msg){ Write-Host "$inf $msg" -ForegroundColor Cyan }
function Pass($msg){ Write-Host "$ok $msg" -ForegroundColor Green }
function Fail($msg){ Write-Host "$bad $msg" -ForegroundColor Red }

Note "Surface Dev Doctor — Windows"

Pass "Windows $([Environment]::OSVersion.VersionString)  Arch: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)"

# WSL status
try {
  $wsl = wsl.exe -l -v 2>$null
  if ($LASTEXITCODE -eq 0 -and ($wsl -match "Ubuntu")) { Pass "WSL installed; Ubuntu present" } else { Fail "WSL/Ubuntu not found. Open Ubuntu from Start or reinstall" }
} catch { Fail "WSL check error: $_" }

# Docker CLI
if (Test-Command "docker") {
  try { docker info -f '{{.ServerVersion}}' | Out-Null; Pass "Docker Desktop CLI reachable" } catch { Fail "Docker CLI not responding — start Docker Desktop" }
} else { Fail "Docker not on PATH" }

# Core CLIs
$need = @(
  "git","gh","python","py","node","npm","go","rustup","cargo",
  "dotnet","java","mvn","gradle","terraform","packer","tflint",
  "aws","az","gcloud","pwsh","op"
)
foreach ($n in $need) {
  if (Test-Command $n) { Pass "$n found" } else { Fail "$n missing" }
}

# VS Code CLI
if (Test-Command "code") { Pass "VS Code 'code' CLI available" } else { Fail "VS Code CLI not on PATH (open VS Code once, then retry)" }

# Defender settings
try {
  $mp = Get-MpPreference
  if ($mp.PUAProtection -eq 1) { Pass "Defender PUA protection: Enabled" } else { Fail "Defender PUA protection: Disabled" }
  if ($mp.EnableNetworkProtection -eq 1) { Pass "Defender Network Protection: Enabled" } else { Fail "Network Protection: Disabled" }
  $ids = $mp.AttackSurfaceReductionRules_Ids
  $acts = $mp.AttackSurfaceReductionRules_Actions
  if ($ids) {
    $aud = 0; $enf = 0
    for ($i=0; $i -lt $ids.Count; $i++){ if ($acts[$i] -eq 2){$aud++} elseif ($acts[$i] -eq 1){$enf++} }
    Pass "ASR rules present — Enforced:$enf  Audit:$aud"
  } else { Fail "ASR rules not configured" }
} catch { Fail "Defender query failed: $_" }

# Firewall
try {
  $profiles = Get-NetFirewallProfile
  if (($profiles | Where-Object { -not $_.Enabled }).Count -eq 0) { Pass "Firewall ON for Domain/Private/Public" } else { Fail "Firewall disabled on some profile(s)" }
} catch { Fail "Firewall query failed: $_" }

# BitLocker
try {
  $bl = Get-BitLockerVolume -MountPoint C: -ErrorAction Stop
  if ($bl.ProtectionStatus -eq 'On') { Pass "BitLocker ON for C:" } else { Fail "BitLocker OFF on C:" }
} catch { Fail "BitLocker not available on this edition or query failed" }

# .wslconfig
$wslCfgPath = Join-Path $env:UserProfile ".wslconfig"
if (Test-Path $wslCfgPath) { Pass ".wslconfig found at $wslCfgPath" } else { Fail ".wslconfig missing (resource caps for WSL not set)" }

# Dev Drive (ReFS)
try {
  $refs = Get-Volume | Where-Object FileSystem -eq "ReFS"
  if ($refs) { Pass "Dev Drive (ReFS) present: $($refs | ForEach-Object { $_.DriveLetter + ':' } -join ' ')" } else { Fail "No ReFS volume found (Dev Drive not created)" }
} catch { Fail "Volume query failed: $_" }

# Winget scheduled task
$taskName = "Dev-Winget-Weekly-Upgrade"
schtasks /Query /TN $taskName /FO LIST 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { Pass "Winget weekly upgrade task present" } else { Fail "Winget weekly upgrade task missing" }

# Optional: versions
if ($VerboseOut) {
  Note "Versions:"
  foreach ($cmd in @("python --version","node --version","go version","rustc --version","dotnet --version","java -version","mvn -v","gradle -v","terraform -version","tflint --version","aws --version","az version","gcloud --version")) {
    try { Write-Host "  $cmd → " -NoNewline; Invoke-Expression $cmd | Select-Object -First 1 } catch {}
  }
}

Write-Host ""
Pass "Doctor check finished"
