<#
.SYNOPSIS
    Fix file ownership on existing Dev Drive partitions.

.DESCRIPTION
    This script fixes ownership issues that can occur when existing Dev Drive partitions
    are mounted after OS reinstalls or when created by different users. It sets the
    current user as the owner of the Dev Drive mount points and grants full control.

.PARAMETER CachePath
    Path to the cache Dev Drive (default: C:\DevCache)

.PARAMETER CodePath
    Path to the code Dev Drive (default: %USERPROFILE%\code)

.PARAMETER Force
    Force ownership fix even if access appears to work

.EXAMPLE
    .\scripts\windows\42-devdrive-fix-ownership.ps1

.EXAMPLE
    .\scripts\windows\42-devdrive-fix-ownership.ps1 -Force

.NOTES
    This script requires Administrator privileges to modify ownership.
    Run this if you see permission errors when using Dev Drives.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "Path to the cache Dev Drive")]
    [ValidateNotNullOrEmpty()]
    [string]$CachePath = "C:\DevCache",

    [Parameter(HelpMessage = "Path to the code Dev Drive")]
    [ValidateNotNullOrEmpty()]
    [string]$CodePath = (Join-Path $env:USERPROFILE "code"),

    [Parameter(HelpMessage = "Force ownership fix even if access appears to work")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Get current user information
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$currentUserSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
Write-Host "🔧 Dev Drive Ownership Fix" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Current user: $currentUser (SID: $currentUserSid)" -ForegroundColor Gray

function Set-OwnershipRecursive {
    param(
        [string]$Path,
        [string]$UserName
    )

    Write-Host "   Setting ownership recursively to $UserName..." -ForegroundColor Gray
    try {
        # Set ownership on root
        $acl = Get-Acl $Path
        $acl.SetOwner([System.Security.Principal.NTAccount]$UserName)
        Set-Acl -Path $Path -AclObject $acl

        # Recursively set ownership on all subitems
        Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $itemAcl = Get-Acl $_.FullName
                $itemAcl.SetOwner([System.Security.Principal.NTAccount]$UserName)
                Set-Acl -Path $_.FullName -AclObject $itemAcl
            } catch {
                Write-Host "   ⚠️  Failed to set ownership on $($_.FullName): $_" -ForegroundColor Yellow
            }
        }
        Write-Host "   ✅ Ownership set recursively" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Failed to set recursive ownership: $_" -ForegroundColor Red
        throw
    }
}

# Validate paths exist and are accessible
function Test-DevDrivePath {
    param(
        [string]$Path,
        [string]$Name
    )

    if (-not (Test-Path $Path)) {
        Write-Host "⚠️  $Name Dev Drive not found at $Path" -ForegroundColor Yellow
        return $false
    }

    # Check if this is actually a Dev Drive (ReFS)
    try {
        # For mount points, get the volume GUID first, then get volume info
        $mountvolOutput = & mountvol $Path /L 2>&1
        if ($LASTEXITCODE -eq 0 -and $mountvolOutput) {
            $volumeGuid = $mountvolOutput.Trim()
            $volume = Get-Volume -UniqueId $volumeGuid
            if ($volume.FileSystem -ne "ReFS") {
                Write-Host "⚠️  $Path is not a ReFS Dev Drive (FileSystem: $($volume.FileSystem))" -ForegroundColor Yellow
                return $false
            }
        } else {
            # Fallback: try Get-Volume -Path (may not work on older Windows versions)
            try {
                $volume = Get-Volume -Path $Path
                if ($volume.FileSystem -ne "ReFS") {
                    Write-Host "⚠️  $Path is not a ReFS Dev Drive (FileSystem: $($volume.FileSystem))" -ForegroundColor Yellow
                    return $false
                }
            } catch {
                Write-Host "⚠️  Could not determine filesystem for $Path (may be NTFS mount point)" -ForegroundColor Yellow
                # Assume it's valid if we can't determine - let the ownership fix proceed
                return $true
            }
        }
        return $true
    } catch {
        Write-Host "⚠️  Could not verify $Name Dev Drive filesystem: $_" -ForegroundColor Yellow
        return $false
    }
}

