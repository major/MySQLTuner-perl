#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;

# Compliance Check: Enforces single-file architecture and zero-dependency rules for mysqltuner.pl.
# Whitelist of allowed Core/Standard modules.
my %ALLOWED_MODULES = map { $_ => 1 } (
    'strict',       'warnings',    'constant',      'vars',
    'utf8',         'POSIX',       'File::Spec',    'File::Temp',
    'Getopt::Long', 'Pod::Usage',  'Sys::Hostname', 'File::Basename',
    'Cwd',          'Time::Local', 'HTTP::Tiny',    'Win32',
    'Time::HiRes',  'Digest::SHA', 'JSON'
);

my $script_path = dirname(__FILE__) . '/../mysqltuner.pl';
open my $fh, '<', $script_path or die "Could not open $script_path: $!";

my $errors = 0;
while ( my $line = <$fh> ) {

    # Stop parsing if we reach the end of the executable code
    last if $line =~ /^__(?:END|DATA)__/;

    # Skip comments
    next if $line =~ /^\s*#/;

    # Extract local file inclusions before stripping strings,
    # but make sure we only flag actual require/do on file paths (strings).
    if ( $line =~ /\b(?:require|do)\s+['"]([^'"]+)['"]/ ) {
        my $target = $1;

    # Only flag if it looks like a local perl file/module path, not generic text
        if ( $target =~ /\.(?:pl|pm)$/ || $target =~ m{^[./]} ) {
            print
              "ERROR: Prohibited local file inclusion found at line $. : $line";
            $errors++;
        }
    }

    # Clean the line by stripping comments and string literals
    my $clean_line = $line;
    $clean_line =~ s/#.*$//;                       # Strip comments
    $clean_line =~ s/'[^'\\]*(?:\\.[^'\\]*)*'//g;  # Strip single-quoted strings
    $clean_line =~ s/"[^"\\]*(?:\\.[^"\\]*)*"//g;  # Strip double-quoted strings

    # Extract use/require statements from the cleaned Perl code
    if ( $clean_line =~ /\b(?:use|require)\s+([\w::]+)/ ) {
        my $module = $1;

        # Skip numeric Perl version requirements (e.g., use 5.005)
        next if $module =~ /^[0-9\._v]+$/;

        if ( !$ALLOWED_MODULES{$module} ) {
            print
"ERROR: Unauthorized dependency '$module' detected at line $. : $line\n";
            $errors++;
        }
    }
}
close $fh;

# Check release notes completeness
my $version_file   = dirname(__FILE__) . '/../CURRENT_VERSION.txt';
my $changelog_file = dirname(__FILE__) . '/../Changelog';
my $releases_dir   = dirname(__FILE__) . '/../releases';

my $version;
if ( open my $v_fh, '<', $version_file ) {
    $version = <$v_fh>;
    close $v_fh;
    if ( defined $version ) {
        $version =~ s/^\s+|\s+$//g;
    }

    if ( $version && open my $c_fh, '<', $changelog_file ) {
        my $in_version_block = 0;
        my @expected_entries;
        while ( my $line = <$c_fh> ) {
            chomp $line;
            if ( $line =~ /^\s*(\d+\.\d+\.\d+)\s+(\d{4}-\d{2}-\d{2})/ ) {
                if ( $1 eq $version ) {
                    $in_version_block = 1;
                }
                else {
                    $in_version_block = 0;
                }
                next;
            }
            if ($in_version_block) {
                if ( $line =~ /^\s*-\s*(fix|feat):(.*)$/ ) {
                    my $entry = $2;
                    $entry =~ s/^\s+|\s+$//g;
                    push @expected_entries, $entry;
                }
            }
        }
        close $c_fh;

        if (@expected_entries) {
            my $release_file = "$releases_dir/v$version.md";
            if ( !-f $release_file ) {
                print
                  "ERROR: Release notes file '$release_file' does not exist.\n";
                $errors++;
            }
            else {
                if ( open my $r_fh, '<', $release_file ) {
                    my $release_content = do { local $/; <$r_fh> };
                    close $r_fh;

                    foreach my $entry (@expected_entries) {

                     # Clean entry for robust comparison (strip trailing period)
                        my $clean_entry = $entry;
                        $clean_entry =~ s/\.$//;

                        my $escaped = quotemeta($clean_entry);
                        if ( $release_content !~ /$escaped/ ) {
                            print
"ERROR: Release notes file '$release_file' is missing the Changelog entry: '$entry'\n";
                            $errors++;
                        }
                    }
                }
                else {
                    print
"ERROR: Could not open release notes file '$release_file': $!\n";
                    $errors++;
                }
            }
        }
    }
}

# Whitelist of allowed scopes for conventional commits
my %ALLOWED_SCOPES = map { $_ => 1 } (
    'ci',       'docs',     'test',         'chore',
    'versions', 'report',   'security',     'cve',
    'options',  'lab',      'container',    'refactor',
    'style',    'releases', 'dependencies', 'cli',
    'auth',     'main',     'metadata'
);

# Lint Changelog structure and scopes for the current version block
if ( $version && open my $c_fh, '<', $changelog_file ) {
    my $line_num         = 0;
    my $in_current_block = 0;
    while ( my $line = <$c_fh> ) {
        $line_num++;
        chomp $line;
        if ( $line =~ /^\s*(\d+\.\d+\.\d+)\s+(\d{4}-\d{2}-\d{2})\s*$/ ) {
            if ( $1 eq $version ) {
                $in_current_block = 1;
            }
            else {
                $in_current_block = 0;
            }
            next;
        }
        if ($in_current_block) {
            next if $line =~ /^\s*$/;

  # It must start with "- type:" where type is one of allowed conventional types
            if ( $line =~ /^\s*-\s*(\w+)(?:\(([^)]+)\))?(!)?:\s*(.*)$/ ) {
                my $type  = $1;
                my $scope = $2;
                if ( defined $scope ) {
                    if ( !$ALLOWED_SCOPES{ lc($scope) } ) {
                        print
"ERROR [Changelog Scope Audit]: Unauthorized scope '$scope' at line $line_num in Changelog\n";
                        $errors++;
                    }
                }
                next;
            }
            print
"ERROR [Changelog Lint]: Malformed line $line_num in Changelog (current version $version block): '$line'\n";
            $errors++;
        }
    }
    close $c_fh;
}

# Audit scopes of git commits since the last release tag
my $prev_tag = `git describe --tags --abbrev=0 2>/dev/null`;
if ( defined $prev_tag && $prev_tag ne '' ) {
    chomp $prev_tag;
    my @commits = `git log $prev_tag..HEAD --pretty=format:%s 2>/dev/null`;
    foreach my $commit (@commits) {
        chomp $commit;
        if ( $commit =~ /^(\w+)(?:\(([^)]+)\))?(!)?:\s*(.*)$/ ) {
            my $type  = $1;
            my $scope = $2;
            if ( defined $scope ) {
                if ( !$ALLOWED_SCOPES{ lc($scope) } ) {
                    print
"ERROR [Commit Scope Audit]: Unauthorized scope '$scope' in commit message: '$commit'\n";
                    $errors++;
                }
            }
        }
    }
}

if ( $errors > 0 ) {
    print "\n[FAIL] Compliance check failed: $errors violations detected.\n";
    exit 1;
}

print
"[OK] Compliance check passed: mysqltuner.pl adheres to single-file and zero-dependency rules, and release notes are complete.\n";
exit 0;

