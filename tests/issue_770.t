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

subtest 'Issue 770 - Incorrect innodb_log_file_size recommendation' => sub {
    @main::adjvars = ();
    @main::generalrec = ();
    @mock_output = ();
    
    # Simulate user environment from #770
    $main::myvar{'have_innodb'} = 'YES';
    $main::myvar{'innodb_version'} = '10.11.6';
    $main::myvar{'innodb_buffer_pool_size'} = 6.0 * 1024 * 1024 * 1024;
    $main::myvar{'innodb_log_file_size'} = 1073741824;
    $main::myvar{'innodb_log_files_in_group'} = 1;

    # Pre-calculate ratio as mysql_innodb expects it
    $main::mycalc{'innodb_log_size_pct'} = 16.67;

    # Call the subroutine
    main::mysql_innodb();

    # Before fix, it should erroneously say (=1G)
    # Actually, let's just assert it is present in @adjvars
    my $rec = (grep { /innodb_log_file_size should be/ } @main::adjvars)[0];
    ok($rec, "Recommendation for innodb_log_file_size found");
    diag "Found recommendation: $rec";
    
    # Reproduction: recommendation says (=1G) instead of (=1.5G)
    like($rec, qr/should be \(=1.5G\)/, "Verification: accurately recommends 1.5G (no truncation)");
};

done_testing();
