# SSL/TLS Security Enhancements

## Goal

Enhance MySQLTuner's SSL/TLS diagnostics to ensure modern security standards are met, certificates are valid, and remote users are forced to use encrypted connections.

## Requirements

1. **TLS 1.2+ Enforcement**: Ensure only TLS 1.2 and TLS 1.3 are enabled. Warn if older versions are active.
2. **Certificate Presence**: Verify `ssl_cert`, `ssl_key`, and `ssl_ca` are configured.
3. **Local Certificate Audit**:
    - Check if certificate files are readable on the local filesystem.
    - Validate certificate expiration dates using `openssl`.
    - Warn if certificates are expired or nearing expiration (e.g., within 30 days).
    1. **Remote User SSL Enforcement**:
    - identify users allowed to connect from non-local hosts (`%` or specific IPs).
    - Check if these users have `REQUIRE SSL` (or equivalent) enabled.
    - Warn for users with remote access but no SSL requirement.

## Technical Details

- **TLS Versions**: Check `tls_version` (MySQL) or `tls_version` (MariaDB).
- **Certificates**: Check `ssl_cert`, `ssl_key`, `ssl_ca` variables.
- **Certificate Expiration**:
  - Use `openssl x509 -enddate -noout -in <file>` for local files.
  - Handle cases where `openssl` is missing or files are unreachable.
- **User SSL Requirements**:
  - Query `mysql.user` or `mysql.global_priv`.
  - Column `ssl_type` (NONE, ANY, X509, SPECIFIED).
  - For MariaDB 10.4+: `JSON_VALUE(Priv, '$.ssl_type')`.
