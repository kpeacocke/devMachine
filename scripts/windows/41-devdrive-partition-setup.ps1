<#
.SYNOPSIS
    Create and mount the DevMachine development drive.

.DESCRIPTION
    Creates ONE Windows Dev Drive on the disk containing C:.

      DevCache: 90 GB, mounted at C:\DevCache
      Code:     C:\Users\<username>\code -> C:\DevCache\code

    The Surface configuration has ~98 GB available to this purpose, so one 90 GB
    Dev Drive is used. Windows requires a minimum 50 GB Dev Drive.

    Safety properties:
      - Uses Windows' actual supported C: shrink boundary.
      - Requires enough contiguous free space for the requested volume.
      - Never shrinks C: below the reported supported minimum.
      - Never deletes or reformats an existing DevCache/DevCode volume.
      - Refuses to replace an existing non-empty code directory.
      - Uses -WhatIf via SupportsShouldProcess; no duplicate WhatIf parameter.
      - Creates a real Dev Drive using Format-Volume -DevDrive.
      - Trusts the Dev Drive so Microsoft Defender can use Performance Mode.

    This script deliberately does NOT disable Defender or add a Defender exclusion
    for the Dev Drive. Microsoft recommends trusted Dev Drives with Defender
    Performance Mode instead.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [ValidateRange(50, 500)]
    [int]$DevDriveGB = 90
)

$ErrorActionPreference = 'Stop'

$minimumDevDriveGB = 50
$devDriveMountPoint = 'C:\DevCache'
$codePath = Join-Path $env:USERPROFILE 'code'
$codeTarget = Join-Path $devDriveMountPoint 'code'

function Get-VolumeByLabel {
    param([Parameter(Mandatory)][string]$Label)

    Get-Volume -ErrorAction SilentlyContinue |
        Where-Object { $_.FileSystem -eq 'ReFS' -and $_.FileSystemLabel -eq $Label } |
        Select-Object -First 1
}

function Get-PartitionForVolume {
    param([Parameter(Mandatory)]$Volume)

    if ($Volume.DriveLetter) {
        return Get-Partition -DriveLetter $Volume.DriveLetter -ErrorAction Stop
    }

    foreach ($candidate in @(Get-Partition -ErrorAction Stop)) {
        $candidateVolume = Get-Volume -Partition $candidate -ErrorAction SilentlyContinue
        if ($candidateVolume -and
            $candidateVolume.FileSystem -eq 'ReFS' -and
            $candidateVolume.FileSystemLabel -eq $Volume.FileSystemLabel -and
            $candidateVolume.Size -eq $Volume.Size) {
            return $candidate
        }
    }

    return $null
}

