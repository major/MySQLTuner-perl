#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use Cwd 'abs_path';

my $script = abs_path(dirname(__FILE__) . '/../mysqltuner.pl');

# List of boolean options to test
my @boolean_options = qw(
    debug
    silent
    checkversion
    updateversion
    buffers
    dbstat
    tbstat
    colstat
    idxstat
    sysstat
    pfstat
    plugininfo
    structstat
    myisamstat
    experimental
    nondedicated
    cloud
    azure
    pipe
    verbose
    json
    prettyjson
    skippassword
    noask
    color
    nobad
    nogood
    noinfo
    noprocess
    noprettyicon
);

plan tests => scalar @boolean_options;

foreach my $opt (@boolean_options) {
    # We try to run the script with --no-$opt --help and check if it fails
    # If it fails with "Unknown option: no-$opt", then it's missing.
    # Note: --help will exit with 0 or 1, but we care about the warning on stderr.
    my $cmd = "perl $script --no-$opt --help 2>&1";
    my $output = `$cmd`;
    
    if ($output =~ /Unknown option: no-$opt/) {
        fail("Option --no-$opt is missing");
    } else {
        pass("Option --no-$opt is present or supported");
    }
}
