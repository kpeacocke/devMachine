<#
Windows Terminal Configuration Automation
Automates settings.json configuration for Windows Terminal with optimal dev settings.
#>
$ErrorActionPreference = 'Stop'

Write-Host "[WINDOWS TERMINAL] Configuring Windows Terminal settings..."

# Locate Windows Terminal settings.json
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$settingsPreviewPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"

# Check which version is installed
$targetPath = $null
if (Test-Path $settingsPath) {
    $targetPath = $settingsPath
    Write-Host "  Found Windows Terminal (stable)" -ForegroundColor Cyan
} elseif (Test-Path $settingsPreviewPath) {
    $targetPath = $settingsPreviewPath
    Write-Host "  Found Windows Terminal Preview" -ForegroundColor Cyan
} else {
    Write-Warning "Windows Terminal not found. Install via:"
    Write-Host "  winget install Microsoft.WindowsTerminal" -ForegroundColor Yellow
    exit 1
}

# Backup existing settings
$backupPath = "$targetPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
if (Test-Path $targetPath) {
    Copy-Item $targetPath $backupPath
    Write-Host "  Backed up existing settings to:" -ForegroundColor Yellow
    Write-Host "  $backupPath" -ForegroundColor Gray
}

# Detect PowerShell 7 installation
$pwsh7Path = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh7Path) {
    $pwsh7Path = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
}
if (-not (Test-Path $pwsh7Path)) {
    Write-Warning "PowerShell 7 not found. Using Windows PowerShell as default."
    $pwsh7Path = "powershell.exe"
}

# Detect WSL Ubuntu installation
$wslInstalled = $false
try {
    $wslDistros = wsl --list --quiet 2>$null
    if ($wslDistros -match 'Ubuntu') {
        $wslInstalled = $true
        Write-Host "  ✅ WSL Ubuntu detected" -ForegroundColor Green
    }
} catch {
    Write-Host "  → WSL not detected (skipping Ubuntu profile)" -ForegroundColor Yellow
}

# Create optimized Windows Terminal configuration
$config = @{
    '$help' = 'https://aka.ms/terminal-documentation'
    '$schema' = 'https://aka.ms/terminal-profiles-schema'
    defaultProfile = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'  # PowerShell 7 GUID

    profiles = @{
        defaults = @{
            font = @{
                face = 'JetBrainsMono Nerd Font'
                size = 11
            }
            colorScheme = 'One Half Dark'
            opacity = 95
            useAcrylic = $true
            acrylicOpacity = 0.9
            cursorShape = 'bar'
            antialiasingMode = 'cleartype'
            bellStyle = 'none'
        }
        list = @(
            @{
                guid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
                name = 'PowerShell 7'
                source = 'Windows.Terminal.PowershellCore'
                commandline = $pwsh7Path
                icon = 'ms-appx:///ProfileIcons/{574e775e-4f2a-5b96-ac1e-a2962a402336}.png'
                startingDirectory = '%USERPROFILE%'
                hidden = $false
            },
            @{
                guid = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'
                name = 'Windows PowerShell'
                commandline = 'powershell.exe'
                hidden = $false
                startingDirectory = '%USERPROFILE%'
            },
            @{
                guid = '{0caa0dad-35be-5f56-a8ff-afceeeaa6101}'
                name = 'Command Prompt'
                commandline = 'cmd.exe'
                hidden = $false
                startingDirectory = '%USERPROFILE%'
            }
        )
    }

    schemes = @(
        @{
            name = 'One Half Dark'
            black = '#282c34'
            red = '#e06c75'
            green = '#98c379'
            yellow = '#e5c07b'
            blue = '#61afef'
            purple = '#c678dd'
            cyan = '#56b6c2'
            white = '#dcdfe4'
            brightBlack = '#282c34'
            brightRed = '#e06c75'
            brightGreen = '#98c379'
            brightYellow = '#e5c07b'
            brightBlue = '#61afef'
            brightPurple = '#c678dd'
            brightCyan = '#56b6c2'
            brightWhite = '#dcdfe4'
            background = '#282c34'
            foreground = '#dcdfe4'
            selectionBackground = '#3e4451'
            cursorColor = '#528bff'
        }
    )

    actions = @(
        @{ command = 'find'; keys = 'ctrl+shift+f' }
        @{ command = @{ action = 'copy'; singleLine = $false }; keys = 'ctrl+c' }
        @{ command = 'paste'; keys = 'ctrl+v' }
        @{ command = 'newTab'; keys = 'ctrl+t' }
        @{ command = 'closeTab'; keys = 'ctrl+w' }
        @{ command = @{ action = 'splitPane'; split = 'auto'; splitMode = 'duplicate' }; keys = 'alt+shift+d' }
        @{ command = @{ action = 'splitPane'; split = 'horizontal' }; keys = 'alt+shift+minus' }
        @{ command = @{ action = 'splitPane'; split = 'vertical' }; keys = 'alt+shift+plus' }
        @{ command = 'toggleFocusMode'; keys = 'f11' }
        @{ command = 'toggleFullscreen'; keys = 'alt+enter' }
    )

    copyOnSelect = $false
    copyFormatting = $false
    confirmCloseAllTabs = $true
    largePasteWarning = $true
    multiLinePasteWarning = $true
    trimBlockSelection = $true
    wordDelimiters = ' ./\()\"''-:,.;<>~!@#$%^&*|+=[]{}~?\u2502'

    theme = 'dark'
    tabWidthMode = 'equal'
    showTabsInTitlebar = $true
    alwaysShowTabs = $true
    startOnUserLogin = $false
    launchMode = 'default'
    initialCols = 120
    initialRows = 30
}

