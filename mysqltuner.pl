#!/usr/bin/perl -w
use strict;
use warnings;
use diagnostics;

# CONFIGURATION ITEMS
# Quick color reference
#Black       0;30     Dark Gray     1;30
#Blue        0;34     Light Blue    1;34
#Green       0;32     Light Green   1;32
#Cyan        0;36     Light Cyan    1;36
#Red         0;31     Light Red     1;31
#Purple      0;35     Light Purple  1;35
#Brown       0;33     Yellow        1;33
#Light Gray  0;37     White         1;37
my $revision = "1";
my $good = "[\e[00;32mOK\e[00m]";
my $bad = "[\e[00;31m!!\e[00m]";
my $info = "[\e[00;34m--\e[00m]";

my ($physical_memory,$swap_memory,$duflags);
sub os_setup {
    my $os = `uname`;
    $duflags = '';
    if ($os =~ /Linux/) {
        $physical_memory = `free -b | grep Mem | awk '{print \$2}'`;
        $swap_memory = `free -b | grep Swap | awk '{print \$2}'`;
        $duflags = '-b';
    } elsif ($os =~ /Darwin/) {
        $physical_memory = `sysctl -n hw.memsize`;
        $swap_memory = `sysctl -n vm.swapusage | awk '{print \$3}' | sed 's/\..*$//'`;
    } elsif ($os =~ /BSD/) {
        $physical_memory = `sysctl -n hw.realmem`;
        $swap_memory = `swapinfo | grep '^/' | awk '{ s+= \$2 } END { print s }'`;
    }
    chomp($physical_memory);
}

my $mysqllogin;
sub setup_mysql_login {
    if ( -f "/etc/psa/.psa.shadow" ) {
        # It's a Plesk box, use the available credentials
        $mysqllogin = "-u admin -p`cat /etc/psa/.psa.shadow`";
        my $loginstatus = `mysqladmin ping $mysqllogin 2>&1`;
        if ($loginstatus =~ /mysqld is alive/) {
            print $good." Successfully logged into MySQL using Plesk's credentials.\n";
            return 1;
        } else {
            print $bad." Attempted to use login credentials from Plesk, but they failed.\n";
            exit 0;
        }
    } else {
        # It's not Plesk, we should try a login
        my $loginstatus = `mysqladmin ping 2>&1`;
        if ($loginstatus =~ /mysqld is alive/) {
            # Login went just fine
            $mysqllogin = "";
            # Did this go well because of a .my.cnf file or is there no password set?
            my $userpath = `ls -d ~`;
            chomp($userpath);
            if ( -e "$userpath/.my.cnf" ) {
                # Login was successful, but we won't say anything to save space
            } else {
                print $bad." Successfully authenticated with no password - SECURITY RISK!\n";
            }
            return 1;
        } else {
            print "Please enter your MySQL login: ";
            my $name = <>;
            print "Please enter your MySQL password: ";
            system("stty -echo"); #don't show the password
            my $password = <>;
            system("stty echo"); #plz give echo back
            chomp($password);
            chomp($name);
            $mysqllogin = "-u $name -p'$password'";
            my $loginstatus = `mysqladmin ping $mysqllogin 2>&1`;
            if ($loginstatus =~ /mysqld is alive/) {
                print "\n".$good." Successfully logged into MySQL using provided credentials.\n";
                return 1;
            } else {
                print "\n".$bad." Attempted to use login credentials, but they were invalid.\n";
                exit 0;
            }
            exit 0;
        }
    }
}

my %mystat;
my %myvar;
sub get_all_vars {
    my @mysqlvarlist = `mysql $mysqllogin -Bse "SHOW /*!50000 GLOBAL */ VARIABLES;"`;
    foreach my $line (@mysqlvarlist) {
        $line =~ /([a-zA-Z_]*)\s*(.*)/;
        $myvar{$1} = $2;
    }
    my @mysqlstatlist = `mysql $mysqllogin -Bse "SHOW /*!50000 GLOBAL */ STATUS;"`;
    foreach my $line (@mysqlstatlist) {
        $line =~ /([a-zA-Z_]*)\s*(.*)/;
        $mystat{$1} = $2;
    }
}

