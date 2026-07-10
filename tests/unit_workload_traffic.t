#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";

# Mock MySQLTuner environment and helper modules
require 'mysqltuner.pl';

# Helper for resetting state
sub reset_workload_state {
    no warnings 'once';
    %main::myvar = ();
    %main::mystat = ();
    @main::generalrec = ();
    @main::adjvars = ();
    $main::is_local_only = 0;
    
    # Defaults
    $main::myvar{'performance_schema'} = 'ON';
}

# Subtest 1: Workload Characterization
subtest 'Workload Characterization' => sub {
    no warnings 'once';
    # Test 1a: Read-heavy workload
    reset_workload_state();
    $main::mystat{'Com_select'} = 900;
    $main::mystat{'Com_insert'} = 50;
    $main::mystat{'Com_update'} = 30;
    $main::mystat{'Com_delete'} = 20;
    main::check_workload_traffic();
    ok(!grep(/Write-heavy workload detected/, @main::generalrec), 'No write-heavy warning for read-heavy workload');

    # Test 1b: Write-heavy workload
    reset_workload_state();
    $main::mystat{'Com_select'} = 50;
    $main::mystat{'Com_insert'} = 500;
    $main::mystat{'Com_update'} = 300;
    $main::mystat{'Com_delete'} = 150;
    main::check_workload_traffic();
    ok(grep(/Write-heavy workload detected/, @main::generalrec), 'Warns and recommends on write-heavy workload');
};

# Subtest 2: Wait Event Fingerprinting
subtest 'Wait Event Fingerprinting' => sub {
    no warnings 'redefine';
    # Test 2a: Disk I/O bottleneck
    reset_workload_state();
    local *main::select_array = sub {
        my $sql = shift;
        if ($sql =~ /events_waits_summary_global_by_event_name/i) {
            return (
                "wait/io/file/innodb/innodb_data_file\t800000000000000",
                "wait/synch/mutex/innodb/buf_pool_mutex\t100000000000000",
                "wait/io/socket/mysql/client_connection\t5000000000000\n"
            );
        }
        return ();
    };
    main::check_workload_traffic();
    ok(grep(/Primary database bottleneck is Disk I\/O/, @main::generalrec), 'Warns on Disk I/O bottleneck');

    # Test 2b: Lock contention bottleneck
    reset_workload_state();
    local *main::select_array = sub {
        my $sql = shift;
        if ($sql =~ /events_waits_summary_global_by_event_name/i) {
            return (
                "wait/synch/mutex/innodb/buf_pool_mutex\t900000000000000",
                "wait/io/file/innodb/innodb_data_file\t50000000000000"
            );
        }
        return ();
    };
    main::check_workload_traffic();
    ok(grep(/Primary database bottleneck is Lock contention/, @main::generalrec), 'Warns on lock contention bottleneck');
};

# Subtest 3: Table Churn & Fragmentation Alignment
subtest 'Table Churn & Fragmentation Alignment' => sub {
    no warnings 'redefine', 'once';
    reset_workload_state();
    # Mock table churn queries
    local *main::select_array = sub {
        my $sql = shift;
        if ($sql =~ /table_io_waits_summary_by_table/i) {
            return ("test_db\tactive_table\t15000");
        }
        return ();
    };
    # Mock fragmented tables list
    $main::result{'Tables'}{'Fragmented tables'} = [ "test_db\tactive_table\tInnoDB\t104857600" ];
    main::check_workload_traffic();
    ok(grep(/Defragment high-churn table `test_db`.`active_table`/, @main::generalrec), 'Suggests defragmentation on high-churn table');
};

# Subtest 4: Auto-Increment Exhaustion Audit
subtest 'Auto-Increment Exhaustion Audit' => sub {
    no warnings 'redefine', 'once';
    reset_workload_state();
    # Mock auto increment columns query
    local *main::select_array = sub {
        my $sql = shift;
        if ($sql =~ /information_schema\.tables/i) {
            return ("test_db\tlarge_table\tid\tint\t3500000000");
        }
        return ();
    };
    # Mock column type details (unsigned)
    local *main::select_one = sub {
        my $sql = shift;
        if ($sql =~ /COLUMN_TYPE/i) {
            return 'int(11) unsigned';
        }
        return '';
    };
    main::check_workload_traffic();
    ok(grep(/Danger of auto-increment overflow on `test_db`.`large_table`.`id`/, @main::generalrec), 'Warns when auto-increment is near exhaustion');
};

done_testing();
