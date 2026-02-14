# Specification: SSL/TLS Security Checks

## Goal

Implement automated checks for SSL/TLS configuration in `mysqltuner.pl` to ensure production databases are following security best practices.

## Scope

1. **Detection of SSL Configuration**: Check if SSL is enabled and correctly configured on the server.
2. **Protocol Version Enforcement**: Warn if insecure protocols (TLSv1.0, TLSv1.1) are enabled.
3. **Secure Connection Requirement**: Check if `require_secure_transport` is enabled to force SSL connections.
4. **Default Secure Connection**: Check if the connection established by MySQLTuner itself is secure.

## Technical Details

### Variables to check

- `have_ssl`: (Legacy) Indicates if SSL support is compiled/available.
- `ssl_ca`: Path to CA certificate. If empty, SSL might not be fully configured for verification.
- `tls_version`: Comma-separated list of supported TLS versions (e.g., `TLSv1.2,TLSv1.3`).
- `tls_cipher_list`: (Optional) Check for weak ciphers if possible.
- `require_secure_transport`: (MySQL 5.7.17+, MariaDB 10.5.2+) If `ON`, all connections must use SSL.

### Recommendations logic

- **SSL Not Enabled**: If `have_ssl` is `DISABLED` or no SSL certificates are configured, recommend enabling SSL.
- **Insecure Protocols**: If `tls_version` includes `TLSv1.0` or `TLSv1.1`, recommend disabling them and using only `TLSv1.2` or `TLSv1.3`.
- **Incomplete SSL Config**: If `have_ssl` is `YES` but `ssl_ca` is empty, warn about incomplete SSL setup.
- **Forced SSL Missing**: If `require_secure_transport` is `OFF`, recommend setting it to `ON` for production stability.

### Status Indicators

- **HEALTHY**: SSL enabled, `require_secure_transport=ON`, only TLSv1.2/v1.3 enabled.
- **WARNING**: SSL enabled but `require_secure_transport=OFF` OR insecure protocols enabled.
- **CRITICAL**: SSL disabled or misconfigured.

## User Scenarios

- **Scenario 1**: User runs MySQLTuner on a default installation. It should detect that SSL might be missing or not forced.
- **Scenario 2**: User has SSL enabled but hasn't disabled TLSv1.1. It should point out the security risk.
- **Scenario 3**: User wants to know if their current connection to the database is encrypted.