my ($mysqlvermajor,$mysqlverminor);
sub validate_mysql_version {
    ($mysqlvermajor,$mysqlverminor) = $myvar{'version'} =~ /(\d)\.(\d)/;
    if ($mysqlvermajor < 4) {
        print $bad." This script will not work with MySQL < 4.0\n";
        exit 0;
    } elsif ($1 == 4 && $2 == 0) {
        print $bad." Your MySQL version ".$myvar{'version'}." is EOL software!  Upgrade soon!\n";
    } elsif ($1 == 5 && $2 == 1) {
        print $bad." Currently running supported MySQL version ".$myvar{'version'}." (BETA - USE CAUTION)\n";
    } else {
        print $good." Currently running supported MySQL version ".$myvar{'version'}."\n";
    }
}

sub pretty_uptime {
    my $uptime = shift;
    my $seconds = $uptime % 60;
    my $minutes = int(($uptime % 3600) / 60);
    my $hours = int(($uptime % 86400) / (3600));
    my $days = int($uptime / (86400));
    my $uptimestring;
    if ($days > 0) {
        $uptimestring = "${days}d ${hours}h ${minutes}m ${seconds}s";
    } elsif ($hours > 0) {
        $uptimestring = "${hours}h ${minutes}m ${seconds}s";
    } elsif ($minutes > 0) {
        $uptimestring = "${minutes}m ${seconds}s";
    } else {
        $uptimestring = "${seconds}s";
    }
    return $uptimestring;
}

sub hr_bytes_rnd {
    my $num = shift;
    if ($num >= (1024**3)) { #GB
        return int(($num/(1024**3)))."G";
    } elsif ($num >= (1024**2)) { #MB
        return int(($num/(1024**2)))."M";
    } elsif ($num >= 1024) { #KB
        return int(($num/1024))."K";
    } else {
        return $num;
    }
}

sub hr_bytes {
    my $num = shift;
    if ($num >= (1024**3)) { #GB
        return sprintf("%.1f",($num/(1024**3)))."G";
    } elsif ($num >= (1024**2)) { #MB
        return sprintf("%.1f",($num/(1024**2)))."M";
    } elsif ($num >= 1024) { #KB
        return sprintf("%.1f",($num/1024))."K";
    } else {
        return $num;
    }
}

sub hr_num {
    my $num = shift;
    if ($num >= (1000**3)) { #GB
        return int(($num/(1000**3)))."G";
    } elsif ($num >= (1000**2)) { #MB
        return int(($num/(1000**2)))."M";
    } elsif ($num >= 1000) { #KB
        return int(($num/1000))."K";
    } else {
        return $num;
    }
}

sub mysql_initial_stats {
    # Show uptime, queries per second, connections, traffic stats
    my $qps = sprintf("%.3f",$mystat{'Questions'}/$mystat{'Uptime'});
    print $info." Up for: ".pretty_uptime($mystat{'Uptime'})." (".hr_num($mystat{'Questions'}).
        " q [".hr_num($qps)." qps], ".hr_num($mystat{'Connections'})." conn,".
        " TX: ".hr_num($mystat{'Bytes_sent'}).", RX: ".hr_num($mystat{'Bytes_received'}).")\n";
}

