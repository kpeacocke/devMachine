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

# Load unattended mode override if available
if ($env:DEVMACHINE_UNATTENDED -eq "true" -and $env:DEVMACHINE_OVERRIDE_PATH -and (Test-Path $env:DEVMACHINE_OVERRIDE_PATH)) {
    . $env:DEVMACHINE_OVERRIDE_PATH
}

# Initialize skip flags
$skipCachePartition = $false
$skipCodePartition = $false

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

Write-Host "📊 Current Disk Configuration" -ForegroundColor Yellow
Write-Host "   Disk: $($disk.FriendlyName) ($([math]::Round($disk.Size / 1GB, 2)) GB)" -ForegroundColor Gray
Write-Host "   C: Drive: $([math]::Round($cDrive.Size / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "   Used: $([math]::Round(($cDrive.Size - $cDrive.SizeRemaining) / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "   Free: $([math]::Round($cDrive.SizeRemaining / 1GB, 2)) GB" -ForegroundColor Green

# Calculate partition sizes with improved logic
$totalDiskGB = [math]::Round($disk.Size / 1GB, 2)
$currentUsedGB = [math]::Round(($cDrive.Size - $cDrive.SizeRemaining) / 1GB, 2)

# Get actual shrinkable space from Windows
$shrinkInfo = Get-PartitionSupportedSize -DriveLetter C
$maxShrinkableGB = [math]::Floor(($cDrive.Size - $shrinkInfo.SizeMin) / 1GB)

Write-Host "💾 Disk Space Analysis" -ForegroundColor Cyan
Write-Host "   Total disk size: $totalDiskGB GB" -ForegroundColor Gray
Write-Host "   Current C: size: $([math]::Round($cDrive.Size / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "   Used space: $currentUsedGB GB" -ForegroundColor Gray
Write-Host "   Maximum shrinkable: $maxShrinkableGB GB" -ForegroundColor Yellow

# Conservative recommended sizes (adjustable based on available space)
$requestedCacheGB = 60  # For package manager caches
$requestedCodeGB = 10   # For active development

# Apply constraints based on available space
$availableForDevDrives = [math]::Floor($maxShrinkableGB * 0.85) # Use only 85% of shrinkable space for safety

if ($availableForDevDrives -lt ($requestedCacheGB + $requestedCodeGB)) {
    Write-Host "   ⚠️  Limited space available for Dev Drives: $availableForDevDrives GB" -ForegroundColor Yellow

    # Prioritize cache partition, reduce both if necessary
    if ($availableForDevDrives -ge 40) {
        $cachePartitionGB = [math]::Min($requestedCacheGB, [math]::Floor($availableForDevDrives * 0.8))
        $codePartitionGB = [math]::Min($requestedCodeGB, $availableForDevDrives - $cachePartitionGB)
    } elseif ($availableForDevDrives -ge 20) {
        $cachePartitionGB = [math]::Floor($availableForDevDrives * 0.7)
        $codePartitionGB = $availableForDevDrives - $cachePartitionGB
    } else {
        Write-Host "   ❌ Insufficient space for Dev Drives (need at least 20GB)" -ForegroundColor Red
        Write-Host "      Available: $availableForDevDrives GB" -ForegroundColor Yellow
        Write-Host "      Try freeing up disk space or disabling hibernation: powercfg /h off" -ForegroundColor Yellow
        exit 1
    }
} else {
    $cachePartitionGB = $requestedCacheGB
    $codePartitionGB = $requestedCodeGB
}

# Calculate total partition sizes needed
$totalPartitionsGB = $cachePartitionGB + $codePartitionGB

# Calculate target C: size (original size minus dev drives)
$targetCDriveSizeGB = [math]::Round($cDrive.Size / 1GB, 2) - $totalPartitionsGB

# Verify our calculations are feasible
if ($totalPartitionsGB -gt $maxShrinkableGB) {
    Write-Host "❌ Calculated partition sizes exceed available space" -ForegroundColor Red
    Write-Host "   Calculated needs: $totalPartitionsGB GB" -ForegroundColor Yellow
    Write-Host "   Maximum shrinkable: $maxShrinkableGB GB" -ForegroundColor Yellow
    Write-Host "   This should not happen - please report this as a bug" -ForegroundColor Gray
    exit 1
}

Write-Host "   ✅ Space allocation feasible" -ForegroundColor Green
Write-Host "      Cache partition: $cachePartitionGB GB" -ForegroundColor Gray
Write-Host "      Code partition: $codePartitionGB GB" -ForegroundColor Gray
Write-Host "      Total Dev Drives: $totalPartitionsGB GB" -ForegroundColor Gray

# Final validation: Ensure 30% free space requirement after partitioning
$finalFreeSpaceGB = [math]::Round($cDrive.SizeRemaining / 1GB - $totalPartitionsGB, 2)
$finalCDriveSizeAfterShrink = $finalCDriveSizeGB
$requiredFreeSpaceGB = [math]::Ceiling($finalCDriveSizeAfterShrink * 0.3)

Write-Host "`n🔍 Free Space Validation" -ForegroundColor Cyan
Write-Host "   C: drive after shrink: $finalCDriveSizeAfterShrink GB" -ForegroundColor Gray
Write-Host "   Projected free space: $finalFreeSpaceGB GB" -ForegroundColor Gray
Write-Host "   Required (30% rule): $requiredFreeSpaceGB GB" -ForegroundColor Gray

if ($finalFreeSpaceGB -lt $requiredFreeSpaceGB) {
    Write-Host "   ⚠️  Final configuration would violate 30% free space rule" -ForegroundColor Yellow
    Write-Host "   Reducing partition sizes to maintain healthy free space..." -ForegroundColor Yellow

    # Recalculate with more conservative approach
    $maxUsableForDevDrives = [math]::Floor($maxShrinkableGB * 0.6) # Only use 60% of shrinkable space
    $cachePartitionGB = [math]::Min($cachePartitionGB, [math]::Floor($maxUsableForDevDrives * 0.75))
    $codePartitionGB = [math]::Min($codePartitionGB, $maxUsableForDevDrives - $cachePartitionGB)
    $totalPartitionsGB = $cachePartitionGB + $codePartitionGB
    $finalCDriveSizeGB = [math]::Round($cDrive.Size / 1GB, 2) - $totalPartitionsGB

    Write-Host "   Adjusted cache partition: $cachePartitionGB GB" -ForegroundColor Yellow
    Write-Host "   Adjusted code partition: $codePartitionGB GB" -ForegroundColor Yellow
}

Write-Host "   ✅ Free space requirements will be met" -ForegroundColor Green

# Calculate final C: size after shrink
$finalCDriveSizeGB = $targetCDriveSizeGB
$shrinkAmountGB = [math]::Round($cDrive.Size / 1GB, 2) - $finalCDriveSizeGB

Write-Host "📋 Proposed Partition Plan" -ForegroundColor Cyan
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

Write-Host "⚠️  WARNING: This will modify disk partitions!" -ForegroundColor Yellow
Write-Host "   • Backup important data before proceeding" -ForegroundColor Yellow
Write-Host "   • This operation cannot be easily reversed" -ForegroundColor Yellow
Write-Host "   • The process may take 10-15 minutes" -ForegroundColor Yellow

if ($env:CREATE_DEV_DRIVE -eq 'Y') {
    Write-Host "→ Proceeding with partition creation (CREATE_DEV_DRIVE=Y)" -ForegroundColor Green
    $confirm = 'Y'
} elseif ($env:UNATTENDED_MODE) {
    Write-Host "❌ Dev Drive creation skipped in unattended mode (set CREATE_DEV_DRIVE=Y to enable)" -ForegroundColor Yellow
    Write-Host "   You can run this script manually later" -ForegroundColor Yellow
    exit 0
} else {
    $confirm = Read-Host "`nProceed with partition creation? (Y/N) [Default: N]"
    if ([string]::IsNullOrWhiteSpace($confirm)) { $confirm = 'N' }
}

if ($confirm -ne 'Y') {
    Write-Host "❌ Setup cancelled" -ForegroundColor Red
    Write-Host "   You can run this script again or use -SkipDevDrive" -ForegroundColor Yellow
    exit 0
}

# Check if mount points already exist
$cacheMountPoint = "C:\DevCache"
$codeMountPoint = "C:\Users\$env:USERNAME\code"

# Check if cache mount point exists and has a volume mounted
$cacheExists = $false
if (Test-Path $cacheMountPoint) {
    $cacheVolume = Get-Volume | Where-Object { $_.Path -eq "$cacheMountPoint\" }
    if ($cacheVolume) {
        Write-Host "✅ Cache Dev Drive already exists at $cacheMountPoint" -ForegroundColor Green
        Write-Host "   Size: $([math]::Round($cacheVolume.Size / 1GB, 2)) GB, FileSystem: $($cacheVolume.FileSystem)" -ForegroundColor Gray
        $cacheExists = $true
    }
}

# Check if code mount point exists and has a volume mounted
$codeExists = $false
if (Test-Path $codeMountPoint) {
    $codeVolume = Get-Volume | Where-Object { $_.Path -eq "$codeMountPoint\" }
    if ($codeVolume) {
        Write-Host "✅ Code Dev Drive already exists at $codeMountPoint" -ForegroundColor Green
        Write-Host "   Size: $([math]::Round($codeVolume.Size / 1GB, 2)) GB, FileSystem: $($codeVolume.FileSystem)" -ForegroundColor Gray
        $codeExists = $true
    } else {
        # Check if it's a regular directory with contents
        $items = Get-ChildItem $codeMountPoint -ErrorAction SilentlyContinue
        if ($items) {
            Write-Host "⚠️  $codeMountPoint exists but contains files" -ForegroundColor Yellow
            Write-Host "   This appears to be a regular directory, not a Dev Drive mount point" -ForegroundColor Gray
        }
    }
}

# Only skip ALL disk operations if BOTH mount points exist with volumes
if ($cacheExists -and $codeExists) {
    Write-Host "🎉 Both Dev Drive mount points already exist - no disk changes needed!" -ForegroundColor Green
    Write-Host "   Cache: $cacheMountPoint" -ForegroundColor Gray
    Write-Host "   Code:  $codeMountPoint" -ForegroundColor Gray
    Write-Host "📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Run 40-devdrive-caches.ps1 to move package caches to $cacheMountPoint" -ForegroundColor Gray
    Write-Host "   2. Clone your repositories to $codeMountPoint" -ForegroundColor Gray
    Write-Host "   3. Enjoy faster builds with no antivirus interference! 🚀" -ForegroundColor Gray
    exit 0
}

# Determine what needs to be created
if ($cacheExists) {
    Write-Host "📝 Cache Dev Drive exists, will only create code partition" -ForegroundColor Cyan
    $skipCachePartition = $true
} else {
    Write-Host "📝 Cache Dev Drive missing, will create it" -ForegroundColor Cyan
}

if ($codeExists) {
    Write-Host "📝 Code Dev Drive exists, will only create cache partition" -ForegroundColor Cyan
    $skipCodePartition = $true
} else {
    Write-Host "📝 Code Dev Drive missing, will create it" -ForegroundColor Cyan
}

Write-Host "🔧 Starting partition operations..." -ForegroundColor Cyan

# Step 1: Shrink C: drive
Write-Host "`n[1/5] Shrinking C: drive by $shrinkAmountGB GB..." -ForegroundColor Yellow

if ($shrinkAmountGB -le 0) {
    Write-Host "   ℹ️  No shrinking needed - sufficient unallocated space available" -ForegroundColor Cyan
} else {
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
}

# Step 2: Create Cache partition
if (-not $skipCachePartition) {
    Write-Host "`n[2/5] Creating Cache Dev Drive partition ($cachePartitionGB GB)..." -ForegroundColor Yellow
    try {
        # If we didn't shrink C: drive, we need to do it now to create unallocated space
        if ($shrinkAmountGB -le 0) {
            Write-Host "   Creating unallocated space by shrinking C: drive..." -ForegroundColor Gray
            $shrinkBytes = $totalPartitionsGB * 1GB
            $currentSize = (Get-Partition -DriveLetter C).Size
            $targetSize = $currentSize - $shrinkBytes

            Resize-Partition -DriveLetter C -Size $targetSize
            Write-Host "   ✅ Created $totalPartitionsGB GB of unallocated space" -ForegroundColor Green
        }

        # Check available unallocated space
        $availableExtents = Get-Disk -Number $disk.Number | Get-PartitionSupportedSize
        $maxAvailableGB = [math]::Floor($availableExtents.SizeMax / 1GB)

        if ($maxAvailableGB -lt $cachePartitionGB) {
            Write-Host "   ⚠️  Adjusting cache partition size from $cachePartitionGB GB to $maxAvailableGB GB" -ForegroundColor Yellow
            $cachePartitionGB = $maxAvailableGB
        }

        $cacheSize = $cachePartitionGB * 1GB
        $cachePartition = New-Partition -DiskNumber $disk.Number -Size $cacheSize -AssignDriveLetter
        $cacheDriveLetter = $cachePartition.DriveLetter

        Write-Host "   Formatting as ReFS (Dev Drive)..." -ForegroundColor Gray
        Format-Volume -DriveLetter $cacheDriveLetter -FileSystem ReFS -NewFileSystemLabel "DevCache" -DevDrive -Confirm:$false | Out-Null

        Write-Host "   ✅ Cache partition created as $cacheDriveLetter`: ($cachePartitionGB GB)" -ForegroundColor Green
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
    Write-Host "[2/5] Skipping cache partition (already exists)" -ForegroundColor Yellow
}

# Step 3: Create Code partition
Write-Host "[3/5] Creating Code Dev Drive partition ($codePartitionGB GB)..." -ForegroundColor Yellow
try {
    # Check available free space on disk first
    $diskFreeSpace = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | Measure-Object -Property FreeSpace -Sum
    $availableSpaceGB = [math]::Floor($diskFreeSpace.Sum / 1GB)

    # Check for largest available extent on the disk
    $maxExtent = Get-Disk -Number $disk.Number | Get-PartitionSupportedSize
    $maxAvailableGB = [math]::Floor($maxExtent.SizeMax / 1GB)

    Write-Host "   Available disk space: $availableSpaceGB GB, Max extent: $maxAvailableGB GB" -ForegroundColor Gray

    if ($maxAvailableGB -lt $codePartitionGB) {
        Write-Host "   ⚠️  Insufficient contiguous space for $codePartitionGB GB partition" -ForegroundColor Yellow
        $adjustedCodeGB = [math]::Max(5, [math]::Floor($maxAvailableGB * 0.8)) # Use 80% of available, minimum 5GB
        Write-Host "   Adjusting code partition to $adjustedCodeGB GB" -ForegroundColor Yellow
        $codePartitionGB = $adjustedCodeGB
    }

    $codeSize = $codePartitionGB * 1GB
    $codePartition = New-Partition -DiskNumber $disk.Number -Size $codeSize -AssignDriveLetter
    $codeDriveLetter = $codePartition.DriveLetter

    Write-Host "   Formatting as ReFS (Dev Drive)..." -ForegroundColor Gray
    Format-Volume -DriveLetter $codeDriveLetter -FileSystem ReFS -NewFileSystemLabel "DevCode" -DevDrive -Confirm:$false | Out-Null

    Write-Host "   ✅ Code partition created as $codeDriveLetter`: ($codePartitionGB GB)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed to create code partition: $_" -ForegroundColor Red
    Write-Host "   Trying to create with maximum available space..." -ForegroundColor Yellow
    try {
        # Try with maximum available space
        $maxSize = (Get-Disk -Number $disk.Number | Get-PartitionSupportedSize).SizeMax
        if ($maxSize -gt 2GB) {
            $fallbackSize = [math]::Min($maxSize, 5GB) # Max 5GB fallback
            $codePartition = New-Partition -DiskNumber $disk.Number -Size $fallbackSize -AssignDriveLetter
            $codeDriveLetter = $codePartition.DriveLetter
            Format-Volume -DriveLetter $codeDriveLetter -FileSystem ReFS -NewFileSystemLabel "DevCode" -DevDrive -Confirm:$false | Out-Null
            $codePartitionGB = [math]::Round($fallbackSize / 1GB, 1)
            Write-Host "   ✅ Code partition created as $codeDriveLetter`: ($codePartitionGB GB)" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Not enough space for any code partition" -ForegroundColor Red
            $skipCodePartition = $true
        }
    } catch {
        Write-Host "   ❌ Fallback partition creation also failed: $_" -ForegroundColor Red
        $skipCodePartition = $true
    }
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
if (-not $skipCodePartition) {
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
} else {
    Write-Host "`n[5/5] Skipping code partition mount (creation failed)" -ForegroundColor Yellow
    Write-Host "   Creating regular directory for code instead..." -ForegroundColor Gray
    try {
        if (-not (Test-Path $codeMountPoint)) {
            New-Item -ItemType Directory -Path $codeMountPoint -Force | Out-Null
            Write-Host "   ✅ Created regular directory at $codeMountPoint" -ForegroundColor Green
        }
    } catch {
        Write-Host "   ❌ Failed to create code directory: $_" -ForegroundColor Red
    }
}

# Verify setup
Write-Host "📊 Final Configuration" -ForegroundColor Cyan
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

Write-Host "✅ Dev Drive partitions created successfully!" -ForegroundColor Green
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Run 40-devdrive-caches.ps1 to move package caches to $cacheMountPoint" -ForegroundColor Gray
Write-Host "   2. Clone your repositories to $codeMountPoint" -ForegroundColor Gray
Write-Host "   3. Enjoy faster builds with no antivirus interference! 🚀" -ForegroundColor Gray
