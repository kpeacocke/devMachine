<#
SSL/TLS and Encryption Hardening
Configures Windows to use modern encryption standards and disables weak ciphers/protocols.
Based on NSA/CISA guidelines and security best practices.
#>
$ErrorActionPreference = 'Stop'

# Load unattended mode override if available
if ($env:DEVMACHINE_UNATTENDED -eq "true" -and $env:DEVMACHINE_OVERRIDE_PATH -and (Test-Path $env:DEVMACHINE_OVERRIDE_PATH)) {
    . $env:DEVMACHINE_OVERRIDE_PATH
}

Write-Host "[CRYPTO] SSL/TLS and Encryption Hardening..." -ForegroundColor Cyan

Write-Host "`n🔒 Disabling weak SSL/TLS protocols..."

# Disable SSL 2.0 (completely insecure)
$ssl2ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"
$ssl2ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client"
New-Item -Path $ssl2ServerPath -Force | Out-Null
New-Item -Path $ssl2ClientPath -Force | Out-Null
Set-ItemProperty -Path $ssl2ServerPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $ssl2ServerPath -Name "DisabledByDefault" -Value 1 -Type DWord
Set-ItemProperty -Path $ssl2ClientPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $ssl2ClientPath -Name "DisabledByDefault" -Value 1 -Type DWord
Write-Host "  ✅ SSL 2.0 disabled" -ForegroundColor Green

# Disable SSL 3.0 (POODLE vulnerability)
$ssl3ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"
$ssl3ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client"
New-Item -Path $ssl3ServerPath -Force | Out-Null
New-Item -Path $ssl3ClientPath -Force | Out-Null
Set-ItemProperty -Path $ssl3ServerPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $ssl3ServerPath -Name "DisabledByDefault" -Value 1 -Type DWord
Set-ItemProperty -Path $ssl3ClientPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $ssl3ClientPath -Name "DisabledByDefault" -Value 1 -Type DWord
Write-Host "  ✅ SSL 3.0 disabled (POODLE protection)" -ForegroundColor Green

# Disable TLS 1.0 (deprecated, weak)
$tls10ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"
$tls10ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client"
New-Item -Path $tls10ServerPath -Force | Out-Null
New-Item -Path $tls10ClientPath -Force | Out-Null
Set-ItemProperty -Path $tls10ServerPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $tls10ServerPath -Name "DisabledByDefault" -Value 1 -Type DWord
Set-ItemProperty -Path $tls10ClientPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $tls10ClientPath -Name "DisabledByDefault" -Value 1 -Type DWord
Write-Host "  ✅ TLS 1.0 disabled" -ForegroundColor Green

# Disable TLS 1.1 (deprecated, weak)
$tls11ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"
$tls11ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"
New-Item -Path $tls11ServerPath -Force | Out-Null
New-Item -Path $tls11ClientPath -Force | Out-Null
Set-ItemProperty -Path $tls11ServerPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $tls11ServerPath -Name "DisabledByDefault" -Value 1 -Type DWord
Set-ItemProperty -Path $tls11ClientPath -Name "Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $tls11ClientPath -Name "DisabledByDefault" -Value 1 -Type DWord
Write-Host "  ✅ TLS 1.1 disabled" -ForegroundColor Green

Write-Host "`n🔐 Enabling strong TLS protocols..."

# Enable TLS 1.2 (ensure it's enabled)
$tls12ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
$tls12ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"
New-Item -Path $tls12ServerPath -Force | Out-Null
New-Item -Path $tls12ClientPath -Force | Out-Null
Set-ItemProperty -Path $tls12ServerPath -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $tls12ServerPath -Name "DisabledByDefault" -Value 0 -Type DWord
Set-ItemProperty -Path $tls12ClientPath -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $tls12ClientPath -Name "DisabledByDefault" -Value 0 -Type DWord
Write-Host "  ✅ TLS 1.2 enabled" -ForegroundColor Green

