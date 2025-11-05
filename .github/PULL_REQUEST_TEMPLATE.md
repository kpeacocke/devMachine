# Pull request template

name: Pull Request
description: Submit changes to the project
title: ""
labels: []

body:

* type: markdown
    attributes:
      value: |
        Thanks for contributing! Please fill out this form to help us review your changes.

* type: checkboxes
    id: checklist
    attributes:
      label: Pre-submission Checklist
      options:
        - label: I have tested my changes locally
          required: true
        - label: I have run the syntax validation tests
          required: true
        - label: I have updated documentation if needed
          required: true
        - label: I have followed the code standards in CONTRIBUTING.md
          required: true
        - label: I have considered security implications
          required: true

* type: dropdown
    id: change-type
    attributes:
      label: Type of Change
      options:
        - Bug fix (non-breaking change that fixes an issue)
        - New feature (non-breaking change that adds functionality)
        - Breaking change (fix or feature that would cause existing functionality to not work as expected)
        - Documentation update
        - Performance improvement
        - Security enhancement
        - Refactoring (no functional changes)
        - Test improvements
      multiple: true
    validations:
      required: true

* type: textarea
    id: description
    attributes:
      label: Description of Changes
      description: What does this PR do? Why was it needed?
      placeholder: |
        This PR adds/fixes/improves...

        Changes include:
        - Added X feature to script Y
        - Fixed issue with Z
        - Updated documentation for...
    validations:
      required: true

* type: input
    id: related-issue
    attributes:
      label: Related Issue
      description: Link to related issue (if applicable)
      placeholder: "Fixes #123, Closes #456, Related to #789"

* type: dropdown
    id: testing
    attributes:
      label: Testing Performed
      description: How did you test these changes?
      options:
        - Syntax validation tests only
        - Manual testing on Surface Pro
        - Manual testing on VM
        - Full setup-machine.ps1 run
        - Specific script testing
        - Windows and WSL testing
        - Not tested (explain why)
      multiple: true
    validations:
      required: true

* type: textarea
    id: testing-details
    attributes:
      label: Testing Details
      description: Provide specific details about your testing
      placeholder: |
        Environment:
        - Windows 11 ARM on Surface Pro X
        - 512GB storage, 100GB free
        - Fresh VM setup

        Tests run:
        - .\tests\syntax-validation.Tests.ps1 ✅
        - .\setup-machine.ps1 -SkipLicensedApps ✅
        - Manual verification of feature X ✅
        
        Results:
        - All tests passed
        - Feature works as expected
        - No breaking changes observed

* type: checkboxes
    id: breaking-changes
    attributes:
      label: Breaking Changes
      description: Does this introduce any breaking changes?
      options:
        - label: No breaking changes
        - label: Breaking changes (explained below)
        - label: Requires updated documentation
        - label: Changes default behavior
        - label: Removes existing functionality

* type: textarea
    id: breaking-details
    attributes:
      label: Breaking Change Details
      description: If you selected breaking changes above, explain the impact and migration path
      placeholder: |
        Breaking changes:
        - Parameter X was renamed to Y
        - Script Z now requires additional dependency

        Migration guide:
        - Users should update calls from old-param to new-param
        - Install dependency A before running script Z

* type: checkboxes
    id: scope
    attributes:
      label: Areas Affected
      description: Which parts of the project are affected?
      options:
        - label: Windows PowerShell scripts
        - label: WSL/Ubuntu bash scripts
        - label: Main orchestrator (setup-machine.ps1)
        - label: Tests
        - label: Documentation (README.md)
        - label: Security configuration
        - label: Performance tuning
        - label: Licensed/commercial software
        - label: Optional development tools
        - label: GitHub Actions/CI (if applicable)

* type: textarea
    id: security-considerations
    attributes:
      label: Security Considerations
      description: Any security implications of these changes?
      placeholder: |
        Security review:
        - New software comes from trusted source (winget/apt)
        - No new admin privileges required
        - No network security changes
        - Follows existing security patterns

        OR
        
        - Adds new firewall rule for X (justified because...)
        - Modifies registry key Y (improves security by...)
        - Downloads from new source Z (verified authentic by...)

* type: textarea
    id: performance-impact
    attributes:
      label: Performance Impact
      description: How do these changes affect performance or storage?
      placeholder: |
        Performance impact:
        - Adds ~50MB to installation size
        - No runtime performance impact
        - Improves build times by caching X

        Storage impact:
        - Tool requires 200MB disk space
        - Moves cache to Dev Drive (saves space on C:)

* type: textarea
    id: additional-notes
    attributes:
      label: Additional Notes
      description: Any other information reviewers should know?
      placeholder: |
        - Tested on both ARM and x64 Surface devices
        - Requires Windows 11 22H2 or later
        - May need follow-up PR for feature Y
        - Special thanks to @contributor for suggestion

* type: checkboxes
    id: future-work
    attributes:
      label: Future Work
      description: Are there related tasks that should be addressed later?
      options:
        - label: No follow-up work needed
        - label: Additional testing needed
        - label: Documentation improvements planned
        - label: Related features to be added
        - label: Performance optimizations possible
