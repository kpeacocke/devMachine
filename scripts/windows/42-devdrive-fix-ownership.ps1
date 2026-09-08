<#
.SYNOPSIS
    Verify DevMachine Dev Drive access without damaging filesystem ownership.

.DESCRIPTION
    Dev Drives do not need recursive ownership rewrites for normal use. This script
    performs a conservative write/read check and only changes ownership when -Force
    is explicitly supplied and the target is an actual Dev Drive.

    The previous implementation used recursive Get-ChildItem -Recurse -Force ACL
    changes and suggested icacls/takeown. That approach is intentionally no longer
    used because recursive ownership changes are unnecessary and risky on Dev Drives.

    C:\DevCache is the Dev Drive. The user's code path is a junction into it and is
    validated as such rather than treated as a separate volume.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [ValidateNotNullOrEmpty()]
    [string]$CachePath = 'C:\DevCache',

    [ValidateNotNullOrEmpty()]
    [string]$CodePath = (Join-Path $env:USERPROFILE 'code'),

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$fsutil = Join-Path $env:SystemRoot 'System32\fsutil.exe'
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

function Test-DevDrive {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $fsutil)) { return $false }
    $output = & $fsutil devdrv query $Path 2>&1
    return ($LASTEXITCODE -eq 0 -and (($output | Out-String) -match '(?i)developer volume'))
}

function Test-Writable {
    param([Parameter(Mandatory)][string]$Path)
    $testFile = Join-Path $Path '.devmachine-access-test'
    try {
        'ok' | Set-Content -LiteralPath $testFile -Encoding ascii -ErrorAction Stop
        Remove-Item -LiteralPath $testFile -Force -ErrorAction Stop
        return $true
    }
    catch {
        Remove-Item -LiteralPath $testFile -Force -ErrorAction SilentlyContinue
        return $false
    }
}

Write-Host '🔧 Dev Drive Access Check' -ForegroundColor Cyan
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $CachePath)) {
    Write-Host "❌ Dev Drive not found: $CachePath" -ForegroundColor Red
    exit 1
}

if (-not (Test-DevDrive -Path $CachePath)) {
    throw "$CachePath is not recognised as a Windows Dev Drive."
}

Write-Host "   Cache Dev Drive: $CachePath" -ForegroundColor Gray
Write-Host "   Current user:    $currentUser" -ForegroundColor Gray

if ($WhatIfPreference) {
    Write-Host '`n🔍 WHAT-IF MODE: no ownership or permission changes will be made.' -ForegroundColor Cyan
    Write-Host '   Cache path is a valid Dev Drive.' -ForegroundColor Green
    if (Test-Path -LiteralPath $CodePath) {
        $codeItem = Get-Item -LiteralPath $CodePath -Force
        if ($codeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host '   Code path is a reparse point/junction.' -ForegroundColor Green
        }
    }
    return
}

if (Test-Writable -Path $CachePath) {
    Write-Host '   ✅ Current user can write to Dev Drive' -ForegroundColor Green
}
elseif (-not $Force) {
    throw "Current user cannot write to $CachePath. Re-run with -Force if you explicitly want an ownership/ACL repair."
}
elseif ($PSCmdlet.ShouldProcess($CachePath, "Grant $currentUser FullControl")) {
    $acl = Get-Acl -LiteralPath $CachePath
    $acl.SetOwner([System.Security.Principal.NTAccount]$currentUser)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.SetAccessRule($rule)
    Set-Acl -LiteralPath $CachePath -AclObject $acl -ErrorAction Stop
    if (-not (Test-Writable -Path $CachePath)) {
        throw 'ACL repair completed but write verification still fails.'
    }
    Write-Host '   ✅ ACL repair verified' -ForegroundColor Green
}

if (Test-Path -LiteralPath $CodePath) {
    $codeItem = Get-Item -LiteralPath $CodePath -Force
    if ($codeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Host "   ✅ Code path is a junction/reparse point: $CodePath" -ForegroundColor Green
    }
    else {
        Write-Host "   ⚠️  Code path exists but is not a junction: $CodePath" -ForegroundColor Yellow
    }
}
else {
    Write-Host "   ⚠️  Code path not found: $CodePath" -ForegroundColor Yellow
}

Write-Host '`n✅ Dev Drive access check complete.' -ForegroundColor Green
