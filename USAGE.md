# NAME

    MySQLTuner 2.9.4 - MySQL High Performance Tuning Advisor for MySQL, MariaDB, and Percona Server

# SYNOPSIS

**mysqltuner** \[_OPTIONS_\]

    # Basic local execution using standard unix socket
    perl mysqltuner.pl

    # Remote TCP/IP connection with explicit credentials and forced memory sizing
    perl mysqltuner.pl --host 192.168.1.50 --port 3306 --user root --pass secret --forcemem 16G

    # Containerized database analysis via Docker/Podman
    perl mysqltuner.pl --container production_mysql_1 --user root --pass secret

    # Generate comprehensive interactive HTML diagnostic dashboard
    perl mysqltuner.pl --reportfile /var/www/html/tuner_report.html

    # Export schema markdown documentation per database
    perl mysqltuner.pl --schemadir /opt/db_docs/

    # AI Agent integration output (actionable JSON remediation plan)
    perl mysqltuner.pl --agent-json

    # Export indicator catalog and metadata in JSON format (offline, no database connection)
    perl mysqltuner.pl --list-indicators

# IMPORTANT USAGE GUIDELINES

- **Production Stability:** Run the script without modifying arguments first to review recommendations before applying changes.
- **Representative Workload:** Allow your database server to run under normal production load for at least 24 to 48 hours before trusting metric ratios and sizing advice.
- **Privilege Requirements:** Administrative read-only access (`SELECT`, `PROCESS`, `SHOW DATABASES`, `REPLICATION CLIENT`) is required for exhaustive diagnostics.
- **Remote Host Hardware Sizing:** When connecting over TCP/IP or SSH to remote instances, specify host RAM via `--forcemem` (e.g., `--forcemem 32G`) to ensure accurate buffer sizing recommendations.

# OPTIONS

## Connection and Authentication Options

- **--host** _hostname_

    Connect to remote MySQL/MariaDB server via TCP/IP hostname or IP address.

- **--port** _port_

    TCP/IP port number to connect to (default: 3306).

- **--socket** _socket\_path_

    Path to local UNIX domain socket for database communication.

- **--pipe**

    Connect to a local Windows database using named pipes.

- **--pipe\_name** _name_

    Use a different pipe name for a local Windows named pipe connection.

- **--protocol** _tcp_

    Force TCP connection protocol instead of UNIX domain socket.

- **--user** _username_

    Database username for authentication.

- **--password** _password_, **--pass** _password_

    Database password for authentication.

- **--userenv** _envvar_

    Environment variable name containing the database username.

- **--passenv** _envvar_

    Environment variable name containing the database password.

- **--defaults-file** _path_

    Path to a custom MySQL configuration file (e.g., `~/.my.cnf`).

- **--defaults-extra-file** _path_

    Path to an additional configuration file to read after standard defaults.

- **--login-path** _path_

    Read credentials from MySQL encrypted login path (via `mysql_config_editor`).

- **--mysqlcmd** _path_

    Path to custom `mysql` client binary.

- **--mysqladmin** _path_

    Path to custom `mysqladmin` binary.

- **--ssl-ca** _path_

    Path to SSL Certificate Authority (CA) certificate.

## Target Environment and Cloud Discovery Options

- **--cloud**

    Enable cloud mode for remote or managed cloud database instances.

- **--azure**

    Enable Azure Database for MySQL specific optimizations and metrics.

- **--container** _container\_name\_or\_id_

    Execute diagnostics inside a running Docker or Podman container.

- **--ssh-host** _hostname_

    Execute diagnostics over SSH remote transport.

- **--ssh-user** _username_

    SSH login username.

- **--ssh-password** _password_

    SSH password for remote cloud host authentication.

- **--ssh-identity-file** _path_

    Path to SSH private key identity file for remote host authentication.

## Performance and Diagnostic Tuning Options

- **--forcemem** _size_

    Amount of physical RAM installed in host (e.g., `16G`, `1024M`, `128K`).

- **--forceswap** _size_

    Amount of configured swap space on host (e.g., `4G`, `2048M`).

- **--skipworkload**

    Bypass high-cardinality table churn and auto-increment exhaustion checks.

- **--skippassword**

    Skip offline dictionary checks for weak user passwords.

- **--skipsize**

    Skip table size enumeration queries on `information_schema`.

- **--buffers**

    Print detailed per-buffer memory allocations.

- **--cvefile** _path_

    Path to custom CVE vulnerabilities CSV database file.

- **--passwordfile** _path_

    Path to custom dictionary file for password audits.

- **--checkversion**

    Check for upstream MySQLTuner version updates.

- **--updateversion**

    Update MySQLTuner in-place if a newer version is available.

- **--sysbench-file** _path_

    Path to a sysbench output file for performance metadata integration.

- **--compare-file** _path_

    Path to a previous JSON result file for trend analysis.

- **--feature** _feature\_name_

    Run a specific diagnostic feature report subroutine (see FEATURES.md).

- **--server-log** _path_

    Path to explicit server error log file for log analysis.

- **--nondedicated**

    Adjust tuning formulas assuming the host runs non-database workloads.

- **--noprocess**

    Skip OS-level non-mysqld process enumeration.

## Output and Export Options

- **--verbose**, **-v**

    Activate full verbose output including storage engines and table statistics.

- **--silent**

    Suppress standard console output.

