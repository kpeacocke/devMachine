<#
Revert to stable channels:
- Windows: leave Insider rings (set Release Preview-ish)
- Office: set Current channel
- VS Code: restore 'code' to stable (or uninstall Insiders manually)
#>

$ErrorActionPreference = 'Stop'

Write-Host "🪟 Windows: reverting Insider settings to Release Preview (closest to stable)."
$sel = 'HKLM:\SOFTWARE\Microsoft\WindowsSelfHost\UI\Selection'
$app = 'HKLM:\SOFTWARE\Microsoft\WindowsSelfHost\Applicability'
New-Item -Path $sel -Force | Out-Null
New-Item -Path $app -Force | Out-Null
New-ItemProperty -Path $sel -Name 'UIContentType' -Type String -Value 'Mainline' -Force | Out-Null
New-ItemProperty -Path $sel -Name 'UIRing'        -Type String -Value 'External' -Force | Out-Null
New-ItemProperty -Path $sel -Name 'UIBranch'      -Type String -Value 'ReleasePreview' -Force | Out-Null
New-ItemProperty -Path $app -Name 'BranchName'    -Type String -Value 'ReleasePreview' -Force | Out-Null
New-ItemProperty -Path $app -Name 'Ring'          -Type String -Value 'External' -Force | Out-Null

Write-Host "🧩 Office: switching to Current channel."
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate'
New-Item -Path $pol -Force | Out-Null
New-ItemProperty -Path $pol -Name 'updatebranch' -Type String -Value 'Current' -Force | Out-Null

Write-Host "📝 VS Code: restoring 'code' to stable (if we created a shim)."
$bin = "$env:UserProfile\.local\bin"
$shim = Join-Path $bin "code.cmd"
if (Test-Path $shim) { Remove-Item $shim -Force }

Write-Host "ℹ️ Optionally uninstall Insiders:"
Write-Host "    winget uninstall Microsoft.VisualStudioCode.Insiders"
Write-Host "✅ Revert complete."
