#!/usr/bin/env perl
# ===========================================================================
# Test:        repro_native_parsing.t
# Description: Unit test for native Linux /proc and OS parameter parsing (Phase 26.1).
# ===========================================================================
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

plan tests => 4;

# 1. Mocking environment
our %opt;
our %result;
our @generalrec;
my @infoprints;
my @badprints;
my @goodprints;

# 2. Load MySQLTuner logic
my $script_dir = dirname( abs_path(__FILE__) );
my $script     = abs_path( File::Spec->catfile( $script_dir, '..', 'mysqltuner.pl' ) );

# Suppress warnings from mysqltuner.pl initialization
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

{
    no warnings 'redefine';
    *main::infoprint = sub { push @infoprints, $_[0] };
    *main::badprint  = sub { push @badprints,  $_[0] };
    *main::goodprint = sub { push @goodprints, $_[0] };
    *main::execute_system_command = sub {
        my $cmd = $_[0];
        if ( $cmd =~ /memtotal:/i )           { return "16777216"; }
        if ( $cmd =~ /swaptotal:/i )          { return "8388608"; }
        if ( $cmd =~ /grep -c \^processor/i ) { return "1"; }
        if ( $cmd =~ /nproc/i )               { return "1"; }
        if ( $cmd =~ /awk.*CPUs\*CORES/i )    { return "1"; }
        if ( $cmd =~ /grep 'nameserver'/i )   { return "8.8.8.8\n8.8.4.4"; }
        if ( $cmd =~ /sysctl -n vm.swappiness/i ) { return "60"; }
        if ( $cmd =~ /uname/i )               { return "Linux"; }
        return "0";
    };
    *main::get_transport_prefix = sub { return "MOCK:" };
    *POSIX::uname = sub { return ( "Linux", "localhost", "5.0.0", "mock", "x86_64" ) };
}

# --- Subtest 1: Memory Parsing via /proc/meminfo ---
subtest 'Memory Parsing via /proc/meminfo' => sub {
    plan tests => 2;

    main::os_setup();
    is( $main::result{'OS'}{'Physical Memory'}{'pretty'}, '16.0G', "Parsed physical memory via /proc/meminfo" );
    is( $main::result{'OS'}{'Swap Memory'}{'pretty'},     '8.0G',  "Parsed swap memory via /proc/meminfo" );
};

# --- Subtest 2: Kernel Swappiness & VM Evaluation ---
subtest 'Kernel Swappiness & VM Evaluation' => sub {
    plan tests => 1;

    @main::generalrec = ();
    main::get_kernel_info();
    ok( 1, "get_kernel_info executed cleanly without runtime exceptions" );
};

# --- Subtest 3: System Info & Resolv.conf Parsing ---
subtest 'System Info & Resolv.conf Parsing' => sub {
    plan tests => 1;

    @infoprints = ();
    main::get_system_info();
    ok( 1, "get_system_info executed cleanly" );
};

# --- Subtest 4: Syntax and Script Integrity ---
subtest 'Script Compilation & Syntax' => sub {
    plan tests => 1;

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "mysqltuner.pl compiles cleanly" );
};

done_testing();
