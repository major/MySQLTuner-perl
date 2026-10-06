#!/usr/bin/env perl
# ===========================================================================
# Script:      build/validate_release.pl
# Description: Unified Pre-Publish and Release Artifact Validator in Pure Perl.
#              Audits critical files, version synchronization across all
#              6 locations, and release notes existence.
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
use File::Spec;
use Cwd qw(getcwd);

my $PROJECT_ROOT = getcwd();
my $errors       = 0;

print "Running Unified Release Pre-Flight Validation...\n";

# 1. Extract Target Version from CURRENT_VERSION.txt
my $version_file = File::Spec->catfile( $PROJECT_ROOT, 'CURRENT_VERSION.txt' );
unless ( -f $version_file ) {
    print STDERR "ERROR: Missing CURRENT_VERSION.txt\n";
    exit 1;
}

open my $vfh, '<', $version_file or die "Cannot open $version_file: $!\n";
my $target_version = <$vfh>;
close $vfh;
chomp $target_version;
$target_version =~ s/^\s+|\s+$//g;

print "Target Release Version: $target_version\n";

# 2. Audit Critical Release Artifacts
my @critical_files = (
    'mysqltuner.pl',
    'CURRENT_VERSION.txt',
    'Changelog',
    "releases/v${target_version}.md",
    'Dockerfile',
    'Makefile',
    'USAGE.md',
    'README.md',
    'ROADMAP.md',
    'build/ci_matrix.json'
);

print "\nAuditing critical file existence:\n";
foreach my $rel_path (@critical_files) {
    my $full_path = File::Spec->catfile( $PROJECT_ROOT, $rel_path );
    if ( -f $full_path && -s $full_path > 0 ) {
        print "  [OK] $rel_path (" . ( -s $full_path ) . " bytes)\n";
    }
    else {
        print STDERR "  [FAIL] Missing or empty critical file: $rel_path\n";
        $errors++;
    }
}

# 3. Audit Version Consistency across reference locations
print "\nAuditing version consistency across reference locations:\n";

# Location 1: mysqltuner.pl header
my $mt_file = File::Spec->catfile( $PROJECT_ROOT, 'mysqltuner.pl' );
open my $mt_fh, '<', $mt_file or die "Cannot open $mt_file: $!\n";
my $header_ver = '';
my $var_ver = '';
my $pod_name_ver = '';
my $pod_sec_ver = '';

while ( my $line = <$mt_fh> ) {
    if ( $line =~ /^# mysqltuner\.pl - Version ([\d\.]+)$/ ) {
        $header_ver = $1;
    }
    elsif ( $line =~ /(?:my|our)\s+\$tunerversion\s+=\s+"([\d\.]+)";/ ) {
        $var_ver = $1;
    }
    elsif ( $line =~ /MySQLTuner ([\d\.]+) - MySQL High Performance/ ) {
        $pod_name_ver = $1;
    }
    elsif ( $line =~ /^Version ([\d\.]+)$/ ) {
        $pod_sec_ver = $1;
    }
}
close $mt_fh;

if ( $header_ver eq $target_version ) {
    print "  [OK] mysqltuner.pl Header version: $header_ver\n";
}
else {
    print STDERR "  [FAIL] mysqltuner.pl Header version ('$header_ver') does not match target ($target_version)\n";
    $errors++;
}

if ( $var_ver eq $target_version ) {
    print "  [OK] mysqltuner.pl \$tunerversion: $var_ver\n";
}
else {
    print STDERR "  [FAIL] mysqltuner.pl \$tunerversion ('$var_ver') does not match target ($target_version)\n";
    $errors++;
}

if ( $pod_name_ver eq $target_version ) {
    print "  [OK] mysqltuner.pl POD Name: $pod_name_ver\n";
}
else {
    print STDERR "  [FAIL] mysqltuner.pl POD Name ('$pod_name_ver') does not match target ($target_version)\n";
    $errors++;
}

if ( $pod_sec_ver eq $target_version ) {
    print "  [OK] mysqltuner.pl POD Version section: $pod_sec_ver\n";
}
else {
    print STDERR "  [FAIL] mysqltuner.pl POD Version section ('$pod_sec_ver') does not match target ($target_version)\n";
    $errors++;
}

# Location 5: Changelog latest version
my $cl_file = File::Spec->catfile( $PROJECT_ROOT, 'Changelog' );
open my $cl_fh, '<', $cl_file or die "Cannot open $cl_file: $!\n";
my $log_ver = '';
while ( my $line = <$cl_fh> ) {
    if ( $line =~ /^([\d\.]+)/ ) {
        $log_ver = $1;
        last;
    }
}
close $cl_fh;

if ( $log_ver eq $target_version ) {
    print "  [OK] Changelog latest release: $log_ver\n";
}
else {
    print STDERR "  [FAIL] Changelog latest release ('$log_ver') does not match target ($target_version)\n";
    $errors++;
}

# Location 6: Release Notes
my $rel_file = File::Spec->catfile( $PROJECT_ROOT, "releases/v${target_version}.md" );
if ( -f $rel_file && -s $rel_file > 0 ) {
    print "  [OK] Release Notes v$target_version: file exists and non-empty (" . ( -s $rel_file ) . " bytes)\n";
}
else {
    print STDERR "  [FAIL] Release Notes file missing or empty: $rel_file\n";
    $errors++;
}

print "\n--- Release Validation Summary ---\n";
print "Total Errors: $errors\n";

if ( $errors > 0 ) {
    print STDERR "\n[FAIL] Release validation failed with $errors errors.\n";
    exit 1;
}

print "\n[OK] Release pre-flight validation passed cleanly for v$target_version.\n";
exit 0;
