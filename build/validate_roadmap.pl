#!/usr/bin/env perl
# ===========================================================================
# Script:      build/validate_roadmap.pl
# Description: Structured Roadmap Schema Validator in Pure Perl.
#              Validates phase headers, statuses, checkbox syntax, and
#              verifies that all linked specification files exist.
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
use File::Spec;
use Cwd qw(getcwd);

my $PROJECT_ROOT = getcwd();
my $ROADMAP_FILE = File::Spec->catfile( $PROJECT_ROOT, 'ROADMAP.md' );

if ( !-e $ROADMAP_FILE ) {
    print STDERR "ERROR: ROADMAP.md not found at $ROADMAP_FILE\n";
    exit 1;
}

open my $fh, '<', $ROADMAP_FILE or die "Cannot open $ROADMAP_FILE: $!\n";
my $line_no = 0;
my $errors  = 0;
my $phases_count = 0;
my $completed_count = 0;
my $in_progress_count = 0;
my $not_started_count = 0;
my $tasks_count = 0;
my $checked_tasks = 0;

print "Auditing ROADMAP.md structure and link integrity...\n";

while ( my $line = <$fh> ) {
    $line_no++;
    chomp $line;

    # 1. Validate Phase Headers
    if ( $line =~ /^###\s+/ ) {
        if ( $line =~ /^###\s+(?:\[?Phase\s+(\d+):?\s*[^\]\n]+\](?:\([^)]+\))?|Phase\s+(\d+):?\s*[^\[\n]+)\s*(\[(?:COMPLETED|IN PROGRESS|NOT STARTED)\])/i ) {
            my $phase_num = $1 // $2;
            my $status    = uc($3);
            $phases_count++;
            if ( $status eq '[COMPLETED]' ) {
                $completed_count++;
            }
            elsif ( $status eq '[IN PROGRESS]' ) {
                $in_progress_count++;
            }
            elsif ( $status eq '[NOT STARTED]' ) {
                $not_started_count++;
            }
        }
        elsif ( $line =~ /^###\s+Phase/ ) {
            print STDERR "ERROR [Line $line_no]: Invalid Phase header format or missing status tag: '$line'\n";
            $errors++;
        }
    }

    # 2. Validate Checkbox Syntax
    if ( $line =~ /^\s*\*\s*\[(.)\]/ ) {
        my $mark = $1;
        $tasks_count++;
        if ( $mark eq 'x' || $mark eq 'X' ) {
            $checked_tasks++;
        }
        elsif ( $mark ne ' ' ) {
            print STDERR "ERROR [Line $line_no]: Invalid checkbox marker '[$mark]': '$line'\n";
            $errors++;
        }
    }

    # 3. Validate Internal Hyperlinks
    while ( $line =~ /\[([^\]]+)\]\(([^)]+)\)/g ) {
        my $link_text = $1;
        my $url       = $2;

        # Only audit local relative file links or file:/// URLs
        if ( $url =~ /^(?:file:\/\/\/|\/)?(documentation\/[a-zA-Z0-9_\-\.\/]+)$/ ) {
            my $rel_path = $1;
            my $full_path = File::Spec->catfile( $PROJECT_ROOT, $rel_path );
            if ( !-e $full_path ) {
                print STDERR "ERROR [Line $line_no]: Broken specification link '$url' -> '$rel_path' does not exist!\n";
                $errors++;
            }
        }
    }
}
close $fh;

print "\n--- ROADMAP.md Audit Summary ---\n";
print "Total Phases Detected   : $phases_count\n";
print "  - Completed           : $completed_count\n";
print "  - In Progress         : $in_progress_count\n";
print "  - Not Started         : $not_started_count\n";
print "Total Tasks Tracked     : $tasks_count\n";
print "  - Completed Tasks     : $checked_tasks (" . sprintf( "%.1f", ( $checked_tasks * 100 / ( $tasks_count || 1 ) ) ) . "%)\n";
print "Total Lint Errors       : $errors\n";

if ( $errors > 0 ) {
    print STDERR "\n[FAIL] ROADMAP.md validation failed with $errors errors.\n";
    exit 1;
}

print "\n[OK] ROADMAP.md schema and link integrity validation passed cleanly.\n";
exit 0;
