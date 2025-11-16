<#
DNS Security & Advanced Firewall Configuration
Configures DNS over HTTPS (DoH) and creates firewall rules for development tools.
#>
$ErrorActionPreference = 'Continue'  # Changed to Continue to handle existing configurations gracefully

# Helper function to check if a firewall rule already exists
function Test-FirewallRuleExists {
    param(
        [string]$DisplayName,
        [string]$Direction = "Inbound",
        [string]$Protocol = "TCP",
        [string[]]$LocalPort = @(),
        [string]$Program = $null
    )

    try {
        $existingRules = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue
        if ($existingRules) {
            foreach ($rule in $existingRules) {
                $portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue
                $appFilter = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue

                # Check if this rule matches our criteria
                $directionMatch = $rule.Direction -eq $Direction
                $protocolMatch = $portFilter.Protocol -eq $Protocol
                $portMatch = ($LocalPort.Count -eq 0) -or ($portFilter.LocalPort | ForEach-Object { $LocalPort -contains $_ } | Where-Object { $_ -eq $true }).Count -gt 0
                $programMatch = ([string]::IsNullOrEmpty($Program)) -or ($appFilter.Program -eq $Program)

                if ($directionMatch -and $protocolMatch -and $portMatch -and $programMatch) {
                    return $true
                }
            }
        }
        return $false
    } catch {
        return $false
    }
}

# Helper function to create firewall rule only if it doesn't exist
function New-FirewallRuleIfNotExists {
    param(
        [string]$DisplayName,
        [string]$Direction = "Inbound",
        [string]$Action = "Allow",
        [string]$Protocol = "TCP",
        [string[]]$LocalPort = @(),
        [string]$Program = $null,
        [string]$RemoteAddress = $null
    )

    $exists = Test-FirewallRuleExists -DisplayName $DisplayName -Direction $Direction -Protocol $Protocol -LocalPort $LocalPort -Program $Program

    if ($exists) {
        Write-Host "    → Rule '$DisplayName' already exists, skipping" -ForegroundColor Gray
        return $false
    } else {
        try {
            $params = @{
                DisplayName = $DisplayName
                Direction = $Direction
                Action = $Action
                Protocol = $Protocol
                ErrorAction = 'Stop'
            }

            if ($LocalPort.Count -gt 0) { $params.LocalPort = $LocalPort }
            if ($Program) { $params.Program = $Program }
            if ($RemoteAddress) { $params.RemoteAddress = $RemoteAddress }

            New-NetFirewallRule @params | Out-Null
            Write-Host "    ✅ Created rule: $DisplayName" -ForegroundColor Green
            return $true
        } catch {
            Write-Warning "    Failed to create rule '$DisplayName': $_"
            return $false
        }
    }
}

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

    # Clean up ALL existing DoH configurations to prevent conflicts
    Write-Host "  Removing all existing DoH configurations..." -ForegroundColor Cyan
    $existingDohServers | ForEach-Object {
        Remove-DnsClientDohServerAddress -ServerAddress $_.ServerAddress -ErrorAction SilentlyContinue
    }
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
            # Set DNS servers for all active adapters
            Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
                try {
                    # First reset any existing DNS configuration to ensure clean state
                    Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
                    # Then set the new DNS servers
                    Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ("1.1.1.1","1.0.0.1")
                } catch {
                    Write-Host "    → Interface $($_.Name) ($($_.ifIndex)): $_" -ForegroundColor Yellow
                }
            }
            # Check if DoH servers already exist, remove if needed
            $existingDoh = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddress -in @('1.1.1.1', '1.0.0.1') }
            if ($existingDoh) {
                Write-Host "  Removing existing Cloudflare DoH configuration..." -ForegroundColor Yellow
                $existingDoh | Remove-DnsClientDohServerAddress -ErrorAction SilentlyContinue
            }
            # Enable DoH for Cloudflare with UDP fallback for compatibility
            Add-DnsClientDohServerAddress -ServerAddress '1.1.1.1' -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $true -AutoUpgrade $false
            Add-DnsClientDohServerAddress -ServerAddress '1.0.0.1' -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $true -AutoUpgrade $false
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
                try {
                    # First reset any existing DNS configuration to ensure clean state
                    Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
                    # Then set the new DNS servers
                    Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ("8.8.8.8","8.8.4.4")
                } catch {
                    Write-Host "    → Interface $($_.Name) ($($_.ifIndex)): $_" -ForegroundColor Yellow
                }
            }
            # Check if DoH servers already exist, remove if needed
            $existingDoh = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddress -in @('8.8.8.8', '8.8.4.4') }
            if ($existingDoh) {
                Write-Host "  Removing existing Google DoH configuration..." -ForegroundColor Yellow
                $existingDoh | Remove-DnsClientDohServerAddress -ErrorAction SilentlyContinue
            }
            Add-DnsClientDohServerAddress -ServerAddress '8.8.8.8' -DohTemplate 'https://dns.google/dns-query' -AllowFallbackToUdp $true -AutoUpgrade $false
            Add-DnsClientDohServerAddress -ServerAddress '8.8.4.4' -DohTemplate 'https://dns.google/dns-query' -AllowFallbackToUdp $true -AutoUpgrade $false
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
                try {
                    # First reset any existing DNS configuration to ensure clean state
                    Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
                    # Then set the new DNS servers
                    Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ("9.9.9.9","149.112.112.112")
                } catch {
                    Write-Host "    → Interface $($_.Name) ($($_.ifIndex)): $_" -ForegroundColor Yellow
                }
            }
            # Check if DoH servers already exist, remove if needed
            $existingDoh = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddress -in @('9.9.9.9', '149.112.112.112') }
            if ($existingDoh) {
                Write-Host "  Removing existing Quad9 DoH configuration..." -ForegroundColor Yellow
                $existingDoh | Remove-DnsClientDohServerAddress -ErrorAction SilentlyContinue
            }
            Add-DnsClientDohServerAddress -ServerAddress '9.9.9.9' -DohTemplate 'https://dns.quad9.net/dns-query' -AllowFallbackToUdp $true -AutoUpgrade $false
            Add-DnsClientDohServerAddress -ServerAddress '149.112.112.112' -DohTemplate 'https://dns.quad9.net/dns-query' -AllowFallbackToUdp $true -AutoUpgrade $false
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
$dockerRulesCreated = 0
$dockerRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Docker Desktop - WSL 2" -LocalPort @("2375", "2376"))
$dockerRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Docker Desktop - Kubernetes" -LocalPort @("6443"))
if ($dockerRulesCreated -gt 0) {
    Write-Host "  ✅ Docker firewall rules created ($dockerRulesCreated new)" -ForegroundColor Green
} else {
    Write-Host "  → All Docker firewall rules already exist" -ForegroundColor Yellow
}

