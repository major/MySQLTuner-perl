use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Suppress warnings from mysqltuner.pl initialization
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;
my $helper = abs_path(File::Spec->catfile($script_dir, 'MySQLTuner', 'TestHelper.pm'));
require $helper;

our %opt;

subtest 'Statistical Statement Analysis - Modern MySQL 8.0.31+ with all columns' => sub {
    no warnings 'redefine';
    my @selected_queries;

    local *main::select_array = sub {
        my $query = shift;
        if ($query =~ /SHOW DATABASES LIKE 'sys'/i) {
            return ('sys');
        }
        if ($query =~ /SHOW TABLES FROM sys LIKE 'x\\\$statement_analysis'/i) {
            return ('x$statement_analysis');
        }
        if ($query =~ /FROM information_schema\.COLUMNS/i) {
            return (
                'db', 'digest', 'query', 'full_scan', 'first_seen', 'last_seen',
                'exec_count', 'exec_secondary_count', 'err_count', 'warn_count',
                'total_latency', 'max_latency', 'avg_latency', 'lock_latency', 'cpu_latency',
                'rows_sent', 'rows_sent_avg', 'rows_examined', 'rows_examined_avg',
                'rows_affected', 'rows_affected_avg', 'tmp_tables', 'tmp_disk_tables',
                'rows_sorted', 'sort_merge_passes', 'max_controlled_memory', 'max_total_memory'
            );
        }
        return ();
    };

    local *main::select_csv_file = sub {
        my ($file, $query) = @_;
        push @selected_queries, { file => $file, query => $query };
    };
    local *main::infoprint = sub {};

    main::dump_sys_statement_analysis_statistical('/tmp/dummy_dump');

    is(scalar @selected_queries, 2, "Generated exactly two CSV exports");

    my ($unfilt) = grep { $_->{file} =~ /sys_statement_analysis_statistical\.csv$/ } @selected_queries;
    ok($unfilt, "Generates unfiltered statistical export");
    like($unfilt->{query}, qr/x\.exec_secondary_count AS exec_secondary_count_raw/, "Includes real exec_secondary_count");
    like($unfilt->{query}, qr/x\.cpu_latency AS cpu_latency_ps_raw/, "Includes real cpu_latency");
    like($unfilt->{query}, qr/x\.max_controlled_memory AS max_controlled_memory_bytes_raw/, "Includes real max_controlled_memory");
    like($unfilt->{query}, qr/x\.max_total_memory AS max_total_memory_bytes_raw/, "Includes real max_total_memory");
    like($unfilt->{query}, qr/ROUND\(LOG10\(x\.exec_count\), 4\)/, "Includes LOG10 calculations");
    like($unfilt->{query}, qr/sys\.format_statement\(x\.query\)/, "Includes sys.format_statement");
    like($unfilt->{query}, qr/sys\.format_time\(x\.total_latency\)/, "Includes sys.format_time");
    like($unfilt->{query}, qr/sys\.format_bytes\(x\.max_total_memory\)/, "Includes sys.format_bytes");
    like($unfilt->{query}, qr/ORDER BY x\.total_latency DESC/, "Orders by total latency descending");
    unlike($unfilt->{query}, qr/WHERE/i, "Unfiltered export has no WHERE clause");

    my ($filt) = grep { $_->{file} =~ /sys_statement_analysis_statistical_filtered\.csv$/ } @selected_queries;
    ok($filt, "Generates filtered statistical export");
    like($filt->{query}, qr/x\.db IS NULL OR x\.db NOT IN \('mysql', 'information_schema', 'performance_schema', 'sys'\)/, "Filters out system databases");
    like($filt->{query}, qr/x\.query NOT LIKE 'COMMIT%'/, "Filters out COMMIT statements");
    like($filt->{query}, qr/x\.query NOT LIKE 'ROLLBACK%'/, "Filters out ROLLBACK statements");
    like($filt->{query}, qr/x\.query NOT LIKE 'SET %'/, "Filters out SET statements");
};

