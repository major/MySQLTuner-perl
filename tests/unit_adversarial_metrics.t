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
# [REQ-TEST-01] Adversarial Metric Testing: Zero Values & Fuzzing
# =====================================================================
subtest 'REQ-TEST-01: Adversarial zero boundaries & uninitialized variables' => sub {
    # Test all pure functions with entirely empty hashes (undef / 0)
    my $empty_vars  = {};
    my $empty_stats = {};

    # 1. calculate_server_buffers
    my $sb = eval { main::calculate_server_buffers($empty_vars) };
    ok(!$@, "calculate_server_buffers does not die on empty hash: $@");
    is($sb, 0, "Server buffers is 0");

    # 2. calculate_per_thread_buffers
    my $tb = eval { main::calculate_per_thread_buffers($empty_vars, $empty_stats) };
    ok(!$@, "calculate_per_thread_buffers does not die on empty hash: $@");
    is($tb->{per_thread_buffers}, 0, "Per-thread buffers is 0");
    is($tb->{total_per_thread_buffers}, 0, "Total per-thread buffers is 0");
    is($tb->{max_total_per_thread_buffers}, 0, "Max total per-thread buffers is 0");

    # 3. calculate_memory_allocation with 0 physical RAM
    my $mem = eval { main::calculate_memory_allocation(0, 0, 0, 0, 0) };
    ok(!$@, "calculate_memory_allocation does not die on zero physical RAM: $@");
    is($mem->{pct_max_used_memory}, 0, "Used RAM pct is 0%");
    is($mem->{pct_max_physical_memory}, 0, "Peak RAM pct is 0%");

    # 4. calculate_query_cache_efficiency with zero queries & zero uptime
    my $qc = eval { main::calculate_query_cache_efficiency($empty_vars, $empty_stats, 0) };
    ok(!$@, "calculate_query_cache_efficiency does not die on empty hash: $@");
    is($qc->{query_cache_efficiency}, 0, "QC efficiency is 0");
    is($qc->{query_cache_prunes_per_day}, 0, "QC prunes per day is 0");

    # 5. calculate_key_buffer_ratios with empty stats
    my $kb = eval { main::calculate_key_buffer_ratios($empty_vars, $empty_stats) };
    ok(!$@, "calculate_key_buffer_ratios does not die on empty hash: $@");
    is($kb->{pct_keys_from_mem}, 0, "Keys from mem is 0");
    is($kb->{pct_wkeys_from_mem}, 0, "Wkeys from mem is 0");

    # 6. calculate_traffic_and_sort_ratios with 0 uptime, 0 questions, 0 connections
    my $tf = eval { main::calculate_traffic_and_sort_ratios($empty_vars, $empty_stats) };
    ok(!$@, "calculate_traffic_and_sort_ratios does not die on empty hash: $@");
    is($tf->{pct_slow_queries}, 0, "Slow queries is 0");
    is($tf->{joins_without_indexes_per_day}, 0, "Joins without indexes per day is 0");
    is($tf->{table_cache_hit_rate}, 100, "Table cache hit rate defaults to 100");
    is($tf->{thread_cache_hit_rate}, 100, "Thread cache hit rate defaults to 100");
};

# =====================================================================
# [REQ-TEST-01] Adversarial Scale-Up: Massive Scale Values (TB / PB / Max Uint64)
# =====================================================================
subtest 'REQ-TEST-01: Massive scale-up (Multi-Terabyte & 64-bit integer values)' => sub {
    my $one_tb = 1024 * 1024 * 1024 * 1024; # 1 TB
    my $massive_vars = {
        key_buffer_size         => 64 * 1024 * 1024 * 1024,   # 64 GB
        innodb_buffer_pool_size => 512 * 1024 * 1024 * 1024,  # 512 GB
        innodb_log_buffer_size  => 4 * 1024 * 1024 * 1024,    # 4 GB
        read_buffer_size        => 16 * 1024 * 1024,          # 16 MB
        sort_buffer_size        => 32 * 1024 * 1024,          # 32 MB
        max_connections         => 50000,                     # 50,000 connections
    };
    my $massive_stats = {
        Max_used_connections => 10000,
        Questions            => 5000000000,                   # 5 Billion questions
        Uptime               => 31536000,                     # 1 year (365 days)
    };

    my $sb = main::calculate_server_buffers($massive_vars);
    is($sb, 580 * 1024 * 1024 * 1024, "Server buffers correctly calculates 580 GB");

    my $tb = main::calculate_per_thread_buffers($massive_vars, $massive_stats);
    ok($tb->{total_per_thread_buffers} > 0, "Total per-thread buffers is positive");
    ok($tb->{max_total_per_thread_buffers} > 0, "Max total per-thread buffers is positive");

    # 1 TB physical RAM
    my $mem = main::calculate_memory_allocation(
        $sb,
        $tb->{total_per_thread_buffers},
        $tb->{max_total_per_thread_buffers},
        $one_tb,
        0
    );
    ok($mem->{pct_max_used_memory} > 0, "Max used RAM pct calculated cleanly on massive scale");
    ok($mem->{max_peak_memory} > $mem->{max_used_memory}, "Peak memory exceeds used memory");
};

# =====================================================================
# [REQ-TEST-01] Adversarial Degenerate Inputs: Negative Numbers & Malformed Data
# =====================================================================
subtest 'REQ-TEST-01: Degenerate inputs (negative & string inputs)' => sub {
    my $degenerate_vars = {
        key_buffer_size     => -100,
        read_buffer_size    => 'INVALID_STRING',
        tmp_table_size      => -50,
        max_heap_table_size => -20,
    };
    my $degenerate_stats = {
        Key_read_requests => -10,
        Questions         => -5,
        Uptime            => -1000,
    };

    my $sb = main::calculate_server_buffers($degenerate_vars);
    is($sb, 0, "Negative key_buffer_size ignored, server buffers is 0");

    my $tb = main::calculate_per_thread_buffers($degenerate_vars, $degenerate_stats);
    is($tb->{per_thread_buffers}, 0, "Invalid read_buffer_size ignored, per_thread_buffers is 0");

    my $qc = main::calculate_query_cache_efficiency($degenerate_vars, $degenerate_stats, 0);
    is($qc->{query_cache_efficiency}, 0, "Negative questions/requests handled without errors");

    my $tf = main::calculate_traffic_and_sort_ratios($degenerate_vars, $degenerate_stats);
    is($tf->{pct_slow_queries}, 0, "Negative questions yields 0% slow queries");
    is($tf->{joins_without_indexes_per_day}, 0, "Negative uptime yields 0 joins/day");
};

done_testing();
