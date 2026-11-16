#!/usr/bin/env perl
# tests/challenge_m3_adversarial.t
# Adversarial Empirical Challenge Suite for Milestone 3:
#   1. Challenge 1: InnoDB Buffer Pool page sizing under extreme bounds & invalid types
#   2. Challenge 2: Virtual column preloading under schema variations & zero-match conditions
#   3. Challenge 3: Engine query deduplication invariants across multiple databases
#   4. Challenge 4: PFS & GCache memory caching idempotence & lifecycle transitions
#   5. Challenge 5: Galera wsrep status metric isolation & array reference immutability
#   6. Challenge 6: Distinct character set metric isolation vs collation count
#   7. Challenge 7: Index TYPE dual-resolution under varied column dimensions & NULLs
#   8. Challenge 8: Foreign key check deduplication & single source of truth verification

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Pre-declare required globals
our @generalrec;
our @modeling;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %enginestats;
our %result;
our @dblist;
our $selIdxReq;

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
    %myvar            = ();
    %mystat           = ();
    %mycalc           = ();
    %enginestats      = ();
    @dblist           = ();
    $selIdxReq        = '';
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
# Challenge 1: InnoDB Buffer Pool Page Sizing Under Extreme Bounds
# =====================================================================
subtest 'Challenge 1: InnoDB Buffer Pool Page Sizing Under Extreme Bounds' => sub {
    # Test 1A: Extreme 1TB buffer pool (67,108,864 pages of 16KB)
    reset_state();
    $opt{buffers} = 1;
    $enginestats{'InnoDB'} = 1;
    %myvar = (
        have_innodb             => 'YES',
        innodb_page_size        => 16384,
        innodb_buffer_pool_size => 1099511627776,
    );
    %mystat = (
        Innodb_buffer_pool_pages_total => 67108864,
        Innodb_buffer_pool_pages_free  => 16777216,
    );

    main::mysql_innodb();

    ok( grep( /InnoDB Buffer Free:\s+256\.0G/, @captured_info ),
        '1TB Buffer Pool: Free correctly calculated as 256.0G' );
    ok( grep( /InnoDB Buffer Used:\s+768\.0G/, @captured_info ),
        '1TB Buffer Pool: Used correctly calculated as 768.0G' );

    # Test 1B: Negative page size falls back safely to 16384
    reset_state();
    $opt{buffers} = 1;
    $enginestats{'InnoDB'} = 1;
    %myvar = (
        have_innodb             => 'YES',
        innodb_page_size        => -16384,
        innodb_buffer_pool_size => 1073741824,
    );
    %mystat = (
        Innodb_buffer_pool_pages_total => 65536,
        Innodb_buffer_pool_pages_free  => 16384,
    );

    main::mysql_innodb();

    ok( grep( /InnoDB Buffer Free:\s+256\.0M/, @captured_info ),
        'Negative innodb_page_size falls back to default 16384 (256.0M)' );
    ok( grep( /InnoDB Buffer Used:\s+768\.0M/, @captured_info ),
        'Negative innodb_page_size used bytes calculated with default 16384 (768.0M)' );

    # Test 1C: Non-numeric string page size falls back safely
    reset_state();
    $opt{buffers} = 1;
    $enginestats{'InnoDB'} = 1;
    %myvar = (
        have_innodb             => 'YES',
        innodb_page_size        => 'INVALID_SIZE',
        innodb_buffer_pool_size => 1073741824,
    );
    %mystat = (
        Innodb_buffer_pool_pages_total => 65536,
        Innodb_buffer_pool_pages_free  => 16384,
    );

    {
        no warnings 'numeric';
        main::mysql_innodb();
    }

    ok( grep( /InnoDB Buffer Free:\s+256\.0M/, @captured_info ),
        'String innodb_page_size falls back safely to 16384' );

    # Test 1D: Zero free and zero total pages
    reset_state();
    $opt{buffers} = 1;
    $enginestats{'InnoDB'} = 1;
    %myvar = (
        have_innodb      => 'YES',
        innodb_page_size => 16384,
    );
    %mystat = (
        Innodb_buffer_pool_pages_total => 0,
        Innodb_buffer_pool_pages_free  => 0,
    );

    main::mysql_innodb();

    ok( grep( /InnoDB Buffer Free:\s+0(?:\.0)?B/, @captured_info ),
        'Zero free pages outputs 0B' );
    ok( grep( /InnoDB Buffer Used:\s+0(?:\.0)?B/, @captured_info ),
        'Zero used pages outputs 0B' );
};

