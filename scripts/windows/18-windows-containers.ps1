<#
.SYNOPSIS
    Configure Windows Containers and container development features

.DESCRIPTION
    This script configures Windows container features including:
    - Windows container feature enablement
    - Hyper-V container isolation support
    - Container management tools
    - Windows Subsystem for Linux integration
    - Container development optimizations

.EXAMPLE
    .\scripts\windows\18-windows-containers.ps1

.EXAMPLE
    .\scripts\windows\18-windows-containers.ps1 -WhatIf

.NOTES
    Requires Administrator privileges and may require a reboot
    Run after Docker Desktop installation
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "Show what would be done without making changes")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Skip Hyper-V container isolation setup")]
    [switch]$SkipHyperV,

    [Parameter(HelpMessage = "Enable Windows container base image pre-caching")]
    [switch]$EnableBaseCaching
)

$ErrorActionPreference = 'Stop'

function Test-Command($n){ $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

function Test-ContainerFeature {
    param([string]$FeatureName)
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
        return $feature.State -eq 'Enabled'
    } catch {
        return $false
    }
}

function Enable-ContainerFeature {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$FeatureName,
        [string]$DisplayName
    )

    if (Test-ContainerFeature -FeatureName $FeatureName) {
        Write-Host "  → $DisplayName already enabled" -ForegroundColor Green
        return $false
    }

    if ($WhatIf) {
        Write-Host "  🔍 Would enable $DisplayName" -ForegroundColor Cyan
        return $false
    }

    if ($PSCmdlet.ShouldProcess($DisplayName, "Enable Windows Feature")) {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart | Out-Null
            Write-Host "  ✅ $DisplayName enabled" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "  ❌ Failed to enable $DisplayName`: $_" -ForegroundColor Red
            return $false
        }
    }
    return $false
}

Write-Host "🐳 Windows Container Features Configuration" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Check if running in WhatIf mode
if ($WhatIf) {
    Write-Host "`n🔍 WHAT-IF MODE: No changes will be made" -ForegroundColor Cyan
    Write-Host "   This would configure Windows container features and optimizations." -ForegroundColor Gray
}

$rebootRequired = $false

Write-Host "`n📦 Windows Container Features"
Write-Host "   Enabling core container functionality..."

# Enable Windows Subsystem for Linux (if not already enabled)
if (-not (Test-ContainerFeature -FeatureName "Microsoft-Windows-Subsystem-Linux")) {
    $rebootRequired = Enable-ContainerFeature -FeatureName "Microsoft-Windows-Subsystem-Linux" -DisplayName "Windows Subsystem for Linux" -or $rebootRequired
}

# Enable Virtual Machine Platform (required for WSL2 and Hyper-V containers)
if (-not (Test-ContainerFeature -FeatureName "VirtualMachinePlatform")) {
    $rebootRequired = Enable-ContainerFeature -FeatureName "VirtualMachinePlatform" -DisplayName "Virtual Machine Platform" -or $rebootRequired
}

# Enable Windows Hypervisor Platform (for container isolation)
if (-not $SkipHyperV) {
    if (-not (Test-ContainerFeature -FeatureName "HypervisorPlatform")) {
        $rebootRequired = Enable-ContainerFeature -FeatureName "HypervisorPlatform" -DisplayName "Windows Hypervisor Platform" -or $rebootRequired
    }
}

# Enable Containers feature (Windows containers)
if (-not (Test-ContainerFeature -FeatureName "Containers")) {
    $rebootRequired = Enable-ContainerFeature -FeatureName "Containers" -DisplayName "Windows Containers" -or $rebootRequired
}

