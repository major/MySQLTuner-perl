#!/usr/bin/env perl
# tests/t_challenger_m1_stress.t
# Adversarial Stress Test Suite for Milestone 1 Changes:
#   1. Challenge select_one escaping (malicious injections, nested backticks, unbalanced quotes, dollar sign expressions)
#   2. Challenge select_csv_file duplicate limit prevention (obscure queries, multiline, subqueries, OFFSET, semicolons)
#   3. Challenge mysql_indexes PFS table query (edge cases, quotes, empty, multiple tables)
#   4. Challenge mysql_stats query_cache_type under strict fatal warning handlers

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Cwd 'abs_path';

# Setup environment
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
our $mysqlcmd;
our $mysqllogin;
our $devnull;
our $is_win;

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# =====================================================================
# SUBTEST 1: Challenge select_one escaping (Empirical Shell Execution)
# =====================================================================
subtest 'Challenge 1: select_one escaping adversarial harness' => sub {
    my $temp_dir = tempdir(CLEANUP => 1);
    my $canary_file = File::Spec->catfile($temp_dir, 'canary_pwned.txt');

    # 1.1: Malicious Command Injection via Dollar Subshell and Backticks
    my @malicious_injections = (
        "SELECT \$(touch '$canary_file') AS pwned",
        "SELECT `touch '$canary_file'` AS pwned",
        "SELECT 1; touch '$canary_file';",
        "SELECT 1 | touch '$canary_file'",
        "SELECT 1 & touch '$canary_file' &",
        "SELECT 1 > '$canary_file'",
    );

    # Mock execute_system_command to actually run shell commands via real /bin/sh
    # but using a safe echo-based receiver for the mysql client command
    my $echo_arg_capture = File::Spec->catfile($temp_dir, 'captured_args.txt');

    no warnings 'redefine';
    local *main::debugprint = sub { };
    local *main::badprint   = sub { };

    # We set $mysqlcmd to a real shell wrapper that writes its exact arguments to $echo_arg_capture
    my $wrapper_script = File::Spec->catfile($temp_dir, 'mysql_mock.sh');
    open(my $wfh, '>', $wrapper_script) or die "Cannot create wrapper: $!";
    print $wfh "#!/bin/sh\n";
    print $wfh "echo \"\$@\" > '$echo_arg_capture'\n";
    print $wfh "exit 0\n";
    close($wfh);
    chmod(0755, $wrapper_script);

    local $main::mysqlcmd   = "'$wrapper_script'";
    local $main::mysqllogin = '';
    local $main::devnull    = '/dev/null';

    for my $malicious_sql (@malicious_injections) {
        unlink($canary_file) if -e $canary_file;
        unlink($echo_arg_capture) if -e $echo_arg_capture;

        main::select_one($malicious_sql);

        ok(! -e $canary_file, "Canary file was NOT created by injection: $malicious_sql");
    }

    # 1.2: Dollar Sign Expressions (${VAR}, $(), $((math)), $$, $1)
    my $test_user = $ENV{USER} // 'nobody';
    my @dollar_tests = (
        {
            sql      => 'SELECT "${USER}"',
            expected => '-Bse SELECT "${USER}"',
            desc     => '${USER} is not expanded by shell',
        },
        {
            sql      => 'SELECT "$USER"',
            expected => '-Bse SELECT "$USER"',
            desc     => '$USER is not expanded by shell',
        },
        {
            sql      => 'SELECT "$((10 + 20))"',
            expected => '-Bse SELECT "$((10 + 20))"',
            desc     => 'Arithmetic expansion $((10 + 20)) is not evaluated',
        },
        {
            sql      => 'SELECT "$$ $? $! $0"',
            expected => '-Bse SELECT "$$ $? $! $0"',
            desc     => 'Special parameters ($$, $?, $!, $0) are preserved literally',
        },
        {
            sql      => 'SELECT "\$USER"',
            expected => '-Bse SELECT "$USER"',
            desc     => 'Pre-escaped dollar sign safely preserved as literal dollar by shell',
        },
        {
            sql      => 'SELECT "\\$USER"',
            expected => '-Bse SELECT "$USER"',
            desc     => 'Double backslash dollar sign safely preserved as literal dollar by shell',
        },
    );

    for my $dt (@dollar_tests) {
        unlink($echo_arg_capture) if -e $echo_arg_capture;
        main::select_one($dt->{sql});
        
        my $captured = '';
        if (open(my $rfh, '<', $echo_arg_capture)) {
            $captured = <$rfh>;
            chomp($captured) if defined $captured;
            close($rfh);
        }
        is($captured, $dt->{expected}, "$dt->{desc}");
    }

    # 1.3: Nested and Multiple Backticks
    my @backtick_tests = (
        {
            sql      => 'SELECT `col` FROM `tbl`',
            expected => '-Bse SELECT `col` FROM `tbl`',
            desc     => 'Standard backticks preserved literally',
        },
        {
            sql      => 'SELECT `nested```backtick` FROM `t`',
            expected => '-Bse SELECT `nested```backtick` FROM `t`',
            desc     => 'Escaped doubled backticks preserved literally',
        },
        {
            sql      => 'SELECT `a`.`b`.`c`',
            expected => '-Bse SELECT `a`.`b`.`c`',
            desc     => 'Multiple dot-separated backtick identifiers',
        },
    );

    for my $bt (@backtick_tests) {
        unlink($echo_arg_capture) if -e $echo_arg_capture;
        main::select_one($bt->{sql});

        my $captured = '';
        if (open(my $rfh, '<', $echo_arg_capture)) {
            $captured = <$rfh>;
            chomp($captured) if defined $captured;
            close($rfh);
        }
        is($captured, $bt->{expected}, "$bt->{desc}");
    }

    # 1.4: Unbalanced Quotes and Edge Case Quotations
    # Note: Unbalanced double quotes in shell strings exit with shell error; select_one must return "" and not crash
    my @unbalanced_tests = (
        'SELECT "unbalanced',
        'SELECT \'unbalanced',
        'SELECT `unbalanced',
        'SELECT "quote\\"with\\backslashes\\"',
    );

    for my $ub (@unbalanced_tests) {
        my $ret = eval { main::select_one($ub) };
        ok(defined $ret, "select_one did not die on unbalanced input: $ub");
        is($@, '', "No fatal perl exception thrown on unbalanced input: $ub");
    }
};

