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
my $script_dir = dirname( abs_path(__FILE__) );
my $script =
  abs_path( File::Spec->catfile( $script_dir, '..', 'mysqltuner.pl' ) );
require $script;
require './tests/MySQLTuner/TestHelper.pm';

# Mock global variables
our %result;
our @dblist;

subtest 'Issue #913: AUTO_INCREMENT capacity warnings by integer type' => sub {
    no warnings 'redefine';

    my @bad_prints;
    my @good_prints;
    my @info_prints;

    local *main::badprint  = sub { push @bad_prints,  $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::infoprint = sub { push @info_prints, $_[0] };

    # Mock select_one to return max int (18446744073709551615)
    local *main::select_one = sub {
        my $query = shift;
        if ( $query =~ /SELECT ~0/ ) {
            return "18446744073709551615";
        }
        return "0";
    };

    # Mock select_array for the new information_schema query
    local *main::select_array = sub {
        my $query = shift;
        if ( $query =~ /SHOW DATABASES/ ) {
            return ("test_db");
        }
        if ( $query =~ /information_schema.ENGINES/ ) {
            return ( "InnoDB\tYES", "MyISAM\tYES" );
        }
        if ( $query =~ /information_schema.TABLES.*information_schema.COLUMNS/ )
        {
            return (
# Table 1: bigint unsigned, AUTO_INCREMENT = 6 (Issue #913 description) -> SHOULD NOT TRIGGER WARNING (0.00%)
                "test_db\tt_bigint_unsigned\t4\t6\tbigint\tbigint(20) unsigned",

# Table 2: tinyint signed, AUTO_INCREMENT = 100 -> SHOULD TRIGGER WARNING (78.74%)
                "test_db\tt_tinyint_signed\t50\t100\ttinyint\ttinyint(4)",

# Table 3: tinyint unsigned, AUTO_INCREMENT = 100 -> SHOULD NOT TRIGGER WARNING (39.22%)
"test_db\tt_tinyint_unsigned\t50\t100\ttinyint\ttinyint(3) unsigned",

# Table 4: int unsigned, AUTO_INCREMENT = 4294967200 -> SHOULD TRIGGER WARNING (100.00%)
"test_db\tt_int_unsigned\t1000\t4294967200\tint\tint(10) unsigned",

# Table 5: int signed, AUTO_INCREMENT = 2147483600 -> SHOULD TRIGGER WARNING (100.00%)
                "test_db\tt_int_signed\t1000\t2147483600\tint\tint(11)",
            );
        }
        return ();
    };

    # Set version so version >= 5.0 check passes
    $main::myvar{'version'} = '8.0.35';

    MySQLTuner::TestHelper::reset_state();
    $main::opt{'nocolor'} = 1;
    @main::dblist = ("test_db");

    main::check_storage_engines();

    # Verify results
    is( $main::result{'PctAutoIncrement'}{'test_db.t_bigint_unsigned'},
        "0.00", "t_bigint_unsigned capacity should be 0.00%" );
    is( $main::result{'PctAutoIncrement'}{'test_db.t_tinyint_signed'},
        "78.74", "t_tinyint_signed capacity should be 78.74%" );
    is( $main::result{'PctAutoIncrement'}{'test_db.t_tinyint_unsigned'},
        "39.22", "t_tinyint_unsigned capacity should be 39.22%" );
    is( $main::result{'PctAutoIncrement'}{'test_db.t_int_unsigned'},
        "100.00", "t_int_unsigned capacity should be 100.00%" );
    is( $main::result{'PctAutoIncrement'}{'test_db.t_int_signed'},
        "100.00", "t_int_signed capacity should be 100.00%" );

    # Verify warnings
    ok( !grep( /Table 'test_db.t_bigint_unsigned'/, @bad_prints ),
        "No warning printed for t_bigint_unsigned" );
    ok(
        grep(
/Table 'test_db.t_tinyint_signed' has an autoincrement value near max capacity \(78.74%\)/,
            @bad_prints ),
        "Warning printed for t_tinyint_signed"
    );
    ok( !grep( /Table 'test_db.t_tinyint_unsigned'/, @bad_prints ),
        "No warning printed for t_tinyint_unsigned" );
    ok(
        grep(
/Table 'test_db.t_int_unsigned' has an autoincrement value near max capacity \(100.00%\)/,
            @bad_prints ),
        "Warning printed for t_int_unsigned"
    );
    ok(
        grep(
/Table 'test_db.t_int_signed' has an autoincrement value near max capacity \(100.00%\)/,
            @bad_prints ),
        "Warning printed for t_int_signed"
    );
};

1;
