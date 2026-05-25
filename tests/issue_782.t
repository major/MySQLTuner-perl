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

use Test::More tests => 2;
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
our $dummyselect;
our %result;

subtest 'Issue #782: Retry succeeds on 3rd attempt' => sub {
    no warnings 'redefine';
    
    my @bad_prints;
    my @good_prints;
    my @info_prints;
    
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::debugprint = sub { };
    
    # Mock sleep to run immediately
    local *main::sleep = sub { 0 };
    
    # Mock SHOW VARIABLES/SHOW GLOBAL VARIABLES to avoid crash after VERSION check
    local *main::select_array = sub { return () };
    local *main::arr2hash = sub { };

    my $select_calls = 0;
    local *main::select_one = sub {
        my $query = shift;
        if ($query eq "SELECT VERSION()") {
            $select_calls++;
            if ($select_calls < 3) {
                return undef;
            }
            return "8.0.30-MySQL";
        }
        return "";
    };

    MySQLTuner::TestHelper::reset_state();
    $main::dummyselect = undef;

    eval {
        main::get_all_vars();
    };
    
    is($select_calls, 3, "SELECT VERSION() was called 3 times");
    is($main::result{'MySQL Client'}{'Version'}, "8.0.30", "Version correctly parsed and stored");
    
    # Verify retry messages
    ok(grep(/Retrying connection check \(2 attempts left\)/, @info_prints), "Logged first retry");
    ok(grep(/Retrying connection check \(1 attempts left\)/, @info_prints), "Logged second retry");
};

subtest 'Issue #782: Failure after all retries' => sub {
    no warnings 'redefine';
    
    my @bad_prints;
    my @good_prints;
    my @info_prints;
    
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::debugprint = sub { };
    
    local *main::sleep = sub { 0 };

    my $select_calls = 0;
    local *main::select_one = sub {
        my $query = shift;
        if ($query eq "SELECT VERSION()") {
            $select_calls++;
            return "";
        }
        return "";
    };

    MySQLTuner::TestHelper::reset_state();
    $main::dummyselect = undef;
    $exit_val = undef;

    eval {
        main::get_all_vars();
    };
    
    my $err = $@;
    is($err, "MOCK_EXIT\n", "The script should exit upon connection failure");
    is($exit_val, 256, "Exit code must be 256");
    is($select_calls, 3, "Tried 3 times before failing");
    ok(grep(/Failed to connect to the database or insufficient privileges/, @bad_prints), "Error message printed");
};

1;