sub check_memory {
    print "------ MEMORY USAGE ------\n";
    # The purpose of this section is to make sure you're not going to end up in swap or crashing the box
    # by having buffers that are set too large
    #
    # PER-THREAD BUFFERS:
    #   binlog_cache_size - only if log_bin is 'ON' (default 32K)
    my $binlog_cache_size = ($myvar{'log_bin'} =~ /ON/) ? $myvar{'binlog_cache_size'} : 0 ;
    #   join_buffer_size - helps joins that don't use indexes (default 128M)
    my $join_buffer_size = $myvar{'join_buffer_size'};
    #   read_buffer_size - for sequential scans (default 128K)
    my $read_buffer_size = $myvar{'read_buffer_size'};
    #   read_rnd_buffer_size - helps ORDER BY (default 256K)
    my $read_rnd_buffer_size = $myvar{'read_rnd_buffer_size'};
    #   sort_buffer_size - helps SORT/ORDER BY (default 2M)
    my $sort_buffer_size = $myvar{'sort_buffer_size'};
    #   thread_stack - stack size per thread (default 192K) [MySQL says not to adjust this]
    my $thread_stack = $myvar{'thread_stack'};
    #
    # PER-THREAD BUFFER CALCULATIONS:
    my $thread_buffers = $read_buffer_size + $read_rnd_buffer_size + $sort_buffer_size + $thread_stack + $join_buffer_size + $binlog_cache_size;
    my $total_thread_buffers = $thread_buffers * $myvar{'max_connections'};
    my $max_thread_buffers = $thread_buffers * $mystat{'Max_used_connections'};
    #
    # GLOBAL BUFFERS:
    #   innodb_buffer_pool_size - general buffer for InnoDB (default 8M)
    my $innodb_buffer_pool_size = (defined $myvar{'innodb_buffer_pool_size'}) ? $myvar{'innodb_buffer_pool_size'} : 0 ;
    #   innodb_additional_mem_pool_size - stores internal InnoDB table data (default 1M)
    my $innodb_additional_mem_pool_size = (defined $myvar{'innodb_additional_mem_pool_size'}) ? $myvar{'innodb_additional_mem_pool_size'} : 0 ;
    #   innodb_log_buffer_size - holds InnoDB log before writing to disk (default 1M)
    my $innodb_log_buffer_size = (defined $myvar{'innodb_log_buffer_size'}) ? $myvar{'innodb_log_buffer_size'} : 0 ;
    #   key_buffer_size - holds all index data from MyISAM tables (default 8M)
    my $key_buffer_size = $myvar{'key_buffer_size'};
    #   query_cache_size - holds query results (default 0) [still allocated when query_cache_type = 0]
    my $query_cache_size = (defined $myvar{'query_cache_size'}) ? $myvar{'query_cache_size'} : 0 ;
    #
    # GLOBAL BUFFER CALCULATIONS:
    my $global_buffers = $innodb_buffer_pool_size + $innodb_additional_mem_pool_size + $innodb_log_buffer_size + $key_buffer_size + $query_cache_size;
    #
    # FINAL BUFFER/MEMORY CALCULATIONS:
    my $max_memory = $global_buffers + $max_thread_buffers;
    my $total_memory = $global_buffers + $total_thread_buffers;
    my $pct_physical_memory = int(($total_memory * 100) / $physical_memory);
    
    print $info." Per-thread buffers are ".hr_bytes_rnd($thread_buffers).", total ".hr_bytes_rnd($total_thread_buffers).
        " ($myvar{'max_connections'} connections)\n";
    print $info." Max allocated is ".hr_bytes_rnd($max_memory)." (".hr_bytes_rnd($thread_buffers).
        " per-thread * $mystat{'Max_used_connections'} connections + ".hr_bytes_rnd($global_buffers)." global)\n";
    if ($pct_physical_memory > 85) {
        print $bad." DANGER - MySQL is configured to use $pct_physical_memory% (".hr_bytes($total_memory).
            ") of physical memory (".hr_bytes($physical_memory).")\n";
    } else {
        print $good." MySQL is configured to use $pct_physical_memory% (".hr_bytes($total_memory).
            ") of physical memory (".hr_bytes($physical_memory).")\n";
    }
}

