<#
DNS Security & Advanced Firewall Configuration
Configures DNS over HTTPS (DoH) and creates firewall rules for development tools.
#>
$ErrorActionPreference = 'Continue'  # Changed to Continue to handle existing configurations gracefully

# Load unattended mode override if available
if ($env:DEVMACHINE_UNATTENDED -eq "true" -and $env:DEVMACHINE_OVERRIDE_PATH -and (Test-Path $env:DEVMACHINE_OVERRIDE_PATH)) {
    . $env:DEVMACHINE_OVERRIDE_PATH
}

Write-Host "[DNS] Configuring DNS over HTTPS (DoH)..."

# Check if DNS over HTTPS is already configured
$existingDohServers = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue
if ($existingDohServers) {
    Write-Host "  Existing DNS over HTTPS configuration found:" -ForegroundColor Yellow
    $existingDohServers | ForEach-Object {
        Write-Host "    $($_.ServerAddress) -> $($_.DohTemplate)" -ForegroundColor Gray
    }
    Write-Host "  Existing configuration will be replaced if you proceed." -ForegroundColor Yellow
}

# Prompt for DNS provider
Write-Host "Select DNS over HTTPS provider:"
Write-Host "  1. Cloudflare (1.1.1.1) - Privacy-focused, fastest"
Write-Host "  2. Google (8.8.8.8) - Reliable, widely used"
Write-Host "  3. Quad9 (9.9.9.9) - Security-focused, blocks malicious domains"
Write-Host "  4. Skip DNS configuration"

if ($env:DNS_CHOICE) {
    $dnsChoice = $env:DNS_CHOICE
} elseif ($env:UNATTENDED_MODE) {
    $dnsChoice = '1'  # Default to Cloudflare
} else {
    $dnsChoice = Read-Host "Choice (1-4) [Default: 1]"
}
if ([string]::IsNullOrWhiteSpace($dnsChoice)) { $dnsChoice = '1' }

switch ($dnsChoice) {
    '1' {
        Write-Host "  Configuring Cloudflare DNS over HTTPS..."
        try {
            # Set DNS servers
            Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
                Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ("1.1.1.1","1.0.0.1")
            }
            # Check if DoH servers already exist, remove if needed
            $existingDoh = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddress -in @('1.1.1.1', '1.0.0.1') }
            if ($existingDoh) {
                Write-Host "  Removing existing Cloudflare DoH configuration..." -ForegroundColor Yellow
                $existingDoh | Remove-DnsClientDohServerAddress -ErrorAction SilentlyContinue
            }
            # Enable DoH for Cloudflare
            Add-DnsClientDohServerAddress -ServerAddress '1.1.1.1' -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true
            Add-DnsClientDohServerAddress -ServerAddress '1.0.0.1' -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true
            Write-Host "  ✅ Cloudflare DNS over HTTPS configured" -ForegroundColor Green
        } catch {
            Write-Warning "DNS configuration partially failed: $_"
            Write-Host "  → DNS servers may already be configured" -ForegroundColor Yellow
        }
    }
    '2' {
        Write-Host "  Configuring Google DNS over HTTPS..."
        try {
            Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
                Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ("8.8.8.8","8.8.4.4")
            }
            # Check if DoH servers already exist, remove if needed
            $existingDoh = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddress -in @('8.8.8.8', '8.8.4.4') }
            if ($existingDoh) {
                Write-Host "  Removing existing Google DoH configuration..." -ForegroundColor Yellow
                $existingDoh | Remove-DnsClientDohServerAddress -ErrorAction SilentlyContinue
            }
            Add-DnsClientDohServerAddress -ServerAddress '8.8.8.8' -DohTemplate 'https://dns.google/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true
            Add-DnsClientDohServerAddress -ServerAddress '8.8.4.4' -DohTemplate 'https://dns.google/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true
            Write-Host "  ✅ Google DNS over HTTPS configured" -ForegroundColor Green
        } catch {
            Write-Warning "DNS configuration partially failed: $_"
            Write-Host "  → DNS servers may already be configured" -ForegroundColor Yellow
        }
    }
    '3' {
        Write-Host "  Configuring Quad9 DNS over HTTPS..."
        try {
            Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
                Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ("9.9.9.9","149.112.112.112")
            }
            # Check if DoH servers already exist, remove if needed
            $existingDoh = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddress -in @('9.9.9.9', '149.112.112.112') }
            if ($existingDoh) {
                Write-Host "  Removing existing Quad9 DoH configuration..." -ForegroundColor Yellow
                $existingDoh | Remove-DnsClientDohServerAddress -ErrorAction SilentlyContinue
            }
            Add-DnsClientDohServerAddress -ServerAddress '9.9.9.9' -DohTemplate 'https://dns.quad9.net/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true
            Add-DnsClientDohServerAddress -ServerAddress '149.112.112.112' -DohTemplate 'https://dns.quad9.net/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true
            Write-Host "  ✅ Quad9 DNS over HTTPS configured" -ForegroundColor Green
        } catch {
            Write-Warning "DNS configuration partially failed: $_"
            Write-Host "  → DNS servers may already be configured" -ForegroundColor Yellow
        }
    }
    default {
        Write-Host "  → Skipped DNS configuration" -ForegroundColor Yellow
    }
}

