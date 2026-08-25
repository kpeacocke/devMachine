<#
PowerShell 7 compatibility layer for the devMachine bootstrap.

Loaded by setup-machine.ps1 for the lifetime of the bootstrap only.

Rules:
- Windows servicing (optional features/capabilities) ALWAYS uses dism.exe.
  Do not use Import-Module Dism -UseWindowsPowerShell here: on affected
  Windows 11 builds that proxy can still fail with "Class not registered".
- Appx uses the Windows PowerShell compatibility proxy where available.
- Get-WmiObject is mapped to Get-CimInstance for legacy repo call sites.
- System Restore operations are explicitly executed in Windows PowerShell 5.1.
- WSL cp calls have Windows source paths translated to /mnt/<drive>/... paths.

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

    if (-not (Test-Path $script:DismExe)) {
        throw "DISM executable not found at $script:DismExe"
    }

    $output = & $script:DismExe @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -notin $SuccessExitCodes) {
        throw "DISM failed with exit code $exitCode.`n$(($output | Out-String).Trim())"
    }

    return $output
}

function Get-NativeWindowsFeatureState {
    [CmdletBinding()]
    param(
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

    return $state
}

# ---------------------------------------------------------------------------
# DISM compatibility
# ---------------------------------------------------------------------------
# These functions are deliberately defined unconditionally. PowerShell function
# command precedence ensures the repo never reaches the DISM module cmdlets while
# this bootstrap compatibility layer is loaded.

function Get-WindowsOptionalFeature {
    [CmdletBinding()]
    param(
        [switch]$Online,
        [Parameter(Mandatory)]
        [string]$FeatureName
    )

    $state = Get-NativeWindowsFeatureState -FeatureName $FeatureName

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

    try {
        if ((Get-NativeWindowsFeatureState -FeatureName $FeatureName) -eq 'Enabled') {
            return [pscustomobject]@{
                FeatureName = $FeatureName
                State = 'Enabled'
                Online = $true
                RestartNeeded = $false
            }
        }
    }
    catch {
        Write-Verbose "Could not pre-query feature $FeatureName; DISM enable will determine the result: $($_.Exception.Message)"
    }

    if ($PSCmdlet.ShouldProcess($FeatureName, 'Enable Windows optional feature')) {
        $arguments = @('/Online', '/Enable-Feature', "/FeatureName:$FeatureName", '/Quiet')
        if ($All) { $arguments += '/All' }
        if ($NoRestart) { $arguments += '/NoRestart' }

        Invoke-NativeDism -Arguments $arguments | Out-Null

        return [pscustomobject]@{
            FeatureName = $FeatureName
            State = 'Enabled'
            Online = $true
            RestartNeeded = $false
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

    try {
        $currentState = Get-NativeWindowsFeatureState -FeatureName $FeatureName
        if ($currentState -match '^Disabled') {
            return [pscustomobject]@{
                FeatureName = $FeatureName
                State = $currentState
                Online = $true
                RestartNeeded = $false
            }
        }
    }
    catch {
        Write-Verbose "Could not pre-query feature $FeatureName; DISM disable will determine the result: $($_.Exception.Message)"
    }

    if ($PSCmdlet.ShouldProcess($FeatureName, 'Disable Windows optional feature')) {
        $arguments = @('/Online', '/Disable-Feature', "/FeatureName:$FeatureName", '/Quiet')
        if ($NoRestart) { $arguments += '/NoRestart' }

        Invoke-NativeDism -Arguments $arguments | Out-Null

        return [pscustomobject]@{
            FeatureName = $FeatureName
            State = 'Disabled'
            Online = $true
            RestartNeeded = $false
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

        Invoke-NativeDism -Arguments $arguments | Out-Null

        return [pscustomobject]@{
            Name = $Name
            State = 'Installed'
            Online = $true
            RestartNeeded = $false
        }
    }
}

Write-Host '[COMPAT] Windows servicing forced through native dism.exe' -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Appx compatibility
# ---------------------------------------------------------------------------
try {
    Import-Module Appx -UseWindowsPowerShell -Force -WarningAction SilentlyContinue -ErrorAction Stop
    Write-Host '[COMPAT] Appx module routed through Windows PowerShell 5.1' -ForegroundColor DarkGray
}
catch {
    Write-Warning "[COMPAT] Appx compatibility import failed. Debloat operations may be skipped: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# WMI compatibility
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# System Restore compatibility
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# WSL compatibility
# ---------------------------------------------------------------------------
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
