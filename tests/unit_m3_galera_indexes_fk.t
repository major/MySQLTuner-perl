#!/usr/bin/env perl
# tests/unit_m3_galera_indexes_fk.t
# Validates Milestone 3:
#   - Issue 12A: Galera status in %mystat and wsrep options as array ref in mariadb_galera
#   - Issue 12B: Distinct character sets calculation in mysql_databases
#   - Issue 12C: Index TYPE resolution ($info[3]) and dual-resolution mock compatibility in mysql_indexes
#   - Issue 16:  Consolidation of FK type mismatch check in mysql_foreign_key_checks and removal from mysql_table_structures

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
# Subtest 1: Issue 12A - Galera Status Lookup from %mystat
# =====================================================================
subtest 'Issue 12A: Galera Status Metrics Read from %mystat' => sub {
    reset_state();

    no warnings 'redefine';
    local *main::cpu_cores = sub { return 8 };
    local *main::get_wsrep_option = sub { return 134217728 };
    local *main::get_wsrep_options = sub {
        return ( 'gcache.size = 256M', 'gcs.fc_limit = 64', 'evs.keepalive_period = 1' );
    };

    %myvar = (
        have_galera            => 'YES',
        wsrep_on               => 'ON',
        wsrep_provider_options => 'gcache.size = 256M; gcs.fc_limit = 64; evs.keepalive_period = 1',
        wsrep_slave_threads    => 4,
    );
    %mystat = (
        wsrep_local_state_comment => 'Synced',
        wsrep_cluster_size        => '3',
        wsrep_flow_control_paused => '0.000',
        wsrep_ready               => 'ON',
        wsrep_connected           => 'ON',
    );

    main::mariadb_galera();

    is( $result{'Galera'}{'status'}{'wsrep_local_state_comment'}, 'Synced',
        'wsrep_local_state_comment retrieved from %mystat (not undef from %myvar)' );
    is( $result{'Galera'}{'status'}{'wsrep_cluster_size'}, '3',
        'wsrep_cluster_size retrieved from %mystat' );
    is( $result{'Galera'}{'status'}{'wsrep_ready'}, 'ON',
        'wsrep_ready retrieved from %mystat' );
};

# =====================================================================
# Subtest 2: Issue 12A - wsrep options Assigned as Array Reference
# =====================================================================
subtest 'Issue 12A: wsrep options Stored as Array Reference' => sub {
    reset_state();

    no warnings 'redefine';
    local *main::cpu_cores = sub { return 4 };
    local *main::get_wsrep_option = sub { return 67108864 };
    local *main::get_wsrep_options = sub {
        return ( 'gcache.size = 128M', 'gcs.fc_factor = 0.5' );
    };

    %myvar = (
        have_galera            => 'YES',
        wsrep_on               => 'ON',
        wsrep_provider_options => 'gcache.size = 128M; gcs.fc_factor = 0.5',
    );
    %mystat = (
        wsrep_local_state_comment => 'Synced',
        wsrep_cluster_size        => '2',
    );

    main::mariadb_galera();

    ok( ref( $result{'Galera'}{'wsrep options'} ) eq 'ARRAY',
        'wsrep options is stored as an ARRAY reference (not a scalar count integer)' );
    is( scalar( @{ $result{'Galera'}{'wsrep options'} } ), 2,
        'Array reference contains expected 2 elements' );
    is( $result{'Galera'}{'wsrep options'}->[0], 'gcache.size = 128M',
        'First option element preserved intact' );
};

# =====================================================================
# Subtest 3: Issue 12B - Distinct Character Sets in mysql_databases
# =====================================================================
subtest 'Issue 12B: Distinct Character Sets (CHARS) in mysql_databases' => sub {
    reset_state();
    $opt{dbstat} = 1;

    no warnings 'redefine';
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_one = sub {
        my ($q) = @_;
        if ($q =~ /SELECT SUM\(TABLE_ROWS\)/i) {
            # Total dbinfo: 7 elements: rows, data, idx, tot, tables, collations (15), engines (3)
            return "1000 1048576 524288 1572864 20 15 3";
        }
        if ($q =~ /TABLE_SCHEMA='test_db'.*GROUP BY TABLE_SCHEMA/i) {
            return "test_db 500 524288 262144 786432 1 10 12 1";
        }
        return "1";
    };

    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /information_schema\.SCHEMATA/i) {
            return ('test_db');
        }
        if ($q =~ /distinct\(CHARACTER_SET_NAME\).*NOT IN/i) {
            # Global distinct charsets across all databases: exactly 3
            return ('utf8mb4', 'latin1', 'binary');
        }
        if ($q =~ /distinct\(CHARACTER_SET_NAME\).*TABLE_SCHEMA='test_db'/i) {
            # Per-database distinct charsets for test_db: exactly 2
            return ('utf8mb4', 'latin1');
        }
        if ($q =~ /DISTINCT\(TABLE_COLLATION\)/i) {
            return ('utf8mb4_general_ci', 'latin1_swedish_ci');
        }
        if ($q =~ /DISTINCT\(ENGINE\)/i) {
            return ('InnoDB');
        }
        return ();
    };

    main::mysql_databases();

    # Check global CHARS line
    my @global_chars = grep { /\+-- CHARS\s+:\s+3\s+\(utf8mb4,\s+latin1,\s+binary\)/ } @captured_info;
    ok( scalar(@global_chars) > 0,
        'Global CHARS reports scalar count of distinct character sets (3), not collation count (15)' );

    # Check per-database CHARS line
    my @db_chars = grep { /\+-- CHARS\s+:\s+2\s+\(utf8mb4,\s+latin1\)/ } @captured_info;
    ok( scalar(@db_chars) > 0,
        'Database test_db CHARS reports scalar count of db character sets (2), not global collation count' );
};

