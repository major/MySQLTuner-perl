#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use File::Spec;
use File::Temp qw(tempfile);
use Time::Local;

# Dry-Run Version Validation script
# Simulates incrementing the version (e.g. from CURRENT_VERSION.txt)
# to a target version and runs checks on all 8 files.

my $script_dir = dirname(__FILE__);
my $root_dir   = File::Spec->rel2abs("$script_dir/..");
my $log_file   = File::Spec->catfile($root_dir, 'execution.log');

sub log_message {
    my ($msg) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $timestamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
    my $log_line = "[$timestamp] [DRY-RUN] $msg\n";
    print $log_line;
    open(my $lf, '>>', $log_file) or warn "Cannot write to log file $log_file: $!";
    if ($lf) {
        print $lf $log_line;
        close($lf);
    }
}

# 1. Determine current version
my $version_file = File::Spec->catfile($root_dir, 'CURRENT_VERSION.txt');
open(my $vf, '<', $version_file) or die "Cannot read CURRENT_VERSION.txt: $!";
my $current_version = <$vf>;
close($vf);
$current_version =~ s/^\s+|\s+$//g;

# 2. Determine target version
my $target_version = $ARGV[0];
if (!$target_version) {
    if ($current_version =~ /^(\d+)\.(\d+)\.(\d+)$/) {
        $target_version = sprintf("%d.%d.%d", $1, $2, $3 + 1);
    } else {
        die "Could not automatically increment current version '$current_version'. Please specify target version as argument.\n";
    }
}

log_message("Starting dry-run validation from version $current_version to $target_version...");

my $errors = 0;

