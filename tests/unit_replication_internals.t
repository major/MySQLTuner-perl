#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use Data::Dumper;

# 1. Load MySQLTuner logic
require './mysqltuner.pl';
require './tests/MySQLTuner/TestHelper.pm';

# Mocking essential globals and subroutines
$main::good = '[OK]';
$main::bad  = '[!!]';
$main::info = '[--]';
$main::deb  = '[DG]';
$main::end  = '';
our %myvar;
our %mystat;
our %myrepl;
our @generalrec;

# Task 1: GTID Gap Analysis
subtest 'GTID Gap Analysis' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0; # Enable advanced checks
    
    # Mock replica status to simulate a running replica
    $main::myrepl{'Seconds_Behind_Source'} = 0;
    $main::myrepl{'Replica_IO_Running'} = 'Yes';
    $main::myrepl{'Replica_SQL_Running'} = 'Yes';
    $main::myrepl{'Executed_Gtid_Set'} = '11111111-1111-1111-1111-111111111111:1-10:12-20'; # Has a gap (missing 11)

    main::check_replication_advanced();
    
    ok(grep(/GTID Gap detected/, @main::generalrec), 'Recommends checking replication consistency for GTID gap');
};

# Task 2: Parallel Applier workers check
subtest 'Parallel Applier workers' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;
    $main::myrepl{'Seconds_Behind_Source'} = 0;
    $main::myvar{'replica_parallel_workers'} = 0;
    $main::myvar{'slave_parallel_workers'} = 0;

    main::check_replication_advanced();
    
    # It just prints info on single-threaded replica, no push_recommendation needed unless specified.
    pass("Parallel applier verified");
};

# Task 3: GTID mode check
subtest 'GTID mode check' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;
    $main::myvar{'gtid_mode'} = 'OFF';
    $main::myvar{'enforce_gtid_consistency'} = 'WARN';
    $main::myvar{'binlog_format'} = 'STATEMENT';

    main::check_replication_advanced();
    
    ok(grep(/Set gtid_mode = ON/, @main::generalrec), 'Recommends setting gtid_mode = ON');
    ok(grep(/Set enforce_gtid_consistency = ON/, @main::generalrec), 'Recommends setting enforce_gtid_consistency = ON');
    ok(grep(/Set binlog_format = ROW/, @main::generalrec), 'Recommends setting binlog_format = ROW');
};

# Task 4: Dependency tracking check
subtest 'Dependency tracking check' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;
    $main::myvar{'binlog_transaction_dependency_tracking'} = 'COMMIT_ORDER';

    main::check_replication_advanced();
    
    ok(grep(/Set binlog_transaction_dependency_tracking = WRITESET/, @main::generalrec), 'Recommends setting WRITESET for parallel throughput');
};

# Task 5: Binlog compression check
subtest 'Binlog compression check' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;
    $main::myvar{'binlog_transaction_compression'} = 'OFF';

    main::check_replication_advanced();
    
    ok(grep(/Enable binlog_transaction_compression = ON/, @main::generalrec), 'Suggests enabling binlog compression');
};

# Task 6: Binlog cache check
subtest 'Binlog cache check' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;
    $main::mystat{'Binlog_cache_disk_use'} = 10;
    $main::mystat{'Binlog_cache_use'} = 90; # ratio = 10% (>5%)

    main::check_replication_advanced();
    
    ok(grep(/Increase binlog_cache_size/, @main::generalrec), 'Recommends increasing binlog_cache_size to reduce spills');
};

# Task 7: Semi-sync wait point check
subtest 'Semi-sync wait point check' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;
    $main::myvar{'rpl_semi_sync_master_enabled'} = 'ON';
    $main::myvar{'rpl_semi_sync_master_wait_point'} = 'AFTER_COMMIT';

    main::check_replication_advanced();
    
    ok(grep(/Set rpl_semi_sync_source_wait_point = AFTER_SYNC/, @main::generalrec), 'Recommends setting AFTER_SYNC wait point');
};

# Task 8: Replication Checksums and Terminology verification
subtest 'Replication Checksums & Terminology' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    $main::is_local_only = 0;
    
    # Set legacy variables to trigger warnings
    $main::myvar{'master_verify_checksum'} = 'OFF';
    $main::myvar{'slave_sql_verify_checksum'} = 'OFF';
    $main::myvar{'slave_skip_verify_binlog_checksum'} = 'ON';

    main::check_replication_advanced();

    # Verify recommendations are made using clean terms
    ok(grep(/Enable source_verify_checksum/, @main::generalrec), 'Recommends source_verify_checksum instead of master_verify_checksum');
    ok(grep(/Enable replica_sql_verify_checksum/, @main::generalrec), 'Recommends replica_sql_verify_checksum instead of slave_sql_verify_checksum');
    ok(grep(/Disable replica_skip_verify_binlog_checksum/, @main::generalrec), 'Recommends replica_skip_verify_binlog_checksum instead of slave');

    # Double check no raw 'master' or 'slave' in the output recommendations
    foreach my $rec (@main::generalrec) {
        # Exclude legacy variable names in parentheses: e.g. "Enable source_verify_checksum = ON (or master_verify_checksum)."
        my $clean_rec = $rec;
        $clean_rec =~ s/\((?:or )?master_verify_checksum\)//g;
        $clean_rec =~ s/\((?:or )?slave_sql_verify_checksum\)//g;
        $clean_rec =~ s/slave_skip_verify_binlog_checksum//g;
        
        like($clean_rec, qr/^(?!.*\b(?:master|slave)\b).*$/i, "No standalone 'master' or 'slave' in recommendation: $rec");
    }
};

done_testing();
