#!/usr/bin/env perl
# ===========================================================================
# Script:      build/genFeatures.pl
# Description: Generates FEATURES.md by extracting user-facing feature
#              subroutines from mysqltuner.pl in pure Perl.
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
use Getopt::Long;
use File::Spec;
use Cwd qw(getcwd);
use JSON::PP qw(decode_json);

my $PROJECT_ROOT  = getcwd();
my $MYSQLTUNER_PL = File::Spec->catfile( $PROJECT_ROOT, 'mysqltuner.pl' );
my $FEATURES_MD   = File::Spec->catfile( $PROJECT_ROOT, 'FEATURES.md' );

my $output_file;
my $dry_run;

GetOptions(
    'output=s' => \$output_file,
    'dry-run'  => \$dry_run,
) or die "Error in command line arguments\n";

my %seen;
my @subs;

# 1. Primary: Extract features by consuming mysqltuner.pl --list-indicators
my $cmd = "$^X " . File::Spec->catfile( $PROJECT_ROOT, 'mysqltuner.pl' ) . " --list-indicators 2>/dev/null";
my $json_out = `$cmd`;

if ( $json_out && $json_out =~ /^\s*\{/ ) {
    my $data = eval { decode_json($json_out) };
    if ( $data && ref $data eq 'HASH' && ref $data->{features} eq 'ARRAY' ) {
        for my $f ( @{ $data->{features} } ) {
            push @subs, $f unless $seen{$f}++;
        }
    }
}

# 2. Defensive fallback: Parse source file if CLI invocation is unavailable
if ( !@subs && -e $MYSQLTUNER_PL ) {
    open my $in_fh, '<', $MYSQLTUNER_PL or die "Cannot open $MYSQLTUNER_PL: $!\n";
    my $content = do { local $/; <$in_fh> };
    close $in_fh;

    # Extract runnable report subroutines from @REPORT_SECTION_NAMES or @REPORT_SECTIONS
    if ( $content =~ /(?:our|my)\s+\@REPORT_SECTION_NAMES\s*=\s*qw\((.*?)\);/s ) {
        my $block = $1;
        while ( $block =~ /([a-zA-Z0-9_]+)/g ) {
            push @subs, $1 unless $seen{$1}++;
        }
    }
    elsif ( $content =~ /my\s+\@REPORT_SECTIONS\s*=\s*\((.*?)\);/s ) {
        my $block = $1;
        while ( $block =~ /\\&([a-zA-Z0-9_]+)/g ) {
            my $sub_name = $1;
            next if $sub_name =~ /^_/;
            push @subs, $sub_name unless $seen{$sub_name}++;
        }
    }

    # Extract registered audit subroutines
    while ( $content =~ /^sub\s+(audit_[a-zA-Z0-9_]+)\s*\{/mg ) {
        my $sub_name = $1;
        next if $sub_name =~ /^_/;
        push @subs, $sub_name unless $seen{$sub_name}++;
    }

    # Defensive fallback if sections were not found
    if ( !@subs ) {
        my $filter_regex = qr/^(?:_|get_|close_|check_|memerror|cpu_cores|compare_tuner_version|grep_file_contents|update_tuner_version|mysql_version_|calculations|merge_hash|os_setup|pretty_uptime|human_size|string2file|file2|arr2|dump|which|percentage|trim|is_|hr_|info|print|select|wrap|remove_|my_|show_|execute_|sub|bad|good|cmd|debug|header|pretty|red|green|format|parse|clear|log|logical|report|save|stop|compute|display|extract|find)/;
        while ( $content =~ /^sub\s+([a-zA-Z0-9_]+)\s*\{/mg ) {
            my $sub_name = $1;
            next if $sub_name =~ $filter_regex;
            push @subs, $sub_name unless $seen{$sub_name}++;
        }
    }
}

my @sorted_subs = sort @subs;

my $target_file = $output_file || $FEATURES_MD;

if ( !$dry_run ) {
    open my $out_fh, '>', $target_file or die "Cannot open $target_file for writing: $!\n";
    print $out_fh "Features list for option: --feature (dev only)\n---\n\n";
    for my $s (@sorted_subs) {
        print $out_fh "* $s\n";
    }
    close $out_fh;

    print "Generated: $target_file\n";

    # Print contents to stdout for CLI feedback
    if ( open my $rfh, '<', $target_file ) {
        while ( my $line = <$rfh> ) {
            print $line;
        }
        close $rfh;
    }
}
else {
    print "Dry-run: generated features list for option: --feature (dev only)\n";
    for my $s (@sorted_subs) {
        print "* $s\n";
    }
}
