#!/usr/bin/env perl
# tests/challenger_m3_issues_9_12_16.t
# Adversarial Stress Test Suite for Milestone 3:
#   - Issue 9:  PFS & GCache memory caching (single execution, 0-value preservation, edge cases)
#   - Issue 12: Galera %mystat lookup, wsrep options arrayref, distinct charsets count, dual-resolution index TYPE
#   - Issue 16: Complete elimination of redundant FK mismatch query in mysql_table_structures and proper reporting in mysql_foreign_key_checks

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempdir);
use Cwd 'abs_path';

# Suppress harmless subroutine redefine warnings when loading mysqltuner.pl
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

our @generalrec;
our @modeling;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
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
    %opt              = (
        tbstat  => 0,
        pfstat  => 0,
        buffers => 0,
    );
    %myvar            = (
        long_query_time   => 10,
        query_cache_size  => 0,
        thread_cache_size => 8,
        concurrent_insert => 'AUTO',
        log_bin           => 'OFF',
        version           => '10.5.20-MariaDB',
        max_connections   => 150,
    );
    %mystat           = (
        Created_tmp_tables => 0,
        Open_tables        => 0,
        Uptime             => 86400,
        Questions          => 10000,
        Connections        => 200,
        Bytes_sent         => 1048576,
        Bytes_received     => 524288,
    );
    %mycalc           = (
        server_buffers                => 1073741824,
        per_thread_buffers            => 2097152,
        total_sorts                   => 0,
        joins_without_indexes_per_day => 0,
        thread_cache_hit_rate         => 100,
    );
    @dblist           = ();
    $selIdxReq        = '';
}

{
    no warnings 'redefine';
    *main::infoprint      = sub { push @captured_info, $_[0] };
    *main::goodprint      = sub { push @captured_good, $_[0] };
    *main::badprint       = sub { push @captured_bad, $_[0] };
    *main::subheaderprint = sub { };
    *main::debugprint     = sub { };
}

# =====================================================================
# Subtest 1: Issue 9 - Adversarial Stress on PFS & GCache Memory Caching
# =====================================================================
subtest 'Issue 9: PFS & GCache Memory Caching Under Adversarial Conditions' => sub {
    reset_state();

    my $pf_calls = 0;
    my $gcache_calls = 0;

    no warnings 'redefine';
    local *main::get_pf_memory = sub {
        $pf_calls++;
        return 0; # Edge case: 0 memory reported (PFS active but 0 bytes)
    };
    local *main::get_gcache_memory = sub {
        $gcache_calls++;
        return 0; # Edge case: 0 bytes reported
    };

    # 1.1: Verify single execution in mysql_stats when memory returns 0
    main::mysql_stats();

    is( $pf_calls, 1, 'get_pf_memory() executed exactly once in mysql_stats even when returning 0' );
    is( $gcache_calls, 1, 'get_gcache_memory() executed exactly once in mysql_stats even when returning 0' );
    is( $result{'Performance_schema'}{'memory'}, 0, 'Zero PFS memory safely recorded in %result' );
    is( $result{'Galera'}{'GCache'}{'memory'}, 0, 'Zero GCache memory safely recorded in %result' );

    # 1.2: Crucial // defined-or check: 0 is defined!
    # In mysql_pfs, $result{'Performance_schema'}{'memory'} is 0.
    # If // is used correctly, get_pf_memory() MUST NOT be called again!
    # (If || were used, 0 would be false and trigger re-execution).
    $myvar{'performance_schema'} = 'ON';
    $opt{pfstat} = 1;
    local *main::select_array = sub { return ('sys'); };

    main::mysql_pfs();

    is( $pf_calls, 1, 'get_pf_memory() NOT re-executed when cached value in %result is 0 (defined-or // verification)' );
    ok( grep( /Memory used by Performance_schema:\s+0B/, @captured_info ),
        'PFS memory printed correctly as 0B from cached 0 value' );

    # 1.3: Large GCache memory parsing and single call
    reset_state();
    $pf_calls = 0;
    $gcache_calls = 0;

    local *main::get_pf_memory = sub {
        $pf_calls++;
        return 134217728; # 128 MB
    };
    local *main::get_gcache_memory = sub {
        $gcache_calls++;
        return 17179869184; # 16 GB
    };

    main::mysql_stats();

    is( $pf_calls, 1, 'get_pf_memory() called once for 128MB' );
    is( $gcache_calls, 1, 'get_gcache_memory() called once for 16GB' );
    is( $result{'Galera'}{'GCache'}{'memory'}, 17179869184, 'Large 16GB GCache stored in %result' );
    is( $result{'Galera'}{'GCache'}{'pretty_memory'}, '16G', 'Pretty memory formats 16GB as 16G' );

    # 1.4: Repeated calls to mysql_pfs with populated cache
    for (1..3) {
        main::mysql_pfs();
    }
    is( $pf_calls, 1, 'Multiple successive calls to mysql_pfs never re-execute get_pf_memory()' );
};

