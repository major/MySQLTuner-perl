# Specification - Syslog and Systemd Journal Support for MariaDB/MySQL

## 🧠 Rationale

On modern Linux distributions (like Ubuntu 18.04+), MariaDB and MySQL often default to logging via the systemd journal or syslog instead of a traditional error log file. When `log_error` is not set or points to an unreadable file, MySQLTuner currently fails to analyze logs. This feature adds automatic detection of systemd journal and syslog as fallback sources for error logs.

## User Scenarios

- **Scenario 1**: A user installs MariaDB 10.3 on Ubuntu 18.04. The default configuration logs to systemd. MySQLTuner detects that the traditional log file is missing or empty and automatically switches to `journalctl` to fetch logs.
- **Scenario 2**: A user has a legacy system where logs are directed to `/var/log/syslog`. MySQLTuner checks this file as a last resort if other methods fail.

## User Stories

| Title | Priority | Description | Rationale | Test Case |
| :--- | :--- | :--- | :--- | :--- |
| Systemd Detection | P1 | As a script, I want to automatically detect if MariaDB/MySQL logs are in the systemd journal. | Simplify log analysis on modern systems. | GIVEN a system with `journalctl` and `mariadb.service`, WHEN `log_error` is missing, THEN use `journalctl`. |
| Syslog Fallback | P2 | As a script, I want to check `/var/log/syslog` if no other log source is found. | Provide a fallback for systems using traditional syslog. | GIVEN `/var/log/syslog` exists and contains `mysqld` entries, WHEN other logs fail, THEN use syslog. |
| Automatic Prefixing | P1 | As a script, I want to automatically use `systemd:<service>` prefix for log analysis. | Leverage existing systemd journal reading logic. | GIVEN `mariadb` service is active, WHEN log analysis starts, THEN `log_error` is set to `systemd:mariadb`. |

## Technical Implementation Details

- **Service Detection**: Check for `mariadb.service` or `mysql.service` using `systemctl` if available.
- **Fallback Logic in `log_file_recommendations`**:
    1. Check `log_error` variable.
    2. Check Performance Schema `error_log` table.
    3. Check traditional file paths (existing logic).
    4. **NEW**: Check `journalctl` for `mariadb` or `mysql` units.
    5. **NEW**: Check `/var/log/syslog` if it contains `mysqld` or `mariadb` entries.
- **Command Abstraction**: Use `execute_system_command` for all external calls.

## Verification

- Simulate systemd logs in a test environment.
- Verify that `systemd:` prefix correctly triggers `journalctl` calls.
- Verify that syslog fallback works when files are readable.