# Add WSL Ubuntu profile if installed
if ($wslInstalled) {
    $ubuntuProfile = @{
        guid = '{2c4de342-38b7-51cf-b940-2309a097f518}'
        name = 'Ubuntu'
        source = 'Windows.Terminal.Wsl'
        commandline = 'wsl.exe -d Ubuntu'
        icon = 'ms-appx:///ProfileIcons/{9acb9455-ca41-5af7-950f-6bca1bc9722f}.png'
        startingDirectory = '~'
        hidden = $false
    }
    $config.profiles.list += $ubuntuProfile
}

# Convert to JSON and save
Write-Host "`n  Writing configuration to $targetPath..." -ForegroundColor Cyan
$jsonConfig = $config | ConvertTo-Json -Depth 10
$jsonConfig | Set-Content -Path $targetPath -Encoding UTF8

Write-Host "`n[OK] Windows Terminal configured successfully!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Default Profile:   PowerShell 7" -ForegroundColor Green
Write-Host "✅ Font:              JetBrainsMono Nerd Font (size 11)" -ForegroundColor Green
Write-Host "✅ Color Scheme:      One Half Dark" -ForegroundColor Green
Write-Host "✅ Opacity:           95% with acrylic" -ForegroundColor Green
Write-Host "✅ Starting Dir:      %USERPROFILE%" -ForegroundColor Green
Write-Host "✅ Keyboard Shortcuts:" -ForegroundColor Green
Write-Host "   • Ctrl+Shift+F:    Find" -ForegroundColor Gray
Write-Host "   • Ctrl+T:          New tab" -ForegroundColor Gray
Write-Host "   • Ctrl+W:          Close tab" -ForegroundColor Gray
Write-Host "   • Alt+Shift+D:     Duplicate pane" -ForegroundColor Gray
Write-Host "   • Alt+Shift+-:     Split horizontal" -ForegroundColor Gray
Write-Host "   • Alt+Shift++:     Split vertical" -ForegroundColor Gray
Write-Host "   • F11:             Focus mode" -ForegroundColor Gray
Write-Host "   • Alt+Enter:       Fullscreen" -ForegroundColor Gray
if ($wslInstalled) {
    Write-Host "✅ WSL Ubuntu:        Profile included" -ForegroundColor Green
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "`n💡 Restart Windows Terminal to apply changes" -ForegroundColor Yellow
Write-Host "💡 Backup saved to: $backupPath" -ForegroundColor Yellow
Write-Host "`n⚠️  Ensure JetBrainsMono Nerd Font is installed!" -ForegroundColor Yellow
Write-Host "   Install via: winget install JanDeDobbeleer.OhMyPosh (includes font)" -ForegroundColor Gray
Write-Host "   Or download: https://www.nerdfonts.com/font-downloads" -ForegroundColor Gray
