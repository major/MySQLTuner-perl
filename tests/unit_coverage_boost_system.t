#!/usr/bin/env perl
# Targets: select_*_db, infocmd*, get_opened_ports, get_process_memory, historical_comparison, select_one_g, select_csv_file
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempfile tempdir);
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
our $is_win;
our $mysqlcmd;
our $mysqllogin;
our $devnull;

my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# Shared mock infrastructure
my @mock_output;
my %mock_queries;

sub reset_mocks {
    @mock_output = ();
    @main::generalrec = ();
    @main::adjvars = ();
    @main::modeling = ();
    @main::sysrec = ();
    @main::secrec = ();
    %main::result = ();
    %mock_queries = ();
}

{
    no warnings 'redefine';
    *main::infoprint       = sub { push @mock_output, "INFO: $_[0]" };
    *main::badprint        = sub { push @mock_output, "BAD: $_[0]" };
    *main::goodprint       = sub { push @mock_output, "GOOD: $_[0]" };
    *main::debugprint      = sub { };
    *main::subheaderprint  = sub { push @mock_output, "HEADER: $_[0]" };
    *main::prettyprint     = sub { push @mock_output, "PRETTY: $_[0]" };
    *main::select_array    = sub {
        my ($query) = @_;
        foreach my $pattern (keys %mock_queries) {
            if ($query =~ /$pattern/si) {
                return @{$mock_queries{$pattern}};
            }
        }
        return ();
    };
    *main::select_one      = sub {
        my ($query) = @_;
        foreach my $pattern (keys %mock_queries) {
            if ($query =~ /$pattern/si) {
                my @res = @{$mock_queries{$pattern}};
                return $res[0] // '';
            }
        }
        return '';
    };
}

# =====================================================================
# 1. select_*_db functions
# =====================================================================
subtest 'select_tables_db delegates to select_array' => sub {
    reset_mocks();
    %mock_queries = ( "TABLE_SCHEMA='mydb'" => ['users', 'orders'] );
    my @tables = main::select_tables_db('mydb');
    is_deeply(\@tables, ['users', 'orders'], "select_tables_db returns tables");
};

subtest 'select_indexes_db delegates to select_array' => sub {
    reset_mocks();
    %mock_queries = ( "TABLE_SCHEMA='mydb'" => ['idx_email', 'PRIMARY'] );
    my @indexes = main::select_indexes_db('mydb');
    is_deeply(\@indexes, ['idx_email', 'PRIMARY'], "select_indexes_db returns indexes");
};

subtest 'select_views_db delegates to select_array' => sub {
    reset_mocks();
    %mock_queries = ( "TABLE_SCHEMA='mydb'" => ['v_active_users'] );
    my @views = main::select_views_db('mydb');
    is_deeply(\@views, ['v_active_users'], "select_views_db returns views");
};

subtest 'select_triggers_db delegates to select_array' => sub {
    reset_mocks();
    %mock_queries = ( "TRIGGER_SCHEMA='mydb'" => ['trg_audit'] );
    my @triggers = main::select_triggers_db('mydb');
    is_deeply(\@triggers, ['trg_audit'], "select_triggers_db returns triggers");
};

subtest 'select_routines_db delegates to select_array' => sub {
    reset_mocks();
    %mock_queries = ( "ROUTINE_SCHEMA='mydb'" => ['sp_cleanup'] );
    my @routines = main::select_routines_db('mydb');
    is_deeply(\@routines, ['sp_cleanup'], "select_routines_db returns routines");
};

subtest 'select_table_indexes_db delegates to select_array' => sub {
    reset_mocks();
    %mock_queries = ( "TABLE_SCHEMA='mydb'.*TABLE_NAME='users'" => ['PRIMARY', 'idx_email'] );
    my @indexes = main::select_table_indexes_db('mydb', 'users');
    is_deeply(\@indexes, ['PRIMARY', 'idx_email'], "select_table_indexes_db returns indexes");
};

# =====================================================================
# 2. infocmd / infocmd_tab / infocmd_one
# =====================================================================
subtest 'infocmd executes and prints output' => sub {
    reset_mocks();
    {
        no warnings 'redefine';
        local *main::execute_system_command = sub { return ("result_line1\n", "result_line2\n"); };
        main::infocmd("echo test");
    }
    ok(grep({ /result_line1/ } @mock_output), "infocmd prints command output");
};

