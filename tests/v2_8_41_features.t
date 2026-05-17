#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Load MySQLTuner
require './mysqltuner.pl';
require './tests/MySQLTuner/TestHelper.pm';

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



# Test Task 4: table_open_cache_instances
subtest 'table_open_cache_instances recommendation' => sub {
    MySQLTuner::TestHelper::reset_state();
    
    no warnings 'redefine';
    local *main::logical_cpu_cores = sub { return 8 };
    local *main::select_one = sub { 
        my $q = shift;
        return 100 if $q =~ /COUNT\(\*\)/;
        return 0;
    };

    main::mysql_stats();
    
    ok(grep(/table_open_cache_instances \(=\s*4\)/, @main::adjvars), 'Suggested 4 instances for 8 CPU cores');
    
    MySQLTuner::TestHelper::reset_state();
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
    MySQLTuner::TestHelper::reset_state();
    
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
