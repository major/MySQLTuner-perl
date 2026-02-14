#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;

# Mocking the environment to test mysqltuner.pl internal hash initialization
my $script = 'mysqltuner.pl';

unless (-f $script) {
    plan skip_all => "MySQLTuner script not found at $script";
}

# Slurp the script to extract %CLI_METADATA and %opt initialization
open(my $fh, '<', $script) or die "Cannot open $script: $!";
my $content = do { local $/; <$fh> };
close($fh);

# Extract %CLI_METADATA content
# We look for 'our %CLI_METADATA = (' up to the next ');'
if ($content =~ /our %CLI_METADATA = \((.*?)\);/s) {
    my $metadata_str = $1;
    
    # We want to verify specific keys like colstat!, dbstat!, etc.
    my @negated_keys = $metadata_str =~ /'([a-z0-9_-]+!)'/g;
    
    if (!@negated_keys) {
        plan skip_all => "No negated keys found in metadata for testing";
    }

    # Now we test the actual script execution logic for these keys
    # Instead of full execution, we verify that %opt has the keys WITHOUT !
    
    foreach my $key (@negated_keys) {
        my $clean_key = $key;
        $clean_key =~ s/!$//;
        
        # Test if the script contains code that references $opt{$clean_key}
        # and NOT $opt{$key}
        ok($content =~ /\$opt\{$clean_key\}/, "Script references clean key \$opt{$clean_key}");
        ok($content !~ /\$opt\{$key\}/, "Script does NOT reference raw key \$opt{$key}");
    }
} else {
    fail("Could not find %CLI_METADATA in script");
}

done_testing();