subtest 'infocmd_tab prints tabbed output' => sub {
    reset_mocks();
    {
        no warnings 'redefine';
        local *main::execute_system_command = sub { return ("tabbed_line\n"); };
        main::infocmd_tab("echo test");
    }
    ok(grep({ /\ttabbed_line/ } @mock_output), "infocmd_tab adds tab prefix");
};

subtest 'infocmd_one returns joined string' => sub {
    reset_mocks();
    my $result;
    {
        no warnings 'redefine';
        local *main::execute_system_command = sub { return ("val1\n", "val2\n"); };
        $result = main::infocmd_one("echo test");
    }
    like($result, qr/val1.*val2/, "infocmd_one joins output");
};

# =====================================================================
# 3. get_opened_ports / is_open_port
# =====================================================================
subtest 'get_opened_ports parses netstat' => sub {
    reset_mocks();
    $main::is_win = 0;
    {
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            return (
                "tcp  0  0  0.0.0.0:22  0.0.0.0:*  LISTEN\n",
                "tcp  0  0  0.0.0.0:3306  0.0.0.0:*  LISTEN\n",
                "tcp  0  0  0.0.0.0:80  0.0.0.0:*  LISTEN\n",
            );
        };
        my @ports = main::get_opened_ports();
        ok(grep({ $_ == 22 } @ports), "Port 22 detected");
        ok(grep({ $_ == 3306 } @ports), "Port 3306 detected");
        ok(grep({ $_ == 80 } @ports), "Port 80 detected");
    }
};

subtest 'is_open_port returns 1 for open port' => sub {
    reset_mocks();
    $main::is_win = 0;
    {
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            return (
                "tcp  0  0  0.0.0.0:3306  0.0.0.0:*  LISTEN\n",
                "tcp  0  0  0.0.0.0:22  0.0.0.0:*  LISTEN\n",
            );
        };
        is(main::is_open_port(3306), 1, "3306 is open");
        is(main::is_open_port(8080), 0, "8080 is not open");
    }
};

# =====================================================================
# 4. get_process_memory
# =====================================================================
subtest 'get_process_memory returns 0 on Windows' => sub {
    local $main::is_win = 1;
    my $mem = main::get_process_memory($$);
    is($mem, 0, "Returns 0 on Windows");
};

# =====================================================================
# 5. historical_comparison
# =====================================================================
subtest 'historical_comparison - no file skips' => sub {
    reset_mocks();
    $main::opt{'compare-file'} = '';
    main::historical_comparison();
    is(scalar @mock_output, 0, "No output without compare-file");
};

subtest 'historical_comparison - file not found' => sub {
    reset_mocks();
    $main::opt{'compare-file'} = '/nonexistent/old_results.json';
    main::historical_comparison();
    ok(grep({ /BAD:.*not found/ } @mock_output), "Reports file not found");
};

# =====================================================================
# 6. select_one_g / select_str_g
# =====================================================================
subtest 'select_one_g extracts matching line' => sub {
    reset_mocks();
    {
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            return (
                "   Variable_name: Threads_running\n",
                "           Value: 5\n",
            );
        };
        $main::mysqlcmd = 'mysql';
        $main::mysqllogin = '';
        $main::devnull = '/dev/null';
        my $result = main::select_one_g('Value', 'SHOW STATUS LIKE "Threads_running"');
        like($result, qr/Value.*5/, "Extracts matching line");
    }
};

subtest 'select_str_g extracts value after colon' => sub {
    reset_mocks();
    {
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            return (
                "   Variable_name: slow_query_log\n",
                "           Value: ON\n",
            );
        };
        $main::mysqlcmd = 'mysql';
        $main::mysqllogin = '';
        $main::devnull = '/dev/null';
        my $result = main::select_str_g('Value', 'SHOW VARIABLES LIKE "slow_query_log"');
        like($result, qr/ON/, "Extracts value after colon");
    }
};

# =====================================================================
# 7. select_csv_file
# =====================================================================
subtest 'select_csv_file smoke' => sub {
    reset_mocks();
    ok(defined &main::select_csv_file, "select_csv_file is defined");
};

done_testing();
