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
    *main::prettyprint = sub { };
}

sub has_output {
    my ($pattern) = @_;
    return grep { $_ =~ /$pattern/ } @mock_output;
}

subtest 'Issue 783 - Persistent innodb_log_buffer_size recommendation' => sub {
    @main::adjvars = ();
    @main::generalrec = ();
    @mock_output = ();
    
    # Simulate a fresh/idle MariaDB install (0 requests)
    $main::myvar{'have_innodb'} = 'YES';
    $main::myvar{'innodb_version'} = '11.3.2';
    $main::myvar{'innodb_log_buffer_size'} = 64 * 1024 * 1024;
    
    # 0 requests
    $main::mystat{'Innodb_log_write_requests'} = 0;
    $main::mystat{'Innodb_log_writes'} = 0;
    $main::mystat{'Innodb_log_waits'} = 0;

    # The actual script calculates these in a loop/subroutine, but for testing we can pre-set
    # Actually, let's call the calculations subroutine or simulate it.
    
    # Calculate pct_write_efficiency using the script's function
    $main::mycalc{'pct_write_efficiency'} = main::percentage(
        ( $main::mystat{'Innodb_log_write_requests'} - $main::mystat{'Innodb_log_writes'} ),
        $main::mystat{'Innodb_log_write_requests'}
    );

    diag "Calculated pct_write_efficiency for (0,0): " . $main::mycalc{'pct_write_efficiency'};
    
    # Call the reporting subroutine
    main::mysql_innodb();

    # After fix, it should have 100.00% efficiency and NO recommendation
    my $rec = (grep { /innodb_log_buffer_size/ } @main::adjvars)[0];
    ok(!$rec, "No recommendation for innodb_log_buffer_size on idle server (Verification after fix)");
    diag "Found recommendation (SHOULD BE EMPTY): $rec" if $rec;
    
    is($main::mycalc{'pct_write_efficiency'}, '100.00', "Verification: pct_write_efficiency is 100.00 for (0,0)");
};

done_testing();
