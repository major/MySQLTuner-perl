# Specification: Authentication Plugin Security Checks

## Feature Name: Authentication Plugin Auditing

**Status**: Draft
**Created Date**: 2026-02-14

## Goal

Implement diagnostic checks in `mysqltuner.pl` to identify insecure or deprecated authentication plugins used by database users.

## Insecure/Deprecated Plugins by Version

### MySQL

| Plugin | Status in 8.0 | Status in 8.4 LTS | Status in 9.0 | Risk | Recommendation |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `mysql_native_password` | Deprecated | Disabled by default | **REMOVED** | SHA-1, no salt | Migrate to `caching_sha2_password` |
| `sha256_password` | Deprecated (8.0.16) | Deprecated | Deprecated | Lower perf than caching | Migrate to `caching_sha2_password` |
| `mysql_old_password` | Removed | Removed | Removed | Pre-4.1, very weak | Already handled by `secure_auth` |

### MariaDB

| Plugin | Recommended | Risk | Recommendation |
| :--- | :--- | :--- | :--- |
| `mysql_native_password` | No | SHA-1 | Use `ed25519` or `unix_socket` |
| `unix_socket` | **Yes** (Local) | N/A | Best for local OS-level auth |
| `ed25519` | **Yes** | N/A | Standard for high security |

## User Scenarios

1. **Scenario 1**: User has legacy accounts still using `mysql_native_password` on MySQL 8.0. MySQLTuner should warn that these will break in MySQL 9.0 and are less secure.
2. **Scenario 2**: User is on MariaDB and using default `mysql_native_password`. MySQLTuner should suggest `ed25519` for better security.

## User Stories

| Title | Priority | Description | Rationale | Test Case |
| :--- | :--- | :--- | :--- | :--- |
| Detect Insecure Plugins | P1 | As a DBA, I want to see a list of users using insecure plugins. | To prevent security breaches and future breakage. | GIVEN users with `mysql_native_password`, WHEN I run MySQLTuner, THEN it shows a warning. |
| MySQL 9.0 Readiness | P1 | As a DBA, I want to know if my users are ready for MySQL 9.0. | `mysql_native_password` is removed in 9.0. | GIVEN MySQL 8.x, WHEN I run MySQLTuner, THEN it flags accounts needing migration for 9.0. |

## Implementation Plan

1. Query `mysql.user` (or `information_schema.USER_PRIVILEGES` / `information_schema.applicable_roles` depending on version).
2. For each account, check `plugin` column.
3. Aggregate findings and display in "Security Recommendations".
