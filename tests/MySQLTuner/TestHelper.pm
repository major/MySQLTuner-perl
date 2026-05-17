package MySQLTuner::TestHelper;
use strict;
use warnings;

# Initialize common mock state for MySQLTuner tests
sub reset_state {
    # Provide defaults to prevent uninitialized value warnings
    $main::good = '[OK]';
    $main::bad  = '[!!]';
    $main::info = '[--]';
    $main::deb  = '[DG]';
    $main::end  = '';
    
    @main::adjvars = ();
    @main::generalrec = ();
    @main::modeling = ();
    
    $main::mysqllogin = "-u root";
    $main::mysqlcmd = "mysql";
    $main::mysqladmincmd = "mysqladmin";
    $main::devnull = "/dev/null";
    
    %main::myvar = (
        have_innodb => 'YES',
        version => '8.0.35',
        version_comment => 'MySQL Community Server (GPL)',
        table_open_cache => 400,
        table_open_cache_instances => 1,
        max_connections => 151,
        query_cache_size => 0,
        thread_cache_size => 8,
        aria_pagecache_buffer_size => 0,
        key_buffer_size => 8 * 1024 * 1024,
        innodb_buffer_pool_size => 128 * 1024 * 1024,
        innodb_log_buffer_size => 8 * 1024 * 1024,
        innodb_additional_mem_pool_size => 0,
        innodb_file_per_table => 'ON',
        log_bin => 'OFF',
        concurrent_insert => 'AUTO',
        open_files_limit => 1024,
        long_query_time => 10,
        hostname => 'localhost',
        datadir => '/var/lib/mysql/',
        tmp_table_size => 16 * 1024 * 1024,
        max_heap_table_size => 16 * 1024 * 1024,
        key_cache_block_size => 1024,
        log_error => '/var/log/mysql/error.log'
    );
    
    %main::mystat = (
        Questions => 100,
        Uptime => 86400,
        Max_used_connections => 10,
        Connections => 100,
        Aborted_connects => 0,
        Key_read_requests => 100,
        Key_reads => 0,
        Key_write_requests => 100,
        Key_writes => 0,
        Qcache_hits => 0,
        Com_select => 0,
        Com_delete => 0,
        Com_insert => 0,
        Com_update => 0,
        Com_replace => 0,
        Sort_scan => 0,
        Sort_range => 0,
        Sort_merge_passes => 0,
        Select_range_check => 0,
        Select_full_join => 0,
        Created_tmp_tables => 0,
        Created_tmp_disk_tables => 0,
        Opened_tables => 100,
        Open_tables => 100,
        Threads_cached => 5,
        Threads_created => 1,
        Table_locks_immediate => 100,
        Table_locks_waited => 0,
        Innodb_buffer_pool_reads => 0,
        Innodb_buffer_pool_read_requests => 100,
        Table_open_cache_hits => 100,
        Table_open_cache_misses => 10,
        Open_files => 50,
        Slow_queries => 0,
        Key_blocks_unused => 0,
    );
    
    %main::mycalc = (
        table_cache_hit_rate => 10,
        pct_reads => 50,
        pct_writes => 50,
        total_sorts => 0,
        joins_without_indexes_per_day => 0,
        thread_cache_hit_rate => 100,
        pct_temp_sort_table => 0,
        pct_temp_disk => 0,
        pct_connections_used => 10,
        pct_connections_aborted => 0,
        pct_max_used_memory => 10,
        pct_max_physical_memory => 10,
        pct_slow_queries => 0,
        query_cache_efficiency => 100,
        query_cache_prunes_per_day => 0,
        server_buffers => 128 * 1024 * 1024,
        per_thread_buffers => 2 * 1024 * 1024,
        max_peak_memory => 256 * 1024 * 1024,
        max_used_memory => 128 * 1024 * 1024,
        max_tmp_table_size => 16 * 1024 * 1024,
    );
    
    $main::physical_memory = 16 * 1024 * 1024 * 1024;
    $main::swap_memory = 2 * 1024 * 1024 * 1024;
    $main::architecture = 64;
    $main::doremote = 0;
}

sub mock_printers {
    no warnings 'redefine';
    *main::infoprint = sub { };
    *main::goodprint = sub { };
    *main::badprint = sub { };
    *main::subheaderprint = sub { };
    *main::debugprint = sub { };
}

1;
