#!/usr/bin/env perl
# PI-006 Coverage Boost Part 3: Deep-mocked diagnostic subroutines
# Targets: system_recommendations, mysql_indexes, mysql_plugins,
#          check_query_anti_patterns, check_metadata_perf, mariadb_query_cache_info,
#          process_sysbench_metrics, select_*_db, infocmd*, is_open_port,
#          get_opened_ports, get_process_memory, historical_comparison
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
our @secrec;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;
our @dblist;

my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# --- Shared mock infrastructure ---
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
    *main::select_user_dbs = sub { return @dblist; };
}

# =====================================================================
# 1. mysql_plugins
# =====================================================================
subtest 'mysql_plugins - disabled via opt' => sub {
    reset_mocks();
    $main::opt{plugininfo} = 0;
    main::mysql_plugins();
    is(scalar @mock_output, 0, "No output when plugininfo=0");
};

subtest 'mysql_plugins - with plugins' => sub {
    reset_mocks();
    $main::opt{plugininfo} = 1;
    %mock_queries = (
        'PLUGIN_NAME.*PLUGIN_STATUS' => [
            "InnoDB\t5.7\tACTIVE\tSTORAGE ENGINE",
            "MyISAM\t1.0\tACTIVE\tSTORAGE ENGINE",
        ],
    );
    main::mysql_plugins();
    ok(grep({ /InnoDB/ } @mock_output), "InnoDB plugin listed");
    ok(grep({ /MyISAM/ } @mock_output), "MyISAM plugin listed");
};

subtest 'mysql_plugins - no plugins' => sub {
    reset_mocks();
    $main::opt{plugininfo} = 1;
    %mock_queries = ();
    main::mysql_plugins();
    ok(grep({ /No ACTIVE plugins/ } @mock_output), "Reports no active plugins");
};

# =====================================================================
# 2. check_metadata_perf
# =====================================================================
subtest 'check_metadata_perf - ON triggers badprint' => sub {
    reset_mocks();
    $main::myvar{'innodb_stats_on_metadata'} = 'ON';
    %mock_queries = ( 'SET GLOBAL' => ['OK'] );
    my $ret = main::check_metadata_perf();
    is($ret, 1, "Returns 1 when ON");
    ok(grep({ /BAD:.*Stat are updated/ } @mock_output), "Badprint issued");
    ok(grep({ /innodb_stats_on_metadata/ } @main::adjvars), "Adjustment var pushed");
};

subtest 'check_metadata_perf - OFF is good' => sub {
    reset_mocks();
    $main::myvar{'innodb_stats_on_metadata'} = 'OFF';
    my $ret = main::check_metadata_perf();
    is($ret, 0, "Returns 0 when OFF");
    ok(grep({ /GOOD:.*No stat updates/ } @mock_output), "Goodprint issued");
};

subtest 'check_metadata_perf - undefined var' => sub {
    reset_mocks();
    delete $main::myvar{'innodb_stats_on_metadata'};
    my $ret = main::check_metadata_perf();
    is($ret, 0, "Returns 0 when var undefined");
};

# =====================================================================
# 3. mariadb_query_cache_info
# =====================================================================
subtest 'mariadb_query_cache_info - not MariaDB' => sub {
    reset_mocks();
    $main::myvar{'version'} = '8.0.35';
    $main::myvar{'version_comment'} = 'MySQL Community Server';
    main::mariadb_query_cache_info();
    ok(grep({ /Not a MariaDB/ } @mock_output), "Skips for MySQL");
};

subtest 'mariadb_query_cache_info - MariaDB no plugin' => sub {
    reset_mocks();
    $main::myvar{'version'} = '11.4.0-MariaDB';
    $main::myvar{'version_comment'} = 'MariaDB Server';
    %mock_queries = ( 'QUERY_CACHE_INFO' => ['DISABLED'] );
    main::mariadb_query_cache_info();
    ok(grep({ /not active or not installed/ } @mock_output), "Reports plugin not active");
};

subtest 'mariadb_query_cache_info - MariaDB with active plugin' => sub {
    reset_mocks();
    $main::myvar{'version'} = '11.4.0-MariaDB';
    $main::myvar{'version_comment'} = 'MariaDB Server';
    {
        no warnings 'redefine';
        local *main::select_one = sub {
            my ($query) = @_;
            return 'ACTIVE' if $query =~ /QUERY_CACHE_INFO/;
            return '';
        };
        %mock_queries = (
            'query_cache_info' => ['mydb;;SELECT * FROM t1;;5;;1024'],
        );
        main::mariadb_query_cache_info();
    }
    ok(grep({ /GOOD:.*QUERY_CACHE_INFO plugin is installed/ } @mock_output), "Plugin active reported");
};

