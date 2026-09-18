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

subtest 'dump_csv_files - Sys views SQL query construction without escaping defects' => sub {
    no warnings 'redefine';
    my @selected_queries;

    local *main::select_array = sub {
        my $query = shift;
        if ($query =~ /use sys;show tables;/i) {
            return ('x$statement_analysis', 'version');
        }
        return ();
    };

    local *main::select_csv_file = sub {
        my ($file, $query) = @_;
        push @selected_queries, { file => $file, query => $query };
    };
    local *main::infoprint = sub {};
    local *main::dump_sys_statement_analysis_statistical = sub {};
    local *main::write_manifest_files = sub {};

    local %main::opt = ( dumpdir => '/tmp/dummy_dump' );

    main::dump_csv_files();

    my ($x_stmt) = grep { $_->{file} =~ /sys_x\$statement_analysis\.csv$/ } @selected_queries;
    ok($x_stmt, "Dumps x\$statement_analysis view");
    is($x_stmt->{query}, "SELECT * FROM sys.`x\$statement_analysis`", "Query has backticks without literal backslash escaping");
    unlike($x_stmt->{query}, qr/sys\.\\`/, "Does not contain backslash before backtick");
    unlike($x_stmt->{query}, qr/sys\.\\\$/, "Does not contain double backslash before dollar");
};

subtest 'select_array_with_headers - Returns empty list on non-zero exit code' => sub {
    no warnings 'redefine';
    local $main::mysqlcmd   = 'mysql';
    local $main::mysqllogin = '';
    local $main::devnull    = '/dev/null';
    local *main::execute_system_command = sub {
        $? = 256; # Non-zero exit code
        return "ERROR 1064 (42000): You have an error in your SQL syntax";
    };
    local *main::badprint = sub {};

    my @res = main::select_array_with_headers("SELECT * FROM invalid_table");
    is(scalar @res, 0, "Returns empty list when command fails ($? != 0)");
};

subtest 'select_csv_file - Creates directory if non-existent' => sub {
    no warnings 'redefine';
    use File::Temp qw(tempdir);
    my $tmpdir = tempdir(CLEANUP => 1);
    my $nested_dir = "$tmpdir/nested_test_dir";
    my $test_file = "$nested_dir/test.csv";

    local *main::select_array_with_headers = sub {
        return ("header1\theader2", "val1\tval2");
    };
    local *main::debugprint = sub {};
    local *main::infoprint = sub {};
    local %main::opt = ();

    ok(!-d $nested_dir, "Target directory does not exist prior to select_csv_file");
    main::select_csv_file($test_file, "SELECT 1");
    ok(-d $nested_dir, "Directory was created automatically by select_csv_file");
    ok(-f $test_file, "CSV file was written successfully in newly created directory");
};

subtest 'dump_csv_files - Information schema skips legacy disabled status/variables views' => sub {
    no warnings 'redefine';
    my @dumped_files;

    local *main::select_array = sub {
        my $query = shift;
        if ($query =~ /use information_schema;show tables;/i) {
            return ('TABLES', 'COLUMNS', 'GLOBAL_STATUS', 'GLOBAL_VARIABLES', 'SESSION_STATUS', 'SESSION_VARIABLES');
        }
        return ();
    };

    local *main::select_csv_file = sub {
        my ($file, $query) = @_;
        push @dumped_files, $file;
    };
    local *main::infoprint = sub {};
    local *main::dump_sys_statement_analysis_statistical = sub {};
    local *main::write_manifest_files = sub {};

    local %main::opt = ( dumpdir => '/tmp/dummy_dump' );

    main::dump_csv_files();

    ok((grep { $_ =~ /ifs_TABLES\.csv$/ } @dumped_files), "Dumps normal table TABLES");
    ok((grep { $_ =~ /ifs_COLUMNS\.csv$/ } @dumped_files), "Dumps normal table COLUMNS");
    ok(!(grep { $_ =~ /ifs_GLOBAL_STATUS\.csv$/ } @dumped_files), "Skips disabled information_schema.GLOBAL_STATUS");
    ok(!(grep { $_ =~ /ifs_GLOBAL_VARIABLES\.csv$/ } @dumped_files), "Skips disabled information_schema.GLOBAL_VARIABLES");
    ok(!(grep { $_ =~ /ifs_SESSION_STATUS\.csv$/ } @dumped_files), "Skips disabled information_schema.SESSION_STATUS");
    ok(!(grep { $_ =~ /ifs_SESSION_VARIABLES\.csv$/ } @dumped_files), "Skips disabled information_schema.SESSION_VARIABLES");
};

done_testing();


