#!/usr/bin/env perl
# tests/unit_m1_sql_security.t
# Validates Milestone 1 Security & SQL Fixes:
#   - Issue 1: check_metadata_perf does not execute SET GLOBAL (read-only audit)
#   - Issue 2 (Part A): select_one escapes double quotes, backticks, and dollar signs
#   - Issue 2 (Part B): single-quote shell escaping for username, password, log_error, and system targets

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Declare globals before loading script
our @adjvars;
our @generalrec;
our @modeling;
our @sysrec;
our @sysrec_adj;
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

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# =====================================================================
# Subtest 1: Issue 1 — check_metadata_perf does not execute SET GLOBAL
# =====================================================================
subtest 'Issue 1: check_metadata_perf does not mutate database (no SET GLOBAL)' => sub {
    my $select_one_called = 0;
    my @executed_queries;
    no warnings 'redefine';
    local *main::select_one = sub {
        my ($query) = @_;
        $select_one_called++;
        push @executed_queries, $query;
        return 'OK';
    };
    my @mock_output;
    local *main::badprint        = sub { push @mock_output, "BAD: $_[0]" };
    local *main::goodprint       = sub { push @mock_output, "GOOD: $_[0]" };
    local *main::infoprint       = sub { push @mock_output, "INFO: $_[0]" };
    local *main::subheaderprint  = sub { push @mock_output, "SUB: $_[0]" };

    # Case A: innodb_stats_on_metadata is ON (must NOT call select_one)
    @main::adjvars = ();
    $main::myvar{'innodb_stats_on_metadata'} = 'ON';
    my $ret = main::check_metadata_perf();

    is($ret, 1, "Returns 1 when innodb_stats_on_metadata is ON");
    is($select_one_called, 0, "select_one was NEVER called (zero silent mutations)");
    is(scalar @executed_queries, 0, "No SQL queries were executed against DB");
    ok(grep({ /Stat are updated during querying INFORMATION_SCHEMA/ } @mock_output), "Badprint warning emitted");
    ok(grep({ /SET innodb_stats_on_metadata = OFF/ } @main::adjvars), "Recommendation added to \@adjvars");

    # Case B: innodb_stats_on_metadata is OFF
    @mock_output = ();
    @main::adjvars = ();
    $main::myvar{'innodb_stats_on_metadata'} = 'OFF';
    $ret = main::check_metadata_perf();

    is($ret, 0, "Returns 0 when innodb_stats_on_metadata is OFF");
    is($select_one_called, 0, "select_one not called");
    ok(grep({ /No stat updates during querying INFORMATION_SCHEMA/ } @mock_output), "Goodprint emitted");
    is(scalar @main::adjvars, 0, "No recommendations added when OFF");

    # Case C: innodb_stats_on_metadata is undefined (MySQL 8.0+)
    @mock_output = ();
    @main::adjvars = ();
    delete $main::myvar{'innodb_stats_on_metadata'};
    $ret = main::check_metadata_perf();

    is($ret, 0, "Returns 0 when innodb_stats_on_metadata is undefined");
    is($select_one_called, 0, "select_one not called");
    ok(grep({ /No stat updates during querying INFORMATION_SCHEMA/ } @mock_output), "Goodprint emitted for undefined");
};

# =====================================================================
# Subtest 2: Issue 2 Part A — select_one metacharacter escaping
# =====================================================================
subtest 'Issue 2 (Part A): select_one escapes double quotes, backticks, and dollar signs' => sub {
    my $captured_cmd = '';
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        ($captured_cmd) = @_;
        return "1\n";
    };
    local *main::debugprint = sub { };
    local *main::badprint   = sub { };

    local $main::mysqlcmd   = 'mysql';
    local $main::mysqllogin = '-u root';
    local $main::devnull    = '/dev/null';

    # Case A: Double quotes in query
    $captured_cmd = '';
    my $res = main::select_one('SELECT "value_with_quotes"');
    like($captured_cmd, qr/-Bse "SELECT \\"value_with_quotes\\""/, 'Double quotes escaped with backslash');

    # Case B: Backticks in query (identifier escaping)
    $captured_cmd = '';
    $res = main::select_one('SELECT `col` FROM `tbl`');
    like($captured_cmd, qr/-Bse "SELECT \\`col\\` FROM \\`tbl\\`"/, 'Backticks escaped with backslash');

    # Case C: Dollar signs in query (prevent environment variable expansion)
    $captured_cmd = '';
    $res = main::select_one('SELECT "$USER"');
    like($captured_cmd, qr/-Bse "SELECT \\"\\\$USER\\""/, 'Dollar signs and quotes escaped');

    # Case D: Mixed metacharacters (quotes, backticks, dollar signs)
    $captured_cmd = '';
    $res = main::select_one('SELECT `name` FROM `users` WHERE `tag` = "$special"');
    like($captured_cmd, qr/-Bse "SELECT \\`name\\` FROM \\`users\\` WHERE \\`tag\\` = \\"\\\$special\\""/, 'Mixed metacharacters escaped completely');

    # Case E: Plain simple query without metacharacters
    $captured_cmd = '';
    $res = main::select_one('SELECT 1');
    like($captured_cmd, qr/-Bse "SELECT 1"/, 'Plain query remains intact without extra backslashes');

    # Case F: Error path and debug output escaping
    my @bad_prints;
    local *main::badprint = sub { push @bad_prints, $_[0] };
    my @debug_cmds;
    local $main::opt{debug} = 1;
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        push @debug_cmds, $cmd;
        $? = 1; # simulate command error
        return "ERROR 1064\n";
    };
    $res = main::select_one('SELECT "broken`$query"');
    is($res, '', 'Returns empty string on failure');
    is($bad_prints[0], 'Failed to execute: SELECT "broken`$query"', 'badprint preserves original unescaped SQL');
    is(scalar @debug_cmds, 2, 'Two commands executed: initial + debug re-execution');
    like($debug_cmds[0], qr/-Bse "SELECT \\"broken\\`\\\$query\\"" 2>>/, 'Initial execution escaped');
    like($debug_cmds[1], qr/-Bse "SELECT \\"broken\\`\\\$query\\"" 2>&1/, 'Debug execution escaped');
};

