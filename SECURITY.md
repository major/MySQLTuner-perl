# Security Policy

## Supported Versions

MySQLTuner is committed to providing security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 2.x     | :white_check_mark: |
| < 2.x   | :x:                |

We strongly recommend using the latest stable release (currently v2.8.35) available on [GitHub](https://github.com/jmrenouard/MySQLTuner-perl/releases).

## Reporting a Vulnerability

If you discover a security vulnerability within this project, please report it privately to the maintainer.

**Contact**: [jmrenouard@lightpath.fr](mailto:jmrenouard@lightpath.fr)

### What to expect

- **Acknowledgement**: You can expect an initial response within 48-72 hours.
- **Updates**: We will provide periodic updates on the progress of any reported vulnerability until it is resolved.
- **Disclosure**: We will coordinate with you to determine a mutually agreeable disclosure timeline.

## Security Philosophy

- **Production Stability**: Every recommendation provided by MySQLTuner is designed to be safe for production environments.
- **Read-Only**: MySQLTuner is a read-only script. It does not modify your database or system configuration files.
- **CVE Detection**: The script includes features to detect known vulnerabilities (CVEs) based on your MySQL/MariaDB version.
- **Zero-Dependency**: To maintain a secure and portable footprint, we avoid external dependencies and only use Perl Core modules.
