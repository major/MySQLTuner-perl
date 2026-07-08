#!/usr/bin/env perl
# Targets: mysql_indexes, system_recommendations, process_sysbench_metrics
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
our $is_cloud;
our $cloud_type;
our $physical_memory;
our $is_win;

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
    *main::select_user_dbs = sub { return @dblist; };
}

# =====================================================================
# 1. mysql_indexes
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
# 2. system_recommendations
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
# 3. process_sysbench_metrics
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

done_testing();
