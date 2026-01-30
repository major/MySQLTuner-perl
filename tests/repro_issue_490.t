#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use File::Basename;

# Mock environment
$main::devnull = '/dev/null';
$main::is_win = 0;
$main::transport_prefix = '';
$main::mysqlcmd = 'mysql';
$main::mysqladmincmd = 'mysqladmin';

# Require the script but we need to prevent it from running itself
{
    local @ARGV = (); # Avoid GetOptions parsing from test ARGV
    no warnings 'redefine';
    require './mysqltuner.pl';
}

# Now mock the functions after they are defined in mysqltuner.pl
{
    no warnings 'redefine';
    *main::infoprint = sub { diag "INFO: $_[0]" };
    *main::badprint = sub { diag "BAD: $_[0]" };
    *main::goodprint = sub { diag "GOOD: $_[0]" };
    *main::debugprint = sub { diag "DEBUG: $_[0]" };
    *main::subheaderprint = sub { diag "SUBHEADER: $_[0]" };
    *main::is_remote = sub { return 1; };
    *main::get_transport_prefix = sub { return ''; };
    *main::which = sub { return "/usr/bin/$_[0]"; };
    *main::execute_system_command = sub { 
        my ($cmd) = @_;
        diag "MOCK CMD: $cmd";
        if ($cmd =~ /--version/) { return "mariadb-admin version 10.3"; }
        if ($cmd =~ /--print-defaults/) { return ""; }
        if ($cmd =~ /mysqld is alive/) { return "mysqld is alive"; }
        if ($cmd =~ /ping/) { return "mysqld is alive"; } # mysqladmin ping
        return "mysqld is alive"; 
    };
}

{
    my ($fh, $filename) = tempfile();
    print $fh "dummy content";
    close($fh);
    # Provide user and pass to avoid interactive prompts
    local %main::opt = ( %main::opt, 'host' => 'localhost', 'ssl-ca' => $filename, 'user' => 'root', 'pass' => 'root', 'noask' => 1 );
    main::mysql_setup();
}

ok(defined $main::mysqllogin, '$mysqllogin should be defined even with --ssl-ca');
isnt($main::mysqllogin, undef, '$mysqllogin should not be undef');
like($main::mysqllogin, qr/--ssl-ca/, '$mysqllogin should contain --ssl-ca');

done_testing();