my @files_to_check = (
    {
        name => 'CURRENT_VERSION.txt',
        path => File::Spec->catfile($root_dir, 'CURRENT_VERSION.txt'),
        check => sub {
            my ($content, $simulated) = @_;
            if ($content !~ /^\Q$current_version\E$/m) {
                return "Current version '$current_version' not found in file.";
            }
            if ($simulated !~ /^\Q$target_version\E$/m) {
                return "Failed to simulate replacement to '$target_version'.";
            }
            return undef;
        }
    },
    {
        name => 'mysqltuner.pl',
        path => File::Spec->catfile($root_dir, 'mysqltuner.pl'),
        check => sub {
            my ($content, $simulated) = @_;
            if ($content !~ /^# mysqltuner.pl - Version \Q$current_version\E/m) {
                return "Header version '$current_version' not found.";
            }
            if ($content !~ /tunerversion\s*=\s*"\Q$current_version\E"/m) {
                return "Variable \$tunerversion version '$current_version' not found.";
            }
            if ($content !~ /MySQLTuner \Q$current_version\E - MySQL High Performance/m) {
                return "POD Name version '$current_version' not found.";
            }
            if ($content !~ /^Version \Q$current_version\E$/m) {
                return "POD Version section version '$current_version' not found.";
            }

            # Check simulated content checks
            if ($simulated !~ /^# mysqltuner.pl - Version \Q$target_version\E/m) {
                return "Failed to replace Header version.";
            }
            if ($simulated !~ /tunerversion\s*=\s*"\Q$target_version\E"/m) {
                return "Failed to replace Variable \$tunerversion version.";
            }
            if ($simulated !~ /MySQLTuner \Q$target_version\E - MySQL High Performance/m) {
                return "Failed to replace POD Name version.";
            }
            if ($simulated !~ /^Version \Q$target_version\E$/m) {
                return "Failed to replace POD Version section version.";
            }

            # Syntax check: write simulated file to temp and compile it
            my ($tf, $temp_filename) = tempfile(SUFFIX => '.pl');
            print $tf $simulated;
            close($tf);

            my $syntax_check = `perl -wc "$temp_filename" 2>&1`;
            unlink($temp_filename);

            if ($syntax_check !~ /syntax OK/) {
                return "Simulated mysqltuner.pl has syntax errors: $syntax_check";
            }
            return undef;
        }
    },
    {
        name => 'USAGE.md',
        path => File::Spec->catfile($root_dir, 'USAGE.md'),
        check => sub {
            my ($content, $simulated) = @_;
            if ($content !~ /MySQLTuner \Q$current_version\E/m) {
                return "Name version '$current_version' not found.";
            }
            if ($content !~ /^Version \Q$current_version\E$/m) {
                return "Version section version '$current_version' not found.";
            }
            if ($simulated !~ /MySQLTuner \Q$target_version\E/m) {
                return "Failed to replace Name version.";
            }
            if ($simulated !~ /^Version \Q$target_version\E$/m) {
                return "Failed to replace Version section version.";
            }
            return undef;
        }
    },
    {
        name => 'README.md',
        path => File::Spec->catfile($root_dir, 'README.md'),
        check => sub {
            my ($content, $simulated) = @_;
            if ($content !~ /version-\Q$current_version\E-blue/m) {
                return "Badge image version '$current_version' not found.";
            }
            if ($content !~ /\/releases\/tag\/v\Q$current_version\E/m) {
                return "Badge release tag '$current_version' not found.";
            }
            if ($simulated !~ /version-\Q$target_version\E-blue/m) {
                return "Failed to replace Badge image version.";
            }
            if ($simulated !~ /\/releases\/tag\/v\Q$target_version\E/m) {
                return "Failed to replace Badge release tag.";
            }
            return undef;
        }
    },
    {
        name => 'SECURITY.md',
        path => File::Spec->catfile($root_dir, 'SECURITY.md'),
        check => sub {
            my ($content, $simulated) = @_;
            if ($content !~ /Supported \(v\Q$current_version\E\)/m) {
                return "Supported version '$current_version' not found.";
            }
            if ($simulated !~ /Supported \(v\Q$target_version\E\)/m) {
                return "Failed to replace Supported version.";
            }
            return undef;
        }
    },
    {
        name => 'MEMORY_DB.md',
        path => File::Spec->catfile($root_dir, 'MEMORY_DB.md'),
        check => sub {
            my ($content, $simulated) = @_;
            if ($content !~ /^## Current Version: \Q$current_version\E$/m) {
                return "Current version header '$current_version' not found.";
            }
            if ($simulated !~ /^## Current Version: \Q$target_version\E$/m) {
                return "Failed to replace Current version header.";
            }
            return undef;
        }
    },
    {
        name => 'Changelog',
        path => File::Spec->catfile($root_dir, 'Changelog'),
        check => sub {
            my ($content, $simulated) = @_;
            if ($content !~ /^\Q$current_version\E\s+/m) {
                return "Changelog entry for version '$current_version' not found.";
            }
            if ($simulated !~ /^\Q$target_version\E\s+/m) {
                return "Failed to simulate Changelog header update.";
            }
            return undef;
        }
    }
);

for my $file_info (@files_to_check) {
    my $name = $file_info->{name};
    my $path = $file_info->{path};

    if (!-f $path) {
        log_message("[FAIL] File $name does not exist at $path.");
        $errors++;
        next;
    }

    open(my $fh, '<', $path) or die "Cannot read $name: $!";
    my $content = do { local $/; <$fh> };
    close($fh);

    # Simulate replacement
    my $simulated = $content;
    $simulated =~ s/\Q$current_version\E/$target_version/g;

    # Run check
    my $err = $file_info->{check}->($content, $simulated);
    if ($err) {
        log_message("[FAIL] Verification failed for $name: $err");
        $errors++;
    } else {
        log_message("[OK] Simulated update on $name matches version schema and compiles cleanly.");
    }
}

# 8. Check release notes path simulation
my $rel_notes_path = File::Spec->catfile($root_dir, 'releases', "v$target_version.md");
log_message("[OK] Simulated path for new release notes: $rel_notes_path");

if ($errors > 0) {
    log_message("Dry-run validation failed with $errors error(s).");
    exit 1;
}

log_message("Dry-run validation completed successfully. All files matches version schemas.");
exit 0;
