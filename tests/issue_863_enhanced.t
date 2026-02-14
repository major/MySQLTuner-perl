#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Mocking variables and functions from mysqltuner.pl
our %result;
our @generalrec;
our @adjvars;

my $badprint_called = 0;
my $last_badprint = "";

sub badprint { 
    $last_badprint = shift;
    $badprint_called++;
}

# Logic to test
sub check_cpanel_logic {
    my ($mock_files, $skip_name_resolve) = @_;
    
    $result{'Variables'}{'skip_name_resolve'} = $skip_name_resolve;
    $badprint_called = 0;
    $last_badprint = "";
    @generalrec = ();
    @adjvars = ();

    # Logic from mysqltuner.pl
    my $is_cpanel = 0;
    foreach my $file (@$mock_files) {
        if ($file eq "/usr/local/cpanel/cpanel" || 
            $file eq "/var/cpanel/cpanel.config" || 
            $file eq "/etc/cpupdate.conf") {
            $is_cpanel = 1;
            last;
        }
    }

    if ( not defined( $result{'Variables'}{'skip_name_resolve'} ) ) {
        # skip
    }
    elsif ( $is_cpanel ) {
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
        badprint "Name resolution is active...";
        push( @adjvars, "skip-name-resolve=ON" );
    }
}

# Test 1: Detection via /usr/local/cpanel/cpanel
check_cpanel_logic(["/usr/local/cpanel/cpanel"], "ON");
is($badprint_called, 1, "Detected via /usr/local/cpanel/cpanel");
like($last_badprint, qr/cPanel\/Flex system detected/, "Refined message check");

# Test 2: Detection via /var/cpanel/cpanel.config
check_cpanel_logic(["/var/cpanel/cpanel.config"], "ON");
is($badprint_called, 1, "Detected via /var/cpanel/cpanel.config");

# Test 3: Detection via /etc/cpupdate.conf
check_cpanel_logic(["/etc/cpupdate.conf"], "ON");
is($badprint_called, 1, "Detected via /etc/cpupdate.conf");

# Test 4: No detection (Normal system)
{
    my $is_cpanel = 0;
    foreach my $file (("/etc/passwd")) {
        if ($file eq "/usr/local/cpanel/cpanel" || 
            $file eq "/var/cpanel/cpanel.config" || 
            $file eq "/etc/cpupdate.conf") {
            $is_cpanel = 1;
            last;
        }
    }
    is($is_cpanel, 0, "Not detected on normal system");
}
check_cpanel_logic(["/etc/passwd"], "OFF");
is($badprint_called, 1, "Normal system with skip_name_resolve=OFF triggers ON recommendation");
is($adjvars[0], "skip-name-resolve=ON", "Normal system recommends ON");

done_testing();
