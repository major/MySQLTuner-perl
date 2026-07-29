#!/usr/bin/env perl
# ===========================================================================
# Script:      analyze_mt_output.pl
# Description: Dedicated MySQLTuner output analyzer for E2E test validation.
#              Detects errors, warnings, missing sections, and HA diagnostics.
# Author:      Jean-Marie Renouard & Antigravity
# Usage:       perl build/analyze_mt_output.pl [--profile <profile.json>] <output_file>
# Exit Codes:  0 = OK, 1 = WARNINGS detected, 2 = ERRORS detected
# ===========================================================================
use strict;
use warnings;
use Getopt::Long;
use JSON;
use File::Basename;

my $profile_file = '';
my $json_output  = 0;
my $quiet        = 0;

GetOptions(
    'profile=s' => \$profile_file,
    'json'      => \$json_output,
    'quiet'     => \$quiet,
) or die "Usage: $0 [--profile <profile.json>] [--json] [--quiet] <output_file>\n";

my $output_file = shift @ARGV
    or die "Usage: $0 [--profile <profile.json>] [--json] [--quiet] <output_file>\n";

die "File not found: $output_file\n" unless -f $output_file;

# Load output content
open my $fh, '<', $output_file or die "Cannot open $output_file: $!\n";
my $content = do { local $/; <$fh> };
close $fh;

# Load profile if provided
my $profile = {};
if ($profile_file && -f $profile_file) {
    open my $pf, '<', $profile_file or die "Cannot open profile $profile_file: $!\n";
    my $json_text = do { local $/; <$pf> };
    close $pf;
    $profile = decode_json($json_text);
}

# Result accumulators
my @errors;
my @warnings;
my @sections_found;
my @sections_missing;
my @diagnostics_found;
my @diagnostics_missing;