# =====================================================================
# 4. check_query_anti_patterns
# =====================================================================
subtest 'check_query_anti_patterns - old version skips' => sub {
    reset_mocks();
    $main::myvar{'version'} = '5.5.0';
    {
        no warnings 'redefine';
        local *main::mysql_version_ge = sub { return 0; };
        main::check_query_anti_patterns();
    }
    ok(grep({ /Skipped.*5\.6/ } @mock_output), "Skips for version < 5.6");
};

subtest 'check_query_anti_patterns - PFS disabled' => sub {
    reset_mocks();
    {
        no warnings 'redefine';
        local *main::mysql_version_ge = sub { return 1; };
        %mock_queries = ( 'performance_schema' => [undef] );
        # select_one for SHOW VARIABLES LIKE 'performance_schema' returns non-ON
        local *main::select_one = sub { return ''; };
        main::check_query_anti_patterns();
    }
    ok(grep({ /Performance Schema is disabled/ } @mock_output), "Skips when PFS disabled");
};

subtest 'check_query_anti_patterns - full scans detected' => sub {
    reset_mocks();
    {
        no warnings 'redefine';
        local *main::mysql_version_ge = sub { return 1; };
        local *main::select_one = sub { return 'ON'; };
        %mock_queries = (
            'sum_no_index_used' => [
                "SELECT * FROM users WHERE name LIKE '%test%'\t1000\t500\t0",
                "SELECT * FROM orders\t2000\t1500\t0",
            ],
            'sum_created_tmp_disk_tables' => [],
        );
        main::check_query_anti_patterns();
    }
    ok(grep({ /BAD:.*Found 2 query digests/ } @mock_output), "Detects full scan queries");
    ok(grep({ /Optimize queries/ } @main::generalrec), "Recommendation pushed");
};

subtest 'check_query_anti_patterns - no issues' => sub {
    reset_mocks();
    {
        no warnings 'redefine';
        local *main::mysql_version_ge = sub { return 1; };
        local *main::select_one = sub { return 'ON'; };
        %mock_queries = (
            'sum_no_index_used' => [],
            'sum_created_tmp_disk_tables' => [],
        );
        main::check_query_anti_patterns();
    }
    ok(grep({ /GOOD:.*No major full table scan/ } @mock_output), "Reports clean scan status");
};

# =====================================================================
# 5. mysql_indexes
# =====================================================================
subtest 'mysql_indexes - disabled via opt' => sub {
    reset_mocks();
    $main::opt{idxstat} = 0;
    main::mysql_indexes();
    is(scalar @mock_output, 0, "No output when idxstat=0");
};

subtest 'mysql_indexes - old version skips' => sub {
    reset_mocks();
    $main::opt{idxstat} = 1;
    {
        no warnings 'redefine';
        local *main::mysql_version_ge = sub { return 0; };
        main::mysql_indexes();
    }
    ok(grep({ /Index metrics.*missing/ } @mock_output), "Skips for old version");
};

subtest 'mysql_indexes - with selectivity data' => sub {
    reset_mocks();
    $main::opt{idxstat} = 1;
    $main::opt{'ignore-tables'} = '';
    $main::myvar{'performance_schema'} = 'OFF';
    @main::dblist = ('testdb');
    {
        no warnings 'redefine';
        local *main::mysql_version_ge = sub { return 1; };
        %mock_queries = (
            'ORDER BY sel' => [
                "testdb.users idx_email(email) 1 2 500 10000 BTREE 5.00",
            ],
            'GROUP BY table_name' => [
                "users.idx_email email 500 NULL BTREE",
            ],
            'count.*BASE TABLE.*TABLE_SCHEMA' => ['3'],
        );
        main::mysql_indexes();
    }
    ok(grep({ /Worst selectivity/ } @mock_output), "Shows selectivity header");
    ok(grep({ /idx_email/ } @mock_output), "Index name appears in output");
};

# =====================================================================
# 6. system_recommendations - skip paths
# =====================================================================
subtest 'system_recommendations - remote skip' => sub {
    reset_mocks();
    {
        no warnings 'redefine';
        local *main::is_remote = sub { return 1; };
        $main::is_cloud = 0;
        main::system_recommendations();
    }
    ok(grep({ /Skipping local system checks/ } @mock_output), "Skips for remote host");
};