# Node.js development servers (common ports)
Write-Host "  Creating firewall rules for Node.js dev servers..."
$nodeRulesCreated = 0
$nodeRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Node.js Dev - Vite/React" -LocalPort @("3000", "3001", "5173"))
$nodeRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Node.js Dev - Next.js" -LocalPort @("3000"))
$nodeRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Node.js Dev - Express/API" -LocalPort @("8000", "8080", "4000"))
if ($nodeRulesCreated -gt 0) {
    Write-Host "  ✅ Node.js firewall rules created ($nodeRulesCreated new)" -ForegroundColor Green
} else {
    Write-Host "  → All Node.js firewall rules already exist" -ForegroundColor Yellow
}

# Python development servers
Write-Host "  Creating firewall rules for Python dev servers..."
$pythonRulesCreated = 0
$pythonRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Python Dev - Flask/FastAPI" -LocalPort @("5000", "8000"))
$pythonRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Python Dev - Django" -LocalPort @("8000", "8080"))
if ($pythonRulesCreated -gt 0) {
    Write-Host "  ✅ Python firewall rules created ($pythonRulesCreated new)" -ForegroundColor Green
} else {
    Write-Host "  → All Python firewall rules already exist" -ForegroundColor Yellow
}

# Databases (local development)
Write-Host "  Creating firewall rules for databases..."
$dbRulesCreated = 0
$dbRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Database - PostgreSQL" -LocalPort @("5432"))
$dbRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Database - MySQL/MariaDB" -LocalPort @("3306"))
$dbRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Database - MongoDB" -LocalPort @("27017"))
$dbRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Database - Redis" -LocalPort @("6379"))
$dbRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Database - SQL Server" -LocalPort @("1433"))
if ($dbRulesCreated -gt 0) {
    Write-Host "  ✅ Database firewall rules created ($dbRulesCreated new)" -ForegroundColor Green
} else {
    Write-Host "  → All Database firewall rules already exist" -ForegroundColor Yellow
}

# Kubernetes (if enabled in Docker Desktop)
Write-Host "  Creating firewall rules for Kubernetes..."
$k8sRulesCreated = 0
$k8sRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Kubernetes - API Server" -LocalPort @("6443"))
$k8sRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Kubernetes - Kubelet" -LocalPort @("10250", "10255"))
if ($k8sRulesCreated -gt 0) {
    Write-Host "  ✅ Kubernetes firewall rules created ($k8sRulesCreated new)" -ForegroundColor Green
} else {
    Write-Host "  → All Kubernetes firewall rules already exist" -ForegroundColor Yellow
}

