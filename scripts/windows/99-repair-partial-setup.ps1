<#
.SYNOPSIS
    Audit and safely clean up artifacts from a partial DevMachine run.

.DESCRIPTION
    This utility is intentionally conservative. It does NOT uninstall applications,
    undo security hardening, resize partitions, or reset Windows configuration.

    It audits the machine and, when -RemoveDevDriveExclusions is supplied, removes
    only the DevMachine-specific Dev Drive exclusion paths that older versions of
    the bootstrap could have created:
      - C:\DevCache
      - %USERPROFILE%\code
      - D:\dev\caches

    Other Defender exclusions are left untouched because they may have pre-existed
    the DevMachine run.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$RemoveDevDriveExclusions
)

$ErrorActionPreference = 'Stop'

Write-Host "🔎 DevMachine Partial-Run Audit" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Dev Drive state
$devVolumes = Get-Volume -ErrorAction SilentlyContinue |
    Where-Object { $_.FileSystem -eq 'ReFS' -and $_.FileSystemLabel -in @('DevCache','DevCode') }

if ($devVolumes) {
    Write-Host "`nDev Drive volumes found:" -ForegroundColor Yellow
    foreach ($volume in $devVolumes) {
        Write-Host "  • $($volume.FileSystemLabel): $([math]::Round($volume.Size / 1GB,1)) GB" -ForegroundColor Gray
    }
} else {
    Write-Host "`n✅ No DevCache/DevCode ReFS volumes found." -ForegroundColor Green
}

# Defender state
try {
    $prefs = Get-MpPreference -ErrorAction Stop
    $candidatePaths = @(
        'C:\DevCache',
        (Join-Path $env:USERPROFILE 'code'),
        'D:\dev\caches'
    )

    $present = @($prefs.ExclusionPath | Where-Object { $_ -in $candidatePaths })

    Write-Host "`nDevMachine-specific Dev Drive exclusions:" -ForegroundColor Yellow
    if ($present.Count -eq 0) {
        Write-Host "  ✅ None found" -ForegroundColor Green
    } else {
        foreach ($path in $present) {
            Write-Host "  ⚠️  $path" -ForegroundColor Red
        }
    }

    if ($RemoveDevDriveExclusions -and $present.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess(($present -join ', '), 'Remove stale Dev Drive Defender exclusions')) {
            Remove-MpPreference -ExclusionPath $present -ErrorAction Stop
            Write-Host "  ✅ Removed stale Dev Drive exclusions" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "`n⚠️  Could not query Windows Defender: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`nWhat this utility deliberately does NOT change:" -ForegroundColor Cyan
Write-Host "  • Installed applications and packages" -ForegroundColor Gray
Write-Host "  • Firewall, UAC, Defender protection or other hardening" -ForegroundColor Gray
Write-Host "  • PATH changes" -ForegroundColor Gray
Write-Host "  • WSL/Ubuntu configuration" -ForegroundColor Gray
Write-Host "  • Partitions or mount points" -ForegroundColor Gray
Write-Host "  • Non-DevMachine Defender exclusions" -ForegroundColor Gray

Write-Host "`nAudit complete." -ForegroundColor Green
if (-not $RemoveDevDriveExclusions) {
    Write-Host "Use -RemoveDevDriveExclusions if the audit shows stale Dev Drive exclusions." -ForegroundColor Yellow
}