function Set-DevDriveOwnership {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path,
        [string]$PartitionName,
        [string]$UserName,
        [bool]$ForceFix = $false
    )

    Write-Host "📁 Processing $PartitionName Dev Drive: $Path" -ForegroundColor Cyan

    # Get volume information
    try {
        # For mount points, get the volume GUID first, then get volume info
        $mountvolOutput = & mountvol $Path /L 2>&1
        if ($LASTEXITCODE -eq 0 -and $mountvolOutput) {
            $volumeGuid = $mountvolOutput.Trim()
            $volume = Get-Volume -UniqueId $volumeGuid
        } else {
            # Fallback: try Get-Volume -Path
            try {
                $volume = Get-Volume -Path $Path
            } catch {
                Write-Host "   ⚠️  Could not get volume information for mount point" -ForegroundColor Yellow
                return
            }
        }
        Write-Host "   Size: $([math]::Round($volume.Size / 1GB, 2)) GB" -ForegroundColor Gray
        Write-Host "   Free: $([math]::Round($volume.SizeRemaining / 1GB, 2)) GB" -ForegroundColor Gray
    } catch {
        Write-Host "   ⚠️  Could not get volume information: $_" -ForegroundColor Yellow
    }

    # Test current access
    $testFile = Join-Path $Path "ownership_test.tmp"
    $accessWorks = $false

    try {
        "test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item $testFile -ErrorAction SilentlyContinue
        $accessWorks = $true
        Write-Host "   ✅ Current access is working" -ForegroundColor Green
    } catch {
        Write-Host "   🔒 Access denied - ownership fix needed" -ForegroundColor Yellow
    }

    # Check current ownership
    try {
        $acl = Get-Acl $Path
        $owner = $acl.Owner
        Write-Host "   Current owner: $owner" -ForegroundColor Gray
        if ($owner -notlike "*$currentUser*") {
            Write-Host "   ⚠️  Ownership issue detected - current owner is not the user" -ForegroundColor Yellow
            $accessWorks = $false
        }
    } catch {
        Write-Host "   ⚠️  Could not check current ownership: $_" -ForegroundColor Yellow
    }

    if ($accessWorks -and -not $ForceFix) {
        Write-Host "   ⏭️  Skipping ownership fix (use -Force to override)" -ForegroundColor Gray
        return $true
    }

    Write-Host "   🔧 Fixing ownership and permissions..." -ForegroundColor Yellow

    try {
        # Step 1: Set ownership recursively
        if ($PSCmdlet.ShouldProcess($Path, "Set ownership recursively to $currentUser")) {
            Set-OwnershipRecursive -Path $Path -UserName $currentUser
        }

        # Step 2: Grant full control recursively
        if ($PSCmdlet.ShouldProcess($Path, "Grant full control recursively to $currentUser")) {
            Write-Host "   Granting full control recursively to $currentUser..." -ForegroundColor Gray
            $acl = Get-Acl $Path
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
            $acl.SetAccessRule($rule)
            Set-Acl -Path $Path -AclObject $acl -ErrorAction Stop
            Write-Host "   ✅ Permissions granted successfully" -ForegroundColor Green
        }

        # Step 4: Verify the fix worked
        Write-Host "   Verifying fix..." -ForegroundColor Gray
        try {
            # Check ownership after fix
            $acl = Get-Acl $Path
            $owner = $acl.Owner
            Write-Host "   Final owner: $owner" -ForegroundColor Gray

            if ($owner -like "*$currentUser*") {
                Write-Host "   ✅ Ownership correctly set to user" -ForegroundColor Green
            } elseif ($owner -like "*Administrators*") {
                Write-Host "   ⚠️  Ownership set to Administrators (may still work)" -ForegroundColor Yellow
            } else {
                Write-Host "   ⚠️  Ownership not set to expected user: $owner" -ForegroundColor Yellow
            }

            "test" | Out-File -FilePath $testFile -ErrorAction Stop
            Remove-Item $testFile -ErrorAction SilentlyContinue

            # Additional validation: check that we can enumerate directory contents recursively
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 5 | Out-Null
            Write-Host "   ✅ Ownership and permissions fixed successfully" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "   ❌ Verification failed: $_" -ForegroundColor Red
            return $false
        }

    } catch {
        Write-Host "   ❌ Failed to fix ownership: $_" -ForegroundColor Red
        Write-Host "   💡 Manual PowerShell commands you can try:" -ForegroundColor Gray
        Write-Host "      # Set ownership recursively" -ForegroundColor Gray
        Write-Host "      Get-ChildItem -Path `"$Path`" -Recurse -Force | ForEach-Object { `$acl = Get-Acl `$_.FullName; `$acl.SetOwner([System.Security.Principal.NTAccount]`"$currentUser`"); Set-Acl -Path `$_.FullName -AclObject `$acl }" -ForegroundColor Gray
        Write-Host "      # Grant full control" -ForegroundColor Gray
        Write-Host "      `$acl = Get-Acl `"$Path`"; `$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(`"$currentUser`", `"FullControl`", `"ContainerInherit,ObjectInherit`", `"None`", `"Allow`"); `$acl.SetAccessRule(`$rule); Set-Acl -Path `"$Path`" -AclObject `$acl" -ForegroundColor Gray
        return $false
    }
}

# Check WhatIf mode first
if ($WhatIf) {
    Write-Host "`n🔍 WHAT-IF MODE: No ownership changes will be made" -ForegroundColor Cyan
    Write-Host "   This would fix ownership on Dev Drive mount points:" -ForegroundColor Gray
    Write-Host "   • Cache: $CachePath" -ForegroundColor Gray
    Write-Host "   • Code: $CodePath" -ForegroundColor Gray
    Write-Host "   Run without -WhatIf to perform actual ownership fixes." -ForegroundColor Gray
    exit 0
}

# Validate Dev Drive paths
$cacheValid = Test-DevDrivePath -Path $CachePath -Name "Cache"
$codeValid = Test-DevDrivePath -Path $CodePath -Name "Code"

if (-not $cacheValid -and -not $codeValid) {
    Write-Host "❌ No valid Dev Drive partitions found to fix" -ForegroundColor Red
    Write-Host "   Ensure Dev Drives are created and mounted first" -ForegroundColor Yellow
    Write-Host "   Run 41-devdrive-partition-setup.ps1 to create Dev Drives" -ForegroundColor Gray
    exit 1
}

# Implement ShouldProcess pattern for ownership changes
$operationDescription = "Fix ownership and permissions on Dev Drive mount points"
if (-not $PSCmdlet.ShouldProcess($operationDescription, "Modify file system permissions")) {
    Write-Host "❌ Operation cancelled by ShouldProcess" -ForegroundColor Red
    exit 0
}

# Apply force flag if set via environment
if ($forceFixOwnership) {
    $Force = $true
}

# Fix cache partition ownership
$cacheFixed = $false
if ($cacheValid) {
    $cacheFixed = Set-DevDriveOwnership -Path $CachePath -PartitionName "Cache" -UserName $currentUser -ForceFix $Force
}

# Fix code partition ownership
$codeFixed = $false
if ($codeValid) {
    $codeFixed = Set-DevDriveOwnership -Path $CodePath -PartitionName "Code" -UserName $currentUser -ForceFix $Force
}

Write-Host ""
Write-Host "📊 Results Summary" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($cacheValid) {
    if ($cacheFixed) {
        Write-Host "✅ Cache Dev Drive: $CachePath" -ForegroundColor Green
    } else {
        Write-Host "❌ Cache Dev Drive: Issues remain" -ForegroundColor Red
    }
} else {
    Write-Host "⏭️  Cache Dev Drive: Not present" -ForegroundColor Gray
}

if ($codeValid) {
    if ($codeFixed) {
        Write-Host "✅ Code Dev Drive: $CodePath" -ForegroundColor Green
    } else {
        Write-Host "❌ Code Dev Drive: Issues remain" -ForegroundColor Red
    }
} else {
    Write-Host "⏭️  Code Dev Drive: Not present" -ForegroundColor Gray
}

Write-Host ""
if (($cacheValid -and $cacheFixed) -or ($codeValid -and $codeFixed)) {
    Write-Host "🎉 Dev Drive ownership issues resolved!" -ForegroundColor Green
    Write-Host "   You should now be able to use your Dev Drives without permission errors." -ForegroundColor Gray
} else {
    Write-Host "⚠️  Some ownership issues remain" -ForegroundColor Yellow
    Write-Host "   Troubleshooting steps:" -ForegroundColor Gray
    if ($cacheValid -and -not $cacheFixed) {
        Write-Host "   • Cache drive: Run commands manually or try as different admin user" -ForegroundColor Gray
    }
    if ($codeValid -and -not $codeFixed) {
        Write-Host "   • Code drive: Run commands manually or try as different admin user" -ForegroundColor Gray
    }
    Write-Host "   • Restart computer and try again" -ForegroundColor Gray
    Write-Host "   • Check Windows Event Viewer for permission-related errors" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🔒 Security Note: This script grants full control to the current user" -ForegroundColor Cyan
Write-Host "   Ensure you're running as the correct user account" -ForegroundColor Gray
