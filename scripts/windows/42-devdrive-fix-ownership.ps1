<#
.SYNOPSIS
    Verify DevMachine Dev Drive access without recursively rewriting ownership.

.DESCRIPTION
    A trusted Dev Drive normally does not need recursive ACL changes. The script
    performs a write test and only changes ownership when -Force is explicitly
    supplied. The old recursive Get-ChildItem -Recurse -Force ACL approach and
    icacls/takeown recovery path are intentionally no longer used.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [ValidateNotNullOrEmpty()][string]$CachePath = 'C:\DevCache',
    [ValidateNotNullOrEmpty()][string]$CodePath = (Join-Path $env:USERPROFILE 'code'),
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
    } catch {
        Remove-Item -LiteralPath $testFile -Force -ErrorAction SilentlyContinue
        return $false
    }
}

Write-Host '🔧 Dev Drive Access Check' -ForegroundColor Cyan
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $CachePath)) { throw "Dev Drive not found: $CachePath" }
if (-not (Test-DevDrive -Path $CachePath)) { throw "$CachePath is not recognised as a Windows Dev Drive." }

if ($WhatIfPreference) {
    Write-Host '🔍 WHAT-IF MODE: no ownership or permission changes will be made.' -ForegroundColor Cyan
    Write-Host '   Cache path is a valid Dev Drive.' -ForegroundColor Green
    return
}

if (Test-Writable -Path $CachePath) {
    Write-Host '   ✅ Current user can write to Dev Drive' -ForegroundColor Green
}
elseif (-not $Force) {
    throw "Current user cannot write to $CachePath. Re-run with -Force only if an ACL repair is intended."
}
elseif ($PSCmdlet.ShouldProcess($CachePath,"Grant $currentUser FullControl")) {
    $acl = Get-Acl -LiteralPath $CachePath
    $acl.SetOwner([System.Security.Principal.NTAccount]$currentUser)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
    $acl.SetAccessRule($rule)
    Set-Acl -LiteralPath $CachePath -AclObject $acl -ErrorAction Stop
    if (-not (Test-Writable -Path $CachePath)) { throw 'ACL repair completed but write verification still fails.' }
    Write-Host '   ✅ ACL repair verified' -ForegroundColor Green
}

if (Test-Path -LiteralPath $CodePath) {
    $codeItem = Get-Item -LiteralPath $CodePath -Force
    if ($codeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { Write-Host "   ✅ Code path is a junction/reparse point: $CodePath" -ForegroundColor Green }
    else { Write-Host "   ⚠️ Code path exists but is not a junction: $CodePath" -ForegroundColor Yellow }
}

Write-Host '✅ Dev Drive access check complete.' -ForegroundColor Green
