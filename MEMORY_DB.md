# MySQLTuner-perl Version Memory

## Current Version: 2.8.41

## Project Evolution & Systemic Findings

### System Call & Core Perl Optimization (v2.8.35+)
Migrated several external commands to native Core Perl to reduce fork overhead and improve portability:
- `whoami` -> `(getpwuid($<))[0]`
- `env` / `printenv` -> `%ENV` hash access
- `hostname` -> `Sys::Hostname::hostname()`
- `grep ... /proc/meminfo` -> Native file parsing
- `grep -c ^processor /proc/cpuinfo` -> Native file parsing
- `which` -> Native PATH iteration
- `getconf PAGESIZE` -> `POSIX::sysconf(POSIX::_SC_PAGESIZE)`
- `uname` -> `POSIX::uname()` or `$^O`
- `stty` -> `POSIX::Termios`
- `uptime` -> `/proc/uptime` parsing or `$^T` calculation

### Recent Audits
- **v2.8.41**: 
  - Completed project-wide refactoring to use standard Perl Boolean practices.
  - Restored Debian maintenance account automatic login functionality (#896).
  - Improved memory calculation accuracy by including `tmp_table_size` in per-thread buffers (#864).
  - Added retry mechanism for initial server connection checks to improve resilience (#782).
  - Resolved `AUTO_INCREMENT` capacity false positives for empty tables (#37).
  - Corrected `check_removed_innodb_variables` false positives for injected variables (#32).
  - Fixed `--defaults-file` usage to prevent dropping other connection options (#605).
  - Refactored InnoDB Redo Log Capacity logic to be workload-based for modern MySQL (#714, #737, #777).
  - Added recommendation for `table_open_cache_instances` based on CPU cores (#480).
  - Improved connection resilience with retry mechanism and fixed uninitialized `$mysqllogin` (#782, #490).
  - Added guards against division by zero in calculations for AWS Aurora compatibility (#435).
- **v2.8.40**: Enhanced SSL/TLS security checks and cloud discovery (AWS RDS/Aurora, GCP, Azure).
- **v2.8.38**: Fixed container startup failures in lab environments.
- **v2.8.31**: Improved SQL check syntax for redundant index detection.
