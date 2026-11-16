#!/usr/bin/env perl
# ===========================================================================
# Script:      build/check_doc_links.pl
# Description: Reference Link Auditing Pipeline for Markdown Documentation.
#              Audits all internal links across documentation/ and root docs.
# Author:      Jean-Marie Renouard / Antigravity
# Dependencies: strict, warnings, File::Find, File::Spec, File::Basename, Cwd
# Usage:       perl build/check_doc_links.pl
# ===========================================================================
use strict;
use warnings;
use File::Find;
use File::Spec;
use File::Basename;
use Cwd qw(getcwd abs_path);

my $PROJECT_ROOT = abs_path(getcwd());
unless (-f File::Spec->catfile($PROJECT_ROOT, 'mysqltuner.pl')) {
    $PROJECT_ROOT = abs_path(File::Spec->catdir(dirname($0), '..'));
}
my $errors            = 0;
my $links_audited     = 0;
my $files_audited     = 0;
my $invariants_checked = 0;

print "Auditing Documentation Reference Links & Version Invariants...\n";

# --- Part 1: Version Invariants Verification ---
sub audit_version_invariants {
    my $curr_ver_file = File::Spec->catfile($PROJECT_ROOT, 'CURRENT_VERSION.txt');
    unless (-f $curr_ver_file) {
        print STDERR "  [FAIL] Missing CURRENT_VERSION.txt\n";
        $errors++;
        return;
    }
    open my $fh, '<', $curr_ver_file or die $!;
    my $expected_version = <$fh>;
    close $fh;
    $expected_version =~ s/^\s+|\s+$//g;
    print "  [INFO] Target Version from CURRENT_VERSION.txt: '$expected_version'\n";

    # Check 1: SECURITY.md
    my $sec_file = File::Spec->catfile($PROJECT_ROOT, 'SECURITY.md');
    if (-f $sec_file) {
        $invariants_checked++;
        open my $sfh, '<', $sec_file or die $!;
        my $content = do { local $/; <$sfh> };
        close $sfh;
        if ($content =~ /\|\s*v2\.x\s*\|\s*Supported\s*\(([^)]+)\)\s*\|/i) {
            my $found_ver = $1;
            if ($found_ver ne "v$expected_version" && $found_ver ne $expected_version) {
                print STDERR "  [FAIL] SECURITY.md version mismatch: found '$found_ver', expected 'v$expected_version'\n";
                $errors++;
            } else {
                print "  [OK] SECURITY.md matches target version ($found_ver)\n";
            }
        } else {
            print STDERR "  [FAIL] SECURITY.md: Could not parse supported version table\n";
            $errors++;
        }
    }

    # Check 2: MEMORY_DB.md
    my $mem_file = File::Spec->catfile($PROJECT_ROOT, 'MEMORY_DB.md');
    if (-f $mem_file) {
        $invariants_checked++;
        open my $mfh, '<', $mem_file or die $!;
        my $content = do { local $/; <$mfh> };
        close $mfh;
        if ($content =~ /##\s*Current Version:\s*([0-9.]+)/i) {
            my $found_ver = $1;
            if ($found_ver ne $expected_version) {
                print STDERR "  [FAIL] MEMORY_DB.md current version mismatch: found '$found_ver', expected '$expected_version'\n";
                $errors++;
            } else {
                print "  [OK] MEMORY_DB.md matches target version ($found_ver)\n";
            }
        } else {
            print STDERR "  [FAIL] MEMORY_DB.md: Missing '## Current Version: <ver>'\n";
            $errors++;
        }
    }

    # Check 3: mysqltuner.pl
    my $pl_file = File::Spec->catfile($PROJECT_ROOT, 'mysqltuner.pl');
    if (-f $pl_file) {
        $invariants_checked++;
        open my $pfh, '<', $pl_file or die $!;
        my $content = do { local $/; <$pfh> };
        close $pfh;
        if ($content =~ /(?:our|my)\s+\$tunerversion\s*=\s*['"]([^'"]+)['"]/ or $content =~ /(?:our|my)\s+\$VERSION\s*=\s*['"]([^'"]+)['"]/) {
            my $found_ver = $1;
            if ($found_ver ne $expected_version) {
                print STDERR "  [FAIL] mysqltuner.pl version mismatch: found '$found_ver', expected '$expected_version'\n";
                $errors++;
            } else {
                print "  [OK] mysqltuner.pl matches target version ($found_ver)\n";
            }
        } else {
            print STDERR "  [FAIL] mysqltuner.pl: Missing \$tunerversion or \$VERSION\n";
            $errors++;
        }
    }

    # Check 4: README badges
    for my $readme ('README.md', 'README.fr.md', 'README.it.md', 'README.ru.md') {
        my $rf = File::Spec->catfile($PROJECT_ROOT, $readme);
        next unless -f $rf;
        $invariants_checked++;
        open my $rfh, '<', $rf or die $!;
        my $content = do { local $/; <$rfh> };
        close $rfh;
        my $badge_pattern = qr{badge/version-\Q$expected_version\E-blue\.svg};
        if ($content =~ $badge_pattern) {
            print "  [OK] $readme contains version-$expected_version badge\n";
        } else {
            print STDERR "  [FAIL] $readme missing badge/version-$expected_version-blue.svg\n";
            $errors++;
        }
    }

    # Check 5: releases/v<ver>.md
    my $rel_note = File::Spec->catfile($PROJECT_ROOT, 'releases', "v$expected_version.md");
    $invariants_checked++;
    if (-f $rel_note) {
        print "  [OK] Release note exists: releases/v$expected_version.md\n";
    } else {
        print STDERR "  [FAIL] Missing release note: releases/v$expected_version.md\n";
        $errors++;
    }
}

