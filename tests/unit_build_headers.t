#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_build_headers.t
# Description: Validates Build Script Header Standardization (Phase 30.3).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 3;

# --- Subtest 1: Header Linter Compilation ---
subtest 'Linter Script Compilation' => sub {
    plan tests => 2;

    my $linter = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'check_build_headers.pl' );
    ok( -f $linter, "build/check_build_headers.pl exists" );

    my $syntax_check = `perl -c "$linter" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "check_build_headers.pl compiles cleanly" );
};

# --- Subtest 2: 100% Header Standardization Across Build Directory ---
subtest 'Header Compliance Check Across All Build Scripts' => sub {
    plan tests => 3;

    my $linter = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'check_build_headers.pl' );
    my $out = `perl "$linter" 2>&1`;
    my $exit_code = $? >> 8;

    is( $exit_code, 0, "check_build_headers.pl returns exit code 0" );
    like( $out, qr/Header Failures :\s*0/, "Zero header failures reported" );
    like( $out, qr/All \d+ build scripts have standardized headers/, "All build scripts verified" );
};

# --- Subtest 3: Zero Non-Core Dependencies ---
subtest 'Zero Non-Core Dependencies' => sub {
    plan tests => 1;

    my $linter = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'check_build_headers.pl' );
    open my $fh, '<', $linter or die "Cannot open $linter: $!\n";
    my @uses;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s*use\s+([A-Za-z0-9_:]+)/ ) {
            my $mod = $1;
            push @uses, $mod unless $mod =~ /^(?:strict|warnings|File::Spec|Cwd)$/;
        }
    }
    close $fh;

    is( scalar(@uses), 0, "check_build_headers.pl uses only core standard Perl modules" );
};

done_testing();
