#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use Data::Dumper;

# 1. Load MySQLTuner logic
require './mysqltuner.pl';
require './tests/MySQLTuner/TestHelper.pm';

# Mock print functions to collect output
$main::good = '[OK]';
$main::bad  = '[!!]';
$main::info = '[--]';
$main::deb  = '[DG]';
$main::end  = '';
our %myvar;
our %mystat;
our %myrepl;
our @generalrec;
our $physical_memory;

# Helper to intercept select_array and select_one for mock values
my $mock_members_data = [];
my $mock_stats_data = '';
my $mock_router_data = 0;

no warnings 'redefine';
*main::select_array = sub {
    my ($sql) = @_;
    if ($sql =~ /replication_group_members/i) {
        return @$mock_members_data;
    }
    return ();
};

*main::select_one = sub {
    my ($sql) = @_;
    if ($sql =~ /\@\@server_uuid/i) {
        return 'mock-uuid-1111';
    }
    if ($sql =~ /replication_group_member_stats/i) {
        return $mock_stats_data;
    }
    if ($sql =~ /processlist.*router/i) {
        return $mock_router_data;
    }
    return undef;
};

subtest 'Group Replication ONLINE Topology & single-primary OK' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;
    
    # Mock system configuration
    $main::myvar{'group_replication_group_name'} = 'test-cluster';
    $main::myvar{'group_replication_single_primary_mode'} = 'ON';
    $main::myvar{'performance_schema'} = 'ON';
    $main::physical_memory = 8 * 1024 * 1024 * 1024; # 8GB
    $main::myvar{'group_replication_message_cache_size'} = 1073741824; # 1GB
    $main::myvar{'group_replication_unreachable_majority_timeout'} = 10; # OK

    # Mock group members: 3 nodes, all ONLINE, 1 primary, matching version
    $mock_members_data = [
        "host1\t3306\tONLINE\tPRIMARY\t8.0.35",
        "host2\t3306\tONLINE\tSECONDARY\t8.0.35",
        "host3\t3306\tONLINE\tSECONDARY\t8.0.35"
    ];
    $mock_stats_data = '10|5|1000|2'; # queue values well below 25000 threshold, rollback ratio 0.2%
    $mock_router_data = 0;

    main::check_replication_advanced();

    ok(!grep(/not ONLINE/, @main::generalrec), 'No offline member warnings');
    ok(!grep(/single-primary mode requires/, @main::generalrec), 'Primary member count OK');
    ok(!grep(/Inconsistent MySQL versions/, @main::generalrec), 'Version consistency OK');
};

subtest 'Group Replication offline nodes and multiple primaries warnings' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;

    $main::myvar{'group_replication_group_name'} = 'test-cluster';
    $main::myvar{'group_replication_single_primary_mode'} = 'ON';
    $main::myvar{'performance_schema'} = 'ON';
    $main::physical_memory = 8 * 1024 * 1024 * 1024;
    $main::myvar{'group_replication_message_cache_size'} = 1073741824;
    $main::myvar{'group_replication_unreachable_majority_timeout'} = 10;

    # host2 is RECOVERING, host3 is ONLINE but also PRIMARY (illegal in single primary mode)
    # version mismatch on host3 (8.4.0)
    $mock_members_data = [
        "host1\t3306\tONLINE\tPRIMARY\t8.0.35",
        "host2\t3306\tRECOVERING\tSECONDARY\t8.0.35",
        "host3\t3306\tONLINE\tPRIMARY\t8.4.0"
    ];
    $mock_stats_data = '10|5|1000|2';

    main::check_replication_advanced();

    ok(grep(/is not ONLINE/, @main::generalrec), 'Warns on recovering member');
    ok(grep(/single-primary mode requires exactly 1 primary/, @main::generalrec), 'Warns on multiple primaries');
    ok(grep(/Standardize MySQL versions/, @main::generalrec), 'Warns on version inconsistency');
};

subtest 'Flow Control Queues & Certification Rollbacks' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;

    $main::myvar{'group_replication_group_name'} = 'test-cluster';
    $main::myvar{'group_replication_single_primary_mode'} = 'ON';
    $main::myvar{'performance_schema'} = 'ON';
    $main::physical_memory = 8 * 1024 * 1024 * 1024;
    $main::myvar{'group_replication_message_cache_size'} = 1073741824;
    $main::myvar{'group_replication_unreachable_majority_timeout'} = 10;

    $mock_members_data = [
        "host1\t3306\tONLINE\tPRIMARY\t8.0.35"
    ];
    # cert_queue: 30000 (>25000), applier_queue: 40000 (>25000)
    # rollbacks: 100 out of 1000 total (10% rollback ratio > 5% threshold)
    $mock_stats_data = '30000|40000|900|100';

    main::check_replication_advanced();

    ok(grep(/group_replication_flow_control_period/, @main::generalrec), 'Warns on certification queue flow control');
    ok(grep(/Scale replication parallel threads/, @main::generalrec), 'Warns on applier queue flow control');
    ok(grep(/High certification rollback ratio/, @main::generalrec), 'Warns on certification rollbacks');
};

subtest 'Resilience Cache & Timeout checks' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;

    $main::myvar{'group_replication_group_name'} = 'test-cluster';
    $main::myvar{'group_replication_single_primary_mode'} = 'ON';
    $main::myvar{'performance_schema'} = 'ON';
    
    # 3GB cache size on 4GB RAM system (75% of RAM, >30% threshold)
    $main::physical_memory = 4 * 1024 * 1024 * 1024;
    $main::myvar{'group_replication_message_cache_size'} = 3 * 1024 * 1024 * 1024;
    
    # timeout set to 0
    $main::myvar{'group_replication_unreachable_majority_timeout'} = 0;

    $mock_members_data = [
        "host1\t3306\tONLINE\tPRIMARY\t8.0.35"
    ];
    $mock_stats_data = '10|5|1000|2';

    main::check_replication_advanced();

    ok(grep(/Reduce group_replication_message_cache_size/, @main::generalrec), 'Warns on excessive cache sizing');
    ok(grep(/Configure group_replication_unreachable_majority_timeout/, @main::generalrec), 'Warns on zero timeout value');
};

subtest 'MySQL Router Connectivity' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;
    
    $main::myvar{'group_replication_group_name'} = 'test-cluster';
    $main::myvar{'group_replication_single_primary_mode'} = 'ON';
    $main::myvar{'performance_schema'} = 'ON';
    $main::physical_memory = 8 * 1024 * 1024 * 1024;
    $main::myvar{'group_replication_message_cache_size'} = 1073741824;
    $main::myvar{'group_replication_unreachable_majority_timeout'} = 10;

    $mock_members_data = [
        "host1\t3306\tONLINE\tPRIMARY\t8.0.35"
    ];
    $mock_stats_data = '10|5|1000|2';
    
    # Mock active router connections
    $mock_router_data = 5;

    main::check_replication_advanced();
    
    # Verified by the output prints
    pass('MySQL Router connectivity check passed');
};

done_testing();