subtest 'Statistical Statement Analysis - Legacy MySQL 8.0.25 (missing cpu_latency & memory columns)' => sub {
    no warnings 'redefine';
    my @selected_queries;

    local *main::select_array = sub {
        my $query = shift;
        if ($query =~ /SHOW DATABASES LIKE 'sys'/i) {
            return ('sys');
        }
        if ($query =~ /SHOW TABLES FROM sys LIKE 'x\\\$statement_analysis'/i) {
            return ('x$statement_analysis');
        }
        if ($query =~ /FROM information_schema\.COLUMNS/i) {
            # Omit cpu_latency, max_controlled_memory, max_total_memory (simulate MySQL 8.0.25)
            return (
                'db', 'digest', 'query', 'full_scan', 'first_seen', 'last_seen',
                'exec_count', 'exec_secondary_count', 'err_count', 'warn_count',
                'total_latency', 'max_latency', 'avg_latency', 'lock_latency',
                'rows_sent', 'rows_sent_avg', 'rows_examined', 'rows_examined_avg',
                'rows_affected', 'rows_affected_avg', 'tmp_tables', 'tmp_disk_tables',
                'rows_sorted', 'sort_merge_passes'
            );
        }
        return ();
    };

    local *main::select_csv_file = sub {
        my ($file, $query) = @_;
        push @selected_queries, { file => $file, query => $query };
    };
    local *main::infoprint = sub {};

    main::dump_sys_statement_analysis_statistical('/tmp/dummy_dump');

    is(scalar @selected_queries, 2, "Generated exactly two CSV exports");

    my ($unfilt) = grep { $_->{file} =~ /sys_statement_analysis_statistical\.csv$/ } @selected_queries;
    ok($unfilt, "Generates unfiltered statistical export");
    like($unfilt->{query}, qr/NULL AS cpu_latency_ps_raw/, "Replaces missing cpu_latency with NULL");
    like($unfilt->{query}, qr/NULL AS log10_cpu_latency_ps/, "Replaces missing cpu_latency LOG10 with NULL");
    like($unfilt->{query}, qr/NULL AS max_controlled_memory_bytes_raw/, "Replaces missing max_controlled_memory with NULL");
    like($unfilt->{query}, qr/NULL AS max_total_memory_bytes_raw/, "Replaces missing max_total_memory with NULL");
    unlike($unfilt->{query}, qr/x\.cpu_latency/, "Does not reference non-existent x.cpu_latency");
    unlike($unfilt->{query}, qr/x\.max_controlled_memory/, "Does not reference non-existent x.max_controlled_memory");
};

subtest 'Statistical Statement Analysis - Graceful skip when sys schema or view absent' => sub {
    no warnings 'redefine';
    my @selected_queries;

    local *main::select_array = sub {
        return (); # No sys database or tables
    };

    local *main::select_csv_file = sub {
        my ($file, $query) = @_;
        push @selected_queries, { file => $file, query => $query };
    };
    local *main::infoprint = sub {};

    main::dump_sys_statement_analysis_statistical('/tmp/dummy_dump');
    is(scalar @selected_queries, 0, "Gracefully skips when sys database is absent");
};

subtest 'Statistical Statement Analysis - Integration in dump_csv_files()' => sub {
    no warnings 'redefine';
    my @selected_queries;

    local *main::select_array = sub {
        my $query = shift;
        if ($query =~ /use sys;show tables;/i) {
            return ('statement_analysis');
        }
        if ($query =~ /SHOW DATABASES LIKE 'sys'/i) {
            return ('sys');
        }
        if ($query =~ /SHOW TABLES FROM sys LIKE 'x\\\$statement_analysis'/i) {
            return ('x$statement_analysis');
        }
        if ($query =~ /FROM information_schema\.COLUMNS/i) {
            return ('db', 'query', 'total_latency');
        }
        return ();
    };

    local *main::select_csv_file = sub {
        my ($file, $query) = @_;
        push @selected_queries, { file => $file, query => $query };
    };
    local *main::infoprint = sub {};
    local *main::write_manifest_files = sub {};

    local %main::opt = ( dumpdir => '/tmp/dummy_dump' );

    main::dump_csv_files();

    my ($stat_unfilt) = grep { $_->{file} =~ /sys_statement_analysis_statistical\.csv$/ } @selected_queries;
    ok($stat_unfilt, "dump_csv_files invokes dump_sys_statement_analysis_statistical for unfiltered CSV");

    my ($stat_filt) = grep { $_->{file} =~ /sys_statement_analysis_statistical_filtered\.csv$/ } @selected_queries;
    ok($stat_filt, "dump_csv_files invokes dump_sys_statement_analysis_statistical for filtered CSV");
};

done_testing();
