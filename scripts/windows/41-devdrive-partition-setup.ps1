<#
.SYNOPSIS
    Create and mount ReFS Dev Drive partitions for development workloads.

.DESCRIPTION
    Creates two Dev Drives on the disk containing C:, when they do not already exist:
      - DevCache: 60 GB mounted at C:\DevCache
      - DevCode:  50 GB mounted at C:\Users\<username>\code

    A Windows Dev Drive must be at least 50 GB. Existing DevCache/DevCode volumes are
    reused rather than recreated. New Dev Drives are formatted with -DevDrive and
    explicitly trusted so Microsoft Defender can use Dev Drive Performance Mode while
    keeping antivirus protection on.

    IMPORTANT: Dev Drive Performance Mode is preferred over broad Defender exclusions.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [ValidateRange(50, 500)]
    [int]$CacheGB = 60,

    [ValidateRange(50, 500)]
    [int]$CodeGB = 50
)

$ErrorActionPreference = 'Stop'

$cacheMountPoint = 'C:\DevCache'
$codeMountPoint  = Join-Path $env:USERPROFILE 'code'

function Get-DevVolumeByLabel {
    param([string]$Label)
    Get-Volume -ErrorAction SilentlyContinue |
        Where-Object { $_.FileSystem -eq 'ReFS' -and $_.FileSystemLabel -eq $Label } |
        Select-Object -First 1
}

function Get-PartitionForDevVolume {
    param($Volume)
    if (-not $Volume) { return $null }

    # Prefer the volume's drive letter when one exists.
    if ($Volume.DriveLetter) {
        return Get-Partition -DriveLetter $Volume.DriveLetter -ErrorAction SilentlyContinue
    }

    # Otherwise resolve the partition by matching the volume label. Do not rely on
    # the global $disk variable because this function is also used before $disk is set.
    foreach ($candidate in @(Get-Partition -ErrorAction SilentlyContinue)) {
        $candidateVolume = Get-Volume -Partition $candidate -ErrorAction SilentlyContinue
        if ($candidateVolume -and
            $candidateVolume.FileSystem -eq 'ReFS' -and
            $candidateVolume.FileSystemLabel -eq $Volume.FileSystemLabel) {
            return $candidate
        }
    }

    return $null
}

function Test-DevMount {
    param([string]$MountPoint)
    if (-not (Test-Path $MountPoint)) { return $false }

    try {
        $mountvol = Join-Path $env:SystemRoot 'System32\mountvol.exe'
        if (-not (Test-Path $mountvol)) { return $false }
        $output = & $mountvol $MountPoint /L 2>$null
        return ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($output | Out-String)))
    } catch {
        return $false
    }
}

function Ensure-DevDriveTrusted {
    param([string]$VolumePath)

    $fsutil = Join-Path $env:SystemRoot 'System32\fsutil.exe'
    if (-not (Test-Path $fsutil)) { throw "fsutil.exe not found at $fsutil" }

    & $fsutil devdrv trust $VolumePath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "fsutil devdrv trust failed for $VolumePath (exit code $LASTEXITCODE)"
    }
}

function Mount-DevVolume {
    param(
        [Parameter(Mandatory)]$Partition,
        [Parameter(Mandatory)][string]$MountPoint,
        [Parameter(Mandatory)][string]$Label
    )

    if (Test-DevMount $MountPoint) {
        Write-Host "   ✅ $Label already mounted at $MountPoint" -ForegroundColor Green
        return
    }

    if (Test-Path $MountPoint) {
        $items = @(Get-ChildItem -LiteralPath $MountPoint -Force -ErrorAction SilentlyContinue)
        if ($items.Count -gt 0) {
            throw "$MountPoint exists and is not empty; refusing to mount over existing data."
        }
    } else {
        New-Item -ItemType Directory -Path $MountPoint -Force | Out-Null
    }

    if ($Partition.DriveLetter) {
        $drivePath = "$($Partition.DriveLetter):\"
        Ensure-DevDriveTrusted -VolumePath $drivePath
        Remove-PartitionAccessPath -DiskNumber $Partition.DiskNumber -PartitionNumber $Partition.PartitionNumber -AccessPath $drivePath -ErrorAction Stop
    }

    Add-PartitionAccessPath -DiskNumber $Partition.DiskNumber -PartitionNumber $Partition.PartitionNumber -AccessPath $MountPoint -ErrorAction Stop
    Write-Host "   ✅ $Label mounted at $MountPoint" -ForegroundColor Green
}

function New-DevPartition {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][int]$SizeGB,
        [Parameter(Mandatory)][string]$MountPoint,
        [Parameter(Mandatory)][int]$DiskNumber
    )

    Write-Host "   Creating $Label partition ($SizeGB GB)..." -ForegroundColor Yellow
    $newPartition = New-Partition -DiskNumber $DiskNumber -Size ([uint64]$SizeGB * 1GB) -AssignDriveLetter -ErrorAction Stop
    $letter = $newPartition.DriveLetter
    if (-not $letter) { throw "New partition for $Label did not receive a drive letter." }

    try {
        Format-Volume -DriveLetter $letter -FileSystem ReFS -NewFileSystemLabel $Label -DevDrive -Confirm:$false -ErrorAction Stop | Out-Null
        Ensure-DevDriveTrusted -VolumePath "$letter`:"
        Write-Host "   ✅ $Label formatted as trusted Dev Drive" -ForegroundColor Green
        Mount-DevVolume -Partition (Get-Partition -DriveLetter $letter) -MountPoint $MountPoint -Label $Label
    } catch {
        throw "Failed creating ${Label}: $($_.Exception.Message)"
    }
}