# =====================================================================
# Subtest 2: Issue 12A - Galera Telemetry Adversarial Stress
# =====================================================================
subtest 'Issue 12A: Galera Telemetry (%mystat vs %myvar & wsrep options arrayref)' => sub {
    reset_state();

    no warnings 'redefine';
    local *main::cpu_cores = sub { return 4 };
    local *main::get_wsrep_option = sub { return 67108864 };
    local *main::get_wsrep_options = sub {
        return (
            'gcache.size = 64M',
            'gcs.fc_limit = 32',
            'evs.keepalive_period = 1',
            'gmcast.listen_addr = tcp://0.0.0.0:4567'
        );
    };

    # Plant decoy values in %myvar that must NOT leak into $result{'Galera'}{'status'}
    %myvar = (
        have_galera               => 'YES',
        wsrep_on                  => 'ON',
        wsrep_provider_options    => 'gcache.size = 64M; gcs.fc_limit = 32',
        wsrep_cluster_size        => 'DECOY_VAR_VALUE',
        wsrep_local_state_comment => 'DECOY_LOCAL_STATE',
        wsrep_slave_threads       => 8,
    );

    # Real status values in %mystat
    %mystat = (
        wsrep_cluster_size        => '3',
        wsrep_local_state_comment => 'Synced',
        wsrep_ready               => 'ON',
        wsrep_connected           => 'ON',
        wsrep_flow_control_paused => '0.000000',
        wsrep_cert_deps_distance  => '25.3',
    );

    main::mariadb_galera();

    # 2.1: Verify status reads strictly from %mystat, not %myvar
    is( $result{'Galera'}{'status'}{'wsrep_cluster_size'}, '3',
        'wsrep_cluster_size read from %mystat ("3"), ignoring decoy in %myvar' );
    is( $result{'Galera'}{'status'}{'wsrep_local_state_comment'}, 'Synced',
        'wsrep_local_state_comment read from %mystat ("Synced"), ignoring decoy in %myvar' );
    is( $result{'Galera'}{'status'}{'wsrep_ready'}, 'ON',
        'wsrep_ready read from %mystat' );
    is( $result{'Galera'}{'status'}{'wsrep_flow_control_paused'}, '0.000000',
        'wsrep_flow_control_paused read from %mystat' );

    # 2.2: Verify wsrep options array reference structure
    my $wsrep_opts = $result{'Galera'}{'wsrep options'};
    ok( defined $wsrep_opts, 'wsrep options exists in %result' );
    is( ref($wsrep_opts), 'ARRAY', 'wsrep options is an ARRAY reference' );
    is( scalar(@$wsrep_opts), 4, 'wsrep options array contains all 4 parsed elements' );
    is( $wsrep_opts->[0], 'gcache.size = 64M', 'Option 0 intact' );
    is( $wsrep_opts->[3], 'gmcast.listen_addr = tcp://0.0.0.0:4567', 'Option 3 intact' );

    # 2.3: Edge case: Galera disabled (wsrep_on != 'ON')
    reset_state();
    %myvar = ( wsrep_on => 'OFF' );
    main::mariadb_galera();
    ok( grep( /Galera is disabled\./, @captured_info ), 'Correctly reports Galera disabled when wsrep_on is OFF' );
    ok( !exists $result{'Galera'}{'status'}, 'No status populated when Galera is disabled' );
};

