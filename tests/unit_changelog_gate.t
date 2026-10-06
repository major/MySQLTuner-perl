#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_changelog_gate.t
# Description: Validates Changelog and Release Artifacts Schema Quality Gate (Phase 19.1 & 19.3).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 3;

# --- Subtest 1: Gate Script Compilation ---
subtest 'Script Compilation & Syntax' => sub {
    plan tests => 2;

    my $gate = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'check_changelog_gate.pl' );
    ok( -f $gate, "build/check_changelog_gate.pl exists" );

    my $syntax_check = `perl -c "$gate" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "check_changelog_gate.pl compiles cleanly" );
};

# --- Subtest 2: Schema Validation on Active Repository ---
subtest 'Active Changelog and Release Notes Schema Verification' => sub {
    plan tests => 3;

    my $gate = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'check_changelog_gate.pl' );
    my $out = `perl "$gate" 2>&1`;
    my $exit_code = $? >> 8;

    is( $exit_code, 0, "check_changelog_gate.pl exits with 0 on clean repository" );
    like( $out, qr/Total Errors:\s*0/, "Zero errors reported" );
    like( $out, qr/validation passed cleanly/, "Confirmation message found in output" );
};

# --- Subtest 3: Zero Non-Core Dependencies ---
subtest 'Zero Non-Core Dependencies' => sub {
    plan tests => 1;

    my $gate = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'check_changelog_gate.pl' );
    open my $fh, '<', $gate or die "Cannot open $gate: $!\n";
    my @uses;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s*use\s+([A-Za-z0-9_:]+)/ ) {
            my $mod = $1;
            push @uses, $mod unless $mod =~ /^(?:strict|warnings|File::Spec|Cwd)$/;
        }
    }
    close $fh;

    is( scalar(@uses), 0, "check_changelog_gate.pl uses only core standard Perl modules" );
};

done_testing();
