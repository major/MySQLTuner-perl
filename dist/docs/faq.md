# Frequently Asked Questions

--

**Question: What are the prerequisites for running MySQL tuner ?**

Before running MySQL tuner, you should have the following:

* A MySQL server installation
* Perl installed on your system
* Administrative access to your MySQL server

**Question: Can MySQL tuner make changes to my configuration automatically ?**

**No.**, MySQL tuner only provides recommendations. It does not make any changes to your configuration files automatically. It is up to the user to review the suggestions and implement them as needed.

**Question: How often should I run MySQL tuner ?**

It is recommended to run MySQL tuner periodically, especially after significant changes to your MySQL server or its workload.

For optimal results, run the script after your server has been running for at least 24 hours to gather sufficient performance data.

**Question: How do I interpret the results from MySQL tuner ?**

MySQL tuner provides output in the form of suggestions and warnings.

Review each recommendation and consider implementing the changes in your MySQL configuration file (usually 'my.cnf' or 'my.ini').

Be cautious when making changes and always backup your configuration file before making any modifications.

**Question: Can MySQL tuner cause harm to my database or server ?**

While MySQL tuner itself will not make any changes to your server, blindly implementing its recommendations without understanding the impact can cause issues.

Always ensure you understand the implications of each suggestion before applying it to your server.

**Question: Does MySQL tuner support MariaDB and Percona Server ?**

Yes, MySQL tuner supports MariaDB and Percona Server since they are derivatives of MySQL and share a similar architecture. The script can analyze and provide recommendations for these systems as well.

**Question: What should I do if I need help with MySQL tuner or have questions about the recommendations ?**

If you need help with MySQL tuner or have questions about the recommendations provided by the script, you can consult the MySQL tuner documentation, seek advice from online forums, or consult a MySQL expert.

Be cautious when implementing changes to ensure the stability and performance of your server.

**Question: Will MySQLTuner fix my slow MySQL server ?**

**No.**  MySQLTuner is a read only script.  It won't write to any configuration files, change the status of any daemons.  It will give you an overview of your server's performance and make some basic recommendations for improvements that you can make after it completes.

**Question: Can I fire my DBA now?**

**MySQLTuner will not replace your DBA in any form or fashion.**

If your DBA constantly takes your parking spot and steals your lunch from the fridge, then you may want to consider it - but that's your call.

Once you create it, make sure it's owned by your user and the mode on the file is 0600.  This should prevent the prying eyes from getting your database login credentials under normal conditions.

**Question: I get "ERROR 1524 (HY000): Plugin 'unix_socket' is not loaded" even with unix_socket=OFF. How to fix?**

This occurs because the MariaDB client attempts to use the `unix_socket` plugin by default when no user/password is provided.

* **Solution 1 (Recommended):** Use a `~/.my.cnf` file as described above to provide explicit credentials.
* **Solution 2:** Pass credentials directly: `perl mysqltuner.pl --user root --pass your_password`.

**Question: How to securely re-enable `unix_socket` authentication?**

If you decide to use `unix_socket` (which allows the OS `root` user to log in to MariaDB `root` without a password), follow these steps:

1. Ensure the plugin is enabled in `/etc/my.cnf`: `unix_socket=ON` (or remove `OFF`).
2. In MariaDB, set the authentication plugin for the root user:

   ```sql
   ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
   ```

3. Verify that the `auth_socket` or `unix_socket` plugin is ACTIVE in `SHOW PLUGINS`.

**Question: Is there another way to secure credentials on latest MySQL and MariaDB distributions ?**

You could use mysql_config_editor utilities.

~~~bash
 $ mysql_config_editor set --login-path=client --user=someusername --password --host=localhost
 Enter password: ********
~~~

After which, `~/.mylogin.cnf` will be created with the appropriate access.

To get information about stored credentials, use the following command:

```bash
$mysql_config_editor print
[client]
user = someusername
password = *****
host = localhost
```

**Question: What's minimum privileges needed by a specific mysqltuner user in database ?**

```bash
 mysql>GRANT SELECT, PROCESS,EXECUTE, REPLICATION CLIENT,
 SHOW DATABASES,SHOW VIEW
 ON *.*
 TO 'mysqltuner'@'localhost' identified by pwd1234;
```

**Question: It's not working on my OS! What gives?!**

These kinds of things are bound to happen. Here are the details I need from you to investigate the issue:

* OS and OS version
* Architecture (x86, x86_64, IA64, Commodore 64)
* Exact MySQL version
* Where you obtained your MySQL version (OS package, source, etc)
* The full text of the error
* A copy of SHOW VARIABLES and SHOW GLOBAL STATUS output (if possible)

**Question: How to perform CVE vulnerability checks?**

* Download vulnerabilities.csv from this repository.
* use option --cvefile to perform CVE checks

**Question: How to use mysqltuner from a remote host?**
Thanks to  [@rolandomysqldba](https://dba.stackexchange.com/users/877/rolandomysqldba)

* You will still have to connect like a mysql client:

Connection and Authentication

 --host <hostname> Connect to a remote host to perform tests (default: localhost)
 --socket <socket> Use a different socket for a local connection
 --port <port>     Port to use for connection (default: 3306)
 --user <username> Username to use for authentication
 --pass <password> Password to use for authentication
 --defaults-file <path> defaults file for credentials

Since you are using a remote host, use parameters to supply values from the OS

 --forcemem <size>  Amount of RAM installed in megabytes
 --forceswap <size> Amount of swap memory configured in megabytes

* You may have to contact your remote SysAdmin to ask how much RAM and swap you have

If the database has too many tables, or very large table, use this:

 --skipsize           Don't enumerate tables and their types/sizes (default: on)
                      (Recommended for servers with many tables)

**Question: Can I install this project using homebrew on Apple Macintosh?**

Yes! `brew install mysqltuner` can be used to install this application using [homebrew](https://brew.sh/) on Apple Macintosh.

