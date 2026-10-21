#!/usr/bin/env perl
# Regression: which() returns 0 for a missing binary; `-x "0"` is true when
# the current directory contains an entry named "0", which made
# detect_infrastructure() execute "0 -d ::0104" (lspci) or "0 /c0 show all"
# (storcli) and print "System command failed ... sh: 1: 0: not found".
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Cwd qw(getcwd);

require './mysqltuner.pl';

no warnings 'redefine';
my @commands;
*main::execute_system_command = sub { push @commands, $_[0]; return (); };
*main::which                  = sub { return 0; };    # real "not found" value
*main::infoprint              = sub { };
*main::goodprint              = sub { };
*main::badprint               = sub { };
*main::subheaderprint         = sub { };
*main::debugprint             = sub { };

# Fake /sys/block with a hardware RAID volume (rotational, no discard) so the
# storcli/megacli helper branch is reached as well.
sub make_raid_sys_block {
    my $tmp = tempdir( CLEANUP => 1 );
    make_path( "$tmp/sda/queue", "$tmp/sda/device" );
    my %files = (
        'sda/queue/rotational'          => "1\n",
        'sda/queue/discard_granularity' => "0\n",
        'sda/device/vendor'             => "AVAGO\n",
        'sda/device/model'              => "MegaRAID SAS 3108\n",
    );
    for my $f ( keys %files ) {
        open( my $fh, '>', "$tmp/$f" ) or die $!;
        print $fh $files{$f};
        close($fh);
    }
    return $tmp;
}

subtest 'Missing lspci/storcli with a "0" entry in the CWD' => sub {
    my $cwd_dir = tempdir( CLEANUP => 1 );
    make_path("$cwd_dir/0");
    ok( -x "$cwd_dir/0", 'precondition: "0" directory is -x' );

    local $ENV{'MYSQLTUNER_SYS_BLOCK_DIR'} = make_raid_sys_block();
    my $orig = getcwd();
    chdir $cwd_dir or die $!;
    @commands = ();
    my $infra = main::detect_infrastructure();
    chdir $orig or die $!;

    ok( defined $infra, 'detect_infrastructure returned a result' );
    my @bogus = grep { /^0\s/ } @commands;
    is( scalar @bogus, 0, 'no command executed with "0" as binary' )
      or diag explain \@bogus;
};

subtest 'Missing lspci/storcli in a clean CWD' => sub {
    local $ENV{'MYSQLTUNER_SYS_BLOCK_DIR'} = make_raid_sys_block();
    @commands = ();
    main::detect_infrastructure();
    is( scalar( grep { /^0\s/ } @commands ),
        0, 'no command executed with "0" as binary' );
};

done_testing();
