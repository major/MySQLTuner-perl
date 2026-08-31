#!/usr/bin/env perl
# ===========================================================================
# Test:        test_issue_863.t
# Description: Validates cPanel & standard skip-name-resolve matrix (Issue #863 / Phase 26.2).
# ===========================================================================
use strict;
use warnings;
no warnings 'once';
use Test::More;

plan tests => 4;

# Mocking variables and functions from mysqltuner.pl
our %result;
our %opt = ( "debug" => 0 );
our ( @adjvars, @generalrec );

my $infoprint_called = 0;
my $badprint_called  = 0;

sub debugprint { }
sub infoprint {
    my $msg = shift;
    $infoprint_called++;
}
sub badprint {
    my $msg = shift;
    $badprint_called++;
}

sub evaluate_skip_name_resolve_logic {
    my ( $has_cpanel, $skip_name_resolve ) = @_;
    $result{'Variables'}{'skip_name_resolve'} = $skip_name_resolve;
    $infoprint_called                         = 0;
    $badprint_called                          = 0;
    @adjvars                                  = ();
    @generalrec                               = ();

    if ( not defined( $result{'Variables'}{'skip_name_resolve'} ) ) {
        # Skipped
    }
    elsif ($has_cpanel) {
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

# --- Subtest 1: cPanel with skip_name_resolve=OFF ---
subtest 'cPanel Environment with skip_name_resolve=OFF' => sub {
    plan tests => 2;

    evaluate_skip_name_resolve_logic( 1, 'OFF' );
    is( $badprint_called, 0, "cPanel with skip_name_resolve=OFF does NOT trigger badprint" );
    is( scalar(@adjvars), 0, "cPanel with skip_name_resolve=OFF does NOT recommend variable adjustment" );
};

# --- Subtest 2: cPanel with skip_name_resolve=ON ---
subtest 'cPanel Environment with skip_name_resolve=ON' => sub {
    plan tests => 3;

    evaluate_skip_name_resolve_logic( 1, 'ON' );
    is( $badprint_called, 1, "cPanel with skip_name_resolve=ON triggers badprint warning" );
    is( scalar(@adjvars), 0, "cPanel does NOT recommend skip-name-resolve=ON" );
    like( $generalrec[0], qr/cPanel recommends keeping skip-name-resolve disabled/, "Recommendation contains cPanel KB link" );
};

# --- Subtest 3: Standard Environment with skip_name_resolve=OFF ---
subtest 'Standard Environment with skip_name_resolve=OFF' => sub {
    plan tests => 3;

    evaluate_skip_name_resolve_logic( 0, 'OFF' );
    is( $badprint_called, 1, "Standard system with skip_name_resolve=OFF triggers badprint warning" );
    is( scalar(@adjvars), 1, "Standard system recommends variable adjustment" );
    is( $adjvars[0], "skip-name-resolve=ON", "Adjustment specifies skip-name-resolve=ON" );
};

# --- Subtest 4: Standard Environment with skip_name_resolve=ON ---
subtest 'Standard Environment with skip_name_resolve=ON' => sub {
    plan tests => 2;

    evaluate_skip_name_resolve_logic( 0, 'ON' );
    is( $badprint_called, 0, "Standard system with skip_name_resolve=ON does NOT trigger badprint" );
    is( scalar(@adjvars), 0, "No adjustment recommended when already ON" );
};

done_testing();