# =====================================================================
# Challenge 2: Virtual Column Preloading Under Varied Schema Conditions
# =====================================================================
subtest 'Challenge 2: Virtual Column Preload Schema Invariance & Boundary Conditions' => sub {
    # Test 2A: Zero JSON columns in instance -> exactly zero virtual queries executed
    reset_state();
    %myvar = ( version => '8.0.35' );

    no warnings 'redefine';
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_array = sub {
        my ($q) = @_;
        push @captured_queries, $q;
        return (); # No JSON columns
    };

    main::mysql_80_modeling_checks();

    my @virtual_queries = grep { /EXTRA LIKE '%VIRTUAL%'/i } @captured_queries;
    is( scalar(@virtual_queries), 0,
        'Zero virtual queries issued when no JSON columns exist in instance' );
    is( scalar(@generalrec), 0, 'No recommendations emitted when no JSON columns exist' );

    # Test 2B: Multiple JSON columns on table with virtual columns vs table without
    reset_state();
    %myvar = ( version => '8.0.35' );

    my %mock_tables = (
        "DATA_TYPE = 'json'" => [
            "prod_db\torder-items\tattrs",     # Hyphenated table name, HAS virtual col
            "prod_db\torder-items\textras",    # Hyphenated table name, HAS virtual col
            "prod_db\tuser_logs\tpayload",     # NO virtual col
            "prod_db\tuser_logs\tcontext",     # NO virtual col
            "prod_db\tuser_logs\tmetadata",    # NO virtual col
        ],
        "EXTRA LIKE '%VIRTUAL%'" => [
            "prod_db\torder-items",
        ],
    );

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

    is( scalar( grep { /EXTRA LIKE '%VIRTUAL%'/i } @captured_queries ), 1,
        'Exactly 1 preload query executed for virtual tables' );

    # prod_db.order-items should NOT be flagged for either column
    ok( !grep( /Table prod_db\.order-items: JSON column/, @captured_info ),
        'Hyphenated table with virtual columns correctly bypassed' );

    # prod_db.user_logs has 3 JSON columns without virtual columns
    ok( grep( /Table prod_db\.user_logs: JSON column 'payload' detected without Virtual/, @captured_info ),
        'user_logs.payload flagged' );
    ok( grep( /Table prod_db\.user_logs: JSON column 'context' detected without Virtual/, @captured_info ),
        'user_logs.context flagged' );
    ok( grep( /Table prod_db\.user_logs: JSON column 'metadata' detected without Virtual/, @captured_info ),
        'user_logs.metadata flagged' );

    ok( grep( /in 3 column\(s\)/, @generalrec ),
        'Recommendation reports exact aggregate count of 3 unindexed columns' );
};