sub check_slow_queries {
    print "------ SLOW QUERIES ------\n";
    # If the server hasn't received any queries, then we can't calculate a slow query percentage
    if ($mystat{'Questions'} > 0) {
        my $slowquerypct = int(($mystat{'Slow_queries'}/$mystat{'Questions'}) * 100);
        if ($slowquerypct > 5) {
            print $bad." $slowquerypct% of all queries take more than ".$myvar{'long_query_time'}." sec - optimization is recommended\n";
        } elsif ($slowquerypct <= 5 && $slowquerypct >= 1) {
            print $good." $slowquerypct% of all queries take more than ".$myvar{'long_query_time'}." sec\n";
        } else {
            print $good." Less than 1% of all queries take more than ".$myvar{'long_query_time'}." sec\n";
        }
    }
    # Best case scenario would be slow query log enabled with a long_query_time of 10 or less
    if ($myvar{'log_slow_queries'} =~ /ON/) {
        if ($myvar{'long_query_time'} <= 10) {
            print $good." Slow query log is enabled, and long_query_time is reasonable ($myvar{'long_query_time'} sec)\n";
        } else {
            print $bad. " Slow query log is enabled, but long_query_time is too long ($myvar{'long_query_time'} sec)\n";
        }
    } else {
        if ($myvar{'long_query_time'} <= 10) {
            print $bad." Slow query log is disabled, but long_query_time is reasonable ($myvar{'long_query_time'} sec)\n";
        } else {
            print $bad." Slow query log is disabled, and long_query_time is too long ($myvar{'long_query_time'} sec)\n";
        }
    }
}

sub check_connections {
    print "------ CONNECTION LIMITS ------\n";
    # We're looking at two things here:
    #   How many connections have been used so far and how close is the connection limit?
    #   How many connections can overflow into the back_log?
    #
    # If the maximum connections used is over 85% of the limit, that's a little close.
    # However, if the maximum connections used is less than 10%, that's just wasted memory.
    my $connpct = int(($mystat{'Max_used_connections'}/$myvar{'max_connections'}) * 100);
    if ($connpct > 85) {
        print $bad." $connpct% of connections have been used ".
            "(".$mystat{'Max_used_connections'}."/".$myvar{'max_connections'}.")".
            " - Increase the max_connections variable\n";
    } elsif ($connpct < 10) {
        print $bad." $connpct% of connections have been used ".
            "(".$mystat{'Max_used_connections'}."/".$myvar{'max_connections'}.")".
            " - Reduce max_connections\n";
    } else {
        print $good." $connpct% of connections have been used ".
            "(".$mystat{'Max_used_connections'}."/".$myvar{'max_connections'}.")\n";
    }
    # If the back_log is less than 50, there's a chance that connections will be forcefully rejected
    if ($myvar{'back_log'} < 50) {
        print $bad." Your listen queue back_log is too low - you should raise this to 50-256\n";
    } else {
        print $good." Your listen queue back_log is set to a reasonable level (".$myvar{'back_log'}.")\n";
    }
}

