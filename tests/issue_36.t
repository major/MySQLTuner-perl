#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';

# We must override exit before loading mysqltuner.pl if we want it to be global
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
our %opt;
our $tunerversion;

subtest 'Issue #36: --updateversion exits early when up-to-date' => sub {
    no warnings 'redefine';
    
    # Mock printer subs to prevent noise
    local *main::badprint = sub { };
    local *main::goodprint = sub { };
    local *main::infoprint = sub { };
    local *main::debugprint = sub { };

    MySQLTuner::TestHelper::reset_state();
    $main::opt{'updateversion'} = 1;
    $main::opt{'checkversion'} = 1;
    
    $exit_val = undef;
    eval {
        main::compare_tuner_version($main::tunerversion);
    };
    
    my $err = $@;
    is($err, "MOCK_EXIT\n", "The script should call exit()");
    is($exit_val, 0, "The exit code must be 0 (clean exit)");
};

1;
