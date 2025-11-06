<#
Windows Services Optimization
Disables unnecessary Windows services for improved performance and reduced attack surface.
#>
$ErrorActionPreference = 'Stop'

Write-Host "[SERVICES] Optimizing Windows services..."

# Service configuration: DisplayName, ServiceName, ShouldPrompt
$servicesToDisable = @(
    @{ Name = 'Spooler'; DisplayName = 'Print Spooler'; Prompt = $true; Reason = 'Not needed unless using printers (PrintNightmare vulnerability)' },
    @{ Name = 'Fax'; DisplayName = 'Fax Service'; Prompt = $false; Reason = 'Legacy service, rarely used' },
    @{ Name = 'WerSvc'; DisplayName = 'Windows Error Reporting'; Prompt = $false; Reason = 'Already disabled in privacy script' },
    @{ Name = 'DiagTrack'; DisplayName = 'Connected User Experiences and Telemetry'; Prompt = $false; Reason = 'Telemetry data collection' },
    @{ Name = 'RemoteRegistry'; DisplayName = 'Remote Registry'; Prompt = $false; Reason = 'Security risk if enabled' },
    @{ Name = 'RetailDemo'; DisplayName = 'Retail Demo Service'; Prompt = $false; Reason = 'Not needed on dev machines' },
    @{ Name = 'XblAuthManager'; DisplayName = 'Xbox Live Auth Manager'; Prompt = $true; Reason = 'Not needed unless using Xbox features' },
    @{ Name = 'XblGameSave'; DisplayName = 'Xbox Live Game Save'; Prompt = $true; Reason = 'Not needed unless using Xbox features' },
    @{ Name = 'XboxNetApiSvc'; DisplayName = 'Xbox Live Networking Service'; Prompt = $true; Reason = 'Not needed unless using Xbox features' },
    @{ Name = 'XboxGipSvc'; DisplayName = 'Xbox Accessory Management Service'; Prompt = $true; Reason = 'Not needed unless using Xbox controller' },
    @{ Name = 'WMPNetworkSvc'; DisplayName = 'Windows Media Player Network Sharing'; Prompt = $true; Reason = 'Not needed unless sharing media' },
    @{ Name = 'Browser'; DisplayName = 'Computer Browser'; Prompt = $false; Reason = 'Legacy network browsing, deprecated' },
    @{ Name = 'HomeGroupListener'; DisplayName = 'HomeGroup Listener'; Prompt = $false; Reason = 'HomeGroup removed in Windows 10 1803+' },
    @{ Name = 'HomeGroupProvider'; DisplayName = 'HomeGroup Provider'; Prompt = $false; Reason = 'HomeGroup removed in Windows 10 1803+' },
    @{ Name = 'MapsBroker'; DisplayName = 'Downloaded Maps Manager'; Prompt = $true; Reason = 'Not needed unless using Maps app' },
    @{ Name = 'PhoneSvc'; DisplayName = 'Phone Service'; Prompt = $true; Reason = 'Not needed unless linking phone' },
    @{ Name = 'dmwappushservice'; DisplayName = 'Device Management Wireless Application Protocol'; Prompt = $false; Reason = 'WAP Push telemetry' },
    @{ Name = 'lfsvc'; DisplayName = 'Geolocation Service'; Prompt = $true; Reason = 'Location tracking (already disabled in privacy script)' },
    @{ Name = 'TabletInputService'; DisplayName = 'Touch Keyboard and Handwriting Panel Service'; Prompt = $true; Reason = 'Not needed on non-touch devices' },
    @{ Name = 'WSearch'; DisplayName = 'Windows Search'; Prompt = $true; Reason = 'Can use Everything instead (indexing consumes resources)' },
    @{ Name = 'SysMain'; DisplayName = 'SysMain (Superfetch)'; Prompt = $true; Reason = 'May slow down SSDs (debated performance impact)' }
)

Write-Host "`nℹ️  This script will disable unnecessary Windows services to improve performance." -ForegroundColor Cyan
Write-Host "   Services will be set to 'Disabled' (not just stopped)." -ForegroundColor Cyan
Write-Host "   You will be prompted for services that may be needed in specific scenarios.`n" -ForegroundColor Cyan

$disabledCount = 0
$skippedCount = 0
$notFoundCount = 0

foreach ($service in $servicesToDisable) {
    # Check if service exists
    $svc = Get-Service -Name $service.Name -ErrorAction SilentlyContinue

    if (-not $svc) {
        Write-Host "  → $($service.DisplayName): Not found (may not exist on this Windows version)" -ForegroundColor Gray
        $notFoundCount++
        continue
    }

    # Check if already disabled
    $startType = (Get-Service -Name $service.Name).StartType
    if ($startType -eq 'Disabled') {
        Write-Host "  → $($service.DisplayName): Already disabled" -ForegroundColor Gray
        continue
    }

    # Prompt user if needed
    $shouldDisable = $true
    if ($service.Prompt) {
        Write-Host "`n  Disable '$($service.DisplayName)'?" -ForegroundColor Yellow
        Write-Host "    Reason: $($service.Reason)" -ForegroundColor Gray
        $response = Read-Host "    Disable? (Y/N) [Default: Y]"
        if ([string]::IsNullOrWhiteSpace($response)) { $response = 'Y' }
        if ($response -ne 'Y') {
            $shouldDisable = $false
            Write-Host "    → Kept enabled" -ForegroundColor Yellow
            $skippedCount++
        }
    }

    if ($shouldDisable) {
        try {
            # Stop service if running
            if ($svc.Status -eq 'Running') {
                Stop-Service -Name $service.Name -Force -ErrorAction Stop
            }

            # Disable service
            Set-Service -Name $service.Name -StartupType Disabled -ErrorAction Stop
            Write-Host "  ✅ $($service.DisplayName): Disabled" -ForegroundColor Green
            $disabledCount++
        } catch {
            Write-Warning "Failed to disable $($service.DisplayName): $_"
        }
    }
}

# Special: Windows Update can be set to Manual (not Disabled) for control
Write-Host "`n  Would you like to set Windows Update to Manual (recommended for dev machines)?"
Write-Host "    This prevents automatic restarts but allows manual updates." -ForegroundColor Gray
$wuResponse = Read-Host "    Set to Manual? (Y/N) [Default: Y]"
if ([string]::IsNullOrWhiteSpace($wuResponse)) { $wuResponse = 'Y' }

if ($wuResponse -eq 'Y') {
    try {
        Set-Service -Name 'wuauserv' -StartupType Manual -ErrorAction Stop
        Write-Host "  ✅ Windows Update: Set to Manual" -ForegroundColor Green
        $disabledCount++
    } catch {
        Write-Warning "Failed to set Windows Update to Manual: $_"
    }
} else {
    Write-Host "  → Windows Update: Left as-is" -ForegroundColor Yellow
}

Write-Host "`n[OK] Service optimization complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Services Disabled:  $disabledCount" -ForegroundColor Green
Write-Host "→  Services Skipped:   $skippedCount" -ForegroundColor Yellow
Write-Host "→  Services Not Found: $notFoundCount" -ForegroundColor Gray
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "`n💡 Restart recommended for all changes to take effect" -ForegroundColor Yellow
Write-Host "💡 You can re-enable any service via:" -ForegroundColor Yellow
Write-Host "   Set-Service -Name <ServiceName> -StartupType Automatic" -ForegroundColor Gray
Write-Host "   Start-Service -Name <ServiceName>" -ForegroundColor Gray
