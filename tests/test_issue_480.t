#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;

# Load MySQLTuner
require './mysqltuner.pl';
require './tests/MySQLTuner/TestHelper.pm';

# Force redefinition of essential subs
no warnings 'redefine';
*main::execute_system_command = sub { return ""; };
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

done_testing();