# =====================================================================
# Challenge 3: Engine Query Deduplication Invariants Across Multiple DBs
# =====================================================================
subtest 'Challenge 3: Engine Query Deduplication Invariants' => sub {
    reset_state();
    $opt{dbstat} = 1;
    $opt{'ignore-tables'} = 'audit_log,backup_log';

    no warnings 'redefine';
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_one = sub {
        my ($q) = @_;
        if ($q =~ /SELECT SUM\(TABLE_ROWS\)/i) {
            return "300 3145728 1572864 4718592 15 3 3";
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
        if ($q =~ /TABLE_SCHEMA='(db_\w+)'/i) {
            return "$1 100 1048576 524288 1572864 1 5 1 1";
        }
        return "1";
    };

    local *main::select_array = sub {
        my ($q) = @_;
        push @captured_queries, $q;
        if ($q =~ /information_schema\.SCHEMATA/i) {
            return ('db_alpha', 'db_beta', 'db_gamma');
        }
        if ($q =~ /SELECT DISTINCT\(ENGINE\).*TABLE_SCHEMA='(db_\w+)'/i) {
            return ('InnoDB', 'MyISAM');
        }
        if ($q =~ /distinct\(CHARACTER_SET_NAME\)/i) {
            return ('utf8mb4');
        }
        if ($q =~ /DISTINCT\(TABLE_COLLATION\)/i) {
            return ('utf8mb4_bin');
        }
        return ();
    };

    main::mysql_databases();

    # For each database, verify SELECT DISTINCT(ENGINE) is called exactly once
    for my $db ('db_alpha', 'db_beta', 'db_gamma') {
        my @calls = grep { /SELECT DISTINCT\(ENGINE\).*TABLE_SCHEMA='$db'/i } @captured_queries;
        is( scalar(@calls), 1, "SELECT DISTINCT(ENGINE) for $db executed exactly once" );
        # Verify ignore-tables SQL is preserved
        ok( $calls[0] =~ /TABLE_NAME NOT IN \('audit_log','backup_log'\)/,
            "Ignore-tables clause properly preserved in engine query for $db" );
    }
};

# =====================================================================
# Challenge 4: PFS & GCache Memory Caching Idempotency
# =====================================================================
subtest 'Challenge 4: PFS & GCache Memory Caching Idempotency' => sub {
    reset_state();
    my $pf_call_count = 0;
    my $gcache_call_count = 0;

    no warnings 'redefine';
    local *main::get_pf_memory = sub {
        $pf_call_count++;
        return 10485760; # 10 MB
    };
    local *main::get_gcache_memory = sub {
        $gcache_call_count++;
        return 20971520; # 20 MB
    };
    local *main::select_array = sub { return ('sys') };

    %mystat = (
        Uptime      => 3600,
        Questions   => 500,
        Connections => 50,
    );
    %myvar = (
        version            => '8.0.32',
        max_connections    => 100,
        performance_schema => 'ON',
    );
    %mycalc = (
        server_buffers     => 1048576,
        per_thread_buffers => 1048576,
    );
    $opt{pfstat} = 1;

    # Sequence 1: mysql_stats executes and seeds %result
    main::mysql_stats();

    is( $pf_call_count, 1, 'get_pf_memory executed exactly once in mysql_stats' );
    is( $gcache_call_count, 1, 'get_gcache_memory executed exactly once in mysql_stats' );

    # Sequence 2: mysql_pfs executes and reuses %result without additional get_pf_memory call
    main::mysql_pfs();

    is( $pf_call_count, 1, 'get_pf_memory was NOT executed again in mysql_pfs (cached)' );
    ok( grep( /Memory used by Performance_schema:\s+10\.0M/, @captured_info ),
        'mysql_pfs outputs the correct cached 10.0M memory value' );
};

# =====================================================================
# Challenge 5: Galera wsrep Status Metric Isolation & Arrayref Structure
# =====================================================================
subtest 'Challenge 5: Galera wsrep Status Metric Isolation & Arrayref' => sub {
    reset_state();

    no warnings 'redefine';
    local *main::cpu_cores = sub { return 4 };
    local *main::get_wsrep_option = sub { return 67108864 };
    local *main::get_wsrep_options = sub {
        return ( 'gcache.size = 64M', 'gcache.page_size = 128M' );
    };

    %myvar = (
        have_galera         => 'YES',
        wsrep_on            => 'ON',
        wsrep_slave_threads => 8,
    );
    %mystat = (
        wsrep_local_state_comment => 'Synced',
        wsrep_cluster_size        => '3',
        wsrep_cert_deps_distance  => '25.5',
        # Non-wsrep metric that should NOT be in Galera status
        Queries                   => '1000000',
        Threads_connected         => '12',
    );

    main::mariadb_galera();

    # Verify array reference type
    my $wsrep_opts = $result{'Galera'}{'wsrep options'};
    is( ref($wsrep_opts), 'ARRAY', 'wsrep options is an ARRAY reference' );
    is_deeply( $wsrep_opts, [ 'gcache.size = 64M', 'gcache.page_size = 128M' ],
        'Array reference contents match provider options' );

    # Verify status lookup isolation from %mystat
    my $galera_status = $result{'Galera'}{'status'};
    is( $galera_status->{'wsrep_local_state_comment'}, 'Synced', 'wsrep_local_state_comment populated' );
    is( $galera_status->{'wsrep_cluster_size'}, '3', 'wsrep_cluster_size populated' );
    is( $galera_status->{'wsrep_cert_deps_distance'}, '25.5', 'wsrep_cert_deps_distance populated' );

    # Verify non-wsrep keys were NOT copied into Galera status
    ok( !exists( $galera_status->{'Queries'} ), 'Non-wsrep status metric Queries omitted' );
    ok( !exists( $galera_status->{'Threads_connected'} ), 'Non-wsrep status metric Threads_connected omitted' );
};

# =====================================================================
# Challenge 6: Distinct Character Set Metrics Isolation vs Collations
# =====================================================================
subtest 'Challenge 6: Distinct Character Set Metrics Isolation' => sub {
    reset_state();
    $opt{dbstat} = 1;

    no warnings 'redefine';
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_one = sub {
        my ($q) = @_;
        if ($q =~ /SELECT SUM\(TABLE_ROWS\)/i) {
            # Total dbinfo: collations count is 42, engines count is 4
            return "5000 10485760 5242880 15728640 50 42 4";
        }
        if ($q =~ /TABLE_SCHEMA='multi_char_db'/i) {
            return "multi_char_db 1000 2097152 1048576 3145728 1 10 8 1";
        }
        return "1";
    };

    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /information_schema\.SCHEMATA/i) {
            return ('multi_char_db');
        }
        if ($q =~ /distinct\(CHARACTER_SET_NAME\).*NOT IN/i) {
            # Global distinct charsets: 4 (utf8mb4, latin1, utf8mb3, ascii)
            return ('utf8mb4', 'latin1', 'utf8mb3', 'ascii');
        }
        if ($q =~ /distinct\(CHARACTER_SET_NAME\).*TABLE_SCHEMA='multi_char_db'/i) {
            # DB distinct charsets: 2 (utf8mb4, latin1)
            return ('utf8mb4', 'latin1');
        }
        if ($q =~ /DISTINCT\(TABLE_COLLATION\)/i) {
            return ('utf8mb4_unicode_ci', 'latin1_swedish_ci');
        }
        if ($q =~ /DISTINCT\(ENGINE\)/i) {
            return ('InnoDB');
        }
        return ();
    };

    main::mysql_databases();

    # Ensure global CHARS outputs 4 (not 42 collations)
    ok( grep( /\+-- CHARS\s+:\s+4\s+\(utf8mb4,\s+latin1,\s+utf8mb3,\s+ascii\)/, @captured_info ),
        'Global CHARS outputs distinct character sets count 4 (not 42 collations)' );

    # Ensure per-database CHARS outputs 2 (not 8 collations)
    ok( grep( /\+-- CHARS\s+:\s+2\s+\(utf8mb4,\s+latin1\)/, @captured_info ),
        'Database CHARS outputs distinct character sets count 2 (not 8 collations)' );
};

