MySQLTuner-perl
====

MySQLTuner is a script written in Perl that allows you to review a MySQL installation quickly and make adjustments to increase performance and stability.  The current configuration variables and status data is retrieved and presented in a brief format along with some basic performance suggestions.

Compatibility:

* MySQL 3.23, 4.0, 4.1, 5.0, 5.1 (full support)
* MySQL 5.4 (not fully tested, partially supported)
* MySQL 6.0 (partial support)
* MariaDB 10.x (partial support)
* Perl 5.6 or later (with [perl-doc](http://search.cpan.org/~dapm/perl-5.14.4/pod/perldoc.pod) package)
* Unix/Linux based operating system (tested on Linux, BSD variants, and Solaris variants)
* Windows is not supported at this time
* Unrestricted read access to the MySQL server (OS root access recommended for MySQL < 5.0)

***WARNING***
--
It is **extremely important** for you to fully understand each change 
you make to a MySQL database server.  If you don't understand portions 
of the script's output, or if you don't understand the recommendations, 
**you should consult** a knowledgeable DBA or system administrator 
that you trust.  **Always** test your changes on staging environments, and 
always keep in mind that improvements in one area can **negatively affect** 
MySQL in other areas.

**Seriously - please review the FAQ section below.**

Download/Installation
--

You can download the entire repository by using 'git clone' followed by the cloning URL above.  The simplest and shortest method is:

	wget http://mysqltuner.pl/ -O mysqltuner.pl
	perl mysqltuner.pl
	
Of course, you can add the execute bit (`chmod +x mysqltuner.pl`) so you can execute it without calling perl directly.

FAQ
--

Question: Will MySQLTuner fix my slow MySQL server?

**No.**  MySQLTuner is a read only script.  It won't write to any configuration files, change the status of any daemons, or call your mother to wish her a happy birthday.  It will give you an overview of your server's performance and make some basic recommendations about improvements that you can make after it completes.  *Make sure you read the warning above prior to following any recommendations.*

Question: Can I fire my DBA now?

**MySQLTuner will not replace your DBA in any form or fashion.**  If your DBA constantly takes your parking spot and steals your lunch from the fridge, then you may want to consider it - but that's your call.

Question: Why does MySQLTuner keep asking me the login credentials for MySQL over and over?

The script will try its best to log in via any means possible.  It will check for ~/.my.cnf files, Plesk password files, and empty password root logins.  If none of those are available, then you'll be prompted for a password.  If you'd like the script to run in an automated fashion without user intervention, then create a .my.cnf file in your home directory which contains:

	[client]
	user=someusername
	pass=thatuserspassword
	
Once you create it, make sure it's owned by your user and the mode on the file is 0600.  This should prevent the prying eyes from getting your database login credentials under normal conditions.  If a [T-1000 shows up in a LAPD uniform](https://en.wikipedia.org/wiki/T-1000) and demands your database credentials, you won't have much of an option.

Question: It's not working on my OS! What gives?!

These kinds of things are bound to happen.  Here are the details I need from you in order to research the problem thoroughly:

	* OS and OS version
	* Architecture (x86, x86_64, IA64, Commodore 64)
	* Exact MySQL version
	* Where you obtained your MySQL version (OS package, source, etc)
	* The full text of the error
	* A copy of SHOW VARIABLES and SHOW GLOBAL STATUS output (if possible)