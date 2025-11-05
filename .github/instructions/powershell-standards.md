---
applyTo: "**/*.ps1"
description: PowerShell Coding Standards
---

# PowerShell Coding Standards

## Script Header

All PowerShell scripts must include:

```powershell
#Requires -Version 7.0

<#
.SYNOPSIS
    Brief description of what the script does

.DESCRIPTION
    Detailed description of functionality

.PARAMETER ParameterName
    Description of each parameter

.EXAMPLE
    .\script.ps1 -ParameterName "value"
    Description of what this example does

.NOTES
    Author: Your Name
    Last Updated: YYYY-MM-DD
#>
```

## Error Handling

* Always set `$ErrorActionPreference = 'Stop'` at script start
* Use try-catch-finally blocks for critical operations
* Log errors with contextual information
* Provide actionable error messages

```powershell
try {
    # Operation that might fail
    Get-Item -Path $FilePath -ErrorAction Stop
} catch {
    Write-Error "Failed to get file '$FilePath': $_"
    throw
}
```

## Parameter Validation

Use parameter attributes for validation:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Low', 'Medium', 'High')]
    [string]$Priority = 'Medium',

    [switch]$WhatIf
)
```

## Output and Logging

* Use `Write-Host` with colors for user-facing output
* Use `Write-Verbose` for detailed logging (with `-Verbose` support)
* Use `Write-Warning` for non-fatal issues
* Use `Write-Error` for errors

```powershell
Write-Host "✓ Operation completed successfully" -ForegroundColor Green
Write-Warning "Configuration file not found, using defaults"
Write-Verbose "Processing file: $FilePath"
```

## Code Style

* Use PascalCase for function names (Verb-Noun)
* Use camelCase for variable names
* Use UPPERCASE for constants
* Limit line length to 120 characters
* Use 4-space indentation
* Always use curly braces, even for single-line blocks

## Best Practices

* Avoid using aliases in scripts (use full cmdlet names)
* Use `Join-Path` instead of string concatenation for paths
* Quote all paths that might contain spaces
* Use splatting for cmdlets with many parameters
* Prefer pipeline over ForEach-Object when appropriate
* Use approved verbs from `Get-Verb`

## Security

* Never hardcode credentials
* Use SecureString for passwords
* Validate all user input
* Escape special characters in file paths
* Use `-LiteralPath` when paths come from user input
* Check file permissions before sensitive operations
