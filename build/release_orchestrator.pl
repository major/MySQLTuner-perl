#!/usr/bin/env perl
# ===========================================================================
# Script:      build/release_orchestrator.pl
# Description: Unified Release Orchestration Engine in Pure Perl.
#              Calculates SemVer bumps, synchronizes all reference locations,
#              generates release notes, and triggers pre-flight validation.
# Author:      Jean-Marie Renouard / Antigravity
# Dependencies: strict, warnings, Getopt::Long, File::Spec, Cwd, POSIX
# Usage:       perl build/release_orchestrator.pl [--bump=micro|minor|major] [--dry-run]
# ===========================================================================
use strict;
use warnings;
use Getopt::Long;
use File::Spec;
use Cwd qw(getcwd abs_path);
use POSIX qw(strftime);

my $PROJECT_ROOT = abs_path(getcwd());

my $bump_type   = 'micro';
my $target_ver  = '';
my $dry_run     = 0;
my $help        = 0;
my $sync_only   = 0;

GetOptions(
    'bump=s'    => \$bump_type,
    'version=s' => \$target_ver,
    'dry-run'   => \$dry_run,
    'sync-only' => \$sync_only,
    'help|h'    => \$help,
) or die "Error in command line arguments\n";

if ($help) {
    print "Usage: perl build/release_orchestrator.pl [options]\n";
    print "Options:\n";
    print "  --bump=micro|minor|major  Calculate SemVer bump (default: micro)\n";
    print "  --version=X.Y.Z           Specify exact target version\n";
    print "  --dry-run                 Simulate release actions without file modifications\n";
    print "  --sync-only               Only regenerate release notes and validate artifacts\n";
    print "  --help, -h                Show this help screen\n";
    exit 0;
}

# 1. Read Current Version from CURRENT_VERSION.txt
my $cur_version_file = File::Spec->catfile( $PROJECT_ROOT, 'CURRENT_VERSION.txt' );
open my $vfh, '<', $cur_version_file or die "Cannot open $cur_version_file: $!\n";
my $current_ver = <$vfh>;
close $vfh;
chomp $current_ver;
$current_ver =~ s/^\s+|\s+$//g;

print "Current Release Version: $current_ver\n";

# 2. Compute New Target Version
unless ($target_ver) {
    if ( $current_ver =~ /^(\d+)\.(\d+)\.(\d+)$/ ) {
        my ( $maj, $min, $mic ) = ( $1, $2, $3 );
        if ( $bump_type eq 'major' ) {
            $maj++;
            $min = 0;
            $mic = 0;
        }
        elsif ( $bump_type eq 'minor' ) {
            $min++;
            $mic = 0;
        }
        elsif ( $bump_type eq 'micro' ) {
            $mic++;
        }
        else {
            die "Unknown bump type '$bump_type'. Allowed: micro, minor, major\n";
        }
        $target_ver = "$maj.$min.$mic";
    }
    else {
        die "Cannot parse current version '$current_ver' as SemVer (X.Y.Z)\n";
    }
}

if ($sync_only) {
    $target_ver = $current_ver;
}

print "Target Release Version : $target_ver" . ( $dry_run ? " [DRY-RUN]" : "" ) . "\n";

if ($dry_run) {
    print "\n[DRY-RUN] Actions that would be executed:\n";
    print "  1. Update CURRENT_VERSION.txt to '$target_ver'\n";
    print "  2. Update mysqltuner.pl header, \$tunerversion, and POD blocks to '$target_ver'\n";
    print "  3. Create releases/v${target_ver}.md\n";
    print "  4. Execute 'perl build/release_gen.pl'\n";
    print "  5. Execute 'perl build/validate_release.pl'\n";
    print "\n[DRY-RUN] Simulation completed successfully.\n";
    exit 0;
}

# 3. Apply updates to reference locations if bumping version
if ( $target_ver ne $current_ver ) {
    print "\nUpdating reference locations to v$target_ver...\n";

    # Update CURRENT_VERSION.txt
    open my $ovh, '>', $cur_version_file or die "Cannot write to $cur_version_file: $!\n";
    print $ovh "$target_ver\n";
    close $ovh;
    print "  [OK] Updated CURRENT_VERSION.txt\n";

    # Update mysqltuner.pl
    my $mt_file = File::Spec->catfile( $PROJECT_ROOT, 'mysqltuner.pl' );
    open my $mtfh, '<', $mt_file or die "Cannot read $mt_file: $!\n";
    my $mt_content = do { local $/; <$mtfh> };
    close $mtfh;

    $mt_content =~ s/(# mysqltuner\.pl - Version )[\d\.]+/${1}$target_ver/;
    $mt_content =~ s/((?:my|our)\s+\$tunerversion\s+=\s+")[\d\.]+(";)/${1}$target_ver${2}/;
    $mt_content =~ s/(MySQLTuner )[\d\.]+( - MySQL High Performance)/${1}$target_ver${2}/;
    $mt_content =~ s/(Version )[\d\.]+/${1}$target_ver/;

    open my $omt_fh, '>', $mt_file or die "Cannot write to $mt_file: $!\n";
    print $omt_fh $mt_content;
    close $omt_fh;
    print "  [OK] Updated mysqltuner.pl\n";
}

# 4. Generate Release Notes
print "\nGenerating release notes via build/release_gen.pl...\n";
system("perl", File::Spec->catfile( $PROJECT_ROOT, 'build', 'release_gen.pl' )) == 0
  or die "Error executing build/release_gen.pl: $!\n";

# 5. Run Unified Pre-Flight Validation
print "\nValidating release artifacts via build/validate_release.pl...\n";
system("perl", File::Spec->catfile( $PROJECT_ROOT, 'build', 'validate_release.pl' )) == 0
  or die "Error executing build/validate_release.pl: $!\n";

print "\n[OK] Release Orchestration completed successfully for v$target_ver.\n";
exit 0;