# Flush DNS cache
ipconfig /flushdns | Out-Null
Write-Host "  DNS cache flushed"

Write-Host "`n[FIREWALL] Configuring advanced firewall rules for dev tools..."

# Enable firewall logging (helpful for debugging blocked connections)
Set-NetFirewallProfile -All -LogBlocked True -LogMaxSizeKilobytes 4096 -LogFileName "%SystemRoot%\System32\LogFiles\Firewall\pfirewall.log"

# Docker Desktop
Write-Host "  Creating firewall rules for Docker Desktop..."
try {
    New-NetFirewallRule -DisplayName "Docker Desktop - WSL 2" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 2375,2376 -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Docker Desktop - Kubernetes" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 6443 -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  ✅ Docker firewall rules created" -ForegroundColor Green
} catch {
    Write-Warning "Docker firewall rules may already exist"
}

# Node.js development servers (common ports)
Write-Host "  Creating firewall rules for Node.js dev servers..."
try {
    New-NetFirewallRule -DisplayName "Node.js Dev - Vite/React" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3000,3001,5173 -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Node.js Dev - Next.js" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3000 -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Node.js Dev - Express/API" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8000,8080,4000 -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  ✅ Node.js firewall rules created" -ForegroundColor Green
} catch {
    Write-Warning "Node.js firewall rules may already exist"
}

# Python development servers
Write-Host "  Creating firewall rules for Python dev servers..."
try {
    New-NetFirewallRule -DisplayName "Python Dev - Flask/FastAPI" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5000,8000 -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Python Dev - Django" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8000,8080 -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  ✅ Python firewall rules created" -ForegroundColor Green
} catch {
    Write-Warning "Python firewall rules may already exist"
}

# Databases (local development)
Write-Host "  Creating firewall rules for databases..."
try {
    New-NetFirewallRule -DisplayName "Database - PostgreSQL" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5432 -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Database - MySQL/MariaDB" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3306 -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Database - MongoDB" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 27017 -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Database - Redis" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 6379 -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Database - SQL Server" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433 -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  ✅ Database firewall rules created" -ForegroundColor Green
} catch {
    Write-Warning "Database firewall rules may already exist"
}

# Kubernetes (if enabled in Docker Desktop)
Write-Host "  Creating firewall rules for Kubernetes..."
try {
    New-NetFirewallRule -DisplayName "Kubernetes - API Server" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 6443 -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Kubernetes - Kubelet" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 10250,10255 -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  ✅ Kubernetes firewall rules created" -ForegroundColor Green
} catch {
    Write-Warning "Kubernetes firewall rules may already exist"
}

# Webpack Dev Server / Hot Reload
Write-Host "  Creating firewall rules for webpack dev server..."
try {
    New-NetFirewallRule -DisplayName "Webpack Dev Server - Hot Reload" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8080,8081 -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Webpack - WebSocket (HMR)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 24678 -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  ✅ Webpack firewall rules created" -ForegroundColor Green
} catch {
    Write-Warning "Webpack firewall rules may already exist"
}

# WSL 2 networking (localhost forwarding)
Write-Host "  Creating firewall rules for WSL 2..."
try {
    New-NetFirewallRule -DisplayName "WSL 2 - Localhost Forwarding" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1-65535 -RemoteAddress LocalSubnet -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  ✅ WSL 2 firewall rules created" -ForegroundColor Green
} catch {
    Write-Warning "WSL 2 firewall rules may already exist"
}

Write-Host "[NETWORK] Additional network security settings..."

# Enable Windows Firewall for all profiles (redundant check - already done in 01-early-hardening.ps1)
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Note: LLMNR and NetBIOS are already disabled in 01-early-hardening.ps1

# Enable firewall notifications (helpful during development)
Set-NetFirewallProfile -Profile Domain,Public,Private -NotifyOnListen True

Write-Host "[OK] DNS and firewall configuration complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ DNS over HTTPS:    Configured" -ForegroundColor Green
Write-Host "✅ Firewall Rules:    Dev tools allowed" -ForegroundColor Green
Write-Host "✅ Docker:            Ports 2375, 2376, 6443" -ForegroundColor Green
Write-Host "✅ Node.js:           Ports 3000, 3001, 5173, 8080" -ForegroundColor Green
Write-Host "✅ Python:            Ports 5000, 8000" -ForegroundColor Green
Write-Host "✅ Databases:         PostgreSQL, MySQL, MongoDB, Redis, SQL Server" -ForegroundColor Green
Write-Host "✅ Kubernetes:        Ports 6443, 10250, 10255" -ForegroundColor Green
Write-Host "✅ WSL 2:             Localhost forwarding enabled" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "💡 Note: LLMNR and NetBIOS already disabled in early hardening phase" -ForegroundColor Yellow
Write-Host "💡 Firewall logs: %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log" -ForegroundColor Yellow
