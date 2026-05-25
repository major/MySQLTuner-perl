#!/usr/bin/env perl

use strict;
use warnings;

# MySQLTuner Test Output Auditor
# Purpose: Run prove and scan its output for subtle Perl warnings, typos, and syntax errors.

my $cmd = $ARGV[0] || $ENV{AUDIT_TEST_CMD} || 'prove -r tests/';
print "Executing test suite: $cmd\n";

open(my $ph, '-|', "$cmd 2>&1") or die "Failed to execute: $cmd: $!";

my @anomalies;
my @warnings;
my $line_num = 0;

while (my $line = <$ph>) {
    print $line; # Output in real-time
    $line_num++;

    # Scan for Perl warnings and errors
    if ($line =~ /Use of uninitialized value/i) {
        push @warnings, { type => 'Uninitialized Value', content => $line, line => $line_num };
    }
    elsif ($line =~ /possible typo/i && $line !~ /tests\//i) {
        push @warnings, { type => 'Possible Typo', content => $line, line => $line_num };
    }
    elsif ($line =~ /syntax error/i) {
        push @anomalies, { type => 'Syntax Error', content => $line, line => $line_num };
    }
    elsif ($line =~ /Compilation failed/i) {
        push @anomalies, { type => 'Compilation Failure', content => $line, line => $line_num };
    }
    elsif ($line =~ /Can't locate/i) {
        push @anomalies, { type => 'Missing Dependency / Location Error', content => $line, line => $line_num };
    }
    elsif ($line =~ /Can't call method|Can't use/i) {
        push @anomalies, { type => 'Runtime Invocation Error', content => $line, line => $line_num };
    }
    elsif ($line =~ /Undefined subroutine/i) {
        push @anomalies, { type => 'Undefined Subroutine', content => $line, line => $line_num };
    }
    elsif ($line =~ /Bail out!/i) {
        push @anomalies, { type => 'Test Execution Bail Out', content => $line, line => $line_num };
    }
    elsif ($line =~ /died at|died\b/i) {
        push @anomalies, { type => 'Fatal Exception', content => $line, line => $line_num };
    }
    elsif ($line =~ /Modification of a read-only value|Attempt to free unreferenced scalar|divided by zero/i) {
        push @anomalies, { type => 'Perl Runtime Violation', content => $line, line => $line_num };
    }
    elsif ($line =~ /Out of memory/i) {
        push @anomalies, { type => 'Out Of Memory Error', content => $line, line => $line_num };
    }
    elsif ($line =~ /Dubious, test returned/i || $line =~ /Failed test/i) {
        push @anomalies, { type => 'Test Failure', content => $line, line => $line_num };
    }
}
close($ph);

my $exit_code = $? >> 8;

if (@anomalies) {
    print "\n[!] Test Audit Gate: Found " . scalar(@anomalies) . " execution errors/failures:\n";
    foreach my $anomaly (@anomalies) {
        chomp $anomaly->{content};
        printf("  - [%s] %s (Output line %d)\n", $anomaly->{type}, $anomaly->{content}, $anomaly->{line});
    }
    exit 1;
}

if (@warnings) {
    print "\n[!] Test Audit Gate: Detected " . scalar(@warnings) . " warnings/notices:\n";
    # Limit warnings display to top 20 to avoid log bloat
    my $count = 0;
    foreach my $warning (@warnings) {
        chomp $warning->{content};
        printf("  - [%s] %s (Output line %d)\n", $warning->{type}, $warning->{content}, $warning->{line});
        $count++;
        if ($count >= 20) {
            print "  - ... and " . (scalar(@warnings) - 20) . " more warnings.\n";
            last;
        }
    }
}

if ($exit_code != 0) {
    print "\n[!] Test suite failed with exit code: $exit_code\n";
    exit $exit_code;
}

print "\n[OK] Test Audit Gate: No execution errors, typos, or anomalies detected in test output.\n";
exit 0;
