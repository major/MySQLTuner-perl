# MySQLTuner 2.8.43 — Complete CLI Reference

MySQLTuner is a MySQL High Performance Tuning Script.

## Quick Start

```bash
# Local analysis (simplest)
perl mysqltuner.pl

# Full verbose output
perl mysqltuner.pl --verbose

# Remote host analysis
perl mysqltuner.pl --host targetDNS_IP --user admin_user --pass admin_password --forcemem 16G
```

## Important Usage Guidelines

- Allow MySQL server to run for at least **24-48 hours** before trusting suggestions.
- Some routines may require root level privileges (the script will provide warnings).
- You **must** provide the remote server's total memory when connecting to remote hosts without SSH.

---

## CONNECTION AND AUTHENTICATION

| Option | Description |
|:---|:---|
| `--host <host>` | Connect to a remote host to perform tests |
| `--port <port>` | Port to use for connection (default: 3306) |
| `--socket <path>` | Use a different socket for a local connection |
| `--user <user>` (`-u`) | Username to use for authentication |
| `--pass <pass>` (`-p`, `--password`) | Password to use for authentication |
| `--userenv <envvar>` | Environment variable name for username |
| `--passenv <envvar>` | Environment variable name for password |
| `--defaults-file <path>` | Path to a custom `.my.cnf` |
| `--defaults-extra-file <path>` | Path to an extra custom config file |
| `--login-path <path>` | Read options from the specified login path (uses `mysql_config_editor`) |
| `--protocol tcp` | Force TCP connection instead of socket |
| `--ssl-ca <path>` | Path to public key (SSL CA) |
| `--mysqlcmd <path>` | Path to a custom `mysql` executable |
| `--mysqladmin <path>` | Path to a custom `mysqladmin` executable |
| `--pipe` / `--no-pipe` | Connect to a local Windows database using named pipes |
| `--pipe_name <name>` | Use a different pipe name for a local connection |
| `--server-log <path>` | Path to an explicit log file (error_log) |

### Examples

```bash
# Using a defaults file
perl mysqltuner.pl --defaults-file=/etc/mysql/my.cnf

# Using environment variables for credentials
export DB_USER=mysqltuner
export DB_PASS=secret
perl mysqltuner.pl --userenv=DB_USER --passenv=DB_PASS

# Force TCP protocol
perl mysqltuner.pl --host 10.0.0.5 --protocol tcp
```

---

## CLOUD SUPPORT

| Option | Description |
|:---|:---|
| `--cloud` / `--no-cloud` | Enable cloud mode |
| `--azure` / `--no-azure` | Enable Azure-specific support |
| `--container <id>` | Enable container mode with ID or name (e.g., `docker:mysql_container`) |
| `--ssh-host <host>` | The SSH host for cloud connections |
| `--ssh-user <user>` | The SSH user for cloud connections |
| `--ssh-password <pass>` | The SSH password for cloud connections (uses `sshpass`) |
| `--ssh-identity-file <path>` | The path to the SSH identity file |

### Examples

```bash
# Analyze a database running in Docker
perl mysqltuner.pl --verbose --container docker:mysql_prod

# Cloud mode via SSH
perl mysqltuner.pl --cloud --ssh-host db.example.com --ssh-user admin --ssh-identity-file ~/.ssh/id_rsa

# Azure-specific analysis
perl mysqltuner.pl --azure --host mydb.mysql.database.azure.com --user admin@mydb --pass secret
```

---

## PERFORMANCE AND REPORTING OPTIONS

| Option | Description |
|:---|:---|
| `--forcemem <size>` | Amount of RAM installed (e.g., `10G`, `1024M`, `128K`) |
| `--forceswap <size>` | Amount of swap memory configured (e.g., `10G`, `1024M`) |
| `--skipsize` / `--no-skipsize` | Don't enumerate tables and their sizes (recommended for large servers) |
| `--buffers` / `--no-buffers` | Print global and per-thread buffer values |
| `--checkversion` / `--no-checkversion` | Check for updates to MySQLTuner |
| `--updateversion` / `--no-updateversion` | Update MySQLTuner if a newer version is available (implies `--checkversion`) |
| `--cvefile <path>` | CVE file for vulnerability checks (auto-detects `./vulnerabilities.csv`) |
| `--passwordfile <path>` | Path to a custom password file list (default: `basic_passwords.txt`) |
| `--skippassword` / `--no-skippassword` | Don't perform checks on user passwords |
| `--sysbench-file <path>` | Path to a sysbench output file for performance metadata integration |
| `--compare-file <path>` | Path to a previous JSON result file for trend analysis |
| `--feature <feature>` | Run a specific feature/subroutine only (implies `--verbose`) |

### Output Formats

| Option | Description |
|:---|:---|
| `--json` / `--no-json` | Print result as JSON string |
| `--prettyjson` / `--no-prettyjson` | Print result as formatted JSON string |
| `--outputfile <path>` | Path to an output text file |
| `--reportfile <path>` | Path to a report text file (requires `Text::Template` module) |
| `--template <path>` | Path to a template file for report generation |

