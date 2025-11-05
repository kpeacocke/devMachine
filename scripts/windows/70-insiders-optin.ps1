<#
Opt into Insider/preview channels:

- Windows: Canary (most forward). If you prefer Dev, set $WindowsInsiderChannel = 'Dev'
- Office: BetaChannel (formerly “Insider Fast”)
- VS Code: install Insiders, optionally make 'code' -> 'code-insiders'

Limitations:
- You must link a Microsoft account to Windows Insider manually (Settings UI will be opened for you).
#>

$ErrorActionPreference = 'Stop'

# === Settings you can tweak ===
$WindowsInsiderChannel = 'Canary'   # 'Canary' | 'Dev' | 'Beta' | 'ReleasePreview'
$MakeCodeCLIPointToInsiders = $true # make 'code' invoke 'code-insiders'

Write-Host "🪟 Windows Insider: target channel = $WindowsInsiderChannel"

# 1) WINDOWS INSIDER CHANNEL
$sel = 'HKLM:\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection'
$app = 'HKLM:\SOFTWARE\Microsoft\WindowsSelfHost\Applicability'
New-Item -Path $sel -Force | Out-Null
New-Item -Path $app -Force | Out-Null

switch ($WindowsInsiderChannel) {
  'Canary'         { $Ring='Canary'; $BranchName='Canary' }
  'Dev'            { $Ring='Dev';    $BranchName='Dev' }
  'Beta'           { $Ring='Beta';   $BranchName='Beta' }
  'ReleasePreview' { $Ring='External'; $BranchName='ReleasePreview' }
  default          { throw "Unknown WindowsInsiderChannel '$WindowsInsiderChannel'" }
}

New-ItemProperty -Path $sel -Name 'UIContentType' -Type String -Value 'Mainline' -Force | Out-Null
New-ItemProperty -Path $sel -Name 'UIRing'        -Type String -Value $Ring        -Force | Out-Null
New-ItemProperty -Path $sel -Name 'UIBranch'      -Type String -Value $BranchName   -Force | Out-Null

New-ItemProperty -Path $app -Name 'BranchName'        -Type String -Value $BranchName -Force | Out-Null
New-ItemProperty -Path $app -Name 'Ring'              -Type String -Value $Ring       -Force | Out-Null
New-ItemProperty -Path $app -Name 'ContentType'       -Type String -Value 'Mainline'  -Force | Out-Null
New-ItemProperty -Path $app -Name 'EnablePreviewBuilds' -Type DWord -Value 1 -Force   | Out-Null

Write-Host "✅ Windows Insider channel preference recorded."
Write-Host "ℹ️ Opening Settings → Windows Insider Program so you can link your Microsoft account (required once)."
Start-Process "ms-settings:windowsinsider"

# Telemetry for Insider builds
try {
  New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force | Out-Null
  New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Type DWord -Value 3 -Force | Out-Null
} catch { Write-Warning "Could not set AllowTelemetry=3 (Optional). Insider might not offer builds until set." }

# 2) OFFICE INSIDER — BetaChannel
Write-Host "🧩 Office: switching to BetaChannel (Insider Fast)"
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate'
New-Item -Path $pol -Force | Out-Null
New-ItemProperty -Path $pol -Name 'updatebranch' -Type String -Value 'BetaChannel' -Force | Out-Null
New-ItemProperty -Path $pol -Name 'enabled'      -Type DWord  -Value 1            -Force | Out-Null
New-ItemProperty -Path $pol -Name 'updatesareenabled' -Type DWord -Value 1        -Force | Out-Null

$odt = "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
if (Test-Path $odt) {
  Write-Host "⏫ Asking Office Click-to-Run to update to BetaChannel..."
  Start-Process -FilePath $odt -ArgumentList "/update user" -Wait:$false
} else {
  Write-Host "ℹ️ OfficeC2RClient not found; run an Office app → Account → Update."
}

# 3) VS CODE INSIDERS
Write-Host "📝 Installing VS Code Insiders"
winget install Microsoft.VisualStudioCode.Insiders --silent --accept-source-agreements --accept-package-agreements

if ($MakeCodeCLIPointToInsiders) {
  Write-Host "🔗 Pointing 'code' CLI to 'code-insiders'"
  $bin = "$env:UserProfile\.local\bin"
  New-Item -ItemType Directory -Force -Path $bin | Out-Null
  $shim = Join-Path $bin "code.cmd"
  "@echo off
code-insiders %*" | Out-File -Encoding ascii $shim
  $uPath = [Environment]::GetEnvironmentVariable('Path','User')
  if ($uPath -notlike "*$bin*") {
    [Environment]::SetEnvironmentVariable('Path', $uPath + ";" + $bin, 'User')
  }
  Write-Host "✅ 'code' now launches VS Code Insiders (open a new terminal to pick up PATH)."
}

Write-Host "🔁 Finally, check Windows Update for Insider builds."
Start-Process "ms-settings:windowsupdate"
Write-Host "✅ Insider opt-in script finished."
