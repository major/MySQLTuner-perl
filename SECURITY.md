# Security Policy

MySQLTuner is committed to providing a secure and reliable experience for all users. This document outlines our security policies, supported versions, and the process for reporting vulnerabilities.

## Supported Versions

We provide security updates for the following versions of MySQLTuner:

| Version | Status                |
| ------- | --------------------- |
| v2.x    | Supported (v2.8.38)   |
| < v2.x  | End of Life           |

We strongly recommend that all users stay updated with the latest stable release available on [GitHub Releases](https://github.com/jmrenouard/MySQLTuner-perl/releases).

## Reporting a Vulnerability

If you discover a security vulnerability in MySQLTuner, please do **not** open a public issue. Instead, report it privately to the maintainer:

- **Contact**: Jean-Marie Renouard ([jmrenouard@lightpath.fr](mailto:jmrenouard@lightpath.fr))

### Reporting Guidelines

Please include the following information in your report:

- A description of the vulnerability.
- Steps to reproduce the issue (proof of concept).
- Potential impact and affected versions.

### What to Expect

- **Acknowledgement**: You will receive an initial response within 48-72 hours.
- **Triage**: We will investigate the report and determine the impact.
- **Resolution**: We will work on a fix as a priority.
- **Disclosure**: We will coordinate with you to determine a mutually agreeable disclosure timeline.

## Security Scope

### In-Scope Vulnerabilities

- Local Privilege Escalation through insecure system calls.
- Credential leaks in the report output (unless explicitly permitted via CLI options).
- Remote Code Execution (RCE) via malicious database responses.
- Insecure storage of temporary data.

### Out-of-Scope

- Vulnerabilities in the underlying Percona/MySQL/MariaDB database itself.
- Issues requiring root access to the host machine to exploit.
- Denial of Service (DoS) attacks that are inherent to database benchmarking or diagnostics.

## Security Philosophy

- **Production Stability**: Every recommendation is designed to be safe for production environments. No destructive actions are performed.
- **Read-Only Architecture**: MySQLTuner is strictly a read-only script. It does not modify database configurations or system files.
- **Zero-Dependency Portability**: To minimize the attack surface, MySQLTuner only uses Perl Core modules and avoids external dependencies.
- **CVE Detection**: The script proactively checks for known CVEs based on the detected database version.
- **Auditability**: As a single-file Perl script, MySQLTuner is easily auditable by security teams before deployment.
