---
trigger: explicit_call
description: Mastery of MySQLTuner CLI options for connection and authentication.
category: skill
---
# CLI Execution Mastery Skill

## 🧠 Rationale

Mastering the CLI options of `mysqltuner.pl` allows for seamless execution across diverse environments while maintaining security and leveraging existing configurations.

## 🛠️ Implementation

### 1. Connection Discovery & Targeting

| Target Type | Primary Command/Options |
| :--- | :--- |
| **Local Socket** | `perl mysqltuner.pl` (Default) \| `--socket=/path/to/mysql.sock` |
| **Remote Host** | `perl mysqltuner.pl --host=1.2.3.4 --port=3306` |
| **Container** | `perl mysqltuner.pl --container=container_name_or_id` |
| **Cloud/Azure** | `perl mysqltuner.pl --cloud --azure` |

### 2. Authentication Strategies

> [!IMPORTANT]
> Avoid passing passwords directly via `--pass` on the command line to prevent exposure in process lists.

- **Preferred: `.my.cnf` Usage**
  - Use `--defaults-file=/path/to/.my.cnf` to point to a specific configuration file.
  - The script automatically respects common paths if not specified.

- **Environment Variables**
  - Use `--userenv=MY_USER_VAR` and `--passenv=MY_PASS_VAR` to leverage pre-set credentials.

- **Password Files**
  - Use `--passwordfile=/path/to/passwords.txt` for batch security auditing.

### 3. Execution Contexts

- **Standard Verbose Run**: `perl mysqltuner.pl --verbose` (Recommended for full diagnostics).
- **Silent Mode**: `perl mysqltuner.pl --silent` (Useful for automated data collection).
- **JSON Output**: `perl mysqltuner.pl --json` or `--prettyjson` (For integration with other tools).

### 4. Debugging Connections

If connection fails, use these flags to diagnose:

- `--debug`: Enables full debug output.
- `--dbgpattern='.*'`: Filters debug information with regex.
- Verify `mysqlcmd` path if custom binaries are used: `--mysqlcmd=/usr/local/bin/mysql`.

## ✅ Verification

- Run `perl mysqltuner.pl --help` to confirm availability of these options.
- Use `execute_system_command` to test connectivity with specific flags in the target environment.