sub check_key_buffer {
    print "------ KEY BUFFER ------\n";
    my $myisamindexes;
    if ($mysqlvermajor < 5) {
        $myisamindexes = `find $myvar{'datadir'} -name '*.MYI' 2>&1 | xargs du $duflags '{}' 2>&1 | awk '{ s += \$1 } END { print s }'`;
        if ($myisamindexes =~ /^0\n$/) {
            print $bad." Unable to complete calculations - run this script with root privileges\n";
            return 0;
        }
    } else {
        $myisamindexes = `mysql $mysqllogin -Bse "/*!50000 SELECT SUM(INDEX_LENGTH) from information_schema.TABLES where ENGINE='MyISAM' */"`;
    }
    chomp($myisamindexes);
    # There's several variables that come into play with regards to key buffers
    #   Key_blocks_unused - number of unused key blocks in the key cache (will decrease over time)
    #   Key_blocks_used - number of used blocks in the key cache (will increase over time)
    #   Key_read_requests - number of requests to read a key block from the cache (this should be high)
    #   Key_reads - number of requests for a key that had to be read from a disk (this should be low)
    if ($mystat{'Key_reads'} == 0) {
        print $bad." Your queries are not using any indexes - no recommendations can be made\n";
        return 0;
    }
    # BUFFER CALCULATIONS:
    #   key_buffer_use_pct - how much of the key buffer is being used
    #       if this gets too high, and key_buffer_size is less than the total
    #       size of the MyISAM indexes, then it should be raised
    #   key_from_mem_pct - the percent of key requests that come from the cache (rather than the disk)
    #       if this starts to increase, the key_buffer_size is too small and 
    #       keys are being thrown out and replaced by other keys
    my $key_buffer_use_pct = sprintf("%.1f",(1 - (($mystat{'Key_blocks_unused'} * $myvar{'key_cache_block_size'}) / $myvar{'key_buffer_size'})) * 100);
    my $key_from_mem_pct = sprintf("%.1f",(100 - (($mystat{'Key_reads'} / $mystat{'Key_read_requests'}) * 100)));
    my $raise_key_buffer = 0;
    if ($key_buffer_use_pct >= 85) {
        $raise_key_buffer = 1       # Key buffer is almost full - raise it
    } elsif ($key_buffer_use_pct < 85 && $key_buffer_use_pct >= 25) {
        $raise_key_buffer = 0;      # Key buffer is reasonable
    } else {
        $raise_key_buffer = -1;     # Key buffer is too big - lower it
    }
    if ($key_from_mem_pct < 95 && $key_from_mem_pct >= 80) {
        $raise_key_buffer += 1;     # Key buffer is probably set to the default, should be raised
    } elsif ($key_from_mem_pct < 80) {
        $raise_key_buffer += 2;     # This is really, really bad - raise the buffer!
    }
    print $info." The key buffer is $key_buffer_use_pct% used, and $key_from_mem_pct% of key requests come from memory\n";
    if ($myisamindexes < $myvar{'key_buffer_size'} && $raise_key_buffer >= 1) {
        print $bad." Your key_buffer_size (".hr_bytes_rnd($myvar{'key_buffer_size'}).") is higher than your total MyISAM indexes (".hr_bytes_rnd($myisamindexes).")\n";
    } else {
        print $info." Total MyISAM index size is ".hr_bytes_rnd($myisamindexes).
            " (current key_buffer_size ".hr_bytes_rnd($myvar{'key_buffer_size'}).")\n";
    }
    if ($raise_key_buffer >= 1) {
        print $bad." Raise the key_buffer_size for better indexing performance in MyISAM tables\n";
    } elsif ($raise_key_buffer == 0) {
        print $good." Your key_buffer_size is set to a reasonable level\n";
    } else {
        print $bad." Lower the key_buffer_size to use the resources elsewhere\n";
    }
}

