#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_table_definition_cache.t
# Description: Validates Table Definition Cache & Open Tables Saturation (Phase 34).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 4;

my $script = File::Spec->catfile( $FindBin::Bin, '..', 'mysqltuner.pl' );
require $script;

# --- Subtest 1: Healthy Low Utilization Baseline ---
subtest 'Healthy Low Utilization Baseline' => sub {
    plan tests => 2;

    # 200 open definitions out of 2000 cache capacity, 500 opened total over 3600s
    my @findings = main::audit_table_definition_cache( 2000, 200, 500, 3600 );
    is( scalar(@findings), 0, "Healthy table definition cache triggers no warnings" );

    my @findings_zero = main::audit_table_definition_cache( 0, 0, 0, 0 );
    is( scalar(@findings_zero), 0, "Zero cache size handled safely" );
};

# --- Subtest 2: Saturated Cache Without Thrashing ---
subtest 'Saturated Cache Low Eviction Rate' => sub {
    plan tests => 1;

    # 1950 open out of 2000 cache (97.5% full), but only 2100 opened definitions over 100,000s (0.02 opened/sec)
    my @findings = main::audit_table_definition_cache( 2000, 1950, 2100, 100000 );
    is( scalar(@findings), 0, "Saturated cache with minimal churn triggers no warning" );
};

# --- Subtest 3: Saturated Cache With Severe Eviction Thrashing ---
subtest 'Saturated Cache & Eviction Thrashing' => sub {
    plan tests => 3;

    # 400 cache, 390 open (97.5%), 50,000 opened over 1,000s (50 opened/sec)
    my @findings = main::audit_table_definition_cache( 400, 390, 50000, 1000 );
    is( scalar(@findings), 1, "Detected table definition cache thrashing" );
    like( $findings[0]->{message}, qr/table_definition_cache is 97\.5% full \(390\/400\) with high eviction rate \(50\.0 opened\/sec\)/, "Message includes fill ratio and eviction rate" );
    like( $findings[0]->{recommendation}, qr/Increase table_definition_cache \(current: 400, suggest >= 2000\)/, "Actionable sizing recommendation provided" );
};

# --- Subtest 4: Script Compilation & Syntax ---
subtest 'Script Compilation & Syntax' => sub {
    plan tests => 1;

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "mysqltuner.pl compiles cleanly" );
};

done_testing();
