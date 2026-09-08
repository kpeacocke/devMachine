<#
.SYNOPSIS
    Create and mount the DevMachine development drive.

.DESCRIPTION
    Creates one 90 GB Windows Dev Drive on the disk containing C:, mounted at
    C:\DevCache. C:\Users\<user>\code is a junction to C:\DevCache\code.

    A Dev Drive requires at least 50 GB. The script uses Windows'
    Get-PartitionSupportedSize result and refuses to reduce C: below 30% free.
    Existing undersized DevCache/DevCode volumes are never deleted automatically.

    WhatIf is provided by SupportsShouldProcess; it is not redeclared.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [ValidateRange(50,500)]
    [int]$DevDriveGB = 90
)

$ErrorActionPreference = 'Stop'
$MinimumGB = 50
$MountPoint = 'C:\DevCache'
$CodePath = Join-Path $env:USERPROFILE 'code'
$CodeTarget = Join-Path $MountPoint 'code'
$FsUtil = Join-Path $env:SystemRoot 'System32\fsutil.exe'

# Regression contract: Test-Path C:\DevCache; Get-Volume DevCache; existing partition.

function Get-LabeledVolume {
    param([Parameter(Mandatory)][string]$Label)
    Get-Volume -ErrorAction SilentlyContinue |
        Where-Object { $_.FileSystem -eq 'ReFS' -and $_.FileSystemLabel -eq $Label } |
        Select-Object -First 1
}

function Get-VolumePartition {
    param([Parameter(Mandatory)]$Volume)
    if ($Volume.DriveLetter) { return Get-Partition -DriveLetter $Volume.DriveLetter -ErrorAction Stop }
    foreach ($p in @(Get-Partition -ErrorAction Stop)) {
        $v = Get-Volume -Partition $p -ErrorAction SilentlyContinue
        if ($v -and $v.FileSystemLabel -eq $Volume.FileSystemLabel -and $v.Size -eq $Volume.Size) { return $p }
    }
    return $null
}

function Test-DevDrive {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $FsUtil)) { throw "fsutil.exe not found: $FsUtil" }
    $output = & $FsUtil devdrv query $Path 2>&1
    return ($LASTEXITCODE -eq 0 -and (($output | Out-String) -match '(?i)developer volume'))
}

function Trust-DevDrive {
    param([Parameter(Mandatory)][string]$Path)
    $output = & $FsUtil devdrv trust $Path 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Failed to trust Dev Drive $Path (exit code $LASTEXITCODE). $($output | Out-String)" }
}

function Ensure-CodeJunction {
    if (Test-Path -LiteralPath $CodePath) {
        $item = Get-Item -LiteralPath $CodePath -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $target = (@($item.Target) -join ';')
            if ($target -ieq $CodeTarget) { return }
            throw "$CodePath is an existing reparse point with an unexpected target. Refusing to change it."
        }
        if (@(Get-ChildItem -LiteralPath $CodePath -Force -ErrorAction Stop).Count -gt 0) {
            throw "$CodePath contains data. Refusing to replace it with a junction."
        }
        Remove-Item -LiteralPath $CodePath -Force -ErrorAction Stop
    }
    New-Item -ItemType Junction -Path $CodePath -Target $CodeTarget -ErrorAction Stop | Out-Null
}

function Ensure-MountPoint {
    param([Parameter(Mandatory)]$Partition)
    if (Test-Path -LiteralPath $MountPoint) {
        if (Test-DevDrive -Path $MountPoint) { return }
        if (@(Get-ChildItem -LiteralPath $MountPoint -Force -ErrorAction Stop).Count -gt 0) {
            throw "$MountPoint exists and is not an empty mount-point directory."
        }
    } else {
        New-Item -ItemType Directory -Path $MountPoint -Force | Out-Null
    }
    Add-PartitionAccessPath -DiskNumber $Partition.DiskNumber -PartitionNumber $Partition.PartitionNumber -AccessPath $MountPoint -ErrorAction Stop
}

function Get-ContiguousFreeAfterC {
    param([Parameter(Mandatory)]$Disk,[Parameter(Mandatory)]$CPartition)
    $cEnd = [uint64]$CPartition.Offset + [uint64]$CPartition.Size
    $next = @(Get-Partition -DiskNumber $Disk.Number -ErrorAction Stop |
        Where-Object { [uint64]$_.Offset -gt $cEnd } | Sort-Object Offset | Select-Object -First 1)
    $boundary = if ($next.Count) { [uint64]$next[0].Offset } else { [uint64]$Disk.Size }
    if ($boundary -le $cEnd) { return [uint64]0 }
    return $boundary - $cEnd
}

Write-Host '🔧 Dev Drive Setup' -ForegroundColor Cyan
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Cyan

if ($DevDriveGB -lt $MinimumGB) { throw "Dev Drive must be at least $MinimumGB GB." }
if (-not (Test-Path -LiteralPath $FsUtil)) { throw "fsutil.exe not found: $FsUtil" }

$legacyCode = Get-LabeledVolume 'DevCode'
$cache = Get-LabeledVolume 'DevCache'
if ($legacyCode) { throw "Legacy DevCode volume detected ($([math]::Round($legacyCode.Size/1GB,1)) GB). Remove it explicitly before continuing." }
if ($cache -and $cache.Size -lt ([uint64]$MinimumGB * 1GB)) { throw "Undersized legacy DevCache volume detected ($([math]::Round($cache.Size/1GB,1)) GB). Remove it explicitly before continuing." }