# =====================================================================
# SUBTEST 2: Challenge select_csv_file duplicate limit prevention
# =====================================================================
subtest 'Challenge 2: select_csv_file with obscure SQL queries' => sub {
    my $temp_dir = tempdir(CLEANUP => 1);
    my $tmp_file = File::Spec->catfile($temp_dir, 'export_obscure.csv');

    my $captured_query;
    no warnings 'redefine';
    local *main::select_array_with_headers = sub {
        my ($q) = @_;
        $captured_query = $q;
        return ("col1\tcol2", "val1\tval2");
    };

    local $main::opt{'dump-limit'} = 50000;

    my @obscure_cases = (
        # 1. Multiline LIMIT
        {
            name  => "Multiline LIMIT across lines",
            sql   => "SELECT * FROM mysql.user\nWHERE 1=1\nLIMIT\n  25;",
            check => sub {
                my ($res) = @_;
                is($res, "SELECT * FROM mysql.user\nWHERE 1=1\nLIMIT\n  25;", "Multiline LIMIT preserved without duplicate LIMIT");
            }
        },
        # 2. Subquery containing LIMIT
        {
            name  => "Derived table subquery with LIMIT",
            sql   => "SELECT * FROM (SELECT id, name FROM users LIMIT 10) AS top_u;",
            check => sub {
                my ($res) = @_;
                is($res, "SELECT * FROM (SELECT id, name FROM users LIMIT 10) AS top_u;", "Subquery LIMIT detected; does not append second LIMIT");
            }
        },
        # 3. Subquery in WHERE clause with LIMIT
        {
            name  => "Subquery in WHERE with LIMIT",
            sql   => "SELECT * FROM users WHERE id IN (SELECT uid FROM active_logins LIMIT 100);",
            check => sub {
                my ($res) = @_;
                is($res, "SELECT * FROM users WHERE id IN (SELECT uid FROM active_logins LIMIT 100);", "WHERE subquery LIMIT detected; does not duplicate");
            }
        },
        # 4. LIMIT ... OFFSET ...
        {
            name  => "LIMIT with OFFSET keyword",
            sql   => "SELECT * FROM mysql.user LIMIT 50 OFFSET 10;",
            check => sub {
                my ($res) = @_;
                is($res, "SELECT * FROM mysql.user LIMIT 50 OFFSET 10;", "LIMIT ... OFFSET ... preserved intact");
            }
        },
        # 5. Comma-separated LIMIT offset, row_count
        {
            name  => "Comma-syntax LIMIT offset, count",
            sql   => "SELECT * FROM mysql.user LIMIT 100, 50;",
            check => sub {
                my ($res) = @_;
                is($res, "SELECT * FROM mysql.user LIMIT 100, 50;", "LIMIT offset, count preserved intact");
            }
        },
        # 6. Semicolon with trailing tabs and newlines
        {
            name  => "Query ending in semicolon with trailing whitespace",
            sql   => "SELECT 1;\t  \n",
            check => sub {
                my ($res) = @_;
                like($res, qr/SELECT 1 LIMIT 50000;$/, "Trailing whitespace after semicolon replaced with LIMIT 50000;");
                unlike($res, qr/;\s*LIMIT/, "No semicolon preceding LIMIT");
            }
        },
        # 7. Query without semicolon
        {
            name  => "Query without semicolon",
            sql   => "SELECT 1, 2, 3",
            check => sub {
                my ($res) = @_;
                is($res, "SELECT 1, 2, 3 LIMIT 50000", "Appends LIMIT 50000 to query without semicolon");
            }
        },
        # 8. Query without semicolon but with trailing whitespace
        {
            name  => "Query without semicolon with trailing whitespace",
            sql   => "SELECT 1, 2, 3  \n",
            check => sub {
                my ($res) = @_;
                is($res, "SELECT 1, 2, 3  \n LIMIT 50000", "Appends LIMIT 50000 with trailing whitespace preserved");
            }
        },
        # 9. Column or table name containing word 'limit'
        {
            name  => "Identifier `limit` enclosed in backticks",
            sql   => "SELECT `limit` FROM `app_limits`;",
            check => sub {
                my ($res) = @_;
                # Note: \bLIMIT\b matches `limit` because ` is non-word, preventing duplicate limit addition
                is($res, "SELECT `limit` FROM `app_limits`;", "Matches word boundary on `limit`, preserving original query without syntax error");
            }
        },
        # 10. String literal containing 'LIMIT'
        {
            name  => "String literal containing 'LIMIT'",
            sql   => "SELECT * FROM logs WHERE message = 'Rate LIMIT exceeded';",
            check => sub {
                my ($res) = @_;
                is($res, "SELECT * FROM logs WHERE message = 'Rate LIMIT exceeded';", "Word boundary matches inside literal without producing syntax error");
            }
        },
    );

    for my $c (@obscure_cases) {
        $captured_query = undef;
        main::select_csv_file($tmp_file, $c->{sql});
        $c->{check}->($captured_query);
    }
};

