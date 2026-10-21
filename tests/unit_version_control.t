#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_version_control.t
# Description: Unit tests validating database engine version control and
#              EOL/LTS support validation (MySQL & MariaDB).
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
no warnings 'once';
use Test::More;
use FindBin;
use File::Spec;

# Load mysqltuner.pl
{
    local @ARGV = ();
    no warnings 'redefine';
    require File::Spec->catfile( $FindBin::Bin, '..', 'mysqltuner.pl' );
}

# Capture mock outputs
my @mock_good;
my @mock_bad;
my @mock_info;
{
    no warnings 'redefine';
    *main::goodprint   = sub { push @mock_good, $_[0] };
    *main::badprint    = sub { push @mock_bad,  $_[0] };
    *main::infoprint   = sub { push @mock_info, $_[0] };
    *main::debugprint  = sub { };
    *main::prettyprint = sub { };
}

sub reset_state {
    @mock_good        = ();
    @mock_bad         = ();
    @mock_info        = ();
    @main::generalrec = ();
    %main::myvar      = ();
}

# --- Subtest 1: Supported MySQL Versions Control ---
subtest 'Supported MySQL Versions Control' => sub {
    plan tests => 6;

    my @supported_mysql = (
        '8.0.35',
        '8.0.40',
        '8.4.0',
        '8.4.1',
        '9.7.0',
        '9.7.1',
    );

    for my $ver (@supported_mysql) {
        reset_state();
        $main::myvar{'version'} = $ver;
        main::validate_mysql_version();

        ok(
            grep( { /Currently running supported MySQL\/MariaDB version/ } @mock_good ),
            "MySQL $ver is validated as supported"
        );
    }
};

# --- Subtest 2: Supported MariaDB Versions Control ---
subtest 'Supported MariaDB Versions Control' => sub {
    plan tests => 6;

    my @supported_mariadb = (
        '10.11.8-MariaDB',
        '11.4.2-MariaDB',
        '11.8.1-MariaDB',
        '12.3.1-MariaDB',
        '13.0.0-MariaDB',
        '13.0.1-MariaDB',
    );

    for my $ver (@supported_mariadb) {
        reset_state();
        $main::myvar{'version'} = $ver;
        main::validate_mysql_version();

        ok(
            grep( { /Currently running supported MySQL\/MariaDB version/ } @mock_good ),
            "MariaDB $ver is validated as supported"
        );
    }
};

# --- Subtest 3: Unsupported / Outdated Versions Control ---
subtest 'Unsupported and EOL Versions Control' => sub {
    plan tests => 8;

    my @unsupported = (
        '5.5.62',
        '5.6.51',
        '5.7.44',
        '8.1.0',
        '8.2.0',
        '8.3.0',
        '9.5.0',
        '9.6.0',
    );

    for my $ver (@unsupported) {
        reset_state();
        $main::myvar{'version'} = $ver;
        main::validate_mysql_version();

        ok(
            grep( { /is EOL software\. Upgrade soon!/ } @mock_bad ) &&
            grep( { /unsupported version for production environments/ } @main::generalrec ),
            "Version $ver is flagged as EOL with production upgrade recommendation"
        );
    }
};

# --- Subtest 4: Edge Cases & Uninitialized Safety ---
subtest 'Edge Cases and Undefined Safety' => sub {
    plan tests => 4;

    # Case 1: Undefined version
    reset_state();
    $main::myvar{'version'} = undef;
    eval { main::validate_mysql_version(); };
    is( $@, '', "validate_mysql_version handles undef without dying" );
    is( scalar(@mock_good) + scalar(@mock_bad), 0, "No output on undef version" );

    # Case 2: Complex distribution string with suffix
    reset_state();
    $main::myvar{'version'} = '11.4.2-MariaDB-1:11.4.2+maria~ubu2404-log';
    main::validate_mysql_version();
    ok(
        grep( { /Currently running supported MySQL\/MariaDB version/ } @mock_good ),
        "Handles MariaDB version with package and OS suffix"
    );

    # Case 3: Empty string
    reset_state();
    $main::myvar{'version'} = '';
    eval { main::validate_mysql_version(); };
    is( $@, '', "validate_mysql_version handles empty string without dying" );
};

# --- Subtest 5: Version Helpers Boundary Control ---
subtest 'Version Helpers Boundary Control' => sub {
    plan tests => 7;

    $main::myvar{'version'} = '13.0.1-MariaDB';

    ok( main::mysql_version_eq(13),           "mysql_version_eq(13) matches 13.0.1" );
    ok( main::mysql_version_eq(13, 0),        "mysql_version_eq(13, 0) matches 13.0.1" );
    ok( main::mysql_version_eq(13, 0, 1),     "mysql_version_eq(13, 0, 1) matches 13.0.1" );
    ok( !main::mysql_version_eq(13, 1),       "mysql_version_eq(13, 1) does not match 13.0.1" );

    ok( main::mysql_version_ge(13, 0),        "13.0.1 is ge 13.0" );
    ok( main::mysql_version_ge(10, 11),       "13.0.1 is ge 10.11" );
    ok( !main::mysql_version_ge(14, 0),       "13.0.1 is not ge 14.0" );
};

# --- Subtest 6: Support Label (LTS vs Short-Term) ---
subtest 'Support Label LTS vs Short-Term' => sub {
    plan tests => 5;

    for my $ver ( '8.4.1', '12.3.1-MariaDB' ) {
        reset_state();
        $main::myvar{'version'} = $ver;
        main::validate_mysql_version();
        like( $mock_good[0] // '', qr/\Q$ver\E \(LTS\)$/, "$ver is labelled (LTS)" );
    }

    for my $ver ( '13.0.0-MariaDB', '13.0.2-MariaDB', '26.7.0' ) {
        reset_state();
        $main::myvar{'version'} = $ver;
        main::validate_mysql_version();
        like( $mock_good[0] // '', qr/\Q$ver\E \(short-term support\)$/,
            "$ver is labelled (short-term support), not LTS" );
    }
};

done_testing();
