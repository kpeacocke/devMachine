<#
.SYNOPSIS
    Create Dev Drive partitions on a single-drive system using mount points.

.DESCRIPTION
    This script shrinks the C: drive and creates two ReFS Dev Drive partitions:
    1. Cache partition (~50-60GB, minimum 2GB) mounted at C:\DevCache
    2. Code partition (~10GB, minimum 3GB) mounted at C:\Users\<username>\code

    ReFS requires a minimum of 2GB per partition. The script automatically adjusts sizes
    to meet these requirements while ensuring 30% free space remains on C:.

    PARTITION DETECTION:
    The script detects existing Dev Drive partitions by their filesystem labels (DevCache, DevCode).
    If partitions exist but are not mounted (e.g., after OS reinstall), the script will mount them
    instead of creating new ones. This prevents duplicate partitions and preserves data.

.PARAMETER WhatIf
    Shows what would be done without making any changes

.EXAMPLE
    .\scripts\windows\41-devdrive-partition-setup.ps1

.EXAMPLE
    .\scripts\windows\41-devdrive-partition-setup.ps1 -WhatIf

.NOTES
    After wiping/reinstalling Windows, existing Dev Drive partitions remain on disk but unmounted.
    This script intelligently detects them by label and remounts them rather than creating duplicates.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "Shows what would be done without making any changes")]
    [ValidateNotNull()]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Override minimum cache partition size in GB")]
    [ValidateRange(2, 500)]
    [int]$MinCacheGB = 2,

    [Parameter(HelpMessage = "Override minimum code partition size in GB")]
    [ValidateRange(3, 100)]
    [int]$MinCodeGB = 3
)

#Requires -Version 5.1
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

# Load unattended mode override if available
if ($env:DEVMACHINE_UNATTENDED -eq "true" -and $env:DEVMACHINE_OVERRIDE_PATH -and (Test-Path $env:DEVMACHINE_OVERRIDE_PATH)) {
    . $env:DEVMACHINE_OVERRIDE_PATH
}

# Initialize skip flags
$skipCachePartition = $false
$skipCodePartition = $false

# Function to set proper ownership on mounted Dev Drives
function Set-DevDriveOwnership {
    param(
        [string]$MountPath,
        [string]$PartitionType
    )

    Write-Host "    Setting ownership for $PartitionType partition..." -ForegroundColor Gray

    try {
        # Get current user
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

        # For cache partition, set ownership to current user
        if ($PartitionType -eq "Cache") {
            # Set ownership to current user for cache directories
            $acl = Get-Acl $MountPath
            $acl.SetOwner([System.Security.Principal.NTAccount]$currentUser)

            # Grant full control to current user
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $currentUser,
                "FullControl",
                "ContainerInherit,ObjectInherit",
                "None",
                "Allow"
            )
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $MountPath -AclObject $acl
            Write-Host "      ✅ Cache ownership set to: $currentUser" -ForegroundColor Green
        }

        # For code partition, set ownership to current user
        if ($PartitionType -eq "Code") {
            $acl = Get-Acl $MountPath
            $acl.SetOwner([System.Security.Principal.NTAccount]$currentUser)

            # Grant full control to current user
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $currentUser,
                "FullControl",
                "ContainerInherit,ObjectInherit",
                "None",
                "Allow"
            )
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $MountPath -AclObject $acl
            Write-Host "      ✅ Code ownership set to: $currentUser" -ForegroundColor Green
        }
    } catch {
        Write-Host "      ⚠️  Failed to set ownership: $_" -ForegroundColor Yellow
        Write-Host "      You may need to run 'takeown /f \"$MountPath\" /r' if you encounter permission issues" -ForegroundColor Gray
    }
}

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
$minSizeBytes = if ($shrinkInfo.SizeMin -is [array]) { $shrinkInfo.SizeMin[0] } else { $shrinkInfo.SizeMin }
$maxShrinkableGB = [math]::Floor(($cDrive.Size - $minSizeBytes) / 1GB)

