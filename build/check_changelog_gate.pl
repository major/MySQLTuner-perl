#!/usr/bin/env perl
# ===========================================================================
# Script:      build/check_changelog_gate.pl
# Description: Quality Gate for Changelog & Release Artifacts Schema Validation.
#              Audits Conventional Commit types, category ordering, and issue tags.
# Author:      Jean-Marie Renouard / Antigravity
# Dependencies: strict, warnings, File::Spec, Cwd
# Usage:       perl build/check_changelog_gate.pl
# ===========================================================================
use strict;
use warnings;
use File::Spec;
use Cwd qw(getcwd);

my $PROJECT_ROOT = getcwd();
my $errors       = 0;

print "Running Changelog & Release Schema Quality Gate...\n";

# 1. Read Current Version
my $v_file = File::Spec->catfile( $PROJECT_ROOT, 'CURRENT_VERSION.txt' );
open my $vfh, '<', $v_file or die "Cannot open $v_file: $!\n";
my $target_ver = <$vfh>;
close $vfh;
chomp $target_ver;
$target_ver =~ s/^\s+|\s+$//g;

print "Current Target Release: v$target_ver\n";

# Priority weights for category ordering
my %CATEGORY_PRIORITY = (
    'chore'    => 1,
    'feat'     => 2,
    'fix'      => 3,
    'test'     => 4,
    'ci'       => 5,
    'docs'     => 6,
    'perf'     => 7,
    'refactor' => 8,
    'style'    => 9,
);

# 2. Audit Changelog Latest Block
my $cl_file = File::Spec->catfile( $PROJECT_ROOT, 'Changelog' );
open my $clfh, '<', $cl_file or die "Cannot open $cl_file: $!\n";
my $in_current_block = 0;
my @current_entries;
my $cl_line_num = 0;

while ( my $line = <$clfh> ) {
    $cl_line_num++;
    if ( $line =~ /^(\d+\.\d+\.\d+)\s+\d{4}-\d{2}-\d{2}/ ) {
        my $ver = $1;
        if ( $ver eq $target_ver ) {
            $in_current_block = 1;
            next;
        }
        else {
            last if $in_current_block; # Exit after current version block
        }
    }

    if ($in_current_block) {
        if ( $line =~ /^\s*-\s*([a-z]+)(?:\([^\)]+\))?!?:\s*(.+)$/ ) {
            my ( $type, $desc ) = ( $1, $2 );
            push @current_entries, { line => $cl_line_num, type => $type, desc => $desc, raw => $line };
        }
        elsif ( $line =~ /^\s*-\s*(.+)$/ ) {
            print STDERR "  [FAIL] Changelog:$cl_line_num -> Entry does not match Conventional Commit format: $line";
            $errors++;
        }
    }
}
close $clfh;

print "\nAudited " . scalar(@current_entries) . " entries in latest Changelog block (v$target_ver):\n";

my $last_priority = 0;
foreach my $entry (@current_entries) {
    my $type = $entry->{type};
    my $prio = $CATEGORY_PRIORITY{$type} // 99;

    unless ( exists $CATEGORY_PRIORITY{$type} ) {
        print STDERR "  [FAIL] Changelog:$entry->{line} -> Unknown Conventional Commit type '$type'\n";
        $errors++;
    }

    if ( $prio < $last_priority ) {
        print STDERR "  [FAIL] Changelog:$entry->{line} -> Category ordering violation: type '$type' (priority $prio) appears after a lower priority entry (priority $last_priority)\n";
        $errors++;
    }
    $last_priority = $prio;

    # Check for issue reference
    unless ( $entry->{desc} =~ /\(#\d+\)/ ) {
        print STDERR "  [WARN] Changelog:$entry->{line} -> Missing issue reference '(#1234)' in: $entry->{desc}\n";
    }
}

# 3. Audit Release Notes File Existence & Schema
my $rel_file = File::Spec->catfile( $PROJECT_ROOT, 'releases', "v${target_ver}.md" );
if ( -f $rel_file && -s $rel_file > 0 ) {
    open my $rfh, '<', $rel_file or die "Cannot open $rel_file: $!\n";
    my $rel_content = do { local $/; <$rfh> };
    close $rfh;

    if ( $rel_content =~ /##\s*.*?Executive Summary/i ) {
        print "  [OK] Release Notes v$target_ver has Executive Summary section\n";
    }
    else {
        print STDERR "  [FAIL] Release Notes v$target_ver missing '## Executive Summary' section\n";
        $errors++;
    }
}
else {
    print STDERR "  [FAIL] Missing or empty release notes file: $rel_file\n";
    $errors++;
}

print "\n--- Quality Gate Summary ---\n";
print "Total Errors: $errors\n";

if ( $errors > 0 ) {
    print STDERR "\n[FAIL] Changelog and Release Schema Quality Gate failed with $errors errors.\n";
    exit 1;
}

print "\n[OK] Changelog and Release Notes schema validation passed cleanly for v$target_ver.\n";
exit 0;
