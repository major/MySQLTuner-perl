#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;

# 1. Load MySQLTuner logic
require './mysqltuner.pl';
require './tests/MySQLTuner/TestHelper.pm';

# Mocking essential globals and subroutines
$main::good = '[OK]';
$main::bad  = '[!!]';
$main::info = '[--]';
$main::deb  = '[DG]';
$main::end  = '';
our %myvar;
our %real_vars;
our @generalrec;

# Test 1: MariaDB 10.6 with removed vars
subtest 'MariaDB 10.6 Removed Variables' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = ( %main::myvar, 
        version => '10.6.15-MariaDB',
        version_numbers => '10.6.15',
        version_comment => 'mariadb.org binary distribution',
        innodb_file_format => 'Antelope',
        innodb_large_prefix => 'ON',
    );
    %main::real_vars = %main::myvar;
    main::check_removed_innodb_variables();
    ok(grep(/Remove 'innodb_file_format'/, @main::generalrec), 'MariaDB 10.6: innodb_file_format detected');
    ok(grep(/Remove 'innodb_large_prefix'/, @main::generalrec), 'MariaDB 10.6: innodb_large_prefix detected');
};

# Test 2: MySQL 8.0 with removed vars
subtest 'MySQL 8.0 Removed Variables' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = ( %main::myvar, 
        version => '8.0.35',
        version_numbers => '8.0.35',
        version_comment => 'MySQL Community Server - GPL',
        innodb_locks_unsafe_for_binlog => '1',
        tx_isolation => 'REPEATABLE-READ',
    );
    %main::real_vars = %main::myvar;
    main::check_removed_innodb_variables();
    ok(grep(/Remove 'innodb_locks_unsafe_for_binlog'/, @main::generalrec), 'MySQL 8.0: innodb_locks_unsafe_for_binlog detected');
    ok(grep(/Remove 'tx_isolation'/, @main::generalrec), 'MySQL 8.0: tx_isolation detected');
};

# Test 3: MySQL 9.0 with removed vars
subtest 'MySQL 9.0 Removed Variables' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = ( %main::myvar, 
        version => '9.0.1',
        version_numbers => '9.0.1',
        version_comment => 'MySQL Community Server - GPL',
        innodb_log_file_size => '50331648',
        innodb_undo_tablespaces => '2',
    );
    %main::real_vars = %main::myvar;
    main::check_removed_innodb_variables();
    ok(grep(/Remove 'innodb_log_file_size'/, @main::generalrec), 'MySQL 9.0: innodb_log_file_size detected');
    ok(grep(/Remove 'innodb_undo_tablespaces'/, @main::generalrec), 'MySQL 9.0: innodb_undo_tablespaces detected');
};

# Test 4: MySQL 5.7 (Legacy) - should NOT warn for these vars
subtest 'MySQL 5.7 Legacy Variables' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = ( %main::myvar, 
        version => '5.7.44',
        version_numbers => '5.7.44',
        version_comment => 'MySQL Community Server - GPL',
        innodb_file_format => 'Barracuda',
        tx_isolation => 'REPEATABLE-READ',
    );
    %main::real_vars = %main::myvar;
    main::check_removed_innodb_variables();
    is(scalar @main::generalrec, 0, 'MySQL 5.7: No warnings for legacy valid variables');
};

# Test 5: MariaDB 10.3 (Legacy) - should NOT warn for file_format (removed in 10.6)
subtest 'MariaDB 10.3 Legacy Variables' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = ( %main::myvar, 
        version => '10.3.39-MariaDB',
        version_numbers => '10.3.39',
        version_comment => 'mariadb.org binary distribution',
        innodb_file_format => 'Antelope',
    );
    %main::real_vars = (
        version => '10.3.39-MariaDB',
        version_numbers => '10.3.39',
        version_comment => 'mariadb.org binary distribution',
        innodb_file_format => 'Antelope',
    );
    main::check_removed_innodb_variables();
    is(scalar @main::generalrec, 0, 'MariaDB 10.3: No warnings for innodb_file_format (not removed yet)');
};

# Test 6: Internally injected variables should NOT trigger warnings (Issue #32)
subtest 'Injected Variables (Issue #32)' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = ( %main::myvar, 
        version => '10.11.3-MariaDB',
        version_numbers => '10.11.3',
        version_comment => 'mariadb.org binary distribution',
        have_innodb => 'YES', # Injected
        innodb_support_xa => 'ON', # Injected
    );
    %main::real_vars = (
        version => '10.11.3-MariaDB',
    );
    main::check_removed_innodb_variables();
    is(scalar @main::generalrec, 0, 'Injected variables (have_innodb, innodb_support_xa) do not trigger false warnings');
};

# Test 7: Variables set to 'OFF' should NOT trigger warnings (Issue #32)
subtest 'Variables set to OFF (Issue #32)' => sub {
    @main::generalrec = ();
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = ( %main::myvar, 
        version => '10.11.3-MariaDB',
        version_numbers => '10.11.3',
        version_comment => 'mariadb.org binary distribution',
        innodb_prefix_index_cluster_optimization => 'OFF',
    );
    %main::real_vars = (
        version => '10.11.3-MariaDB',
        version_numbers => '10.11.3',
        version_comment => 'mariadb.org binary distribution',
        innodb_prefix_index_cluster_optimization => 'OFF',
    );
    main::check_removed_innodb_variables();
    is(scalar @main::generalrec, 0, "Variables set to 'OFF' do not trigger false warnings");
};

done_testing();