# ===================================================================
# Category 1: Perl Warnings
# ===================================================================
my @perl_warnings;
while ($content =~ /^(.*(?:Use of uninitialized value|uninitialized value|deprecated).*)$/gmi) {
    my $line = $1;
    # Skip false positives from MySQLTuner output about DB deprecation
    next if $line =~ /✔|✘|\[OK\]|\[!!?\]|uses DEPRECATED|uses DISABLED|DEPRECATED auth/i;
    push @perl_warnings, $line;
}
if (@perl_warnings) {
    push @errors, {
        category => 'Perl Warnings',
        severity => 'ERROR',
        count    => scalar @perl_warnings,
        details  => [ map { substr($_, 0, 200) } @perl_warnings[0 .. ($#perl_warnings > 4 ? 4 : $#perl_warnings)] ],
    };
}

# ===================================================================
# Category 2: SQL Execution Failures
# ===================================================================
my @sql_failures;
while ($content =~ /^(.*FAIL Execute SQL.*)$/gmi) {
    push @sql_failures, $1;
}
if (@sql_failures) {
    push @errors, {
        category => 'SQL Execution Failures',
        severity => 'ERROR',
        count    => scalar @sql_failures,
        details  => [ map { substr($_, 0, 200) } @sql_failures[0 .. ($#sql_failures > 4 ? 4 : $#sql_failures)] ],
    };
}

# ===================================================================
# Category 3: Transport / Connection Errors
# ===================================================================
my @conn_errors;
while ($content =~ /^(.*(?:Can't connect to|Access denied|Connection refused|timeout|Lost connection).*)$/gmi) {
    push @conn_errors, $1;
}
if (@conn_errors) {
    push @errors, {
        category => 'Transport/Connection Errors',
        severity => 'ERROR',
        count    => scalar @conn_errors,
        details  => [ map { substr($_, 0, 200) } @conn_errors[0 .. ($#conn_errors > 4 ? 4 : $#conn_errors)] ],
    };
}

# ===================================================================
# Category 4: Incomplete Execution
# ===================================================================
unless ($content =~ /Terminated successfully/i) {
    push @errors, {
        category => 'Incomplete Execution',
        severity => 'ERROR',
        count    => 1,
        details  => ['Missing "Terminated successfully" marker in output'],
    };
}

# ===================================================================
# Category 5: Performance Schema Disabled
# ===================================================================
if ($content =~ /Performance_schema should be activated/i) {
    push @warnings, {
        category => 'Performance Schema Disabled',
        severity => 'WARNING',
        count    => 1,
        details  => ['Performance Schema is disabled; some diagnostics may be incomplete'],
    };
}

# ===================================================================
# Category 6: Standard Sections Detection
# ===================================================================
my @standard_sections = (
    'General Statistics',
    'Storage Engine Statistics',
    'Performance Metrics',
    'Security Recommendations',
);

for my $section (@standard_sections) {
    if ($content =~ /\Q$section\E/i) {
        push @sections_found, $section;
    } else {
        push @sections_missing, $section;
    }
}

if (@sections_missing) {
    push @warnings, {
        category => 'Missing Standard Sections',
        severity => 'WARNING',
        count    => scalar @sections_missing,
        details  => \@sections_missing,
    };
}

# ===================================================================
# Category 7: Profile-Based Validation (HA Diagnostics)
# ===================================================================
if ($profile && $profile->{required_sections}) {
    for my $section (@{ $profile->{required_sections} }) {
        if ($content =~ /\Q$section\E/i) {
            push @sections_found, "HA:$section";
        } else {
            push @sections_missing, "HA:$section";
            push @warnings, {
                category => "Missing HA Section: $section",
                severity => 'WARNING',
                count    => 1,
                details  => ["Expected HA section '$section' not found in output for topology '$profile->{topology}'"],
            };
        }
    }
}

if ($profile && $profile->{required_patterns}) {
    for my $pattern (@{ $profile->{required_patterns} }) {
        if ($content =~ /\Q$pattern\E/i) {
            push @diagnostics_found, $pattern;
        } else {
            push @diagnostics_missing, $pattern;
        }
    }
    if (@diagnostics_missing) {
        push @warnings, {
            category => 'Missing HA Diagnostic Patterns',
            severity => 'WARNING',
            count    => scalar @diagnostics_missing,
            details  => \@diagnostics_missing,
        };
    }
}

if ($profile && $profile->{expected_diagnostics}) {
    for my $diag (@{ $profile->{expected_diagnostics} }) {
        if ($content =~ /\Q$diag\E/i) {
            push @diagnostics_found, "expected:$diag";
        }
    }
}

if ($profile && $profile->{forbidden_patterns}) {
    for my $forbidden (@{ $profile->{forbidden_patterns} }) {
        my @matches;
        while ($content =~ /^(.*\Q$forbidden\E.*)$/gmi) {
            push @matches, $1;
        }
        if (@matches) {
            push @errors, {
                category => "Forbidden Pattern: $forbidden",
                severity => 'ERROR',
                count    => scalar @matches,
                details  => [ map { substr($_, 0, 200) } @matches[0 .. ($#matches > 2 ? 2 : $#matches)] ],
            };
        }
    }
}

# ===================================================================
# Category 8: Empty / Silent Output
# ===================================================================
my $line_count = () = $content =~ /\n/g;
if ($line_count < 10) {
    push @warnings, {
        category => 'Suspiciously Short Output',
        severity => 'WARNING',
        count    => 1,
        details  => ["Output contains only $line_count lines, expected >50"],
    };
}

# ===================================================================
# Result Compilation
# ===================================================================
my $exit_code = 0;
$exit_code = 1 if @warnings;
$exit_code = 2 if @errors;

my $result = {
    file                => basename($output_file),
    profile             => $profile->{topology} || 'standalone',
    exit_code           => $exit_code,
    verdict             => $exit_code == 0 ? 'PASS' : ($exit_code == 1 ? 'WARNING' : 'ERROR'),
    error_count         => scalar @errors,
    warning_count       => scalar @warnings,
    errors              => \@errors,
    warnings            => \@warnings,
    sections_found      => \@sections_found,
    sections_missing    => \@sections_missing,
    diagnostics_found   => \@diagnostics_found,
    diagnostics_missing => \@diagnostics_missing,
    output_lines        => $line_count,
};

# ===================================================================
# Output
# ===================================================================
if ($json_output) {
    print encode_json($result) . "\n";
} elsif (!$quiet) {
    my $icon = $exit_code == 0 ? '✅' : ($exit_code == 1 ? '⚠️' : '❌');
    print "=" x 60 . "\n";
    print "$icon MySQLTuner Output Analysis: $result->{verdict}\n";
    print "=" x 60 . "\n";
    printf "  File:       %s\n", $result->{file};
    printf "  Profile:    %s\n", $result->{profile};
    printf "  Lines:      %d\n", $result->{output_lines};
    printf "  Errors:     %d\n", $result->{error_count};
    printf "  Warnings:   %d\n", $result->{warning_count};
    printf "  Sections:   %d found, %d missing\n", scalar @sections_found, scalar @sections_missing;
    printf "  HA Diags:   %d found, %d missing\n", scalar @diagnostics_found, scalar @diagnostics_missing;
    print "-" x 60 . "\n";

    if (@errors) {
        print "\n🔴 ERRORS:\n";
        for my $err (@errors) {
            printf "  [%s] %s (count: %d)\n", $err->{severity}, $err->{category}, $err->{count};
            for my $d (@{ $err->{details} }) {
                printf "    → %s\n", $d;
            }
        }
    }

    if (@warnings) {
        print "\n🟡 WARNINGS:\n";
        for my $w (@warnings) {
            printf "  [%s] %s (count: %d)\n", $w->{severity}, $w->{category}, $w->{count};
            for my $d (@{ $w->{details} }) {
                printf "    → %s\n", $d;
            }
        }
    }

    if (@diagnostics_found) {
        print "\n🟢 HA DIAGNOSTICS FOUND:\n";
        for my $d (@diagnostics_found) {
            printf "    ✔ %s\n", $d;
        }
    }
    print "\n";
}

exit $exit_code;
