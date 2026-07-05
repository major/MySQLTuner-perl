#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempfile);
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Mock environment - set BEFORE require
$main::devnull = '/dev/null';
$main::is_win = 0;
$main::transport_prefix = '';

# Resolve script path portably (works in CI regardless of cwd)
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

# Require the script but prevent it from running itself
{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# Now mock the functions after they are defined in mysqltuner.pl
{
    no warnings 'redefine';
    *main::infoprint = sub { diag "INFO: $_[0]" };
    *main::badprint = sub { diag "BAD: $_[0]" };
    *main::goodprint = sub { diag "GOOD: $_[0]" };
    *main::debugprint = sub { diag "DEBUG: $_[0]" };
    *main::subheaderprint = sub { diag "SUBHEADER: $_[0]" };

    # Prototype-matching mock for is_remote (original has () prototype)
    eval '*main::is_remote = sub () { return 1; };';

    *main::get_transport_prefix = sub { return ''; };
    *main::which = sub { return "/usr/bin/$_[0]"; };
    *main::execute_system_command = sub {
        my ($cmd) = @_;
        diag "MOCK CMD: $cmd";
        if ($cmd =~ /--version/) { return "mariadb-admin version 10.3"; }
        if ($cmd =~ /--print-defaults/) { return ""; }
        if ($cmd =~ /mysqld is alive/) { return "mysqld is alive"; }
        if ($cmd =~ /ping/) { return "mysqld is alive"; }
        if ($cmd =~ /select "mysqld is alive"/) { return "mysqld is alive"; }
        if ($cmd =~ /SELECT VERSION/) { return "10.3.0-MariaDB"; }
        return "mysqld is alive";
    };
}

{
    my ($fh, $filename) = tempfile();
    print $fh "dummy content";
    close($fh);

    # Use mysqlcmd/mysqladmin opts to bypass which+(-x) checks that fail in CI
    local %main::opt = (
        %main::opt,
        'host'       => 'localhost',
        'ssl-ca'     => $filename,
        'user'       => 'root',
        'pass'       => 'root',
        'noask'      => 1,
        'mysqlcmd'   => '/usr/bin/mysql',
        'mysqladmin' => '/usr/bin/mysqladmin',
    );
    # Wrap in eval to catch exit() calls from mysql_setup
    eval { main::mysql_setup(); };
    if ($@ && $@ !~ /EXIT/) {
        diag "mysql_setup died: $@";
    }

    unlink $filename;
}

ok(defined $main::mysqllogin, '$mysqllogin should be defined even with --ssl-ca');
isnt($main::mysqllogin, undef, '$mysqllogin should not be undef');
like($main::mysqllogin, qr/--ssl-ca/, '$mysqllogin should contain --ssl-ca');

done_testing();
