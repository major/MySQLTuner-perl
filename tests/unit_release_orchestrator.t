#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_release_orchestrator.t
# Description: Validates Release Orchestration Engine (Phase 20.1 & 20.2).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 4;

# --- Subtest 1: Script Compilation ---
subtest 'Script Compilation & Syntax' => sub {
    plan tests => 2;

    my $orch = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'release_orchestrator.pl' );
    ok( -f $orch, "build/release_orchestrator.pl exists" );

    my $syntax_check = `perl -c "$orch" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "release_orchestrator.pl compiles cleanly" );
};

# --- Subtest 2: Dry-Run SemVer Bumps ---
subtest 'Dry-Run SemVer Bumps Calculation' => sub {
    plan tests => 4;

    my $orch = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'release_orchestrator.pl' );
    my $ver_file = File::Spec->catfile( $FindBin::Bin, '..', 'CURRENT_VERSION.txt' );
    open my $fh, '<', $ver_file or die "Cannot open $ver_file: $!\n";
    my $curr_ver = <$fh>;
    close $fh;
    chomp($curr_ver);
    my ( $major, $minor, $patch ) = split( /\./, $curr_ver );
    my $expected_micro = join( '.', $major, $minor, $patch + 1 );
    my $expected_minor = join( '.', $major, $minor + 1, 0 );

    my $out_micro = `perl "$orch" --dry-run --bump=micro 2>&1`;
    is( $? >> 8, 0, "Dry-run micro bump exits 0" );
    like( $out_micro, qr/Target Release Version :\s*\Q$expected_micro\E/, "Micro bump calculates $expected_micro" );

    my $out_minor = `perl "$orch" --dry-run --bump=minor 2>&1`;
    is( $? >> 8, 0, "Dry-run minor bump exits 0" );
    like( $out_minor, qr/Target Release Version :\s*\Q$expected_minor\E/, "Minor bump calculates $expected_minor" );
};

# --- Subtest 3: Help Screen Output ---
subtest 'CLI Help Screen' => sub {
    plan tests => 2;

    my $orch = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'release_orchestrator.pl' );
    my $help_out = `perl "$orch" --help 2>&1`;
    is( $? >> 8, 0, "Help command exits 0" );
    like( $help_out, qr/--bump=micro\|minor\|major/, "Help options documented" );
};

# --- Subtest 4: Zero Non-Core Dependencies ---
subtest 'Zero Non-Core Dependencies' => sub {
    plan tests => 1;

    my $orch = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'release_orchestrator.pl' );
    open my $fh, '<', $orch or die "Cannot open $orch: $!\n";
    my @uses;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s*use\s+([A-Za-z0-9_:]+)/ ) {
            my $mod = $1;
            push @uses, $mod unless $mod =~ /^(?:strict|warnings|Getopt::Long|File::Spec|Cwd|POSIX)$/;
        }
    }
    close $fh;

    is( scalar(@uses), 0, "release_orchestrator.pl uses only core standard Perl modules" );
};

done_testing();
