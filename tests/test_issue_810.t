#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;

my $script = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..', 'mysqltuner.pl'));

# Mocking and loading mysqltuner.pl
{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# Silence console printing from within the test
{
    no warnings 'redefine';
    no warnings 'once';
    *main::badprint = sub { };
    *main::goodprint = sub { };
    *main::debugprint = sub { };
    *main::infoprint = sub { };
    *main::subheaderprint = sub { };
    *main::prettyprint = sub { };
}

# Mock transport and system commands
{
    no warnings 'redefine';
    no warnings 'once';
    *main::get_transport_prefix = sub { return '' };
    *main::execute_system_command = sub { return '' };
}

subtest 'Issue 810 - Verify forcemem MB interpretation correctness (regression test)' => sub {
    # Initialize basic CLI options metadata defaults
    foreach my $o (keys %main::CLI_METADATA) {
        my ($p) = split /\|/, $o;
        $p =~ s/[!+=:].*$//;
        $main::opt{$p} //= $main::CLI_METADATA{$o}->{default};
    }

    # Simulate `--forcemem 32768` (passed in MB for a 32GB system)
    $main::opt{'forcemem'} = 32768;
    $main::opt{'forceswap'} = 0;
    
    # Run OS setup logic to calculate physical memory
    main::os_setup();

    # Verification:
    # 32768 MB must equal 34,359,738,368 bytes (32 GB)
    is($main::physical_memory, 34359738368, "Physical memory must be correctly calculated in bytes (32768 * 1024 * 1024)");

    # Verify that human readable formatting outputs 32.0G and NOT 32.0K (which occurred before the regression fix)
    my $pretty = main::hr_bytes($main::physical_memory);
    is($pretty, "32.0G", "Pretty memory output must be 32.0G");
    isnt($pretty, "32.0K", "Pretty memory output must not be 32.0K (regression check)");
};

done_testing();
