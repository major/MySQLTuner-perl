## MySQLTuner checks & logic

* Get total RAM/swap
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
* Security checks
    * Is anonymous user present?
    * Users without passwords
    * Users w/username as password
    * Users w/o host restriction
    * Weak password check (possibly using cracklib later?)
* EOL MySQL version check
* 32-bit w/>2GB RAM check
* Get storage engine counts/stats
    * Check for DB engines that are enabled but unused
    * Look for fragmented tables
    * Look for auto-increments near capacity
* Calculations
    * Has server answered any queries?
    * 