sub check_query_cache {
    print "------ QUERY CACHE ------\n";
    # If query cache support isn't compiled into MySQL, we fail here
    if (!defined $myvar{'have_query_cache'}) {
        print $bad." Your MySQL server does not support query caching - upgrade MySQL\n";
        return 0;
    }
    # If the query cache is disabled, we fail here
    if ($myvar{'query_cache_size'} == 0) {
        print $bad." The query cache is disabled - set the query_cache_size > 0 to enable it\n";
        return 0;
    }
    # If there haven't been any selects, then we can't do much
    if ($mystat{'Com_select'} == 0) {
        print $info." No SELECT statements have been run - no recommendations can be made\n";
        return 0;
    }
    # QUERY CACHE VARIABLES/STATUS:
    #   Com_select - number of SELECTS executed that didn't use the query cache
    #   Qcache_free_memory - memory available for use in the query cache
    #   Qcache_hits - number of queries that pulled a result from the query cache
    #   Qcache_lowmem_prunes - amount of times MySQL has had to clear a full query cache
    #   query_cache_limit - the biggest result allowed per query
    #   query_cache_size - the size of the query cache (if it's 0, query cache is disabled)
    #   
    # QUERY CACHE CALCULATIONS:
    #   query_cache_efficiency - % of SELECTS that pull from query cache (should be > 20%)
    my $query_cache_efficiency = sprintf("%.1f",($mystat{'Qcache_hits'} / ($mystat{'Com_select'} + $mystat{'Qcache_hits'})) * 100);
    #   qcache_pct_free - % of query cache free
    my $qcache_pct_free = sprintf("%.1f",($mystat{'Qcache_free_memory'} / $myvar{'query_cache_size'}) * 100);
    my $problem = 0;
    print $info." $query_cache_efficiency% of SELECTS used query cache (Stats: $qcache_pct_free% free, "
        .hr_bytes_rnd($myvar{'query_cache_size'})." total, $mystat{'Qcache_lowmem_prunes'} prunes)\n";
    # When the prunes get to be pretty high, either too many queries are making it into the query cache
    # that don't belong there, or the queries are too big and the query_cache_limit needs to be reduced.
    if ($mystat{'Qcache_lowmem_prunes'} > 50) {
        print $bad." Cache cleared $mystat{'Qcache_lowmem_prunes'} times due to low memory - increase query_cache_size\n";
        $problem = 1;
    }
    # If the query_cache_efficiency is less than 20%, then too many selects are not being pulled from
    # the query_cache.  This could mean that the results exceed query_cache_limit, or the queries are
    # using the SQL_NO_CACHE modifier (which throw these recommendations way off).
    if ($query_cache_efficiency <= 20) {
        print $bad." Very few queries used query cache - increase query_cache_limit or adjust queries\n";
        $problem = 1;
    }
    # If the query_cache efficiency is over 20% and the prunes are under 50, then everything should be good.
    if ($problem == 0) {
        print $good." Your query cache is configured properly\n";
    }
}

sub check_sort {
    print "------ SORTING ------\n";
    # SORTING VARIABLES/STATUS:
    #   read_rnd_buffer_size - sorts are read from this buffer after the sort is complete, helps ORDER BY
    #   sort_buffer_size - per-thread buffer used for sorting, helps ORDER/GROUP BY
    #   Sort_merge_passes - number of merge passes that the sort algorithm has had to do (bad if high, raise sort_buffer_size)
    #   Sort_range - sorts done using ranges
    #   Sort_scan - sorts done by scanning table
    # LOGIC:
    #   If a SELECT does a sequential table scan, then Sort_scan gets incremented
    #   If a SELECT retrieves a range of rows, then Sort_range gets incremented
    #   If a sort is too big for the sort_buffer_size, temporary tables are made, sorted, and then Sort_merge_passes gets incremented
    my $total_sorts = $mystat{'Sort_scan'} + $mystat{'Sort_range'};
    if ($total_sorts == 0) {
        print $info." No sorts have been performed - no recommendations can be made\n";
        return 0;
    }
    my $temp_sort_table_pct = int(($mystat{'Sort_merge_passes'} / $total_sorts) * 100);
    print $info." $total_sorts sorts have occurred with $temp_sort_table_pct% requiring temporary tables\n";
    if ($temp_sort_table_pct > 10) {
        print $bad." Increase sorting performance by raising sort_buffer_size and read_rnd_buffer_size\n";
    } else {
        print $good." Your sorting buffers are reasonable\n";
    }
}