function Invoke-FsUtil {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Operation
    )

    $fsutil = Join-Path $env:SystemRoot 'System32\fsutil.exe'
    if (-not (Test-Path -LiteralPath $fsutil)) {
        throw "fsutil.exe not found at $fsutil"
    }

    $output = & $fsutil @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with fsutil exit code $LASTEXITCODE.`n$(($output | Out-String).Trim())"
    }
    return $output
}

function Test-IsDevDrive {
    param([Parameter(Mandatory)][string]$Path)

    $fsutil = Join-Path $env:SystemRoot 'System32\fsutil.exe'
    $output = & $fsutil devdrv query $Path 2>&1
    if ($LASTEXITCODE -ne 0) { return $false }

    $text = ($output | Out-String)
    return $text -match '(?i)(trusted )?developer volume|developer volumes are enabled'
}

function Ensure-TrustedDevDrive {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-IsDevDrive -Path $Path)) {
        throw "$Path is not recognised as a Windows Dev Drive."
    }

    Invoke-FsUtil -Arguments @('devdrv', 'trust', $Path) -Operation "Trust Dev Drive $Path" | Out-Null
}

function Test-MountPoint {
    param([Parameter(Mandatory)][string]$Path)

    $mountvol = Join-Path $env:SystemRoot 'System32\mountvol.exe'
    if (-not (Test-Path -LiteralPath $mountvol)) { return $false }

    $output = & $mountvol $Path /L 2>&1
    return ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($output | Out-String)))
}

function Ensure-CodePath {
    if (Test-Path -LiteralPath $codePath) {
        $item = Get-Item -LiteralPath $codePath -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $target = @($item.Target) -join ';'
            if ($target -ieq $codeTarget) {
                Write-Host "   ✅ Code path already linked to $codeTarget" -ForegroundColor Green
                return
            }
            throw "$codePath is an existing reparse point with an unexpected target. Refusing to change it."
        }

        $items = @(Get-ChildItem -LiteralPath $codePath -Force -ErrorAction Stop)
        if ($items.Count -gt 0) {
            throw "$codePath already exists and contains data. Refusing to replace it with a junction."
        }

        Remove-Item -LiteralPath $codePath -Force -ErrorAction Stop
    }

    New-Item -ItemType Junction -Path $codePath -Target $codeTarget -ErrorAction Stop | Out-Null
    Write-Host "   ✅ Code path linked: $codePath → $codeTarget" -ForegroundColor Green
}

function Get-ContiguousFreeSpaceAfterC {
    param(
        [Parameter(Mandatory)]$Disk,
        [Parameter(Mandatory)]$CPartition
    )

    $partitions = @(Get-Partition -DiskNumber $Disk.Number -ErrorAction Stop | Sort-Object Offset)
    $cEnd = [uint64]$CPartition.Offset + [uint64]$CPartition.Size
    $next = $partitions |
        Where-Object { [uint64]$_.Offset -gt $cEnd } |
        Select-Object -First 1

    $boundary = if ($next) { [uint64]$next.Offset } else { [uint64]$Disk.Size }
    if ($boundary -le $cEnd) { return [uint64]0 }
    return $boundary - $cEnd
}

Write-Host "🔧 Dev Drive Setup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($DevDriveGB -lt $minimumDevDriveGB) {
    throw "Dev Drive must be at least $minimumDevDriveGB GB."
}

$requestedBytes = [uint64]$DevDriveGB * 1GB

$existingCache = Get-VolumeByLabel -Label 'DevCache'
$existingCode = Get-VolumeByLabel -Label 'DevCode'

if ($existingCode) {
    throw "A legacy DevCode volume exists ($([math]::Round($existingCode.Size / 1GB, 1)) GB). This layout now uses one Dev Drive. Remove the legacy volume explicitly before continuing."
}

if ($existingCache) {
    if ($existingCache.Size -lt ([uint64]$minimumDevDriveGB * 1GB)) {
        throw "An undersized legacy DevCache volume exists ($([math]::Round($existingCache.Size / 1GB, 1)) GB). Remove it explicitly before continuing."
    }

    $partition = Get-PartitionForVolume -Volume $existingCache
    if (-not $partition) {
        throw 'Could not safely resolve the existing DevCache partition.'
    }

    Write-Host "   Existing DevCache found: $([math]::Round($existingCache.Size / 1GB, 1)) GB" -ForegroundColor Green
    if ($PSCmdlet.ShouldProcess($devDriveMountPoint, 'Mount and trust existing DevCache')) {
        if (-not (Test-MountPoint -Path $devDriveMountPoint)) {
            if (Test-Path -LiteralPath $devDriveMountPoint) {
                $items = @(Get-ChildItem -LiteralPath $devDriveMountPoint -Force -ErrorAction Stop)
                if ($items.Count -gt 0) {
                    throw "$devDriveMountPoint exists and is not an empty mount-point directory."
                }
            }
            else {
                New-Item -ItemType Directory -Path $devDriveMountPoint -Force | Out-Null
            }

            if ($partition.DriveLetter) {
                Add-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath $devDriveMountPoint -ErrorAction Stop
            }
            else {
                Add-PartitionAccessPath -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath $devDriveMountPoint -ErrorAction Stop
            }
        }

        Ensure-TrustedDevDrive -Path $devDriveMountPoint
        New-Item -ItemType Directory -Path $codeTarget -Force | Out-Null
        Ensure-CodePath
        Write-Host "`n🎉 Existing Dev Drive configured successfully." -ForegroundColor Green
    }
    return
}

$partition = Get-Partition -DriveLetter C -ErrorAction Stop
$disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
$cVolume = Get-Volume -DriveLetter C -ErrorAction Stop

if ($disk.PartitionStyle -ne 'GPT') {
    throw "Disk $($disk.Number) is not GPT. DevMachine requires a GPT system disk."
}

if ($disk.IsReadOnly) {
    throw "Disk $($disk.Number) is read-only."
}

$supported = Get-PartitionSupportedSize -DriveLetter C -ErrorAction Stop
$maxShrinkBytes = [uint64]$partition.Size - [uint64]$supported.SizeMin
$maxShrinkGB = [math]::Floor($maxShrinkBytes / 1GB)
$existingGapBytes = Get-ContiguousFreeSpaceAfterC -Disk $disk -CPartition $partition
$spaceNeededFromC = [uint64][math]::Max([int64]0, [int64]$requestedBytes - [int64]$existingGapBytes)

