#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;

# Setup environment for MySQLTuner
$main::is_remote = 0;
$main::mysqlcmd = "mysql";
$main::mysqllogin = "";
$main::remotestring = "";
$main::devnull = File::Spec->devnull();

# Load the script first to get the subroutines
{
    local @ARGV = (); 
    no warnings 'redefine';
    require './mysqltuner.pl';
}

my @mock_output;

# Mock functions
{
    no warnings 'redefine';
    *main::infoprint = sub { push @mock_output, "INFO: $_[0]" };
    *main::badprint = sub { push @mock_output, "BAD: $_[0]" };
    *main::goodprint = sub { push @mock_output, "GOOD: $_[0]" };
    *main::debugprint = sub { push @mock_output, "DEBUG: $_[0]" };
    *main::subheaderprint = sub { push @mock_output, "SUBHEADER: $_[0]" };
    *CORE::GLOBAL::exit = sub { diag "MOCK EXIT CALLED"; };
}

# Mock global variables used by OS setup and calculations
$main::physical_memory = 128 * 1024 * 1024 * 1024; # 128GB
$main::swap_memory = 0;

subtest 'Issue 777 - Incorrect redo log capacity ratio' => sub {
    @main::adjvars = ();
    @main::generalrec = ();
    @mock_output = ();
    
    # Simulate MySQL 8 environment via arr2hash
    # SCENARIO: innodb_redo_log_capacity is present
    my @vars = (
        "have_innodb\tYES",
        "version\t8.0.32",
        "version_comment\tMySQL Community Server - GPL",
        "innodb_redo_log_capacity\t16106127360", # 15G
        "innodb_buffer_pool_size\t64424509440",  # 60G
        "innodb_log_file_size\t100663296",       # 96M
        "innodb_log_files_in_group\t1"
    );
    main::arr2hash(\%main::myvar, \@vars, "\t");
    
    # Reset mycalc to ensure we test the recalculation in mysql_innodb
    $main::mycalc{'innodb_log_size_pct'} = 0;
    $main::mystat{'Uptime'} = 10; # Less than 1 hour to avoid hourly rate logic
    
    # Call the reporting subroutine
    main::mysql_innodb();

    diag "Final innodb_log_size_pct: " . $main::mycalc{'innodb_log_size_pct'};
    
    # VERIFICATION:
    # 1. Ratio should be 25% (Calculated during mysql_innodb)
    is($main::mycalc{'innodb_log_size_pct'}, 25, "Ratio correctly recalculated to 25%");

    # 2. Should NOT have legacy "Ratio" warning because it's MySQL 8.0.32
    ok(!grep({ /Ratio InnoDB redo log capacity/ } @mock_output), "Legacy ratio warning NOT emitted for modern MySQL");
    
    # 3. Should have modern info print
    ok(grep({ /InnoDB Redo Log Capacity is set to 15.0G/ } @mock_output), "Modern redo log capacity info emitted");

    # 4. Prove no more "0.15625%" is seen
    ok(!grep({ /0\.15625/ } @mock_output), "No incorrect ratio reported");
};

done_testing();