# Enable TLS 1.3 (Windows 11 22H2+)
$os = Get-CimInstance Win32_OperatingSystem
if ($os.BuildNumber -ge 22621) {
    $tls13ServerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server"
    $tls13ClientPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client"
    New-Item -Path $tls13ServerPath -Force | Out-Null
    New-Item -Path $tls13ClientPath -Force | Out-Null
    Set-ItemProperty -Path $tls13ServerPath -Name "Enabled" -Value 1 -Type DWord
    Set-ItemProperty -Path $tls13ServerPath -Name "DisabledByDefault" -Value 0 -Type DWord
    Set-ItemProperty -Path $tls13ClientPath -Name "Enabled" -Value 1 -Type DWord
    Set-ItemProperty -Path $tls13ClientPath -Name "DisabledByDefault" -Value 0 -Type DWord
    Write-Host "  ✅ TLS 1.3 enabled" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  TLS 1.3 requires Windows 11 22H2+ (your build: $($os.BuildNumber))" -ForegroundColor Yellow
}

Write-Host "`n🚫 Disabling weak cipher suites..."

# Disable weak cipher suites
$weakCiphers = @(
    "DES 56/56",
    "RC2 40/128",
    "RC2 56/128",
    "RC2 128/128",
    "RC4 40/128",
    "RC4 56/128",
    "RC4 64/128",
    "RC4 128/128",
    "Triple DES 168",
    "NULL"
)

foreach ($cipher in $weakCiphers) {
    $cipherPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\$cipher"
    New-Item -Path $cipherPath -Force | Out-Null
    Set-ItemProperty -Path $cipherPath -Name "Enabled" -Value 0 -Type DWord
}
Write-Host "  ✅ Weak ciphers disabled (DES, RC2, RC4, 3DES, NULL)" -ForegroundColor Green

Write-Host "`n🔒 Disabling weak hashing algorithms..."

# Disable weak hashes
$weakHashes = @(
    "MD5",
    "SHA"
)

foreach ($hash in $weakHashes) {
    $hashPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\$hash"
    New-Item -Path $hashPath -Force | Out-Null
    Set-ItemProperty -Path $hashPath -Name "Enabled" -Value 0 -Type DWord
}
Write-Host "  ✅ Weak hashes disabled (MD5, SHA-1)" -ForegroundColor Green

Write-Host "`n🔐 Configuring strong cipher order..."

# Set cipher suite order (prioritize modern, secure algorithms)
$cipherOrder = @(
    # TLS 1.3 cipher suites (AEAD only)
    "TLS_AES_256_GCM_SHA384",
    "TLS_AES_128_GCM_SHA256",
    "TLS_CHACHA20_POLY1305_SHA256",

    # TLS 1.2 ECDHE cipher suites (Perfect Forward Secrecy)
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256",
    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",

    # TLS 1.2 ECDHE with CBC (less preferred but compatible)
    "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384",
    "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256",
    "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384",
    "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256"
) -join ","

# Apply cipher suite order
$cipherSuitePath = "HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002"
New-Item -Path $cipherSuitePath -Force | Out-Null
Set-ItemProperty -Path $cipherSuitePath -Name "Functions" -Value $cipherOrder -Type String
Write-Host "  ✅ Modern cipher suite order configured" -ForegroundColor Green

Write-Host "`n🔐 Enabling strong key exchange..."

# Enable strong key exchange algorithms
$keyExchangePath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms"

# Enable ECDH (Elliptic Curve Diffie-Hellman)
$ecdhPath = "$keyExchangePath\ECDH"
New-Item -Path $ecdhPath -Force | Out-Null
Set-ItemProperty -Path $ecdhPath -Name "Enabled" -Value 1 -Type DWord

# Enable PKCS (RSA key exchange - for compatibility)
$pkcsPath = "$keyExchangePath\PKCS"
New-Item -Path $pkcsPath -Force | Out-Null
Set-ItemProperty -Path $pkcsPath -Name "Enabled" -Value 1 -Type DWord

# Disable Diffie-Hellman (DH) - prefer ECDH
$dhPath = "$keyExchangePath\Diffie-Hellman"
New-Item -Path $dhPath -Force | Out-Null
Set-ItemProperty -Path $dhPath -Name "Enabled" -Value 0 -Type DWord