# =====================================================================
# SUBTEST 3: Challenge mysql_indexes PFS table query
# =====================================================================
subtest 'Challenge 3: mysql_indexes PFS table query edge cases' => sub {
    my @executed_queries;
    no warnings 'redefine';
    local *main::infoprint      = sub { };
    local *main::badprint       = sub { };
    local *main::goodprint      = sub { };
    local *main::debugprint     = sub { };
    local *main::subheaderprint = sub { };
    local *main::select_one     = sub { return 1 };
    local *main::select_user_dbs = sub { return ('testdb') };
    local *main::mysql_version_ge = sub { return 1 };

    local *main::select_array = sub {
        my ($q) = @_;
        push @executed_queries, $q;
        return ();
    };

    # 3.1: Standard multiple tables in --ignore-tables
    @executed_queries = ();
    %main::opt = ( idxstat => 1, 'ignore-tables' => 'users,orders,sessions' );
    $main::myvar{'performance_schema'} = 'ON';
    @main::dblist = ('testdb');

    main::mysql_indexes();

    my ($pfs_q) = grep { /performance_schema\.table_io_waits_summary_by_index_usage/i } @executed_queries;
    ok($pfs_q, "PFS query executed for multiple tables");
    like($pfs_q, qr/AND object_name NOT IN \('users','orders','sessions'\)/, "PFS query uses object_name NOT IN with multiple tables");
    unlike($pfs_q, qr/TABLE_NAME NOT IN/, "PFS query does NOT use TABLE_NAME");

    # 3.2: Single table in --ignore-tables
    @executed_queries = ();
    %main::opt = ( idxstat => 1, 'ignore-tables' => 'audit_log' );
    main::mysql_indexes();

    ($pfs_q) = grep { /performance_schema\.table_io_waits_summary_by_index_usage/i } @executed_queries;
    like($pfs_q, qr/AND object_name NOT IN \('audit_log'\)/, "Single table correctly formatted in object_name filter");

    # 3.3: Empty elements in list (e.g. trailing or consecutive commas: 't1,,t2')
    @executed_queries = ();
    %main::opt = ( idxstat => 1, 'ignore-tables' => 't1,,t2' );
    main::mysql_indexes();

    ($pfs_q) = grep { /performance_schema\.table_io_waits_summary_by_index_usage/i } @executed_queries;
    like($pfs_q, qr/AND object_name NOT IN \('t1','','t2'\)/, "Consecutive commas produce valid SQL empty string element");

    # 3.4: Table name with single quote: "user's_data"
    @executed_queries = ();
    %main::opt = ( idxstat => 1, 'ignore-tables' => "user's_data" );
    main::mysql_indexes();

    ($pfs_q) = grep { /performance_schema\.table_io_waits_summary_by_index_usage/i } @executed_queries;
    ok($pfs_q, "PFS query executed for table with single quote");
    like($pfs_q, qr/AND object_name NOT IN \('user's_data'\)/, "Table name with single quote is preserved directly");

    # 3.5: Value is '0'
    @executed_queries = ();
    %main::opt = ( idxstat => 1, 'ignore-tables' => '0' );
    main::mysql_indexes();

    ($pfs_q) = grep { /performance_schema\.table_io_waits_summary_by_index_usage/i } @executed_queries;
    unlike($pfs_q, qr/object_name NOT IN/, "'0' evaluates to false in Perl boolean context; no filter injected");

    # 3.6: Verify Information Schema queries continue using TABLE_NAME NOT IN
    @executed_queries = ();
    %main::opt = ( idxstat => 1, 'ignore-tables' => 'tab1,tab2' );
    main::mysql_indexes();

    my @is_queries = grep { /FROM information_schema\.statistics/i } @executed_queries;
    ok(scalar @is_queries > 0, "Information Schema statistics queries were executed");
    for my $is_q (@is_queries) {
        like($is_q, qr/TABLE_NAME NOT IN/, "Information Schema statistics query continues using TABLE_NAME NOT IN");
    }
};

# =====================================================================
# SUBTEST 4: Challenge mysql_stats query_cache_type strict warnings
# =====================================================================
subtest 'Challenge 4: mysql_stats query_cache_type under strict fatal warning handler' => sub {
    my @all_qc_states = (
        { val => 'OFF',        expected_text => 'DISABLED',     desc => "String 'OFF'" },
        { val => '0',          expected_text => 'DISABLED',     desc => "String '0'" },
        { val => 0,            expected_text => 'DISABLED',     desc => "Integer 0" },
        { val => '1',          expected_text => 'ALL REQUESTS', desc => "String '1'" },
        { val => 1,            expected_text => 'ALL REQUESTS', desc => "Integer 1" },
        { val => 'ON',         expected_text => 'ON DEMAND',    desc => "String 'ON' (fallback branch)" },
        { val => 'DEMAND',     expected_text => 'ON DEMAND',    desc => "String 'DEMAND'" },
        { val => '2',          expected_text => 'ON DEMAND',    desc => "String '2'" },
        { val => 2,            expected_text => 'ON DEMAND',    desc => "Integer 2" },
        { val => '',           expected_text => 'ON DEMAND',    desc => "Empty string ''" },
        { val => 'CUSTOM_VAL', expected_text => 'ON DEMAND',    desc => "Unknown string 'CUSTOM_VAL'" },
    );

    for my $tc (@all_qc_states) {
        my @info_captured;
        my @fatal_warnings;

        no warnings 'redefine';
        local *main::infoprint = sub { push @info_captured, $_[0] };
        local *main::badprint  = sub { };
        local *main::goodprint = sub { };
        local *main::debugprint = sub { };
        local *main::hr_bytes  = sub { return "$_[0] B" };
        local *main::hr_bytes_rnd = sub { return "$_[0] B" };
        local *main::get_pf_memory = sub { return 0 };
        local *main::get_gcache_memory = sub { return 0 };

        %main::opt = ( buffers => 1 );
        %main::myvar = (
            query_cache_type     => $tc->{val},
            query_cache_size     => 0,
            key_buffer_size      => 1024,
            read_buffer_size     => 1024,
            read_rnd_buffer_size => 1024,
            sort_buffer_size     => 1024,
            thread_stack         => 1024,
            join_buffer_size     => 1024,
            log_bin              => 'OFF',
            max_connections      => 100,
        );
        %main::mystat = (
            Uptime                => 100000,
            Questions             => 50000,
            Com_select            => 1000,
            Connections           => 50,
            Threads_connected     => 5,
            Threads_running       => 1,
            Slow_queries          => 0,
            Open_tables           => 10,
            Opened_tables         => 20,
            Table_locks_waited    => 0,
            Table_locks_immediate => 100,
        );
        %main::mycalc = ( max_tmp_table_size => 1024 );

        # Enforce strict fatal warnings on query_cache evaluation
        eval {
            use warnings FATAL => 'all';
            local $SIG{__WARN__} = sub {
                push @fatal_warnings, $_[0];
            };
            main::mysql_stats();
        };

        is($@, '', "No exception thrown under FATAL warnings for $tc->{desc}");
        my @qc_warnings = grep { /bitwise/i || /query_cache/i || /isn't numeric/i } @fatal_warnings;
        is(scalar @qc_warnings, 0, "Zero query_cache/bitwise warnings emitted for $tc->{desc}");

        my ($qc_line) = grep { /Query Cache:/ } @info_captured;
        ok($qc_line, "Query Cache output emitted for $tc->{desc}");
        like($qc_line, qr/\Q$tc->{expected_text}\E/, "Outputs '$tc->{expected_text}' for $tc->{desc}");
    }
};

done_testing();
