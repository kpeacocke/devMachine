<#
Early Security Hardening
Run BEFORE installing applications to ensure they install into a hardened environment.
Enables firewall, UAC, Defender, and disables risky legacy protocols.
Does NOT require reboot - that happens later with advanced hardening.
#>

$ErrorActionPreference = 'Stop'

Write-Host "[EARLY HARDENING] Applying basic security before app installation..." -ForegroundColor Cyan

# PowerShell 7 can inherit a PATH that is missing the standard Windows system
# directories. Restore them before invoking Windows command-line utilities.
$requiredWindowsPaths = @(
    (Join-Path $env:SystemRoot 'System32'),
    (Join-Path $env:SystemRoot),
    (Join-Path $env:SystemRoot 'System32\Wbem'),
    (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0')
)
$currentPathEntries = @($env:Path -split ';' | Where-Object { $_ })
foreach ($requiredPath in $requiredWindowsPaths) {
    if ((Test-Path $requiredPath) -and ($currentPathEntries -notcontains $requiredPath)) {
        $env:Path = "$requiredPath;$env:Path"
    }
}

Write-Host "   Windows system command paths verified" -ForegroundColor DarkGray

Write-Host "`n🔥 Firewall: Enable on all profiles (block inbound, allow outbound)"
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow
Write-Host "   ✅ Firewall enabled - all inbound connections blocked by default" -ForegroundColor Green

$regExe = Join-Path $env:SystemRoot 'System32\reg.exe'
if (-not (Test-Path $regExe)) {
    throw "Windows Registry utility not found at $regExe"
}

Write-Host "`n🛡️ UAC: Set to maximum security (always notify)"
& $regExe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 2 /f | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to set ConsentPromptBehaviorAdmin (reg.exe exit code $LASTEXITCODE)" }
& $regExe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to set PromptOnSecureDesktop (reg.exe exit code $LASTEXITCODE)" }
Write-Host "   ✅ UAC set to always notify on secure desktop" -ForegroundColor Green

Write-Host "`n🦠 Windows Defender: Enable core protections"
Set-MpPreference -PUAProtection Enabled -MAPSReporting Advanced -SubmitSamplesConsent SendSafeSamples -EnableNetworkProtection Enabled
Write-Host "   ✅ PUA protection, network protection, and cloud-delivered protection enabled" -ForegroundColor Green

Write-Host "`n🚫 Disable legacy/risky protocols"
# Disable SMBv1 (WannaCry vulnerability).
# Current Windows 11 builds can throw "Class not registered" when the DISM
# PowerShell cmdlets are invoked from PowerShell 7. Run this Windows servicing
# operation in the inbox Windows PowerShell 5.1 host.
Write-Host "   Disabling SMBv1..."
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path $windowsPowerShell)) {
    throw "Windows PowerShell 5.1 not found at $windowsPowerShell"
}

& $windowsPowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command `
    "Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop | Out-Null"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to disable SMBv1 using Windows PowerShell 5.1 (exit code $LASTEXITCODE)"
}

# Disable RDP (not needed on development machine, security risk if exposed)
Write-Host "   Disabling Remote Desktop..."
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 1 -ErrorAction SilentlyContinue
Disable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

# Disable LLMNR (Link-Local Multicast Name Resolution - spoofing risk)
Write-Host "   Disabling LLMNR..."
& $regExe add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to disable LLMNR (reg.exe exit code $LASTEXITCODE)" }

# Disable NetBIOS over TCP/IP (legacy protocol, spoofing risk)
Write-Host "   Disabling NetBIOS over TCP/IP..."
$regKey = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces"
Get-ChildItem $regKey -ErrorAction SilentlyContinue | ForEach-Object {
    Set-ItemProperty -Path "$regKey\$($_.PSChildName)" -Name NetbiosOptions -Value 2 -ErrorAction SilentlyContinue
}

Write-Host "   ✅ SMBv1, RDP, LLMNR, and NetBIOS disabled" -ForegroundColor Green

Write-Host "`n🔧 Enable developer-friendly settings"
# Enable NTFS long paths (needed for node_modules, etc.)
& $regExe add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to enable long paths (reg.exe exit code $LASTEXITCODE)" }
# Enable Developer Mode (sideloading, etc.)
& $regExe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense /t REG_DWORD /d 1 /f | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to enable Developer Mode (reg.exe exit code $LASTEXITCODE)" }
Write-Host "   ✅ NTFS long paths and Developer Mode enabled" -ForegroundColor Green

Write-Host "`n[OK] Early hardening complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Firewall:        Enabled (inbound blocked)" -ForegroundColor Green
Write-Host "✅ UAC:             Maximum security" -ForegroundColor Green
Write-Host "✅ Defender:        PUA + network protection enabled" -ForegroundColor Green
Write-Host "✅ Legacy protocols: SMBv1, RDP, LLMNR, NetBIOS disabled" -ForegroundColor Green
Write-Host "✅ Dev settings:    Long paths, Developer Mode enabled" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "`n💡 Apps will now install into a hardened environment" -ForegroundColor Yellow
Write-Host "💡 Advanced hardening (BitLocker, Credential Guard) happens later" -ForegroundColor Yellow
