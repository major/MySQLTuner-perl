## MySQLTuner Internals


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

## MySQLTuner system checks

* Get total RAM/swap
* 32-bit w/>2GB RAM check

## MySQLTuner Server version checks
* EOL MySQL version check
* Currently MySQL < 5.1 are EOF considerated.

## MySQL Storage engine general information

* Get storage engine counts/stats
    * Check for DB engines that are enabled but unused
    * Look for fragmented tables
    * Look for auto-increments near capacity


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

## MySQLTuner Connections information

* TODO

## MySQLTuner InnoDB information

* InnoDB Buffer Pool Size
   * If possible, innodb_buffer_pool_size should be greater data and index size for Innodb Table
   * Innodb_buffer_pool_size should around 75 to 80 % of the available system memory.
* InnoDB Buffer Pool Instances
   * MySQL needs 1 instanes per 1Go of Buffer Pool
   * innodb_buffer_pool instances = round(innodb_buffer_pool_size / 1Go)
   * innodb_buffer_pool instances must be equals or lower than 64
*  InnoDB Buffer Pool uUsage
   * If more than 20% of InnoDB buffer pool is not used, MySQLTuner raise an alert.
* InnoDB Read effiency
   * Ratio of read without locks
* InnoDB Write effiency
   * Ratio of write without locks
* InnoDB Log Waits
   * Checks that no lock is used on Innodb Log.

## MySQLTuner ARIADB information

* TODO

## MySQLTuner MYISAM information

* TODO
