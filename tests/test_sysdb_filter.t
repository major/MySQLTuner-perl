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
require './tests/MySQLTuner/TestHelper.pm';

# Mock global variables
our %opt;

subtest 'sys_db_filter_definitions' => sub {
    no warnings 'redefine';
    my @executed_queries;
    local *main::select_array = sub {
        my $query = shift;
        push @executed_queries, $query;
        if ($query eq "SHOW DATABASES") {
            return ('sys'); # Mock sys database as existing
        }
        return ();
    };
    local *main::select_one = sub {
        my $query = shift;
        push @executed_queries, $query;
        return '1.5.2'; # sys version
    };
    local *main::badprint = sub {};
    local *main::goodprint = sub {};
    local *main::infoprint = sub {};
    local *main::subheaderprint = sub {};
    local *main::debugprint = sub {};
    local *main::get_pf_memory = sub { return 1024 * 1024; };
    
    # Setup some test helper settings to get past initialization checks in mysql_pfs
    MySQLTuner::TestHelper::reset_state();
    $main::myvar{performance_schema} = 'ON';
    $main::opt{pfstat} = 1;

    main::mysql_pfs();

    # Check if the generated queries include the DB filters
    my @statement_analysis_queries = grep { $_ =~ /statement_analysis/ } @executed_queries;
    ok(scalar @statement_analysis_queries > 0, "Found statement_analysis queries executed");
    for my $q (@statement_analysis_queries) {
        like($q, qr/WHERE db NOT IN/, "Query filters db column: $q");
    }

    my @table_stats_queries = grep { $_ =~ /schema_table_statistics/ } @executed_queries;
    ok(scalar @table_stats_queries > 0, "Found schema_table_statistics queries executed");
    for my $q (@table_stats_queries) {
        like($q, qr/(WHERE|AND) table_schema NOT IN/i, "Query filters table_schema column: $q");
    }
};

subtest 'dump_csv_files_filtering' => sub {
    no warnings 'redefine';
    my @selected_queries;
    local *main::select_array = sub {
        my $query = shift;
        if ($query =~ /show tables/) {
            return ('statement_analysis', 'x$statement_analysis', 'schema_index_statistics', 'users');
        }
        return ();
    };
    local *main::select_csv_file = sub {
        my ($file, $query) = @_;
        push @selected_queries, { file => $file, query => $query };
    };
    local *main::infoprint = sub {};

    # Set up opt dumpdir
    local %main::opt = ( dumpdir => '/tmp/dummy_dump' );

    main::dump_csv_files();

    my ($sa_query) = grep { $_->{file} =~ /sys_statement_analysis\.csv/ } @selected_queries;
    ok($sa_query, "Dumps statement_analysis");
    like($sa_query->{query}, qr/WHERE db NOT IN/, "Filters statement_analysis via db column");

    my ($xsa_query) = grep { $_->{file} =~ /sys_x\$statement_analysis\.csv/ } @selected_queries;
    ok($xsa_query, "Dumps x\$statement_analysis");
    like($xsa_query->{query}, qr/WHERE db NOT IN/, "Filters x\$statement_analysis via db column");

    my ($sis_query) = grep { $_->{file} =~ /sys_schema_index_statistics\.csv/ } @selected_queries;
    ok($sis_query, "Dumps schema_index_statistics");
    like($sis_query->{query}, qr/WHERE table_schema NOT IN/, "Filters schema_index_statistics via table_schema column");

    my ($users_query) = grep { $_->{file} =~ /sys_users\.csv/ } @selected_queries;
    ok($users_query, "Dumps generic table users");
    unlike($users_query->{query}, qr/WHERE/, "Does not filter generic table users if not in %sys_schema_filter_cols");
};

done_testing();