$projectedCSize = [uint64]$partition.Size - $spaceNeededFromC
$projectedCFree = [uint64]$cVolume.SizeRemaining - $spaceNeededFromC
$projectedFreePercent = if ($projectedCSize -gt 0) { ($projectedCFree / $projectedCSize) * 100 } else { 0 }

Write-Host "`n📊 Dev Drive preflight" -ForegroundColor Cyan
Write-Host "   Disk:                    $($disk.Number) ($([math]::Round($disk.Size / 1GB, 1)) GB)" -ForegroundColor Gray
Write-Host "   C: size:                 $([math]::Round($partition.Size / 1GB, 1)) GB" -ForegroundColor Gray
Write-Host "   C: free:                 $([math]::Round($cVolume.SizeRemaining / 1GB, 1)) GB" -ForegroundColor Gray
Write-Host "   Contiguous free after C: $([math]::Round($existingGapBytes / 1GB, 1)) GB" -ForegroundColor Gray
Write-Host "   Requested Dev Drive:     $DevDriveGB GB" -ForegroundColor Yellow
Write-Host "   Max C: shrinkable:       $maxShrinkGB GB" -ForegroundColor Gray
Write-Host "   Required C: shrink:      $([math]::Round($spaceNeededFromC / 1GB, 1)) GB" -ForegroundColor Gray
Write-Host "   Projected C: free:       $([math]::Round($projectedFreePercent, 1))%" -ForegroundColor Gray

if ($spaceNeededFromC -gt $maxShrinkBytes) {
    throw "Cannot safely create a $DevDriveGB GB Dev Drive. Required C: shrink is $([math]::Round($spaceNeededFromC / 1GB,1)) GB but Windows permits only $maxShrinkGB GB."
}

if ($projectedFreePercent -lt 30) {
    throw "Refusing to shrink C: below 30% free space. Projected free space: $([math]::Round($projectedFreePercent,1))%."
}

if (-not $PSCmdlet.ShouldProcess("Disk $($disk.Number)", "Create a $DevDriveGB GB Dev Drive at $devDriveMountPoint")) {
    return
}

$newCSize = [uint64]$partition.Size - $spaceNeededFromC

if ($spaceNeededFromC -gt 0) {
    Write-Host "`n[1/3] Shrinking C: by $([math]::Round($spaceNeededFromC / 1GB, 1)) GB..." -ForegroundColor Yellow
    Resize-Partition -DriveLetter C -Size $newCSize -ErrorAction Stop
    Write-Host "   ✅ C: resized to $([math]::Round($newCSize / 1GB, 1)) GB" -ForegroundColor Green
}
else {
    Write-Host "`n[1/3] Existing unallocated space is sufficient; C: will not be resized." -ForegroundColor Green
}

Write-Host "`n[2/3] Creating $DevDriveGB GB Dev Drive..." -ForegroundColor Yellow
$newPartition = New-Partition -DiskNumber $disk.Number -Size $requestedBytes -AssignDriveLetter -ErrorAction Stop

if (-not $newPartition.DriveLetter) {
    throw 'Windows did not assign a temporary drive letter to the new Dev Drive.'
}

$temporaryPath = "$($newPartition.DriveLetter):\"

try {
    Format-Volume -DriveLetter $newPartition.DriveLetter -FileSystem ReFS -NewFileSystemLabel 'DevCache' -DevDrive -Confirm:$false -ErrorAction Stop | Out-Null
    Ensure-TrustedDevDrive -Path $temporaryPath

    if (-not (Test-Path -LiteralPath $devDriveMountPoint)) {
        New-Item -ItemType Directory -Path $devDriveMountPoint -Force | Out-Null
    }
    else {
        $items = @(Get-ChildItem -LiteralPath $devDriveMountPoint -Force -ErrorAction Stop)
        if ($items.Count -gt 0) {
            throw "$devDriveMountPoint exists and is not empty."
        }
    }

    Add-PartitionAccessPath -DiskNumber $newPartition.DiskNumber -PartitionNumber $newPartition.PartitionNumber -AccessPath $devDriveMountPoint -ErrorAction Stop
    Remove-PartitionAccessPath -DiskNumber $newPartition.DiskNumber -