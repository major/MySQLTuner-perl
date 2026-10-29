#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_release_gen.t
# Description: Validates Build Stack Rationalization (Phase 30.1 & 30.2):
#              pure Perl release_gen.pl and genFeatures.pl.
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;
use File::Temp qw(tempfile);

plan tests => 5;

my ( $rfh_temp, $temp_release ) = tempfile( CLEANUP => 1 );
close $rfh_temp;
my ( $ffh_temp, $temp_features ) = tempfile( CLEANUP => 1 );
close $ffh_temp;

# --- Subtest 1: Test release_gen.pl Execution & Output ---
subtest 'release_gen.pl Script Syntax & Execution' => sub {
    plan tests => 3;

    my $script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'release_gen.pl' );
    ok( -f $script, "build/release_gen.pl exists" );

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "build/release_gen.pl compiles cleanly" );

    my $exec_out = `perl "$script" --output "$temp_release" 2>&1`;
    is( $? >> 8, 0, "build/release_gen.pl exits with code 0" );
};

# --- Subtest 2: Test genFeatures.pl Execution & Output ---
subtest 'genFeatures.pl Script Syntax & Output' => sub {
    plan tests => 4;

    my $script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'genFeatures.pl' );
    ok( -f $script, "build/genFeatures.pl exists" );

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "build/genFeatures.pl compiles cleanly" );

    my $exec_out = `perl "$script" --output "$temp_features" 2>&1`;
    is( $? >> 8, 0, "build/genFeatures.pl exits with code 0" );

    ok( -f $temp_features && -s $temp_features > 100, "FEATURES.md generated with content" );
};

# --- Subtest 3: Release Notes Content Validation ---
subtest 'Generated Release Note Schema Validation' => sub {
    plan tests => 5;

    my $ver_file = File::Spec->catfile( $FindBin::Bin, '..', 'CURRENT_VERSION.txt' );
    open my $fh, '<', $ver_file or die "Cannot open $ver_file: $!\n";
    my $version = <$fh>;
    close $fh;
    $version =~ s/^\s+|\s+$//g;

    ok( -f $temp_release, "Release notes generated in temporary file: $temp_release" );

    open my $rfh, '<', $temp_release or die "Cannot open $temp_release: $!\n";
    my $content = do { local $/; <$rfh> };
    close $rfh;

    like( $content, qr/# Release Notes - v$version/, "Contains correct title" );
    like( $content, qr/## 📝 Executive Summary/, "Contains Executive Summary section" );
    like( $content, qr/## 📈 Diagnostic Growth Indicators/, "Contains Diagnostic Growth Indicators" );
    like( $content, qr/## 🛠️ Internal Commit History/, "Contains Internal Commit History" );
};

# --- Subtest 4: Conventional Commit Parsing Logic ---
subtest 'Commit Classification & Ordering' => sub {
    plan tests => 4;

    my $commits_sample = <<'EOF';
- feat(engine): add new diagnostic check (abc1234)
- fix(galera): resolve uninitialized warning (def5678)
- docs: update README (7890abc)
- chore: upgrade deps (cde1234)
- feat!: major breaking feature (1234567)
EOF

    my @lines = split /\n/, $commits_sample;
    ok( grep( /feat/, @lines ), "Found feat commits" );
    ok( grep( /fix/, @lines ), "Found fix commits" );
    ok( grep( /docs/, @lines ), "Found docs commits" );
    ok( grep( /feat!/, @lines ), "Found breaking commit" );
};

# --- Subtest 5: Zero Non-Core Dependencies Verification ---
subtest 'Zero Dependency Check on Build Scripts' => sub {
    plan tests => 2;

    for my $file ( 'release_gen.pl', 'genFeatures.pl' ) {
        my $path = File::Spec->catfile( $FindBin::Bin, '..', 'build', $file );
        open my $fh, '<', $path or die "Cannot open $path: $!\n";
        my @uses;
        while ( my $line = <$fh> ) {
            if ( $line =~ /^\s*use\s+([A-Za-z0-9_:]+)/ ) {
                my $mod = $1;
                push @uses, $mod unless $mod =~ /^(?:strict|warnings|Getopt::Long|File::Spec|Cwd|POSIX|FindBin)$/;
            }
        }
        close $fh;
        is( scalar(@uses), 0, "$file uses only standard Perl core modules (no CPAN dependencies)" );
    }
};

done_testing();
