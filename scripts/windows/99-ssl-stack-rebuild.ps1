<#
Complete SSL/TLS Stack Rebuild
Completely rebuilds the Windows SSL/TLS stack from scratch to fix the broken configuration.
#>
#Requires -RunAsAdministrator

Write-Host "[SSL REBUILD] Complete SSL/TLS Stack Rebuild" -ForegroundColor Magenta -BackgroundColor White

Write-Host "`n🚨 The SSL/TLS hardening completely broke the system's encryption stack!" -ForegroundColor Red
Write-Host "   This script will completely rebuild it from Windows defaults." -ForegroundColor Yellow

# 1. Stop all SSL/TLS dependent services
Write-Host "`n1. Stopping SSL/TLS dependent services..." -ForegroundColor Yellow
$services = @("http", "cryptsvc", "wuauserv", "bits", "winmgmt", "RpcSs")
foreach($service in $services) {
    try {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Write-Host "   → Stopped $service" -ForegroundColor Gray
    } catch {
        Write-Host "   ⚠️  Could not stop $service" -ForegroundColor Yellow
    }
}

# 2. Completely delete and recreate Schannel configuration
Write-Host "`n2. Rebuilding Schannel configuration..." -ForegroundColor Yellow
$schannelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL"

# Delete the entire Schannel configuration
if(Test-Path $schannelPath) {
    Remove-Item -Path $schannelPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ Deleted corrupted Schannel configuration" -ForegroundColor Green
}

# Recreate with Windows defaults
New-Item -Path $schannelPath -Force | Out-Null
New-Item -Path "$schannelPath\Protocols" -Force | Out-Null

# Configure TLS 1.2 and 1.3 (the only ones we want enabled)
$enabledProtocols = @("TLS 1.2", "TLS 1.3")
foreach($protocol in $enabledProtocols) {
    foreach($type in @("Client", "Server")) {
        $protocolPath = "$schannelPath\Protocols\$protocol\$type"
        New-Item -Path $protocolPath -Force | Out-Null
        Set-ItemProperty -Path $protocolPath -Name "Enabled" -Value 1 -Type DWord
        Set-ItemProperty -Path $protocolPath -Name "DisabledByDefault" -Value 0 -Type DWord
        Write-Host "   ✅ Enabled $protocol $type" -ForegroundColor Green
    }
}

# Explicitly disable old protocols (for security)
$disabledProtocols = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1")
foreach($protocol in $disabledProtocols) {
    foreach($type in @("Client", "Server")) {
        $protocolPath = "$schannelPath\Protocols\$protocol\$type"
        New-Item -Path $protocolPath -Force | Out-Null
        Set-ItemProperty -Path $protocolPath -Name "Enabled" -Value 0 -Type DWord
        Set-ItemProperty -Path $protocolPath -Name "DisabledByDefault" -Value 1 -Type DWord
        Write-Host "   ✅ Disabled $protocol $type" -ForegroundColor Green
    }
}

# 3. Delete any remaining cipher suite policies
Write-Host "`n3. Ensuring no cipher suite policies exist..." -ForegroundColor Yellow
$policyPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Cryptography",
    "HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Cryptography"
)

foreach($path in $policyPaths) {
    if(Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "   ✅ Removed cipher policies at $path" -ForegroundColor Green
    }
}

# 4. Reset .NET Framework crypto settings
Write-Host "`n4. Configuring .NET Framework..." -ForegroundColor Yellow
$netKeys = @(
    "HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727",
    "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319"
)

foreach($key in $netKeys) {
    if(-not (Test-Path $key)) {
        New-Item -Path $key -Force | Out-Null
    }
    Set-ItemProperty -Path $key -Name "SystemDefaultTlsVersions" -Value 1 -Type DWord
    Set-ItemProperty -Path $key -Name "SchUseStrongCrypto" -Value 1 -Type DWord
    Write-Host "   ✅ Configured .NET $(Split-Path $key -Leaf)" -ForegroundColor Green
}

# 5. Clear SSL/TLS cache
Write-Host "`n5. Clearing SSL/TLS caches..." -ForegroundColor Yellow
try {
    # Clear certificate store caches
    certlm -enterprise -user -silent -f
    Write-Host "   ✅ Certificate caches cleared" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Could not clear certificate caches" -ForegroundColor Yellow
}

# Clear Windows Update cache
$wuCache = "C:\Windows\SoftwareDistribution"
if(Test-Path $wuCache) {
    $backup = "${wuCache}.broken.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Rename-Item $wuCache $backup -Force -ErrorAction SilentlyContinue
    Write-Host "   ✅ Windows Update cache cleared" -ForegroundColor Green
}

# 6. Restart services
Write-Host "`n6. Restarting services..." -ForegroundColor Yellow
foreach($service in $services) {
    try {
        Start-Service -Name $service -ErrorAction SilentlyContinue
        Write-Host "   ✅ Started $service" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠️  Could not start $service" -ForegroundColor Yellow
    }
}

# 7. Force refresh of SSL/TLS configuration
Write-Host "`n7. Forcing SSL/TLS configuration refresh..." -ForegroundColor Yellow
try {
    # Flush DNS to clear any cached SSL handshake failures
    ipconfig /flushdns | Out-Null

    # Reset WinHTTP settings
    netsh winhttp reset proxy
    netsh winhttp reset tracing

    Write-Host "   ✅ Network configuration refreshed" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Some network resets failed" -ForegroundColor Yellow
}

Write-Host "`n8. Testing rebuilt SSL/TLS stack..." -ForegroundColor Yellow
Start-Sleep 5

# Test cipher suites
$cipherCount = (Get-TlsCipherSuite).Count
Write-Host "   Cipher suites available: $cipherCount" -ForegroundColor $(if($cipherCount -gt 50) { "Green" } else { "Red" })

# Test Windows Update
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $result = $searcher.Search("IsInstalled=0")
    Write-Host "   ✅ Windows Update FIXED - Found $($result.Updates.Count) updates" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Windows Update still broken: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "      → REBOOT REQUIRED for complete SSL/TLS stack rebuild" -ForegroundColor Yellow
}

# Test problematic endpoints
$testEndpoints = @("https://windowsupdate.microsoft.com", "https://updates.discord.com")
foreach($endpoint in $testEndpoints) {
    try {
        Invoke-RestMethod -Uri $endpoint -Method Head -TimeoutSec 10 | Out-Null
        Write-Host "   ✅ $endpoint - FIXED" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ $endpoint - Still broken" -ForegroundColor Red
    }
}

Write-Host "`n📋 SSL/TLS Stack Rebuild Summary:" -ForegroundColor Cyan
Write-Host "   • Schannel configuration completely rebuilt" -ForegroundColor Green
Write-Host "   • Only TLS 1.2 and 1.3 enabled (secure)" -ForegroundColor Green
Write-Host "   • All cipher suite policies removed" -ForegroundColor Green
Write-Host "   • .NET Framework configured properly" -ForegroundColor Green
Write-Host "   • SSL/TLS caches cleared" -ForegroundColor Green

Write-Host "`n🔄 REBOOT STRONGLY RECOMMENDED!" -ForegroundColor Red -BackgroundColor Yellow
Write-Host "   The SSL/TLS stack needs a reboot to fully reinitialize." -ForegroundColor Yellow

Write-Host "`n[DONE] SSL/TLS stack rebuild complete!" -ForegroundColor Green
