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
# [REQ-METRIC-04, REQ-METRIC-05] calculate_query_cache_efficiency
# =====================================================================
subtest 'REQ-METRIC-04: calculate_query_cache_efficiency invariants' => sub {
    # 1. MySQL 8.0+ query cache removal check
    my $vars_80 = { version => '8.0.35' };
    my $stats = { Com_select => 1000, Qcache_hits => 500 };
    my $res_80 = main::calculate_query_cache_efficiency($vars_80, $stats, 0);
    is($res_80->{query_cache_efficiency}, 0, "MySQL 8.0 returns 0 for query cache efficiency");

    # 2. MySQL 5.7 query cache calculation
    my $vars_57 = {
        version          => '5.7.44',
        query_cache_size => 16 * 1024 * 1024,
    };
    my $stats_57 = {
        Com_select           => 1000,
        Qcache_hits          => 500,
        Qcache_free_memory   => 4 * 1024 * 1024, # 75% used
        Qcache_lowmem_prunes => 100,
        Uptime               => 86400,           # 1 day -> 100 prunes/day
    };
    my $res_57 = main::calculate_query_cache_efficiency($vars_57, $stats_57, 0);
    # Total selects = 1000 + 500 = 1500; Efficiency = 500 / 1500 * 100 = 33.3%
    is($res_57->{query_cache_efficiency}, "33.3", "MySQL 5.7 query cache efficiency 33.3%");
    is($res_57->{pct_query_cache_used}, "75.0", "Query cache used percentage 75.0%");
    is($res_57->{query_cache_prunes_per_day}, 100, "Query cache prunes per day is 100");

    # 3. MariaDB (MDEV-4981: Com_select already includes Qcache_hits)
    my $vars_maria = {
        version          => '10.11.6-MariaDB',
        query_cache_size => 16 * 1024 * 1024,
    };
    my $stats_maria = {
        Com_select           => 1000,
        Qcache_hits          => 500,
        Qcache_free_memory   => 8 * 1024 * 1024,
        Qcache_lowmem_prunes => 50,
        Uptime               => 43200, # 0.5 days -> 100 prunes/day
    };
    my $res_maria = main::calculate_query_cache_efficiency($vars_maria, $stats_maria, 1);
    # In MariaDB: efficiency = 500 / 1000 * 100 = 50.0%
    is($res_maria->{query_cache_efficiency}, "50.0", "MariaDB efficiency calculation honors MDEV-4981");
    is($res_maria->{query_cache_prunes_per_day}, 100, "MariaDB prunes per day calculated accurately");

    # 4. Invariant: zero selects, zero uptime
    my $res_zero = main::calculate_query_cache_efficiency({ version => '5.7.40' }, { Com_select => 0, Qcache_hits => 0, Uptime => 0 }, 0);
    is($res_zero->{query_cache_efficiency}, 0, "Zero selects yields 0 efficiency without division by zero");
    is($res_zero->{query_cache_prunes_per_day}, 0, "Zero uptime yields 0 prunes per day without division by zero");
};

# =====================================================================
# [REQ-METRIC-04, REQ-METRIC-05] calculate_key_buffer_ratios
# =====================================================================
subtest 'REQ-METRIC-04: calculate_key_buffer_ratios invariants' => sub {
    my $vars = {
        version              => '5.7.44',
        key_buffer_size      => 64 * 1024 * 1024,
        key_cache_block_size => 1024,
    };
    my $stats = {
        Key_blocks_unused              => 32768, # 32768 * 1024 = 32MB unused -> 50% used
        Key_read_requests              => 10000,
        Key_reads                      => 500,   # 100 - (500/10000 * 100) = 95.0%
        Key_write_requests             => 2000,
        Key_writes                     => 200,   # 200/2000 * 100 = 10.0%
        Aria_pagecache_read_requests   => 5000,
        Aria_pagecache_reads           => 50,    # 100 - (50/5000 * 100) = 99.0%
    };

    my $res = main::calculate_key_buffer_ratios($vars, $stats);
    is($res->{pct_key_buffer_used}, "50.0", "Key buffer used is 50.0%");
    is($res->{pct_keys_from_mem}, "95.0", "Key reads from memory is 95.0%");
    is($res->{pct_wkeys_from_mem}, "10.0", "Key writes ratio is 10.0%");
    is($res->{pct_aria_keys_from_mem}, "99.0", "Aria key reads from memory is 99.0%");

    # Invariant: zero requests
    my $zero_res = main::calculate_key_buffer_ratios($vars, {});
    is($zero_res->{pct_keys_from_mem}, 0, "Zero key read requests yields 0 without division by zero");
    is($zero_res->{pct_aria_keys_from_mem}, 0, "Zero aria requests yields 0 without division by zero");
    is($zero_res->{pct_wkeys_from_mem}, 0, "Zero write requests yields 0 without division by zero");
};

