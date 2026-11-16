#!/usr/bin/env perl
# tests/unit_m1_index_stats_csv.t
# Validates Milestone 1 fixes:
#   - Issue 13A: mysql_indexes PFS object_name filtering with --ignore-tables
#   - Issue 13B: mysql_stats query_cache_type logical || check
#   - Issue 15: select_csv_file LIMIT clause deduplication

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# 1. Initialize globals and require mysqltuner.pl
our @adjvars;
our @generalrec;
our @modeling;
our @sysrec;
our @secrec;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;
our @dblist;
our $is_cloud;
our $cloud_type;
our $physical_memory;
our $is_win;

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# Shared mock state
my @mock_info_output;
my @mock_captured_queries;
my $mock_captured_csv_query;

sub reset_test_state {
    @mock_info_output      = ();
    @mock_captured_queries = ();
    $mock_captured_csv_query = undef;
    @main::generalrec      = ();
    @main::adjvars         = ();
    %main::result          = ();
    %main::opt             = ();
    %main::myvar           = ();
    %main::mystat          = ();
    %main::mycalc          = ();
}

{
    no warnings 'redefine';
    *main::infoprint      = sub { push @mock_info_output, "INFO: $_[0]" };
    *main::badprint       = sub { push @mock_info_output, "BAD: $_[0]" };
    *main::goodprint      = sub { push @mock_info_output, "GOOD: $_[0]" };
    *main::debugprint     = sub { };
    *main::subheaderprint = sub { };
    *main::hr_bytes       = sub { return "$_[0] B" };
    *main::hr_bytes_rnd   = sub { return "$_[0] B" };
    *main::get_pf_memory  = sub { return 0 };
    *main::get_gcache_memory = sub { return 0 };
    *main::select_one     = sub { return 1 };
    *main::select_user_dbs = sub { return ('testdb') };
    *main::mysql_version_ge = sub { return 1 };

    *main::select_array = sub {
        my ($query) = @_;
        push @mock_captured_queries, $query;
        if ($query =~ /performance_schema\.table_io_waits_summary_by_index_usage/i) {
            return ("testdb.active_table idx_active");
        }
        return ();
    };

    *main::select_array_with_headers = sub {
        my ($query) = @_;
        $mock_captured_csv_query = $query;
        return ("header1\theader2", "val1\tval2");
    };
}

# =====================================================================
# SUBTEST 1: Issue 13A - mysql_indexes PFS Column Name
# =====================================================================
subtest 'Issue 13A: mysql_indexes with --ignore-tables and PFS' => sub {
    reset_test_state();
    $main::opt{idxstat}          = 1;
    $main::opt{'ignore-tables'}  = 'ignored_tab1,ignored_tab2';
    $main::myvar{'performance_schema'} = 'ON';
    @main::dblist               = ('testdb');

    main::mysql_indexes();

    my ($pfs_query) = grep { /performance_schema\.table_io_waits_summary_by_index_usage/i } @mock_captured_queries;
    ok($pfs_query, "Performance schema index query was executed");
    like(
        $pfs_query,
        qr/AND\s+object_name\s+NOT\s+IN\s*\('\s*ignored_tab1\s*',\s*'\s*ignored_tab2\s*'\)/i,
        "PFS query uses object_name NOT IN (...)"
    );
    unlike($pfs_query, qr/TABLE_NAME\s+NOT\s+IN/i, "PFS query does NOT contain TABLE_NAME");

    my @is_queries = grep { /FROM\s+INFORMATION_SCHEMA/i } @mock_captured_queries;
    ok(scalar(@is_queries) > 0, "Information schema queries executed");
    for my $is_q (@is_queries) {
        like($is_q, qr/TABLE_NAME\s+NOT\s+IN/i, "Information schema queries continue using TABLE_NAME");
    }
};

subtest 'Issue 13A: mysql_indexes without --ignore-tables' => sub {
    reset_test_state();
    $main::opt{idxstat}          = 1;
    $main::opt{'ignore-tables'}  = '0';
    $main::myvar{'performance_schema'} = 'ON';
    @main::dblist               = ('testdb');

    main::mysql_indexes();

    my ($pfs_query) = grep { /performance_schema\.table_io_waits_summary_by_index_usage/i } @mock_captured_queries;
    ok($pfs_query, "Performance schema index query was executed");
    unlike($pfs_query, qr/object_name\s+NOT\s+IN/i, "No object_name exclusion filter injected when ignore-tables is '0'");
};

