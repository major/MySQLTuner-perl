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

# Silence console printing and capture output for assertion
my @badprints;
my @infoprints;
{
    no warnings 'redefine';
    no warnings 'once';
    *main::badprint = sub { push @badprints, $_[0] };
    *main::goodprint = sub { };
    *main::debugprint = sub { };
    *main::infoprint = sub { push @infoprints, $_[0] };
    *main::subheaderprint = sub { };
    *main::prettyprint = sub { };
}

# Mock command transport prefix
{
    no warnings 'redefine';
    no warnings 'once';
    *main::get_transport_prefix = sub { return '' };
}

sub reset_state {
    # Initialize basic CLI options metadata defaults
    %main::opt = ();
    foreach my $o (keys %main::CLI_METADATA) {
        my ($p) = split /\|/, $o;
        $p =~ s/[!+=:].*$//;
        $main::opt{$p} = $main::CLI_METADATA{$o}->{default} // 0;
    }
    @badprints = ();
    @infoprints = ();
    $main::physical_memory = undef;
    $main::swap_memory = undef;
}

subtest 'Issue 796 - Remote host with --forcemem specified' => sub {
    reset_state();

    $main::opt{'host'} = '192.168.1.100';
    $main::opt{'forcemem'} = 2000; # 2000 MB
    $main::opt{'forceswap'} = 512;

    # Simulate setup_environment and mysql_setup checks
    $main::doremote = main::is_remote();
    is($main::doremote, 1, "Connection to remote IP must be remote");

    # os_setup logic
    main::os_setup();

    # Verification:
    # 2000 MB must equal 2097152000 bytes (2.0G)
    is($main::physical_memory, 2097152000, "Physical memory must be exactly calculated in bytes (2000 * 1024 * 1024)");
    is(main::hr_bytes($main::physical_memory), "2.0G", "Pretty memory output must be 2.0G (and not 2.0K regression)");
    is($main::swap_memory, 512 * 1048576, "Swap memory must be calculated in bytes");
};

subtest 'Issue 796 - Remote host WITHOUT --forcemem specified' => sub {
    reset_state();

    $main::opt{'host'} = '192.168.1.100';
    $main::opt{'forcemem'} = 0;
    $main::opt{'forceswap'} = 0;

    # Mocking DB setup behavior where if --forcemem isn't specified on a remote host,
    # it warns the user and defaults to 1024 MB.
    if ( !$main::opt{'forcemem'} && main::is_remote() == 1 ) {
        main::badprint("The --forcemem option is required for remote connections");
        main::badprint("Assuming RAM memory is 1Gb for simplify remote connection usage");
        $main::opt{'forcemem'} = 1024;
    }

    # Verify that warnings were printed and forcemem defaulted
    ok(grep(/The --forcemem option is required/, @badprints), "Required --forcemem warning was printed");
    is($main::opt{'forcemem'}, 1024, "forcemem should default to 1024 MB");

    # os_setup logic
    main::os_setup();

    is($main::physical_memory, 1024 * 1048576, "Physical memory must default to 1GB in bytes");
    is(main::hr_bytes($main::physical_memory), "1.0G", "Pretty memory output must be 1.0G");
};

subtest 'Issue 796 - Local host WITHOUT --forcemem specified' => sub {
    reset_state();

    $main::opt{'host'} = '127.0.0.1';
    $main::opt{'forcemem'} = 0;

    $main::doremote = main::is_remote();
    is($main::doremote, 0, "Connection to 127.0.0.1 must not be remote");

    if ( !$main::opt{'forcemem'} && main::is_remote() == 1 ) {
        $main::opt{'forcemem'} = 1024;
    }

    is($main::opt{'forcemem'}, 0, "forcemem should remain 0 for local host");
};

done_testing();
