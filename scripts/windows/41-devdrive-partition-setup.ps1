<#
.SYNOPSIS
    Create and mount a single ReFS Dev Drive for development workloads.

.DESCRIPTION
    Creates one Dev Drive on the disk containing C: when one does not already exist.

      - DevCache: 90 GB mounted at C:\DevCache
      - C:\Users\<username>\code is a directory junction to C:\DevCache\code

    A single 90 GB Dev Drive is used because this Surface has enough space for one
    useful Dev Drive but not two independent 50 GB minimum Dev Drives.

    The script never shrinks C: below Windows' reported supported minimum and never
    assumes that nominal free space is shrinkable. It calculates the actual supported
    shrink boundary before changing the partition table.

    New Dev Drives are formatted with -DevDrive and explicitly trusted. Microsoft
    Defender remains enabled and can use Dev Drive Performance Mode.

    Existing undersized legacy DevCache/DevCode volumes are never deleted automatically.
    They must be explicitly cleaned up before this script will proceed.

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
$minimumDevDriveBytes = [uint64]$minimumDevDriveGB * 1GB
$devDriveMountPoint = 'C:\DevCache'
$codePath = Join-Path $env:USERPROFILE 'code'
$codeTarget = Join-Path $devDriveMountPoint 'code'

function Get-DevCacheVolume {
    Get-Volume -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FileSystem -eq 'ReFS' -and
            $_.FileSystemLabel -eq 'DevCache'
        } |
        Select-Object -First 1
}

function Get-DevCodeVolume {
    Get-Volume -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FileSystem -eq 'ReFS' -and
            $_.FileSystemLabel -eq 'DevCode'
        } |
        Select-Object -First 1
}

function Get-PartitionForVolume {
    param([Parameter(Mandatory)]$Volume)

    if ($Volume.DriveLetter) {
        return Get-Partition -DriveLetter $Volume.DriveLetter -ErrorAction Stop
    }

    foreach ($candidate in @(Get-Partition -ErrorAction SilentlyContinue)) {
        $candidateVolume = Get-Volume -Partition $candidate -ErrorAction SilentlyContinue
        if ($candidateVolume -and
            $candidateVolume.FileSystemLabel -eq $Volume.FileSystemLabel -and
            $candidateVolume.FileSystem -eq 'ReFS' -and
            $candidateVolume.Size -eq $Volume.Size) {
            return $candidate
        }
    }

    return $null
}

function Test-DevDrive {
    param([Parameter(Mandatory)][string]$Path)

    $fsutil = Join-Path $env:SystemRoot 'System32\fsutil.exe'
    if (-not (Test-Path $fsutil)) {
        throw "fsutil.exe not found at $fsutil"
    }

    $output = & $fsutil devdrv query $Path 2>&1
    return ($LASTEXITCODE -eq 0 -and
        (($output | Out-String) -match 'developer volume|developer volumes are enabled'))
}

function Ensure-DevDriveTrusted {
    param([Parameter(Mandatory)][string]$Path)

    $fsutil = Join-Path $env:SystemRoot 'System32\fsutil.exe'
    & $fsutil devdrv trust $Path 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Could not trust Dev Drive $Path (fsutil exit code $LASTEXITCODE)"
    }
}

