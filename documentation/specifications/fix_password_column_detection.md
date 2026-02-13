# Specification: Robust Password Column Detection in mysqltuner.pl

## Problem

`mysqltuner.pl` fails to detect the correct password column (`password` vs `authentication_string`) on MySQL 8.0+ because its detection logic is hardcoded for specific versions (5.7, MariaDB 10.2-10.5). This leads to failing SQL queries like:
`SELECT ... FROM mysql.user WHERE (password = '' OR password IS NULL)`
on versions where the `password` column no longer exists.

## Requirements

1. **Version Agnostic**: Detection must rely on actual schema inspection of `mysql.user` rather than hardcoded version numbers.
2. **Compatibility**:
    - Support legacy `Password` (capital P) and modern `authentication_string` columns.
    - Handle instances where both might exist (e.g., during some MariaDB upgrades).
    - Stay agnostic to exact casing of the `Password` column.
3. **Stability**:
    - Fail gracefully if no known authentication column is found.
    - Ensure the resulting SQL remains safe for all supported versions.

## Proposed Logic

1. Retrieve columns from `mysql.user` using `select_table_columns_db('mysql', 'user')`.
2. Check for `authentication_string` and `password` (case-insensitive).
3. Set `$PASS_COLUMN_NAME`:
    - If both exist: use `IF(plugin='mysql_native_password', authentication_string, password)`.
    - If only `authentication_string` exists: use `authentication_string`.
    - If only `password` exists: use the exact name found in the schema (e.g., `Password`).
4. If none exist, log an info message and return early (skip password-related security checks).

## Success Criteria

- `mysqltuner.pl` executes security recommendations without SQL errors on MySQL 8.0.
- `mysqltuner.pl` still works correctly on legacy MySQL 5.5/5.6.
- `mysqltuner.pl` works correctly on MariaDB 10.11+.