sub check_join {
    print "------ JOINS ------\n";
    # JOIN VARIABLES/STATUS:
    #   join_buffer_size - buffer used to join tables when indexes can't be utilized
    #   Select_full_join - number of joins not using indexes
    #   Select_range_check - number of joins where MySQL was uncertain on whether it could use indexes to find a range
    # LOGIC:
    #   If Select_full_join or Select_range_check are greater than 0, then the join queries need to be fixed
    #   Technically, the performance hit of Select_range_check is as bad as Select_full_join, so they should be summed
    my $joins_without_indexes = $mystat{'Select_range_check'} + $mystat{'Select_range_check'};
    if ($joins_without_indexes > 0) {
        print $info." $joins_without_indexes joins did not use indexes, join buffer is ".hr_bytes_rnd($myvar{'join_buffer_size'})."\n";
        print $bad." Adjust your joins to utilize indexes (if impossible, increase join_buffer_size)\n";
        print $bad." NOTE: This script will always suggest raising the join_buffer_size\n";
    } else {
        print $good." Your joins are using indexes appropriately, join buffer is not necessary\n";
    }
}

sub check_temporary_tables {
    print "------ TEMPORARY TABLES ------\n";
    # TEMPORARY TABLE VARIABLES/STATUS:
    #   Created_tmp_disk_tables - number of temporary tables created on disk
    #   Created_tmp_tables - number of temporary tables created in memory
    #   max_heap_table_size - maximum size for MEMORY tables (also limits tmp_table_size)
    #   tmp_table_size - max size for all temporary tables in memory (limited by max_heap_table_size)
    # LOGIC:
    #   If the ratio of Created_tmp_disk_tables to Created_tmp_tables increases, this is bad
    #   To reduce temporary tables on disk, the tmp_table_size needs to be increased (and possibly max_heap_table_size)
    if ($mystat{'Created_tmp_tables'} == 0) {
        print $info." No temporary tables have been created since the server started\n";
        return 0;
    }
    my $tmp_disk_pct = int(($mystat{'Created_tmp_disk_tables'} / $mystat{'Created_tmp_tables'}) * 100);
    if ($tmp_disk_pct > 25) {
        print $bad." $tmp_disk_pct% of temp tables were created on disk\n";
        print $bad." Increase tmp_table_size (which is limited by max_heap_table_size)\n";
    } else {
        print $good." $tmp_disk_pct% of temp tables were created on disk - this is reasonable\n";
    }
}

sub check_other_buffers {
    print "------ OTHER BUFFERS ------\n";
    #  bulk_insert_buffer_size = buffer for large inserts (default: 8M)
    print $info." Your bulk_insert_buffer_size is ".hr_bytes_rnd($myvar{'bulk_insert_buffer_size'}).
        " - increase this for large bulk inserts\n";
}

sub performance_options {
    print "------ PERFORMANCE OPTIONS ------\n";
    # concurrent_insert = enables simultaneous insert/select on MyISAM tables w/o holes
    # It's ON/OFF in MySQL 4.1 and 0/1 in MySQL 5.x
    if ($myvar{'concurrent_insert'} eq "ON" || $myvar{'concurrent_insert'} > 0) {
        print $good." Concurrent inserts/selects in MyISAM tables are enabled\n";
    } else {
        print $bad." Concurrent inserts/selects in MyISAM tables are disabled - enable concurrent_insert\n";
    }
}

# ---------------------------------------------------------------------------
# BEGIN 'MAIN'
# ---------------------------------------------------------------------------
print "------------------------------------------------------------------------------\n".
    $info." MySQL High-Performance Tuner - Major Hayden <major.hayden\@rackspace.com>\n";
os_setup;                       # Set up some OS variables
setup_mysql_login;              # Gotta login first
get_all_vars;                   # Toss variables/status into hashes
validate_mysql_version;         # Check current MySQL version
mysql_initial_stats;            # Print some basic server stats
check_memory;					# Check memory usage
check_slow_queries;             # Check slow query percentage
check_connections;              # Check connection limits/usage
check_key_buffer;               # Check key buffer
check_query_cache;              # Check query caching
check_sort;                     # Check sorting buffers
check_join;                     # Check join buffers
check_temporary_tables;         # Check temporary table creation
check_other_buffers;
performance_options;
print "------------------------------------------------------------------------------\n";
# ---------------------------------------------------------------------------
# END 'MAIN'
# ---------------------------------------------------------------------------