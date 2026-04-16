#!/usr/bin/env perl
use strict;
use warnings;

# Parses mysql_support.md and mariadb_support.md to find "Supported" versions
# and outputs them in the format expected by multi-db-docker-env (e.g. mysql84 mariadb1011)

my @configs;

sub parse_support_file {
    my ($file, $prefix) = @_;
    return unless -f $file;

    open my $fh, '<', $file or die "Cannot open $file: $!\n";
    while (my $line = <$fh>) {
        # Format: | 8.4 | Supported | 2024-04-30 | 2032-04-30 |
        if ($line =~ /\|\s*([\d\.]+)\s*\|\s*Supported\s*\|/) {
            my $version = $1;
            $version =~ s/\.//g; # Remove dots (e.g. 8.4 -> 84, 10.11 -> 1011)
            push @configs, "$prefix$version";
        }
    }
    close $fh;
}

parse_support_file("mysql_support.md", "mysql");
parse_support_file("mariadb_support.md", "mariadb");

# Always append percona80 as a default supported engine
push @configs, "percona80";

print join(" ", @configs) . "\n";
