#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Mock environment - set BEFORE require
$main::devnull = '/dev/null';
$main::is_win = 0;

my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# Mock helper functions to avoid printing or exiting
{
    no warnings 'redefine';
    *main::infoprint = sub { diag "INFO: $_[0]" };
    *main::badprint = sub { diag "BAD: $_[0]" };
    *main::goodprint = sub { diag "GOOD: $_[0]" };
    *main::debugprint = sub { diag "DEBUG: $_[0]" };
    *main::subheaderprint = sub { diag "SUBHEADER: $_[0]" };
    *main::get_pf_memory = sub { return 0 };
    *main::get_gcache_memory = sub { return 0 };
    *main::mysql_cloud_discovery = sub { return "none" };
    *main::pretty_uptime = sub { return "1 day" };
    *main::get_other_process_memory = sub { return 0 };
    *main::select_array = sub { return () };
    *main::select_one = sub { return 0 };
    *main::execute_system_command = sub { return "" };
    eval '*main::is_remote = sub () { return 0; };';
}

sub get_base_mock_vars {
    return (
        'version'                         => '5.7.35',
        'version_comment'                 => 'MySQL Community Server',
        'read_buffer_size'                => 1024,
        'read_rnd_buffer_size'            => 1024,
        'sort_buffer_size'                => 1024,
        'thread_stack'                    => 1024,
        'join_buffer_size'                => 1024,
        'binlog_cache_size'               => 1024,
        'tmp_table_size'                  => 1024,
        'max_heap_table_size'             => 1024,
        'max_connections'                 => 10,
        'key_buffer_size'                 => 5000,
        'innodb_buffer_pool_size'         => 10000,
        'innodb_additional_mem_pool_size' => 1024,
        'innodb_log_buffer_size'          => 1024,
        'query_cache_size'                => 64 * 1024 * 1024,
        'query_cache_type'                => 'ON',
        'aria_pagecache_buffer_size'      => 1024,
        'long_query_time'                 => 10,
        'log_bin'                         => 'OFF',
        'have_innodb'                     => 'YES',
        'open_files_limit'                => 1024,
        'thread_cache_size'               => 8,
        'concurrent_insert'               => 'AUTO',
    );
}

sub get_base_mock_stats {
    return (
        'Questions'             => 1500,
        'Max_used_connections'  => 5,
        'Uptime'                => 86400,
        'Qcache_free_memory'    => 32 * 1024 * 1024,
        'Qcache_hits'           => 1000,
        'Com_select'            => 1500,
        'Qcache_lowmem_prunes'  => 0,
        'Connections'           => 100,
        'Aborted_connects'      => 0,
        'Key_read_requests'     => 100,
        'Key_reads'             => 0,
        'Key_write_requests'    => 100,
        'Key_writes'            => 0,
        'Slow_queries'          => 0,
        'Key_blocks_unused'     => 100,
        'Table_locks_immediate' => 100,
        'Table_locks_waited'    => 0,
        'Created_tmp_tables'    => 10,
        'Opened_tables'         => 10,
        'Open_tables'           => 10,
        'Threads_cached'        => 5,
        'Bytes_sent'            => 1000,
        'Bytes_received'        => 1000,
        'Threads_created'       => 2,
    );
}

subtest 'slow_query_log is OFF' => sub {
    @main::generalrec = ();
    @main::adjvars = ();
    $main::physical_memory = 32 * 1024 * 1024 * 1024;
    $main::swap_memory     = 4 * 1024 * 1024 * 1024;
    
    %main::myvar = (
        get_base_mock_vars(),
        slow_query_log => 'OFF',
        log_slow_queries => 'ON', # Should be overridden by slow_query_log
    );
    %main::mystat = (
        get_base_mock_stats(),
    );
    %main::mycalc = ();

    eval { main::calculations(); main::mysql_stats(); };
    ok(!$@, 'calculations() did not crash') or diag("Crashed: $@");

    my $found = grep { /Enable the slow query log/ } @main::generalrec;
    ok($found, 'Should recommend enabling slow query log when slow_query_log is OFF');
};

subtest 'slow_query_log is ON' => sub {
    @main::generalrec = ();
    @main::adjvars = ();
    $main::physical_memory = 32 * 1024 * 1024 * 1024;
    $main::swap_memory     = 4 * 1024 * 1024 * 1024;
    
    %main::myvar = (
        get_base_mock_vars(),
        slow_query_log => 'ON',
        log_slow_queries => 'OFF', # Should be overridden by slow_query_log
    );
    %main::mystat = (
        get_base_mock_stats(),
    );
    %main::mycalc = ();

    eval { main::calculations(); main::mysql_stats(); };
    ok(!$@, 'calculations() did not crash') or diag("Crashed: $@");

    my $found = grep { /Enable the slow query log/ } @main::generalrec;
    ok(!$found, 'Should not recommend enabling slow query log when slow_query_log is ON');
};

subtest 'log_slow_queries fallback is OFF' => sub {
    @main::generalrec = ();
    @main::adjvars = ();
    $main::physical_memory = 32 * 1024 * 1024 * 1024;
    $main::swap_memory     = 4 * 1024 * 1024 * 1024;
    
    %main::myvar = (
        get_base_mock_vars(),
        log_slow_queries => 'OFF',
    );
    %main::mystat = (
        get_base_mock_stats(),
    );
    %main::mycalc = ();

    eval { main::calculations(); main::mysql_stats(); };
    ok(!$@, 'calculations() did not crash') or diag("Crashed: $@");

    my $found = grep { /Enable the slow query log/ } @main::generalrec;
    ok($found, 'Should recommend enabling slow query log when log_slow_queries fallback is OFF');
};

done_testing();
