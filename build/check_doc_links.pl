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
my $errors       = 0;
my $links_audited = 0;
my $files_audited = 0;

print "Auditing Documentation Reference Links...\n";

# Collect all markdown files in root and documentation/
my @md_files;

opendir my $dh, $PROJECT_ROOT or die "Cannot open root: $!\n";
push @md_files, map { File::Spec->catfile( $PROJECT_ROOT, $_ ) }
  grep { -f File::Spec->catfile( $PROJECT_ROOT, $_ ) && /\.md$/ } readdir $dh;
closedir $dh;

my $doc_dir = File::Spec->catdir( $PROJECT_ROOT, 'documentation' );
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

            # Skip web URLs, mailto, @ emails, and pure in-page anchors
            next if $link =~ /^(?:https?:\/\/|http:|mailto:|#)/i;
            next if $link =~ /@/;
            next if $link =~ /^\/?brain\//;
            next if $link =~ /^(?:path|file:\/\/\/path)/; # Example patterns in documentation

            $links_audited++;

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
print "Files Audited : $files_audited\n";
print "Links Audited : $links_audited\n";
print "Broken Links  : $errors\n";

if ( $errors > 0 ) {
    print STDERR "\n[FAIL] Documentation link audit failed with $errors dead links.\n";
    exit 1;
}

print "\n[OK] All $links_audited reference links in $files_audited documentation files are valid.\n";
exit 0;
