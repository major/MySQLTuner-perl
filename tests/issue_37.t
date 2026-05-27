#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';

use Test::More tests => 1;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Suppress warnings from mysqltuner.pl initialization if any
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;
require './tests/MySQLTuner/TestHelper.pm';

# Mock global variables
our %result;
our @dblist;

subtest 'Issue #37: AUTO_INCREMENT capacity warnings' => sub {
    no warnings 'redefine';

    my @bad_prints;
    my @good_prints;
    my @info_prints;

    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::infoprint = sub { push @info_prints, $_[0] };

    # Mock select_one to return max int (18446744073709551615)
    local *main::select_one = sub {
        my $query = shift;
        if ($query =~ /SELECT ~0/) {
            return "18446744073709551615";
        }
        return "0";
    };

    # Mock select_array for SHOW TABLE STATUS
    # We want to test different combinations of TableName, Rows, Auto_increment
    # Columns are index: 0=Name, 4=Rows, 10=Auto_increment
    local *main::select_array = sub {
        my $query = shift;
        if ($query =~ /SHOW DATABASES/) {
            return ("test_db");
        }
        if ($query =~ /information_schema.ENGINES/) {
            return ("InnoDB\tYES", "MyISAM\tYES");
        }
        if ($query =~ /SHOW TABLE STATUS/) {
            return (
                # Table 1: Empty table t_empty, AUTO_INCREMENT = 1, Rows = 0 -> SHOULD BE SKIPPED
                "t_empty\tEngine\tVersion\tRow_format\t0\tAvg_row_length\tData_length\tMax_data_length\tIndex_length\tData_free\t1",
                # Table 2: Near max capacity t_full, AUTO_INCREMENT = 18446744073709551600, Rows = 1000 -> SHOULD TRIGGER WARNING
                "t_full\tEngine\tVersion\tRow_format\t1000\tAvg_row_length\tData_length\tMax_data_length\tIndex_length\tData_free\t18446744073709551600",
                # Table 3: Low capacity t_low, AUTO_INCREMENT = 5, Rows = 10 -> SHOULD NOT TRIGGER WARNING
                "t_low\tEngine\tVersion\tRow_format\t10\tAvg_row_length\tData_length\tMax_data_length\tIndex_length\tData_free\t5",
            );
        }
        return ();
    };

    MySQLTuner::TestHelper::reset_state();
    $main::opt{'nocolor'} = 1;
    @main::dblist = ("test_db");

    main::check_storage_engines();

    # Verify results
    ok(!exists $main::result{'PctAutoIncrement'}{'test_db.t_empty'}, "test_db.t_empty should be skipped (empty table, AUTO_INCREMENT <= 1)");
    ok(exists $main::result{'PctAutoIncrement'}{'test_db.t_full'}, "test_db.t_full should have capacity calculated");
    ok(exists $main::result{'PctAutoIncrement'}{'test_db.t_low'}, "test_db.t_low should have capacity calculated");
    
    ok(grep(/Table 'test_db.t_full' has an autoincrement value near max capacity/, @bad_prints), "Warning is printed for test_db.t_full");
    ok(!grep(/Table 'test_db.t_empty'/, @bad_prints), "No warning is printed for test_db.t_empty");
    ok(!grep(/Table 'test_db.t_low'/, @bad_prints), "No warning is printed for test_db.t_low");
};

1;
