#!/usr/bin/env perl
# ===========================================================================
# Script:      build/check_build_headers.pl
# Description: Static Linter for Build Script Header Standardization.
#              Audits all scripts in build/ to verify metadata headers.
# Author:      Jean-Marie Renouard / Antigravity
# Dependencies: strict, warnings, File::Spec, Cwd
# Usage:       perl build/check_build_headers.pl
# ===========================================================================
use strict;
use warnings;
use File::Spec;
use Cwd qw(getcwd);

my $PROJECT_ROOT = getcwd();
my $BUILD_DIR    = File::Spec->catdir( $PROJECT_ROOT, 'build' );
my $errors       = 0;
my $audited      = 0;

print "Auditing Build Script Headers Standardization...\n";

opendir my $dh, $BUILD_DIR or die "Cannot open directory $BUILD_DIR: $!\n";
my @files = sort grep { -f File::Spec->catfile( $BUILD_DIR, $_ ) && /\.(?:pl|sh)$/ } readdir $dh;
closedir $dh;

foreach my $file (@files) {
    my $full_path = File::Spec->catfile( $BUILD_DIR, $file );
    $audited++;

    open my $fh, '<', $full_path or die "Cannot open $full_path: $!\n";
    my $header_block = "";
    for ( 1 .. 25 ) {
        my $line = <$fh> // '';
        $header_block .= $line;
    }
    close $fh;

    my @missing;
    push @missing, "Description" unless $header_block =~ /(?:Description|Desc)\s*:/i;
    push @missing, "Author"      unless $header_block =~ /(?:Author|Maintainer)\s*:/i;

    if (@missing) {
        print STDERR "  [FAIL] build/$file missing header fields: " . join( ", ", @missing ) . "\n";
        $errors++;
    }
    else {
        print "  [OK] build/$file has compliant header\n";
    }
}

print "\n--- Header Audit Summary ---\n";
print "Scripts Audited : $audited\n";
print "Header Failures : $errors\n";

if ( $errors > 0 ) {
    print STDERR "\n[FAIL] Build header standardization check failed with $errors errors.\n";
    exit 1;
}

print "\n[OK] All $audited build scripts have standardized headers.\n";
exit 0;
