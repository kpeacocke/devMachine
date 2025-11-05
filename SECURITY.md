# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it by:

1. **Do NOT open a public issue** for security vulnerabilities
2. Send an email to the repository owner through GitHub
3. Use GitHub's private vulnerability reporting feature

### What to include in your report

* Description of the vulnerability
* Steps to reproduce
* Potential impact
* Suggested fix (if any)

### What to expect

* **Acknowledgment**: We will acknowledge receipt of your vulnerability report within 48 hours
* **Assessment**: We will assess the vulnerability and determine its impact within 5 business days
* **Fix Timeline**: Critical vulnerabilities will be addressed within 30 days, others within 90 days
* **Disclosure**: We will coordinate with you on responsible disclosure

## Security Considerations

This project contains scripts that:

* Install and configure software with administrative privileges
* Modify system security settings (Windows Defender, Firewall, BitLocker)
* Handle SSH keys and authentication
* Configure network and system access

### Before running these scripts

1. **Review all scripts** before execution
2. **Run in a test environment** first (VM recommended)
3. **Backup your system** before making changes
4. **Verify checksums** of downloaded files when possible
5. **Use official package managers** (winget, apt) when available

### Security Features Included

* **Defense in depth**: Multiple security layers (Defender, Malwarebytes, GlassWire, firewall)
* **Least privilege**: Scripts request only necessary permissions
* **Audit logging**: Enhanced Windows audit policies
* **Encryption**: BitLocker, Credential Guard, LSA Protection
* **Network security**: Firewall rules, SSH key-only authentication
* **Vulnerability scanning**: Snyk, Trivy, security linters

### Known Security Considerations

1. **Administrative Privileges**: Scripts require admin rights to modify system settings
2. **Network Downloads**: Scripts download software from the internet
3. **Registry Modifications**: System registry is modified for security hardening
4. **Service Configuration**: System services are modified (Windows Search, Superfetch, etc.)
5. **Firewall Rules**: Custom firewall rules are applied

### Mitigation Strategies

* All downloads use official package managers when possible
* Registry changes are documented and reversible
* Service changes improve security posture
* Firewall rules follow security best practices
* Scripts include error handling and validation

## Disclaimer

**Use at your own risk.** These scripts modify system configurations and install software.
While designed for security and best practices, any automation carries inherent risks.
Always test in a non-production environment first.
