# MySQL and MariaDB Authentication Plugins Reference

This document provides a comprehensive overview of authentication plugins across MySQL and MariaDB, including security levels, deprecation status, and platform support.

## Summary Table

| Plugin Name | Description | Algorithm | Security Level | Deprecated / Obsolete | Present in MySQL | Present in MariaDB |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `mysql_native_password` | Historical default authentication method. | Double-SHA-1 | Low | Yes (Removed from MySQL 8.4+ / Deprecated in MariaDB) | ✅ (Obsolete) | ✅ (Historical default) |
| `mysql_old_password` | Ancient pre-4.1 authentication method. | Legacy pre-4.1 hash | Very Low | Yes (Removed) | ❌ | ✅ (Obsolete) |
| `sha256_password` | Authenticates using SHA-256 with salting. | SHA-256 | High | Yes (Due to CPU scalability issues without TLS) | ❌ (Removed in 8.4) | ✅ |
| `caching_sha2_password` | Optimized version of SHA-256 with memory caching. | SHA-256 | High | No | ✅ (Default since 8.0) | ✅ (Since v11.4 for compatibility) |
| `unix_socket` | Authentication via OS-level user identity (UID). | OS Identity | Very High | No | ✅ (as `auth_socket`) | ✅ |
| `ed25519` | Elliptic Curve digital signature algorithm (EdDSA). | Ed25519 | Very High | No | ❌ (Except via third-party Enterprise modules) | ✅ |
| `parsec` | Password Authentication using Response Signed with Elliptic Curve (new MariaDB standard). | PBKDF2 + SHA-512 + Ed25519 | Maximal | No | ❌ | ✅ |

---

## 🔒 Recommended Migration Queries

### Upgrading to MySQL 8.4 LTS / 9.x (Deprecating `mysql_native_password`):
In MySQL 8.4 LTS and 9.x, `mysql_native_password` is disabled by default and will be completely removed. Migrate accounts to `caching_sha2_password`:
```sql
ALTER USER 'app_user'@'%' IDENTIFIED WITH caching_sha2_password BY 'StrongSecurePassw0rd!';
FLUSH PRIVILEGES;
```

### Upgrading to MariaDB 11.4+ LTS (Adopting `ed25519` or `parsec`):
To enable high-performance elliptic curve authentication in MariaDB:
```sql
INSTALL SONAME 'auth_ed25519';
ALTER USER 'app_user'@'%' IDENTIFIED VIA ed25519 USING PASSWORD('StrongSecurePassw0rd!');
FLUSH PRIVILEGES;
```

---

## 🛡️ SSL/TLS Hardening Best Practices

1. **Enforce Encryption for All Connections**:
   ```ini
   [mysqld]
   require_secure_transport = ON
   tls_version = TLSv1.2,TLSv1.3
   ```
2. **Restrict Administrative Accounts to Localhost**:
   Ensure administrative accounts (`root`, `dba_admin`) are bound to `127.0.0.1` or `localhost` and enforce socket authentication where available.

