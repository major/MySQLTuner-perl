#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';

my $exit_val;
BEGIN {
    *CORE::GLOBAL::exit = sub {
        $exit_val = shift // 0;
        die "MOCK_EXIT\n";
    };
}

use Test::More tests => 1;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Suppress warnings from mysqltuner.pl initialization if any
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;
require './tests/MySQLTuner/TestHelper.pm';

# Mock global variables
our $mysqladmincmd;
our $mysqlcmd;
our $mysqllogin;
our $doremote;
our %opt;

subtest 'Issue #896: Debian maintenance account login' => sub {
    no warnings 'redefine';
    
    my @bad_prints;
    my @good_prints;
    
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::infoprint = sub { };
    local *main::debugprint = sub { };

    # 1. Mock file readability helper to return true for Debian cnf file
    local *main::my_file_readable = sub {
        my $file = shift;
        return 1 if $file eq '/etc/mysql/debian.cnf';
        return 0;
    };

    # 2. Mock execute_system_command to return ping success for debian.cnf
    local *main::execute_system_command = sub {
        my $cmd = shift;
        if ($cmd =~ /debian\.cnf.*ping/) {
            return "mysqld is alive";
        }
        return "";
    };

    MySQLTuner::TestHelper::reset_state();
    $main::mysqladmincmd = "/usr/bin/mysqladmin";
    $main::mysqlcmd = "/usr/bin/mysql";
    $main::doremote = 0;
    $main::opt{'defaults-file'} = '';

    $exit_val = undef;
    @good_prints = ();
    
    my $ret = eval {
        main::mysql_setup();
    };
    
    ok(grep(/Logged in using credentials from Debian maintenance account/, @good_prints), 
       "Logged in with Debian maintenance credentials automatically");
    is($main::mysqllogin, "--defaults-file=/etc/mysql/debian.cnf", 
       "mysqllogin variable is set correctly");
};

1;