# =====================================================================
# SUBTEST 2: Issue 13B - mysql_stats query_cache_type Logical Check
# =====================================================================
subtest 'Issue 13B: mysql_stats query_cache_type logical evaluation' => sub {
    # 1. Source code inspection: ensure mysqltuner.pl uses logical || and not bitwise |
    open my $fh, '<', $script or die "Cannot open $script: $!";
    my $script_content = do { local $/; <$fh> };
    close $fh;

    like(
        $script_content,
        qr/\$myvar\{['"]query_cache_type['"]\}\s*eq\s*0\s*\|\|\s*\$myvar\{['"]query_cache_type['"]\}\s*eq\s*['"]OFF['"]/,
        "mysqltuner.pl source uses logical || for query_cache_type 0 or OFF check"
    );

    unlike(
        $script_content,
        qr/\$myvar\{['"]query_cache_type['"]\}\s*eq\s*0\s*\|(?!\|)/,
        "mysqltuner.pl source does not use bitwise | operator on query_cache_type"
    );

    # 2. Behavioral verification of short-circuit evaluation
    {
        {
            package MockVarTie;
            require Tie::Hash;
            our @ISA = qw(Tie::ExtraHash);
            our $fetches = 0;
            sub FETCH {
                my ($self, $key) = @_;
                if ($key eq 'query_cache_type') {
                    $fetches++;
                }
                return $self->[0]{$key};
            }
        }

        reset_test_state();
        tie %main::myvar, 'MockVarTie';
        $main::opt{buffers}                = 1;
        $main::myvar{'query_cache_type'}   = 0;
        $main::myvar{'query_cache_size'}   = 0;
        $main::myvar{'key_buffer_size'}    = 1024;
        $main::mycalc{'max_tmp_table_size'} = 1024;
        $main::myvar{'read_buffer_size'}   = 1024;
        $main::myvar{'read_rnd_buffer_size'} = 1024;
        $main::myvar{'sort_buffer_size'}   = 1024;
        $main::myvar{'thread_stack'}       = 1024;
        $main::myvar{'join_buffer_size'}   = 1024;
        $main::myvar{'log_bin'}            = 'OFF';
        $main::myvar{'max_connections'}    = 100;

        $MockVarTie::fetches = 0;
        {
            local $SIG{__WARN__} = sub {};
            main::mysql_stats();
        }
        # With logical ||: exactly 3 fetches (defined, string concat, eq 0; eq 'OFF' is short-circuited)
        # With bitwise |: 4 fetches (both eq 0 and eq 'OFF' are evaluated)
        is($MockVarTie::fetches, 3, "Logical || short-circuits: exactly 3 fetches of query_cache_type when val is 0 (bitwise | performs 4)");
        untie %main::myvar;
    }

    # 3. Functional output matrix across supported values
    my @test_cases = (
        { val => 'OFF',    expected => 'Query Cache: OFF - DISABLED' },
        { val => '0',      expected => 'Query Cache: 0 - DISABLED' },
        { val => 0,        expected => 'Query Cache: 0 - DISABLED' },
        { val => '1',      expected => 'Query Cache: 1 - ALL REQUESTS' },
        { val => 1,        expected => 'Query Cache: 1 - ALL REQUESTS' },
        { val => 'DEMAND', expected => 'Query Cache: DEMAND - ON DEMAND' },
        { val => '2',      expected => 'Query Cache: 2 - ON DEMAND' },
    );

    for my $tc (@test_cases) {
        reset_test_state();
        $main::opt{buffers}                = 1;
        $main::myvar{'query_cache_type'}   = $tc->{val};
        $main::myvar{'query_cache_size'}   = 0;
        $main::myvar{'key_buffer_size'}    = 1024;
        $main::mycalc{'max_tmp_table_size'} = 1024;
        $main::myvar{'read_buffer_size'}   = 1024;
        $main::myvar{'read_rnd_buffer_size'} = 1024;
        $main::myvar{'sort_buffer_size'}   = 1024;
        $main::myvar{'thread_stack'}       = 1024;
        $main::myvar{'join_buffer_size'}   = 1024;
        $main::myvar{'log_bin'}            = 'OFF';
        $main::myvar{'max_connections'}    = 100;

        my @warnings_caught;
        {
            local $SIG{__WARN__} = sub { push @warnings_caught, $_[0] };
            main::mysql_stats();
        }

        ok(grep({ $_ =~ /\Q$tc->{expected}\E/ } @mock_info_output), "Displays '$tc->{expected}' for val '$tc->{val}'");
        my @qc_warnings = grep { /bitwise/i || ( /Argument/i && /bitwise/i ) } @warnings_caught;
        is(scalar(@qc_warnings), 0, "No bitwise operator warnings emitted for val '$tc->{val}'");
    }
};

# =====================================================================
# SUBTEST 3: Issue 15 - select_csv_file LIMIT Deduplication
# =====================================================================
subtest 'Issue 15: select_csv_file does not duplicate existing LIMIT' => sub {
    my $temp_dir = tempdir(CLEANUP => 1);
    my $tmp_file = File::Spec->catfile($temp_dir, 'export_test.csv');

    # Case A: Plain query without LIMIT -> appends default LIMIT 50000
    reset_test_state();
    $main::opt{'dump-limit'} = 50000;
    main::select_csv_file($tmp_file, "SELECT user, host FROM mysql.user");
    is($mock_captured_csv_query, "SELECT user, host FROM mysql.user LIMIT 50000", "Appends LIMIT 50000 when none present");

    # Case B: Query with trailing semicolon -> replaces semicolon with LIMIT 50000;
    reset_test_state();
    $main::opt{'dump-limit'} = 50000;
    main::select_csv_file($tmp_file, "SELECT user, host FROM mysql.user;");
    is($mock_captured_csv_query, "SELECT user, host FROM mysql.user LIMIT 50000;", "Replaces semicolon with LIMIT 50000;");

    # Case C: Query with existing uppercase LIMIT -> preserved untouched
    reset_test_state();
    $main::opt{'dump-limit'} = 50000;
    main::select_csv_file($tmp_file, "SELECT user, host FROM mysql.user LIMIT 10");
    is($mock_captured_csv_query, "SELECT user, host FROM mysql.user LIMIT 10", "Preserves existing LIMIT 10 without duplicate");

    # Case D: Query with existing uppercase LIMIT and semicolon -> preserved untouched
    reset_test_state();
    $main::opt{'dump-limit'} = 50000;
    main::select_csv_file($tmp_file, "SELECT user, host FROM mysql.user LIMIT 10;");
    is($mock_captured_csv_query, "SELECT user, host FROM mysql.user LIMIT 10;", "Preserves existing LIMIT 10; without duplicate");

    # Case E: Query with lowercase limit -> preserved untouched
    reset_test_state();
    $main::opt{'dump-limit'} = 50000;
    main::select_csv_file($tmp_file, "SELECT user, host FROM mysql.user limit 25;");
    is($mock_captured_csv_query, "SELECT user, host FROM mysql.user limit 25;", "Case-insensitively preserves existing limit 25;");

    # Case F: Query with LIMIT and offset -> preserved untouched
    reset_test_state();
    $main::opt{'dump-limit'} = 50000;
    main::select_csv_file($tmp_file, "SELECT user, host FROM mysql.user LIMIT 5, 20;");
    is($mock_captured_csv_query, "SELECT user, host FROM mysql.user LIMIT 5, 20;", "Preserves existing LIMIT with offset");

    # Case G: --dump-limit=0 disables limit addition
    reset_test_state();
    $main::opt{'dump-limit'} = 0;
    main::select_csv_file($tmp_file, "SELECT user, host FROM mysql.user");
    is($mock_captured_csv_query, "SELECT user, host FROM mysql.user", "Does not add LIMIT when --dump-limit=0");

    # Case H: Custom dump-limit
    reset_test_state();
    $main::opt{'dump-limit'} = 200;
    main::select_csv_file($tmp_file, "SELECT user, host FROM mysql.user");
    is($mock_captured_csv_query, "SELECT user, host FROM mysql.user LIMIT 200", "Appends custom dump-limit 200");
};

done_testing();
