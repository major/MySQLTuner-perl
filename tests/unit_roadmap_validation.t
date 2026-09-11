#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_roadmap_validation.t
# Description: Validates Structured Roadmap Automation & Schema Validation (Phase 21).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 4;

# --- Subtest 1: Script Compilation & Syntax Check ---
subtest 'validate_roadmap.pl Compilation' => sub {
    plan tests => 2;

    my $script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'validate_roadmap.pl' );
    ok( -f $script, "build/validate_roadmap.pl exists" );

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "build/validate_roadmap.pl compiles cleanly" );
};

# --- Subtest 2: Clean Execution against ROADMAP.md ---
subtest 'Execution against Production ROADMAP.md' => sub {
    plan tests => 3;

    my $script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'validate_roadmap.pl' );
    my $out = `perl "$script" 2>&1`;
    my $exit_code = $? >> 8;

    is( $exit_code, 0, "validate_roadmap.pl exits with 0" );
    like( $out, qr/ROADMAP\.md schema and link integrity validation passed cleanly/, "Confirmation message found" );
    like( $out, qr/Total Phases Detected\s*:\s*\d+/, "Summary statistics displayed" );
};

# --- Subtest 3: Zero Non-Core Dependencies Check ---
subtest 'Zero Non-Core Dependencies' => sub {
    plan tests => 1;

    my $script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'validate_roadmap.pl' );
    open my $fh, '<', $script or die "Cannot open $script: $!\n";
    my @uses;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s*use\s+([A-Za-z0-9_:]+)/ ) {
            my $mod = $1;
            push @uses, $mod unless $mod =~ /^(?:strict|warnings|File::Spec|Cwd)$/;
        }
    }
    close $fh;
    is( scalar(@uses), 0, "validate_roadmap.pl uses only standard Perl core modules" );
};

# --- Subtest 4: Roadmap Checkbox and Phase Counting Integrity ---
subtest 'Roadmap Metrics Consistency' => sub {
    plan tests => 2;

    my $roadmap_path = File::Spec->catfile( $FindBin::Bin, '..', 'ROADMAP.md' );
    open my $fh, '<', $roadmap_path or die "Cannot open $roadmap_path: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;

    my @completed_phases = ( $content =~ /###\s+(?:\[Phase|Phase)\s+\d+:[^\[\n]+(?:\]\([^)]+\))?\s*\[COMPLETED\]/gi );
    my @all_phases       = ( $content =~ /###\s+(?:\[Phase|Phase)\s+\d+:[^\[\n]+/gi );

    cmp_ok( scalar(@completed_phases), '>=', 20, "At least 20 phases completed in ROADMAP.md" );
    cmp_ok( scalar(@all_phases), '>=', 30, "At least 30 phases tracked in ROADMAP.md" );
};

done_testing();
