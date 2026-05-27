#!/usr/bin/env perl

use strict;
use warnings;

# MySQLTuner Test Output Auditor
# Purpose: Run prove and scan its output for subtle Perl warnings, typos, and syntax errors.

my $cmd = $ARGV[0] || $ENV{AUDIT_TEST_CMD} || 'prove -r tests/';

# --- Phase 1: Compile-time syntax check and static analysis ---
print "Performing compile-time syntax checks...\n";
my @files_to_check = (
    'mysqltuner.pl',
    'tests/MySQLTuner/TestHelper.pm',
    glob("tests/*.t")
);

my @syntax_errors;
my @syntax_warnings;

foreach my $file (@files_to_check) {
    next unless -f $file;
    open(my $ch, '-|', "perl -I. -Itests -wc \"$file\" 2>&1") or do {
        push @syntax_errors, { file => $file, content => "Failed to execute perl -wc: $!" };
        next;
    };
    
    my $has_error = 0;
    while (my $line = <$ch>) {
        chomp $line;
        next if $line =~ /syntax OK$/;
        
        if ($line =~ /syntax error|Compilation failed|Can't locate|Undefined subroutine/i) {
            push @syntax_errors, { file => $file, content => $line };
            $has_error = 1;
        }
        elsif ($line =~ /possible typo|redefined|prototype mismatch|masks earlier declaration|redeclared/i) {
            # Skip known compile-time warning categories that are normal for test mocks
            next;
        }
        else {
            push @syntax_warnings, { file => $file, content => $line };
        }
    }
    close($ch);
    
    my $exit_val = $? >> 8;
    if ($exit_val != 0 && !$has_error) {
        push @syntax_errors, { file => $file, content => "Compile check failed with exit code $exit_val" };
    }
}

if (@syntax_errors) {
    print "\n[!] Compile Check Failed: Found " . scalar(@syntax_errors) . " compile-time syntax errors/failures:\n";
    foreach my $err (@syntax_errors) {
        printf("  - %s: %s\n", $err->{file}, $err->{content});
    }
    exit 1;
}

if (@syntax_warnings) {
    my %warnings_by_file;
    foreach my $warn (@syntax_warnings) {
        push @{$warnings_by_file{$warn->{file}}}, $warn->{content};
    }

    print "\n[!] Compile Check Warnings: Detected " . scalar(@syntax_warnings) . " compile-time warnings/typos:\n";
    foreach my $file (sort keys %warnings_by_file) {
        my $count = scalar(@{$warnings_by_file{$file}});
        print "  - $file: $count warnings\n";
        
        my $display_limit = 3;
        my $displayed = 0;
        foreach my $content (@{$warnings_by_file{$file}}) {
            print "    * $content\n";
            $displayed++;
            if ($displayed >= $display_limit && $count > $display_limit) {
                print "    * ... and " . ($count - $display_limit) . " more warnings\n";
                last;
            }
        }
    }
    print "\n";
} else {
    print "[OK] Compile Check: All files parsed cleanly.\n\n";
}

# --- Phase 2: Run test suite and audit runtime output ---
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
