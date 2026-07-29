#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

# Load MySQLTuner
require './mysqltuner.pl';
require './tests/MySQLTuner/TestHelper.pm';

# Force redefinition of essential subs
no warnings 'redefine';
*main::execute_system_command = sub { return (); };
*main::which                  = sub { return undef; };
*main::infoprint              = sub { };
*main::goodprint             = sub { };
*main::badprint              = sub { };
*main::subheaderprint         = sub { };
*main::debugprint             = sub { };

subtest 'Storage Detection Logic - Issue #957' => sub {
    subtest 'Hardware RAID with rotational=1 defaults to unknown when unconfirmed' => sub {
        my $tmp = tempdir( CLEANUP => 1 );
        make_path("$tmp/sda/queue");
        make_path("$tmp/sda/device");

        open( my $rf, '>', "$tmp/sda/queue/rotational" ) or die $!;
        print $rf "1\n";
        close($rf);

        open( my $df, '>', "$tmp/sda/queue/discard_granularity" ) or die $!;
        print $df "0\n";
        close($df);

        open( my $vf, '>', "$tmp/sda/device/vendor" ) or die $!;
        print $vf "AVAGO\n";
        close($vf);

        open( my $mf, '>', "$tmp/sda/device/model" ) or die $!;
        print $mf "MegaRAID SAS 3108\n";
        close($mf);

        local $ENV{'MYSQLTUNER_SYS_BLOCK_DIR'} = $tmp;

        my $infra = main::detect_infrastructure();
        is( $infra->{'storage_type'}, 'unknown', 'Hardware RAID unconfirmed media defaults to unknown' );
    };

    subtest 'NVMe block device detected as SSD/NVMe' => sub {
        my $tmp = tempdir( CLEANUP => 1 );
        make_path("$tmp/nvme0n1/queue");

        open( my $rf, '>', "$tmp/nvme0n1/queue/rotational" ) or die $!;
        print $rf "0\n";
        close($rf);

        local $ENV{'MYSQLTUNER_SYS_BLOCK_DIR'} = $tmp;

        my $infra = main::detect_infrastructure();
        is( $infra->{'storage_type'}, 'SSD/NVMe', 'NVMe block device correctly detected as SSD/NVMe' );
    };

    subtest 'Discard granularity > 0 detected as SSD/NVMe' => sub {
        my $tmp = tempdir( CLEANUP => 1 );
        make_path("$tmp/sdb/queue");

        open( my $rf, '>', "$tmp/sdb/queue/rotational" ) or die $!;
        print $rf "1\n";
        close($rf);

        open( my $df, '>', "$tmp/sdb/queue/discard_granularity" ) or die $!;
        print $df "512\n";
        close($df);

        local $ENV{'MYSQLTUNER_SYS_BLOCK_DIR'} = $tmp;

        my $infra = main::detect_infrastructure();
        is( $infra->{'storage_type'}, 'SSD/NVMe', 'Device with discard_granularity > 0 detected as SSD/NVMe' );
    };

    subtest 'Standard HDD with rotational=1 detected as HDD' => sub {
        my $tmp = tempdir( CLEANUP => 1 );
        make_path("$tmp/sdc/queue");
        make_path("$tmp/sdc/device");

        open( my $rf, '>', "$tmp/sdc/queue/rotational" ) or die $!;
        print $rf "1\n";
        close($rf);

        open( my $df, '>', "$tmp/sdc/queue/discard_granularity" ) or die $!;
        print $df "0\n";
        close($df);

        open( my $vf, '>', "$tmp/sdc/device/vendor" ) or die $!;
        print $vf "ATA\n";
        close($vf);

        open( my $mf, '>', "$tmp/sdc/device/model" ) or die $!;
        print $mf "WDC WD2003FZEX\n";
        close($mf);

        local $ENV{'MYSQLTUNER_SYS_BLOCK_DIR'} = $tmp;

        my $infra = main::detect_infrastructure();
        is( $infra->{'storage_type'}, 'HDD', 'Standard HDD detected as HDD' );
    };
};

done_testing();