# =====================================================================
# Subtest 3: Issue 12B - Distinct Character Sets Adversarial Stress
# =====================================================================
subtest 'Issue 12B: Distinct Character Sets (CHARS) Under High Collation Diversity' => sub {
    reset_state();
    $opt{dbstat} = 1;
    @dblist = ('polyglot_db');

    no warnings 'redefine';
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_one = sub {
        my ($q) = @_;
        if ($q =~ /SELECT SUM\(TABLE_ROWS\)/i) {
            # Total dbinfo: 7 elements: rows, data, idx, tot, tables, collations (42), engines (1)
            # High collation count = 42, but only 3 character sets!
            return "100000 10485760 5242880 15728640 50 42 1";
        }
        if ($q =~ /TABLE_SCHEMA='polyglot_db'.*GROUP BY TABLE_SCHEMA/i) {
            return "polyglot_db 100000 10485760 5242880 15728640 1 50 42 1";
        }
        if ($q =~ /SELECT count\(\*\) from information_schema\.TABLES WHERE TABLE_TYPE ='BASE TABLE'/i) {
            return "50";
        }
        if ($q =~ /SELECT count\(\*\) from information_schema\.TABLES WHERE TABLE_TYPE ='VIEW'/i) {
            return "0";
        }
        if ($q =~ /SELECT count\(distinct.*information_schema\.STATISTICS/i) {
            return "30";
        }
        if ($q =~ /COUNT\(\*\).*ENGINE='InnoDB'/i) {
            return "50";
        }
        return "1";
    };

    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /information_schema\.SCHEMATA/i) {
            return ('polyglot_db');
        }
        if ($q =~ /distinct\(CHARACTER_SET_NAME\).*NOT IN/i) {
            # 4 distinct charsets across 42 collations globally
            return ('utf8mb4', 'latin1', 'utf8mb3', 'binary');
        }
        if ($q =~ /distinct\(CHARACTER_SET_NAME\).*TABLE_SCHEMA='polyglot_db'/i) {
            # 3 distinct charsets in polyglot_db
            return ('utf8mb4', 'latin1', 'utf8mb3');
        }
        if ($q =~ /DISTINCT\(TABLE_COLLATION\)/i) {
            return ('utf8mb4_0900_ai_ci', 'latin1_swedish_ci', 'utf8mb3_general_ci');
        }
        if ($q =~ /DISTINCT\(ENGINE\)/i) {
            return ('InnoDB');
        }
        return ();
    };

    main::mysql_databases();

    # Verify global CHARS output: must be exactly 4, not 42!
    my @global_chars = grep { /\+-- CHARS\s+:\s+4\s+\(utf8mb4,\s+latin1,\s+utf8mb3,\s+binary\)/ } @captured_info;
    is( scalar(@global_chars), 1, 'Global CHARS accurately reports 4 distinct charsets despite 42 collations' );
    ok( !grep( /\+-- CHARS\s+:\s+42/, @captured_info ), 'Global CHARS does NOT report collation count (42)' );

    # Verify database polyglot_db CHARS output: must be exactly 3, not 42!
    my @db_chars = grep { /\+-- CHARS\s+:\s+3\s+\(utf8mb4,\s+latin1,\s+utf8mb3\)/ } @captured_info;
    is( scalar(@db_chars), 1, 'Database CHARS accurately reports 3 distinct charsets in polyglot_db' );

    # Edge case: Empty database (0 character sets)
    reset_state();
    $opt{dbstat} = 1;
    @dblist = ('empty_db');
    local *main::select_one = sub {
        my ($q) = @_;
        if ($q =~ /SELECT SUM\(TABLE_ROWS\)/i) {
            return "0 0 0 0 0 NULL NULL";
        }
        if ($q =~ /TABLE_SCHEMA='empty_db'.*GROUP BY TABLE_SCHEMA/i) {
            return "empty_db 0 0 0 0 0 0 NULL 0";
        }
        return "0";
    };
    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /information_schema\.SCHEMATA/i) {
            return ('empty_db');
        }
        return (); # 0 charsets, 0 collations
    };

    main::mysql_databases();
    ok( grep( /\+-- CHARS\s+:\s+0 \(\)/, @captured_info ), 'Empty database safely outputs CHARS: 0 () without warnings' );
};