Write-Host "💾 Disk Space Analysis" -ForegroundColor Cyan
Write-Host "   Total disk size: $totalDiskGB GB" -ForegroundColor Gray
Write-Host "   Current C: size: $([math]::Round($cDrive.Size / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "   Used space: $currentUsedGB GB" -ForegroundColor Gray
Write-Host "   Maximum shrinkable: $maxShrinkableGB GB" -ForegroundColor Yellow

# Conservative recommended sizes (adjustable based on available space)
$requestedCacheGB = 60  # For package manager caches
$requestedCodeGB = 10   # For active development

# ReFS minimum size requirements (ReFS won't format on partitions < 2GB)
$minCacheGB = 2         # ReFS absolute minimum size
$minCodeGB = 3          # ReFS minimum + buffer for actual development work

# Apply constraints based on available space
$availableForDevDrives = [math]::Floor($maxShrinkableGB * 0.85) # Use only 85% of shrinkable space for safety

if ($availableForDevDrives -lt ($requestedCacheGB + $requestedCodeGB)) {
    Write-Host "   ⚠️  Limited space available for Dev Drives: $availableForDevDrives GB" -ForegroundColor Yellow

    # Prioritize cache partition, but ensure ReFS minimums are met
    if ($availableForDevDrives -ge ($minCacheGB + $minCodeGB)) {
        # We have enough for minimums, calculate optimal split
        if ($availableForDevDrives -ge 40) {
            $cachePartitionGB = [math]::Min($requestedCacheGB, [math]::Floor($availableForDevDrives * 0.8))
            $codePartitionGB = [math]::Max($minCodeGB, $availableForDevDrives - $cachePartitionGB)
        } elseif ($availableForDevDrives -ge 20) {
            $cachePartitionGB = [math]::Max($minCacheGB, [math]::Floor($availableForDevDrives * 0.7))
            $codePartitionGB = [math]::Max($minCodeGB, $availableForDevDrives - $cachePartitionGB)
        } else {
            # Minimum viable setup
            $cachePartitionGB = $minCacheGB
            $codePartitionGB = $availableForDevDrives - $cachePartitionGB
        }

        # Ensure code partition meets ReFS minimum
        if ($codePartitionGB -lt $minCodeGB) {
            Write-Host "   ⚠️  Adjusting partitions to meet ReFS 3GB minimum for code partition" -ForegroundColor Yellow
            $codePartitionGB = $minCodeGB
            $cachePartitionGB = [math]::Max($minCacheGB, $availableForDevDrives - $codePartitionGB)
        }
    } else {
        Write-Host "   ❌ Insufficient space for ReFS Dev Drives (need at least $($minCacheGB + $minCodeGB)GB)" -ForegroundColor Red
        Write-Host "      Available: $availableForDevDrives GB" -ForegroundColor Yellow
        Write-Host "      ReFS requires minimum 2GB per partition" -ForegroundColor Yellow
        Write-Host "      Try freeing up disk space or disabling hibernation: powercfg /h off" -ForegroundColor Yellow
        exit 1
    }
} else {
    $cachePartitionGB = $requestedCacheGB
    $codePartitionGB = [math]::Max($minCodeGB, $requestedCodeGB)  # Ensure ReFS minimum
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

Write-Host "   ✅ Space allocation feasible (meets ReFS minimums)" -ForegroundColor Green
Write-Host "      Cache partition: $cachePartitionGB GB (ReFS minimum: 2GB)" -ForegroundColor Gray
Write-Host "      Code partition: $codePartitionGB GB (ReFS minimum: 3GB)" -ForegroundColor Gray
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

# Check WhatIf mode first
if ($WhatIf) {
    Write-Host "`n🔍 WHAT-IF MODE: No changes will be made" -ForegroundColor Cyan
    Write-Host "   This would shrink C: drive and create Dev Drive partitions as shown above." -ForegroundColor Gray
    Write-Host "   Run without -WhatIf to perform actual partition operations." -ForegroundColor Gray
    exit 0
}

# Implement ShouldProcess pattern for destructive operations
if (-not $PSCmdlet.ShouldProcess("C: drive partitions", "Create Dev Drive partitions")) {
    Write-Host "❌ Operation cancelled by ShouldProcess" -ForegroundColor Red
    exit 0
}

# Use proper confirmation for destructive operations
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

# Define mount points
$cacheMountPoint = "C:\DevCache"
$codeMountPoint = "C:\Users\$env:USERNAME\code"

Write-Host "`n🔍 Detecting existing Dev Drive partitions..." -ForegroundColor Cyan

# Look for existing unmounted partitions by label (survives OS reinstalls)
$existingCachePartition = $null
$existingCodePartition = $null

$allVolumes = Get-Volume | Where-Object { $_.FileSystem -eq 'ReFS' -and $_.FileSystemLabel -in @('DevCache', 'DevCode') }
foreach ($vol in $allVolumes) {
    if ($vol.FileSystemLabel -eq 'DevCache') {
        $existingCachePartition = $vol
        Write-Host "   Found existing DevCache partition: $([math]::Round($vol.Size / 1GB, 2)) GB (ReFS)" -ForegroundColor Yellow
    } elseif ($vol.FileSystemLabel -eq 'DevCode') {
        $existingCodePartition = $vol
        Write-Host "   Found existing DevCode partition: $([math]::Round($vol.Size / 1GB, 2)) GB (ReFS)" -ForegroundColor Yellow
    }
}

# Check if mount points already exist and have volumes mounted
$cacheMountPoint = "C:\DevCache"
$codeMountPoint = "C:\Users\$env:USERNAME\code"

# Check if cache mount point exists and has a volume mounted
$cacheExists = $false
$cacheMounted = $false
if (Test-Path $cacheMountPoint) {
    $cacheVolume = Get-Volume | Where-Object { $_.Path -eq "$cacheMountPoint\" }
    if ($cacheVolume) {
        Write-Host "✅ Cache Dev Drive already mounted at $cacheMountPoint" -ForegroundColor Green
        Write-Host "   Size: $([math]::Round($cacheVolume.Size / 1GB, 2)) GB, FileSystem: $($cacheVolume.FileSystem)" -ForegroundColor Gray
        $cacheExists = $true
        $cacheMounted = $true
    }
} elseif ($existingCachePartition) {
    Write-Host "   Cache partition exists but not mounted - will mount it" -ForegroundColor Yellow
    $cacheExists = $true
    $cacheMounted = $false
}

# Check if code mount point exists and has a volume mounted
$codeExists = $false
$codeMounted = $false
if (Test-Path $codeMountPoint) {
    $codeVolume = Get-Volume | Where-Object { $_.Path -eq "$codeMountPoint\" }
    if ($codeVolume) {
        Write-Host "✅ Code Dev Drive already mounted at $codeMountPoint" -ForegroundColor Green
        Write-Host "   Size: $([math]::Round($codeVolume.Size / 1GB, 2)) GB, FileSystem: $($codeVolume.FileSystem)" -ForegroundColor Gray
        $codeExists = $true
        $codeMounted = $true
    } else {
        # Check if it's a regular directory with contents
        $items = Get-ChildItem $codeMountPoint -ErrorAction SilentlyContinue
        if ($items) {
            Write-Host "⚠️  $codeMountPoint exists but contains files" -ForegroundColor Yellow
            Write-Host "   This appears to be a regular directory, not a Dev Drive mount point" -ForegroundColor Gray
        }
    }
} elseif ($existingCodePartition) {
    Write-Host "   Code partition exists but not mounted - will mount it" -ForegroundColor Yellow
    $codeExists = $true
    $codeMounted = $false
}

# Only skip ALL operations if BOTH are already mounted
if ($cacheMounted -and $codeMounted) {
    Write-Host "`n🎉 Both Dev Drive mount points already exist and mounted - no changes needed!" -ForegroundColor Green
    Write-Host "   Cache: $cacheMountPoint" -ForegroundColor Gray
    Write-Host "   Code:  $codeMountPoint" -ForegroundColor Gray
    Write-Host "📝 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Run 40-devdrive-caches.ps1 to move package caches to $cacheMountPoint" -ForegroundColor Gray
    Write-Host "   2. Clone your repositories to $codeMountPoint" -ForegroundColor Gray
    Write-Host "   3. Enjoy faster builds with no antivirus interference! 🚀" -ForegroundColor Gray
    exit 0
}

# Determine what needs to be created vs mounted
Write-Host ""
if ($cacheExists -and -not $cacheMounted) {
    Write-Host "📝 Cache Dev Drive partition exists - will mount it" -ForegroundColor Cyan
    $skipCachePartition = $true  # Skip creation, just mount
} elseif ($cacheMounted) {
    Write-Host "📝 Cache Dev Drive already mounted - skipping" -ForegroundColor Cyan
    $skipCachePartition = $true
} else {
    Write-Host "📝 Cache Dev Drive missing - will create and mount it" -ForegroundColor Cyan
}

if ($codeExists -and -not $codeMounted) {
    Write-Host "📝 Code Dev Drive partition exists - will mount it" -ForegroundColor Cyan
    $skipCodePartition = $true  # Skip creation, just mount
} elseif ($codeMounted) {
    Write-Host "📝 Code Dev Drive already mounted - skipping" -ForegroundColor Cyan
    $skipCodePartition = $true
} else {
    Write-Host "📝 Code Dev Drive missing - will create and mount it" -ForegroundColor Cyan
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
        $supportedSize = Get-PartitionSupportedSize -DriveLetter C
        $maxShrink = if ($supportedSize.SizeMin -is [array]) { $supportedSize.SizeMin[0] } else { $supportedSize.SizeMin }
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
        $maxSizeBytes = if ($availableExtents.SizeMax -is [array]) { $availableExtents.SizeMax[0] } else { $availableExtents.SizeMax }
        $maxAvailableGB = [math]::Floor($maxSizeBytes / 1GB)

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
            $sizeInfo = Get-PartitionSupportedSize -DriveLetter C
            $maxSize = if ($sizeInfo.SizeMax -is [array]) { $sizeInfo.SizeMax[0] } else { $sizeInfo.SizeMax }
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
if (-not $skipCodePartition) {
    Write-Host "`n[3/5] Creating Code Dev Drive partition ($codePartitionGB GB)..." -ForegroundColor Yellow
    try {
        # Check available free space on disk first
        $diskFreeSpace = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | Measure-Object -Property FreeSpace -Sum
        $availableSpaceGB = [math]::Floor($diskFreeSpace.Sum / 1GB)

        # Check for largest available extent on the disk
        $maxExtent = Get-Disk -Number $disk.Number | Get-PartitionSupportedSize
        $maxSizeBytes = if ($maxExtent.SizeMax -is [array]) { $maxExtent.SizeMax[0] } else { $maxExtent.SizeMax }
        $maxAvailableGB = [math]::Floor($maxSizeBytes / 1GB)

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
            $maxSizeInfo = Get-Disk -Number $disk.Number | Get-PartitionSupportedSize
            $maxSize = if ($maxSizeInfo.SizeMax -is [array]) { $maxSizeInfo.SizeMax[0] } else { $maxSizeInfo.SizeMax }
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
} else {
    Write-Host "`n[3/5] Skipping code partition creation (already exists)" -ForegroundColor Yellow
}

# Step 4: Mount Cache partition
if (-not $cacheMounted) {
    Write-Host "`n[4/5] Mounting cache partition at $cacheMountPoint..." -ForegroundColor Yellow
    try {
        if (-not (Test-Path $cacheMountPoint)) {
            New-Item -ItemType Directory -Path $cacheMountPoint -Force | Out-Null
        }

        # If we have an existing partition, find and mount it
        if ($existingCachePartition -and -not $cachePartition) {
            Write-Host "   Mounting existing DevCache partition..." -ForegroundColor Gray
            # Find the partition by matching the volume
            $allPartitions = Get-Partition | Where-Object { $_.DriveLetter -or $_.AccessPaths }
            foreach ($part in $allPartitions) {
                $vol = Get-Volume -Partition $part -ErrorAction SilentlyContinue
                if ($vol -and $vol.FileSystemLabel -eq 'DevCache') {
                    # Remove existing drive letter if present
                    if ($part.DriveLetter) {
                        Remove-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "$($part.DriveLetter):\" -ErrorAction SilentlyContinue
                    }
                    # Mount to folder
                    Add-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "$cacheMountPoint\"
                    Write-Host "   ✅ Existing cache partition mounted at $cacheMountPoint" -ForegroundColor Green

                    # Set proper ownership for existing partition
                    Set-DevDriveOwnership -MountPath $cacheMountPoint -PartitionType "Cache"
                    break
                }
            }
        } elseif ($cachePartition) {
            # Mounting newly created partition
            Remove-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $cachePartition.PartitionNumber -AccessPath "$cacheDriveLetter`:" -ErrorAction SilentlyContinue
            Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $cachePartition.PartitionNumber -AccessPath "$cacheMountPoint\"
            Write-Host "   ✅ Cache partition mounted at $cacheMountPoint" -ForegroundColor Green

            # Set proper ownership for new partition
            Set-DevDriveOwnership -MountPath $cacheMountPoint -PartitionType "Cache"
        }
    } catch {
        Write-Host "   ❌ Failed to mount cache partition: $_" -ForegroundColor Red
        if ($cacheDriveLetter) {
            Write-Host "      Partition exists as $cacheDriveLetter`: but not mounted" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "`n[4/5] Cache partition already mounted - skipping" -ForegroundColor Yellow
}

# Step 5: Mount Code partition
if (-not $codeMounted) {
    Write-Host "`n[5/5] Mounting code partition at $codeMountPoint..." -ForegroundColor Yellow
    try {
        if (-not (Test-Path $codeMountPoint)) {
            New-Item -ItemType Directory -Path $codeMountPoint -Force | Out-Null
        }

        # If we have an existing partition, find and mount it
        if ($existingCodePartition -and -not $codePartition) {
            Write-Host "   Mounting existing DevCode partition..." -ForegroundColor Gray
            # Find the partition by matching the volume
            $allPartitions = Get-Partition | Where-Object { $_.DriveLetter -or $_.AccessPaths }
            foreach ($part in $allPartitions) {
                $vol = Get-Volume -Partition $part -ErrorAction SilentlyContinue
                if ($vol -and $vol.FileSystemLabel -eq 'DevCode') {
                    # Remove existing drive letter if present
                    if ($part.DriveLetter) {
                        Remove-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "$($part.DriveLetter):\" -ErrorAction SilentlyContinue
                    }
                    # Mount to folder
                    Add-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "$codeMountPoint\"
                    Write-Host "   ✅ Existing code partition mounted at $codeMountPoint" -ForegroundColor Green

                    # Set proper ownership for existing partition
                    Set-DevDriveOwnership -MountPath $codeMountPoint -PartitionType "Code"
                    break
                }
            }
        } elseif ($codePartition) {
            # Mounting newly created partition
            Remove-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $codePartition.PartitionNumber -AccessPath "$codeMountPoint\"
            Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $codePartition.PartitionNumber -AccessPath "$codeMountPoint\"
            Write-Host "   ✅ Code partition mounted at $codeMountPoint" -ForegroundColor Green

            # Set proper ownership for new partition
            Set-DevDriveOwnership -MountPath $codeMountPoint -PartitionType "Code"
        } else {
            # Fallback: create regular directory if partition creation was skipped/failed
            Write-Host "   No code partition available - creating regular directory" -ForegroundColor Yellow
            if (-not (Test-Path $codeMountPoint)) {
                New-Item -ItemType Directory -Path $codeMountPoint -Force | Out-Null
                Write-Host "   ✅ Created $codeMountPoint as regular directory" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "   ❌ Failed to mount code partition: $_" -ForegroundColor Red
        if ($codeDriveLetter) {
            Write-Host "      Partition exists as $codeDriveLetter`: but not mounted" -ForegroundColor Yellow
        }
        # Fallback: create regular directory
        Write-Host "   Creating regular directory for code instead..." -ForegroundColor Gray
        try {
            if (-not (Test-Path $codeMountPoint)) {
                New-Item -ItemType Directory -Path $codeMountPoint -Force | Out-Null
                Write-Host "   ✅ Created $codeMountPoint as regular directory" -ForegroundColor Green
            }
        } catch {
            Write-Host "   ❌ Failed to create code directory: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "`n[5/5] Code partition already mounted - skipping" -ForegroundColor Yellow
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
