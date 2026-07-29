#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";

# Mock MySQLTuner environment and helper modules
require 'mysqltuner.pl';

# Helper for resetting state
sub reset_galera_state {
    no warnings 'once';
    %main::myvar = ();
    %main::mystat = ();
    @main::generalrec = ();
    @main::adjvars = ();
    $main::physical_memory = 4 * 1024 * 1024 * 1024; # 4GB RAM
    
    # Enable Galera globally for tests
    $main::myvar{'have_galera'} = 'YES';
    $main::myvar{'wsrep_on'} = 'ON';
    $main::myvar{'wsrep_provider_options'} = 'gcache.size = 256M; gcs.fc_limit = 50; gcs.fc_factor = 0.8; wsrep_flow_control_paused = 0.0; wsrep_slave_FK_checks = ON;';
    $main::myvar{'innodb_autoinc_lock_mode'} = 2;
}

# Subtest 1: parse_size_bytes helper validation
subtest 'parse_size_bytes helper validation' => sub {
    is(main::parse_size_bytes('1024'), 1024, 'Parses raw bytes');
    is(main::parse_size_bytes('256K'), 256 * 1024, 'Parses Kilobytes');
    is(main::parse_size_bytes('128M'), 128 * 1024 * 1024, 'Parses Megabytes');
    is(main::parse_size_bytes('2G'), 2 * 1024 * 1024 * 1024, 'Parses Gigabytes');
    is(main::parse_size_bytes('invalid'), 0, 'Invalid size returns 0');
};

# Subtest 2: Streaming Replication Monitor
subtest 'Streaming Replication Monitor' => sub {
    reset_galera_state();
    $main::mystat{'wsrep_streaming_log_writes'} = 15;
    $main::mystat{'wsrep_streaming_log_reads'}  = 5;

    main::mariadb_galera();

    ok(grep(/Streaming replication active. Review wsrep_trx_fragment_size/, @main::generalrec), 'Suggests fragment size review when streaming is active');
};

# Subtest 3: Gcache Sizing Optimization
subtest 'Gcache Sizing Optimization' => sub {
    # Test 3a: gcache size is sufficient
    reset_galera_state();
    $main::myvar{'wsrep_provider_options'} = 'gcache.size = 256M; gcache.page_size = 128M; gcs.fc_limit = 50; gcs.fc_factor = 0.8; wsrep_flow_control_paused = 0.0;';
    main::mariadb_galera();
    ok(!grep(/Increase gcache.size in wsrep_provider_options/, @main::generalrec), 'No warning when gcache size is sufficient (>128M and >5% RAM)');

    # Test 3b: gcache size is too small (<128M)
    reset_galera_state();
    $main::myvar{'wsrep_provider_options'} = 'gcache.size = 64M; gcs.fc_limit = 50; gcs.fc_factor = 0.8; wsrep_flow_control_paused = 0.0;';
    main::mariadb_galera();
    ok(grep(/Increase gcache.size in wsrep_provider_options/, @main::generalrec), 'Suggests gcache expansion when size is below minimum threshold');
};

# Subtest 4: Certification Conflict & Abort Analysis
subtest 'Certification Conflict & Abort Analysis' => sub {
    reset_galera_state();
    $main::mystat{'wsrep_local_bf_aborts'} = 60;
    $main::mystat{'wsrep_local_cert_failures'} = 10;

    main::mariadb_galera();

    ok(grep(/High certification conflicts/, @main::generalrec), 'Warns on high brute-force aborts');
};

# Subtest 5: Advanced Flow Control Observability
subtest 'Advanced Flow Control Observability' => sub {
    # Test 5a: Node is flow control pause sender
    reset_galera_state();
    $main::mystat{'wsrep_flow_control_sent'} = 5;
    main::mariadb_galera();
    ok(grep(/Node is triggering flow control pause events/, @main::generalrec), 'Warns when node acts as flow control pause sender');

    # Test 5b: Node is heavily throttled
    reset_galera_state();
    $main::mystat{'wsrep_flow_control_paused'} = 0.08; # 8% of the time
    main::mariadb_galera();
    ok(grep(/Node is heavily throttled by flow control/, @main::generalrec), 'Warns when node is throttled > 5%');
};

# Subtest 6: Group Communication Latency & Jitter
subtest 'Group Communication Latency & Jitter' => sub {
    # Test 6a: High replication latency
    reset_galera_state();
    $main::mystat{'wsrep_evs_repl_latency'} = '0.005/0.120/0.500/0.010'; # avg is 120ms (>100ms)
    main::mariadb_galera();
    ok(grep(/High average replication latency/, @main::generalrec), 'Warns on high avg group latency');

    # Test 6b: High replication jitter
    reset_galera_state();
    $main::mystat{'wsrep_evs_repl_latency'} = '0.005/0.020/0.300/0.060'; # stddev is 60ms (>50ms)
    main::mariadb_galera();
    ok(grep(/High replication jitter/, @main::generalrec), 'Warns on high network replication jitter');
};

# Subtest 7: Applier Concurrency Tuning
subtest 'Applier Concurrency Tuning' => sub {
    reset_galera_state();
    $main::myvar{'wsrep_slave_threads'} = 1;
    $main::mystat{'wsrep_cert_deps_distance'} = 8.5; # >4

    main::mariadb_galera();

    ok(grep(/Consider increasing wsrep_slave_threads/, @main::generalrec), 'Suggests increasing slave threads when deps distance is high');
};

# Subtest 8: PXC Strict Mode Verification
subtest 'PXC Strict Mode Verification' => sub {
    # Test 8a: Percona Cluster with enforcing mode OK
    reset_galera_state();
    $main::myvar{'version_comment'} = 'Percona XtraDB Cluster (GPL), Release 22.4';
    $main::myvar{'pxc_strict_mode'} = 'ENFORCING';
    main::mariadb_galera();
    ok(!grep(/Set pxc_strict_mode = ENFORCING/, @main::generalrec), 'No warning when PXC strict mode is ENFORCING');

    # Test 8b: Percona Cluster with disabled strict mode
    reset_galera_state();
    $main::myvar{'version_comment'} = 'Percona XtraDB Cluster (GPL), Release 22.4';
    $main::myvar{'pxc_strict_mode'} = 'DISABLED';
    main::mariadb_galera();
    ok(grep(/Set pxc_strict_mode = ENFORCING/, @main::generalrec), 'Warns when PXC strict mode is DISABLED');
};

done_testing();
