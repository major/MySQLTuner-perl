#!/usr/bin/env perl
# tests/stress_m3_adversarial.t
# Adversarial Stress Testing Harness for Milestone 3 (Issues 5 & 8):
#   - Issue 5: InnoDB Buffer Pool page size scaling (4KB to 128KB, 0, negative, undef,
#              huge 1TB allocations, underflow clamping when free > total)
#   - Issue 8A: Virtual column preload under multi-database schema collisions,
#               multiple JSON columns per table, empty sets, and special characters
#   - Issue 8B: Engine query deduplication across multi-database topologies,
#               diverse storage engine combinations, and --ignore-tables filtering
#   - State immutability & cross-interaction stress

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
our %enginestats;
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
        total_sorts                   => 0,
        joins_without_indexes_per_day => 0,
        thread_cache_hit_rate         => 100,
    );
    %enginestats      = ();
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
# Subtest 1: Issue 5 - Adversarial Page Sizes & Extreme Buffer Pool Values
# =====================================================================
subtest 'Adversarial Issue 5: Page Size Matrix & Extreme Value Stress' => sub {
    # 1.1 Matrix of valid & exotic page sizes (4KB to 128KB)
    my @matrix = (
        { desc => '4KB page size',   page_size => 4096,   total => 262144, free => 65536,  exp_free => '256\.0M', exp_used => '768\.0M' },
        { desc => '8KB page size',   page_size => 8192,   total => 131072, free => 32768,  exp_free => '256\.0M', exp_used => '768\.0M' },
        { desc => '16KB page size',  page_size => 16384,  total => 65536,  free => 16384,  exp_free => '256\.0M', exp_used => '768\.0M' },
        { desc => '32KB page size',  page_size => 32768,  total => 32768,  free => 8192,   exp_free => '256\.0M', exp_used => '768\.0M' },
        { desc => '64KB page size',  page_size => 65536,  total => 16384,  free => 4096,   exp_free => '256\.0M', exp_used => '768\.0M' },
        { desc => '128KB page size', page_size => 131072, total => 8192,   free => 2048,   exp_free => '256\.0M', exp_used => '768\.0M' },
    );

    for my $case (@matrix) {
        reset_state();
        $opt{buffers} = 1;
        %myvar = (
            have_innodb             => 'YES',
            innodb_page_size        => $case->{page_size},
            innodb_buffer_pool_size => $case->{total} * $case->{page_size},
        );
        %mystat = (
            Innodb_buffer_pool_pages_total => $case->{total},
            Innodb_buffer_pool_pages_free  => $case->{free},
        );
        $enginestats{'InnoDB'} = 1;

        main::mysql_innodb();

        ok( grep( /InnoDB Buffer Free:\s+$case->{exp_free}/, @captured_info ),
            "$case->{desc}: Free buffer matched $case->{exp_free}" );
        ok( grep( /InnoDB Buffer Used:\s+$case->{exp_used}/, @captured_info ),
            "$case->{desc}: Used buffer matched $case->{exp_used}" );
    }

    # 1.2 Boundary & Invalid page sizes: 0, negative, empty string, undef
    my @boundary_sizes = (
        { desc => 'Zero page size (0)',            val => 0 },
        { desc => 'Negative page size (-16384)',   val => -16384 },
        { desc => 'Negative small (-1)',           val => -1 },
        { desc => 'Empty string ("")',             val => '' },
        { desc => 'Undefined page size',           val => undef },
    );

    for my $bs (@boundary_sizes) {
        reset_state();
        $opt{buffers} = 1;
        %myvar = (
            have_innodb             => 'YES',
            innodb_buffer_pool_size => 1073741824,
        );
        $myvar{innodb_page_size} = $bs->{val} if defined $bs->{val};
        %mystat = (
            Innodb_buffer_pool_pages_total => 65536,
            Innodb_buffer_pool_pages_free  => 16384,
        );
        $enginestats{'InnoDB'} = 1;

        main::mysql_innodb();

        # All invalid/zero/negative sizes MUST default safely to 16384
        ok( grep( /InnoDB Buffer Free:\s+256\.0M/, @captured_info ),
            "$bs->{desc}: safely defaulted to 16KB for Free (256.0M)" );
        ok( grep( /InnoDB Buffer Used:\s+768\.0M/, @captured_info ),
            "$bs->{desc}: safely defaulted to 16KB for Used (768.0M)" );
    }

    # 1.3 High-scale Enterprise: 1 Terabyte Buffer Pool (67,108,864 pages * 16KB)
    {
        reset_state();
        $opt{buffers} = 1;
        %myvar = (
            have_innodb             => 'YES',
            innodb_page_size        => 16384,
            innodb_buffer_pool_size => 1099511627776, # 1 TB
        );
        %mystat = (
            Innodb_buffer_pool_pages_total => 67108864, # 1 TB
            Innodb_buffer_pool_pages_free  => 16777216, # 256 GB free
        );
        $enginestats{'InnoDB'} = 1;

        main::mysql_innodb();

        ok( grep( /InnoDB Buffer Free:\s+256\.0G/, @captured_info ),
            '1TB Buffer Pool: Free reported correctly in Gigabytes (256.0G)' );
        ok( grep( /InnoDB Buffer Used:\s+768\.0G/, @captured_info ),
            '1TB Buffer Pool: Used reported correctly in Gigabytes (768.0G)' );
    }

    # 1.4 Underflow and Asymmetric Anomalies
    {
        # Total = 0, Free = 0
        reset_state();
        $opt{buffers} = 1;
        %myvar = (
            have_innodb             => 'YES',
            innodb_page_size        => 16384,
            innodb_buffer_pool_size => 0,
        );
        %mystat = (
            Innodb_buffer_pool_pages_total => 0,
            Innodb_buffer_pool_pages_free  => 0,
        );
        $enginestats{'InnoDB'} = 1;

        main::mysql_innodb();

        ok( grep( /InnoDB Buffer Free:\s+0B/, @captured_info ),
            'Zero total and zero free: Free prints 0B' );
        ok( grep( /InnoDB Buffer Used:\s+0B/, @captured_info ),
            'Zero total and zero free: Used prints 0B' );

        # Severe Free > Total spike (Free = 50000, Total = 10000)
        reset_state();
        $opt{buffers} = 1;
        %myvar = (
            have_innodb             => 'YES',
            innodb_page_size        => 16384,
            innodb_buffer_pool_size => 163840000,
        );
        %mystat = (
            Innodb_buffer_pool_pages_total => 10000,
            Innodb_buffer_pool_pages_free  => 50000,
        );
        $enginestats{'InnoDB'} = 1;

        main::mysql_innodb();

        ok( grep( /InnoDB Buffer Used:\s+0(?:\.0)?B/, @captured_info ),
            'Extreme free > total spike: Used clamped strictly to 0B (no negative memory)' );
        ok( !grep( /InnoDB Buffer Used:\s+-/, @captured_info ),
            'No negative sign appears in Used memory' );
    }
};

