---
applyTo: "tests/**"
description: Testing Standards and Best Practices
---

# Testing Standards

## Pester 5 Tests (PowerShell)

### Test Structure

```powershell
#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    # Setup code that runs once before all tests
    $script:testRoot = $PSScriptRoot
    $script:projectRoot = Split-Path -Parent $testRoot
}

Describe "Component Name" {
    BeforeEach {
        # Setup before each test
    }
    
    AfterEach {
        # Cleanup after each test
    }
    
    Context "When testing specific scenario" {
        It "Should produce expected result" {
            $result = Get-Something
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
```

### Test Configuration

Use Pester 5 configuration objects:

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './tests'
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.CodeCoverage.Enabled = $true

$result = Invoke-Pester -Configuration $config
```

### Best Practices

* Use descriptive test names that explain intent
* Test one thing per `It` block
* Use `BeforeAll` for expensive setup
* Use `BeforeEach` for test isolation
* Mock external dependencies
* Avoid testing implementation details
* Test both success and failure paths
* Use `-Tag` for test categorization

### Assertions

```powershell
# Comparison
$result | Should -Be $expected
$result | Should -BeExactly "CaseSensitive"
$result | Should -BeLike "*pattern*"

# Type checks
$result | Should -BeOfType [string]

# Existence
$result | Should -Exist
$result | Should -Not -BeNullOrEmpty

# Exceptions
{ Get-Something } | Should -Throw
{ Get-Something } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
```

## Bash Tests

### Test Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

# Test runner for bash scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" == "$actual" ]]; then
        echo "✓ $message"
        ((TESTS_PASSED++))
    else
        echo "✗ $message"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        ((TESTS_FAILED++))
    fi
}

# Test cases
test_something() {
    local result
    result=$(my_function "input")
    assert_equals "expected" "$result" "my_function should return expected value"
}

# Run tests
test_something

# Report results
echo ""
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
```

## Test Organization

### Directory Structure

```text
tests/
├── pester.Windows.Tests.ps1      # Windows environment validation
├── syntax-validation.Tests.ps1   # Syntax checks for all scripts
├── unit/                         # Unit tests
│   ├── function1.Tests.ps1
│   └── function2.Tests.ps1
└── integration/                  # Integration tests
    ├── setup-flow.Tests.ps1
    └── wsl-integration.Tests.ps1
```

### Test Naming

* Use `.Tests.ps1` suffix for Pester tests
* Use `-test.sh` suffix for bash tests
* Name tests after the component being tested
* Use descriptive `Describe` and `Context` blocks

## CI/CD Integration

### Running Tests in CI

```yaml
- name: Run Pester Tests
  shell: pwsh
  run: |
    $config = New-PesterConfiguration
    $config.Run.Path = './tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    
    $result = Invoke-Pester -Configuration $config
    
    if ($result.FailedCount -gt 0) {
      throw "$($result.FailedCount) test(s) failed"
    }
```

### Test Requirements

* Tests must run without admin privileges (when possible)
* Tests must be idempotent (repeatable)
* Tests must clean up after themselves
* Tests must not depend on external services (or mock them)
* Tests must run in parallel-safe manner

## Coverage Goals

* Unit tests: 80% code coverage minimum
* Integration tests: All critical paths
* Syntax validation: 100% of scripts
* Edge cases: Common error scenarios

## Test Data

* Use realistic but anonymized test data
* Store test fixtures in `tests/fixtures/`
* Don't commit sensitive data
* Use mocking for external dependencies
