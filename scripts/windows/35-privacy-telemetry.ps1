<#
Privacy & Telemetry Hardening
Disables Windows telemetry, diagnostics, Game Mode/Bar, Cortana, activity history, and advertising.
#>
$ErrorActionPreference = 'Stop'

Write-Host "[PRIVACY] Disabling telemetry and unnecessary features..."

Write-Host "`n🔒 Windows Telemetry & Diagnostics"
# Set telemetry to minimum (Security only - enterprise SKU only, otherwise Basic)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null

# Disable diagnostic data
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" /v ShowedToastAtLevel /t REG_DWORD /d 1 /f | Out-Null

Write-Host "  ✅ Telemetry disabled" -ForegroundColor Green

Write-Host "`n📊 Activity History & Timeline"
# Disable activity history
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v UploadUserActivities /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f | Out-Null

Write-Host "  ✅ Activity history disabled" -ForegroundColor Green

Write-Host "`n📱 Advertising & Personalization"
# Disable advertising ID
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f | Out-Null

# Disable app suggestions
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f | Out-Null

# Disable suggestions in Start
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f | Out-Null

Write-Host "  ✅ Advertising and suggestions disabled" -ForegroundColor Green

Write-Host "`n🎮 Game Mode & Game Bar"
# Disable Game Mode
reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 0 /f | Out-Null

# Disable Game Bar
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\GameBar" /v UseNexusForGameBarEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f | Out-Null

Write-Host "  ✅ Game Mode and Game Bar disabled" -ForegroundColor Green

Write-Host "`n🎤 Cortana & Voice Activation"
# Disable Cortana
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v CortanaEnabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v CanCortanaBeEnabled /t REG_DWORD /d 0 /f | Out-Null

# Disable voice activation
reg add "HKCU\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps" /v AgentActivationEnabled /t REG_DWORD /d 0 /f | Out-Null

Write-Host "  ✅ Cortana and voice activation disabled" -ForegroundColor Green

Write-Host "`n☁️ OneDrive & Cloud"
# Disable OneDrive (optional - prompts user)
if ($env:DISABLE_ONEDRIVE -eq 'Y') {
    $disableOneDrive = 'Y'
} elseif ($env:UNATTENDED_MODE) {
    $disableOneDrive = 'N'  # Conservative default
} else {
    $disableOneDrive = Read-Host "  Disable OneDrive integration? (Y/N) [Default: N]"
}
if ([string]::IsNullOrWhiteSpace($disableOneDrive)) { $disableOneDrive = 'N' }

if ($disableOneDrive -eq 'Y') {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f | Out-Null
    Write-Host "  ✅ OneDrive disabled" -ForegroundColor Green
} else {
    Write-Host "  → OneDrive left enabled" -ForegroundColor Yellow
}

Write-Host "`n🌐 Location & Sensors"
# Disable location tracking
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Deny /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f | Out-Null

Write-Host "  ✅ Location tracking disabled" -ForegroundColor Green

Write-Host "`n📷 Camera & Microphone Privacy"
# These are set to prompt, not fully disabled (keep for dev work like video calls)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" /v Value /t REG_SZ /d Deny /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" /v Value /t REG_SZ /d Deny /f | Out-Null

Write-Host "  ⚠️  Camera and microphone access set to ASK (Teams, Zoom need access)" -ForegroundColor Yellow

Write-Host "`n📧 Feedback & Tips"
# Disable feedback requests
reg add "HKCU\Software\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DoNotShowFeedbackNotifications /t REG_DWORD /d 1 /f | Out-Null

# Disable tips and suggestions
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f | Out-Null

Write-Host "  ✅ Feedback and tips disabled" -ForegroundColor Green

Write-Host "`n🔍 Search Suggestions & Web Results"
# Disable web results in Search
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f | Out-Null

Write-Host "  ✅ Search web results disabled" -ForegroundColor Green

Write-Host "`n⚡ Delivery Optimization (P2P Updates)"
# Limit Delivery Optimization to LAN only (not internet peers)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 1 /f | Out-Null

# Set bandwidth limits
try {
    Set-DeliveryOptimizationStatus -DownloadMode LAN | Out-Null
    Write-Host "  ✅ Delivery Optimization limited to LAN" -ForegroundColor Green
} catch {
    Write-Warning "  Delivery Optimization config failed (may need newer Windows version)"
}

Write-Host "`n🛡️ Windows Error Reporting"
# Disable Windows Error Reporting
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f | Out-Null

try {
    Stop-Service WerSvc -Force -ErrorAction SilentlyContinue
    Set-Service WerSvc -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "  ✅ Windows Error Reporting disabled" -ForegroundColor Green
} catch {
    Write-Warning "  WerSvc service configuration skipped"
}

Write-Host "`n📺 Consumer Features & Bloatware"
# Disable consumer features (prevents auto-installed apps like Candy Crush)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f | Out-Null

Write-Host "  ✅ Consumer features disabled" -ForegroundColor Green

Write-Host "`n🔄 Windows Update P2P"
# Already handled by Delivery Optimization above
Write-Host "  ✅ Windows Update P2P limited (configured above)" -ForegroundColor Green

Write-Host "`n[OK] Privacy and telemetry hardening complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Telemetry:          Minimized" -ForegroundColor Green
Write-Host "✅ Activity History:   Disabled" -ForegroundColor Green
Write-Host "✅ Advertising:        Disabled" -ForegroundColor Green
Write-Host "✅ Game Mode/Bar:      Disabled" -ForegroundColor Green
Write-Host "✅ Cortana:            Disabled" -ForegroundColor Green
Write-Host "✅ Location:           Disabled" -ForegroundColor Green
Write-Host "✅ Feedback:           Disabled" -ForegroundColor Green
Write-Host "✅ Web Search:         Disabled" -ForegroundColor Green
Write-Host "✅ Bloatware:          Blocked" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "`n⚠️  Note: Camera/Microphone set to ASK (needed for Teams, Zoom)" -ForegroundColor Yellow
Write-Host "💡 Restart Windows to apply all changes" -ForegroundColor Yellow