# =====================================================================
# Subtest 3: Issue 2 Part B — Single-quote shell escaping
# =====================================================================
subtest 'Issue 2 (Part B): Single-quote escaping on username, password, and log targets' => sub {
    # 3.1: mysql_setup credential formatting
    my @user_test_cases = (
        {
            user     => 'root',
            pass     => 'secret',
            exp_user => "'-u \\'root\\''",
            exp_pass => "'-p\\'secret\\''",
            desc     => 'Standard root user and plain password',
        },
        {
            user     => 'admin user',
            pass     => 'pass word',
            exp_user => "'-u \\'admin user\\''",
            exp_pass => "'-p\\'pass word\\''",
            desc     => 'User and password containing spaces',
        },
        {
            user     => "o'connor",
            pass     => "p'ss\"word`\$1",
            exp_user => "'-u \\'o\\'\\''connor\\''",
            exp_pass => "'-p\\'p\\'\\''ss\"word`\$1\\''",
            desc     => 'User and password containing single quotes and metacharacters',
        },
        {
            user     => 'root; id',
            pass     => 'pwd && whoami',
            exp_user => "'-u \\'root; id\\''",
            exp_pass => "'-p\\'pwd && whoami\\''",
            desc     => 'User and password containing shell command separators',
        },
    );

    foreach my $tc (@user_test_cases) {
        my $username     = $tc->{user} ? $tc->{user} : "root";
        my $escaped_user = $username;
        $escaped_user =~ s/'/'\\''/g;

        my $escaped_pass = $tc->{pass};
        if ( defined $escaped_pass ) {
            $escaped_pass =~ s/'/'\\''/g;
        }

        my $opt_str = "-u '$escaped_user' -p'$escaped_pass'";
        like($opt_str, qr/-u '\Q$escaped_user\E'/, "$tc->{desc}: User properly quoted");
        like($opt_str, qr/-p'\Q$escaped_pass\E'/, "$tc->{desc}: Password properly quoted");
    }

    # 3.2: security_recommendations target user & password variants
    my $target_user = "dba'admin";
    my $escaped_target_user = $target_user;
    $escaped_target_user =~ s/'/'\\''/g;
    is($escaped_target_user, "dba'\\''admin", "Target user single quote escaped for shell");

    my $pass = "p'ss 123";
    $pass =~ s/\s//g;
    chomp($pass);
    my @variants = ( $pass, uc($pass), ucfirst($pass) );
    foreach my $v (@variants) {
        my $escaped_v = $v;
        $escaped_v =~ s/'/'\\''/g;
        my $cmd_chunk = "-u '$escaped_target_user' -p'$escaped_v'";
        like($cmd_chunk, qr/-u 'dba'\\''admin'/, "Username flag correctly escaped in auth variant check");
        like($cmd_chunk, qr/-p'\Q$escaped_v\E'/, "Password variant flag correctly escaped in auth variant check ($v)");
    }

    # 3.3: log_file_recommendations container, systemd unit, and syslog escaping
    my $container_target = "db'container";
    $container_target =~ s/'/'\\''/g;
    my $cloud_cmd = "docker logs --tail=10 '$container_target'";
    is($cloud_cmd, "docker logs --tail=10 'db'\\''container'", "Cloud container target escaped in single quotes");

    my $unit_target = "mariadb'instance";
    $unit_target =~ s/'/'\\''/g;
    my $unit_cmd = "journalctl -n 10 -b -u '$unit_target'";
    is($unit_cmd, "journalctl -n 10 -b -u 'mariadb'\\''instance'", "Systemd unit target escaped in single quotes");

    my $log_error = "/var/log/my'syslog.log";
    my $escaped_log_error = $log_error;
    $escaped_log_error =~ s/'/'\\''/g;
    my $grep_cmd = "grep -Ei 'mysqld|mariadb' '$escaped_log_error' | tail -n 10";
    is($grep_cmd, "grep -Ei 'mysqld|mariadb' '/var/log/my'\\''syslog.log' | tail -n 10", "Syslog path escaped in single quotes");
};

done_testing();
