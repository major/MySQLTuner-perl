#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;

# Compliance Check: Enforces single-file architecture and zero-dependency rules for mysqltuner.pl.
# Whitelist of allowed Core/Standard modules.
my %ALLOWED_MODULES = map { $_ => 1 } (
    'strict',
    'warnings',
    'constant',
    'vars',
    'utf8',
    'POSIX',
    'File::Spec',
    'File::Temp',
    'Getopt::Long',
    'Pod::Usage',
    'Sys::Hostname',
    'File::Basename',
    'Cwd',
    'Time::Local',
    'HTTP::Tiny',
    'Win32',
    'Time::HiRes',
    'Digest::SHA',
    'JSON'
);

my $script_path = dirname(__FILE__) . '/../mysqltuner.pl';
open my $fh, '<', $script_path or die "Could not open $script_path: $!";

my $errors = 0;
while (my $line = <$fh>) {
    # Stop parsing if we reach the end of the executable code
    last if $line =~ /^__(?:END|DATA)__/;

    # Skip comments
    next if $line =~ /^\s*#/;

    # Extract local file inclusions before stripping strings,
    # but make sure we only flag actual require/do on file paths (strings).
    if ($line =~ /\b(?:require|do)\s+['"]([^'"]+)['"]/) {
        my $target = $1;
        # Only flag if it looks like a local perl file/module path, not generic text
        if ($target =~ /\.(?:pl|pm)$/ || $target =~ m{^[./]}) {
            print "ERROR: Prohibited local file inclusion found at line $. : $line";
            $errors++;
        }
    }

    # Clean the line by stripping comments and string literals
    my $clean_line = $line;
    $clean_line =~ s/#.*$//; # Strip comments
    $clean_line =~ s/'[^'\\]*(?:\\.[^'\\]*)*'//g; # Strip single-quoted strings
    $clean_line =~ s/"[^"\\]*(?:\\.[^"\\]*)*"//g; # Strip double-quoted strings

    # Extract use/require statements from the cleaned Perl code
    if ($clean_line =~ /\b(?:use|require)\s+([\w::]+)/) {
        my $module = $1;
        
        # Skip numeric Perl version requirements (e.g., use 5.005)
        next if $module =~ /^[0-9\._v]+$/;

        if (!$ALLOWED_MODULES{$module}) {
            print "ERROR: Unauthorized dependency '$module' detected at line $. : $line\n";
            $errors++;
        }
    }
}
close $fh;

if ($errors > 0) {
    print "\n[FAIL] Compliance check failed: $errors violations detected.\n";
    exit 1;
}

print "[OK] Compliance check passed: mysqltuner.pl adheres to single-file and zero-dependency rules.\n";
exit 0;