# =====================================================================
# Subtest 4: Issue 12C - Dual-Resolution Index TYPE Adversarial Stress
# =====================================================================
subtest 'Issue 12C: Index TYPE Dual-Resolution ($info[3] / $info[4]) Stress' => sub {
    reset_state();
    $opt{idxstat} = 1;
    $myvar{'performance_schema'} = 'OFF';

    no warnings 'redefine';
    local *main::select_user_dbs = sub { return ('test_indexes_db') };
    local *main::select_one = sub { return "4" };
    local *main::mysql_version_ge = sub { return 1 };

    # Stress case 1: Real MySQL 4-column output with various engine types (BTREE, HASH, FULLTEXT, SPATIAL)
    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /GROUP BY table_name, idxname/i) {
            return (
                "tbl.idx_btree c1 1000 BTREE",
                "tbl.idx_hash c2 500 HASH",
                "tbl.idx_fulltext c3 200 FULLTEXT",
                "tbl.idx_spatial c4 50 SPATIAL",
            );
        }
        return ();
    };

    main::mysql_indexes();

    ok( grep( /\+-- TYPE\s+:\s+BTREE/, @captured_info ), 'Resolved $info[3] BTREE' );
    ok( grep( /\+-- TYPE\s+:\s+HASH/, @captured_info ), 'Resolved $info[3] HASH' );
    ok( grep( /\+-- TYPE\s+:\s+FULLTEXT/, @captured_info ), 'Resolved $info[3] FULLTEXT' );
    ok( grep( /\+-- TYPE\s+:\s+SPATIAL/, @captured_info ), 'Resolved $info[3] SPATIAL' );

    # Stress case 2: Legacy mock 5-column format where $info[3] is NULL and $info[4] is the type
    reset_state();
    $opt{idxstat} = 1;
    $myvar{'performance_schema'} = 'OFF';

    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /GROUP BY table_name, idxname/i) {
            return (
                "tbl.idx_legacy c1 100 NULL BTREE",
                "tbl.idx_legacy_hash c2 200 NULL HASH",
            );
        }
        return ();
    };

    main::mysql_indexes();

    ok( grep( /\+-- TYPE\s+:\s+BTREE/, @captured_info ), 'Fallback to $info[4] for legacy BTREE mock' );
    ok( grep( /\+-- TYPE\s+:\s+HASH/, @captured_info ), 'Fallback to $info[4] for legacy HASH mock' );
    ok( !grep( /\+-- TYPE\s+:\s+NULL/, @captured_info ), 'Never outputs literal NULL when $info[4] is present' );

    # Stress case 3: Truncated 3-column input where type is missing entirely ($info[3] and $info[4] undef)
    reset_state();
    $opt{idxstat} = 1;
    $myvar{'performance_schema'} = 'OFF';

    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /GROUP BY table_name, idxname/i) {
            return (
                "tbl.idx_truncated c1 50",
            );
        }
        return ();
    };

    main::mysql_indexes();

    ok( grep( /\+-- INDEX\s+:\s+tbl\.idx_truncated/, @captured_info ), 'Processed index even without type' );
    ok( !grep( /\+-- TYPE/, @captured_info ), 'Omitted TYPE line cleanly when type is completely undefined' );
};

# =====================================================================
# Subtest 5: Issue 16 - Intercepting and Verifying Zero FK Queries in mysql_table_structures
# =====================================================================
subtest 'Issue 16: Empirical Proof of Zero FK Mismatch Queries in mysql_table_structures' => sub {
    reset_state();
    $opt{structstat} = 1;
    $opt{dumpdir} = tempdir( CLEANUP => 1 );

    my @queries_in_table_structures;

    no warnings 'redefine';
    local *main::dump_into_file = sub { };
    local *main::mysql_naming_conventions = sub { };
    local *main::mysql_foreign_key_checks = sub { }; # Stub out child call to isolate mysql_table_structures body
    local *main::mysql_80_modeling_checks = sub { };
    local *main::mysql_datatype_optimization = sub { };
    local *main::mysql_schema_sanitization = sub { };
    local *main::select_one = sub { return "0" };
    local *main::select_array = sub {
        my ($q) = @_;
        push @queries_in_table_structures, $q;
        return ();
    };

    main::mysql_table_structures();

    # Assertive verification: NO query matching KEY_COLUMN_USAGE and c1.COLUMN_TYPE != c2.COLUMN_TYPE
    my @fk_queries = grep {
        /key_column_usage/i && /c1\.COLUMN_TYPE\s*!=\s*c2\.COLUMN_TYPE/i
    } @queries_in_table_structures;

    is( scalar(@fk_queries), 0,
        'ABSOLUTE CONFIRMATION: Zero FK type mismatch queries executed in mysql_table_structures body' );

    # Also assert that other structural queries (non-InnoDB, non-UTF8, fulltext, large tables) WERE executed
    ok( grep( /ENGINE <> 'InnoDB'/i, @queries_in_table_structures ),
        'mysql_table_structures still executes non-InnoDB table query' );
    ok( grep( /CHARacter_set_name\s+NOT LIKE 'utf8%'/i, @queries_in_table_structures ),
        'mysql_table_structures still executes non-UTF8 columns query' );
    ok( grep( /data_type='FULLTEXT'/i, @queries_in_table_structures ),
        'mysql_table_structures still executes fulltext columns query' );
};

