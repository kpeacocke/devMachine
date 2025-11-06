<#
Additional Development Tools
Installs FREE supplementary dev tools: Insomnia, database clients, Wireshark, diagrams, etc.
NOTE: Paid tools (Postman Pro, Figma Pro, Typora, Sublime Text) are in 11-licensed-apps.ps1
#>
$ErrorActionPreference = 'Stop'

Write-Host "[DEV TOOLS] Installing additional development tools (free editions)..."

Write-Host "🔌 API Development & Testing"
Write-Host "  Installing Insomnia (free REST client)..."
winget install Insomnia.Insomnia --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🗄️ Database Clients"
Write-Host "  Installing DBeaver (universal DB client)..."
winget install dbeaver.dbeaver --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "  Installing SQL Server Management Studio (SSMS)..."
winget install Microsoft.SQLServerManagementStudio --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🌐 Network Tools"
Write-Host "  Installing Wireshark..."
winget install WiresharkFoundation.Wireshark --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "  Installing nmap..."
winget install Insecure.Nmap --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🎥 Screen Recording"
Write-Host "  Installing OBS Studio (screen recording/streaming)..."
winget install OBSProject.OBSStudio --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🔧 System Utilities"
Write-Host "  Installing PowerToys..."
winget install Microsoft.PowerToys --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "  Installing QuickLook (file preview)..."
winget install QL-Win.QuickLook --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "🎮 3D & Game Development"
Write-Host "  Installing Blender (3D modeling/animation)..."
winget install BlenderFoundation.Blender --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "  Installing Godot Engine (game development)..."
winget install GodotEngine.GodotEngine --source winget --silent --accept-package-agreements --accept-source-agreements

Write-Host "[OK] Additional dev tools installed!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ API Testing:      Insomnia" -ForegroundColor Green
Write-Host "✅ Databases:        DBeaver, SSMS" -ForegroundColor Green
Write-Host "✅ Network:          Wireshark, nmap" -ForegroundColor Green
Write-Host "✅ Screen Recording: OBS Studio" -ForegroundColor Green
Write-Host "✅ 3D & Game Dev:    Blender, Godot Engine" -ForegroundColor Green
Write-Host "✅ Utilities:        PowerToys, QuickLook" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "`n💡 NOTE: Paid tools (Postman Pro, Typora) available in 11-licensed-apps.ps1" -ForegroundColor Yellow
