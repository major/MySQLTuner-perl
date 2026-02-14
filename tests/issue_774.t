#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# We will extract and test the logic of sub mysql_myisam
# To avoid loading the whole script, we'll mock the globals it uses.

our %myvar;
our %mystat;
our %mycalc;
our %opt = ( myisamstat => 1 );
our @adjvars;
our @generalrec;

# Mocked functions
sub subheaderprint { }
sub badprint { }
sub goodprint { }
sub infoprint { }
sub debugprint { }
sub hr_bytes { return "@_"; }
sub hr_num { return "@_"; }
sub select_one { return 1; }
sub select_array { return (); }
sub dump_into_file { }
sub mysql_version_ge { return 0; }
sub mysql_version_le { return 0; }

# The logic we are testing:
sub test_logic {
    @adjvars = ();
    
    # --- START OF COPIED LOGIC FROM mysqltuner.pl ---
    # Simplified version of the logic in mysql_myisam
    
    # Key buffer usage (simplified from 4862)
    if ( $mycalc{'pct_key_buffer_used'} < 90 ) {
        push(@adjvars, "key_buffer_size (~ usage)");
    }
    
    # Key buffer size / total MyISAM indexes (modified with fix)
    if (   $myvar{'key_buffer_size'} < $mycalc{'total_myisam_indexes'}
        && $mycalc{'pct_keys_from_mem'} < 95
        && $mycalc{'pct_key_buffer_used'} >= 90 ) # THIS IS OUR FIX
    {
        push(@adjvars, "key_buffer_size (> indexes)");
    }
    # --- END OF COPIED LOGIC ---
}

# Scenario 1: Underutilized buffer (User case)
%myvar = ( key_buffer_size => 8388608 );
%mycalc = ( 
    pct_key_buffer_used => 18.5, 
    total_myisam_indexes => 12897484,
    pct_keys_from_mem => 86.3 
);
test_logic();
is(grep(/key_buffer_size/, @adjvars), 1, "Scenario 1: Only one recommendation when underutilized");
ok($adjvars[0] =~ /~ usage/, "Scenario 1: Recommendation is to shrink/adjust to usage");

# Scenario 2: High utilization but too small
%mycalc = ( 
    pct_key_buffer_used => 95, 
    total_myisam_indexes => 20000000,
    pct_keys_from_mem => 80 
);
test_logic();
is(grep(/key_buffer_size/, @adjvars), 1, "Scenario 2: Only one recommendation when highly utilized but small");
ok($adjvars[0] =~ /> indexes/, "Scenario 2: Recommendation is to increase");

# Scenario 3: Optimal (high utilization, enough size, good hit rate)
%mycalc = ( 
    pct_key_buffer_used => 95, 
    total_myisam_indexes => 5000000,
    pct_keys_from_mem => 99 
);
test_logic();
is(grep(/key_buffer_size/, @adjvars), 0, "Scenario 3: No recommendation when optimal");

done_testing();
