#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Declare globals before loading script
our @adjvars;
our @generalrec;
our @modeling;
our @sysrec;
our @secrec;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;
our $mysqlcmd;

my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

my @mock_output;
sub reset_mocks {
    @mock_output = ();
    @main::generalrec = ();
    @main::adjvars = ();
    @main::modeling = ();
    @main::sysrec = ();
    @main::secrec = ();
    %main::result = ();
    %main::opt = ();
    %main::myvar = ();
}

{
    no warnings 'redefine';
    *main::infoprint       = sub { push @mock_output, "INFO: $_[0]" };
    *main::badprint        = sub { push @mock_output, "BAD: $_[0]" };
    *main::goodprint       = sub { push @mock_output, "GOOD: $_[0]" };
    *main::debugprint      = sub { };
    *main::subheaderprint  = sub { push @mock_output, "HEADER: $_[0]" };
    *main::prettyprint     = sub { push @mock_output, "PRETTY: $_[0]" };
}

# =====================================================================
# 1. get_tuning_info
# =====================================================================
subtest 'get_tuning_info' => sub {
    reset_mocks();
    no warnings 'redefine';
    local *main::select_array = sub {
        return (
            "   Connection: localhost via UNIX socket\n",
            "   Server: Localhost via UNIX socket\n",
        );
    };
    main::get_tuning_info();
    is($result{'MySQL Client'}{'Connection'}, 'localhost via UNIX socket', 'parsed client connection');
    is($result{'MySQL Client'}{'Client Path'}, $mysqlcmd, 'Client Path set');
};

# =====================================================================
# 2. check_privileges
# =====================================================================
subtest 'check_privileges' => sub {
    # Case 1: ALL PRIVILEGES
    {
        reset_mocks();
        no warnings 'redefine';
        local *main::select_array = sub { return ("GRANT ALL PRIVILEGES ON *.* TO 'root'\@'localhost'"); };
        main::check_privileges();
        is(scalar @mock_output, 0, 'No warning output when ALL PRIVILEGES present');
    }
    # Case 2: SUPER privilege
    {
        reset_mocks();
        no warnings 'redefine';
        local *main::select_array = sub { return ("GRANT SUPER ON *.* TO 'root'\@'localhost'"); };
        main::check_privileges();
        is(scalar @mock_output, 0, 'No warning output when SUPER present');
    }
    # Case 3: Missing privileges on MySQL 8.0
    {
        reset_mocks();
        $main::myvar{'version'} = '8.0.35';
        no warnings 'redefine';
        local *main::select_array = sub { return ("GRANT SELECT, PROCESS ON *.* TO 'user'\@'localhost'"); };
        local *main::mysql_version_ge = sub { return 1; };
        main::check_privileges();
        ok(grep({ /missing the following privileges/ } @mock_output), 'Warning print on missing privileges');
    }
    # Case 4: Missing privileges on MariaDB 10.5
    {
        reset_mocks();
        $main::myvar{'version'} = '10.5.25-MariaDB';
        no warnings 'redefine';
        local *main::select_array = sub { return ("GRANT SELECT, PROCESS ON *.* TO 'user'\@'localhost'"); };
        local *main::mysql_version_ge = sub {
            my ($major, $minor) = @_;
            return 1 if $major == 10 && $minor == 5;
            return 0;
        };
        main::check_privileges();
        ok(grep({ /missing the following privileges/ } @mock_output), 'Warning print on missing MariaDB privileges');
    }
};

done_testing();
