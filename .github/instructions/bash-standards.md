---
applyTo: "**/*.sh"
description: Bash Scripting Standards
---

# Bash Scripting Standards

## Script Header

All bash scripts must include:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Script: script-name.sh
# Description: What this script does
# Author: Your Name
# Last Updated: YYYY-MM-DD
```

## Error Handling

* Use `set -e` to exit on error
* Use `set -u` to treat unset variables as errors
* Use `set -o pipefail` to catch errors in pipelines
* Implement trap handlers for cleanup

```bash
set -euo pipefail

cleanup() {
    echo "Cleaning up..."
    rm -f "$TEMP_FILE"
}

trap cleanup EXIT ERR
```

## Variable Naming

* Use lowercase for local variables
* Use UPPERCASE for environment variables and constants
* Use descriptive names, not single letters
* Quote all variable expansions

```bash
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
local temp_file="/tmp/myfile.tmp"

echo "Processing: $temp_file"
```

## Functions

* Declare functions before use
* Use local variables inside functions
* Return meaningful exit codes
* Document function purpose

```bash
# Install a package using apt
# Arguments:
#   $1 - package name
# Returns:
#   0 on success, 1 on failure
install_package() {
    local package_name="$1"
    
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y "$package_name"
        return $?
    else
        echo "Error: apt-get not found" >&2
        return 1
    fi
}
```

## Conditionals

* Use `[[` instead of `[` for better safety
* Quote variables in conditionals
* Use explicit comparisons

```bash
if [[ -f "$config_file" ]]; then
    source "$config_file"
elif [[ -d "$config_dir" ]]; then
    echo "Found directory instead of file"
else
    echo "Configuration not found"
fi
```

## Command Checks

* Check for required commands before use
* Provide helpful error messages

```bash
check_requirements() {
    local missing=()
    
    for cmd in git curl jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing required commands: ${missing[*]}" >&2
        exit 1
    fi
}
```

## Best Practices

* Use `command -v` instead of `which`
* Prefer `[[` over `[` for conditionals
* Use `printf` instead of `echo` for complex output
* Quote all variable expansions: `"$var"`
* Use arrays for lists, not space-separated strings
* Use `readonly` for constants
* Shellcheck your scripts before committing

## Security

* Validate all input
* Use absolute paths or sanitize user paths
* Quote variables to prevent word splitting
* Avoid `eval` unless absolutely necessary
* Use `mktemp` for temporary files
* Set restrictive permissions on created files
