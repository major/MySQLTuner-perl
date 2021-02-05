# NAME

    MySQLTuner 1.7.21 - MySQL High Performance Tuning Script

# IMPORTANT USAGE GUIDELINES

To run the script with the default options, run the script without arguments
Allow MySQL server to run for at least 24-48 hours before trusting suggestions
Some routines may require root level privileges (script will provide warnings)
You must provide the remote server's total memory when connecting to other servers

# CONNECTION AND AUTHENTICATION

    --host <hostname>           Connect to a remote host to perform tests (default: localhost)
    --socket <socket>           Use a different socket for a local connection
    --port <port>               Port to use for connection (default: 3306)
    --user <username>           Username to use for authentication
    --userenv <envvar>          Name of env variable which contains username to use for authentication
    --pass <password>           Password to use for authentication
    --passenv <envvar>          Name of env variable which contains password to use for authentication
    --ssl-ca <path>             Path to public key
    --mysqladmin <path>         Path to a custom mysqladmin executable
    --mysqlcmd <path>           Path to a custom mysql executable
    --defaults-file <path>      Path to a custom .my.cnf
    --server-log <path>         Path to explict log file

# PERFORMANCE AND REPORTING OPTIONS

    --skipsize                  Don't enumerate tables and their types/sizes (default: on)
                                (Recommended for servers with many tables)
    --skippassword              Don't perform checks on user passwords(default: off)
    --checkversion              Check for updates to MySQLTuner (default: don't check)
    --updateversion             Check for updates to MySQLTuner and update when newer version is available (default: don't check)
    --forcemem <size>           Amount of RAM installed in megabytes
    --forceswap <size>          Amount of swap memory configured in megabytes
    --passwordfile <path>       Path to a password file list(one password by line)

# OUTPUT OPTIONS

    --silent                    Don't output anything on screen
    --nogood                    Remove OK responses
    --nobad                     Remove negative/suggestion responses
    --noinfo                    Remove informational responses
    --debug                     Print debug information
    --noprocess                Consider no other process is running
    --dbstat                    Print database information
    --nodbstat                  Don't Print database information
    --tbstat                    Print table information
    --notbstat                  Don't Print table information
    --idxstat                   Print index information
    --noidxstat                 Don't Print index information
    --sysstat                   Print system information
    --nosysstat                 Don't Print system information
    --pfstat                    Print Performance schema
    --nopfstat                  Don't Print Performance schema
    --verbose                   Prints out all options (default: no verbose, dbstat, idxstat, sysstat, tbstat, pfstat)
    --bannedports               Ports banned separated by comma(,)
    --maxportallowed            Number of ports opened allowed on this hosts
    --cvefile <path>            CVE File for vulnerability checks
    --nocolor                   Don't print output in color
    --json                      Print result as JSON string
    --buffers                   Print global and per-thread buffer values
    --outputfile <path>         Path to a output txt file
    --reportfile <path>         Path to a report txt file
    --template   <path>         Path to a template file

# PERLDOC

You can find documentation for this module with the perldoc command.

    perldoc mysqltuner

## INTERNALS

[https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md](https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md)

    Internal documentation

# AUTHORS

Major Hayden - major@mhtx.net

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
- Major Hayden
- Joe Ashcraft
- Jean-Marie Renouard
- Stephan GroBberndt
- Christian Loos

# SUPPORT

Bug reports, feature requests, and downloads at http://mysqltuner.pl/

Bug tracker can be found at https://github.com/major/MySQLTuner-perl/issues

Maintained by Major Hayden (major\\@mhtx.net) - Licensed under GPL

# SOURCE CODE

[https://github.com/major/MySQLTuner-perl](https://github.com/major/MySQLTuner-perl)

    git clone https://github.com/major/MySQLTuner-perl.git

# COPYRIGHT AND LICENSE

Copyright (C) 2006-2020 Major Hayden - major@mhtx.net

For the latest updates, please visit http://mysqltuner.pl/

Git repository available at https://github.com/major/MySQLTuner-perl

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
