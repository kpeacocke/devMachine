---
applyTo: ".github/workflows/**"
description: GitHub Actions Workflow Standards
---

# GitHub Actions Workflow Standards

## Workflow Structure

### Naming and Triggers

```yaml
name: 'Descriptive Workflow Name'

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:
    inputs:
      input_name:
        description: 'Input description'
        required: false
        type: string
        default: 'default-value'

permissions:
  contents: read
  security-events: write
```

### Job Organization

```yaml
jobs:
  validate:
    name: Validate Code
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Run validation
        run: ./scripts/validate.sh

  test:
    name: Run Tests
    needs: [validate]
    runs-on: windows-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Run tests
        shell: pwsh
        run: |
          # Test commands
```

## Best Practices

### Permissions

* Use least privilege principle
* Specify only required permissions
* Use `contents: read` as default
* Add `security-events: write` only for security scans

```yaml
permissions:
  contents: read
  pull-requests: write
  security-events: write
```

### Job Dependencies

* Use `needs:` to create dependency chains
* Run independent jobs in parallel
* Use matrix strategy for multi-platform tests

```yaml
jobs:
  test:
    needs: [lint, validate]
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
        version: ['7.0', '7.4']
```

### Caching

* Cache dependencies to speed up workflows
* Use appropriate cache keys with version info

```yaml
- name: Cache dependencies
  uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
    restore-keys: |
      ${{ runner.os }}-pip-
```

### Secrets and Variables

* Never hardcode secrets
* Use repository secrets for sensitive data
* Use environment variables for configuration

```yaml
env:
  NODE_VERSION: '20'

steps:
  - name: Use secret
    env:
      API_TOKEN: ${{ secrets.API_TOKEN }}
    run: |
      echo "Token is available but not exposed"
```

### Error Handling

* Set proper exit codes
* Use `continue-on-error` sparingly
* Implement proper failure notifications

```yaml
- name: Run tests
  id: test
  continue-on-error: false
  run: ./test.sh

- name: Handle failure
  if: failure()
  run: echo "Tests failed"
```

### Outputs and Artifacts

* Use job outputs to pass data between jobs
* Upload artifacts for build results
* Set retention periods appropriately

```yaml
jobs:
  build:
    outputs:
      version: ${{ steps.get_version.outputs.version }}
    steps:
      - name: Get version
        id: get_version
        run: echo "version=1.0.0" >> $GITHUB_OUTPUT
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts
          path: dist/
          retention-days: 90
```

## Workflow Types

### Pull Request Validation

* Run syntax checks
* Run unit tests
* Run security scans
* Validate formatting
* Block merge on failure

### Release Workflows

* Trigger on version tags or main branch
* Wait for all validations to pass
* Create GitHub releases
* Upload release artifacts
* Update changelog
* Tag with semantic version

### Scheduled Workflows

* Use cron syntax for scheduling
* Run comprehensive integration tests
* Check for security updates
* Validate documentation
* Run weekly/monthly as appropriate

```yaml
on:
  schedule:
    # Run every Sunday at 2 AM UTC
    - cron: '0 2 * * 0'
  workflow_dispatch:
```

## Security Considerations

* Pin action versions to specific commits or tags
* Review third-party actions before use
* Use official actions when available
* Scan for secrets before committing workflows
* Limit workflow permissions

```yaml
- name: Run security scan
  uses: aquasecurity/trivy-action@0.20.0  # Pinned version
  with:
    scan-type: 'fs'
    severity: 'CRITICAL,HIGH'
```

## Debugging Workflows

* Use `workflow_dispatch` for manual testing
* Enable debug logging with `ACTIONS_STEP_DEBUG`
* Add verbose output to critical steps
* Use `actions/upload-artifact` to inspect files

```yaml
- name: Debug step
  if: ${{ runner.debug == '1' }}
  run: |
    echo "Debug information"
    env | sort
```

## Maintenance

* Keep actions up to date
* Review workflow runs regularly
* Archive unused workflows
* Document complex workflows
* Test workflow changes in feature branches
