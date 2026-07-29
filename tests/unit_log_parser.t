#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";
use File::Temp qw(tempfile);

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
    $main::maxlines = 10000;
    
    # Defaults to avoid validation failures
    $main::mystat{'Questions'} = 1000;
    $main::mystat{'Connections'} = 100;
    $main::mystat{'Aborted_connects'} = 0;
    $main::mystat{'Table_locks_immediate'} = 0;
}

subtest 'InnoDB Lock Monitoring variables audit' => sub {
    no warnings 'redefine', 'once';
    reset_test_state();
    $main::myvar{'have_innodb'} = 'YES';
    $main::myvar{'innodb_print_all_deadlocks'} = 'OFF';
    $main::myvar{'innodb_status_output'} = 'OFF';
    $main::myvar{'innodb_status_output_locks'} = 'OFF';
    
    main::mysql_innodb();
    
    ok(grep(/Enable innodb_print_all_deadlocks = ON/, @main::generalrec), 'Suggests enabling deadlock printout');
    ok(grep(/Consider enabling innodb_status_output_locks = ON/, @main::generalrec), 'Suggests enabling status output locks');
};

subtest 'Log Error Verbosity and Warning Level Audit' => sub {
    no warnings 'redefine', 'once';
    reset_test_state();
    $main::myvar{'version'} = '8.0.35'; # MySQL 8.0+
    $main::myvar{'log_error_verbosity'} = 1; # Too low
    
    # Create empty temp log to bypass empty log check
    my ($fh, $filename) = tempfile();
    print $fh "2026-07-09T01:00:00Z [Note] [MY-000000] ready for connections\n";
    close $fh;
    $main::myvar{'log_error'} = $filename;
    
    main::log_file_recommendations();
    
    ok(grep(/Set log_error_verbosity = 2 or 3/, @main::generalrec), 'Suggests increasing log_error_verbosity');
    unlink($filename);
};

subtest 'Proactive Semantic Error Log Tracer' => sub {
    no warnings 'redefine', 'once';
    reset_test_state();
    $main::myvar{'version'} = '10.11.8-MariaDB';
    $main::myvar{'log_warnings'} = 2; # Good
    
    # Create temp log file with OOM, semaphore, descriptor limit, and corruption events
    my ($fh, $filename) = tempfile();
    print $fh "2026-07-09T01:00:00Z [Note] [MY-000000] ready for connections\n";
    print $fh "2026-07-09T01:01:00Z [Warning] Out of memory (Needed 1048576 bytes)\n";
    print $fh "2026-07-09T01:02:00Z [Error] InnoDB: semaphore wait timeout exceeded\n";
    print $fh "2026-07-09T01:03:00Z [Error] Error in accept: Too many open files\n";
    print $fh "2026-07-09T01:04:00Z [Warning] Table './test/users' is marked as crashed and should be repaired\n";
    close $fh;
    
    $main::myvar{'log_error'} = $filename;
    
    main::log_file_recommendations();
    
    ok(grep(/Verify system RAM allocations and consider reducing innodb_buffer_pool_size/, @main::generalrec), 'Suggests buffer pool check on OOM');
    ok(grep(qr{Audit storage I/O capacity or check system-level contention}, @main::generalrec), 'Suggests I/O check on semaphore wait');
    ok(grep(/Increase open_files_limit or raise OS-level ulimits/, @main::generalrec), 'Suggests ulimit check on too many open files');
    ok(grep(qr{Run CHECK TABLE / REPAIR TABLE or restore from backup}, @main::generalrec), 'Suggests recovery check on crashed table');
    
    unlink($filename);
};

subtest 'Experimental Correlation Engine' => sub {
    no warnings 'redefine', 'once';
    reset_test_state();
    $main::myvar{'version'} = '10.11.8-MariaDB';
    $main::myvar{'log_warnings'} = 2;
    $main::mystat{'Innodb_row_lock_waits'} = 25; # High lock contention
    
    # Mock load average to return high load
    local *main::get_load_average = sub { return (12.5, 10.2, 8.1); };
    local *main::logical_cpu_cores = sub { return 4; }; # 12.5 > 4 (high load)
    
    my ($fh, $filename) = tempfile();
    print $fh "2026-07-09T01:00:00Z [Note] [MY-000000] ready for connections\n";
    print $fh "2026-07-09T01:02:00Z [Error] InnoDB: semaphore wait timeout exceeded\n";
    close $fh;
    
    $main::myvar{'log_error'} = $filename;
    
    # Capture prints
    my @prints;
    local *main::infoprint = sub { push @prints, $_[0] };
    
    main::log_file_recommendations();
    
    ok(grep(qr{Experimental Correlation: Log anomalies \(semaphore/OOM\) correlate with active system pressure}, @prints), 'Correlates log semaphore stalls with system pressure');
    
    unlink($filename);
};

done_testing();