# Webpack Dev Server / Hot Reload
Write-Host "  Creating firewall rules for webpack dev server..."
$webpackRulesCreated = 0
$webpackRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Webpack Dev Server - Hot Reload" -LocalPort @("8080", "8081"))
$webpackRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "Webpack - WebSocket (HMR)" -LocalPort @("24678"))
if ($webpackRulesCreated -gt 0) {
    Write-Host "  ✅ Webpack firewall rules created ($webpackRulesCreated new)" -ForegroundColor Green
} else {
    Write-Host "  → All Webpack firewall rules already exist" -ForegroundColor Yellow
}

# WSL 2 networking (localhost forwarding)
Write-Host "  Creating firewall rules for WSL 2..."
$wslRulesCreated = 0
$wslRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "WSL 2 - Localhost Forwarding" -LocalPort @("1-65535") -RemoteAddress "LocalSubnet")
if ($wslRulesCreated -gt 0) {
    Write-Host "  ✅ WSL 2 firewall rules created ($wslRulesCreated new)" -ForegroundColor Green
} else {
    Write-Host "  → All WSL 2 firewall rules already exist" -ForegroundColor Yellow
}

# 1Password (to prevent connectivity issues after hardening)
Write-Host "  Creating firewall rules for 1Password..."

# Find 1Password installation
$onePasswordPaths = @(
    "${env:ProgramFiles}\1Password\1Password.exe",
    "${env:ProgramFiles(x86)}\1Password\1Password.exe",
    "${env:LOCALAPPDATA}\1Password\1Password.exe"
)

$onePasswordExe = $onePasswordPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($onePasswordExe) {
    $onePasswordRulesCreated = 0
    $onePasswordRulesCreated += [int](New-FirewallRuleIfNotExists -DisplayName "1Password - All Outbound" -Direction "Outbound" -Program $onePasswordExe)
    if ($onePasswordRulesCreated -gt 0) {
        Write-Host "  ✅ 1Password firewall rules created ($onePasswordRulesCreated new)" -ForegroundColor Green
    } else {
        Write-Host "  → All 1Password firewall rules already exist" -ForegroundColor Yellow
    }
} else {
    Write-Host "  → 1Password not installed, skipping firewall rules" -ForegroundColor Yellow
}

Write-Host "[NETWORK] Additional network security settings..."

# Enable Windows Firewall for all profiles (redundant check - already done in 01-early-hardening.ps1)
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Note: LLMNR and NetBIOS are already disabled in 01-early-hardening.ps1

# Enable firewall notifications (helpful during development)
Set-NetFirewallProfile -Profile Domain,Public,Private -NotifyOnListen True

# Show smart summary of firewall rules
function Show-FirewallRulesSummary {
    Write-Host "`n[FIREWALL SUMMARY] Active development firewall rules:" -ForegroundColor Cyan

    $devRulePatterns = @(
        "Docker Desktop*",
        "Node.js Dev*",
        "Python Dev*",
        "Database*",
        "Kubernetes*",
        "Webpack*",
        "WSL 2*",
        "1Password*"
    )

    $foundRules = @()
    foreach ($pattern in $devRulePatterns) {
        $rules = Get-NetFirewallRule -DisplayName $pattern -ErrorAction SilentlyContinue
        if ($rules) {
            foreach ($rule in $rules) {
                $portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue
                $ports = if ($portFilter.LocalPort -and $portFilter.LocalPort -ne "Any") {
                    " (Ports: $($portFilter.LocalPort -join ', '))"
                } else {
                    ""
                }
                $foundRules += "  ✅ $($rule.DisplayName)$ports"
            }
        }
    }

    if ($foundRules.Count -gt 0) {
        $foundRules | ForEach-Object { Write-Host $_ -ForegroundColor Green }
        Write-Host "  📊 Total development firewall rules: $($foundRules.Count)" -ForegroundColor Yellow
    } else {
        Write-Host "  → No development firewall rules found" -ForegroundColor Yellow
    }
}

Show-FirewallRulesSummary

Write-Host "`n[OK] DNS and firewall configuration complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ DNS over HTTPS:    Configured with smart fallback" -ForegroundColor Green
Write-Host "✅ Firewall Rules:    Smart duplicate detection enabled" -ForegroundColor Green
Write-Host "✅ Development Ports: All major frameworks supported" -ForegroundColor Green
Write-Host "✅ Security:          LLMNR/NetBIOS disabled, logging enabled" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "💡 Firewall logs: %SystemRoot%\System32\LogFiles\Firewall\pfirewall.log" -ForegroundColor Yellow
Write-Host "💡 Rules are idempotent - safe to run multiple times" -ForegroundColor Yellow
