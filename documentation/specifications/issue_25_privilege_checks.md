# Specification: Warn if current user does not have minimum privileges

## Goal

MySQLTuner should verify that the database user used to connect has the minimum necessary privileges to perform its analysis. If any privilege is missing, it should display a warning (`[!!]`) specifying which privileges are missing.

## Minimum Privileges

The minimum privileges vary by database engine and version.

### MySQL 8.0+

- `SELECT`
- `PROCESS`
- `SHOW DATABASES`
- `EXECUTE`
- `REPLICATION SLAVE`
- `REPLICATION CLIENT`
- `SHOW VIEW`

### MariaDB 10.5+

- `SELECT`
- `PROCESS`
- `SHOW DATABASES`
- `EXECUTE`
- `BINLOG MONITOR`
- `SHOW VIEW`
- `REPLICATION MASTER ADMIN`
- `SLAVE MONITOR` (or `REPLICA MONITOR` in newer versions)

## Tasks

1. **Code Change**: Implement `check_privileges` in `mysqltuner.pl`.
2. **Documentation**: Update all `README.*.md` files to feature these privileges prominently.

## Data Sources

The check should be compatible with various MySQL and MariaDB versions:

### Universal

- `SHOW GRANTS FOR CURRENT_USER()`: Reliable for checking the current user's own grants.

### MySQL Specific (if `mysql.user` is accessible)

- `SELECT * FROM mysql.user WHERE User = ... AND Host = ...`

### MariaDB Specific

- `SELECT * FROM information_schema.USER_PRIVILEGES WHERE GRANTEE = ...`

## Implementation Detail

- New subroutine `check_privileges` will be implemented.
- It will be called within `mysql_setup` after a successful login.
- Errors during privilege checks should be handled gracefully (informational warning if check itself fails).
- The warning should be displayed using `badprint`.

## Success Criteria

- [ ] `mysqltuner.pl` runs normally when full privileges are granted.
- [ ] `mysqltuner.pl` displays a warning listing missing privileges when some are revoked.
- [ ] Compatible with MySQL 5.5-8.4 and MariaDB 10.3-11.8.