# Enable Hyper-V (if not skipped and supported)
if (-not $SkipHyperV) {
    if (-not (Test-ContainerFeature -FeatureName "Microsoft-Hyper-V-All")) {
        Write-Host "   Checking Hyper-V compatibility..."
        try {
            $hyperVInfo = Get-ComputerInfo -Property "HyperV*" -ErrorAction Stop
            if ($hyperVInfo.HyperVRequirementDataExecutionPreventionAvailable -and
                $hyperVInfo.HyperVRequirementSecondLevelAddressTranslation -and
                $hyperVInfo.HyperVRequirementVirtualizationFirmwareEnabled -and
                $hyperVInfo.HyperVRequirementVMMonitorModeExtensions) {

                $rebootRequired = Enable-ContainerFeature -FeatureName "Microsoft-Hyper-V-All" -DisplayName "Hyper-V Platform" -or $rebootRequired
            } else {
                Write-Host "  ⚠️  Hyper-V requirements not met (virtualization disabled or unsupported)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  ⚠️  Could not check Hyper-V compatibility: $_" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n🔧 Container Development Tools"
Write-Host "   Installing container management tools..."

# Install Windows container tools
if (Test-Command "docker") {
    Write-Host "  → Docker already available" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Docker not found - install Docker Desktop first" -ForegroundColor Yellow
}

# Install container build tools
$containerTools = @(
    @{ Name = "hadolint"; Package = "hadolint"; Description = "Dockerfile linter" },
    @{ Name = "trivy"; Package = "AquaSecurity.Trivy"; Description = "Container vulnerability scanner" },
    @{ Name = "dive"; Package = "wagoodman.dive"; Description = "Docker image layer analyzer" }
)

foreach ($tool in $containerTools) {
    if (Test-Command $tool.Name) {
        Write-Host "  → $($tool.Description) already installed" -ForegroundColor Green
    } else {
        if (-not $WhatIf) {
            try {
                Write-Host "  Installing $($tool.Description)..." -ForegroundColor Gray
                winget install $tool.Package --source winget --silent --accept-package-agreements --accept-source-agreements
                Write-Host "  ✅ $($tool.Description) installed" -ForegroundColor Green
            } catch {
                Write-Host "  ⚠️  Failed to install $($tool.Description): $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  🔍 Would install $($tool.Description)" -ForegroundColor Cyan
        }
    }
}

Write-Host "`n🛡️  Container Security Configuration"
Write-Host "   Configuring security settings for containers..."

if (-not $WhatIf) {
    # Configure Windows Defender exclusions for container workloads
    try {
        if (Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) {
            $containerPaths = @(
                "$env:ProgramData\Docker",
                "$env:USERPROFILE\.docker",
                "$env:LOCALAPPDATA\Docker"
            )

            foreach ($path in $containerPaths) {
                if (Test-Path $path) {
                    try {
                        Add-MpPreference -ExclusionPath $path -ErrorAction Stop
                        Write-Host "  ✅ Added Defender exclusion: $path" -ForegroundColor Green
                    } catch {
                        Write-Host "  ⚠️  Could not add exclusion for: $path" -ForegroundColor Yellow
                    }
                }
            }

            # Exclude container processes
            $containerProcesses = @("dockerd.exe", "docker.exe", "containerd.exe", "runc.exe")
            foreach ($process in $containerProcesses) {
                try {
                    Add-MpPreference -ExclusionProcess $process -ErrorAction Stop
                    Write-Host "  ✅ Added Defender exclusion for process: $process" -ForegroundColor Green
                } catch {
                    Write-Host "  ⚠️  Could not add process exclusion: $process" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "  ⚠️  Windows Defender cmdlets not available" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠️  Could not configure Defender exclusions: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  🔍 Would configure Windows Defender exclusions for containers" -ForegroundColor Cyan
}

Write-Host "`n⚙️ Container Runtime Optimization"
Write-Host "   Optimizing container performance settings..."

if (-not $WhatIf) {
    # Configure Windows container storage optimization
    try {
        $containerStorageRoot = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization\Containers"
        if (-not (Test-Path $containerStorageRoot)) {
            New-Item -Path $containerStorageRoot -Force | Out-Null
        }

        # Enable container layer compression
        Set-ItemProperty -Path $containerStorageRoot -Name "EnableLayerCompression" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Write-Host "  ✅ Container layer compression enabled" -ForegroundColor Green

        # Optimize container memory usage
        Set-ItemProperty -Path $containerStorageRoot -Name "OptimizeMemoryUsage" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Write-Host "  ✅ Container memory optimization enabled" -ForegroundColor Green

    } catch {
        Write-Host "  ⚠️  Could not apply container storage optimizations: $_" -ForegroundColor Yellow
    }

    # Configure network optimizations for containers
    try {
        $networkOptPath = "HKLM:\SYSTEM\CurrentControlSet\Services\hns\Parameters"
        if (Test-Path $networkOptPath) {
            Set-ItemProperty -Path $networkOptPath -Name "EnableRSC" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Write-Host "  ✅ Container network receive side coalescing enabled" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ⚠️  Could not apply network optimizations: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  🔍 Would configure container storage and network optimizations" -ForegroundColor Cyan
}

# Base image caching (if requested)
if ($EnableBaseCaching) {
    Write-Host "`n📥 Container Base Image Pre-caching"
    Write-Host "   Downloading common Windows container base images..."

    $baseImages = @(
        "mcr.microsoft.com/windows/nanoserver:ltsc2022",
        "mcr.microsoft.com/windows/servercore:ltsc2022",
        "mcr.microsoft.com/dotnet/runtime:8.0-nanoserver-ltsc2022",
        "mcr.microsoft.com/dotnet/aspnet:8.0-nanoserver-ltsc2022"
    )

    if (Test-Command "docker" -and -not $WhatIf) {
        foreach ($image in $baseImages) {
            try {
                Write-Host "  Pulling $image..." -ForegroundColor Gray
                docker pull $image 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✅ Cached: $image" -ForegroundColor Green
                } else {
                    Write-Host "  ⚠️  Failed to pull: $image" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  ⚠️  Error pulling $image`: $_" -ForegroundColor Yellow
            }
        }
    } else {
        if ($WhatIf) {
            Write-Host "  🔍 Would pre-cache Windows container base images" -ForegroundColor Cyan
        } else {
            Write-Host "  ⚠️  Docker not available for base image caching" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n🔍 Container Environment Validation"
Write-Host "   Validating container features and tools..."

# Validate enabled features
$features = @(
    @{ Name = "Microsoft-Windows-Subsystem-Linux"; Display = "WSL" },
    @{ Name = "VirtualMachinePlatform"; Display = "Virtual Machine Platform" },
    @{ Name = "Containers"; Display = "Windows Containers" }
)

if (-not $SkipHyperV) {
    $features += @{ Name = "Microsoft-Hyper-V-All"; Display = "Hyper-V" }
    $features += @{ Name = "HypervisorPlatform"; Display = "Hypervisor Platform" }
}

foreach ($feature in $features) {
    if (Test-ContainerFeature -FeatureName $feature.Name) {
        Write-Host "  ✅ $($feature.Display) enabled" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($feature.Display) not enabled" -ForegroundColor Red
    }
}

# Validate tools
$tools = @("docker", "hadolint", "trivy", "dive")
foreach ($tool in $tools) {
    if (Test-Command $tool) {
        Write-Host "  ✅ $tool available" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  $tool not found" -ForegroundColor Yellow
    }
}

Write-Host "`n📖 Container Development Guidance" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "`n🐧 Linux Containers (Default):" -ForegroundColor Yellow
Write-Host "  • Use Docker Desktop's default Linux container mode" -ForegroundColor Gray
Write-Host "  • Better ecosystem support and performance for most workloads" -ForegroundColor Gray
Write-Host "  • Example: docker run --rm hello-world" -ForegroundColor Gray

Write-Host "`n🪟 Windows Containers:" -ForegroundColor Yellow
Write-Host "  • Switch Docker Desktop to Windows container mode when needed" -ForegroundColor Gray
Write-Host "  • Required for Windows-specific applications (.NET Framework)" -ForegroundColor Gray
Write-Host "  • Example: docker run --rm mcr.microsoft.com/windows/nanoserver:ltsc2022 cmd /c echo hello" -ForegroundColor Gray

Write-Host "`n🔧 Container Development Tools:" -ForegroundColor Yellow
Write-Host "  • hadolint: Lint Dockerfiles for best practices" -ForegroundColor Gray
Write-Host "  • trivy: Scan images for vulnerabilities" -ForegroundColor Gray
Write-Host "  • dive: Analyze image layers and optimize size" -ForegroundColor Gray

Write-Host "`n🚀 Performance Tips:" -ForegroundColor Yellow
Write-Host "  • Use Windows container base images only when necessary" -ForegroundColor Gray
Write-Host "  • Prefer nano server over server core for smaller images" -ForegroundColor Gray
Write-Host "  • Use multi-stage builds to reduce final image size" -ForegroundColor Gray
Write-Host "  • Configure Docker Desktop data-root on Dev Drive if available" -ForegroundColor Gray

# Summary and reboot notification
Write-Host "`n✅ Windows Container Configuration Complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green

if ($rebootRequired) {
    Write-Host "🔄 REBOOT REQUIRED" -ForegroundColor Red
    Write-Host "   Some Windows features require a restart to take effect." -ForegroundColor Yellow
    Write-Host "   Please reboot your system before using container features." -ForegroundColor Yellow
} else {
    Write-Host "💻 No reboot required - container features ready to use!" -ForegroundColor Green
}

Write-Host "`n💡 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Restart Docker Desktop to apply configuration changes" -ForegroundColor Gray
Write-Host "  2. Test container functionality: docker run --rm hello-world" -ForegroundColor Gray
Write-Host "  3. Consider running 40-devdrive-caches.ps1 to optimize Docker performance" -ForegroundColor Gray

if ($WhatIf) {
    Write-Host "`n🔍 Run without -WhatIf to apply these changes" -ForegroundColor Cyan
}
