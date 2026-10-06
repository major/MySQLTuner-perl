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
use File::Spec;
use Cwd qw(getcwd);

my $PROJECT_ROOT  = getcwd();
my $MYSQLTUNER_PL = File::Spec->catfile( $PROJECT_ROOT, 'mysqltuner.pl' );
my $FEATURES_MD   = File::Spec->catfile( $PROJECT_ROOT, 'FEATURES.md' );

open my $in_fh, '<', $MYSQLTUNER_PL or die "Cannot open $MYSQLTUNER_PL: $!\n";

my @subs;
my $filter_regex = qr/^(?:get_|close_|check_|memerror|cpu_cores|compare_tuner_version|grep_file_contents|update_tuner_version|mysql_version_|calculations|merge_hash|os_setup|pretty_uptime|update_tuner_version|human_size|string2file|file2|arr2|dump|which|percentage|trim|is_|hr_|info|print|select|wrap|remove_)/;

while ( my $line = <$in_fh> ) {
    if ( $line =~ /^sub\s+([a-zA-Z0-9_]+)/ ) {
        my $sub_name = $1;
        next if $sub_name =~ $filter_regex;
        push @subs, $sub_name;
    }
}
close $in_fh;

my @sorted_subs = sort @subs;

open my $out_fh, '>', $FEATURES_MD or die "Cannot open $FEATURES_MD for writing: $!\n";
print $out_fh "Features list for option: --feature (dev only)\n---\n\n";
for my $s (@sorted_subs) {
    print $out_fh "* $s\n";
}
close $out_fh;

print "Generated: $FEATURES_MD\n";

# Print contents to stdout for CLI feedback
if ( open my $rfh, '<', $FEATURES_MD ) {
    while ( my $line = <$rfh> ) {
        print $line;
    }
    close $rfh;
}
