#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# =====================================================================
# [REQ-METRIC-01] calculate_server_buffers
# =====================================================================
subtest 'REQ-METRIC-01: calculate_server_buffers pure metric' => sub {
    my $vars = {
        key_buffer_size                 => 16 * 1024 * 1024,
        innodb_buffer_pool_size         => 128 * 1024 * 1024,
        innodb_additional_mem_pool_size => 2 * 1024 * 1024, # Obsolete legacy var
        innodb_log_buffer_size          => 8 * 1024 * 1024,
        query_cache_size                => 16 * 1024 * 1024,
        aria_pagecache_buffer_size      => 32 * 1024 * 1024,
    };

    my $expected = (16 + 128 + 2 + 8 + 16 + 32) * 1024 * 1024;
    my $calc = main::calculate_server_buffers($vars);
    is($calc, $expected, "Sum of all server buffers matches exact bytes");

    # Test with undef / missing variables (e.g., MySQL 8.0 without query_cache)
    my $modern_vars = {
        key_buffer_size         => 32 * 1024 * 1024,
        innodb_buffer_pool_size => 512 * 1024 * 1024,
        innodb_log_buffer_size  => 16 * 1024 * 1024,
    };
    my $modern_calc = main::calculate_server_buffers($modern_vars);
    is($modern_calc, (32 + 512 + 16) * 1024 * 1024, "Calculates cleanly when legacy vars are omitted");

    # Empty hash
    is(main::calculate_server_buffers({}), 0, "Empty vars returns 0");
};

# =====================================================================
# [REQ-METRIC-01] calculate_per_thread_buffers
# =====================================================================
subtest 'REQ-METRIC-01: calculate_per_thread_buffers logic & TempTable cap' => sub {
    my $vars = {
        read_buffer_size     => 128 * 1024,
        read_rnd_buffer_size => 256 * 1024,
        sort_buffer_size     => 512 * 1024,
        thread_stack         => 256 * 1024,
        join_buffer_size     => 256 * 1024,
        binlog_cache_size    => 32 * 1024,
        tmp_table_size       => 16 * 1024 * 1024,
        max_heap_table_size  => 32 * 1024 * 1024,
        max_connections      => 100,
        version              => '8.0.35',
    };
    my $stats = {
        Max_used_connections => 20,
    };

    my $res = main::calculate_per_thread_buffers($vars, $stats);
    is($res->{max_tmp_table_size}, 16 * 1024 * 1024, "max_tmp_table_size takes minimum of tmp_table and max_heap");

    my $base_buffers = (128 + 256 + 512 + 256 + 256 + 32) * 1024;
    my $expected_per_thread = $base_buffers + (16 * 1024 * 1024);
    is($res->{per_thread_buffers}, $expected_per_thread, "Base per-thread buffer sum");
    is($res->{per_thread_buffers_without_tmp}, $base_buffers, "Per-thread buffer without tmp table");

    # MySQL 8.0 TempTable engine cap verification
    $vars->{internal_tmp_mem_storage_engine} = 'TempTable';
    $vars->{temptable_max_ram} = 64 * 1024 * 1024; # 64MB cap

    my $capped_res = main::calculate_per_thread_buffers($vars, $stats);
    # Total tmp connections would be 100 * 16MB = 1600MB > 64MB cap, so actual_tmp_ram is capped at 64MB
    my $expected_total = ($base_buffers * 100) + (64 * 1024 * 1024);
    is($capped_res->{total_per_thread_buffers}, $expected_total, "TempTable correctly caps total temp table RAM across max connections");

    # Used connections: 20 * 16MB = 320MB > 64MB cap, so actual_tmp_used_ram is capped at 64MB
    my $expected_used = ($base_buffers * 20) + (64 * 1024 * 1024);
    is($capped_res->{max_total_per_thread_buffers}, $expected_used, "TempTable correctly caps used temp table RAM across used connections");
};

# =====================================================================
# [REQ-METRIC-02] calculate_memory_allocation Invariants & Division-by-Zero
# =====================================================================
subtest 'REQ-METRIC-02: calculate_memory_allocation invariants & safety' => sub {
    my $server_buffers        = 1024 * 1024 * 1024; # 1GB
    my $total_per_thread      = 2048 * 1024 * 1024; # 2GB
    my $max_total_per_thread  = 512 * 1024 * 1024;  # 512MB
    my $physical_mem          = 4096 * 1024 * 1024; # 4GB
    my $pf_mem                = 128 * 1024 * 1024;  # 128MB

    my $res = main::calculate_memory_allocation(
        $server_buffers,
        $total_per_thread,
        $max_total_per_thread,
        $physical_mem,
        $pf_mem
    );

    is($res->{max_used_memory}, $server_buffers + $max_total_per_thread + $pf_mem, "Max used memory sum");
    is($res->{max_peak_memory}, $server_buffers + $total_per_thread + $pf_mem, "Max peak memory sum");
    ok($res->{pct_max_used_memory} > 0, "Non-zero used percentage");
    ok($res->{pct_max_physical_memory} > $res->{pct_max_used_memory}, "Peak percentage > Used percentage");

    # Invariant: Division by zero guard on zero physical memory
    my $zero_ram_res = main::calculate_memory_allocation(
        $server_buffers, $total_per_thread, $max_total_per_thread, 0, $pf_mem
    );
    is($zero_ram_res->{pct_max_used_memory}, 0, "Zero physical RAM yields 0% used without warning or die");
    is($zero_ram_res->{pct_max_physical_memory}, 0, "Zero physical RAM yields 0% peak without warning or die");

    # Invariant: Negative physical memory guard
    my $neg_ram_res = main::calculate_memory_allocation(
        $server_buffers, $total_per_thread, $max_total_per_thread, -100, $pf_mem
    );
    is($neg_ram_res->{pct_max_used_memory}, 0, "Negative physical RAM yields 0% used safely");
};

done_testing();
