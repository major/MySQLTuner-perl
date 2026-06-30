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
# 1. infoprintcmd & infoprinthcmd
# =====================================================================
subtest 'infoprintcmd & infoprinthcmd' => sub {
    reset_mocks();
    my @cmd_prints;
    my @info_prints;
    my @header_prints;
    no warnings 'redefine';
    local *main::cmdprint = sub { push @cmd_prints, $_[0] };
    local *main::infoprintml = sub { push @info_prints, @_ };
    local *main::subheaderprint = sub { push @header_prints, $_[0] };
    
    main::infoprintcmd("echo 'test_infoprintcmd'");
    is(scalar @cmd_prints, 1, 'cmdprint called once');
    like($cmd_prints[0], qr/echo 'test_infoprintcmd'/, 'cmdprint received command');
    ok(grep({ /test_infoprintcmd/ } @info_prints), 'infoprintml printed output of command');
    
    main::infoprinthcmd("My Header", "echo 'test_infoprinthcmd'");
    is($header_prints[0], "My Header", 'subheaderprint called with header');
    like($cmd_prints[1], qr/echo 'test_infoprinthcmd'/, 'infoprintcmd called inside infoprinthcmd');
};

# =====================================================================
# 2. cloud_setup
# =====================================================================
subtest 'cloud_setup' => sub {
    # Case 1: direct connection mode
    {
        reset_mocks();
        $main::opt{cloud} = 1;
        $main::opt{'ssh-host'} = undef;
        $main::opt{forcemem} = 0;
        main::cloud_setup();
        is($main::opt{cloud}, 1, 'cloud is 1');
        is($main::opt{nosysstat}, 1, 'nosysstat is set to 1 in direct mode');
        is($main::opt{forcemem}, 1024, 'forcemem defaults to 1024');
    }
    # Case 2: ssh connection mode with command outputs
    {
        reset_mocks();
        $main::opt{cloud} = 1;
        $main::opt{'ssh-host'} = 'my-remote-db';
        $main::opt{forcemem} = 0;
        $main::opt{forceswap} = 0;
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /uname/) {
                return "Linux remote-host 5.4.0\n";
            }
            elsif ($cmd =~ /MemTotal/) {
                return "MemTotal:        4194304 kB\n"; # 4GB
            }
            elsif ($cmd =~ /SwapTotal/) {
                return "SwapTotal:       2097152 kB\n"; # 2GB
            }
            return "";
        };
        main::cloud_setup();
        is($main::opt{forcemem}, 4096, 'remote memory detected and set');
        is($main::opt{forceswap}, 2048, 'remote swap detected and set');
    }
    # Case 3: ssh connection mode but commands fail (default fallback)
    {
        reset_mocks();
        $main::opt{cloud} = 1;
        $main::opt{'ssh-host'} = 'my-remote-db';
        $main::opt{forcemem} = 0;
        $main::opt{forceswap} = 0;
        no warnings 'redefine';
        local *main::execute_system_command = sub { return (); };
        main::cloud_setup();
        is($main::opt{forcemem}, 1024, 'forcemem fallback to 1024');
        is($main::opt{forceswap}, 0, 'forceswap fallback to 0');
    }
};

done_testing();
