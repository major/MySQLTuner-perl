#!/usr/bin/env perl
# ===========================================================================
# Script:      build/sync_eol_dates.pl
# Description: EOL Synchronization Audit & Support Markdown Generator
#              in Pure Perl (Core HTTP::Tiny and JSON::PP).
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
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

my $generate_files = 0;
GetOptions(
    'generate|g' => \$generate_files,
);

# Date reference (today's date in YYYY-MM-DD format)
my $today_str = Time::Piece->new->strftime('%Y-%m-%d');
print "Current Date for EOL Auditing: $today_str\n\n";

# Legacy supported versions whitelist (versions that are officially EOL but still whitelisted as supported/LTS)
my %LEGACY_SUPPORTED = (
    '8.0' => 1,    # MySQL 8.0 recently EOL-ed, kept as supported in current validator
);

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

        my $is_active = 0;
        if ( !defined $eol || $eol eq '' || $eol eq '0' || $eol eq 'false' || !$eol ) {
            $is_active = 1;
        }
        else {
            if ( $eol gt $today_str ) {
                $is_active = 1;
            }
        }

        if ( $is_active || $LEGACY_SUPPORTED{$cycle} ) {
            $active_cycles{$cycle} = $eol // 'no EOL';
        }
    }
    return ( \%active_cycles, $data );
}

sub generate_support_markdown {
    my ( $product, $data ) = @_;
    return unless $data;

    my $target_file = File::Spec->catfile( $script_dir, '..', "${product}_support.md" );
    open my $mfh, '>', $target_file or die "Cannot write to $target_file: $!\n";
    print $mfh "# Version Support for $product\n\n";
    print $mfh "| Version | End of Support Date | LTS | Status |\n";
    print $mfh "|---------|------------------------|-----|--------|\n";

    my @sorted = sort { ( $a->{eol} // '9999-99-99' ) cmp( $b->{eol} // '9999-99-99' ) } @$data;
    for my $item (@sorted) {
        my $cycle = $item->{cycle} // 'N/A';
        my $eol   = $item->{eol};
        my $lts   = ( $item->{lts} && ( $item->{lts} eq '1' || $item->{lts} eq 'true' || $item->{lts} == 1 ) ) ? 'YES' : 'NO';

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

my ( $mysql_active,   $mysql_raw )   = fetch_product_data('mysql');
my ( $mariadb_active, $mariadb_raw ) = fetch_product_data('mariadb');

if ($generate_files) {
    generate_support_markdown( 'mysql',   $mysql_raw );
    generate_support_markdown( 'mariadb', $mariadb_raw );
}

# If network failed, exit gracefully
if ( !defined $mysql_active || !defined $mariadb_active ) {
    print "[OK] EOL synchronization check skipped (offline mode).\n";
    exit 0;
}

print "\nActive MySQL cycles (according to EOL API): \n";
print "  - $_ (EOL: $mysql_active->{$_})\n" for sort keys %$mysql_active;
print "\nActive MariaDB cycles (according to EOL API): \n";
print "  - $_ (EOL: $mariadb_active->{$_})\n" for sort keys %$mariadb_active;

# 2. Parse mysqltuner.pl validate_mysql_version logic
print "\nReading checks from $tuner_file...\n";
open my $fh, '<', $tuner_file or die "Could not open $tuner_file: $!";

my $in_validate_sub = 0;
my %checks_found;
while ( my $line = <$fh> ) {
    if ( $line =~ /sub validate_mysql_version\b/ ) {
        $in_validate_sub = 1;
        next;
    }
    if ($in_validate_sub) {
        if ( $line =~ /^\}/ ) {
            $in_validate_sub = 0;
            last;
        }

        while ( $line =~ /mysql_version_eq\(\s*(\d+)\s*,\s*(\d+)\s*\)/g ) {
            my $ver = "$1.$2";
            $checks_found{$ver} = 1;
        }
    }
}
close $fh;

print "Supported checks declared in validate_mysql_version():\n";
print "  - $_\n" for sort keys %checks_found;
print "\n";

# 3. Audit EOL version checks
my $errors = 0;

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
    exit 1;
}

print "[OK] EOL date synchronization audit passed successfully.\n";
exit 0;
