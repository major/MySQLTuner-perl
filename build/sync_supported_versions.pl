#!/usr/bin/env perl
# ===========================================================================
# Script:      build/sync_supported_versions.pl
# Description: Generates the supported versions block used by
#              validate_mysql_version() in mysqltuner.pl from the single
#              source of truth build/ci_matrix.json
#              (lts + legacy_supported => LTS label, short_term => short-term).
#              Use --check to verify synchronization without writing.
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
package SyncSupportedVersions;

use strict;
use warnings;
use JSON::PP;
use File::Basename;
use File::Spec;
use Getopt::Long;

my $BEGIN_MARK = '# BEGIN GENERATED SUPPORTED VERSIONS';
my $END_MARK   = '# END GENERATED SUPPORTED VERSIONS';

# Numeric "major.minor" ordering
sub by_cycle {
    my ( $a_maj, $a_min ) = split( /\./, $a );
    my ( $b_maj, $b_min ) = split( /\./, $b );
    return $a_maj <=> $b_maj || $a_min <=> $b_min;
}

# Build (LTS list, short-term list) from a decoded ci_matrix structure.
sub build_lists {
    my ($matrix) = @_;
    my ( %lts, %short );
    for my $engine (qw(mysql mariadb)) {
        my $e = $matrix->{engines}{$engine} || {};
        $lts{$_}   = 1 for @{ $e->{lts} || [] }, @{ $e->{legacy_supported} || [] };
        $short{$_} = 1 for @{ $e->{short_term} || [] };
    }
    for my $cycle ( keys %lts, keys %short ) {
        die "Invalid cycle '$cycle' in ci_matrix.json (expected major.minor)\n"
          unless $cycle =~ /^\d+\.\d+$/;
    }
    delete $short{$_} for keys %lts;    # LTS wins over short-term
    return ( [ sort by_cycle keys %lts ], [ sort by_cycle keys %short ] );
}

# Render the perltidy-stable Perl block inserted into mysqltuner.pl
sub render_block {
    my ( $lts, $short ) = @_;
    return join( '',
        "$BEGIN_MARK (source: build/ci_matrix.json)\n",
        "# Do not edit by hand: run `perl build/sync_supported_versions.pl`\n",
        "our \@SUPPORTED_LTS_VERSIONS        = qw(@$lts);\n",
        "our \@SUPPORTED_SHORT_TERM_VERSIONS = qw(@$short);\n",
        "\n",
        "$END_MARK\n" );
}

# Replace the generated block in $content; dies if markers are missing.
sub replace_block {
    my ( $content, $block ) = @_;
    my $count = ( $content =~ s/^\Q$BEGIN_MARK\E.*?^\Q$END_MARK\E\n/$block/ms );
    die "Generated block markers not found in mysqltuner.pl\n" unless $count;
    return $content;
}

sub read_file {
    my ($file) = @_;
    open my $fh, '<', $file or die "Cannot read $file: $!\n";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub main {
    my $script_dir  = dirname(__FILE__);
    my $matrix_file = File::Spec->catfile( $script_dir, 'ci_matrix.json' );
    my $tuner_file  = File::Spec->catfile( $script_dir, '..', 'mysqltuner.pl' );
    my $check       = 0;
    GetOptions(
        'check|c'  => \$check,
        'matrix=s' => \$matrix_file,
        'tuner=s'  => \$tuner_file,
    ) or return 2;

    my $matrix = decode_json( read_file($matrix_file) );
    my ( $lts, $short ) = build_lists($matrix);
    my $block   = render_block( $lts, $short );
    my $current = read_file($tuner_file);
    my $updated = replace_block( $current, $block );

    if ( $updated eq $current ) {
        print "[OK] Supported versions block is in sync with ci_matrix.json "
          . "(LTS: @$lts | short-term: @$short)\n";
        return 0;
    }
    if ($check) {
        print "[FAIL] Supported versions block in mysqltuner.pl is out of sync "
          . "with ci_matrix.json. Run: perl build/sync_supported_versions.pl\n";
        return 1;
    }

    my $tmp = "$tuner_file.tmp.$$";
    open my $out, '>', $tmp or die "Cannot write $tmp: $!\n";
    print {$out} $updated;
    close $out or die "Cannot close $tmp: $!\n";
    chmod( ( stat($tuner_file) )[2] & 07777, $tmp );
    rename( $tmp, $tuner_file ) or die "Cannot replace $tuner_file: $!\n";
    print "[OK] mysqltuner.pl supported versions block regenerated "
      . "(LTS: @$lts | short-term: @$short)\n";
    return 0;
}

exit main() unless caller;
1;
