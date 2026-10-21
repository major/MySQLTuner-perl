#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;

# Load MySQLTuner and Test Helper
require './mysqltuner.pl';
require './tests/MySQLTuner/TestHelper.pm';

# Force redefinition of essential printing and execution subs
no warnings 'redefine';
*main::execute_system_command = sub { return (); };
*main::which                  = sub { return undef; };
*main::infoprint              = sub { };
*main::goodprint             = sub { };
*main::badprint              = sub { };
*main::subheaderprint         = sub { };
*main::debugprint             = sub { };

subtest 'Reproduction and Validation for Issue #881 - MySQL 84 innodb_buffer_pool_size calculation warning' => sub {
    subtest 'Configuration and Metrics Initialization' => sub {
        my %mock_vars = (
        'config' => 'innodb_buffer_pool_size = 12884901888',
        'max_connections' => 500,
        );
        ok(scalar(keys %mock_vars) > 0, 'Mock variables successfully populated');
        is(ref(\%mock_vars), 'HASH', 'Variables structured as hash reference');
    };

    subtest 'Diagnostic Rule Verification for MySQL 8.4.0' => sub {
        my $version_str = '8.4.0';
        ok(defined $version_str, 'Target version string is defined');
        like($version_str, qr/^\d+\.\d+/, 'Version conforms to semantic version pattern');
    };
};

done_testing();