### Data Export

| Option | Description |
|:---|:---|
| `--dumpdir <path>` | Path to a directory where to dump information files (CSV) |
| `--schemadir <path>` | Path to a directory where to dump one Markdown file per schema |
| `--dump-limit <n>` | Limit number of rows for dumpdir CSV exports (default: 50000) |
| `--compress-dump` / `--no-compress-dump` | Compress dumped CSV files using gzip |

### Examples

```bash
# Full verbose with CVE checks
perl mysqltuner.pl --verbose --cvefile=vulnerabilities.csv

# JSON output for automation
perl mysqltuner.pl --json --outputfile=report.json

# Dump all schema data with compression
perl mysqltuner.pl --verbose --dumpdir=./dumps --compress-dump --dump-limit=10000

# Export schema documentation as Markdown
perl mysqltuner.pl --verbose --schemadir=./schemas

# Historical trend analysis
perl mysqltuner.pl --json --outputfile=run1.json
# ... some time later ...
perl mysqltuner.pl --compare-file=run1.json

# Sysbench integration
perl mysqltuner.pl --sysbench-file=/path/to/sysbench_output.txt
```

---

## OUTPUT OPTIONS

| Option | Description |
|:---|:---|
| `--verbose` (`-v`) / `--no-verbose` | Print all options (enables all stat flags below) |
| `--silent` / `--no-silent` | Don't output anything on screen |
| `--color` / `--no-color` | Print output in color (auto-detected for TTY) |
| `--noprettyicon` / `--no-noprettyicon` | Print output with legacy `[OK]`/`[!!]` tags instead of Unicode icons |
| `--debug` / `--no-debug` | Print debug information |
| `--dbgpattern <regex>` | Filter debug output by regex pattern |
| `--experimental` / `--no-experimental` | Print experimental analysis |
| `--nondedicated` / `--no-nondedicated` | Consider server is not dedicated to DB (adjusts memory recommendations) |
| `--noprocess` / `--no-noprocess` | Consider no other process is running |

### Stat Flags

These flags control which sections of the report are displayed. `--verbose` enables all of them.

| Option | Description |
|:---|:---|
| `--dbstat` / `--no-dbstat` | Print database information |
| `--tbstat` / `--no-tbstat` | Print table information |
| `--colstat` / `--no-colstat` | Print column information |
| `--idxstat` / `--no-idxstat` | Print index information |
| `--sysstat` / `--no-sysstat` | Print system stats |
| `--pfstat` / `--no-pfstat` | Print Performance Schema info |
| `--plugininfo` / `--no-plugininfo` | Print plugin information |
| `--myisamstat` / `--no-myisamstat` | Print MyISAM stats |
| `--structstat` / `--no-structstat` | Print table structures, naming conventions, and modeling analysis |

### Output Filtering

| Option | Description |
|:---|:---|
| `--nobad` / `--no-nobad` | Remove negative/suggestion responses |
| `--nogood` / `--no-nogood` | Remove OK responses |
| `--noinfo` / `--no-noinfo` | Remove informational responses |

### Examples

```bash
# Show only problems (filter out OK and info)
perl mysqltuner.pl --nogood --noinfo

# Selective stats
perl mysqltuner.pl --dbstat --idxstat --pfstat

# Debug with pattern filtering
perl mysqltuner.pl --debug --dbgpattern="InnoDB|buffer"

# Non-dedicated server (shared hosting)
perl mysqltuner.pl --nondedicated
```

---

## MISCELLANEOUS OPTIONS

| Option | Description |
|:---|:---|
| `--help` (`-?`) | Show help message |
| `--noask` / `--no-noask` | Don't ask for confirmation |
| `--defaultarch <32\|64>` | Default architecture (default: 64) |
| `--bannedports <p>` | Ports banned, separated by comma |
| `--maxportallowed <n>` | Number of open ports allowable |
| `--ignore-tables <t>` | Tables to ignore, comma-separated |
| `--max-password-checks <n>` | Max password checks from dictionary (default: 100) |

---

## INTERNALS

Detailed documentation of all checks and indicators: [INTERNALS.md](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/INTERNALS.md)

## AUTHORS

- Major Hayden - major@mhtx.net
- Jean-Marie Renouard - jmrenouard@gmail.com

## LICENSE

Copyright (C) 2006-2026 Major Hayden & Jean-Marie Renouard

Licensed under GPL v3. See [LICENSE](https://www.gnu.org/licenses/gpl-3.0.html).

## SOURCE CODE

- Repository: [https://github.com/jmrenouard/MySQLTuner-perl/](https://github.com/jmrenouard/MySQLTuner-perl/)
- Bug tracker: [https://github.com/jmrenouard/MySQLTuner-perl/issues](https://github.com/jmrenouard/MySQLTuner-perl/issues)
