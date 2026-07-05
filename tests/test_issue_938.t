#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
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

subtest 'Issue 938 - InnoDB Write Log efficiency gated on waits' => sub {
    # Case 1: Write efficiency < 90% but log waits = 0
    @main::adjvars = ();
    @main::generalrec = ();
    @mock_output = ();

    $main::myvar{'have_innodb'} = 'YES';
    $main::myvar{'innodb_version'} = '11.8.8';
    $main::myvar{'innodb_log_buffer_size'} = 16 * 1024 * 1024;

    $main::mystat{'Innodb_log_write_requests'} = 1000;
    $main::mystat{'Innodb_log_writes'} = 200; # 80% efficiency
    $main::mystat{'Innodb_log_waits'} = 0; # 0 waits

    $main::mycalc{'pct_write_efficiency'} = main::percentage(
        ( $main::mystat{'Innodb_log_write_requests'} - $main::mystat{'Innodb_log_writes'} ),
        $main::mystat{'Innodb_log_write_requests'}
    );

    main::mysql_innodb();

    ok(grep(/GOOD: InnoDB Write Log efficiency/, @mock_output), "Prints write efficiency as GOOD when log waits are 0");
    ok(!grep(/BAD: InnoDB Write Log efficiency/, @mock_output), "Does not print write efficiency as BAD when log waits are 0");
    my $rec = (grep { /innodb_log_buffer_size/ } @main::adjvars)[0];
    ok(!$rec, "No recommendation for innodb_log_buffer_size when log waits are 0");

    # Case 2: Write efficiency < 90% and log waits > 0
    @main::adjvars = ();
    @main::generalrec = ();
    @mock_output = ();

    $main::mystat{'Innodb_log_write_requests'} = 1000;
    $main::mystat{'Innodb_log_writes'} = 200; # 80% efficiency
    $main::mystat{'Innodb_log_waits'} = 10; # >0 waits

    $main::mycalc{'pct_write_efficiency'} = main::percentage(
        ( $main::mystat{'Innodb_log_write_requests'} - $main::mystat{'Innodb_log_writes'} ),
        $main::mystat{'Innodb_log_write_requests'}
    );

    main::mysql_innodb();

    ok(grep(/BAD: InnoDB Write Log efficiency/, @mock_output), "Prints write efficiency as BAD when log waits are > 0");
    my $rec_with_waits = (grep { /innodb_log_buffer_size/ } @main::adjvars)[0];
    ok($rec_with_waits, "Recommends innodb_log_buffer_size when log waits are > 0");
};

done_testing();
