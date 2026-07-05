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
# 1. get_os_release
# =====================================================================
subtest 'get_os_release' => sub {
    reset_mocks();
    my $release = main::get_os_release();
    ok(defined $release && $release ne '', "get_os_release returns some string: $release");
};

# =====================================================================
# 2. is_virtual_machine
# =====================================================================
subtest 'is_virtual_machine' => sub {
    # Case 1: Linux with ssh prefix
    {
        reset_mocks();
        local $^O = 'linux';
        no warnings 'redefine';
        local *main::get_transport_prefix = sub { return 'ssh'; };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            return 1 if $cmd =~ /grep -Ec/;
            return 0;
        };
        is(main::is_virtual_machine(), 1, 'Virtual machine detected via ssh hypervisor grep');
    }
    # Case 2: Linux local check
    {
        reset_mocks();
        local $^O = 'linux';
        no warnings 'redefine';
        local *main::get_transport_prefix = sub { return ''; };
        my $is_vm = main::is_virtual_machine();
        ok(defined $is_vm, 'Local VM detection check executed');
    }
    # Case 3: FreeBSD check
    {
        reset_mocks();
        local $^O = 'freebsd';
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            return "bhyve\n" if $cmd =~ /sysctl/;
            return "none\n";
        };
        is(main::is_virtual_machine(), 1, 'FreeBSD VM detected');
    }
    # Case 4: Windows check
    {
        reset_mocks();
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            return "System Model: Virtual Machine\n";
        };
        is(main::is_virtual_machine(), 1, 'Windows VM model detected');
    }
};

done_testing();
