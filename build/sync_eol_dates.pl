#!/usr/bin/env perl
use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP;
use File::Basename;
use Time::Piece;

# EOL Synchronization Audit Script for MySQLTuner-perl
# Queries endoflife.date API to ensure validate_mysql_version LTS checks are in sync.

my $script_dir = dirname(__FILE__);
my $tuner_file = "$script_dir/../mysqltuner.pl";

# Date reference (today's date in YYYY-MM-DD format)
my $today_str = Time::Piece->new->strftime('%Y-%m-%d');
print "Current Date for EOL Auditing: $today_str\n\n";

# Legacy supported versions whitelist (versions that are officially EOL but still whitelisted as supported/LTS)
my %LEGACY_SUPPORTED = (
    '8.0' => 1, # MySQL 8.0 recently EOL-ed, kept as supported in current validator
);

# 1. Fetch EOL cycles from endoflife.date API
sub fetch_active_cycles {
    my ($product) = @_;
    my $url = "https://endoflife.date/api/$product.json";
    print "Fetching EOL metadata for '$product' from $url...\n";
    
    my $response = HTTP::Tiny->new->get($url);
    if (!$response->{success}) {
        warn "[WARN] Could not retrieve $product metadata: $response->{reason}. Skipping online sync check.\n";
        return undef;
    }
    
    my $data;
    eval {
        $data = decode_json($response->{content});
    };
    if ($@) {
        warn "[WARN] Failed to parse JSON response for $product: $@. Skipping online sync check.\n";
        return undef;
    }
    
    my %active_cycles;
    for my $item (@$data) {
        my $cycle = $item->{cycle};
        my $eol = $item->{eol}; # string date or boolean false
        
        # Determine if cycle is supported/active
        my $is_active = 0;
        if (!defined $eol || $eol eq '' || $eol eq '0' || $eol eq 'false' || !$eol) {
            $is_active = 1; # No EOL set yet
        } else {
            # eol is a date string like "2026-04-30"
            if ($eol gt $today_str) {
                $is_active = 1; # EOL in the future
            }
        }
        
        if ($is_active || $LEGACY_SUPPORTED{$cycle}) {
            $active_cycles{$cycle} = $eol // 'no EOL';
        }
    }
    return \%active_cycles;
}

my $mysql_active = fetch_active_cycles('mysql');
my $mariadb_active = fetch_active_cycles('mariadb');

# If network failed, exit gracefully
if (!defined $mysql_active || !defined $mariadb_active) {
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
while (my $line = <$fh>) {
    if ($line =~ /sub validate_mysql_version\b/) {
        $in_validate_sub = 1;
        next;
    }
    if ($in_validate_sub) {
        if ($line =~ /^\}/) {
            $in_validate_sub = 0;
            last;
        }
        
        # Extract check: mysql_version_eq( X, Y )
        while ($line =~ /mysql_version_eq\(\s*(\d+)\s*,\s*(\d+)\s*\)/g) {
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

# Audit MySQL checks
for my $cycle (keys %$mysql_active) {
    if (!$checks_found{$cycle}) {
        print "ERROR: Supported MySQL cycle $cycle is missing from validate_mysql_version() checks!\n";
        $errors++;
    }
}

# Audit MariaDB checks
for my $cycle (keys %$mariadb_active) {
    if (!$checks_found{$cycle}) {
        print "ERROR: Supported MariaDB cycle $cycle is missing from validate_mysql_version() checks!\n";
        $errors++;
    }
}

# Check if any declared check is actually outdated/EOL
for my $check_ver (keys %checks_found) {
    # It must be active in either MySQL or MariaDB active cycles
    if (!$mysql_active->{$check_ver} && !$mariadb_active->{$check_ver}) {
        print "ERROR: Outdated or EOL cycle $check_ver is still declared as supported in validate_mysql_version()!\n";
        $errors++;
    }
}

if ($errors > 0) {
    print "\n[FAIL] EOL date synchronization audit failed: $errors discrepancy found.\n";
    exit 1;
}

print "[OK] EOL date synchronization audit passed successfully.\n";
exit 0;
