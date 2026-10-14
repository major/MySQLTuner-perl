#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_doc_link_auditor.t
# Description: Validates Documentation Reference Link Auditor (Phase 18.1).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 3;

# --- Subtest 1: Script Existence & Compilation ---
subtest 'Script Compilation & Syntax' => sub {
    plan tests => 2;

    my $linter = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'check_doc_links.pl' );
    ok( -f $linter, "build/check_doc_links.pl exists" );

    my $syntax_check = `perl -c "$linter" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "check_doc_links.pl compiles cleanly" );
};

# --- Subtest 2: 100% Valid Documentation Links ---
subtest 'All Repository Markdown Links Valid' => sub {
    plan tests => 3;

    my $linter = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'check_doc_links.pl' );
    my $out = `perl "$linter" 2>&1`;
    my $exit_code = $? >> 8;

    is( $exit_code, 0, "check_doc_links.pl exits with 0 on clean repository" );
    like( $out, qr/Broken Links\s*:\s*0/, "Zero broken links reported" );
    like( $out, qr/All \d+ reference links in \d+ documentation files are valid/, "Success confirmation present" );
};

# --- Subtest 3: Zero Non-Core Dependencies ---
subtest 'Zero Non-Core Dependencies' => sub {
    plan tests => 1;

    my $linter = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'check_doc_links.pl' );
    open my $fh, '<', $linter or die "Cannot open $linter: $!\n";
    my @uses;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^\s*use\s+([A-Za-z0-9_:]+)/ ) {
            my $mod = $1;
            push @uses, $mod unless $mod =~ /^(?:strict|warnings|File::Find|File::Spec|File::Basename|Cwd)$/;
        }
    }
    close $fh;

    is( scalar(@uses), 0, "check_doc_links.pl uses only core standard Perl modules" );
};

done_testing();
