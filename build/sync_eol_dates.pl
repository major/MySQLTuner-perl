#!/usr/bin/env perl
# ===========================================================================
# Script:      build/sync_eol_dates.pl
# Description: EOL Synchronization Audit & Support Markdown Generator
#              in Pure Perl (Core HTTP::Tiny and JSON::PP).
#              --generate       regenerate mysql_support.md / mariadb_support.md
#              --update-matrix  update build/ci_matrix.json (lts, short_term,
#                               supported, all) from the endoflife.date API
#              --check          guard: report ci_matrix.json drift against the
#                               API without writing (exit 1 when outdated)
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
package SyncEolDates;

use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP;
use File::Basename;
use File::Spec;
use Getopt::Long;
use Time::Piece;

my $script_dir = dirname(__FILE__);
my $tuner_file = File::Spec->catfile( $script_dir, '..', 'mysqltuner.pl' );

# Date reference (today's date in YYYY-MM-DD format), set by main()
my $today_str = Time::Piece->new->strftime('%Y-%m-%d');

# Legacy supported versions whitelist (officially EOL but still accepted by the validator).
# Single source of truth: build/ci_matrix.json -> engines.*.legacy_supported
my %LEGACY_SUPPORTED;

# Matrix layout (key order) reproduced by render_matrix_json()
my @TOP_KEYS    = ( '$schema', qw(title description generated_at engines) );
my @ENGINE_KEYS = qw(supported lts short_term legacy_supported legacy ci_default all);

