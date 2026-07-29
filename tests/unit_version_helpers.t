#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";

# Mock MySQLTuner environment and helper modules
require 'mysqltuner.pl';

# Helper for resetting state
sub reset_test_state {
    no warnings 'once';
    %main::myvar = ();
    %main::mystat = ();
    @main::generalrec = ();
    @main::adjvars = ();
    $main::is_local_only = 0;
}

subtest 'Version Caching & Comparison Helpers' => sub {
    reset_test_state();
    $main::myvar{'version'} = '10.11.8-MariaDB';
    main::validate_mysql_version();
    
    # Test version comparison caching
    ok(main::mysql_version_ge(10, 11), 'MariaDB 10.11 is greater than or equal to 10.11');
    ok(main::mysql_version_ge(10, 6), 'MariaDB 10.11 is greater than or equal to 10.6');
    ok(!main::mysql_version_ge(11, 4), 'MariaDB 10.11 is not greater than or equal to 11.4');
    
    # Test exact equality
    ok(main::mysql_version_eq(10, 11), 'MariaDB 10.11 matches 10.11');
};

done_testing();
