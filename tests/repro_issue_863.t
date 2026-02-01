#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Mocking variables and functions from mysqltuner.pl
our %result;
our %opt = ( "debug" => 0 );
our ( @adjvars, @generalrec );

my $infoprint_called = 0;
my $badprint_called = 0;

sub debugprint { }
sub infoprint { 
    my $msg = shift;
    $infoprint_called++;
    # print "INFO: $msg\n";
}
sub badprint { 
    my $msg = shift;
    $badprint_called++;
    # print "BAD: $msg\n";
}

# Mocking -r operator is not possible easily, so we will extract the logic into a testable function
# For the purpose of reproduction, we copy the logic here as it will be after fix
sub test_logic {
    my ($has_cpanel, $skip_name_resolve) = @_;
    $result{'Variables'}{'skip_name_resolve'} = $skip_name_resolve;
    $infoprint_called = 0;
    $badprint_called = 0;
    @adjvars = ();
    @generalrec = ();

    # Logic from mysqltuner.pl (FIXED)
    if ( not defined( $result{'Variables'}{'skip_name_resolve'} ) ) {
        # infoprint "Skipped name resolution test due to missing skip_name_resolve in system variables.";
    }
    # Cpanel and Skip name resolve (Issue #863)
    # Ref: https://support.cpanel.net/hc/en-us/articles/21664293830423
    elsif ( $has_cpanel ) {
        if ( $result{'Variables'}{'skip_name_resolve'} ne 'OFF'
            and $result{'Variables'}{'skip_name_resolve'} ne '0' )
        {
            badprint "cPanel/Flex system detected: skip-name-resolve should be disabled (OFF)";
            push( @generalrec,
"cPanel recommends keeping skip-name-resolve disabled: https://support.cpanel.net/hc/en-us/articles/21664293830423"
            );
        }
    }
    elsif ( $result{'Variables'}{'skip_name_resolve'} ne 'ON'
        and $result{'Variables'}{'skip_name_resolve'} ne '1' )
    {
        badprint
"Name resolution is active: a reverse name resolution is made for each new connection which can reduce performance";
        push( @generalrec,
"Configure your accounts with ip or subnets only, then update your configuration with skip-name-resolve=ON"
        );
        push( @adjvars, "skip-name-resolve=ON" );
    }
}

# Test Case 1: cPanel detected, skip_name_resolve=OFF
# EXPECTED: No badprint, no recommendation
test_logic(1, 'OFF');
is($badprint_called, 0, "FIXED: cPanel with skip_name_resolve=OFF does NOT trigger a badprint");
is(scalar(@adjvars), 0, "FIXED: cPanel with skip_name_resolve=OFF does NOT recommend an adjustment");

# Test Case 2: cPanel detected, skip_name_resolve=ON
# EXPECTED: badprint saying it should be OFF
test_logic(1, 'ON');
is($badprint_called, 1, "FIXED: cPanel with skip_name_resolve=ON triggers a badprint (should be OFF)");
is(scalar(@adjvars), 0, "FIXED: cPanel should NOT recommend skip-name-resolve=0 even if ON");
like($generalrec[0], qr/cPanel recommends keeping skip-name-resolve disabled/, "FIXED: Recommendation contains cPanel support link");

done_testing();
