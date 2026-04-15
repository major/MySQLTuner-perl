#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Load MySQLTuner
require './mysqltuner.pl';

# Force redefinition of essential subs
no warnings 'redefine';
*main::execute_system_command = sub { 
    my $cmd = shift;
    if ($cmd =~ /ping/) { return "mysqld is alive"; }
    return "";
};
*main::which = sub { return "/usr/bin/mysql" };
*main::infoprint = sub { };
*main::goodprint = sub { };
*main::badprint = sub { };
*main::subheaderprint = sub { };
*main::debugprint = sub { };

# Mock globals
$main::good = '[OK]';
$main::bad  = '[!!]';
$main::info = '[--]';
$main::deb  = '[DG]';
$main::end  = '';
our %myvar;
our %mystat;
our %mycalc;
our @adjvars;
our @generalrec;

sub reset_state {
    @main::adjvars = ();
    @main::generalrec = ();
    $main::mysqllogin = "-u root";
    $main::mysqlcmd = "mysql";
    $main::mysqladmincmd = "mysqladmin";
    $main::devnull = "/dev/null";
    
    %main::myvar = (
        have_innodb => 'YES',
        version => '8.0.35',
        version_comment => 'MySQL Community Server (GPL)',
        table_open_cache => 400,
        table_open_cache_instances => 1,
        max_connections => 151,
        query_cache_size => 0,
        thread_cache_size => 8,
        aria_pagecache_buffer_size => 0,
        key_buffer_size => 8 * 1024 * 1024,
        innodb_buffer_pool_size => 128 * 1024 * 1024,
        innodb_log_buffer_size => 8 * 1024 * 1024,
        innodb_additional_mem_pool_size => 0,
        innodb_file_per_table => 'ON',
        log_bin => 'OFF',
        concurrent_insert => 'AUTO',
        open_files_limit => 1024,
        long_query_time => 10,
        hostname => 'localhost',
        datadir => '/var/lib/mysql/',
    );
    %main::mystat = (
        Questions => 100,
        Uptime => 86400,
        Max_used_connections => 10,
        Connections => 100,
        Aborted_connects => 0,
        Key_read_requests => 100,
        Key_reads => 0,
        Key_write_requests => 100,
        Key_writes => 0,
        Qcache_hits => 0,
        Com_select => 0,
        Com_delete => 0,
        Com_insert => 0,
        Com_update => 0,
        Com_replace => 0,
        Sort_scan => 0,
        Sort_range => 0,
        Sort_merge_passes => 0,
        Select_range_check => 0,
        Select_full_join => 0,
        Created_tmp_tables => 0,
        Created_tmp_disk_tables => 0,
        Opened_tables => 100,
        Open_tables => 100,
        Threads_cached => 5,
        Threads_created => 1,
        Table_locks_immediate => 100,
        Table_locks_waited => 0,
        Innodb_buffer_pool_reads => 0,
        Innodb_buffer_pool_read_requests => 100,
        Table_open_cache_hits => 100,
        Table_open_cache_misses => 10,
        Open_files => 50,
    );
    %main::mycalc = (
        table_cache_hit_rate => 10, # Force low hit rate to trigger recommendation
    );
    $main::physical_memory = 16 * 1024 * 1024 * 1024;
    $main::swap_memory = 2 * 1024 * 1024 * 1024;
    $main::architecture = 64;
    $main::doremote = 0;
}

# Test Task 4: table_open_cache_instances
subtest 'table_open_cache_instances recommendation' => sub {
    reset_state();
    
    no warnings 'redefine';
    local *main::logical_cpu_cores = sub { return 8 };
    local *main::select_one = sub { 
        my $q = shift;
        return 100 if $q =~ /COUNT\(\*\)/;
        return 0;
    };

    main::mysql_stats();
    
    ok(grep(/table_open_cache_instances \(=\s*4\)/, @main::adjvars), 'Suggested 4 instances for 8 CPU cores');
    
    reset_state();
    $main::mycalc{'table_cache_hit_rate'} = 10;
    local *main::logical_cpu_cores = sub { return 64 };
    local *main::select_one = sub { 
        my $q = shift;
        return 100 if $q =~ /COUNT\(\*\)/;
        return 0;
    };
    main::mysql_stats();
    ok(grep(/table_open_cache_instances \(=\s*16\)/, @main::adjvars), 'Suggested max 16 instances for 64 CPU cores');
};

# Test Task 2: Guards against division by zero (AWS Aurora compatibility)
subtest 'Division by zero guards' => sub {
    reset_state();
    
    # Minimal stats that might cause division by zero if not guarded
    $main::mystat{'Questions'} = 100;
    $main::mystat{'Com_select'} = 0;
    $main::mystat{'Qcache_hits'} = 0;
    $main::mystat{'Connections'} = 0; 
    $main::myvar{'max_connections'} = 0; 
    
    no warnings 'redefine';
    local *main::debugprint = sub { };
    local *main::is_int = sub { return defined($_[0]) && $_[0] =~ /^-?\d+$/ };
    local *main::hr_bytes = sub { return $_[0] };
    local *main::human_size = sub { return $_[0] };
    local *main::percentage = sub { return 0 };
    local *main::get_pf_memory = sub { return 0 };
    local *main::get_gcache_memory = sub { return 0 };
    local *main::select_one = sub { return 0 };
    local *main::mysql_cloud_discovery = sub { return "none" };
    local *main::is_remote = sub { return 0 };

    eval { main::calculations(); };
    ok(!$@, 'calculations() did not crash with zero stats') or diag("Crashed with: $@");
};

# Test Task 5: $mysqllogin initialization
subtest '$mysqllogin initialization' => sub {
    $main::mysqllogin = undef;
    
    no warnings 'redefine';
    local *main::get_transport_prefix = sub { return 'ssh ...' }; 
    local %main::opt = ( 'user' => 'root', 'pass' => 'secret' ); 
    local *main::is_remote = sub { return 0 };
    
    eval { main::mysql_setup(); };
    ok(defined($main::mysqllogin), '$mysqllogin is defined after mysql_setup');
};

done_testing();