function Ensure-CodeJunction {
    if (Test-Path $codePath) {
        $item = Get-Item -LiteralPath $codePath -Force

        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $target = $item.Target
            if ($target -and (($target -join ';') -ieq $codeTarget)) {
                Write-Host "   ✅ Code path already linked to $codeTarget" -ForegroundColor Green
                return
            }

            throw "$codePath is an existing reparse point with an unexpected target. Refusing to modify it."
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

function Mount-DevCache {
    param([Parameter(Mandatory)]$Partition)

    if (-not (Test-Path $devDriveMountPoint)) {
        New-Item -ItemType Directory -Path $devDriveMountPoint -Force | Out-Null
    }

    $existingItems = @(Get-ChildItem -LiteralPath $devDriveMountPoint -Force -ErrorAction SilentlyContinue)
    if ($existingItems.Count -gt 0 -and -not (Test-DevDrive $devDriveMountPoint)) {
        throw "$devDriveMountPoint exists and is not an empty Dev Drive mount point."
    }

    if ($Partition.DriveLetter) {
        $drivePath = "$($Partition.DriveLetter):\"
        Ensure-DevDriveTrusted -Path $drivePath

        $mounted = Test-DevDrive $devDriveMountPoint
        if (-not $mounted) {
            Add-PartitionAccessPath `
                -DiskNumber $Partition.DiskNumber `
                -PartitionNumber $Partition.PartitionNumber `
                -AccessPath $devDriveMountPoint `
                -ErrorAction Stop
        }

        # Remove the temporary drive letter after the directory mount exists.
        Remove-PartitionAccessPath `
            -DiskNumber $Partition.DiskNumber `
            -PartitionNumber $Partition.PartitionNumber `
            -AccessPath $drivePath `
            -ErrorAction SilentlyContinue

        Ensure-DevDriveTrusted -Path $devDriveMountPoint
    }
    elseif (-not (Test-DevDrive $devDriveMountPoint)) {
        Add-PartitionAccessPath `
            -DiskNumber $Partition.DiskNumber `
            -PartitionNumber $Partition.PartitionNumber `
            -AccessPath $devDriveMountPoint `
            -ErrorAction Stop

        Ensure-DevDriveTrusted -Path $devDriveMountPoint
    }

    if (-not (Test-DevDrive $devDriveMountPoint)) {
        throw "C:\DevCache is not recognised by Windows as a Dev Drive after mounting."
    }
}

Write-Host "🔧 Dev Drive Setup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($DevDriveGB -lt $minimumDevDriveGB) {
    throw "Dev Drive must be at least $minimumDevDriveGB GB."
}

$cacheVolume = Get-DevCacheVolume
$legacyCodeVolume = Get-DevCodeVolume

if ($legacyCodeVolume) {
    $sizeGB = [math]::Round($legacyCodeVolume.Size / 1GB, 1)
    throw "Legacy DevCode volume detected ($sizeGB GB). It is not a valid Dev Drive and will not be deleted automatically. Remove it explicitly before continuing."
}

if ($cacheVolume -and $cacheVolume.Size -lt $minimumDevDriveBytes) {
    $sizeGB = [math]::Round($cacheVolume.Size / 1GB, 1)
    throw "Legacy undersized DevCache volume detected ($sizeGB GB). It is not a valid Dev Drive and will not be deleted automatically. Remove it explicitly before continuing."
}

# Existing valid Dev Drive: mount/trust it and create the code junction.
if ($cacheVolume) {
    if ($cacheVolume.Size -lt ([uint64]$DevDriveGB * 1GB)) {
        Write-Host "   Existing DevCache is $([math]::Round($cacheVolume.Size / 1GB,1)) GB; reusing it because it is a valid Dev Drive." -ForegroundColor Yellow
    } else {
        Write-Host "   Existing DevCache found: $([math]::Round($cacheVolume.Size / 1GB,1)) GB" -ForegroundColor Green
    }

    $cachePartition = Get-PartitionForVolume -Volume $cacheVolume
    if (-not $cachePartition) {
        throw "Could not safely resolve the DevCache partition."
    }

    if ($PSCmdlet.ShouldProcess($devDriveMountPoint, 'Mount and trust existing DevCache Dev Drive')) {
        Mount-DevCache -Partition $cachePartition
        New-Item -ItemType Directory -Path $codeTarget -Force | Out-Null
        Ensure-CodeJunction

        Write-Host "`n🎉 Existing Dev Drive configured successfully." -ForegroundColor Green
        exit 0
    }

    exit 0
}

$partition = Get-Partition -DriveLetter C -ErrorAction Stop
$disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
$cVolume = Get-Volume -DriveLetter C -ErrorAction Stop

$unallocatedBytes = [uint64]0
foreach ($p in @(Get-Partition -DiskNumber $disk.Number -ErrorAction Stop | Sort-Object Offset)) {
    $end = [uint64]$p.Offset + [uint64]$p.Size
    $next = @(Get-Partition -DiskNumber $disk.Number -ErrorAction Stop |
        Where-Object { [uint64]$_.Offset -gt $end } |
        Sort-Object Offset |
        Select-Object -First 1)

    if ($next.Count -eq 0) {
        $diskEnd = [uint64]$disk.Size
        if ($diskEnd -gt $end) {
            $unallocatedBytes += $diskEnd - $end
        }
    } else {
        $gap = [uint64]$next[0].Offset - $end
        if ($gap -gt 0) { $unallocatedBytes += $gap }
    }
}

$requiredBytes = [uint64]$DevDriveGB * 1GB

# Windows reports the actual supported C: shrink boundary. Use it rather than
# assuming all nominally-free C: space is movable.
$supported = Get-PartitionSupportedSize -DriveLetter C -ErrorAction Stop
$maxShrinkBytes = [uint64]$partition.Size - [uint64]$supported.SizeMin
$maxShrinkGB = [math]::Floor($maxShrinkBytes / 1GB)

$spaceNeededFromC = [math]::Max([int64]0, [int64]$requiredBytes - [int64]$unallocatedBytes)

$projectedCSize = [uint64]$partition.Size - [uint64]$spaceNeededFromC
$projectedCFree = [uint64]$cVolume.SizeRemaining - [uint64]$spaceNeededFromC

# Keep at least 30% free on C: after the shrink.
$projectedFreePercent = if ($projectedCSize -gt 0) {
    ($projectedCFree / $projectedCSize) * 100
} else { 0 }

Write-Host "`n📊 Dev Drive preflight" -ForegroundColor Cyan
Write-Host "   C: size:                 $([math]::Round($partition.Size / 1GB, 1)) GB" -ForegroundColor Gray
Write-Host "   C: free:                 $([math]::Round($cVolume.SizeRemaining / 1GB, 1)) GB" -ForegroundColor Gray
Write-Host "   Existing unallocated:   $([math]::Round($unallocatedBytes / 1GB, 1)) GB" -ForegroundColor Gray
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

if (-not $PSCmdlet.ShouldProcess("Disk $($disk.Number)", "Create a $DevDriveGB GB Dev Drive mounted at $devDriveMountPoint")) {
    exit 0
}

if ($spaceNeededFromC -gt 0) {
    Write-Host "`n[1/3] Shrinking C: by $([math]::Round($spaceNeededFromC / 1GB, 1)) GB..." -ForegroundColor Yellow
    $newCSize = [uint64]$partition.Size - [uint64]$spaceNeededFromC
    Resize-Partition -DriveLetter C -Size $newCSize -ErrorAction Stop
    Write-Host "   ✅ C: resized to $([math]::Round($newCSize / 1GB, 1)) GB" -ForegroundColor Green
}

Write-Host "`n[2/3] Creating $DevDriveGB GB Dev Drive..." -ForegroundColor Yellow
$newPartition = New-Partition `
    -DiskNumber $disk.Number `
    -Size $requiredBytes `
    -AssignDriveLetter `
    -ErrorAction Stop

if (-not $newPartition.DriveLetter) {
    throw 'Windows did not assign a temporary drive letter to the new Dev Drive.'
}

$temporaryLetter = $newPartition.DriveLetter

try {
    Format-Volume `
        -DriveLetter $temporaryLetter `
        -FileSystem ReFS `
        -NewFileSystemLabel 'DevCache' `
        -DevDrive `
        -Confirm:$false `
        -ErrorAction Stop | Out-Null

    Ensure-DevDriveTrusted -Path "$temporaryLetter`:\"

    $newPartition = Get-Partition -DriveLetter $temporaryLetter -ErrorAction Stop
    Mount-DevCache -Partition $newPartition

    New-Item -ItemType Directory -Path $codeTarget -Force | Out-Null
    Ensure-CodeJunction
}
catch {
    throw "Dev Drive creation failed: $($_.Exception.Message)"
}

Write-Host "`n[3/3] Verifying..." -ForegroundColor Cyan

$finalVolume = Get-DevCacheVolume
if (-not $finalVolume) {
    throw 'DevCache volume was not found after creation.'
}
if ($finalVolume.Size -lt $minimumDevDriveBytes) {
    throw "DevCache is below the $minimumDevDriveGB GB Dev Drive minimum."
}
if (-not (Test-DevDrive $devDriveMountPoint)) {
    throw 'C:\DevCache is not recognised as a Dev Drive.'
}
if (-not (Test-Path $codePath)) {
    throw "Code path was not created: $codePath"
}

Write-Host "   ✅ DevCache: $([math]::Round($finalVolume.Size / 1GB, 1)) GB ReFS Dev Drive" -ForegroundColor Green
Write-Host "   ✅ DevCache mount: $devDriveMountPoint" -ForegroundColor Green
Write-Host "   ✅ Code path: $codePath → $codeTarget" -ForegroundColor Green
Write-Host "   ✅ Dev Drive trusted; Defender Performance Mode can remain enabled" -ForegroundColor Green
Write-Host "`n🎉 Dev Drive setup complete." -ForegroundColor Green