# =====================================================================
# [REQ-METRIC-04, REQ-METRIC-05] calculate_traffic_and_sort_ratios
# =====================================================================
subtest 'REQ-METRIC-04: calculate_traffic_and_sort_ratios invariants' => sub {
    my $vars = {
        max_connections  => 100,
        open_files_limit => 2000,
    };
    my $stats = {
        Questions                => 10000,
        Slow_queries             => 200,
        Connections              => 500,
        Aborted_connects         => 25,
        Max_used_connections     => 50,
        Sort_scan                => 300,
        Sort_range               => 200,
        Sort_merge_passes        => 50,
        Select_range_check       => 10,
        Select_full_join         => 15,
        Uptime                   => 86400,
        Opened_tables            => 1000,
        Created_tmp_tables       => 400,
        Created_tmp_disk_tables  => 80,
        Table_open_cache_hits    => 900,
        Table_open_cache_misses  => 100,
        Open_files               => 500,
        Table_locks_immediate    => 980,
        Table_locks_waited       => 20,
        Threads_created          => 50,
        Com_select               => 7000,
        Com_insert               => 2000,
        Com_update               => 1000,
        Com_delete               => 0,
        Com_replace              => 0,
    };

    my $res = main::calculate_traffic_and_sort_ratios($vars, $stats);
    is($res->{pct_slow_queries}, 2, "Slow queries is 2%");
    is($res->{pct_connections_used}, 50, "Connections used is 50%");
    is($res->{pct_connections_aborted}, "5.00", "Aborted connections is 5.00%");
    is($res->{total_sorts}, 500, "Total sorts is 500");
    is($res->{pct_temp_sort_table}, 10, "Temporary sort table is 10%");
    is($res->{joins_without_indexes_per_day}, 25, "Joins without indexes per day is 25");
    is($res->{pct_temp_disk}, 20, "Temporary disk tables percentage is 20%");
    is($res->{table_cache_hit_rate}, 90, "Table cache hit rate is 90%");
    is($res->{pct_files_open}, 25, "Open files percentage is 25%");
    is($res->{pct_table_locks_immediate}, 98, "Table locks immediate is 98%");
    is($res->{thread_cache_hit_rate}, 90, "Thread cache hit rate is 90%");
    is($res->{pct_reads}, 70, "Reads ratio is 70%");
    is($res->{pct_writes}, 30, "Writes ratio is 30%");

    # Invariants on zero metrics
    my $zero_res = main::calculate_traffic_and_sort_ratios({}, {});
    is($zero_res->{pct_slow_queries}, 0, "Zero questions yields 0% slow queries");
    is($zero_res->{pct_connections_used}, 0, "Zero max_conn yields 0% connections used");
    is($zero_res->{pct_connections_aborted}, 0, "Zero connections yields 0% aborted");
    is($zero_res->{total_sorts}, 0, "Zero sorts");
    is($zero_res->{pct_temp_sort_table}, 0, "Zero temp sort table");
    is($zero_res->{joins_without_indexes_per_day}, 0, "Zero joins per day on 0 uptime");
    is($zero_res->{pct_temp_disk}, 0, "Zero temp disk percentage on 0 tmp tables");
    is($zero_res->{table_cache_hit_rate}, 100, "Default table cache hit rate is 100%");
    is($zero_res->{pct_table_locks_immediate}, 100, "Default table locks immediate is 100%");
    is($zero_res->{thread_cache_hit_rate}, 100, "Default thread cache hit rate is 100%");
};

done_testing();
