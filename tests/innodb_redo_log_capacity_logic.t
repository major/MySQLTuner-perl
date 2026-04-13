#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Mocking essentials to avoid dependencies
require './mysqltuner.pl';

$main::good = '[OK]';
$main::bad  = '[!!]';
$main::info = '[--]';
$main::deb  = '[DG]';
$main::end  = '';

# Global variables that need to be cleared/reset
our %myvar;
our %mystat;
our %enginestats;
our @adjvars;
our @generalrec;
our $physical_memory;

sub reset_state {
    %main::myvar = (
        have_innodb => 'YES',
        default_storage_engine => 'InnoDB',
    );
    %main::mystat = ();
    %main::enginestats = ( InnoDB => 1024 * 1024 ); # Some dummy data
    @main::adjvars = ();
    @main::generalrec = ();
    $main::physical_memory = 0;
}

# Test Case 1: Small RAM (< 2GB), low workload
subtest 'Small RAM, Low Workload' => sub {
    reset_state();
    %main::myvar = (
        %main::myvar,
        version => '8.0.35',
        innodb_redo_log_capacity => 100 * 1024 * 1024,
        innodb_buffer_pool_size => 128 * 1024 * 1024,
    );
    %main::mystat = (
        Innodb_os_log_written => 10 * 1024 * 1024, # 10MB
        Uptime => 3601,
    );
    $main::physical_memory = 1 * 1024 * 1024 * 1024; # 1GB

    main::mysql_innodb();
    
    ok(!grep(/innodb_redo_log_capacity/, @main::adjvars), 'No increase suggested for small RAM and low workload');
};

# Test Case 2: Large RAM, low workload (The "issue #714" case)
subtest 'Large RAM, Low Workload' => sub {
    reset_state();
    %main::myvar = (
        %main::myvar,
        version => '8.0.35',
        innodb_redo_log_capacity => 100 * 1024 * 1024,
        innodb_buffer_pool_size => 64 * 1024 * 1024 * 1024, # 64GB BP
    );
    %main::mystat = (
        Innodb_os_log_written => 500 * 1024 * 1024, # 500MB
        Uptime => 3601,
    );
    $main::physical_memory = 120 * 1024 * 1024 * 1024; # ~120GB

    main::mysql_innodb();
    
    ok(grep(/innodb_redo_log_capacity \(>= 1.0G\)/, @main::adjvars), 'Suggested 1.0G instead of 16GB (25% of BP)');
};

# Test Case 3: Dedicated Server
subtest 'Dedicated Server ON' => sub {
    reset_state();
    %main::myvar = (
        %main::myvar,
        version => '8.0.35',
        innodb_dedicated_server => 'ON',
        innodb_redo_log_capacity => 16 * 1024 * 1024 * 1024,
        innodb_buffer_pool_size => 64 * 1024 * 1024 * 1024,
    );
    %main::mystat = (
        Innodb_os_log_written => 500 * 1024 * 1024,
        Uptime => 3601,
    );
    $main::physical_memory = 128 * 1024 * 1024 * 1024;

    main::mysql_innodb();
    
    ok(!grep(/innodb_redo_log_capacity/, @main::adjvars), 'No changes suggested when dedicated server is ON');
};

# Test Case 4: High Workload
subtest 'High Workload' => sub {
    reset_state();
    %main::myvar = (
        %main::myvar,
        version => '8.0.35',
        innodb_redo_log_capacity => 1 * 1024 * 1024 * 1024, # 1GB
        innodb_buffer_pool_size => 32 * 1024 * 1024 * 1024,
    );
    %main::mystat = (
        Innodb_os_log_written => 10 * 1024 * 1024 * 1024, # 10GB written in 1h
        Uptime => 3601,
    );
    $main::physical_memory = 64 * 1024 * 1024 * 1024;

    main::mysql_innodb();
    
    ok(grep(/innodb_redo_log_capacity \(>= 10.0G\)/, @main::adjvars), 'Suggested 10.0G due to high workload');
};

done_testing();
