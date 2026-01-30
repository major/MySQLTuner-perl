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
my $mock_login_success = 0;

# Mock functions
{
    no warnings 'redefine';
    *main::infoprint = sub { diag "MOCK INFO: $_[0]"; push @mock_output, "INFO: $_[0]" };
    *main::badprint = sub { diag "MOCK BAD: $_[0]"; push @mock_output, "BAD: $_[0]" };
    *main::goodprint = sub { diag "MOCK GOOD: $_[0]"; push @mock_output, "GOOD: $_[0]" };
    *main::debugprint = sub { diag "MOCK DEBUG: $_[0]"; push @mock_output, "DEBUG: $_[0]" };
    *main::subheaderprint = sub { diag "MOCK SUBHEADER: $_[0]"; push @mock_output, "SUBHEADER: $_[0]" };
    *main::prettyprint = sub { };

    # Mock execute_system_command to simulate login success/failure
    *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /select "mysqld is alive"/) {
            return $mock_login_success ? "mysqld is alive" : "";
        }
        return "";
    };

    # Mock select_one and select_array to avoid DB connection
    *main::select_one = sub { return 0; };
    *main::select_array = sub { return (); };
}

sub has_output {
    my ($pattern) = @_;
    return grep { $_ =~ /$pattern/ } @mock_output;
}

subtest 'Socket Authentication detection' => sub {
    # 1. Create a temporary password file
    my $pw_file = "tests/mock_passwords.txt";
    open(my $fh, ">", $pw_file) or die $!;
    print $fh "weak123\n";
    close($fh);

    # 2. Case: Socket Auth Enabled (login succeeds with ANY password)
    @main::generalrec = ();
    @mock_output = ();
    $main::basic_password_files = $pw_file;
    $main::myvar{'version'} = "10.11.0-MariaDB"; # Modern version
    $main::myvar{'version_comment'} = "MariaDB";
    $mock_login_success = 1; # Any login attempt succeeds

    main::security_recommendations();

    ok(has_output(qr/INFO: Authentication plugin allows access without a valid password for user 'root'\. Skipping dictionary check\./), 
       'Detected socket-like authentication and skipped dictionary check');
    ok(!has_output(qr/User 'root' is using weak password/), 'No weak password warning for root with socket auth');

    # 3. Case: Socket Auth Disabled (login succeeds only with correct password - which we don't have)
    @main::generalrec = ();
    @mock_output = ();
    $mock_login_success = 0; # Login attempts fail

    main::security_recommendations();

    ok(!has_output(qr/Authentication plugin allows access/), 'Socket auth not detected when login fails');
    
    # Optional: Test that we still catch weak passwords if we mock a successful first login with a dictionary entry
    # But for now, the priority is verifying it SKIPS when it detects success with RA-ND-OM.

    unlink($pw_file);
};

done_testing();
