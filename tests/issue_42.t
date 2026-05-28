#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
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

subtest 'Issue #42: Plesk Obsidian login-link handling' => sub {
    no warnings 'redefine';
    
    my @bad_prints;
    my @good_prints;
    
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::infoprint = sub { };
    local *main::debugprint = sub { };

    # 1. Mock file readability helper to return true for Plesk shadow file
    local *main::my_file_readable = sub {
        my $file = shift;
        return 1 if $file eq '/etc/psa/.psa.shadow';
        return 0;
    };

    # 2. Mock execute_system_command to return Plesk Obsidian unsupported message
    local *main::execute_system_command = sub {
        my $cmd = shift;
        if ($cmd eq 'cat /etc/psa/.psa.shadow') {
            return "some_shadow_password";
        }
        if ($cmd =~ /mysqladmin.*ping/) {
            return "Access denied"; # Fail connection check to trigger fallback
        }
        if ($cmd =~ /admin --show-password/) {
            return "Option --show-password is no longer supported. Use --get-login-link instead.";
        }
        return "";
    };

    MySQLTuner::TestHelper::reset_state();
    $main::mysqladmincmd = "/usr/bin/mysqladmin";
    $main::mysqlcmd = "/usr/bin/mysql";
    $main::doremote = 0;

    $exit_val = undef;
    @bad_prints = ();
    
    eval {
        main::mysql_setup();
    };
    
    my $err = $@;
    is($err, "MOCK_EXIT\n", "Plesk failure calls exit()");
    is($exit_val, 1, "Exit code must be 1 (failure)");
    ok(grep(/Attempted to use login credentials from Plesk/, @bad_prints), "Plesk failure message is logged");
};

1;