# Numeric "major.minor" ordering (non-numeric parts treated as 0)
sub cycle_cmp {
    my ( $x, $y ) = @_;
    my ( $x_maj, $x_min ) = map { /^(\d+)/ ? $1 : 0 } ( split( /\./, $x // '' ), 0, 0 );
    my ( $y_maj, $y_min ) = map { /^(\d+)/ ? $1 : 0 } ( split( /\./, $y // '' ), 0, 0 );
    return $x_maj <=> $y_maj || $x_min <=> $y_min;
}

# A cycle is active when it has no EOL date or an EOL date after today.
sub is_active_eol {
    my ( $eol, $today ) = @_;
    return 1 if !defined $eol || $eol eq '' || $eol eq '0' || $eol eq 'false' || !$eol;
    return ( $eol gt $today ) ? 1 : 0;
}

# endoflife.date "lts" is a boolean or the date the cycle becomes LTS.
sub is_lts_flag {
    my ( $lts, $today ) = @_;
    return 0 unless defined $lts;
    return 1 if "$lts" =~ /^(?:1|true)$/i;
    return 1 if "$lts" =~ /^\d{4}-\d{2}-\d{2}$/ && $lts le $today;
    return 0;
}

# 1. Fetch EOL cycles from endoflife.date API
sub fetch_product_data {
    my ($product) = @_;
    my $url = "https://endoflife.date/api/$product.json";
    print "Fetching EOL metadata for '$product' from $url...\n";

    my $response = HTTP::Tiny->new( timeout => 15 )->get($url);
    if ( !$response->{success} ) {
        warn "[WARN] Could not retrieve $product metadata: $response->{reason}. Skipping online sync check.\n";
        return ( undef, undef );
    }

    my $data;
    eval { $data = decode_json( $response->{content} ); };
    if ($@) {
        warn "[WARN] Failed to parse JSON response for $product: $@. Skipping online sync check.\n";
        return ( undef, undef );
    }

    my %active_cycles;
    for my $item (@$data) {
        my $cycle = $item->{cycle};
        my $eol   = $item->{eol};
        if ( is_active_eol( $eol, $today_str ) || $LEGACY_SUPPORTED{$cycle} ) {
            $active_cycles{$cycle} = $eol // 'no EOL';
        }
    }
    return ( \%active_cycles, $data );
}

sub generate_support_markdown {
    my ( $product, $data ) = @_;
    return unless $data;

    my $prod_title  = ( $product =~ /^maria/i ) ? 'MariaDB' : 'MySQL';
    my $target_file = File::Spec->catfile( $script_dir, '..', "${product}_support.md" );
    open my $mfh, '>', $target_file or die "Cannot write to $target_file: $!\n";
    print $mfh "# Version Support for $prod_title\n\n";
    print $mfh "> Official lifecycle data sourced dynamically from [endoflife.date/$product](https://endoflife.date/$product).\n";
    print $mfh "> Regenerate via: `perl build/sync_eol_dates.pl --generate`\n\n";
    print $mfh "| Version | End of Support Date | LTS | Status |\n";
    print $mfh "|---------|------------------------|-----|--------|\n";

    # Sort by cycle, newest first
    my @sorted = sort { cycle_cmp( $b->{cycle}, $a->{cycle} ) } @$data;
    for my $item (@sorted) {
        my $cycle = $item->{cycle} // 'N/A';
        my $eol   = $item->{eol};

        # JSON::PP booleans stringify to '1'/'0'
        my $lts = ( defined $item->{lts} && $item->{lts} =~ /^(?:1|true)$/i ) ? 'YES' : 'NO';

        my $status = 'Supported';
        if ( defined $eol && $eol ne '' && $eol ne '0' && $eol ne 'false' ) {
            $status = ( $eol gt $today_str ) ? 'Supported' : 'Outdated';
        }
        my $eol_str = ( defined $eol && $eol ne '' && $eol ne '0' && $eol ne 'false' ) ? $eol : 'N/A';
        print $mfh "| $cycle | $eol_str | $lts | $status |\n";
    }
    close $mfh;
    print "The file ${product}_support.md has been successfully generated.\n";
}

# Pure: render a ci_matrix structure with the repository layout
# (fixed key order, inline arrays, 2-space indentation).
sub render_matrix_json {
    my ($matrix) = @_;
    my $js  = JSON::PP->new->allow_nonref->canonical;
    my $val = sub {
        my ($v) = @_;
        return '[' . join( ', ', map { $js->encode($_) } @$v ) . ']' if ref $v eq 'ARRAY';
        return $js->encode($v);
    };
    my $ordered = sub {
        my ( $h, @known ) = @_;
        my %seen = map { $_ => 1 } @known;
        return ( ( grep { exists $h->{$_} } @known ), ( sort grep { !$seen{$_} } keys %$h ) );
    };

    my @top;
    for my $k ( $ordered->( $matrix, @TOP_KEYS ) ) {
        if ( $k eq 'engines' ) {
            my @eng;
            for my $engine ( $ordered->( $matrix->{engines}, qw(mysql mariadb) ) ) {
                my $e = $matrix->{engines}{$engine};
                my @fields =
                  map { '      ' . $js->encode($_) . ': ' . $val->( $e->{$_} ) }
                  $ordered->( $e, @ENGINE_KEYS );
                push @eng, '    ' . $js->encode($engine) . ": {\n" . join( ",\n", @fields ) . "\n    }";
            }
            push @top, '  "engines": {' . "\n" . join( ",\n", @eng ) . "\n  }";
        }
        else {
            push @top, '  ' . $js->encode($k) . ': ' . $val->( $matrix->{$k} );
        }
    }
    return "{\n" . join( ",\n", @top ) . "\n}\n";
}

# Pure: compute the updated matrix from endoflife.date raw data.
#   $raw = { mysql => [ {cycle, eol, lts}, ... ], mariadb => [...] }
# Active cycles (no EOL or EOL > today) go to lts / short_term, supported = lts,
# all = known cycles plus newly active ones. legacy_supported, legacy and
# ci_default are curated by hand and preserved. generated_at is only bumped
# when the engines content changes.
sub compute_matrix_update {
    my ( $matrix, $raw, $today ) = @_;
    my $new = decode_json( encode_json($matrix) );    # deep copy

    for my $engine ( sort keys %$raw ) {
        my $data = $raw->{$engine} or next;
        my $e    = $new->{engines}{$engine} ||= {};
        my ( @lts, @short );
        my %all = map { $_ => 1 } @{ $e->{all} || [] };
        for my $item (@$data) {
            my $cycle = $item->{cycle} // '';
            next unless $cycle =~ /^\d+(?:\.\d+)*$/;
            next unless is_active_eol( $item->{eol}, $today );
            $all{$cycle} = 1;    # only newly active cycles extend the curated list
            if   ( is_lts_flag( $item->{lts}, $today ) ) { push @lts,   $cycle }
            else                                         { push @short, $cycle }
        }
        $e->{lts}        = [ sort { cycle_cmp( $a, $b ) } @lts ];
        $e->{short_term} = [ sort { cycle_cmp( $a, $b ) } @short ];
        $e->{supported}  = [ @{ $e->{lts} } ];
        $e->{all}        = [ sort { cycle_cmp( $a, $b ) } keys %all ];
    }

    my %old_cmp = %$matrix;
    my %new_cmp = %$new;
    delete $old_cmp{generated_at};
    delete $new_cmp{generated_at};
    if ( render_matrix_json( \%old_cmp ) ne render_matrix_json( \%new_cmp ) ) {
        $new->{generated_at} = $today;
    }
    return $new;
}

# Pure: human-readable list of engine fields that differ.
sub matrix_changes {
    my ( $old, $new ) = @_;
    my @changes;
    for my $engine ( sort keys %{ $new->{engines} || {} } ) {
        for my $k (@ENGINE_KEYS) {
            my $o = join( ', ', @{ $old->{engines}{$engine}{$k} || [] } );
            my $n = join( ', ', @{ $new->{engines}{$engine}{$k} || [] } );
            push @changes, "$engine.$k: [$o] -> [$n]" if $o ne $n;
        }
    }
    return @changes;
}

# Compare/update the matrix file. Returns the exit code (0 OK, 1 drift in check mode).
sub run_matrix_step {
    my ( $matrix_file, $raw, $today, $write ) = @_;
    open my $fh, '<', $matrix_file or die "Cannot read $matrix_file: $!\n";
    my $current = do { local $/; <$fh> };
    close $fh;
    my $matrix = decode_json($current);
    my $new    = compute_matrix_update( $matrix, $raw, $today );
    my @changes = matrix_changes( $matrix, $new );

    if ( !@changes ) {
        print "[OK] $matrix_file is synchronized with endoflife.date.\n";
        return 0;
    }
    print "Proposed ci_matrix.json changes (endoflife.date):\n";
    print "  - $_\n" for @changes;
    if ( !$write ) {
        print "[FAIL] $matrix_file is outdated. Run: perl build/sync_eol_dates.pl --update-matrix\n";
        return 1;
    }
    my $tmp = "$matrix_file.tmp.$$";
    open my $out, '>', $tmp or die "Cannot write $tmp: $!\n";
    print $out render_matrix_json($new);
    close $out or die "Cannot close $tmp: $!\n";
    rename $tmp, $matrix_file or die "Cannot rename $tmp to $matrix_file: $!\n";
    print "[OK] $matrix_file updated.\n";
    print "Next: perl build/sync_supported_versions.pl && perl build/sync_eol_dates.pl --generate\n";
    return 0;
}

sub main {
    my $generate_files = 0;
    my $update_matrix  = 0;
    my $check_matrix   = 0;
    my $matrix_file    = File::Spec->catfile( $script_dir, 'ci_matrix.json' );
    GetOptions(
        'generate|g'    => \$generate_files,
        'update-matrix' => \$update_matrix,
        'check'         => \$check_matrix,
        'matrix=s'      => \$matrix_file,
    ) or return 2;

    print "Current Date for EOL Auditing: $today_str\n\n";

    if ( open my $mfh, '<', $matrix_file ) {
        local $/;
        my $matrix = eval { decode_json(<$mfh>) } || {};
        close $mfh;
        for my $engine ( values %{ $matrix->{engines} || {} } ) {
            $LEGACY_SUPPORTED{$_} = 1 for @{ $engine->{legacy_supported} || [] };
        }
    }
    else {
        warn "[WARN] Cannot read $matrix_file: $!. No legacy whitelist applied.\n";
    }

    my ( $mysql_active,   $mysql_raw )   = fetch_product_data('mysql');
    my ( $mariadb_active, $mariadb_raw ) = fetch_product_data('mariadb');

    if ($generate_files) {
        generate_support_markdown( 'mysql',   $mysql_raw );
        generate_support_markdown( 'mariadb', $mariadb_raw );
    }

    # If network failed, exit gracefully
    if ( !defined $mysql_active || !defined $mariadb_active ) {
        print "[OK] EOL synchronization check skipped (offline mode).\n";
        return 0;
    }

    my $errors = 0;
    if ( $update_matrix || $check_matrix ) {
        print "\n";
        $errors += run_matrix_step( $matrix_file, { mysql => $mysql_raw, mariadb => $mariadb_raw },
            $today_str, ( $update_matrix && !$check_matrix ) );
    }

    print "\nActive MySQL cycles (according to EOL API): \n";
    print "  - $_ (EOL: $mysql_active->{$_})\n" for sort keys %$mysql_active;
    print "\nActive MariaDB cycles (according to EOL API): \n";
    print "  - $_ (EOL: $mariadb_active->{$_})\n" for sort keys %$mariadb_active;

    # 2. Parse the generated supported versions block of mysqltuner.pl
    #    (our @SUPPORTED_LTS_VERSIONS / @SUPPORTED_SHORT_TERM_VERSIONS = qw(...))
    print "\nReading checks from $tuner_file...\n";
    open my $fh, '<', $tuner_file or die "Could not open $tuner_file: $!";

    my %checks_found;
    while ( my $line = <$fh> ) {
        if ( $line =~ /^our\s+\@SUPPORTED_(?:LTS|SHORT_TERM)_VERSIONS\s*=\s*qw\(([^)]*)\)/ ) {
            $checks_found{$_} = 1 for split( ' ', $1 );
        }
        last if $line =~ /^# END GENERATED SUPPORTED VERSIONS/;
    }
    close $fh;

    print "Supported checks declared in validate_mysql_version():\n";
    print "  - $_\n" for sort keys %checks_found;
    print "\n";

    # 3. Audit EOL version checks
    for my $cycle ( keys %$mysql_active ) {
        if ( !$checks_found{$cycle} ) {
            print "ERROR: Supported MySQL cycle $cycle is missing from validate_mysql_version() checks!\n";
            $errors++;
        }
    }

    for my $cycle ( keys %$mariadb_active ) {
        if ( !$checks_found{$cycle} ) {
            print "ERROR: Supported MariaDB cycle $cycle is missing from validate_mysql_version() checks!\n";
            $errors++;
        }
    }

    for my $check_ver ( keys %checks_found ) {
        if ( !exists $mysql_active->{$check_ver} && !exists $mariadb_active->{$check_ver} ) {
            print "ERROR: Outdated or EOL cycle $check_ver is still declared as supported in validate_mysql_version()!\n";
            $errors++;
        }
    }

    if ( $errors > 0 ) {
        print "\n[FAIL] EOL date synchronization audit failed: $errors discrepancy found.\n";
        return 1;
    }

    print "[OK] EOL date synchronization audit passed successfully.\n";
    return 0;
}

exit main() unless caller;

1;