- **--outputfile** _path_

    Save console report to plain text file.

- **--reportfile** \[_path_\]

    Generate interactive self-contained HTML diagnostic dashboard.

- **--json**

    Output raw diagnostic results as a JSON string.

- **--prettyjson**

    Output diagnostic results as formatted, indented JSON.

- **--agent-json**

    Output actionable AI remediation schema with SQL/config fixes and rollback statements.

- **--yaml**

    Output diagnostic metrics in YAML format.

- **--dumpdir** _path_

    Dump diagnostic data files and Markdown schema summaries to target directory.

- **--schemadir** _path_

    Export individual Markdown documentation files with Mermaid ER diagrams per schema.

- **--list-indicators**

    Export all diagnostic indicators, features, and metadata in JSON format and exit without establishing a database connection.

- **--color**, **--nocolor**

    Control ANSI color codes in terminal output (enabled by default on TTY).

- **--noprettyicon**

    Use plain text markers (\[OK\], \[!!\], \[--\]) instead of Unicode icons.

- **--stage-timings**

    Display execution duration for each analysis stage.

- **--experimental**

    Print experimental diagnostic analysis and recommendations.

- **--dbstat**, **--nodbstat**

    Print database storage, tables count, and collation breakdown.

- **--tbstat**, **--notbstat**

    Print table-level storage metrics and engine distribution.

- **--colstat**, **--nocolstat**

    Print column metadata and schema optimization findings.

- **--idxstat**, **--noidxstat**

    Print index cardinality, unused index, and duplicate index analysis.

- **--sysstat**, **--nosysstat**

    Print operating system hardware and kernel metrics.

- **--pfstat**, **--nopfstat**

    Print MySQL Performance Schema telemetry and instrumentation metrics.

- **--plugininfo**, **--noplugininfo**

    Print active and inactive MySQL/MariaDB plugin details.

- **--myisamstat**, **--nomyisamstat**

    Print detailed MyISAM key cache and storage statistics.

- **--structstat**, **--nostructstat**

    Print table structure and schema design recommendations.

## Debugging and Filtering Options

- **--debug**

    Print internal debug traces and SQL query payloads.

- **--dbgpattern** _regex_

    Filter debug messages by regular expression pattern.

- **--nobad**

    Suppress negative findings and warning recommendations.

- **--nogood**

    Suppress positive / passing health checks.

- **--noinfo**

    Suppress informational messages.

## Miscellaneous Options

- **--max-password-checks** _number_

    Maximum number of passwords to test from the dictionary file (default: 100).

- **--dump-limit** _number_

    Limit number of rows exported per table in CSV dump mode (default: 50000).

- **--compress-dump**

    Compress dumped CSV files using gzip compression.

- **--ignore-tables** _tables_

    Comma-separated list of tables to exclude from intensive analysis.

- **--bannedports** _ports_

    Comma-separated list of banned network ports to flag.

- **--maxportallowed** _number_

    Maximum allowable number of open ports on the host.

- **--defaultarch** _32|64_

    Assumed operating system architecture (32 or 64-bit, default: 64).

- **--noask**

    Do not prompt for interactive confirmation during operations.

- **--help**, **-?**

    Display the help message and options summary.

# VERSION

Version 2.9.4

# PERLDOC

You can inspect the embedded manual with the perldoc command:

    perldoc mysqltuner.pl

## INTERNALS

[https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md](https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md)

    Internal documentation

# AUTHORS

Major Hayden - major@mhtx.net
Jean-Marie Renouard - jmrenouard@gmail.com

# CONTRIBUTORS

- Matthew Montgomery
- Paul Kehrer
- Dave Burgess
- Jonathan Hinds
- Mike Jackson
- Nils Breunese
- Shawn Ashlee
- Luuk Vosslamber
- Ville Skytta
- Trent Hornibrook
- Jason Gill
- Mark Imbriaco
- Greg Eden
- Aubin Galinotti
- Giovanni Bechis
- Bill Bradford
- Ryan Novosielski
- Michael Scheidell
- Blair Christensen
- Hans du Plooy
- Victor Trac
- Everett Barnes
- Tom Krouper
- Gary Barrueto
- Simon Greenaway
- Adam Stein
- Isart Montane
- Baptiste M.
- Cole Turner
- Daniel Lewart
- Jason Gill
- Jean-Marie Renouard
- Major Hayden
- Matthew Montgomery
- Stephan GroBberndt
- Christian Loos
- Long Radix
- derZ-dev

# SUPPORT

Bug reports, feature requests, and downloads at http://mysqltuner.pl/

Bug tracker can be found at https://github.com/major/MySQLTuner-perl/issues

Maintained by Jean-Marie Renouard (jmrenouard\\@gmail.com) - Licensed under GPL

# SOURCE CODE

[https://github.com/major/MySQLTuner-perl/](https://github.com/major/MySQLTuner-perl/)

    git clone https://github.com/major/MySQLTuner-perl.git

# COPYRIGHT AND LICENSE

Copyright (C) 2006-2026 Major Hayden - major@mhtx.net
\# Copyright (C) 2015-2026 Jean-Marie Renouard - jmrenouard@gmail.com

For the latest updates, please visit http://mysqltuner.pl/

Git repository available at https://github.com/major/MySQLTuner-perl/

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

    See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see &lt;https://www.gnu.org/licenses/>.