Write-Host "🔧 Dev Drive Partition Setup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$cacheVolume = Get-DevVolumeByLabel 'DevCache'
$codeVolume  = Get-DevVolumeByLabel 'DevCode'

$partition = Get-Partition -DriveLetter C
$disk = Get-Disk -Number $partition.DiskNumber
$cVolume = Get-Volume -DriveLetter C

if ($cacheVolume) { Write-Host "   Found existing DevCache: $([math]::Round($cacheVolume.Size / 1GB, 1)) GB" -ForegroundColor Gray }
if ($codeVolume)  { Write-Host "   Found existing DevCode:  $([math]::Round($codeVolume.Size / 1GB, 1)) GB" -ForegroundColor Gray }

# Reuse existing volumes, including volumes that survived an OS reinstall but lost their mount points.
if ($cacheVolume -and $codeVolume) {
    $cachePartition = Get-PartitionForDevVolume $cacheVolume
    $codePartition = Get-PartitionForDevVolume $codeVolume
    if (-not $cachePartition -or -not $codePartition) {
        throw "Existing DevCache/DevCode volume was found but its partition could not be resolved safely."
    }

    if (-not $PSCmdlet.ShouldProcess("Existing Dev Drive volumes", "Mount DevCache and DevCode")) { exit 0 }
    Mount-DevVolume -Partition $cachePartition -MountPoint $cacheMountPoint -Label 'DevCache'
    Mount-DevVolume -Partition $codePartition -MountPoint $codeMountPoint -Label 'DevCode'
    Ensure-DevDriveTrusted -VolumePath $(if ($cachePartition.DriveLetter) { "$($cachePartition.DriveLetter):" } else { $cacheMountPoint })
    Ensure-DevDriveTrusted -VolumePath $(if ($codePartition.DriveLetter) { "$($codePartition.DriveLetter):" } else { $codeMountPoint })
    Write-Host "`n🎉 Existing Dev Drives mounted and trusted." -ForegroundColor Green
    exit 0
}

$missingCache = -not $cacheVolume
$missingCode = -not $codeVolume
$requiredGB = 0
if ($missingCache) { $requiredGB += $CacheGB }
if ($missingCode) { $requiredGB += $CodeGB }

$shrinkInfo = Get-PartitionSupportedSize -DriveLetter C
$minimumCSize = [uint64]$shrinkInfo.SizeMin
$currentCSize = [uint64]$partition.Size
$maxShrinkGB = [math]::Floor(($currentCSize - $minimumCSize) / 1GB)
$finalCSize = $currentCSize - ([uint64]$requiredGB * 1GB)
$finalFree = [uint64]$cVolume.SizeRemaining - ([uint64]$requiredGB * 1GB)
$requiredFree = [uint64]([math]::Ceiling(($finalCSize / 1GB) * 0.30) * 1GB)

Write-Host "   C: current size: $([math]::Round($currentCSize / 1GB, 1)) GB" -ForegroundColor Gray
Write-Host "   C: current free: $([math]::Round($cVolume.SizeRemaining / 1GB, 1)) GB" -ForegroundColor Gray
Write-Host "   Dev Drive space required: $requiredGB GB" -ForegroundColor Yellow
Write-Host "   Maximum shrinkable: $maxShrinkGB GB" -ForegroundColor Gray

if ($requiredGB -gt $maxShrinkGB) {
    throw "Cannot create the requested Dev Drives. Required $requiredGB GB, maximum shrinkable $maxShrinkGB GB."
}

if ($finalFree -lt $requiredFree) {
    throw "Refusing to shrink C: because projected free space would fall below 30%. Required $([math]::Round($requiredFree / 1GB, 1)) GB, projected $([math]::Round($finalFree / 1GB, 1)) GB."
}

if (-not $PSCmdlet.ShouldProcess("C: and disk $($disk.Number)", "Create $requiredGB GB of Dev Drive partitions")) {
    exit 0
}

if ($requiredGB -gt 0) {
    Write-Host "`n[1/4] Shrinking C: by $requiredGB GB..." -ForegroundColor Yellow
    Resize-Partition -DriveLetter C -Size $finalCSize
    Write-Host "   ✅ C: shrunk to $([math]::Round($finalCSize / 1GB, 1)) GB" -ForegroundColor Green
}

if ($missingCache) {
    New-DevPartition -Label 'DevCache' -SizeGB $CacheGB -MountPoint $cacheMountPoint -DiskNumber $disk.Number
}

if ($missingCode) {
    New-DevPartition -Label 'DevCode' -SizeGB $CodeGB -MountPoint $codeMountPoint -DiskNumber $disk.Number
}

Write-Host "`n[4/4] Verifying Dev Drives..." -ForegroundColor Cyan
foreach ($check in @(
    @{ Label = 'DevCache'; Path = $cacheMountPoint },
    @{ Label = 'DevCode';  Path = $codeMountPoint }
)) {
    $volume = Get-DevVolumeByLabel $check.Label
    if (-not $volume) { throw "$($check.Label) volume was not found after creation." }
    if (-not (Test-DevMount $check.Path)) { throw "$($check.Label) is not mounted at $($check.Path)." }
    Write-Host "   ✅ $($check.Label): $([math]::Round($volume.Size / 1GB, 1)) GB ReFS at $($check.Path)" -ForegroundColor Green
}

Write-Host "`n🎉 Dev Drive setup complete." -ForegroundColor Green
Write-Host "   Microsoft Defender remains enabled; trusted Dev Drives use Defender Performance Mode." -ForegroundColor Gray
