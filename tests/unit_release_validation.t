#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_release_validation.t
# Description: Validates Publish Pipeline Unification (Phase 29).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 4;

# --- Subtest 1: Scripts Existence & Syntax ---
subtest 'Script Compilation & Syntax' => sub {
    plan tests => 3;

    my $pl_script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'validate_release.pl' );
    my $sh_script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'validate_release.sh' );

    ok( -f $pl_script, "build/validate_release.pl exists" );
    ok( -f $sh_script, "build/validate_release.sh exists" );

    my $syntax_check = `perl -c "$pl_script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "build/validate_release.pl compiles cleanly" );
};

# --- Subtest 2: Clean Execution against Production Artifacts ---
subtest 'Execution against Production Artifacts' => sub {
    plan tests => 3;

    my $pl_script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'validate_release.pl' );
    my $out = `perl "$pl_script" 2>&1`;
    my $exit_code = $? >> 8;

    is( $exit_code, 0, "validate_release.pl exits with 0 on production repository" );
    like( $out, qr/Release pre-flight validation passed cleanly/, "Success message found in output" );
    like( $out, qr/Total Errors: 0/, "Zero errors reported" );
};

# --- Subtest 3: Zero Non-Core Dependencies ---
subtest 'Zero Non-Core Dependencies' => sub {
    plan tests => 1;

    my $pl_script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'validate_release.pl' );
    open my $fh, '<', $pl_script or die "Cannot open $pl_script: $!\n";
    my @uses;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s*use\s+([A-Za-z0-9_:]+)/ ) {
            my $mod = $1;
            push @uses, $mod unless $mod =~ /^(?:strict|warnings|File::Spec|Cwd)$/;
        }
    }
    close $fh;

    is( scalar(@uses), 0, "validate_release.pl uses only core standard Perl modules" );
};

# --- Subtest 4: Makefile Target Validation ---
subtest 'Makefile validate_release Target' => sub {
    plan tests => 2;

    my $makefile = File::Spec->catfile( $FindBin::Bin, '..', 'Makefile' );
    open my $mfh, '<', $makefile or die "Cannot open $makefile: $!\n";
    my $content = do { local $/; <$mfh> };
    close $mfh;

    like( $content, qr/validate_release:\n\s+perl build\/validate_release\.pl/, "validate_release target present in Makefile" );
    like( $content, qr/WARNING: Local docker_push is deprecated/, "Deprecation notice present in docker_push" );
};

done_testing();
