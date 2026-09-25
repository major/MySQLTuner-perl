#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_innodb_ahi.t
# Description: Validates InnoDB Adaptive Hash Index (AHI) & Memory Partitions (Phase 32).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 4;

my $script = File::Spec->catfile( $FindBin::Bin, '..', 'mysqltuner.pl' );
require $script;

# --- Subtest 1: Disabled AHI Baseline ---
subtest 'AHI Disabled Baseline' => sub {
    plan tests => 2;

    my @findings_off = main::audit_innodb_ahi( 'OFF', 100, 100000, 1, 8 );
    is( scalar(@findings_off), 0, "Disabled AHI (OFF) triggers no warnings" );

    my @findings_zero = main::audit_innodb_ahi( 0, 100, 100000, 1, 8 );
    is( scalar(@findings_zero), 0, "Disabled AHI (0) triggers no warnings" );
};

# --- Subtest 2: High Hit Ratio & Partitioned Baseline ---
subtest 'High Hit Ratio Baseline' => sub {
    plan tests => 1;

    # 80,000 AHI searches out of 100,000 total = 80% hit ratio with 8 parts
    my @findings = main::audit_innodb_ahi( 'ON', 80000, 20000, 8, 8 );
    is( scalar(@findings), 0, "High search hit ratio (80%) triggers no warning" );
};

# --- Subtest 3: Low Hit Ratio & Partition Contention ---
subtest 'Low Hit Ratio & Single Partition Contention' => sub {
    plan tests => 4;

    # 5,000 AHI searches out of 100,000 total = 5% hit ratio with 1 part and 4 BP instances
    my @findings = main::audit_innodb_ahi( 'ON', 5000, 95000, 1, 4 );
    is( scalar(@findings), 2, "Detected 2 AHI anomalies" );
    like( $findings[0]->{message}, qr/low search hit ratio/, "Low search hit ratio identified" );
    like( $findings[0]->{recommendation}, qr/disabling innodb_adaptive_hash_index/, "Disable recommendation provided" );
    like( $findings[1]->{message}, qr/innodb_adaptive_hash_index_parts is 1 with 4 buffer pool instances/, "Partition contention identified" );
};

# --- Subtest 4: Script Compilation & Syntax ---
subtest 'Script Compilation & Syntax' => sub {
    plan tests => 1;

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "mysqltuner.pl compiles cleanly" );
};

done_testing();
