# Implementation Plan: SSL/TLS Security Checks

## Goal

Add comprehensive SSL/TLS security checks to `mysqltuner.pl` to detect missing SSL configuration, insecure protocols, and lack of secure transport enforcement.

## Proposed Changes

### [mysqltuner.pl](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/mysqltuner.pl)

#### [NEW] `ssl_tls_recommendations` subroutine

- Create a new subroutine `ssl_tls_recommendations` to group all SSL/TLS related checks.
- Logic:
    1. **Connection Encryption**: Use `Ssl_cipher` from session status to check if the current connection is secure.
    2. **Global SSL Status**: Check `have_ssl` (or `ssl_cert`/`ssl_key` if `have_ssl` is missing/deprecated).
    3. **Protocol Versions**: Parse `tls_version` (MySQL 8.0+, MariaDB 10.4.6+) or check `ssl_cipher` for protocol restrictions.
    4. **Enforced Transport**: Check `require_secure_transport` (MySQL 5.7+, MariaDB 10.5+).
    5. **Certificates Configuration**: Check if `ssl_ca`, `ssl_cert`, and `ssl_key` are set.

#### [MODIFY] `mysqltuner.pl` main execution flow

- Call `ssl_tls_recommendations` in the reporting section, likely before or after `security_recommendations`.

## Verification Plan

### Automated Tests

- Create a new test script `tests/ssl_tls_validation.t`.
- Mock variables:
  - `require_secure_transport = OFF` -> Expect warning.
  - `tls_version = TLSv1.1,TLSv1.2` -> Expect warning for TLSv1.1.
  - `have_ssl = DISABLED` -> Expect critical warning.
  - `Ssl_cipher = ""` (session) -> Expect warning that current connection is not secure.

### Manual Verification

- Run MySQLTuner against a local containerized MySQL/MariaDB with and without SSL.
- Test with different `--ssl-ca` options.
