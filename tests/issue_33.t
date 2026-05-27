#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
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
our %myvar;
our %mystat;
our @generalrec;

subtest 'Issue #33: Skip cert warnings if in inaccessible datadir' => sub {
    no warnings 'redefine';
    
    my @bad_prints;
    my @good_prints;
    my @info_prints;
    
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::is_remote = sub { 0 };
    
    # 1. Case: Certs are in datadir and do not exist / are inaccessible
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = (
        'datadir'  => '/var/lib/mysql/',
        'ssl_cert' => '/var/lib/mysql/server-cert.pem',
        'ssl_ca'   => '/var/lib/mysql/ca.pem',
    );
    local *main::my_file_exists = sub { 0 };
    local *main::my_file_readable = sub { 0 };
    
    @bad_prints = ();
    @good_prints = ();
    @info_prints = ();
    
    main::check_local_certificates();
    
    is(scalar(@bad_prints), 0, "No bad prints when certs are in datadir and inaccessible");
    ok(grep(/file not found or inaccessible in datadir/, @info_prints), "Skipped certificates are logged as info");
    
    # 2. Case: Certs are NOT in datadir and do not exist / are inaccessible
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = (
        'datadir'  => '/var/lib/mysql/',
        'ssl_cert' => '/etc/mysql/server-cert.pem',
        'ssl_ca'   => '/etc/mysql/ca.pem',
    );
    local *main::my_file_exists = sub { 0 };
    local *main::my_file_readable = sub { 0 };
    
    @bad_prints = ();
    @good_prints = ();
    @info_prints = ();
    
    main::check_local_certificates();
    
    is(scalar(@bad_prints), 2, "Bad prints are shown when certs are outside datadir and missing");
    ok(!grep(/inaccessible in datadir/, @info_prints), "No info prints about datadir skip when outside datadir");
};

1;
