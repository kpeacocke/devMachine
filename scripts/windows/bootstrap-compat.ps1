<#
PowerShell 7 compatibility layer for the devMachine bootstrap.

Loaded by setup-machine.ps1 for the lifetime of the bootstrap only.

Why this exists:
- The inbox DISM PowerShell cmdlets can fail from PowerShell 7 on current
  Windows 11 builds with "Class not registered".
- Get-WmiObject and the System Restore cmdlets are Windows PowerShell-era APIs.
- Some Appx/DISM commands are safest behind the Windows PowerShell compatibility
  boundary.
- setup-machine-core.ps1 contains one WSL cp call with a raw C:\ path; Linux cp
  needs a Linux path.

Normal development commands continue to run in PowerShell 7.
#>

$script:WindowsPowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$script:DismExe = Join-Path $env:SystemRoot 'System32\dism.exe'
$script:WslExe = Join-Path $env:SystemRoot 'System32\wsl.exe'

function ConvertTo-PSLiteral {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return '$null' }
    return "'" + $Value.Replace("'", "''") + "'"
}

function Invoke-WindowsPowerShell51 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        [switch]$IgnoreExitCode
    )

    if (-not (Test-Path $script:WindowsPowerShellExe)) {
        throw "Windows PowerShell 5.1 executable not found at $script:WindowsPowerShellExe"
    }

    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
    $output = & $script:WindowsPowerShellExe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encoded 2>&1
    $exitCode = $LASTEXITCODE

    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        $message = ($output | Out-String).Trim()
        throw "Windows PowerShell 5.1 command failed with exit code $exitCode. $message"
    }

    return $output
}

function Invoke-NativeDism {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [int[]]$SuccessExitCodes = @(0, 3010)
    )

    $output = & $script:DismExe @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -notin $SuccessExitCodes) {
        throw "DISM failed with exit code $exitCode.`n$(($output | Out-String).Trim())"
    }
    return $output
}

# Prefer Microsoft's supported Windows PowerShell compatibility boundary for
# inbox modules. Fall back to native DISM wrappers if the compatibility import
# is unavailable or disabled in PowerShell configuration.
$script:DismCompatLoaded = $false
try {
    Import-Module Dism -UseWindowsPowerShell -Force -WarningAction SilentlyContinue -ErrorAction Stop
    $script:DismCompatLoaded = $true
    Write-Host "[COMPAT] DISM module routed through Windows PowerShell 5.1" -ForegroundColor DarkGray
}
catch {
    Write-Warning "[COMPAT] Could not import DISM through Windows PowerShell compatibility. Using dism.exe fallback: $($_.Exception.Message)"
}

if (-not $script:DismCompatLoaded) {
    function Get-WindowsOptionalFeature {
        [CmdletBinding()]
        param(
            [switch]$Online,
            [Parameter(Mandatory)]
            [string]$FeatureName
        )

        $output = Invoke-NativeDism -Arguments @(
            '/Online',
            '/English',
            '/Get-FeatureInfo',
            "/FeatureName:$FeatureName"
        ) -SuccessExitCodes @(0)

        $state = 'Unknown'
        foreach ($line in $output) {
            if ([string]$line -match '^\s*State\s*:\s*(.+?)\s*$') {
                $state = $Matches[1].Trim()
                break
            }
        }

        [pscustomobject]@{
            FeatureName = $FeatureName
            State = $state
            Online = $true
        }
    }

    function Enable-WindowsOptionalFeature {
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [switch]$Online,
            [Parameter(Mandatory)]
            [string]$FeatureName,
            [switch]$All,
            [switch]$NoRestart
        )

        if ($PSCmdlet.ShouldProcess($FeatureName, 'Enable Windows optional feature')) {
            $arguments = @('/Online', '/Enable-Feature', "/FeatureName:$FeatureName", '/Quiet')
            if ($All) { $arguments += '/All' }
            if ($NoRestart) { $arguments += '/NoRestart' }

            $output = Invoke-NativeDism -Arguments $arguments
            [pscustomobject]@{
                FeatureName = $FeatureName
                Online = $true
                Output = $output
            }
        }
    }

    function Disable-WindowsOptionalFeature {
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [switch]$Online,
            [Parameter(Mandatory)]
            [string]$FeatureName,
            [switch]$NoRestart
        )

        if ($PSCmdlet.ShouldProcess($FeatureName, 'Disable Windows optional feature')) {
            $arguments = @('/Online', '/Disable-Feature', "/FeatureName:$FeatureName", '/Quiet')
            if ($NoRestart) { $arguments += '/NoRestart' }

            $output = Invoke-NativeDism -Arguments $arguments
            [pscustomobject]@{
                FeatureName = $FeatureName
                Online = $true
                Output = $output
            }
        }
    }

    function Add-WindowsCapability {
        [CmdletBinding(SupportsShouldProcess)]
        param(
            [switch]$Online,
            [Parameter(Mandatory)]
            [string]$Name,
            [string[]]$Source,
            [switch]$LimitAccess
        )

        if ($PSCmdlet.ShouldProcess($Name, 'Add Windows capability')) {
            $arguments = @('/Online', '/Add-Capability', "/CapabilityName:$Name", '/NoRestart', '/Quiet')
            foreach ($sourcePath in @($Source)) {
                if ($sourcePath) { $arguments += "/Source:$sourcePath" }
            }
            if ($LimitAccess) { $arguments += '/LimitAccess' }

            $output = Invoke-NativeDism -Arguments $arguments
            [pscustomobject]@{
                Name = $Name
                Online = $true
                Output = $output
            }
        }
    }
}

