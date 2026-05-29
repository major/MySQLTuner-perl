#!/usr/bin/env perl
use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP;
use File::Basename;
use Time::Piece;

# LTS Version Auto-Bumper Utility for MySQLTuner-perl
# Queries endoflife.date API and dynamically updates LTS lists in mysqltuner.pl and test suites.

my $script_dir = dirname(__FILE__);
my $tuner_file = "$script_dir/../mysqltuner.pl";
my $test_file  = "$script_dir/../tests/test_vulnerabilities.t";

my $today_str = Time::Piece->new->strftime('%Y-%m-%d');

my %LEGACY_SUPPORTED = (
    '8.0' => 1, # Whitelisted legacy
);

sub fetch_active_cycles {
    my ($product) = @_;
    my $url = "https://endoflife.date/api/$product.json";
    my $response = HTTP::Tiny->new->get($url);
    return undef unless $response->{success};
    
    my $data = decode_json($response->{content});
    my %active;
    for my $item (@$data) {
        my $cycle = $item->{cycle};
        my $eol = $item->{eol};
        
        my $is_active = 0;
        if (!defined $eol || $eol eq '' || $eol eq '0' || $eol eq 'false' || !$eol) {
            $is_active = 1;
        } else {
            if ($eol gt $today_str) {
                $is_active = 1;
            }
        }
        
        if ($is_active || $LEGACY_SUPPORTED{$cycle}) {
            $active{$cycle} = 1;
        }
    }
    return \%active;
}

my $mysql_active = fetch_active_cycles('mysql');
my $mariadb_active = fetch_active_cycles('mariadb');

if (!defined $mysql_active || !defined $mariadb_active) {
    print "Error fetching EOL dates. Skipping auto-bump.\n";
    exit 0;
}

# Merge and sort active cycles
my %merged;
$merged{$_} = 1 for keys %$mysql_active;
$merged{$_} = 1 for keys %$mariadb_active;

my @sorted_cycles = sort {
    my ($a_maj, $a_min) = split(/\./, $a);
    my ($b_maj, $b_min) = split(/\./, $b);
    $a_maj <=> $b_maj || ($a_min // 0) <=> ($b_min // 0)
} keys %merged;

print "Current active/supported cycles from EOL API:\n";
print "  - $_\n" for @sorted_cycles;

# 1. Update mysqltuner.pl validate_mysql_version()
open(my $fh, '<', $tuner_file) or die $!;
my $tuner_content = do { local $/; <$fh> };
close($fh);

# Construct new validate_mysql_version checks block
my $new_checks_block = "    if (   ";
my @check_lines;
for my $cycle (@sorted_cycles) {
    my ($maj, $min) = split(/\./, $cycle);
    $min //= 0;
    # Add appropriate spacing matching formatting guidelines
    my $spacing = length($min) == 1 ? " " : "";
    push @check_lines, "mysql_version_eq( $maj, $spacing$min )";
}
$new_checks_block .= join("\n        or ", @check_lines) . " )";

# Find the validate_mysql_version block using regex
my $tuner_regex = qr/if\s*\(\s*mysql_version_eq\(\s*\d+,\s*\d+\s*\)(?:\s*\n?\s*or\s+mysql_version_eq\(\s*\d+,\s*\d+\s*\))*\s*\)/s;
if ($tuner_content =~ /$tuner_regex/) {
    my $matched = $&;
    if ($matched ne $new_checks_block) {
        print "Updating validate_mysql_version LTS checks in mysqltuner.pl...\n";
        $tuner_content =~ s/$tuner_regex/$new_checks_block/s;
        
        open(my $out, '>', $tuner_file) or die $!;
        print $out $tuner_content;
        close($out);
        print "[OK] mysqltuner.pl successfully updated.\n";
    } else {
        print "mysqltuner.pl is already up-to-date.\n";
    }
} else {
    print "Warning: Could not match LTS checks block in mysqltuner.pl\n";
}

# 2. Update tests/test_vulnerabilities.t
open(my $tfh, '<', $test_file) or die $!;
my $test_content = do { local $/; <$tfh> };
close($tfh);

my @test_lines;
for my $cycle (@sorted_cycles) {
    my ($maj) = split(/\./, $cycle);
    my $db_type = $maj >= 10 ? "MariaDB" : "MySQL";
    my $spacer = $cycle eq '10.11' || $cycle eq '10.6' ? "" : " ";
    push @test_lines, sprintf('        { version => "%s.1",%sexpected_lts => 1, desc => "%s %s.1 is supported LTS" },',
        $cycle, $spacer, $db_type, $cycle);
}
my $new_test_block = "        # Supported LTS versions\n" . join("\n", @test_lines);

my $test_regex = qr/\s*# Supported LTS versions\n\s*\{ version => .*?expected_lts => 1, desc => .*? \},\n(?:\s*\{ version => .*?expected_lts => 1, desc => .*? \},\n)*/s;

if ($test_content =~ /$test_regex/) {
    my $matched = $&;
    # Clean up spacing to compare
    my $clean_matched = $matched;
    $clean_matched =~ s/\s+//g;
    my $clean_new = $new_test_block;
    $clean_new =~ s/\s+//g;

    if ($clean_matched ne $clean_new) {
        print "Updating test cases in tests/test_vulnerabilities.t...\n";
        $test_content =~ s/$test_regex/\n$new_test_block\n/s;

        open(my $tout, '>', $test_file) or die $!;
        print $tout $test_content;
        close($tout);
        print "[OK] tests/test_vulnerabilities.t successfully updated.\n";
    } else {
        print "tests/test_vulnerabilities.t is already up-to-date.\n";
    }
} else {
    print "Warning: Could not match Supported LTS versions test block in tests/test_vulnerabilities.t\n";
}

exit 0;
