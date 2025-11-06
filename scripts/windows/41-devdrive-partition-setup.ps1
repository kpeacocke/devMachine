<#
.SYNOPSIS
    Create Dev Drive partitions on a single-drive system using mount points.

.DESCRIPTION
    This script shrinks the C: drive and creates two ReFS Dev Drive partitions:
    1. Cache partition (~50-60GB) mounted at C:\DevCache
    2. Code partition (~10GB) mounted at C:\Users\<username>\code

    Ensures 30% free space remains on C: after partitioning.

.EXAMPLE
    .\scripts\windows\41-devdrive-partition-setup.ps1
#>
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

Write-Host "🔧 Dev Drive Partition Setup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Check Windows version (Dev Drive requires Windows 11 22H2+)
$os = Get-CimInstance Win32_OperatingSystem
if ($os.BuildNumber -lt 22621) {
    Write-Host "❌ Dev Drive requires Windows 11 22H2 or later (Build 22621+)" -ForegroundColor Red
    Write-Host "   Your build: $($os.BuildNumber)" -ForegroundColor Yellow
    Write-Host "   Please update Windows or use -SkipDevDrive" -ForegroundColor Yellow
    exit 1
}

# Get C: drive information
$cDrive = Get-Volume -DriveLetter C
$partition = Get-Partition -DriveLetter C
$disk = Get-Disk -Number $partition.DiskNumber