# Appx objects are used in pipelines in 09-debloat-windows.ps1, so use the
# built-in compatibility proxy rather than reimplementing those object types.
try {
    Import-Module Appx -UseWindowsPowerShell -Force -WarningAction SilentlyContinue -ErrorAction Stop
    Write-Host "[COMPAT] Appx module routed through Windows PowerShell 5.1" -ForegroundColor DarkGray
}
catch {
    Write-Warning "[COMPAT] Appx compatibility import failed. Windows may still autoload the inbox module: $($_.Exception.Message)"
}

# Get-WmiObject was removed from PowerShell 7. The repo only uses it for
# property queries; Get-CimInstance is the supported replacement.
function Get-WmiObject {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [Alias('ClassName')]
        [string]$Class,
        [string]$Namespace = 'root\cimv2',
        [string]$Filter,
        [string]$ComputerName
    )

    $parameters = @{
        ClassName = $Class
        Namespace = $Namespace
    }
    if ($Filter) { $parameters.Filter = $Filter }
    if ($ComputerName) { $parameters.ComputerName = $ComputerName }

    Get-CimInstance @parameters
}

# System Restore cmdlets are Windows PowerShell-era commands. Keep their public
# names so existing scripts do not need to know which host is executing them.
function Enable-ComputerRestore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Drive
    )

    foreach ($drivePath in $Drive) {
        $literal = ConvertTo-PSLiteral $drivePath
        Invoke-WindowsPowerShell51 -Command "Enable-ComputerRestore -Drive $literal -ErrorAction Stop" | Out-Null
    }
}

function Checkpoint-Computer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Description,
        [ValidateSet('APPLICATION_INSTALL','APPLICATION_UNINSTALL','DEVICE_DRIVER_INSTALL','MODIFY_SETTINGS','CANCELLED_OPERATION')]
        [string]$RestorePointType = 'APPLICATION_INSTALL'
    )

    $descriptionLiteral = ConvertTo-PSLiteral $Description
    $typeLiteral = ConvertTo-PSLiteral $RestorePointType
    Invoke-WindowsPowerShell51 -Command "Checkpoint-Computer -Description $descriptionLiteral -RestorePointType $typeLiteral -ErrorAction Stop" | Out-Null
}

function Get-ComputerRestorePoint {
    [CmdletBinding()]
    param(
        [int]$RestorePoint
    )

    $selector = if ($PSBoundParameters.ContainsKey('RestorePoint')) {
        " -RestorePoint $RestorePoint"
    }
    else {
        ''
    }

    $command = @"
`$items = Get-ComputerRestorePoint$selector -ErrorAction SilentlyContinue |
    Select-Object SequenceNumber, Description, CreationTime, RestorePointType, EventType
if (`$null -ne `$items) {
    `$items | ConvertTo-Json -Compress -Depth 4
}
"@

    $output = Invoke-WindowsPowerShell51 -Command $command
    $json = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($json)) {
        return
    }

    $json | ConvertFrom-Json
}

# The preserved orchestrator has one raw Windows path passed to Linux `cp`.
# Intercept wsl.exe calls only to translate those cp source arguments.
function wsl {
    $nativeArguments = @($args | ForEach-Object { [string]$_ })

    if ($env:DEVMACHINE_SKIP_WSL -eq 'true') {
        Set-Variable -Name LASTEXITCODE -Scope 1 -Value 0 -ErrorAction SilentlyContinue
        return
    }

    $execIndex = [Array]::IndexOf($nativeArguments, '-e')
    if ($execIndex -lt 0) {
        $execIndex = [Array]::IndexOf($nativeArguments, '--exec')
    }

    if ($execIndex -ge 0 -and ($execIndex + 1) -lt $nativeArguments.Count -and $nativeArguments[$execIndex + 1] -eq 'cp') {
        for ($i = $execIndex + 2; $i -lt $nativeArguments.Count; $i++) {
            if ($nativeArguments[$i] -match '^([A-Za-z]):\\(.*)$') {
                $drive = $Matches[1].ToLowerInvariant()
                $rest = $Matches[2] -replace '\\', '/'
                $nativeArguments[$i] = "/mnt/$drive/$rest"
            }
        }
    }

    $output = & $script:WslExe @nativeArguments
    $exitCode = $LASTEXITCODE
    Set-Variable -Name LASTEXITCODE -Scope 1 -Value $exitCode -ErrorAction SilentlyContinue
    return $output
}
