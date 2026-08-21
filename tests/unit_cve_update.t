#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_cve_update.t
# Description: Validates EOL/CVE Script Consolidation & Multi-Language
#              Normalization (Phase 27 & 30.4).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 5;

# --- Subtest 1: sync_eol_dates.pl Compilation & Syntax ---
subtest 'sync_eol_dates.pl Syntax & Dependency Check' => sub {
    plan tests => 2;

    my $script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'sync_eol_dates.pl' );
    ok( -f $script, "build/sync_eol_dates.pl exists" );

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "build/sync_eol_dates.pl compiles cleanly" );
};

# --- Subtest 2: updateCVElist.pl Syntax & Core Dependency Check ---
subtest 'updateCVElist.pl Syntax & Core Dependency Check' => sub {
    plan tests => 3;

    my $script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'updateCVElist.pl' );
    ok( -f $script, "build/updateCVElist.pl exists" );

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "build/updateCVElist.pl compiles cleanly" );

    open my $fh, '<', $script or die "Cannot open $script: $!\n";
    my @uses;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s*use\s+([A-Za-z0-9_:]+)/ ) {
            my $mod = $1;
            push @uses, $mod unless $mod =~ /^(?:strict|warnings|HTTP::Tiny|JSON::PP|File::Spec|Cwd)$/;
        }
    }
    close $fh;
    is( scalar(@uses), 0, "updateCVElist.pl uses only standard Perl core modules (zero non-core CPAN)" );
};

# --- Subtest 3: get_version.sh Execution & Consistency ---
subtest 'get_version.sh Script Execution' => sub {
    plan tests => 3;

    my $script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'get_version.sh' );
    ok( -f $script && -x $script, "build/get_version.sh exists and is executable" );

    my $version_out = `"$script" 2>&1`;
    $version_out =~ s/^\s+|\s+$//g;
    like( $version_out, qr/^\d+\.\d+\.\d+$/, "get_version.sh returns semantic version string: $version_out" );

    my $ver_file = File::Spec->catfile( $FindBin::Bin, '..', 'CURRENT_VERSION.txt' );
    open my $fh, '<', $ver_file or die "Cannot open $ver_file: $!\n";
    my $expected = <$fh>;
    close $fh;
    $expected =~ s/^\s+|\s+$//g;

    is( $version_out, $expected, "get_version.sh output matches CURRENT_VERSION.txt" );
};

# --- Subtest 4: Orphan Files Elimination Verification ---
subtest 'Orphan Files Elimination Verification' => sub {
    plan tests => 5;

    my $root = File::Spec->catdir( $FindBin::Bin, '..' );
    ok( !-f File::Spec->catfile( $root, 'JenkinsFile' ), "JenkinsFile removed" );
    ok( !-f File::Spec->catfile( $root, 'build', 'updateCVElist.py' ), "build/updateCVElist.py removed" );
    ok( !-f File::Spec->catfile( $root, 'build', 'endoflife.sh' ), "build/endoflife.sh removed" );
    ok( !-f File::Spec->catfile( $root, 'build', 'genFeatures.sh' ), "build/genFeatures.sh removed" );
    ok( !-f File::Spec->catfile( $root, 'build', 'release_gen.py' ), "build/release_gen.py removed" );
};

# --- Subtest 5: Zero-Dependency Policy on sync_eol_dates.pl ---
subtest 'Zero-Dependency Policy on sync_eol_dates.pl' => sub {
    plan tests => 1;

    my $script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'sync_eol_dates.pl' );
    open my $fh, '<', $script or die "Cannot open $script: $!\n";
    my @uses;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s*use\s+([A-Za-z0-9_:]+)/ ) {
            my $mod = $1;
            push @uses, $mod unless $mod =~ /^(?:strict|warnings|HTTP::Tiny|JSON::PP|File::Basename|File::Spec|Getopt::Long|Time::Piece)$/;
        }
    }
    close $fh;
    is( scalar(@uses), 0, "sync_eol_dates.pl uses only standard Perl core modules" );
};

done_testing();
