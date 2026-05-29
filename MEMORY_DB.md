# MySQLTuner-perl Version Memory

## Current Version: 2.8.44

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
- **v2.8.44**:
  - Developed automated specification consistency auditor (`build/audit_specifications.pl`) and Spec-to-Test Mapping Matrix.
  - Developed LTS API auto-bumping utility (`build/lts_autobump.pl`) and GitHub Actions integration.
  - Refactored version parsing regexes and helpers (`mysql_version_eq`, `mysql_version_ge`, `mysql_version_le`) to prevent uninitialized value warnings.
  - Developed EOL dates synchronization check script (`build/sync_eol_dates.pl`).
  - Expanded unit tests with parameterized test matrix covering supported/outdated versions in `tests/test_vulnerabilities.t`.
  - Re-implemented HTML report option (`--reportfile`) removing Text::Template dependency.
- **v2.8.43**:
  - Added `--compress-dump` and `--dump-limit` options for schema exports.
  - Exported deviations (naming conventions, foreign keys) to CSV and created manifest files.
  - Prevented fake aborted connections count increase during password checking (#900).
  - Resolved invalid credentials login errors, prevented plaintext password leakage, and protected connection state files.
- **v2.8.42**: Empty project metadata release.
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

---

## 📌 Versioning Configuration & Replication Reference

The following files track and contain the MySQLTuner version string. Below are the mechanisms to modify or regenerate each:

1. **[mysqltuner.pl](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/mysqltuner.pl)** (Main script & POD documentation):
   - **Locations**: File header (`# mysqltuner.pl - Version X.Y.Z`), internal variable (`our $tunerversion = "X.Y.Z";`), and POD documentation.
   - **Update Command**: Makefile targets `make release VERSION=X.Y.Z` or `make increment_sub_version` automatically replace old versions using `sed`.

2. **[CURRENT_VERSION.txt](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/CURRENT_VERSION.txt)** (Minimal version manifest):
   - **Update Command**: Run `make generate_version_file` to extract the version from the [mysqltuner.pl](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/mysqltuner.pl) header.

3. **[USAGE.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/USAGE.md)** (Markdown CLI manual):
   - **Update Command**: Run `rm -f USAGE.md && pod2markdown mysqltuner.pl > USAGE.md` or `make generate_usage`.

4. **[README.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/README.md)** (Version badge and links):
   - **Update Command**: Handled automatically during `make release VERSION=X.Y.Z` using `sed` substitution.

5. **[SECURITY.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/SECURITY.md)** (Supported versions table):
   - **Update Command**: Updated manually or via sed-based version bumps.

6. **[MEMORY_DB.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/MEMORY_DB.md)** (Project version memory):
   - **Update Command**: Updated automatically during `make release VERSION=X.Y.Z` using `sed` substitution.

7. **[Changelog](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/Changelog)** (History log):
   - **Update Command**: Updated automatically during `make release VERSION=X.Y.Z` using `sed` substitution.

8. **[releases/v[VERSION].md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/releases/)** (Release notes):
   - **Update Command**: Generated via `python3 build/release_gen.py`.

