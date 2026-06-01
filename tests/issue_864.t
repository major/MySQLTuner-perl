#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
no warnings 'once';

use Test::More tests => 2;
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

subtest 'Issue #864: per-thread memory buffer calculations' => sub {
    no warnings 'redefine';
    no warnings 'uninitialized';
    local *main::debugprint = sub { };
    local *main::is_int = sub { return $_[0] && $_[0] =~ /^\d+$/ };
    local *main::human_size = sub { return $_[0] };
    local *main::hr_bytes = sub { return $_[0] };
    local *main::percentage = sub { return 0 };
    local *main::badprint = sub { };
    local *main::infoprint = sub { };
    local *main::select_one = sub { return 0 };
    local *main::select_array = sub { return () };
    local *main::mysql_version_ge = sub { return 1 };
    local *main::mysql_version_le = sub { return 0 };
    local *main::mysql_version_eq = sub { return 0 };
    local *main::execute_system_command = sub { return "" };
    local *main::get_pf_memory = sub { return 0 };
    local *main::get_gcache_memory = sub { return 0 };
    local *main::is_remote = sub () { return 0 };
    local *main::mysql_cloud_discovery = sub { return "none" };

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
    no warnings 'redefine';
    no warnings 'uninitialized';
    local *main::debugprint = sub { };
    local *main::is_int = sub { return $_[0] && $_[0] =~ /^\d+$/ };
    local *main::human_size = sub { return $_[0] };
    local *main::hr_bytes = sub { return $_[0] };
    local *main::percentage = sub { return 0 };
    local *main::badprint = sub { };
    local *main::infoprint = sub { };
    local *main::select_one = sub { return 0 };
    local *main::select_array = sub { return () };
    local *main::mysql_version_ge = sub { return 1 };
    local *main::mysql_version_le = sub { return 0 };
    local *main::mysql_version_eq = sub { return 0 };
    local *main::execute_system_command = sub { return "" };
    local *main::get_pf_memory = sub { return 0 };
    local *main::get_gcache_memory = sub { return 0 };
    local *main::is_remote = sub () { return 0 };
    local *main::mysql_cloud_discovery = sub { return "none" };

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

1;
