#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";

# Mock MySQLTuner environment and helper modules
require 'mysqltuner.pl';

# Helper for resetting state
sub reset_test_state {
    no warnings 'once';
    %main::myvar = ();
    %main::mystat = ();
    @main::generalrec = ();
    @main::adjvars = ();
    $main::is_local_only = 0;
}

subtest 'InnoDB Lock Deadlocks PFS Audit' => sub {
    no warnings 'redefine', 'once';
    reset_test_state();
    $main::myvar{'performance_schema'} = 'ON';
    $main::myvar{'version'} = '8.0.35'; # MySQL 8.0+
    $main::myvar{'have_innodb'} = 'YES'; # Enable InnoDB path
    
    # Populate the version globals
    main::validate_mysql_version();
    
    # Mock select_array and select_one to return correct values
    local *main::select_one = sub {
        my $sql = shift;
        if ($sql =~ /events_errors_summary_global_by_error/i) {
            return 1;
        }
        return 0;
    };
    local *main::select_array = sub {
        my $sql = shift;
        if ($sql =~ /SHOW ENGINE PERFORMANCE_SCHEMA STATUS/i) {
            return ("\tperformance_schema.memory\t104857600");
        }
        if ($sql =~ /events_errors_summary_global_by_error/i) {
            return (5);
        }
        return (0);
    };
    
    main::mysql_innodb();
    ok(grep(/Optimize application queries, transaction lengths, and index coverage to reduce lock deadlocks/, @main::generalrec), 'Suggests query optimization on lock deadlocks detection');
};

subtest 'InnoDB Lock Deadlocks PFS Query Column Verification' => sub {
    no warnings 'redefine', 'once';
    reset_test_state();
    $main::myvar{'performance_schema'} = 'ON';
    $main::myvar{'version'} = '8.0.35';
    $main::myvar{'have_innodb'} = 'YES';
    main::validate_mysql_version();
    
    my $query_checked_raised = 0;
    my $query_checked_count_star = 0;
    
    local *main::select_one = sub {
        my $sql = shift;
        if ($sql =~ /events_errors_summary_global_by_error/i) {
            return 1;
        }
        return 0;
    };
    local *main::select_array = sub {
        my $sql = shift;
        if ($sql =~ /SUM_ERROR_RAISED/i) {
            $query_checked_raised = 1;
        }
        if ($sql =~ /COUNT_STAR/i) {
            $query_checked_count_star = 1;
        }
        return (0);
    };
    
    main::mysql_innodb();
    ok($query_checked_raised, 'PFS deadlock audit query correctly uses SUM_ERROR_RAISED');
    ok(!$query_checked_count_star, 'PFS deadlock audit query does NOT use COUNT_STAR');
};

done_testing();
