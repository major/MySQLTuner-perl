#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;

my $script = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..', 'mysqltuner.pl'));

# Mocking and loading mysqltuner.pl
{
    local @ARGV = ();
    # We need to mock some things before requiring if they are called at top level
    no warnings 'redefine';
    no warnings 'once';
    *main::badprint = sub { print "BAD: $_[0]\n" };
    *main::goodprint = sub { print "GOOD: $_[0]\n" };
    *main::debugprint = sub { print "DEBUG: $_[0]\n" };
    *main::infoprint = sub { print "INFO: $_[0]\n" };
    *main::which = sub { return "/bin/sh" }; # Something that definitely exists and is executable
    *main::is_remote = sub { return 0 };
    
    require $script;
}

my @commands_executed;
{
    no warnings 'redefine';
    no warnings 'once';
    *main::execute_system_command = sub {
        my ($cmd) = @_;
        push @commands_executed, $cmd;
        if ($cmd =~ /--print-defaults/) {
            return "mysql --defaults-file=/tmp/my.cnf";
        }
        if ($cmd =~ /ping/ || $cmd =~ /select "mysqld is alive"/) {
            # Check if our expected faulty behavior is happening
            # Currently it will NOT have --defaults-file if it has -u/-p
            if ($cmd =~ /--defaults-file/ && $cmd =~ /-u tuneruser/ && $cmd =~ /-p'tunerpass'/) {
                return "mysqld is alive";
            }
            return "failed to connect";
        }
        return "";
    };
}

# Initialize some global variables that mysql_setup expects
$main::mysqladmincmd = "/bin/sh";
$main::mysqlcmd = "/bin/sh";
$main::is_win = 0;
$main::remotestring = "";
$main::doremote = 0;
$main::devnull = "/dev/null";
foreach my $o (keys %main::CLI_METADATA) {
    my ($p) = split /\|/, $o;
    $p =~ s/[!+=:].*$//;
    $main::opt{$p} //= $main::CLI_METADATA{$o}->{default} // '0';
}
$main::opt{nobad} = 0;
$main::bad = "[!!]";

subtest 'Issue 605 - --defaults-file should allow --user and --pass' => sub {
    @commands_executed = ();
    %main::opt = (
        %main::opt,
        'defaults-file' => '/tmp/my.cnf',
        'user' => 'tuneruser',
        'pass' => 'tunerpass',
        'host' => '0',
        'port' => 3306,
        'mysqladmin' => '/bin/sh',
        'mysqlcmd' => '/bin/sh',
        'defaults-extra-file' => '0',
        'noask' => 1,
    );
    
    # We need to simulate that the file exists and is readable
    # In mysql_setup: if ( $opt{'defaults-file'} and -r "$opt{'defaults-file'}" )
    # Since we can't easily mock -r, we might need to create the file or mock the check.
    
    open my $fh, '>', '/tmp/my.cnf' or die "Could not create /tmp/my.cnf";
    print $fh "[client]\nuser=ignored\n";
    close $fh;

    # We need to mock execute_system_command to return "mysqld is alive" when it receives the correct command
    {
        no warnings 'redefine';
        *main::execute_system_command = sub {
            my ($cmd) = @_;
            push @commands_executed, $cmd;
            if ($cmd =~ /--defaults-file=\/tmp\/my.cnf/ && $cmd =~ /-u tuneruser/ && $cmd =~ /-p'tunerpass'/) {
                return "mysqld is alive";
            }
            if ($cmd =~ /--print-defaults/) { return "mysql --defaults-file=/tmp/my.cnf"; }
            return "failed";
        };
    }

    # Now call mysql_setup
    eval { main::mysql_setup(); };
    
    my $found = grep { /--defaults-file=["']?\/tmp\/my.cnf["']?/ && /-u tuneruser/ && /-p'tunerpass'/ } @commands_executed;
    ok($found, "mysql_setup should have tried to login using defaults-file AND user/pass");
    
    unless ($found) {
        diag "Commands tried:";
        diag $_ for @commands_executed;
    }
    
    unlink '/tmp/my.cnf';
};

subtest 'Issue 605 - --defaults-extra-file should allow --user and --pass' => sub {
    @commands_executed = ();
    %main::opt = (
        %main::opt,
        'defaults-file' => '0',
        'defaults-extra-file' => '/tmp/extra.cnf',
        'user' => 'tuneruser',
        'pass' => 'tunerpass',
        'host' => '0',
        'port' => 3306,
        'mysqladmin' => '/bin/sh',
        'mysqlcmd' => '/bin/sh',
        'noask' => 1,
    );
    
    open my $fh, '>', '/tmp/extra.cnf' or die "Could not create /tmp/extra.cnf";
    print $fh "[client]\nuser=ignored\n";
    close $fh;

    # Mock success for combined command
    {
        no warnings 'redefine';
        *main::execute_system_command = sub {
            my ($cmd) = @_;
            push @commands_executed, $cmd;
            if ($cmd =~ /--defaults-extra-file=["']?\/tmp\/extra.cnf["']?/ && $cmd =~ /-u tuneruser/ && $cmd =~ /-p'tunerpass'/) {
                return "mysqld is alive";
            }
            if ($cmd =~ /--print-defaults/) { return "mysql --defaults-extra-file=/tmp/extra.cnf"; }
            return "failed";
        };
    }

    eval { main::mysql_setup(); };
    
    my $found = grep { /--defaults-extra-file=["']?\/tmp\/extra.cnf["']?/ && /-u tuneruser/ && /-p'tunerpass'/ } @commands_executed;
    ok($found, "mysql_setup should have tried to login using defaults-extra-file AND user/pass");
    
    unless ($found) {
        diag "Commands tried:";
        diag $_ for @commands_executed;
    }
    
    unlink '/tmp/extra.cnf';
};

done_testing();
