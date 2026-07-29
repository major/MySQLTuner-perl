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

subtest 'MariaDB & MySQL Support EOL Checks' => sub {
    reset_test_state();
    $main::myvar{'version'} = '10.5.15-MariaDB'; # Non-LTS EOL version
    
    # Run version support validations
    main::validate_mysql_version();
    ok(grep(/unsupported version for production environments/, @main::generalrec), 'Checks warning or status notice for legacy unsupported version');
};

done_testing();
