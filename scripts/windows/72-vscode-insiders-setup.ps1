<#
VS Code Insiders setup:
- Install VS Code Insiders (if missing)
- Create an "Insiders-Dev" profile with sensible settings.json
- Enable Settings Sync (prompts you to sign in on first run)
- Optionally alias 'code' -> 'code-insiders'
- Add a DAILY winget upgrade task (Insiders-friendly)
#>

param(
  [switch]$MakeCodeAliasToInsiders = $true
)

$ErrorActionPreference = 'Stop'

Write-Host "== Ensure VS Code Insiders is installed"
try {
  winget install Microsoft.VisualStudioCode.Insiders --silent --accept-source-agreements --accept-package-agreements
} catch {}

# Profile directory (Insiders)
$UserDir = Join-Path $env:APPDATA "Code - Insiders\User"
New-Item -ItemType Directory -Force -Path $UserDir | Out-Null

Write-Host "== Seed Insiders settings + profile"
$settingsPath = Join-Path $UserDir "settings.json"

$settings = @{
  "workbench.startupEditor" = "none";
  "window.zoomLevel"        = 0;
  "editor.fontFamily"       = "JetBrainsMono NF, Cascadia Code, Consolas, 'Courier New', monospace";
  "editor.fontLigatures"    = true;
  "editor.renderWhitespace" = "selection";
  "editor.formatOnSave"     = true;
  "editor.codeActionsOnSave" = @{
    "source.organizeImports" = "explicit"
  };
  "files.trimTrailingWhitespace" = true;
  "files.insertFinalNewline" = true;

  "settingsSync.keybindingsPerPlatform" = true;
  "settingsSync.editor" = true;
  "settingsSync.languageSpecificSettings" = true;
  "settingsSync.enabled" = true;

  "telemetry.telemetryLevel" = "error";
  "remote.WSL.logLevel" = "info";
  "remote.autoForwardPorts" = true;
}

($settings | ConvertTo-Json -Depth 10) | Out-File -Encoding utf8 $settingsPath

$profilesPath = Join-Path $UserDir "profiles.json"
$profiles = @{
  "profiles" = @(
    @{
      "name" = "Insiders-Dev";
      "shortName" = "dev";
      "settings" = @{};
      "extensions" = @()
    }
  );
  "defaultProfile" = "Insiders-Dev"
}
($profiles | ConvertTo-Json -Depth 10) | Out-File -Encoding utf8 $profilesPath

Write-Host "== Seed a common extension pack into Insiders"
$exts = @(
  "EditorConfig.EditorConfig","streetsidesoftware.code-spell-checker",
  "eamodio.gitlens","ms-azuretools.vscode-docker","ms-vscode-remote.remote-wsl",
  "ms-python.python","ms-python.vscode-pylance","rust-lang.rust-analyzer","golang.Go",
  "ms-dotnettools.csharp","vscjava.vscode-java-pack","dbaeumer.vscode-eslint","esbenp.prettier-vscode",
  "redhat.vscode-yaml","ms-vscode.powershell","yzhang.markdown-all-in-one","HashiCorp.terraform"
)
foreach ($e in $exts) { try { code-insiders --install-extension $e --force | Out-Null } catch {} }

if ($MakeCodeAliasToInsiders) {
  Write-Host "== Point 'code' CLI to 'code-insiders'"
  $bin = "$env:UserProfile\.local\bin"
  New-Item -ItemType Directory -Force -Path $bin | Out-Null
  "@echo off
code-insiders %*" | Out-File -Encoding ascii (Join-Path $bin "code.cmd")
  $uPath = [Environment]::GetEnvironmentVariable('Path','User')
  if ($uPath -notlike "*$bin*") { [Environment]::SetEnvironmentVariable('Path', $uPath + ";" + $bin, 'User') }
}

Write-Host "== Create a DAILY Insiders-friendly winget upgrade task (3:05 AM)"
$taskName = "Dev-Winget-Daily-Insiders"
schtasks /Query /TN $taskName /FO LIST 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  $cmd = 'powershell.exe -ExecutionPolicy Bypass -NoLogo -NoProfile -WindowStyle Hidden -Command "winget upgrade --all --include-unknown --silent"'
  schtasks /Create /SC DAILY /ST 03:05 /RL HIGHEST /TN $taskName /TR $cmd /F | Out-Null
} else {
  Write-Host "→ Daily Insiders upgrade task already exists"
}

Write-Host "✅ VS Code Insiders profile + sync seeded. Launch 'Code - Insiders' once and sign in to turn on Settings Sync."
