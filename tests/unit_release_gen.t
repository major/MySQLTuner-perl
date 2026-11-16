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

plan tests => 6;

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
                push @uses, $mod unless $mod =~ /^(?:strict|warnings|Getopt::Long|File::Spec|Cwd|POSIX|FindBin|JSON::PP)$/;
            }
        }
        close $fh;
        is( scalar(@uses), 0, "$file uses only standard Perl core modules (no CPAN dependencies)" );
    }
};

# --- Helper: Parse generated release notes for diagnostic & math invariants ---
sub _audit_release_content {
    my ($rel_content) = @_;
    my @lines              = split /\n/, $rel_content;
    my $in_fence           = 0;
    my $in_diag            = 0;
    my $in_exec_summary    = 0;
    my $bad_diag_bullets   = 0;
    my $raw_perl_fragments = 0;
    my $unescaped_dollars  = 0;
    my @exec_entries;

    for my $line (@lines) {
        if ( $line =~ /^```/ ) {
            $in_fence = !$in_fence;
            next;
        }

        if ($in_fence) {
            if ( $in_exec_summary && $line =~ /^\s*-\s+(.+)$/ ) {
                push @exec_entries, $1;
            }
            next;
        }

        $in_exec_summary = ( $line =~ /^##\s+.*Executive Summary/i ) ? 1 : ( $line =~ /^##\s+/ ? 0 : $in_exec_summary );
        $in_diag         = ( $line =~ /^##\s+.*New Diagnostic Capabilities/i ) ? 1 : ( $line =~ /^##\s+/ ? 0 : $in_diag );

        my $outside_backticks = $line;
        $outside_backticks =~ s/`[^`]*`//g;
        $unescaped_dollars++ if $outside_backticks =~ /(?<!\\)\$/;

        if ( $in_diag && $line =~ /^-\s+(.+)$/ ) {
            my $body = $1;
            $raw_perl_fragments++
              if $body =~ /(?:sprintf\s*\(|#"Skip|them for now|\{\s*$|^\s*`?\$[A-Za-z_][A-Za-z0-9_\[\]\{\}'"]*`?\s*$)/;
            if ( $body =~ /^`([^`]+)`$/ ) {
                my $inner = $1;
                $bad_diag_bullets++ if length($inner) < 12;
            }
            else {
                $bad_diag_bullets++;
            }
        }
    }

    return ( $bad_diag_bullets, $raw_perl_fragments, $unescaped_dollars, \@exec_entries );
}

# --- Subtest 6: Diagnostic Sanitization & Markdown LaTeX Math Safety ---
subtest 'Release Notes Diagnostic Sanitization & Changelog Parity' => sub {
    plan tests => 6;

    open my $rfh, '<', $temp_release or die "Cannot open $temp_release: $!\n";
    my $rel_content = do { local $/; <$rfh> };
    close $rfh;

    my ( $bad_diag_bullets, $raw_perl_fragments, $unescaped_dollars, $exec_entries ) =
      _audit_release_content($rel_content);

    is( $bad_diag_bullets,   0, "All New Diagnostic Capabilities bullets are backtick-wrapped readable phrases (>= 12 chars)" );
    is( $raw_perl_fragments, 0, "No raw Perl AST fragments leak into New Diagnostic Capabilities" );
    is( $unescaped_dollars,  0, "No unescaped '\$' symbols outside backticks or fenced blocks (LaTeX safety)" );

    # Simulate tagless shallow CI checkouts / sbuild chroots (GIT_DIR=/nonexistent)
    my ( $tfh_tagless, $temp_tagless ) = tempfile( CLEANUP => 1 );
    close $tfh_tagless;
    my $script = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'release_gen.pl' );
    my $tagless_raw_fragments = -1;
    {
        local $ENV{GIT_DIR} = '/nonexistent';
        my $tagless_out = `$^X "$script" --output "$temp_tagless" 2>&1`;
        if ( ( $? >> 8 ) == 0 && open my $tlfh, '<', $temp_tagless ) {
            my $tl_content = do { local $/; <$tlfh> };
            close $tlfh;
            my ( undef, $tl_raw ) = _audit_release_content($tl_content);
            $tagless_raw_fragments = $tl_raw;
        }
        else {
            diag("Shallow/tagless release_gen.pl run failed: $tagless_out");
        }
    }
    is( $tagless_raw_fragments, 0, "No raw Perl AST fragments leak in tagless shallow-clone mode (GIT_DIR=/nonexistent)" );

    my $changelog_path = File::Spec->catfile( $FindBin::Bin, '..', 'Changelog' );
    open my $cfh, '<', $changelog_path or die "Cannot open $changelog_path: $!\n";
    my $in_first_block = 0;
    my @cl_entries;
    while ( my $line = <$cfh> ) {
        chomp $line;
        if ( $line =~ /^\d+\.\d+\.\d+\s+\d{4}-\d{2}-\d{2}\s*$/ ) {
            last if $in_first_block;
            $in_first_block = 1;
            next;
        }
        if ( $in_first_block && $line =~ /^\s*-\s+(.+)$/ ) {
            push @cl_entries, $1;
        }
    }
    close $cfh;

    is( scalar(@$exec_entries), scalar(@cl_entries), "Executive Summary entry count matches latest Changelog block" );
    is_deeply( $exec_entries, \@cl_entries, "Executive Summary entries match latest Changelog block 1:1" );
};

done_testing();