Write-Host "`n📊 Current Disk Configuration" -ForegroundColor Yellow
Write-Host "   Disk: $($disk.FriendlyName) ($([math]::Round($disk.Size / 1GB, 2)) GB)" -ForegroundColor Gray
Write-Host "   C: Drive: $([math]::Round($cDrive.Size / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "   Used: $([math]::Round(($cDrive.Size - $cDrive.SizeRemaining) / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "   Free: $([math]::Round($cDrive.SizeRemaining / 1GB, 2)) GB" -ForegroundColor Green

# Calculate partition sizes
$totalDiskGB = [math]::Round($disk.Size / 1GB, 2)
$currentUsedGB = [math]::Round(($cDrive.Size - $cDrive.SizeRemaining) / 1GB, 2)

# Recommended sizes (adjustable)
$cachePartitionGB = 60  # For package manager caches
$codePartitionGB = 10   # For active development

# Calculate safe C: size (used space + 30% buffer + estimated growth)
$estimatedGrowthGB = 30  # Estimate for remaining setup scripts
$bufferMultiplier = 1.5  # 50% buffer on used space
$minCDriveSizeGB = [math]::Ceiling(($currentUsedGB + $estimatedGrowthGB) * $bufferMultiplier)

# Calculate total partition sizes needed
$totalPartitionsGB = $cachePartitionGB + $codePartitionGB
$targetCDriveSizeGB = [math]::Max($minCDriveSizeGB, [math]::Ceiling($totalDiskGB * 0.6))

# Ensure we have enough space
$availableForPartitionsGB = $totalDiskGB - $targetCDriveSizeGB
if ($availableForPartitionsGB -lt $totalPartitionsGB) {
    Write-Host "`n⚠️  Insufficient space for recommended Dev Drive partitions" -ForegroundColor Yellow
    Write-Host "   Total disk: $totalDiskGB GB" -ForegroundColor Gray
    Write-Host "   Required for C: (with 30% buffer): $targetCDriveSizeGB GB" -ForegroundColor Gray
    Write-Host "   Available for Dev Drives: $availableForPartitionsGB GB" -ForegroundColor Yellow
    Write-Host "   Requested Dev Drives: $totalPartitionsGB GB ($cachePartitionGB GB cache + $codePartitionGB GB code)" -ForegroundColor Gray

    # Offer reduced sizes
    $reducedCacheGB = [math]::Floor($availableForPartitionsGB * 0.8)
    $reducedCodeGB = [math]::Floor($availableForPartitionsGB * 0.2)

    if ($reducedCacheGB -lt 20) {
        Write-Host "`n❌ Not enough space to create useful Dev Drive partitions" -ForegroundColor Red
        Write-Host "   Recommendation: Use -SkipDevDrive or free up space on C:" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "`n💡 Suggested reduced sizes:" -ForegroundColor Cyan
    Write-Host "   Cache partition: $reducedCacheGB GB (reduced from $cachePartitionGB GB)" -ForegroundColor Gray
    Write-Host "   Code partition: $reducedCodeGB GB (reduced from $codePartitionGB GB)" -ForegroundColor Gray

    $useReduced = Read-Host "`nUse reduced sizes? (Y/N) [Default: Y]"
    if ([string]::IsNullOrWhiteSpace($useReduced)) { $useReduced = 'Y' }

    if ($useReduced -eq 'Y') {
        $cachePartitionGB = $reducedCacheGB
        $codePartitionGB = $reducedCodeGB
        $totalPartitionsGB = $cachePartitionGB + $codePartitionGB
    } else {
        Write-Host "❌ Setup cancelled" -ForegroundColor Red
        exit 1
    }
}

# Calculate final C: size after shrink
$finalCDriveSizeGB = $totalDiskGB - $totalPartitionsGB
$shrinkAmountGB = [math]::Round($cDrive.Size / 1GB, 2) - $finalCDriveSizeGB

Write-Host "`n📋 Proposed Partition Plan" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "   C: Drive (System)" -ForegroundColor White
Write-Host "      Current: $([math]::Round($cDrive.Size / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "      After shrink: $finalCDriveSizeGB GB" -ForegroundColor Yellow
Write-Host "      Shrink by: $shrinkAmountGB GB" -ForegroundColor Yellow
Write-Host ""
Write-Host "   Dev Drive 1: Cache Partition" -ForegroundColor White
Write-Host "      Size: $cachePartitionGB GB" -ForegroundColor Green
Write-Host "      Mount: C:\DevCache" -ForegroundColor Gray
Write-Host "      Purpose: npm, cargo, go, maven, pip, NuGet caches" -ForegroundColor Gray
Write-Host ""
Write-Host "   Dev Drive 2: Code Partition" -ForegroundColor White
Write-Host "      Size: $codePartitionGB GB" -ForegroundColor Green
Write-Host "      Mount: C:\Users\$env:USERNAME\code" -ForegroundColor Gray
Write-Host "      Purpose: Active development workspace" -ForegroundColor Gray
Write-Host ""
Write-Host "   Final State" -ForegroundColor White
Write-Host "      C: free space: ~$([math]::Round($cDrive.SizeRemaining / 1GB - $shrinkAmountGB, 2)) GB" -ForegroundColor Green
Write-Host "      Total Dev Drive space: $totalPartitionsGB GB" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "`n⚠️  WARNING: This will modify disk partitions!" -ForegroundColor Yellow
Write-Host "   • Backup important data before proceeding" -ForegroundColor Yellow
Write-Host "   • This operation cannot be easily reversed" -ForegroundColor Yellow
Write-Host "   • The process may take 10-15 minutes" -ForegroundColor Yellow

$confirm = Read-Host "`nProceed with partition creation? (Y/N) [Default: N]"
if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = 'N' }

if ($confirm -ne 'Y') {
    Write-Host "❌ Setup cancelled" -ForegroundColor Red
    Write-Host "   You can run this script again or use -SkipDevDrive" -ForegroundColor Yellow
    exit 0
}

# Check if mount points already exist
$cacheMountPoint = "C:\DevCache"
$codeMountPoint = "C:\Users\$env:USERNAME\code"

if (Test-Path $cacheMountPoint) {
    Write-Host "`n⚠️  $cacheMountPoint already exists" -ForegroundColor Yellow
    $existing = Get-Volume | Where-Object { $_.Path -eq "$cacheMountPoint\" }
    if ($existing) {
        Write-Host "   A volume is already mounted here. Skipping cache partition creation." -ForegroundColor Yellow
        $skipCachePartition = $true
    }
}

if (Test-Path $codeMountPoint) {
    Write-Host "⚠️  $codeMountPoint already exists" -ForegroundColor Yellow
    $items = Get-ChildItem $codeMountPoint -ErrorAction SilentlyContinue
    if ($items) {
        Write-Host "   Directory is not empty. Please backup and remove contents first." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`n🔧 Starting partition operations..." -ForegroundColor Cyan

# Step 1: Shrink C: drive
Write-Host "`n[1/5] Shrinking C: drive by $shrinkAmountGB GB..." -ForegroundColor Yellow
try {
    $shrinkBytes = $shrinkAmountGB * 1GB

    # Get maximum shrinkable size
    $maxShrink = (Get-PartitionSupportedSize -DriveLetter C).SizeMin
    $currentSize = $partition.Size
    $targetSize = $currentSize - $shrinkBytes

    if ($targetSize -lt $maxShrink) {
        Write-Host "   ❌ Cannot shrink C: drive to $finalCDriveSizeGB GB" -ForegroundColor Red
        Write-Host "      Minimum size: $([math]::Round($maxShrink / 1GB, 2)) GB" -ForegroundColor Yellow
        Write-Host "      You may need to disable hibernation, page file, or system restore" -ForegroundColor Yellow
        Write-Host "      Run: powercfg /h off" -ForegroundColor Gray
        exit 1
    }

    Resize-Partition -DriveLetter C -Size $targetSize
    Write-Host "   ✅ C: drive shrunk to $finalCDriveSizeGB GB" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed to shrink C: drive: $_" -ForegroundColor Red
    Write-Host "      Try running: Optimize-Volume -DriveLetter C -Defrag -Verbose" -ForegroundColor Yellow
    exit 1
}

# Step 2: Create Cache partition
if (-not $skipCachePartition) {
    Write-Host "`n[2/5] Creating Cache Dev Drive partition ($cachePartitionGB GB)..." -ForegroundColor Yellow
    try {
        $cacheSize = $cachePartitionGB * 1GB
        $cachePartition = New-Partition -DiskNumber $disk.Number -Size $cacheSize -AssignDriveLetter
        $cacheDriveLetter = $cachePartition.DriveLetter

        Write-Host "   Formatting as ReFS (Dev Drive)..." -ForegroundColor Gray
        Format-Volume -DriveLetter $cacheDriveLetter -FileSystem ReFS -NewFileSystemLabel "DevCache" -DevDrive -Confirm:$false | Out-Null

        Write-Host "   ✅ Cache partition created as $cacheDriveLetter`:" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Failed to create cache partition: $_" -ForegroundColor Red
        Write-Host "      Attempting to restore C: drive size..." -ForegroundColor Yellow
        try {
            $maxSize = (Get-PartitionSupportedSize -DriveLetter C).SizeMax
            Resize-Partition -DriveLetter C -Size $maxSize
            Write-Host "      C: drive restored" -ForegroundColor Green
        } catch {
            Write-Host "      ⚠️  Could not restore C: drive automatically" -ForegroundColor Red
        }
        exit 1
    }
} else {
    Write-Host "`n[2/5] Skipping cache partition (already exists)" -ForegroundColor Yellow
}

# Step 3: Create Code partition
Write-Host "`n[3/5] Creating Code Dev Drive partition ($codePartitionGB GB)..." -ForegroundColor Yellow
try {
    $codeSize = $codePartitionGB * 1GB
    $codePartition = New-Partition -DiskNumber $disk.Number -Size $codeSize -AssignDriveLetter
    $codeDriveLetter = $codePartition.DriveLetter

    Write-Host "   Formatting as ReFS (Dev Drive)..." -ForegroundColor Gray
    Format-Volume -DriveLetter $codeDriveLetter -FileSystem ReFS -NewFileSystemLabel "DevCode" -DevDrive -Confirm:$false | Out-Null

    Write-Host "   ✅ Code partition created as $codeDriveLetter`:" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed to create code partition: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Mount Cache partition
if (-not $skipCachePartition) {
    Write-Host "`n[4/5] Mounting cache partition at $cacheMountPoint..." -ForegroundColor Yellow
    try {
        if (-not (Test-Path $cacheMountPoint)) {
            New-Item -ItemType Directory -Path $cacheMountPoint -Force | Out-Null
        }

        # Remove drive letter and mount to folder
        Remove-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $cachePartition.PartitionNumber -AccessPath "$cacheDriveLetter`:\"
        Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $cachePartition.PartitionNumber -AccessPath "$cacheMountPoint\"

        Write-Host "   ✅ Cache partition mounted at $cacheMountPoint" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Failed to mount cache partition: $_" -ForegroundColor Red
        Write-Host "      Partition exists as $cacheDriveLetter`: but not mounted" -ForegroundColor Yellow
    }
}

# Step 5: Mount Code partition
Write-Host "`n[5/5] Mounting code partition at $codeMountPoint..." -ForegroundColor Yellow
try {
    if (-not (Test-Path $codeMountPoint)) {
        New-Item -ItemType Directory -Path $codeMountPoint -Force | Out-Null
    }

    # Remove drive letter and mount to folder
    Remove-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $codePartition.PartitionNumber -AccessPath "$codeDriveLetter`:\"
    Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $codePartition.PartitionNumber -AccessPath "$codeMountPoint\"

    Write-Host "   ✅ Code partition mounted at $codeMountPoint" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed to mount code partition: $_" -ForegroundColor Red
    Write-Host "      Partition exists as $codeDriveLetter`: but not mounted" -ForegroundColor Yellow
}

# Verify setup
Write-Host "`n📊 Final Configuration" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$cDriveAfter = Get-Volume -DriveLetter C
Write-Host "   C: Drive" -ForegroundColor White
Write-Host "      Size: $([math]::Round($cDriveAfter.Size / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "      Free: $([math]::Round($cDriveAfter.SizeRemaining / 1GB, 2)) GB" -ForegroundColor Green

if (Test-Path "$cacheMountPoint\") {
    $cacheVol = Get-Volume | Where-Object { $_.Path -eq "$cacheMountPoint\" }
    if ($cacheVol) {
        Write-Host "`n   Cache Dev Drive ($cacheMountPoint)" -ForegroundColor White
        Write-Host "      Size: $([math]::Round($cacheVol.Size / 1GB, 2)) GB" -ForegroundColor Gray
        Write-Host "      File System: $($cacheVol.FileSystem)" -ForegroundColor Gray
        Write-Host "      Free: $([math]::Round($cacheVol.SizeRemaining / 1GB, 2)) GB" -ForegroundColor Green
    }
}

if (Test-Path "$codeMountPoint\") {
    $codeVol = Get-Volume | Where-Object { $_.Path -eq "$codeMountPoint\" }
    if ($codeVol) {
        Write-Host "`n   Code Dev Drive ($codeMountPoint)" -ForegroundColor White
        Write-Host "      Size: $([math]::Round($codeVol.Size / 1GB, 2)) GB" -ForegroundColor Gray
        Write-Host "      File System: $($codeVol.FileSystem)" -ForegroundColor Gray
        Write-Host "      Free: $([math]::Round($codeVol.SizeRemaining / 1GB, 2)) GB" -ForegroundColor Green
    }
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "`n✅ Dev Drive partitions created successfully!" -ForegroundColor Green
Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Run 40-devdrive-caches.ps1 to move package caches to $cacheMountPoint" -ForegroundColor Gray
Write-Host "   2. Clone your repositories to $codeMountPoint" -ForegroundColor Gray
Write-Host "   3. Enjoy faster builds with no antivirus interference! 🚀" -ForegroundColor Gray