if ($cache) {
    $p = Get-VolumePartition $cache
    if (-not $p) { throw 'Could not safely resolve the existing DevCache partition.' }
    Write-Host "   Existing DevCache: $([math]::Round($cache.Size/1GB,1)) GB" -ForegroundColor Green
    if ($PSCmdlet.ShouldProcess($MountPoint,'Mount and trust existing DevCache')) {
        Ensure-MountPoint $p
        Trust-DevDrive $MountPoint
        if (-not (Test-Path -LiteralPath $CodeTarget)) { New-Item -ItemType Directory -Path $CodeTarget -Force | Out-Null }
        Ensure-CodeJunction
        Write-Host '   ✅ Existing Dev Drive configured' -ForegroundColor Green
    }
    return
}

$c = Get-Partition -DriveLetter C -ErrorAction Stop
$disk = Get-Disk -Number $c.DiskNumber -ErrorAction Stop
$cvol = Get-Volume -DriveLetter C -ErrorAction Stop
if ($disk.PartitionStyle -ne 'GPT') { throw "Disk $($disk.Number) is not GPT." }
if ($disk.IsReadOnly) { throw "Disk $($disk.Number) is read-only." }

$supported = Get-PartitionSupportedSize -DriveLetter C -ErrorAction Stop
$maxShrink = [uint64]$c.Size - [uint64]$supported.SizeMin
$gap = Get-ContiguousFreeAfterC -Disk $disk -CPartition $c
$requested = [uint64]$DevDriveGB * 1GB
$fromC = [uint64][Math]::Max([int64]0,[int64]$requested-[int64]$gap)
$projectedCSize = [uint64]$c.Size - $fromC
$projectedCFree = [uint64]$cvol.SizeRemaining - $fromC
$projectedPct = if ($projectedCSize) { ($projectedCFree/$projectedCSize)*100 } else { 0 }

Write-Host "`n📊 Dev Drive preflight" -ForegroundColor Cyan
Write-Host "   C: size:                 $([math]::Round($c.Size/1GB,1)) GB" -ForegroundColor Gray
Write-Host "   C: free:                 $([math]::Round($cvol.SizeRemaining/1GB,1)) GB" -ForegroundColor Gray
Write-Host "   Contiguous free after C: $([math]::Round($gap/1GB,1)) GB" -ForegroundColor Gray
Write-Host "   Requested Dev Drive:     $DevDriveGB GB" -ForegroundColor Yellow
Write-Host "   Max C: shrinkable:       $([math]::Floor($maxShrink/1GB)) GB" -ForegroundColor Gray
Write-Host "   Required C: shrink:      $([math]::Round($fromC/1GB,1)) GB" -ForegroundColor Gray
Write-Host "   Projected C: free:       $([math]::Round($projectedPct,1))%" -ForegroundColor Gray

if ($fromC -gt $maxShrink) { throw "Cannot create a $DevDriveGB GB Dev Drive: required C: shrink $([math]::Round($fromC/1GB,1)) GB exceeds Windows maximum $([math]::Floor($maxShrink/1GB)) GB." }
if ($projectedPct -lt 30) { throw "Refusing to shrink C: below 30% free. Projected free: $([math]::Round($projectedPct,1))%." }
if (-not $PSCmdlet.ShouldProcess("Disk $($disk.Number)","Create $DevDriveGB GB Dev Drive at $MountPoint")) { return }

if ($fromC -gt 0) {
    Write-Host "`n[1/3] Shrinking C:..." -ForegroundColor Yellow
    Resize-Partition -DriveLetter C -Size ([uint64]$c.Size-$fromC) -ErrorAction Stop
}

Write-Host "`n[2/3] Creating Dev Drive..." -ForegroundColor Yellow
$new = New-Partition -DiskNumber $disk.Number -Size $requested -AssignDriveLetter -ErrorAction Stop
if (-not $new.DriveLetter) { throw 'New Dev Drive did not receive a temporary drive letter.' }
$temporaryPath = "$($new.DriveLetter):\"

try {
    Format-Volume -DriveLetter $new.DriveLetter -FileSystem ReFS -NewFileSystemLabel 'DevCache' -DevDrive -Confirm:$false -ErrorAction Stop | Out-Null
    Trust-DevDrive $temporaryPath
    Ensure-MountPoint (Get-Partition -DriveLetter $new.DriveLetter -ErrorAction Stop)
    Remove-PartitionAccessPath -DiskNumber $new.DiskNumber -PartitionNumber $new.PartitionNumber -AccessPath $temporaryPath -ErrorAction Stop
    Trust-DevDrive $MountPoint
    New-Item -ItemType Directory -Path $CodeTarget -Force | Out-Null
    Ensure-CodeJunction
}
catch {
    throw "Dev Drive creation failed: $($_.Exception.Message)"
}

Write-Host "`n[3/3] Verifying..." -ForegroundColor Cyan
$final = Get-LabeledVolume 'DevCache'
if (-not $final) { throw 'DevCache volume was not found after creation.' }
if ($final.Size -lt ([uint64]$MinimumGB*1GB)) { throw 'Created DevCache is below the 50 GB minimum.' }
if (-not (Test-DevDrive $MountPoint)) { throw 'C:\DevCache is not recognised as a Dev Drive.' }
if (-not (Test-Path -LiteralPath $CodePath)) { throw "Code path was not created: $CodePath" }

Write-Host "   ✅ DevCache: $([math]::Round($final.Size/1GB,1)) GB ReFS Dev Drive" -ForegroundColor Green
Write-Host "   ✅ Mount: $MountPoint" -ForegroundColor Green
Write-Host "   ✅ Code: $CodePath → $CodeTarget" -ForegroundColor Green
Write-Host '   ✅ Trusted; Defender Performance Mode remains enabled' -ForegroundColor Green
Write-Host '`n🎉 Dev Drive setup complete.' -ForegroundColor Green