# =====================================================================
# Subtest 4: Issue 12C - Index Type Resolution ($info[3]) in mysql_indexes
# =====================================================================
subtest 'Issue 12C: Index TYPE Resolution ($info[3]) in mysql_indexes' => sub {
    reset_state();
    $opt{idxstat} = 1;
    $myvar{'performance_schema'} = 'OFF';

    no warnings 'redefine';
    local *main::select_user_dbs = sub { return ('ecommerce_db') };
    local *main::select_one = sub { return "5" };
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /GROUP BY table_name, idxname/i) {
            # Production 4-column format: idxname, cols, card, type
            return (
                "orders.idx_created_at created_at 15000 BTREE",
                "sessions.idx_token token 50000 HASH",
            );
        }
        return ();
    };

    main::mysql_indexes();

    ok( grep( /\+-- TYPE\s+:\s+BTREE/, @captured_info ),
        'Index type BTREE correctly resolved from column $info[3]' );
    ok( grep( /\+-- TYPE\s+:\s+HASH/, @captured_info ),
        'Index type HASH correctly resolved from column $info[3]' );
};

# =====================================================================
# Subtest 5: Issue 12C - Dual-Resolution Pattern Mock Compatibility
# =====================================================================
subtest 'Issue 12C: Dual-Resolution Pattern with Legacy 5-Column Mock' => sub {
    reset_state();
    $opt{idxstat} = 1;
    $myvar{'performance_schema'} = 'OFF';

    no warnings 'redefine';
    local *main::select_user_dbs = sub { return ('legacy_db') };
    local *main::select_one = sub { return "2" };
    local *main::mysql_version_ge = sub { return 1 };
    local *main::select_array = sub {
        my ($q) = @_;
        if ($q =~ /GROUP BY table_name, idxname/i) {
            # Legacy mock format (from unit_coverage_boost_queries.t):
            # idxname(0), cols(1), card(2), NULL(3), BTREE(4)
            return (
                "users.idx_email email 500 NULL BTREE",
            );
        }
        return ();
    };

    main::mysql_indexes();

    ok( grep( /\+-- TYPE\s+:\s+BTREE/, @captured_info ),
        'Dual-resolution pattern falls back to $info[4] when $info[3] is NULL' );
    ok( !grep( /\+-- TYPE\s+:\s+NULL/, @captured_info ),
        'Does not print literal NULL for index type' );
};

# =====================================================================
# Subtest 6: Issue 16 - FK Type Mismatch Consolidation in mysql_foreign_key_checks
# =====================================================================
subtest 'Issue 16: Elimination of Redundant FK Query in mysql_table_structures' => sub {
    reset_state();
    $opt{structstat} = 1;
    $opt{dumpdir} = 0;

    {
        my %queries_executed;
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
            push @captured_queries, $q;
            $queries_executed{$q}++;
            return ();
        };

        main::mysql_table_structures();

        # Ensure the redundant 3-table join query for FK mismatches was NOT executed
        my @fk_mismatch_queries = grep {
            /KEY_COLUMN_USAGE.*(?:c1\.DATA_TYPE != c2\.DATA_TYPE OR c1\.COLUMN_TYPE != c2\.COLUMN_TYPE)/is
        } @captured_queries;

        is( scalar(@fk_mismatch_queries), 0,
            'Redundant FK type mismatch query completely eliminated from mysql_table_structures' );
    }

    # Now verify mysql_foreign_key_checks operates as the single source of truth
    reset_state();
    no warnings 'redefine';
    local *main::dump_into_file = sub { };
    local *main::select_array = sub {
        my ($q) = @_;
        push @captured_queries, $q;
        if ($q =~ /c1\.COLUMN_TYPE != c2\.COLUMN_TYPE/i) {
            return ("shop\torders\tuser_id\tint(11)\tusers\tid\tbigint(20) unsigned");
        }
        return ();
    };

    main::mysql_foreign_key_checks();

    ok( grep( /FK Type Mismatch: shop\.orders\.user_id \(int\(11\)\) -> users\.id \(bigint\(20\) unsigned\)/, @captured_bad ),
        'mysql_foreign_key_checks correctly identifies and reports foreign key type mismatch' );
    ok( grep( /Fix data type mismatch in Foreign Key shop\.orders\.user_id \(int\(11\) vs bigint\(20\) unsigned\)/, @generalrec ),
        'Recommendation pushed to @generalrec by mysql_foreign_key_checks' );
    ok( grep( /FK Type Mismatch: shop\.orders\.user_id \(int\(11\)\) references users\.id \(bigint\(20\) unsigned\)/, @modeling ),
        'Finding pushed to @modeling by mysql_foreign_key_checks' );
};

done_testing();
