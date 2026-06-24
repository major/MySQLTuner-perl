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
# 1. get_fs_info & get_fs_info_win
# =====================================================================
subtest 'get_fs_info' => sub {
    reset_mocks();
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /df -P/) {
            return (
                "Filesystem      1024-blocks      Used Available Capacity Mounted on\n",
                "/dev/sda1          10485760   9437184   1048576      90% /\n", # >85%
                "/dev/sda2          10485760   5242880   5242880      50% /home\n", # <=85%
            );
        }
        elsif ($cmd =~ /df -Pi/) {
            return (
                "Filesystem            Inodes   IUsed     IFree IUse% Mounted on\n",
                "/dev/sda1            1000000  900000    100000   90% /\n", # >85%
                "/dev/sda2            1000000  500000    500000   50% /home\n", # <=85%
            );
        }
        return ();
    };
    main::get_fs_info();
    is($result{'Filesystem'}{'Space Pct'}{'/'}, 90, 'root Space Pct parsed');
    is($result{'Filesystem'}{'Space Pct'}{'/home'}, 50, 'home Space Pct parsed');
    is($result{'Filesystem'}{'Inode Pct'}{'/'}, 90, 'root Inode Pct parsed');
    ok(grep({ /mount point \/ is using 90 % total space/ } @mock_output), 'warning on high disk usage printed');
    ok(grep({ /mount point \/ is using 90 % of max allowed inodes/ } @mock_output), 'warning on high inode usage printed');
};

subtest 'get_fs_info_win' => sub {
    reset_mocks();
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        return (
            "FreeSpace  Name  Size\n",
            "1073741824  C:    10737418240\n", # 90% used
            "5368709120  D:    10737418240\n", # 50% used
        );
    };
    main::get_fs_info_win();
    is($result{'Filesystem'}{'Space Pct'}{'C:'}, 90, 'Disk C Space Pct parsed');
    is($result{'Filesystem'}{'Space Pct'}{'D:'}, 50, 'Disk D Space Pct parsed');
    ok(grep({ /Disk C: is using 90 % total space/ } @mock_output), 'warning on high windows disk usage printed');
};

done_testing();