# =====================================================================
# Challenge 7: Index TYPE Dual-Resolution Under Varied Formats
# =====================================================================
subtest 'Challenge 7: Index TYPE Dual-Resolution Under Varied Formats' => sub {
    # Test 7A: Real 4-column format with various index types (BTREE, HASH, FULLTEXT, SPATIAL)
    reset_state();
    $opt{idxstat} = 1;
    $myvar{'performance_schema'} = 'OFF';

    no warnings 'redefine';
    local *main::select_user_dbs = sub { return ('types_db') };
    local *main::select_one = sub { return "10" };
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /GROUP BY table_name, idxname/i) {
            return (
                "tbl.idx_btree\tcol_a\t100\tBTREE",
                "tbl.idx_hash\tcol_b\t200\tHASH",
                "tbl.idx_full\tcol_c\t300\tFULLTEXT",
                "tbl.idx_spat\tcol_d\t400\tSPATIAL",
            );
        }
        return ();
    };

    main::mysql_indexes();

    ok( grep( /\+-- TYPE\s+:\s+BTREE/, @captured_info ), 'BTREE resolved from $info[3]' );
    ok( grep( /\+-- TYPE\s+:\s+HASH/, @captured_info ), 'HASH resolved from $info[3]' );
    ok( grep( /\+-- TYPE\s+:\s+FULLTEXT/, @captured_info ), 'FULLTEXT resolved from $info[3]' );
    ok( grep( /\+-- TYPE\s+:\s+SPATIAL/, @captured_info ), 'SPATIAL resolved from $info[3]' );

    # Test 7B: Legacy mock 5-column format with NULL in col 3 and type in col 4
    reset_state();
    $opt{idxstat} = 1;
    $myvar{'performance_schema'} = 'OFF';

    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /GROUP BY table_name, idxname/i) {
            return (
                "tbl.idx_legacy\tcol_a\t100\tNULL\tBTREE",
            );
        }
        return ();
    };

    main::mysql_indexes();

    ok( grep( /\+-- TYPE\s+:\s+BTREE/, @captured_info ), 'Legacy mock: BTREE resolved from $info[4]' );
    ok( !grep( /\+-- TYPE\s+:\s+NULL/, @captured_info ), 'Legacy mock: NULL was not printed' );
};

