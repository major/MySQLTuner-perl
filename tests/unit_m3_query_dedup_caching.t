#!/usr/bin/env perl
# tests/unit_m3_query_dedup_caching.t
# Validates Milestone 3:
#   - Issue 8A: Virtual column table preloading in mysql_80_modeling_checks
#   - Issue 8B: Engine query deduplication in mysql_databases
#   - Issue 9A: Performance Schema memory caching in mysql_stats and mysql_pfs
#   - Issue 9B: Galera GCache memory caching in mysql_stats

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

our @generalrec;
our @modeling;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;
our @dblist;

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

my @captured_info;
my @captured_good;
my @captured_bad;
my @captured_queries;

sub reset_state {
    @captured_info    = ();
    @captured_good    = ();
    @captured_bad     = ();
    @captured_queries = ();
    @generalrec       = ();
    @modeling         = ();
    %result           = ();
    %opt              = ();
    %myvar            = (
        long_query_time   => 10,
        query_cache_size  => 0,
        thread_cache_size => 8,
        concurrent_insert => 'AUTO',
        log_bin           => 'OFF',
    );
    %mystat           = (
        Created_tmp_tables => 0,
        Open_tables        => 0,
    );
    %mycalc           = (
        total_sorts                  => 0,
        joins_without_indexes_per_day => 0,
        thread_cache_hit_rate        => 100,
    );
    @dblist           = ();
}

{
    no warnings 'redefine';
    *main::infoprint      = sub { push @captured_info, $_[0] };
    *main::goodprint     = sub { push @captured_good, $_[0] };
    *main::badprint      = sub { push @captured_bad, $_[0] };
    *main::subheaderprint = sub { };
    *main::debugprint     = sub { };
}

# =====================================================================
# Subtest 1: Issue 8A - Virtual Column Table Preload in mysql_80_modeling_checks
# =====================================================================
subtest 'Issue 8A: Virtual Column Preloading in mysql_80_modeling_checks' => sub {
    reset_state();
    %myvar = ( version => '8.0.35' );

    my %mock_tables = (
        "DATA_TYPE = 'json'" => [
            "shop\torders\tpayload",         # shop.orders has NO virtual columns
            "shop\torders\tmetadata",        # shop.orders has NO virtual columns
            "shop\tcustomers\tprofile",      # shop.customers HAS virtual columns
            "analytics\tevents\tproperties", # analytics.events HAS virtual columns
        ],
        "EXTRA LIKE '%VIRTUAL%'" => [
            "shop\tcustomers",
            "analytics\tevents",
        ],
    );

    no warnings 'redefine';
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_array = sub {
        my ($q) = @_;
        push @captured_queries, $q;
        for my $k (keys %mock_tables) {
            if ($q =~ /$k/i) {
                return @{$mock_tables{$k}};
            }
        }
        return ();
    };

    main::mysql_80_modeling_checks();

    # Verify query deduplication: exactly 1 JSON columns query + 1 preloading query for virtual columns
    my @virtual_queries = grep { /EXTRA LIKE '%VIRTUAL%'/i } @captured_queries;
    is( scalar(@virtual_queries), 1, 'Exactly 1 preloading query executed for virtual columns across all tables' );

    # Ensure no per-column queries were executed
    my @per_col_queries = grep { /WHERE TABLE_SCHEMA = 'shop' AND TABLE_NAME = 'orders'/i } @captured_queries;
    is( scalar(@per_col_queries), 0, 'Zero per-column virtual queries executed (N+1 query bug eliminated)' );

    # Verify findings correctly flagged
    ok( grep( /Table shop\.orders: JSON column 'payload' detected without Virtual Generated Columns/, @captured_info ),
        'Detected missing virtual columns for shop.orders (payload)' );
    ok( grep( /Table shop\.orders: JSON column 'metadata' detected without Virtual Generated Columns/, @captured_info ),
        'Detected missing virtual columns for shop.orders (metadata)' );
    ok( !grep( /Table shop\.customers: JSON column 'profile'/, @captured_info ),
        'Table shop.customers with virtual column was correctly NOT flagged' );
    ok( !grep( /Table analytics\.events: JSON column 'properties'/, @captured_info ),
        'Table analytics.events with virtual column was correctly NOT flagged' );

    # Check recommendation count
    ok( grep( /Consider using Generated Columns to index frequently searched attributes in JSON column in 2 column\(s\)/, @generalrec ),
        'Generated column recommendation pushed with correct count (2)' );
};