audit_version_invariants();

# --- Part 2: Markdown Link Auditing ---

# Collect all markdown files in root and documentation/
my @md_files;

opendir my $dh, $PROJECT_ROOT or die "Cannot open root: $!\n";
push @md_files, map { File::Spec->catfile( $PROJECT_ROOT, $_ ) }
  grep { -f File::Spec->catfile( $PROJECT_ROOT, $_ ) && /\.md$/ } readdir $dh;
closedir $dh;

my $doc_dir = $ENV{MYSQLTUNER_DOCS_DIR} || File::Spec->catdir( $PROJECT_ROOT, 'documentation' );
if ( -d $doc_dir ) {
    find(
        sub {
            push @md_files, $File::Find::name if -f && /\.md$/;
        },
        $doc_dir
    );
}

my $agent_dir = File::Spec->catdir( $PROJECT_ROOT, '.agent' );
if ( -d $agent_dir ) {
    find(
        sub {
            push @md_files, $File::Find::name if -f && /\.md$/;
        },
        $agent_dir
    );
}

foreach my $file ( sort @md_files ) {
    $files_audited++;
    my $rel_file = File::Spec->abs2rel( $file, $PROJECT_ROOT );
    my $file_dir = dirname($file);

    open my $fh, '<', $file or next;
    my $line_num = 0;
    my $in_code_block = 0;

    while ( my $line = <$fh> ) {
        $line_num++;

        if ( $line =~ /^\s*```/ ) {
            $in_code_block = !$in_code_block;
            next;
        }
        next if $in_code_block;

        while ( $line =~ /\[([^\]]+)\]\(([^)]+)\)/g ) {
            my ( $text, $link ) = ( $1, $2 );
            $links_audited++;

            # Malformed git URL check
            if ($link =~ m{https?://[^\s)]+/\.git(?:/|\b)}i) {
                print STDERR "  [FAIL] $rel_file:$line_num -> Malformed git URL with '/.git': '$link'\n";
                $errors++;
                next;
            }

            # Email mailto scheme check
            if ($link =~ /@/ && $link !~ /^mailto:/i && $link !~ /^https?:\/\//i) {
                print STDERR "  [FAIL] $rel_file:$line_num -> Email link missing mailto: scheme: '$link'\n";
                $errors++;
                next;
            }

            # Validated mailto format
            if ($link =~ /^mailto:(.*)$/i) {
                my $email = $1;
                if ($email !~ /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/) {
                    print STDERR "  [FAIL] $rel_file:$line_num -> Invalid email address in mailto: '$link'\n";
                    $errors++;
                }
                next;
            }

            # Skip web URLs and pure anchors
            next if $link =~ /^(?:https?:\/\/|http:|https:|#)/i;
            next if $link =~ /^\/?brain\//;
            next if $link =~ /^(?:path|file:\/\/\/path)/; # Example patterns in documentation

            # Clean target link
            my $clean_link = $link;
            $clean_link =~ s{^file:\/\/\/MySQLTuner-perl\/}{\/};
            $clean_link =~ s{^file:\/\/MySQLTuner-perl\/}{\/};
            $clean_link =~ s{^\/MySQLTuner-perl\/}{\/};
            $clean_link =~ s/^file:\/\///;    # Strip file:// prefix
            $clean_link =~ s/#.*$//;          # Strip anchors

            next if $clean_link eq '';        # Was just an anchor

            my $target_path;
            if ( $clean_link =~ /^\// ) {
                # Root-relative path inside project
                $target_path = File::Spec->catfile( $PROJECT_ROOT, substr( $clean_link, 1 ) );
            }
            else {
                # Relative to current document
                $target_path = File::Spec->rel2abs( $clean_link, $file_dir );
            }

            unless ( -e $target_path ) {
                # Check if it was an absolute filesystem link with MySQLTuner-perl
                if ( $clean_link =~ /MySQLTuner-perl\/(.+)$/ ) {
                    my $alt_path = File::Spec->catfile( $PROJECT_ROOT, $1 );
                    next if -e $alt_path;
                }

                # Check if it's an example execution log that might have been pruned
                next if $clean_link =~ /examples\/\d+_\w+\//;

                print STDERR "  [FAIL] $rel_file:$line_num -> Dead link '$link' (Target not found: $target_path)\n";
                $errors++;
            }
        }
    }
    close $fh;
}

print "\n--- Reference Link Audit Summary ---\n";
print "Invariants Checked : $invariants_checked\n";
print "Files Audited      : $files_audited\n";
print "Links Audited      : $links_audited\n";
print "Broken Links       : $errors\n";

if ( $errors > 0 ) {
    print STDERR "\n[FAIL] Documentation link audit failed with $errors dead links or invariant violations.\n";
    exit 1;
}

print "\n[OK] All $links_audited reference links in $files_audited documentation files are valid.\n";
exit 0;
