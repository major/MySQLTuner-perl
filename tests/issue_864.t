#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
no warnings 'once';

use Test::More tests => 6;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;
require './tests/MySQLTuner/TestHelper.pm';

# Mock global variables
our %myvar;
our %mystat;
our %mycalc;
our $physical_memory;
our $swap_memory;

# Setup common mocks globally
no warnings 'redefine';
no warnings 'uninitialized';
*main::debugprint = sub { };
*main::is_int = sub { return $_[0] && $_[0] =~ /^\d+$/ };
*main::human_size = sub { return $_[0] };
*main::hr_bytes = sub { return $_[0] };
*main::percentage = sub { return 0 };
*main::badprint = sub { };
*main::infoprint = sub { };
*main::select_one = sub { return 0 };
*main::select_array = sub { return () };
*main::mysql_version_ge = sub { return 1 };
*main::mysql_version_le = sub { return 0 };
*main::mysql_version_eq = sub { return 0 };
*main::execute_system_command = sub { return "" };
*main::get_pf_memory = sub { return 0 };
*main::get_gcache_memory = sub { return 0 };
*main::is_remote = sub () { return 0 };
*main::mysql_cloud_discovery = sub { return "none" };

subtest 'Issue #864: per-thread memory buffer calculations' => sub {


    $main::physical_memory = 32 * 1024 * 1024 * 1024;
    $main::swap_memory = 4 * 1024 * 1024 * 1024;

    %main::myvar = (
        'version' => '8.0.30',
        'read_buffer_size' => 1024,
        'read_rnd_buffer_size' => 1024,
        'sort_buffer_size' => 1024,
        'thread_stack' => 1024,
        'join_buffer_size' => 1024,
        'binlog_cache_size' => 1024,
        'tmp_table_size' => 1024,
        'max_heap_table_size' => 2048,
        'max_connections' => 10,
        'key_buffer_size' => 5000,
        'innodb_buffer_pool_size' => 10000,
        'innodb_additional_mem_pool_size' => 1024,
        'innodb_log_buffer_size' => 1024,
        'query_cache_size' => 1024,
        'aria_pagecache_buffer_size' => 1024,
        'long_query_time' => 10,
        'log_bin' => 'OFF',
        'have_innodb' => 'YES',
        'open_files_limit' => 1024,
        'thread_cache_size' => 8,
        'concurrent_insert' => 'AUTO',
    );
    %main::mystat = (
        'Questions' => 100,
        'Max_used_connections' => 5,
        'Uptime' => 86400,
        'Qcache_hits' => 100,
        'Com_select' => 100,
        'Qcache_free_memory' => 512,
        'Qcache_lowmem_prunes' => 0,
        'Connections' => 100,
        'Aborted_connects' => 0,
        'Key_read_requests' => 100,
        'Key_reads' => 0,
        'Key_write_requests' => 100,
        'Key_writes' => 0,
        'Slow_queries' => 0,
        'Key_blocks_unused' => 100,
        'Table_locks_immediate' => 100,
        'Table_locks_waited' => 0,
        'Created_tmp_tables' => 10,
        'Opened_tables' => 10,
        'Open_tables' => 10,
        'Threads_cached' => 5,
    );
    %main::mycalc = ();

    eval { main::calculations(); };
    if ($@) {
        fail("calculations crashed: $@");
    } else {
        # Expected per_thread_buffers = 1024*6 + min(1024, 2048) = 1024*7 = 7168
        is($main::mycalc{'per_thread_buffers'}, 7168, "per_thread_buffers includes max_tmp_table_size")
            or diag("Actual per_thread_buffers: " . ($main::mycalc{'per_thread_buffers'} // 'undef'));
        # Expected server_buffers = 5000 (key) + 10000 (bp) + 1024 (add) + 1024 (log) + 1024 (qc) + 1024 (aria) = 19096
        is($main::mycalc{'server_buffers'}, 19096, "server_buffers does NOT include max_tmp_table_size")
            or diag("Actual server_buffers: " . ($main::mycalc{'server_buffers'} // 'undef'));
    }
};

subtest 'temptable_max_ram memory buffer calculations' => sub {


    $main::physical_memory = 32 * 1024 * 1024 * 1024;
    $main::swap_memory = 4 * 1024 * 1024 * 1024;

    %main::myvar = (
        'version' => '8.0.30',
        'read_buffer_size' => 1024,
        'read_rnd_buffer_size' => 1024,
        'sort_buffer_size' => 1024,
        'thread_stack' => 1024,
        'join_buffer_size' => 1024,
        'binlog_cache_size' => 1024,
        'tmp_table_size' => 1024 * 1024 * 1024, # 1 GB individual limit
        'max_heap_table_size' => 1024 * 1024 * 1024,
        'max_connections' => 10,
        'temptable_max_ram' => 2 * 1024 * 1024, # 2 MB global limit
        'key_buffer_size' => 5000,
        'innodb_buffer_pool_size' => 10000,
        'innodb_additional_mem_pool_size' => 1024,
        'innodb_log_buffer_size' => 1024,
        'query_cache_size' => 1024,
        'aria_pagecache_buffer_size' => 1024,
        'long_query_time' => 10,
        'log_bin' => 'OFF',
        'have_innodb' => 'YES',
        'open_files_limit' => 1024,
        'thread_cache_size' => 8,
        'concurrent_insert' => 'AUTO',
    );
    %main::mystat = (
        'Questions' => 100,
        'Max_used_connections' => 5,
        'Uptime' => 86400,
        'Qcache_hits' => 100,
        'Com_select' => 100,
        'Qcache_free_memory' => 512,
        'Qcache_lowmem_prunes' => 0,
        'Connections' => 100,
        'Aborted_connects' => 0,
        'Key_read_requests' => 100,
        'Key_reads' => 0,
        'Key_write_requests' => 100,
        'Key_writes' => 0,
        'Slow_queries' => 0,
        'Key_blocks_unused' => 100,
        'Table_locks_immediate' => 100,
        'Table_locks_waited' => 0,
        'Created_tmp_tables' => 10,
        'Opened_tables' => 10,
        'Open_tables' => 10,
        'Threads_cached' => 5,
    );
    %main::mycalc = ();

    eval { main::calculations(); };
    if ($@) {
        fail("calculations crashed: $@");
    } else {
        # per_thread_buffers_without_tmp = 1024 * 6 = 6144
        # max_connections = 10
        # max_tmp_limit = 1GB * 10 = 10GB
        # actual_tmp_ram = min(2MB, 10GB) = 2MB (2097152)
        # total_per_thread_buffers = 6144 * 10 + 2097152 = 61440 + 2097152 = 2158592
        is($main::mycalc{'total_per_thread_buffers'}, 2158592, "total_per_thread_buffers respects temptable_max_ram")
            or diag("Actual: " . ($main::mycalc{'total_per_thread_buffers'} // 'undef'));
    }
};

subtest 'temptable_max_ram non-binding (large) memory buffer calculations' => sub {


    $main::physical_memory = 32 * 1024 * 1024 * 1024;
    $main::swap_memory = 4 * 1024 * 1024 * 1024;

    %main::myvar = (
        'version' => '8.0.30',
        'read_buffer_size' => 1024,
        'read_rnd_buffer_size' => 1024,
        'sort_buffer_size' => 1024,
        'thread_stack' => 1024,
        'join_buffer_size' => 1024,
        'binlog_cache_size' => 1024,
        'tmp_table_size' => 1024, # 1 KB individual limit
        'max_heap_table_size' => 1024,
        'max_connections' => 10,
        'temptable_max_ram' => 2 * 1024 * 1024, # 2 MB global limit (non-binding since max_tmp_limit is 10 KB)
        'key_buffer_size' => 5000,
        'innodb_buffer_pool_size' => 10000,
        'innodb_additional_mem_pool_size' => 1024,
        'innodb_log_buffer_size' => 1024,
        'query_cache_size' => 1024,
        'aria_pagecache_buffer_size' => 1024,
        'long_query_time' => 10,
        'log_bin' => 'OFF',
        'have_innodb' => 'YES',
        'open_files_limit' => 1024,
        'thread_cache_size' => 8,
        'concurrent_insert' => 'AUTO',
    );
    %main::mystat = (
        'Questions' => 100,
        'Max_used_connections' => 5,
        'Uptime' => 86400,
        'Qcache_hits' => 100,
        'Com_select' => 100,
        'Qcache_free_memory' => 512,
        'Qcache_lowmem_prunes' => 0,
        'Connections' => 100,
        'Aborted_connects' => 0,
        'Key_read_requests' => 100,
        'Key_reads' => 0,
        'Key_write_requests' => 100,
        'Key_writes' => 0,
        'Slow_queries' => 0,
        'Key_blocks_unused' => 100,
        'Table_locks_immediate' => 100,
        'Table_locks_waited' => 0,
        'Created_tmp_tables' => 10,
        'Opened_tables' => 10,
        'Open_tables' => 10,
        'Threads_cached' => 5,
    );
    %main::mycalc = ();

    eval { main::calculations(); };
    if ($@) {
        fail("calculations crashed: $@");
    } else {
        # per_thread_buffers_without_tmp = 1024 * 6 = 6144
        # max_connections = 10
        # max_tmp_limit = 1KB * 10 = 10KB
        # actual_tmp_ram = min(2MB, 10KB) = 10KB (10240)
        # total_per_thread_buffers = 6144 * 10 + 10240 = 61440 + 10240 = 71680
        is($main::mycalc{'total_per_thread_buffers'}, 71680, "total_per_thread_buffers respects temptable_max_ram when non-binding")
            or diag("Actual: " . ($main::mycalc{'total_per_thread_buffers'} // 'undef'));
    }
};

subtest 'temptable_max_ram bypass when internal_tmp_mem_storage_engine is MEMORY' => sub {
    $main::physical_memory = 32 * 1024 * 1024 * 1024;
    $main::swap_memory = 4 * 1024 * 1024 * 1024;

    %main::myvar = (
        'version' => '8.0.30',
        'read_buffer_size' => 1024,
        'read_rnd_buffer_size' => 1024,
        'sort_buffer_size' => 1024,
        'thread_stack' => 1024,
        'join_buffer_size' => 1024,
        'binlog_cache_size' => 1024,
        'tmp_table_size' => 1024 * 1024 * 1024, # 1 GB individual limit
        'max_heap_table_size' => 1024 * 1024 * 1024,
        'max_connections' => 10,
        'temptable_max_ram' => 2 * 1024 * 1024, # 2 MB global limit
        'internal_tmp_mem_storage_engine' => 'MEMORY', # Bypass!
        'key_buffer_size' => 5000,
        'innodb_buffer_pool_size' => 10000,
        'innodb_additional_mem_pool_size' => 1024,
        'innodb_log_buffer_size' => 1024,
        'query_cache_size' => 1024,
        'aria_pagecache_buffer_size' => 1024,
        'long_query_time' => 10,
        'log_bin' => 'OFF',
        'have_innodb' => 'YES',
        'open_files_limit' => 1024,
        'thread_cache_size' => 8,
        'concurrent_insert' => 'AUTO',
    );
    %main::mystat = (
        'Questions' => 100,
        'Max_used_connections' => 5,
        'Uptime' => 86400,
        'Qcache_hits' => 100,
        'Com_select' => 100,
        'Qcache_free_memory' => 512,
        'Qcache_lowmem_prunes' => 0,
        'Connections' => 100,
        'Aborted_connects' => 0,
        'Key_read_requests' => 100,
        'Key_reads' => 0,
        'Key_write_requests' => 100,
        'Key_writes' => 0,
        'Slow_queries' => 0,
        'Key_blocks_unused' => 100,
        'Table_locks_immediate' => 100,
        'Table_locks_waited' => 0,
        'Created_tmp_tables' => 10,
        'Opened_tables' => 10,
        'Open_tables' => 10,
        'Threads_cached' => 5,
    );
    %main::mycalc = ();

    eval { main::calculations(); };
    if ($@) {
        fail("calculations crashed: $@");
    } else {
        is($main::mycalc{'total_per_thread_buffers'}, 10737479680, "total_per_thread_buffers bypasses temptable_max_ram and uses linear calculation when MEMORY engine is used")
            or diag("Actual: " . ($main::mycalc{'total_per_thread_buffers'} // 'undef'));
    }
};

subtest 'temptable_max_ram bypass for MariaDB' => sub {
    $main::physical_memory = 32 * 1024 * 1024 * 1024;
    $main::swap_memory = 4 * 1024 * 1024 * 1024;

    %main::myvar = (
        'version' => '10.6.15-MariaDB', # Bypass!
        'read_buffer_size' => 1024,
        'read_rnd_buffer_size' => 1024,
        'sort_buffer_size' => 1024,
        'thread_stack' => 1024,
        'join_buffer_size' => 1024,
        'binlog_cache_size' => 1024,
        'tmp_table_size' => 1024 * 1024 * 1024,
        'max_heap_table_size' => 1024 * 1024 * 1024,
        'max_connections' => 10,
        'temptable_max_ram' => 2 * 1024 * 1024,
        'key_buffer_size' => 5000,
        'innodb_buffer_pool_size' => 10000,
        'innodb_additional_mem_pool_size' => 1024,
        'innodb_log_buffer_size' => 1024,
        'query_cache_size' => 1024,
        'aria_pagecache_buffer_size' => 1024,
        'long_query_time' => 10,
        'log_bin' => 'OFF',
        'have_innodb' => 'YES',
        'open_files_limit' => 1024,
        'thread_cache_size' => 8,
        'concurrent_insert' => 'AUTO',
    );
    %main::mystat = (
        'Questions' => 100,
        'Max_used_connections' => 5,
        'Uptime' => 86400,
        'Qcache_hits' => 100,
        'Com_select' => 100,
        'Qcache_free_memory' => 512,
        'Qcache_lowmem_prunes' => 0,
        'Connections' => 100,
        'Aborted_connects' => 0,
        'Key_read_requests' => 100,
        'Key_reads' => 0,
        'Key_write_requests' => 100,
        'Key_writes' => 0,
        'Slow_queries' => 0,
        'Key_blocks_unused' => 100,
        'Table_locks_immediate' => 100,
        'Table_locks_waited' => 0,
        'Created_tmp_tables' => 10,
        'Opened_tables' => 10,
        'Open_tables' => 10,
        'Threads_cached' => 5,
    );
    %main::mycalc = ();

    eval { main::calculations(); };
    if ($@) {
        fail("calculations crashed: $@");
    } else {
        is($main::mycalc{'total_per_thread_buffers'}, 10737479680, "total_per_thread_buffers bypasses temptable_max_ram and uses linear calculation for MariaDB")
            or diag("Actual: " . ($main::mycalc{'total_per_thread_buffers'} // 'undef'));
    }
};

subtest 'temptable_max_mmap disk space recommendations check' => sub {
    no warnings 'redefine';
    my $badprint_called = 0;
    my $goodprint_called = 0;
    
    local *main::badprint = sub { $badprint_called = 1 if $_[0] =~ /temptable_max_mmap/ };
    local *main::goodprint = sub { $goodprint_called = 1 if $_[0] =~ /temptable_max_mmap/ };
    local *main::is_remote = sub { return 0 };
    local *main::which = sub { return "/bin/df" };
    
    # Mock execute_system_command to return df output with low available space (100 KB = 102400 bytes)
    local *main::execute_system_command = sub {
        return (
            "Filesystem     1024-blocks      Used Available Capacity Mounted on",
            "/dev/sda1         20511312  15101032     100      99% /tmp"
        );
    };

    %main::myvar = (
        'temptable_max_mmap' => 1024 * 1024 * 1024, # 1 GB limit
        'tmpdir' => '/tmp',
        'log_bin' => 'OFF',
        'version' => '8.0.30',
        'max_connections' => 10,
        'long_query_time' => 10,
        'query_cache_size' => 0,
        'thread_cache_size' => 8,
        'concurrent_insert' => 'AUTO',
    );
    %main::mystat = (
        'Questions' => 100,
        'Connections' => 10,
        'Bytes_sent' => 1000,
        'Bytes_received' => 1000,
        'Created_tmp_tables' => 0,
        'Uptime' => 86400,
        'Open_tables' => 10,
        'Threads_created' => 2,
    );
    %main::mycalc = (
        'pct_reads' => 50,
        'pct_writes' => 50,
        'pct_temp_disk' => 0,
        'thread_cache_hit_rate' => 90,
        'total_sorts' => 0,
        'joins_without_indexes_per_day' => 0,
    );
    @main::generalrec = ();

    eval { main::mysql_stats(); };
    if ($@) {
        fail("mysql_stats crashed: $@");
    } else {
        ok($badprint_called, "badprint warns about temptable_max_mmap exceeding disk space");
        my ($rec) = grep { $_ =~ /Reduce temptable_max_mmap/ } @main::generalrec;
        ok($rec, "recommendation to reduce temptable_max_mmap added");
    }

    # Now test the case where mmap limit is compatible with available disk space (10 GB available = 10485760 KB)
    $badprint_called = 0;
    $goodprint_called = 0;
    local *main::execute_system_command = sub {
        return (
            "Filesystem     1024-blocks      Used Available Capacity Mounted on",
            "/dev/sda1         20511312  15101032 10485760       50% /tmp"
        );
    };
    @main::generalrec = ();

    eval { main::mysql_stats(); };
    ok($goodprint_called, "goodprint confirms temptable_max_mmap is compatible with disk space");
    ok(!$badprint_called, "no warning when temptable_max_mmap is compatible");
};

1;
