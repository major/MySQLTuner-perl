## MySQLTuner Internals

[!["Buy Us A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jmrenouard)
## Table of contents

- [MySQLTuner Internals](#mysqltuner-internals)
- [Table of contents](#table-of-contents)
- [MySQLTuner steps](#mysqltuner-steps)
- [MySQLTuner get login information steps](#mysqltuner-get-login-information-steps)
- [MySQLTuner system checks](#mysqltuner-system-checks)
- [MySQLTuner Server version checks](#mysqltuner-server-version-checks)
- [Mysql error log file analysis](#mysql-error-log-file-analysis)
- [MySQL Storage engine general information](#mysql-storage-engine-general-information)
- [MySQLTuner security checks](#mysqltuner-security-checks)
- [MySQLTuner CVE vulnerabilities detection](#mysqltuner-cve-vulnerabilities-detection)
- [MySQLTuner database information](#mysqltuner-database-information)
- [MySQLTuner index information](#mysqltuner-index-information)
- [MySQLTuner Connections information](#mysqltuner-connections-information)
- [MySQLTuner server information](#mysqltuner-server-information)
- [MySQLTuner sort, join and temp table information](#mysqltuner-sort-join-and-temp-table-information)
- [MySQLTuner global buffer information](#mysqltuner-global-buffer-information)
- [MySQLTuner query cache checks](#mysqltuner-query-cache-checks)
- [MySQLTuner memory checks](#mysqltuner-memory-checks)
- [MySQLTuner slow queries checks](#mysqltuner-slow-queries-checks)
- [MySQLTuner replication checks](#mysqltuner-replication-checks)
- [MySQLTuner InnoDB information](#mysqltuner-innodb-information)
- [MySQLTuner ARIADB information](#mysqltuner-ariadb-information)
- [MySQLTuner MYISAM information](#mysqltuner-myisam-information)
- [MySQLTuner Galera information](#mysqltuner-galera-information)
- [MySQLTuner TokuDB information](#mysqltuner-tokudb-information)
- [MySQLTuner XtraDB information](#mysqltuner-xtradb-information)
- [MySQLTuner Connect information](#mysqltuner-connect-information)
- [MySQLTuner Spider information](#mysqltuner-spider-information)
- [MySQLTuner RocksDb information](#mysqltuner-rocksdb-information)
- [MySQLTuner Thread pool information](#mysqltuner-thread-pool-information)
- [MySQLTuner performance schema and sysschema information](#mysqltuner-performance-schema-and-sysschema-information)

## MySQLTuner steps

* Header Print
* Get login information
* Set up some OS variables
* Toss variables/status into hashes
* Get information about the tuning connection
* Check current MySQL version
* Suggest 64-bit upgrade
* Analyze mysqld error log file
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
* Check whether more than 2GB RAM present if on 32-bit OS
* Check number of opened ports (warn when more than 9 ports opened)
* Check 80, 8080, 443 and 8443 ports if warning is raised if they are opened
* Check if some banned ports are not opened (option --bannedports separated by comma)
* Check if non kernel and user process except mysqld are not using more than 15% of total physical memory
* Check vm.swapiness
* Check /etc/security/limit.conf
* Check sysctl entries: sunrpc.tcp_slot_entries, vm.swappiness, fs.aio-fs-nr
* Check mount point
* Check Ethernet card
* Check load average

## MySQLTuner Server version checks
* EOL MySQL version check
* Currently MySQL < 5.1 are considered EOL
* Using 5.5+ version of MySQL for performance issue (asynchronous IO)

## Mysql error log file analysis
* Look for potential current error log file name
* Check permission on error log file
* Check size on error log file
* Check error and warning on error log file
* Find last start and shutdown on error log file

## MySQL Storage engine general information

* Get storage engine counts/stats
    * Check for DB engines that are enabled but unused
    * Look for fragmented tables
    * Look for auto-increments near capacity
    	* Look for tables with auto-increment with value near max capacity

## MySQLTuner security checks

* Is anonymous user present?
* Users without passwords
* Users with username as password
* Users without host restriction
* Weak password check (possibly using cracklib later?)
* Using basic_passwords.txt as password database
* Password list checks can be avoided (option: --skippassword)

## MySQLTuner CVE vulnerabilities detection

* option: --cvefile
* Check if your MariaDB or MySQL version contains CVE entries.

## MySQLTuner database information
* Performance analysis parameter checks
* Per database information
        * Tables number
	* Rows number
	* Total size
	* Data size
	* Percentage of data size
	* Index size
	* Percentage of index size
        * Collation number
        * Check that there is only one collation for all tables in database
        * Check that there is only one collation for all table columns in database
        * Check that there is only one storage engine per user database


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

* Uptime: whether MySQL started within last 24 hours
* Bytes received and sent
* Number of connections
* Percentage between reads and writes
* Is binary log activated?
   * Is GTID mode activated?

## MySQLTuner sort, join and temp table information

* Max memory temporary table size allowed.
* Percentage of sort using temporary table (<10%)
* Number of join performed without using indexes (<250)
* Percentage of temporary table written on disk (<25%)
* Thread cache (=4)
* Thread cache hit ratio (>50%) if thread_handling is different of pools-of-threads
* Table cache hit ratio (>2°%)
* Table cache definition should be upper that total number of tables or in autoresizing mode
* Percentage of open file and open file limit (<85%)
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

* Is Query cache activated?
   * Query Cache Buffers
   * Query Cache DISABLED, ALL REQUEST or ON DEMAND
   * Query Cache Size
   * Query cache hit ratio (cache efficiency)

## MySQLTuner memory checks

* Get total RAM/swap
* Is there enough memory for max connections reached by MySQL?
* Is there enough memory for max connections allowed by MySQL?
* Max percentage of memory used (<85%)

## MySQLTuner slow queries checks

* Percentage of Slow queries (<5%)

## MySQLTuner replication checks

* Is server replication configured as slave?
* SQL replication thread running?
* IO replication thread running?
* Replication lag in seconds (Seconds_behind_master)
* Is Slave configured in read only?
* Replication type ROW, MIX, STMT
* Replication Semisync master
* Replication Semisync slave
* XA support activated
* Replication started?

## MySQLTuner InnoDB information

* InnoDB Buffer Pool Size
   * If possible, innodb_buffer_pool_size should be greater than data and index size for Innodb Table
   * Innodb_buffer_pool_size should be around 75% to 80% of the available system memory.
* InnoDB Buffer Pool Instances
   * MySQL needs 1 instance per 1Go of Buffer Pool
   * innodb_buffer_pool instances = round(innodb_buffer_pool_size / 1Go)
   * innodb_buffer_pool instances must be equal to or lower than 64

   - A bug in MySQL 5.6 causes SHOW VARIABLES to report an innodb_buffer_pool_instances value of 8 when innodb_buffer_pool_size is less than 1GB and only one buffer pool instance is present (Bug #18343670).

* InnoDB Buffer Pool Usage
   * If more than 20% of InnoDB buffer pool is not used, raise an alert.
* InnoDB Buffer Pool Log Size
   * InnoDB total log file size should be 25% of innodb_buffer_pool_size
* InnoDB Read efficiency
   * Ratio of read without locks
* InnoDB Write efficiency
   * Ratio of write without locks
* InnoDB Log Waits
   * Checks that no lock is used on Innodb Log.
* InnoDB Chunk Size
   * Check InnoDB Buffer Pool size is a multiple of InnoDB Buffer Pool chunk size * InnoDB Buffer Pool instances

## MySQLTuner AriaDB information

* Is Aria indexes size greater than page cache size?
* Page cache read hit ratio (>95%)
* Page cache write hit ratio (>95%)


## MySQLTuner MyISAM information

* Key buffer usage (>90%)
* Is MyISAM indexes size is greater than key buffer size ?
* Key buffer read hit ratio (>95%)
* Key buffer write hit ratio (>95%)

## MySQLTuner Galera information

* wsrep_ready cluster is ready
* wsrep_connected node is connected to other nodes
* wsrep_cluster_name is defined.
* wsrep_node_name is defined.
* Check thet notification script wsrep_notify_cmd is defined
* wsrep_cluster_status PRIMARY /NON PRIMARY.
	* PRIMARY : Coherent cluster
	* NO PRIMARY : cluster gets several states
* wsrep_ local_state_comment: Node state
	* SYNCED (uptodate),
	* DONOR (sending information to another node)
	* Joiner (try to reach cluster group)
	* SYNCED state able to read/write
* wsrep_cluster_conf_id configuration level must be identical in all nodes
* wsrep_slave_thread is between 3 or 4 times number of CPU core.
* gcs.limit should be equal to wsrep_slave_threads * 5
* gcs.fc_factor should be equal to 0.8
* Flow control fraction should be lower than 0.02 (wsrep_flow_control_paused < 0.02)
* wsrep_last_commited committed level must be identical in all nodes
* Look for tables without primary keys
* Look for non InnoDB tables for Galera
* Variable innodb_flush_log_at_trx_commit should be set to 0.
* Check that there are 3 or 5 members in Galera cluster.
* Check that xtrabackup is used for SST method with wsrep_sst_method variable.
* Check variables wsrep_OSU_method is defined to TOI for updates.
* Check that there is no certification failures controlling wsrep_local_cert_failures status.

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

## MySQLTuner XtraDB information

*  Not implemented

## MySQLTuner Connect information

*  Not implemented

## MySQLTuner Spider information

*  Not implemented

## MySQLTuner RocksDb information

*  Not implemented

## MySQLTuner Thread pool information

* thread_pool_size between 16 to 36 for Innodb usage
* thread_pool_size between 4 to 8 for MyISAM usage

## MySQLTuner performance schema and sysschema information

* Check that Performance schema is activated for 5.6+ version
* Check that Performance schema is deactivated for 5.5- version
* Check that Sys schema is installed
* Sys Schema version
* Top user per connection
* Top user per statement
* Top user per statement latency
* Top user per lock latency
* Top user per full scans
* Top user per row_sent
* Top user per row modified
* Top user per io
* Top user per io latency
* Top host per connection
* Top host per statement
* Top host per statement latency
* Top host per lock latency
* Top host per full scans
* Top host per rows sent
* Top host per rows modified
* Top host per io
* Top 5 host per io latency
* Top IO type order by total io
* Top IO type order by total latency
* Top IO type order by max latency
* Top Stages order by total io
* Top Stages order by total latency
* Top Stages order by avg latency
* Top host per table scans
* InnoDB Buffer Pool by schema
* InnoDB Buffer Pool by table
* Process per allocated memory
* InnoDB Lock Waits
* Threads IO Latency
* High Cost SQL statements
* Top 5% slower queries
* Top 10 nb statement type
* Top statement by total latency
* Top statement by lock latency
* Top statement by full scans
* Top statement by rows sent
* Top statement by rows modified
* Use temporary tables
* Unused Indexes
* Full table scans
* Latest file IO by latency
* File by IO read bytes
* File by IO written bytes
* File per IO total latency
* File per IO read latency
* File per IO write latency
* Event Wait by read bytes
* Event Wait by write bytes
* Event per wait total latency
* Event per wait read latency
* Event per wait write latency
* Top 15 most read indexes
* Top 15 most modified indexes
* Top 15 high select latency index
* Top 15 high insert latency index
* Top 15 high update latency index
* Top 15 high delete latency index
* Top 15 most read tables
* Top 15 most modified tables
* Top 15 high select latency tables
* Top 15 high insert latency tables
* Top 15 high update latency tables
* Top 15 high delete latency tables
* Redundant indexes
* Tables not using InnoDb buffer
* Top 15 Tables using InnoDb buffer
* Top 15 Tables with InnoDb buffer free
* Top 15 Most executed queries
* Latest SQL queries in errors or warnings
* Top 20 queries with full table scans
* Top 15 reader queries (95% percentile)
* Top 15 row look queries (95% percentile)
* Top 15 total latency queries (95% percentile)
* Top 15 max latency queries (95% percentile)
* Top 15 average latency queries (95% percentile)
* Top 20 queries with sort
* Last 50 queries with sort
* Top 15 row sorting queries with sort
* Top 15 total latency queries with sort
* Top 15 merge queries with sort
* Top 15 average sort merges queries with sort
* Top 15 scans queries with sort
* Top 15 range queries with sort
* Top 20 queries with temp table
* Last 50 queries with temp table
* Top 15 total latency queries with temp table
* Top 15 queries with temp table to disk
* Top 15 class events by number
* Top 30 events by number
* Top 15 class events by total latency
* Top 30 events by total latency
* Top 15 class events by max latency
* Top 30 events by max latency
