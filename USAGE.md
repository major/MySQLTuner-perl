# NAME

    MySQLTuner 2.9.2 - MySQL High Performance Tuning Advisor for MySQL, MariaDB, and Percona Server

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

- **--user** _username_

    Database username for authentication.

- **--password** _password_, **--pass** _password_

    Database password for authentication.

- **--ask-pass**

    Prompt interactively for database password on the terminal.

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

- **--tli**

    Use Transport Layer Interface abstraction.

- **--ssl-ca** _path_

    Path to SSL Certificate Authority (CA) certificate.

- **--caching-sha2-password**

    Force caching\_sha2\_password authentication plugin mode.

## Target Environment and Cloud Discovery Options

- **--container** _container\_name\_or\_id_

    Execute diagnostics inside a running Docker or Podman container.

- **--ssh-host** _hostname_

    Execute diagnostics over SSH remote transport.

- **--ssh-user** _username_

    SSH login username.

- **--ssh-key** _path_

    Path to SSH private key file.

- **--ssh-port** _port_

    SSH daemon port (default: 22).

- **--aws-profile** _profile_

    AWS CLI profile for Amazon RDS / Aurora cluster discovery.

- **--aws-region** _region_

    AWS Region for RDS / Aurora discovery.

- **--aws-cluster-identifier** _id_

    Amazon RDS / Aurora cluster identifier.

- **--aws-instance-identifier** _id_

    Amazon RDS instance identifier.

- **--gcp-project** _project\_id_

    Google Cloud project ID for Cloud SQL instances.

- **--gcp-instance** _instance\_id_

    Google Cloud SQL instance identifier.

- **--azure-resource-group** _group_

    Azure resource group for Azure Database for MySQL.

- **--azure-server-name** _name_

    Azure MySQL flexible/single server name.

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

- **--nocolor**

    Disable ANSI color codes in terminal output.

- **--noprettyicon**

    Use plain text markers (\[OK\], \[!!\], \[--\]) instead of Unicode icons.

- **--stage-timings**

    Display execution duration for each analysis stage.

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

# VERSION

Version 2.9.2

# PERLDOC

You can inspect the embedded manual with the perldoc command:

    perldoc mysqltuner.pl

## INTERNALS

[https://github.com/jmrenouard/MySQLTuner-perl/blob/master/INTERNALS.md](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/INTERNALS.md)

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

Bug tracker can be found at https://github.com/jmrenouard/MySQLTuner-perl/issues

Maintained by Jean-Marie Renouard (jmrenouard\\@gmail.com) - Licensed under GPL

# SOURCE CODE

[https://github.com/jmrenouard/MySQLTuner-perl/](https://github.com/jmrenouard/MySQLTuner-perl/)

    git clone https://github.com/jmrenouard/MySQLTuner-perl/.git

# COPYRIGHT AND LICENSE

Copyright (C) 2006-2026 Major Hayden - major@mhtx.net
\# Copyright (C) 2015-2026 Jean-Marie Renouard - jmrenouard@gmail.com

For the latest updates, please visit http://mysqltuner.pl/

Git repository available at https://github.com/jmrenouard/MySQLTuner-perl/

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
