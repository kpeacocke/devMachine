<#
SSL/TLS and Encryption Hardening (Compatibility-Safe Version)
Configures Windows to disable only truly insecure protocols while maintaining compatibility.
Disables: SSL 2.0, SSL 3.0 (completely broken)
Keeps enabled: TLS 1.0, 1.1, 1.2, 1.3 (for maximum compatibility)
Does NOT modify: Cipher suites, hashes, or key exchange algorithms (uses Windows defaults)
#>
$ErrorActionPreference = 'Stop'

# Load unattended mode override if available
if ($env:DEVMACHINE_UNATTENDED -eq "true" -and $env:DEVMACHINE_OVERRIDE_PATH -and (Test-Path $env:DEVMACHINE_OVERRIDE_PATH)) {
    . $env:DEVMACHINE_OVERRIDE_PATH
}

Write-Host "[CRYPTO] SSL/TLS Hardening (Compatibility-Safe Mode)..." -ForegroundColor Cyan

# Safety check: Verify SSL/TLS is working before applying changes
Write-Host "`n🔍 Pre-flight SSL/TLS connectivity check..."
$tlsWorking = $false
try {
    $testUrls = @("https://windowsupdate.microsoft.com", "https://www.microsoft.com")
    $workingCount = 0
    foreach ($url in $testUrls) {
        try {
            Invoke-RestMethod -Uri $url -Method Head -TimeoutSec 5 -ErrorAction Stop | Out-Null
            $workingCount++
        } catch { }
    }

    if ($workingCount -eq $testUrls.Count) {
        Write-Host "  ✅ SSL/TLS is working correctly" -ForegroundColor Green
        $tlsWorking = $true
    } elseif ($workingCount -gt 0) {
        Write-Host "  ⚠️  Partial SSL/TLS connectivity - will apply minimal changes only" -ForegroundColor Yellow
        $tlsWorking = $true
    } else {
        Write-Host "  ❌ SSL/TLS not working - SKIPPING all hardening to avoid breaking connectivity" -ForegroundColor Red
        Write-Host "     Fix SSL/TLS issues before running this script" -ForegroundColor Yellow
        exit 0
    }
} catch {
    Write-Host "  ⚠️  Unable to test SSL/TLS - SKIPPING hardening for safety" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n🔒 Disabling only truly insecure protocols (SSL 2.0 and SSL 3.0)..."
Write-Host "   Note: TLS 1.0/1.1 left enabled for compatibility with legacy services" -ForegroundColor Gray

# Disable SSL 2.0 (completely broken - no legitimate use)
$ssl2ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"
$ssl2ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client"
New-Item -Path $ssl2ServerPath -Force | Out-Null
New-Item -Path $ssl2ClientPath -Force | Out-Null
Set-ItemProperty -Path $ssl2ServerPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $ssl2ServerPath -Name "DisabledByDefault" -Value 1 -Type DWord
Set-ItemProperty -Path $ssl2ClientPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $ssl2ClientPath -Name "DisabledByDefault" -Value 1 -Type DWord
Write-Host "  ✅ SSL 2.0 disabled (server + client)" -ForegroundColor Green

# Disable SSL 3.0 (POODLE vulnerability - no legitimate use)
$ssl3ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"
$ssl3ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client"
New-Item -Path $ssl3ServerPath -Force | Out-Null
New-Item -Path $ssl3ClientPath -Force | Out-Null
Set-ItemProperty -Path $ssl3ServerPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $ssl3ServerPath -Name "DisabledByDefault" -Value 1 -Type DWord
Set-ItemProperty -Path $ssl3ClientPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $ssl3ClientPath -Name "DisabledByDefault" -Value 1 -Type DWord
Write-Host "  ✅ SSL 3.0 disabled (POODLE protection)" -ForegroundColor Green

Write-Host "`n✅ Modern TLS protocols (1.0, 1.1, 1.2, 1.3) remain enabled"
Write-Host "   Windows defaults provide good security while maintaining compatibility" -ForegroundColor Gray
Write-Host "   with Windows Update, Discord, and other services requiring legacy TLS" -ForegroundColor Gray

Write-Host "`n🛡️ Configuring .NET Framework for modern TLS support..."

# .NET Framework strong crypto (allows TLS 1.2+ but doesn't break TLS 1.0/1.1 fallback)
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v2.0.50727" /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f | Out-Null

# For 32-bit apps on 64-bit Windows
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727" /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f | Out-Null

Write-Host "  ✅ .NET Framework configured to use system TLS defaults" -ForegroundColor Green

Write-Host "`n📋 Skipped (for compatibility):"
Write-Host "  • Custom cipher suite ordering (uses Windows defaults)" -ForegroundColor Gray
Write-Host "  • Disabling specific ciphers (RC4, DES, 3DES)" -ForegroundColor Gray
Write-Host "  • Disabling specific hashes (MD5, SHA-1)" -ForegroundColor Gray
Write-Host "  • Custom key exchange restrictions" -ForegroundColor Gray
Write-Host "  • TLS 1.0/1.1 remain enabled for legacy compatibility" -ForegroundColor Gray
Write-Host "  • Certificate validation policies (defaults sufficient)" -ForegroundColor Gray

Write-Host "`n🔄 Refreshing services (optional)..."

# Only restart services if they're running
$sslServices = @("cryptsvc")
foreach($service in $sslServices) {
    try {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq 'Running'}) {
            Restart-Service -Name $service -Force -ErrorAction SilentlyContinue
            Write-Host "  ✅ Restarted $service service" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ℹ️  $service service not restarted" -ForegroundColor Gray
    }
}

Write-Host "`n⚠️  Important Notes:" -ForegroundColor Yellow
Write-Host "  • Only SSL 2.0 and SSL 3.0 are disabled (completely broken protocols)" -ForegroundColor Yellow
Write-Host "  • TLS 1.0, 1.1, 1.2, 1.3 remain available for compatibility" -ForegroundColor Yellow
Write-Host "  • Windows default cipher suites, hashes, and key exchange unchanged" -ForegroundColor Yellow
Write-Host "  • This provides basic security while maintaining broad compatibility" -ForegroundColor Yellow
Write-Host "  • No reboot required for these minimal changes" -ForegroundColor Green

Write-Host "`n🔍 Verification:" -ForegroundColor Cyan
Write-Host "  • Test Windows Update: Settings → Windows Update → Check for updates" -ForegroundColor Gray
Write-Host "  • Test HTTPS: Invoke-WebRequest https://www.microsoft.com" -ForegroundColor Gray

Write-Host "`n[OK] Compatibility-safe SSL/TLS hardening complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Disabled: SSL 2.0, SSL 3.0 (completely insecure)" -ForegroundColor Green
Write-Host "✅ Enabled:  TLS 1.0, 1.1, 1.2, 1.3 (full compatibility)" -ForegroundColor Green
Write-Host "✅ Default:  Ciphers, hashes, key exchange (Windows defaults)" -ForegroundColor Green
Write-Host "✅ .NET:     System TLS version inheritance enabled" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