# =====================================================================
# Subtest 6: Issue 16 - Proper Reporting & CSV Export in mysql_foreign_key_checks
# =====================================================================
subtest 'Issue 16: Comprehensive FK Type Mismatch Reporting & Export in mysql_foreign_key_checks' => sub {
    reset_state();

    my $temp_dir = tempdir( CLEANUP => 1 );
    $opt{dumpdir} = $temp_dir;

    my %written_files;
    no warnings 'redefine';
    local *main::dump_into_file = sub {
        my ($fname, $content) = @_;
        $written_files{$fname} = $content;
    };

    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /k\.COLUMN_NAME IS NULL/i) {
            # Unconstrained _id query
            return ("shop\torders\tuser_id");
        }
        if ($q =~ /DELETE_RULE/i) {
            # FK Actions query
            return ("shop\torders\tuser_id\tusers\tid\tCASCADE");
        }
        if ($q =~ /c1\.COLUMN_TYPE != c2\.COLUMN_TYPE/i) {
            # FK Type Mismatch query
            return (
                "shop\torders\tuser_id\tint(11)\tusers\tid\tbigint(20) unsigned",
                "shop\tinvoices\tamount_id\tsmallint(6)\tamounts\tid\tint(11)"
            );
        }
        return ();
    };

    main::mysql_foreign_key_checks();

    # 6.1: Verify badprints for both type mismatches
    ok( grep( /FK Type Mismatch: shop\.orders\.user_id \(int\(11\)\) -> users\.id \(bigint\(20\) unsigned\)/, @captured_bad ),
        'Badprint reports orders.user_id mismatch' );
    ok( grep( /FK Type Mismatch: shop\.invoices\.amount_id \(smallint\(6\)\) -> amounts\.id \(int\(11\)\)/, @captured_bad ),
        'Badprint reports invoices.amount_id mismatch' );

    # 6.2: Verify @generalrec entries
    ok( grep( /Fix data type mismatch in Foreign Key shop\.orders\.user_id \(int\(11\) vs bigint\(20\) unsigned\)/, @generalrec ),
        '@generalrec receives orders.user_id recommendation' );
    ok( grep( /Fix data type mismatch in Foreign Key shop\.invoices\.amount_id \(smallint\(6\) vs int\(11\)\)/, @generalrec ),
        '@generalrec receives invoices.amount_id recommendation' );

    # 6.3: Verify @modeling entries
    ok( grep( /FK Type Mismatch: shop\.orders\.user_id \(int\(11\)\) references users\.id \(bigint\(20\) unsigned\)/, @modeling ),
        '@modeling receives orders.user_id finding' );
    ok( grep( /FK Type Mismatch: shop\.invoices\.amount_id \(smallint\(6\)\) references amounts\.id \(int\(11\)\)/, @modeling ),
        '@modeling receives invoices.amount_id finding' );

    # 6.4: Verify missing_foreign_keys.csv export when dumpdir is provided
    ok( exists $written_files{"missing_foreign_keys.csv"}, 'Dumpfile missing_foreign_keys.csv created' );
    my $csv = $written_files{"missing_foreign_keys.csv"};
    ok( $csv =~ /^Schema,Table,Column,IssueType,Description/m, 'CSV contains valid schema header' );
    ok( $csv =~ /shop,orders,user_id,TypeMismatch,Foreign key type mismatch: int\(11\) references users\.id \(bigint\(20\) unsigned\)/,
        'CSV contains orders.user_id mismatch row' );
    ok( $csv =~ /shop,invoices,amount_id,TypeMismatch,Foreign key type mismatch: smallint\(6\) references amounts\.id \(int\(11\)\)/,
        'CSV contains invoices.amount_id mismatch row' );

    # 6.5: Clean state check: 0 FK issues
    reset_state();
    $opt{dumpdir} = 0;
    local *main::select_array = sub { return (); }; # No issues returned

    main::mysql_foreign_key_checks();

    ok( grep( /No foreign key issues found/, @captured_good ),
        'Outputs "No foreign key issues found" when all constraints match' );
    is( scalar(@generalrec), 0, 'Zero recommendations pushed when clean' );
    is( scalar(@modeling), 0, 'Zero modeling findings pushed when clean' );
};

done_testing();
