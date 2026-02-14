#!/usr/bin/env perl

use strict;
use warnings;
use File::Find;
use Getopt::Long;

# MySQLTuner Audit Log Script
# Purpose: Scan laboratory execution.log files for anomalies and regressions.

my $directory = 'examples';
my $help      = 0;
my $verbose   = 0;

GetOptions(
    'dir=s'   => \$directory,
    'help'    => \$help,
    'verbose' => \$verbose,
) or die("Error in command line arguments\n");

if ($help) {
    print "Usage: $0 [--dir=<directory>] [--verbose] [--help]\n";
    exit 0;
}

my @anomalies;
my $exit_code = 0;

print "Auditing laboratory results in '$directory'...\n";

find(
    sub {
        return unless $_ eq 'execution.log';
        my $file_path = $File::Find::name;
        
        if ($verbose) {
            print "Checking $file_path...\n";
        }

        open my $fh, '<', $_ or do {
            warn "Could not open $file_path: $!";
            return;
        };

        my $line_num = 0;
        while (my $line = <$fh>) {
            $line_num++;
            
            # Anomaly patterns
            if ($line =~ /✘ Performance_schema should be activated[.]/i) {
                push @anomalies, { file => $file_path, line => $line_num, type => 'Performance Schema Disabled', content => $line };
            }
            if ($line =~ /FAIL Execute SQL/i) {
                push @anomalies, { file => $file_path, line => $line_num, type => 'SQL Execution Failure', content => $line };
            }
            if ($line =~ /Syntax error/i || $line =~ /unexpected/i) {
                push @anomalies, { file => $file_path, line => $line_num, type => 'Syntax Anomaly', content => $line };
            }
            if ($line =~ /uninitialized value/i || $line =~ /deprecated/i) {
                push @anomalies, { file => $file_path, line => $line_num, type => 'Perl Warning', content => $line };
            }
        }
        close $fh;
    },
    $directory
);

if (@anomalies) {
    print "\n[!] Found " . scalar(@anomalies) . " anomalies during audit:\n";
    foreach my $anomaly (@anomalies) {
        printf("  - [%s] %s (Line %d)\n", $anomaly->{type}, $anomaly->{file}, $anomaly->{line});
        if ($verbose) {
            print "    Content: $anomaly->{content}";
        }
    }
    $exit_code = 1;
} else {
    print "\n[OK] No anomalies found in laboratory logs.\n";
}

exit $exit_code;
