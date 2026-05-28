#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;

my $script = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..', 'mysqltuner.pl'));

# Mocking and loading mysqltuner.pl
{
    local @ARGV = ();
    require $script;
}

{
    no warnings 'redefine';
    no warnings 'once';
    *main::badprint = sub { print "BAD: $_[0]\n" };
    *main::goodprint = sub { print "GOOD: $_[0]\n" };
    *main::debugprint = sub { print "DEBUG: $_[0]\n" };
    *main::infoprint = sub { print "INFO: $_[0]\n" };
    *main::which = sub {
        my ($cmd) = @_;
        return "/bin/sh" if $cmd =~ /mysql|mariadb/;
        return undef;
    };
    *main::is_remote = sub () { return 0 };
}

my @commands_executed;
{
    no warnings 'redefine';
    no warnings 'once';
    *main::execute_system_command = sub {
        my ($cmd) = @_;
        push @commands_executed, $cmd;
        if ($cmd =~ /select "mysqld is alive"/) {
            return "mysqld is alive";
        }
        return "";
    };
}

$main::mysqladmincmd = "/bin/sh";
$main::mysqlcmd = "/bin/sh";
$main::is_win = 0;
$main::remotestring = "";
$main::doremote = 0;
$main::devnull = "/dev/null";

# Initialize options
foreach my $o (keys %main::CLI_METADATA) {
    my ($p) = split /\|/, $o;
    $p =~ s/[!+=:].*$//;
    $main::opt{$p} //= $main::CLI_METADATA{$o}->{default};
}

subtest 'Issue 781 - Only --pass specified defaults to -u root' => sub {
    @commands_executed = ();
    %main::opt = (
        %main::opt,
        'user' => undef,
        'pass' => 'somepass',
        'noask' => 1,
    );

    eval { main::mysql_setup(); };

    my $found = grep { /-u root/ && /-p'somepass'/ } @commands_executed;
    ok($found, "mysql_setup should connect with -u root when only --pass is set");
    diag "Commands tried: " . join(", ", @commands_executed) unless $found;
};

subtest 'Issue 781 - Passwords with single quotes are escaped' => sub {
    @commands_executed = ();
    %main::opt = (
        %main::opt,
        'user' => 'tuneruser',
        'pass' => "my'pass'word",
        'noask' => 1,
    );

    eval { main::mysql_setup(); };

    my $found = grep { /-u tuneruser/ && /-p'my'\\''pass'\\''word'/ } @commands_executed;
    ok($found, "mysql_setup should escape single quotes in passwords");
    diag "Commands tried: " . join(", ", @commands_executed) unless $found;
};

subtest 'Issue 781 - Passwords with complex characters' => sub {
    @commands_executed = ();
    %main::opt = (
        %main::opt,
        'user' => 'tuneruser',
        'pass' => 'J-GHs[Rx.6[Ggdfaqe8Ay',
        'noask' => 1,
    );

    eval { main::mysql_setup(); };

    my $found = grep { /-u tuneruser/ && /-p'J-GHs\[Rx\.6\[Ggdfaqe8Ay'/ } @commands_executed;
    ok($found, "mysql_setup should pass complex characters inside single quotes");
    diag "Commands tried: " . join(", ", @commands_executed) unless $found;
};

done_testing();
