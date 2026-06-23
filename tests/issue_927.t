#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';

use Test::More tests => 2;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Load mysqltuner.pl as a library
my $script_dir = dirname( abs_path(__FILE__) );
my $script =
  abs_path( File::Spec->catfile( $script_dir, '..', 'mysqltuner.pl' ) );
require $script;
require './tests/MySQLTuner/TestHelper.pm';

# Mock global variables
our %myvar;
our %mystat;
our %mycalc;
our $physical_memory;
our $swap_memory;
our @generalrec;
our @adjvars;

# Setup common mocks globally
no warnings 'redefine';
no warnings 'uninitialized';
*main::debugprint   = sub { };
*main::is_int       = sub { return $_[0] && $_[0] =~ /^\d+$/ };
*main::human_size   = sub { return $_[0] };
*main::hr_bytes     = sub { return $_[0] };
*main::hr_bytes_rnd = sub { return $_[0] };
*main::hr_num       = sub {
    my $val = shift;

    # simple formatting for tests
    1 while $val =~ s/(\d+)(\d{3})/$1,$2/;
    return $val;
};
*main::percentage               = sub { return 0 };
*main::select_one               = sub { return 0 };
*main::select_array             = sub { return () };
*main::mysql_version_ge         = sub { return 1 };
*main::mysql_version_le         = sub { return 0 };
*main::mysql_version_eq         = sub { return 0 };
*main::execute_system_command   = sub { return "" };
*main::get_pf_memory            = sub { return 0 };
*main::get_gcache_memory        = sub { return 0 };
*main::is_remote                = sub () { return 0 };
*main::mysql_cloud_discovery    = sub { return "none" };
*main::pretty_uptime            = sub { return "1 day" };
*main::get_other_process_memory = sub { return 0 };

subtest 'Query cache efficiency on standard MySQL' => sub {
    $main::physical_memory = 32 * 1024 * 1024 * 1024;
    $main::swap_memory     = 4 * 1024 * 1024 * 1024;

    %main::myvar = (
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
    %main::mystat = (
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
    %main::mycalc     = ();
    @main::generalrec = ();
    @main::adjvars    = ();

    eval { main::calculations(); };
    ok( !$@, "calculations completed without crash" );
    is( $main::mycalc{'query_cache_efficiency'}, "40.0",
"MySQL efficiency calculation is Qcache_hits / (Com_select + Qcache_hits) = 40%"
    );

    my @good_prints;
    my @bad_prints;
    my @info_prints;
    local *main::goodprint      = sub { push @good_prints, $_[0] };
    local *main::badprint       = sub { push @bad_prints,  $_[0] };
    local *main::infoprint      = sub { push @info_prints, $_[0] };
    local *main::subheaderprint = sub { };

    eval { main::mysql_stats(); };
    ok( !$@, "mysql_stats completed without crash" );

    my $found_msg = "";
    for my $msg ( @good_prints, @bad_prints ) {
        if ( $msg =~ /Query cache efficiency/ ) {
            $found_msg = $msg;
            last;
        }
    }

    like(
        $found_msg,
        qr/Query cache efficiency: 40\.0% \(1,000 cached \/ 2,500 selects\)/,
"Display text shows correct MySQL hit ratio and total selects (2,500 selects)"
    );
};

subtest 'Query cache efficiency on MariaDB' => sub {
    $main::physical_memory = 32 * 1024 * 1024 * 1024;
    $main::swap_memory     = 4 * 1024 * 1024 * 1024;

    %main::myvar = (
        'version'                         => '10.11.14-MariaDB',
        'version_comment'                 => 'MariaDB Server',
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
    %main::mystat = (
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
    %main::mycalc     = ();
    @main::generalrec = ();
    @main::adjvars    = ();

    eval { main::calculations(); };
    ok( !$@, "calculations completed without crash" );
    is( $main::mycalc{'query_cache_efficiency'},
        "66.7",
        "MariaDB efficiency calculation is Qcache_hits / Com_select = 66.7%" );

    my @good_prints;
    my @bad_prints;
    my @info_prints;
    local *main::goodprint      = sub { push @good_prints, $_[0] };
    local *main::badprint       = sub { push @bad_prints,  $_[0] };
    local *main::infoprint      = sub { push @info_prints, $_[0] };
    local *main::subheaderprint = sub { };

    eval { main::mysql_stats(); };
    ok( !$@, "mysql_stats completed without crash" );

    my $found_msg = "";
    for my $msg ( @good_prints, @bad_prints ) {
        if ( $msg =~ /Query cache efficiency/ ) {
            $found_msg = $msg;
            last;
        }
    }

    like(
        $found_msg,
        qr/Query cache efficiency: 66\.7% \(1,000 cached \/ 1,500 selects\)/,
"Display text shows correct MariaDB hit ratio and total selects without double-counting (1,500 selects)"
    );
};

1;