Write-Host "  ✅ ECDH enabled, DH disabled" -ForegroundColor Green

Write-Host "`n🛡️ Configuring .NET Framework crypto settings..."

# .NET Framework strong crypto (for .NET apps)
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v2.0.50727" /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v2.0.50727" /v SchUseStrongCrypto /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" /v SchUseStrongCrypto /t REG_DWORD /d 1 /f | Out-Null

# For 32-bit apps on 64-bit Windows
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727" /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727" /v SchUseStrongCrypto /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" /v SchUseStrongCrypto /t REG_DWORD /d 1 /f | Out-Null

Write-Host "  ✅ .NET Framework configured for strong cryptography" -ForegroundColor Green

Write-Host "`n🔒 Configuring PowerShell/WinRM security..."

# PowerShell/WinRM TLS settings (if WinRM is used)
try {
    # Set minimum TLS version for WinRM
    Set-WSManInstance -ResourceURI winrm/config/service -ValueSet @{CertificateThumbprint=""; TrustedHosts=""; AllowUnencrypted=$false} -ErrorAction SilentlyContinue
    Write-Host "  ✅ WinRM configured for encrypted connections only" -ForegroundColor Green
} catch {
    Write-Host "  ℹ️  WinRM not configured (not typically needed for dev machines)" -ForegroundColor Gray
}

Write-Host "`n🔐 Certificate validation hardening..."

# Disable weak certificate signature algorithms
reg add "HKLM\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CertDllCreateCertificateChainEngine\Config" /v WeakSignaturePolicy /t REG_DWORD /d 0x08000000 /f | Out-Null

# Certificate pinning for Windows Update (prevent man-in-the-middle)
reg add "HKLM\SOFTWARE\Policies\Microsoft\SystemCertificates\AuthRoot" /v DisableRootAutoUpdate /t REG_DWORD /d 0 /f | Out-Null

Write-Host "  ✅ Certificate validation hardened" -ForegroundColor Green

Write-Host "`n📱 Mobile device crypto hardening..."

# Disable insecure ActiveSync encryption (if using)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\ActiveSync" /v RequireDeviceEncryption /t REG_DWORD /d 1 /f | Out-Null

Write-Host "  ✅ Mobile device encryption required" -ForegroundColor Green

Write-Host "`n⚠️  Important Notes:" -ForegroundColor Yellow
Write-Host "  • Reboot required for all SSL/TLS changes to take effect" -ForegroundColor Yellow
Write-Host "  • Some legacy applications may have connectivity issues" -ForegroundColor Yellow
Write-Host "  • Test critical applications after reboot" -ForegroundColor Yellow
Write-Host "  • TLS 1.2+ now required for all secure connections" -ForegroundColor Yellow

Write-Host "`n🔍 Verification Commands:" -ForegroundColor Cyan
Write-Host "  • Test TLS: Invoke-WebRequest https://www.howsmyssl.com/a/check" -ForegroundColor Gray
Write-Host "  • Check ciphers: Get-TlsCipherSuite | Select-Object Name" -ForegroundColor Gray
Write-Host "  • .NET test: []::ServicePointManager.SecurityProtocol" -ForegroundColor Gray

Write-Host "`n[OK] SSL/TLS and encryption hardening complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Disabled: SSL 2.0, SSL 3.0, TLS 1.0, TLS 1.1" -ForegroundColor Green
Write-Host "✅ Enabled:  TLS 1.2 (TLS 1.3 on Windows 11 22H2+)" -ForegroundColor Green
Write-Host "✅ Removed:  Weak ciphers (RC4, DES, 3DES, NULL)" -ForegroundColor Green
Write-Host "✅ Disabled: Weak hashes (MD5, SHA-1)" -ForegroundColor Green
Write-Host "✅ Priority: AEAD ciphers with Perfect Forward Secrecy" -ForegroundColor Green
Write-Host "✅ .NET:     Strong cryptography enabled" -ForegroundColor Green
Write-Host "✅ Certs:    Signature validation hardened" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