# =====================================================================
# Subtest 2: Issue 8B - Engine Query Deduplication in mysql_databases
# =====================================================================
subtest 'Issue 8B: Engine Query Deduplication in mysql_databases' => sub {
    reset_state();
    $opt{dbstat} = 1;
    @dblist = ('app_production', 'app_reporting');

    no warnings 'redefine';
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_one = sub {
        my ($q) = @_;
        if ($q =~ /SELECT SUM\(TABLE_ROWS\)/i) {
            return "200 2097152 1048576 3145728 10 2 2";
        }
        if ($q =~ /SELECT count\(\*\) from information_schema\.TABLES WHERE TABLE_TYPE ='BASE TABLE'/i) {
            return "5";
        }
        if ($q =~ /SELECT count\(\*\) from information_schema\.TABLES WHERE TABLE_TYPE ='VIEW'/i) {
            return "0";
        }
        if ($q =~ /SELECT count\(distinct.*information_schema\.STATISTICS/i) {
            return "4";
        }
        if ($q =~ /SELECT TABLE_SCHEMA, SUM\(TABLE_ROWS\)/i) {
            return "app_production 100 1048576 524288 1572864 1 5 1 1";
        }
        if ($q =~ /SELECT COUNT\(\*\) FROM information_schema\.TABLES WHERE TABLE_SCHEMA='.*?' AND ENGINE='InnoDB'/i) {
            return "5";
        }
        if ($q =~ /SELECT COUNT\(\*\) FROM information_schema\.TABLES WHERE TABLE_SCHEMA='.*?' AND ENGINE='Aria'/i) {
            return "2";
        }
        return "1";
    };

    local *main::select_array = sub {
        my ($q) = @_;
        push @captured_queries, $q;
        if ($q =~ /information_schema\.SCHEMATA/i) {
            return ('app_production', 'app_reporting');
        }
        if ($q =~ /SELECT DISTINCT\(ENGINE\).*TABLE_SCHEMA='app_production'/i) {
            return ('InnoDB', 'Aria');
        }
        if ($q =~ /SELECT DISTINCT\(ENGINE\).*TABLE_SCHEMA='app_reporting'/i) {
            return ('InnoDB');
        }
        if ($q =~ /distinct\(CHARACTER_SET_NAME\)/i) {
            return ('utf8mb4');
        }
        if ($q =~ /DISTINCT\(TABLE_COLLATION\)/i) {
            return ('utf8mb4_unicode_ci');
        }
        return ();
    };

    main::mysql_databases();

    # Count how many times SELECT DISTINCT(ENGINE) was executed per database
    my @engine_queries_prod = grep { /SELECT DISTINCT\(ENGINE\).*TABLE_SCHEMA='app_production'/i } @captured_queries;
    is( scalar(@engine_queries_prod), 1,
        'SELECT DISTINCT(ENGINE) executed exactly once for app_production (deduplicated from 2)' );

    my @engine_queries_rep = grep { /SELECT DISTINCT\(ENGINE\).*TABLE_SCHEMA='app_reporting'/i } @captured_queries;
    is( scalar(@engine_queries_rep), 1,
        'SELECT DISTINCT(ENGINE) executed exactly once for app_reporting (deduplicated from 2)' );

    # Verify output rendering
    ok( grep( /\+-- ENGINE: 1 \(InnoDB, Aria\)/, @captured_info ),
        'Cached engines list formatted correctly with multiple engines' );
    ok( grep( /\+-- ENGINE InnoDB : 5 TABLE\(s\)/, @captured_info ),
        'Loop iterates through cached engines and queries table count' );
};

# =====================================================================
# Subtest 3: Issue 9A - PFS & GCache Memory Caching in mysql_stats
# =====================================================================
subtest 'Issue 9A: Memory Caching in mysql_stats' => sub {
    reset_state();
    my $pfs_calls    = 0;
    my $gcache_calls = 0;

    no warnings 'redefine';
    local *main::get_pf_memory = sub {
        $pfs_calls++;
        return 16777216; # 16 MB
    };
    local *main::get_gcache_memory = sub {
        $gcache_calls++;
        return 67108864; # 64 MB
    };

    %mystat = (
        Uptime         => 86400,
        Questions      => 10000,
        Connections    => 200,
        Bytes_sent     => 1048576,
        Bytes_received => 524288,
    );
    %myvar = (
        version         => '10.5.20-MariaDB',
        max_connections => 150,
    );
    %mycalc = (
        server_buffers     => 1073741824,
        per_thread_buffers => 2097152,
    );

    main::mysql_stats();

    # Assert get_pf_memory called once
    is( $pfs_calls, 1, 'get_pf_memory() called exactly once in mysql_stats (cached from 3 calls)' );
    is( $result{'Performance_schema'}{'memory'}, 16777216, 'Performance schema raw memory recorded in %result' );
    is( $result{'Performance_schema'}{'pretty_memory'}, '16M', 'Performance schema pretty memory recorded in %result' );

    # Assert get_gcache_memory called once
    is( $gcache_calls, 1, 'get_gcache_memory() called exactly once in mysql_stats (cached from 3 calls)' );
    is( $result{'Galera'}{'GCache'}{'memory'}, 67108864, 'Galera GCache raw memory recorded in %result' );
    is( $result{'Galera'}{'GCache'}{'pretty_memory'}, '64M', 'Galera GCache pretty memory recorded in %result' );

    ok( grep( /Performance_schema Max memory usage:\s+16M/, @captured_info ),
        'PFS memory printed correctly from cached variable' );
    ok( grep( /Galera GCache Max memory usage:\s+64M/, @captured_info ),
        'GCache memory printed correctly from cached variable' );
};

# =====================================================================
# Subtest 4: Issue 9B - PFS Memory Caching in mysql_pfs
# =====================================================================
subtest 'Issue 9B: PFS Memory Caching in mysql_pfs' => sub {
    reset_state();
    my $pfs_calls = 0;

    no warnings 'redefine';
    local *main::get_pf_memory = sub {
        $pfs_calls++;
        return 33554432; # 32 MB
    };
    local *main::select_array = sub { return ('sys'); };

    %myvar = (
        performance_schema => 'ON',
        version            => '8.0.32',
    );
    $opt{pfstat} = 1;

    # Case 1: Result already cached by mysql_stats
    $result{'Performance_schema'}{'memory'} = 33554432;
    main::mysql_pfs();

    is( $pfs_calls, 0, 'get_pf_memory() not executed when %result already contains cached memory' );
    ok( grep( /Memory used by Performance_schema:\s+32\.0M/, @captured_info ),
        'PFS memory printed from cached %result value' );

    # Case 2: Standalone run without prior mysql_stats execution
    reset_state();
    $pfs_calls = 0;
    %myvar = (
        performance_schema => 'ON',
        version            => '8.0.32',
    );
    $opt{pfstat} = 1;

    main::mysql_pfs();

    is( $pfs_calls, 1, 'get_pf_memory() called exactly once when running standalone without %result' );
    ok( grep( /Memory used by Performance_schema:\s+32\.0M/, @captured_info ),
        'PFS memory printed from single standalone call' );
};

done_testing();
