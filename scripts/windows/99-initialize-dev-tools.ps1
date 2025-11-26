<#
.SYNOPSIS
Initialize development tools that require post-installation setup.

.DESCRIPTION
Run AFTER 10-windows-bootstrap.ps1 to complete initialization of:
- Rust (set default toolchain)
- Node.js package managers (yarn, pnpm, bun)
- Python package managers (pipenv, poetry)
- mise shims (gradle, maven)
- PATH refresh for MSBuild and ADK tools

Ensures all development tools are fully configured and ready to use.
#>
$ErrorActionPreference = 'Stop'

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

Write-Host "🚀 Initializing Development Tools" -ForegroundColor Cyan
Write-Host ""

# Refresh environment variables from registry
Write-Host "🔄 Refreshing environment variables..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
Write-Host "  ✅ Environment refreshed" -ForegroundColor Green

# 1. Rust - Set default toolchain
Write-Host ""
Write-Host "🦀 Rust Initialization" -ForegroundColor Cyan
if (Test-CommandExists "rustup") {
    try {
        $currentToolchain = rustup show 2>&1 | Select-String "Default host:" -Context 0,1
        if ($currentToolchain -match "no default toolchain" -or -not $currentToolchain) {
            Write-Host "  Setting default stable toolchain..."
            rustup default stable
            Write-Host "  ✅ Rust stable toolchain set as default" -ForegroundColor Green
        } else {
            Write-Host "  ✅ Rust toolchain already configured" -ForegroundColor Green
            rustup show | Select-String "Default host:" -Context 0,2 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    } catch {
        Write-Warning "Could not set Rust default toolchain: $_"
    }
} else {
    Write-Host "  ⚠️  rustup not found in PATH" -ForegroundColor Yellow
}

# 2. Node.js Package Managers
Write-Host ""
Write-Host "📦 Node.js Package Managers" -ForegroundColor Cyan
if (Test-CommandExists "npm") {
    # Check and install yarn
    if (-not (Test-CommandExists "yarn")) {
        Write-Host "  Installing yarn..."
        npm install -g yarn
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        if (Test-CommandExists "yarn") {
            Write-Host "  ✅ yarn installed: $(yarn --version)" -ForegroundColor Green
        } else {
            Write-Warning "yarn installation failed"
        }
    } else {
        Write-Host "  ✅ yarn already installed: $(yarn --version)" -ForegroundColor Green
    }

    # Check and install pnpm
    if (-not (Test-CommandExists "pnpm")) {
        Write-Host "  Installing pnpm..."
        npm install -g pnpm
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        if (Test-CommandExists "pnpm") {
            Write-Host "  ✅ pnpm installed: $(pnpm --version)" -ForegroundColor Green
        } else {
            Write-Warning "pnpm installation failed"
        }
    } else {
        Write-Host "  ✅ pnpm already installed: $(pnpm --version)" -ForegroundColor Green
    }

    # Check and install bun
    if (-not (Test-CommandExists "bun")) {
        Write-Host "  Installing bun via official installer..."
        try {
            Invoke-RestMethod bun.sh/install.ps1 | Invoke-Expression
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            if (Test-CommandExists "bun") {
                Write-Host "  ✅ bun installed: $(bun --version)" -ForegroundColor Green
            } else {
                Write-Warning "bun installation requires shell restart"
            }
        } catch {
            Write-Warning "bun installation failed: $_"
            Write-Host "  💡 Install manually from https://bun.sh" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✅ bun already installed: $(bun --version)" -ForegroundColor Green
    }
} else {
    Write-Host "  ⚠️  npm not found in PATH" -ForegroundColor Yellow
}

# 3. Python Package Managers
Write-Host ""
Write-Host "🐍 Python Package Managers" -ForegroundColor Cyan
if (Test-CommandExists "pip") {
    # Check and install pipenv
    if (-not (Test-CommandExists "pipenv")) {
        Write-Host "  Installing pipenv..."
        pip install --user pipenv
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        if (Test-CommandExists "pipenv") {
            Write-Host "  ✅ pipenv installed: $(pipenv --version)" -ForegroundColor Green
        } else {
            Write-Warning "pipenv installation failed (may need PATH refresh)"
        }
    } else {
        Write-Host "  ✅ pipenv already installed: $(pipenv --version)" -ForegroundColor Green
    }

    # Check and install poetry
    if (-not (Test-CommandExists "poetry")) {
        Write-Host "  Installing poetry..."
        pip install --user poetry
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        if (Test-CommandExists "poetry") {
            Write-Host "  ✅ poetry installed: $(poetry --version)" -ForegroundColor Green
        } else {
            Write-Warning "poetry installation failed (may need PATH refresh)"
        }
    } else {
        Write-Host "  ✅ poetry already installed: $(poetry --version)" -ForegroundColor Green
    }
} else {
    Write-Host "  ⚠️  pip not found in PATH" -ForegroundColor Yellow
}

# 4. JVM Build Tools (via mise)
Write-Host ""
Write-Host "☕ JVM Build Tools (mise)" -ForegroundColor Cyan
if (Test-CommandExists "mise") {
    # Activate mise in current session (simpler than shims approach)
    Write-Host "  Activating mise in current session..." -ForegroundColor Gray
    try {
        $miseEnv = mise env
        if ($miseEnv -match '\$Env:Path=''([^'']+)''') {
            $misePath = $matches[1]
            # Extract just the mise-managed paths (first part before existing PATH)
            $miseOnlyPaths = ($misePath -split ';' | Select-Object -First 5) -join ';'
            if ($env:Path -notlike "*$miseOnlyPaths*") {
                $env:Path = "$miseOnlyPaths;$env:Path"
                Write-Host "  ✅ mise tools activated in current session" -ForegroundColor Green
            } else {
                Write-Host "  ✅ mise already activated" -ForegroundColor Green
            }
        }
    } catch {
        Write-Warning "mise activation failed: $_"
    }

    # Check gradle
    if (-not (Test-CommandExists "gradle")) {
        Write-Host "  Installing gradle via mise..."
        mise use -g gradle@latest
        if (Test-CommandExists "gradle") {
            Write-Host "  ✅ gradle installed: $(gradle --version | Select-String 'Gradle')" -ForegroundColor Green
        } else {
            Write-Warning "gradle not yet available (may need shell restart)"
        }
    } else {
        Write-Host "  ✅ gradle already available: $(gradle --version | Select-String 'Gradle')" -ForegroundColor Green
    }

    # Check maven
    if (-not (Test-CommandExists "mvn")) {
        Write-Host "  Installing maven via mise..."
        mise use -g maven@latest
        if (Test-CommandExists "mvn") {
            Write-Host "  ✅ maven installed: $(mvn --version | Select-String 'Apache Maven')" -ForegroundColor Green
        } else {
            Write-Warning "maven not yet available (may need shell restart)"
        }
    } else {
        Write-Host "  ✅ maven already available: $(mvn --version | Select-String 'Apache Maven')" -ForegroundColor Green
    }
} else {
    Write-Host "  ⚠️  mise not found in PATH" -ForegroundColor Yellow
}

# 5. MSBuild Verification
Write-Host ""
Write-Host "🔨 MSBuild (.NET)" -ForegroundColor Cyan
if (Test-CommandExists "msbuild") {
    Write-Host "  ✅ msbuild available: $(msbuild -version | Select-String 'Microsoft' | Select-Object -First 1)" -ForegroundColor Green
} else {
    $msbuildPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin"
    if (Test-Path "$msbuildPath\msbuild.exe") {
        Write-Host "  ⚠️  msbuild found but not in PATH" -ForegroundColor Yellow
        Write-Host "    Path: $msbuildPath" -ForegroundColor Gray
        Write-Host "    💡 Restart PowerShell to access msbuild" -ForegroundColor Yellow
    } else {
        Write-Host "  ⚠️  msbuild not found (Visual Studio Build Tools may need installation)" -ForegroundColor Yellow
    }
}

# 6. Final Summary
Write-Host ""
Write-Host "💡 PowerShell Profile Check" -ForegroundColor Cyan
# Check multiple possible profile locations
$profilePaths = @(
    $PROFILE,
    "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
)

$foundProfile = $false
foreach ($profilePath in $profilePaths) {
    if (Test-Path $profilePath) {
        $foundProfile = $true
        $profileContent = Get-Content $profilePath -Raw
        if ($profileContent -match 'mise activate') {
            Write-Host "  ✅ mise activation configured in profile" -ForegroundColor Green
            Write-Host "    Profile: $profilePath" -ForegroundColor Gray
            Write-Host "    💡 New PowerShell sessions will have mise tools in PATH" -ForegroundColor Yellow
        } else {
            Write-Host "  ⚠️  mise not configured in profile" -ForegroundColor Yellow
            Write-Host "    Profile: $profilePath" -ForegroundColor Gray
            Write-Host "    💡 Run .\scripts\windows\06-powershell-profile.ps1 to configure" -ForegroundColor Yellow
        }
        break
    }
}

if (-not $foundProfile) {
    Write-Host "  ⚠️  PowerShell profile not found" -ForegroundColor Yellow
    Write-Host "    Expected: $($profilePaths[0])" -ForegroundColor Gray
    Write-Host "    💡 Run .\scripts\windows\06-powershell-profile.ps1 to create" -ForegroundColor Yellow
}

# 7. VS Code Shell Integration Note
Write-Host ""
Write-Host "💡 VS Code Integration" -ForegroundColor Cyan
$vscodeSettings = "$env:APPDATA\Code - Insiders\User\settings.json"
if (Test-Path $vscodeSettings) {
    $settings = Get-Content $vscodeSettings -Raw
    if ($settings -match '"terminal\.integrated\.shellIntegration\.enabled"\s*:\s*false') {
        Write-Host "  ✅ VS Code shell integration disabled (clean profile loading)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  VS Code shell integration enabled (may cause harmless errors)" -ForegroundColor Yellow
        Write-Host "    To disable: Settings → search 'shellIntegration' → uncheck 'Terminal › Integrated: Shell Integration'" -ForegroundColor Gray
        Write-Host "    Or add to settings.json: `"terminal.integrated.shellIntegration.enabled`": false" -ForegroundColor Gray
    }
} else {
    Write-Host "  ℹ️  VS Code Insiders settings not found" -ForegroundColor Gray
}

# 8. Final Summary
Write-Host ""
Write-Host "📊 Initialization Summary" -ForegroundColor Cyan
Write-Host ""

$tools = @{
    "rustc" = "Rust Compiler"
    "cargo" = "Rust Package Manager"
    "node" = "Node.js"
    "npm" = "Node Package Manager"
    "yarn" = "Yarn"
    "pnpm" = "pnpm"
    "bun" = "Bun"
    "python" = "Python"
    "pip" = "pip"
    "pipenv" = "Pipenv"
    "poetry" = "Poetry"
    "dotnet" = ".NET SDK"
    "msbuild" = "MSBuild"
    "java" = "Java"
    "javac" = "Java Compiler"
    "gradle" = "Gradle"
    "mvn" = "Maven"
    "go" = "Go"
    "git" = "Git"
    "docker" = "Docker"
    "wsl" = "WSL"
}

$available = @()
$missing = @()

foreach ($tool in $tools.Keys) {
    if (Test-CommandExists $tool) {
        $available += "  ✅ $($tools[$tool])"
    } else {
        $missing += "  ❌ $($tools[$tool])"
    }
}

if ($available.Count -gt 0) {
    Write-Host "Available Tools:" -ForegroundColor Green
    $available | ForEach-Object { Write-Host $_ -ForegroundColor Green }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "Missing Tools:" -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "💡 If tools are installed but not showing:" -ForegroundColor Yellow
    Write-Host "   1. Close and reopen PowerShell" -ForegroundColor Gray
    Write-Host "   2. Run this script again" -ForegroundColor Gray
    Write-Host "   3. Check PATH: `$env:Path" -ForegroundColor Gray
}

Write-Host ""
Write-Host "✅ Development tools initialization complete!" -ForegroundColor Green
Write-Host ""