# =====================================================================
# Challenge 8: Foreign Key Check Deduplication & Single Source of Truth
# =====================================================================
subtest 'Challenge 8: Foreign Key Check Consolidation & Deduplication' => sub {
    # Test 8A: mysql_table_structures never executes FK join query
    reset_state();
    $opt{structstat} = 1;
    $opt{dumpdir} = 0;

    my %fk_queries_seen;
    {
        no warnings 'redefine';
        local *main::dump_into_file = sub { };
        local *main::mysql_naming_conventions = sub { };
        local *main::mysql_foreign_key_checks = sub { };
        local *main::mysql_80_modeling_checks = sub { };
        local *main::mysql_datatype_optimization = sub { };
        local *main::mysql_schema_sanitization = sub { };
        local *main::select_one = sub { return "0" };
        local *main::select_array = sub {
            my ($q) = @_;
            if ($q =~ /REFERENCED_TABLE_NAME.*c1\.COLUMN_TYPE != c2\.COLUMN_TYPE/is) {
                $fk_queries_seen{mismatch}++;
            }
            return ();
        };

        main::mysql_table_structures();

        is( $fk_queries_seen{mismatch} // 0, 0,
            'mysql_table_structures executed zero FK type mismatch queries' );
        is( scalar(@generalrec), 0, 'mysql_table_structures added zero FK recommendations' );
        is( scalar(@modeling), 0, 'mysql_table_structures added zero FK modeling items' );
    }

    # Test 8B: mysql_foreign_key_checks is the single source of truth
    reset_state();
    {
        no warnings 'redefine';
        local *main::dump_into_file = sub { };
        local *main::select_array = sub {
            my ($q) = @_;
            if ($q =~ /c1\.COLUMN_TYPE != c2\.COLUMN_TYPE/i) {
                return (
                    "db1\ttable1\tcol1\tint(11)\tref_table\tid\tbigint(20)",
                    "db2\ttable2\tcol2\tvarchar(50)\tref_table2\tcode\tchar(10)",
                );
            }
            return ();
        };

        main::mysql_foreign_key_checks();

        is( scalar( grep { /FK Type Mismatch/ } @captured_bad ), 2,
            'mysql_foreign_key_checks reported both type mismatches to stderr/badprint' );
        is( scalar( grep { /Fix data type mismatch in Foreign Key/ } @generalrec ), 2,
            'mysql_foreign_key_checks pushed both to @generalrec' );
        is( scalar( grep { /FK Type Mismatch/ } @modeling ), 2,
            'mysql_foreign_key_checks pushed both to @modeling' );
    }
};

done_testing();