subtest 'system_recommendations - remote host recap' => sub {
    reset_mocks();
    $main::is_cloud = 1;
    $main::cloud_type = 'AWS RDS';
    $main::myvar{'hostname'} = 'my-rds-db';
    $main::myvar{'version_compile_os'} = 'Linux';
    $main::myvar{'version_compile_machine'} = 'x86_64';
    $main::physical_memory = 8589934592; # 8 GB
    $main::mystat{'Uptime'} = 86400; # 1 day
    {
        no warnings 'redefine';
        local *main::is_remote = sub { return 1; };
        main::system_recommendations();
    }
    ok(grep({ /Skipping local system checks/ } @mock_output), "Skips local checks message shown");
    ok(grep({ /Machine type.*Cloud instance \(AWS RDS\)/ } @mock_output), "Machine type shown");
    ok(grep({ /Host Name.*my-rds-db/ } @mock_output), "Host name shown");
    ok(grep({ /Operating System Type.*Linux/ } @mock_output), "Operating system shown");
    ok(grep({ /CPU Architecture.*x86_64/ } @mock_output), "CPU Architecture shown");
    ok(grep({ /Physical Memory \(RAM\).*8.0G/ } @mock_output), "RAM shown");
    ok(grep({ /Database Uptime.*1d 0h 0m/ } @mock_output), "Database Uptime shown");
    ok(grep({ /There is at least 1.5 Gb/ } @mock_output), "Physical RAM check run");
};

subtest 'system_recommendations - sysstat disabled' => sub {
    reset_mocks();
    $main::opt{sysstat} = 0;
    {
        no warnings 'redefine';
        local *main::is_remote = sub { return 0; };
        $main::is_cloud = 0;
        main::system_recommendations();
    }
    is(scalar @mock_output, 0, "No output when sysstat=0");
};

subtest 'system_recommendations - non-Linux skip' => sub {
    reset_mocks();
    $main::opt{sysstat} = 1;
    {
        no warnings 'redefine';
        local *main::is_remote = sub { return 0; };
        $main::is_cloud = 0;
        local *main::execute_system_command = sub { return 'FreeBSD'; };
        $main::is_win = 0;
        main::system_recommendations();
    }
    ok(grep({ /Skipped due to non Linux/ } @mock_output), "Skips for non-Linux");
};

# =====================================================================
# 7. process_sysbench_metrics
# =====================================================================
subtest 'process_sysbench_metrics - no file skips' => sub {
    reset_mocks();
    $main::opt{'sysbench-file'} = '';
    main::process_sysbench_metrics();
    is(scalar @mock_output, 0, "No output without sysbench file");
};

subtest 'process_sysbench_metrics - file not found' => sub {
    reset_mocks();
    $main::opt{'sysbench-file'} = '/nonexistent/sysbench.log';
    main::process_sysbench_metrics();
    ok(grep({ /BAD:.*not found/ } @mock_output), "Reports file not found");
};

subtest 'process_sysbench_metrics - parses valid output' => sub {
    reset_mocks();
    my $tmpdir = tempdir(CLEANUP => 1);
    my $path = "$tmpdir/sysbench.log";
    main::string2file($path, <<'EOF');
SQL statistics:
    queries:  50000  (2500.50 per sec.)
    transactions:  25000  (1250.25 per sec.)
Latency (ms):
    avg:  3.45
    95th percentile:  7.89
    max:  125.67
EOF
    $main::opt{'sysbench-file'} = $path;
    main::process_sysbench_metrics();
    ok(grep({ /GOOD:.*TPS: 1250\.25/ } @mock_output), "TPS parsed");
    ok(grep({ /GOOD:.*QPS: 2500\.50/ } @mock_output), "QPS parsed");
    is($main::result{'Sysbench'}{'TPS'}, '1250.25', "TPS stored in result hash");
    is($main::result{'Sysbench'}{'QPS'}, '2500.50', "QPS stored in result hash");
};

# =====================================================================
# 8. select_*_db functions (thin wrappers over select_array)
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
# 9. infocmd / infocmd_tab / infocmd_one
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
# 10. get_opened_ports / is_open_port (with mocked execute_system_command)
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
# 11. get_process_memory
# =====================================================================
subtest 'get_process_memory returns 0 on Windows' => sub {
    local $main::is_win = 1;
    my $mem = main::get_process_memory($$);
    is($mem, 0, "Returns 0 on Windows");
};

# =====================================================================
# 12. historical_comparison - skip paths
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
# 13. select_one_g / select_str_g (with mocked execute_system_command)
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
# 14. select_csv_file (from get_state_file_path context)
# =====================================================================
subtest 'select_csv_file smoke' => sub {
    reset_mocks();
    # select_csv_file internally uses $basic_password_files or loads CSV
    # Just verify it exists and is callable
    ok(defined &main::select_csv_file, "select_csv_file is defined");
};

done_testing();
