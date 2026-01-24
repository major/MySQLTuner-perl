#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use Cwd 'abs_path';

# Test for version consistency across the project
# This ensures that ALL version strings are synchronized before release.

my $base_dir = dirname(abs_path(__FILE__)) . "/..";
chdir $base_dir or die "Could not change directory to $base_dir";

# 1. Source of Truth: CURRENT_VERSION.txt
open my $fv, '<', 'CURRENT_VERSION.txt' or die "Missing CURRENT_VERSION.txt";
my $expected = <$fv>;
close $fv;
$expected =~ s/^\s+|\s+$//g;

diag("Expected version: $expected");

# 2. mysqltuner.pl - Header
my $header_ver = "";
open my $fh, '<', 'mysqltuner.pl' or die "Missing mysqltuner.pl";
while (my $line = <$fh>) {
    if ($line =~ /^# mysqltuner.pl - Version ([\d\.]+)$/) {
        $header_ver = $1;
        last;
    }
}
close $fh;
is($header_ver, $expected, "mysqltuner.pl: Header version matches");

# 3. mysqltuner.pl - Internal Variable
my $var_ver = "";
open $fh, '<', 'mysqltuner.pl' or die "Missing mysqltuner.pl";
while (my $line = <$fh>) {
    if ($line =~ /my\s+\$tunerversion\s+=\s+"([\d\.]+)";/) {
        $var_ver = $1;
        last;
    }
}
close $fh;
is($var_ver, $expected, "mysqltuner.pl: Internal \$tunerversion matches");

# 4. mysqltuner.pl - POD Name
my $pod_name_ver = "";
open $fh, '<', 'mysqltuner.pl' or die "Missing mysqltuner.pl";
while (my $line = <$fh>) {
    if ($line =~ /MySQLTuner ([\d\.]+) - MySQL High Performance/) {
        $pod_name_ver = $1;
        last;
    }
}
close $fh;
is($pod_name_ver, $expected, "mysqltuner.pl: POD Name version matches");

# 5. mysqltuner.pl - POD Version Section
my $pod_sec_ver = "";
open $fh, '<', 'mysqltuner.pl' or die "Missing mysqltuner.pl";
while (my $line = <$fh>) {
    if ($line =~ /^Version ([\d\.]+)$/) {
        $pod_sec_ver = $1;
        last;
    }
}
close $fh;
is($pod_sec_ver, $expected, "mysqltuner.pl: POD Version section matches");

# 6. Changelog - Latest Entry
my $log_ver = "";
open my $fl, '<', 'Changelog' or die "Missing Changelog";
my $first_line = <$fl>;
close $fl;
if ($first_line =~ /^([\d\.]+)/) {
    $log_ver = $1;
}
is($log_ver, $expected, "Changelog: Latest version matches");

done_testing();
