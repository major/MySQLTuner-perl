## MySQLTuner checks & logic

* Get total RAM/swap
* EOL MySQL version check
* 32-bit w/>2GB RAM check
* Get storage engine counts/stats
    * Check for DB engines that are enabled but unused
    * Look for fragmented tables
    * Look for auto-increments near capacity
* Calculations
    * Has server answered any queries?
    * 

## MySQLTuner steps

* Header Print
* Get login information
* Set up some OS variables
* Toss variables/status into hashes
* Get information about the tuning connexion
* Check current MySQL version
* Suggest 64-bit upgrade
* Show enabled storage engines
* Show informations about databases (option: --dbstat)
* Show informations about indexes (option: --idxstat)
* Display some security recommendations
* Calculate everything we need
* Print the server stats
* Print InnoDB stats
* Print replication info
* Make recommendations based on stats
* Close reportfile if needed
* Dump result if debug is on

## MySQLTuner get login information steps

* Is a login possible?
    * Force socket?
    * Remote connection?
        * _Specifying available RAM is required_
    * Got user/pass on command line?
    * mysql-quickbackup credentials available?
    * Plesk credentials available?
    * DirectAdmin credentials available?
    * Debian maintenance account credentials available?
    * Just try a login
        * If working, and .my.cnf isn't there, **WARNING**
        * If working, and .my.cnf is there, okay
    * Prompt for creds on the console

## MySQLTuner security checks

    * Is anonymous user present?
    * Users without passwords
    * Users w/username as password
    * Users w/o host restriction
    * Weak password check (possibly using cracklib later?)
    * Using basic_passwords.txt as password database
    * Password list checks can be avoid (option: --skippassword) 

## MySQLTuner database information
    * Rows number
    * Total size
    * Data size
    * Percentage of data size
    * Index size
    * Percentage of index size

## MySQLTuner index information
    * Top 10 worth selectivity index
    * Index Cardinality
    * Index Selectivity
    * Misc information about index definition 
    * Misc information about index size