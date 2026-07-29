#!/usr/bin/env perl
# Targets: mysql_plugins, check_metadata_perf, mariadb_query_cache_info, check_query_anti_patterns
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

done_testing();