# =====================================================================
# Subtest 2: Issue 8A - Virtual Column Preload Under Multi-Database Topologies
# =====================================================================
subtest 'Adversarial Issue 8A: Multi-Database Virtual Column Preload Stress' => sub {
    # 2.1 Multi-tenant schema collision test:
    # 5 tenants, all having the exact same table name 'orders' and column 'payload'.
    # Only tenant_2 and tenant_4 have virtual columns.
    # Checks that schema qualification ($vs.$vtbl) prevents false positives/negatives.
    reset_state();
    %myvar = ( version => '8.0.36' );

    my @json_cols = (
        "tenant_1\torders\tpayload",        # MISSING virtual column
        "tenant_2\torders\tpayload",        # HAS virtual column
        "tenant_3\torders\tpayload",        # MISSING virtual column
        "tenant_4\torders\tpayload",        # HAS virtual column
        "tenant_5\torders\tpayload",        # MISSING virtual column
        "crm\tusers\tprofile",             # HAS virtual column
        "crm\tusers\tsettings",            # HAS virtual column (same table, 2nd JSON col)
        "billing\tinvoices\tline_items",   # MISSING virtual column
    );

    my @virtual_defs = (
        "tenant_2\torders",
        "tenant_4\torders",
        "crm\tusers",
    );

    no warnings 'redefine';
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_array = sub {
        my ($q) = @_;
        push @captured_queries, $q;
        if ($q =~ /DATA_TYPE = 'json'/i) {
            return @json_cols;
        }
        if ($q =~ /EXTRA LIKE '%VIRTUAL%'/i) {
            return @virtual_defs;
        }
        return ();
    };

    main::mysql_80_modeling_checks();

    # Exactly 1 preloading query for virtual columns must be executed
    my @v_queries = grep { /EXTRA LIKE '%VIRTUAL%'/i } @captured_queries;
    is( scalar(@v_queries), 1, 'Only 1 query for virtual columns executed for 8 JSON columns across 6 tables' );

    # Zero per-table queries
    my @per_table = grep { /WHERE TABLE_SCHEMA = 'tenant_/i } @captured_queries;
    is( scalar(@per_table), 0, 'No individual table queries executed' );

    # Verify precision of findings:
    # tenant_1, tenant_3, tenant_5, billing.invoices flagged
    ok( grep( /Table tenant_1\.orders: JSON column 'payload' detected without Virtual/, @captured_info ),
        'tenant_1.orders correctly flagged' );
    ok( grep( /Table tenant_3\.orders: JSON column 'payload' detected without Virtual/, @captured_info ),
        'tenant_3.orders correctly flagged' );
    ok( grep( /Table tenant_5\.orders: JSON column 'payload' detected without Virtual/, @captured_info ),
        'tenant_5.orders correctly flagged' );
    ok( grep( /Table billing\.invoices: JSON column 'line_items' detected without Virtual/, @captured_info ),
        'billing.invoices correctly flagged' );

    # tenant_2, tenant_4, crm.users MUST NOT be flagged
    ok( !grep( /Table tenant_2\.orders/, @captured_info ),
        'tenant_2.orders NOT flagged (virtual column exists)' );
    ok( !grep( /Table tenant_4\.orders/, @captured_info ),
        'tenant_4.orders NOT flagged (virtual column exists)' );
    ok( !grep( /Table crm\.users/, @captured_info ),
        'crm.users NOT flagged for either JSON column (virtual column exists on table)' );

    # Total missing count should be 4
    ok( grep( /Consider using Generated Columns to index frequently searched attributes in JSON column in 4 column\(s\)/, @generalrec ),
        'General recommendations contains exact count (4)' );

    # 2.2 Edge case: Zero JSON columns in database
    reset_state();
    %myvar = ( version => '8.0.36' );
    local *main::select_array = sub {
        my ($q) = @_;
        push @captured_queries, $q;
        return (); # Empty JSON columns
    };

    main::mysql_80_modeling_checks();

    my @v_queries_empty = grep { /EXTRA LIKE '%VIRTUAL%'/i } @captured_queries;
    is( scalar(@v_queries_empty), 0, 'Zero queries issued for virtual columns when no JSON columns exist' );
    is( scalar(@generalrec), 0, 'Zero recommendations when no JSON columns exist' );
};

# =====================================================================
# Subtest 3: Issue 8B - Engine Deduplication Across Multi-Database Topologies
# =====================================================================
subtest 'Adversarial Issue 8B: Multi-Database Engine Deduplication Stress' => sub {
    reset_state();
    $opt{dbstat} = 1;
    my @test_databases = ('db_alpha', 'db_beta', 'db_gamma', 'db_empty');

    my %db_engines = (
        'db_alpha' => ['InnoDB', 'MyISAM', 'MEMORY'],
        'db_beta'  => ['Aria', 'RocksDB'],
        'db_gamma' => ['InnoDB'],
        'db_empty' => [],
    );

    no warnings 'redefine';
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_one = sub {
        my ($q) = @_;
        if ($q =~ /SELECT SUM\(TABLE_ROWS\)/i) {
            return "100 1048576 524288 1572864 10 3 3";
        }
        if ($q =~ /SELECT count\(\*\) from information_schema\.TABLES WHERE TABLE_TYPE ='BASE TABLE'/i) {
            return ($q =~ /db_empty/ ? "0" : "5");
        }
        if ($q =~ /SELECT count\(\*\) from information_schema\.TABLES WHERE TABLE_TYPE ='VIEW'/i) {
            return "0";
        }
        if ($q =~ /SELECT count\(distinct.*information_schema\.STATISTICS/i) {
            return "2";
        }
        if ($q =~ /SELECT TABLE_SCHEMA, SUM\(TABLE_ROWS\)/i) {
            my ($schema) = $q =~ /TABLE_SCHEMA='(.*?)'/;
            $schema //= 'db_unknown';
            my $engine_cnt = scalar(@{$db_engines{$schema} // []});
            my $nb = ($schema eq 'db_empty') ? 0 : 5;
            # TABLE_SCHEMA Rows Data Index Total DistinctEngines Tables Colls TotalEngines
            return "$schema 100 1048576 524288 1572864 $engine_cnt $nb 1 $engine_cnt";
        }
        if ($q =~ /SELECT COUNT\(\*\) FROM information_schema\.TABLES WHERE TABLE_SCHEMA='(.*?)' AND ENGINE='(.*?)'/i) {
            return "2";
        }
        return "1";
    };

    local *main::select_array = sub {
        my ($q) = @_;
        push @captured_queries, $q;
        if ($q =~ /information_schema\.SCHEMATA/i) {
            return @test_databases;
        }
        if ($q =~ /SELECT DISTINCT\(ENGINE\).*TABLE_SCHEMA='(.*?)'/i) {
            my $schema = $1;
            return @{$db_engines{$schema} // []};
        }
        if ($q =~ /SELECT DISTINCT\(ENGINE\).*TABLE_SCHEMA NOT IN/i) {
            return ('InnoDB', 'MyISAM', 'MEMORY', 'Aria', 'RocksDB');
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

    # Check query count per database:
    # EXACTLY 1 SELECT DISTINCT(ENGINE) query per database
    for my $db (@test_databases) {
        my @eng_q = grep { /SELECT DISTINCT\(ENGINE\).*TABLE_SCHEMA='$db'/i } @captured_queries;
        is( scalar(@eng_q), 1, "Database '$db' executed SELECT DISTINCT(ENGINE) exactly once (deduplicated)" );
    }

    # Total engine distinct queries should be 1 global + 4 per-database = 5 (halved from legacy 1 + 8 = 9)
    my @all_eng_queries = grep { /SELECT DISTINCT\(ENGINE\)/i } @captured_queries;
    is( scalar(@all_eng_queries), 5, 'Total 5 engine queries (1 global + 4 per-database, halved from legacy 9)' );

    # Verify multi-engine warning for db_alpha (3 engines) and db_beta (2 engines)
    ok( grep( /There are 3 storage engines/, @captured_bad ),
        'db_alpha correctly warned for 3 storage engines' );
    ok( grep( /There are 2 storage engines/, @captured_bad ),
        'db_beta correctly warned for 2 storage engines' );
    ok( grep( /No table in db_empty database/, @captured_bad ),
        'db_empty correctly recognized as having 0 tables without error' );

    # Verify engine formatting
    ok( grep( /\+-- ENGINE: 3 \(InnoDB, MyISAM, MEMORY\)/, @captured_info ),
        'db_alpha engines properly joined in info print' );
    ok( grep( /\+-- ENGINE: 2 \(Aria, RocksDB\)/, @captured_info ),
        'db_beta engines properly joined in info print' );
};

# =====================================================================
# Subtest 4: Cross-Interaction & State Hygiene
# =====================================================================
subtest 'Adversarial: State Hygiene & Global Variable Protection' => sub {
    reset_state();
    $opt{buffers} = 1;
    %myvar = (
        have_innodb             => 'YES',
        innodb_page_size        => 16384,
        innodb_buffer_pool_size => 1073741824,
    );
    %mystat = (
        Innodb_buffer_pool_pages_total => 65536,
        Innodb_buffer_pool_pages_free  => 16384,
    );
    $enginestats{'InnoDB'} = 1;

    main::mysql_innodb();

    # Verify input hashes were NOT modified/mutated by calculation
    is( $myvar{innodb_page_size}, 16384, '%myvar innodb_page_size remained unchanged' );
    is( $mystat{Innodb_buffer_pool_pages_total}, 65536, '%mystat pages_total remained unchanged' );
    is( $mystat{Innodb_buffer_pool_pages_free}, 16384, '%mystat pages_free remained unchanged' );
};

done_testing();
