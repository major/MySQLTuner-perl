## MySQLTuner Internals

## Table of contents

* [MySQLTuner steps](#mysqltuner-steps)
* [Get login information steps](#mysqltuner-get-login-information-steps)
* [System checks](#mysqltuner-system-checks)
* [Server version checks](#mysqltuner-server-version-checks)
* [MySQL Storage engine general information](#mysql-storage-engine-general-information)
* [Security checks](#mysqltuner-security-checks)
* [CVE checks](#mysqltuner-cve-checks)
* [Database information](#mysqltuner-database-information)
* [Index information](#mysqltuner-index-information)
* [Connections information](#mysqltuner-connections-information)
* [Server information](#mysqltuner-server-information)
* [Sort, join and temp table information](#mysqltuner-sort-join-and-temp-table-information)
* [Global buffer information](#mysqltuner-global-buffer-information)
* [Query cache checks](#mysqltuner-query-cache-checks)
* [Slow queries checks](#mysqltuner-slow-queries-checks)
* [Replication checks](#mysqltuner-replication-checks)
* [InnoDB information](#mysqltuner-innodb-information)
* [ARIADB information](#mysqltuner-ariadb-information)
* [MYISAM information](#mysqltuner-myisam-information)
* [GALERA information](#mysqltuner-galera-information)
* [TOKUDB information](#mysqltuner-tokudb-information)
* [ThreadPool information](#mysqltuner-threadpool-information)

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
* Print MyISAM stats
* Print InnoDB stats
* Print AriaDB stats
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
* 32-bit w/>2GB RAM check

## MySQLTuner Server version checks
* EOL MySQL version check
* Currently MySQL < 5.1 are EOF considerated.
* Using 5.5+ version of MySQL for performance issue (asynchronous IO).

## MySQL Storage engine general information

* Get storage engine counts/stats
    * Check for DB engines that are enabled but unused
    * Look for fragmented tables
    * Look for auto-increments near capacity
    	* Look for table with autoincrement with value near max capacity

## MySQLTuner security checks

* Is anonymous user present?
* Users without passwords
* Users w/username as password
* Users w/o host restriction
* Weak password check (possibly using cracklib later?)
* Using basic_passwords.txt as password database
* Password list checks can be avoid (option: --skippassword) 

## MySQLTuner CVE vulnerabilities detection

* option: --cvefile
* Check if your MariaDB or MySQL version contains CVE bulletins.

## MySQLTuner database information
* Per database information
	* Rows number
	* Total size
	* Data size
	* Percentage of data size
	* Index size
	* Percentage of index size

## MySQLTuner index information

* Top 10 worth selectivity index
* Per index information
	* Index Cardinality
	* Index Selectivity
	* Misc information about index definition 
	* Misc information about index size

## MySQLTuner Connections information

* Highest usage of available connections
* Percentage of used connections (<85%)
* Percentage of aborted connections (<3%)

## MySQLTuner server information

* Uptime: If MySQL started within last 24 hours
* Bytes received and sent
* Number of connections
* Percentage between reads and writes
* Is binary log activated ?
   * Is GTID mode activated ?

## MySQLTuner sort, join and temp table information
* Max memory temporary table size allowed.
* Percentage of sort using temporary table (<10%)
* Number of join performed without using indexes (<250)
* Percentage of temporary table written on disk(<25%)
* Thread cache (=4)
* Table cache hit ratio(>2°%)
* Percentage of open file and open file limit(<85%)
* Percentage of table locks (<95%)
* Percentage of binlog cache lock (<90%)

## MySQLTuner global buffer information

* Key Buffer
* Max Tmp Table
* Per Thread Buffer
   * Read Buffer
   * Read RND Buffer
	* Sort Buffer
	* Thread stack
	* Join Buffer
	* Binlog Cache Buffers size if activated

## MySQLTuner query cache checks

* Is Query cache activated ?
   * Query Cache Buffers
   * Query Cache DISABLED, ALL REQUEST or ON DEMAND
   * Query Cache Size
   * Query cache hit ratio (cache efficienty)
    
## MySQLTuner memory checks

* Get total RAM/swap
* Is there enought memory for max connections reached by MySQL ?
* Is there enought memory for max connections allowed by MySQL ?
* Max percentage of memory used(<85%)

## MySQLTuner slow queries checks

* Percentage of Slow queries  (<5%)

## MySQLTuner replication checks

* Is server replication configuarted as slave ?
* SQL replacation thread running ?
* IO replacation thread running ?
* Replication lag in seconds
* Is Slave configuratedd in read only ?

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

* Is Aria indexes size is greater than page cache size ?
* Page cache read hit ratio (>95%)
* Page cache write hit ratio (>95%)
 

## MySQLTuner MYISAM information

* Key buffer usage (>90%)
* Is MyISAM indexes size is greater than key buffer size ?
* Key buffer read hit ratio (>95%)
* Key buffer write hit ratio (>95%)

## MySQLTuner Galera information

* wsrep_ready cluster is ready
* wsrep_connected node is connected to other nodes
* wsrep_cluster_status PRIMARY /NON PRIMARY.
	* PRIMARY : Coherent cluster
	* NO PRIMARY : cluster gets several states
* wsrep_ local_state_comment: Node state
	* SYNCED (uptodate),
	* DONOR(sending information to another node)
	* Joiner(Try to reach cluster group)
	* SYNCED state able to read/write
* wsrep_cluster_conf_id configuration level must be identical in all nodes
* wsrep_last_commited committed level must be identical in all nodes


## MySQLTuner TokuDB information

* tokudb_cache_size 
* tokudb_directio 
* tokudb_empty_scan
* tokudb_read_block_size
* tokudb_commit_sync
* tokudb_checkpointing_period
* tokudb_block_size 
* tokudb_cleaner_iterations
* tokudb_fanout

## MySQLTuner MariaDB thread pool information

* thread_pool_size
* thread_pool_stall_limit 

* thread_pool_max_threads 
* thread_pool_idle_timeout 

* thread_pool_oversubscribe

* threadpool_threads
* threadpool_idle_threads
* threadpool_threads / thread_pool_size
* threadpool_idle_threads / thread_pool_size
