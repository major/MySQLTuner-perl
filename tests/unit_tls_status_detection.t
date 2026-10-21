#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_tls_status_detection.t
# Description: Validates server TLS detection without have_ssl (removed in
#              MySQL 8.4.0) via Ssl_cipher and performance_schema.tls_channel_status
#              (PI-023: false "TLS/SSL is disabled" on MySQL 8.4+/9.x).
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
no warnings 'once';
use Test::More;
use FindBin;
use File::Spec;

{
    local @ARGV = ();
    no warnings 'redefine';
    require File::Spec->catfile( $FindBin::Bin, '..', 'mysqltuner.pl' );
}

my ( @good, @bad, @info, @queries );
my %answers;
{
    no warnings 'redefine';
    *main::goodprint          = sub { push @good, $_[0] };
    *main::badprint           = sub { push @bad,  $_[0] };
    *main::infoprint          = sub { push @info, $_[0] };
    *main::debugprint         = sub { };
    *main::subheaderprint     = sub { };
    *main::push_recommendation = sub { };
    *main::select_one         = sub {
        my $q = shift;
        push @queries, $q;
        return $answers{cipher}  if $q =~ /Ssl_cipher/;
        return $answers{channel} if $q =~ /tls_channel_status/;
        return '';
    };
}

sub reset_state {
    my (%args) = @_;
    @good = @bad = @info = @queries = ();
    %answers           = ( cipher => "Ssl_cipher\t", channel => '', %{ $args{answers} || {} } );
    %main::myvar       = %{ $args{myvar} || {} };
    $main::is_local_only = $args{local} // 0;
}

subtest 'compute_server_tls_status (pure)' => sub {
    plan tests => 10;
    is( main::compute_server_tls_status('YES'),      1, 'have_ssl=YES => enabled' );
    is( main::compute_server_tls_status('ON'),       1, 'have_ssl=ON => enabled' );
    is( main::compute_server_tls_status('DISABLED'), 0, 'have_ssl=DISABLED => disabled' );
    is( main::compute_server_tls_status('NO'),       0, 'have_ssl=NO => disabled' );
    is( main::compute_server_tls_status( 'DISABLED', 'TLS_AES_256_GCM_SHA384' ),
        0, 'have_ssl has priority over session cipher' );
    is( main::compute_server_tls_status( undef, 'TLS_AES_128_GCM_SHA256' ),
        1, 'no have_ssl + session cipher => enabled' );
    is( main::compute_server_tls_status( undef, 'NULL', 'Yes' ),
        1, 'cipher NULL ignored, channel Enabled=Yes => enabled' );
    is( main::compute_server_tls_status( undef, '', 'No' ), 0, 'channel Enabled=No => disabled' );
    ok( !defined main::compute_server_tls_status( undef, '', '' ), 'no signal => undef' );
    ok( !defined main::compute_server_tls_status(), 'no args => undef' );
};

subtest 'get_server_tls_status signal collection' => sub {
    plan tests => 9;

    reset_state( myvar => { version => '8.0.40', have_ssl => 'YES' } );
    is( main::get_server_tls_status(), 1, 'have_ssl present => enabled' );
    is( scalar(@queries), 0, 'have_ssl present => no extra query' );

    reset_state(
        myvar   => { version => '9.7.2', performance_schema => 'ON' },
        answers => { cipher  => "Ssl_cipher\tTLS_AES_128_GCM_SHA256" }
    );
    is( main::get_server_tls_status(), 1, 'MySQL 9.7 encrypted session => enabled' );
    ok( !grep( /tls_channel_status/, @queries ), 'encrypted session => no P_S query' );

    reset_state(
        myvar   => { version => '8.4.11', performance_schema => 'ON' },
        answers => { channel => 'Yes' }
    );
    is( main::get_server_tls_status(), 1, 'MySQL 8.4 plain session + channel Yes => enabled' );

    reset_state(
        myvar   => { version => '8.4.11', performance_schema => 'ON' },
        answers => { channel => 'No' }
    );
    is( main::get_server_tls_status(), 0, 'MySQL 8.4 channel Enabled=No => disabled' );

    reset_state( myvar => { version => '8.4.11', performance_schema => 'OFF' } );
    ok( !defined main::get_server_tls_status(), 'P_S OFF + plain session => unknown' );
    ok( !grep( /tls_channel_status/, @queries ), 'P_S OFF => tls_channel_status not queried' );

    reset_state( myvar => { version => '11.8.9-MariaDB', performance_schema => 'ON' } );
    main::get_server_tls_status();
    ok( !grep( /tls_channel_status/, @queries ), 'MariaDB => tls_channel_status not queried' );
};

subtest 'check_security_2_0 output (PI-023 regression)' => sub {
    plan tests => 5;

    reset_state(
        myvar   => { version => '9.7.2', performance_schema => 'ON', tls_version => 'TLSv1.2,TLSv1.3' },
        answers => { cipher  => "Ssl_cipher\tTLS_AES_128_GCM_SHA256" }
    );
    main::check_security_2_0();
    ok( !grep( /TLS\/SSL is disabled/, @bad ), 'MySQL 9.7 encrypted: no false "disabled" warning' );
    ok( grep( /TLS\/SSL is enabled/, @info ), 'MySQL 9.7 encrypted: reported as enabled' );

    reset_state( myvar => { version => '8.4.11', performance_schema => 'OFF' } );
    main::check_security_2_0();
    ok( !grep( /TLS\/SSL is disabled/, @bad ), 'unknown status: no false "disabled" warning' );
    ok( grep( /could not be determined/, @info ), 'unknown status: informational message' );

    reset_state( myvar => { version => '10.11.19-MariaDB', have_ssl => 'DISABLED' } );
    main::check_security_2_0();
    ok( grep( /TLS\/SSL is disabled/, @bad ), 'have_ssl=DISABLED (remote): still flagged' );
};

subtest 'ssl_tls_recommendations global check on MySQL 8.4+' => sub {
    plan tests => 2;
    no warnings 'redefine';
    local *main::check_local_certificates = sub { };
    local *main::check_remote_user_ssl    = sub { };

    reset_state(
        myvar   => { version => '8.4.11', performance_schema => 'ON', ssl_cert => 'server-cert.pem', ssl_key => 'server-key.pem' },
        answers => { cipher  => "Ssl_cipher\tTLS_AES_256_GCM_SHA384" }
    );
    main::ssl_tls_recommendations();
    ok( grep( /SSL support is enabled/, @good ), 'SSL support reported enabled without have_ssl' );
    ok( !grep( /SSL is DISABLED/, @bad ), 'no "SSL is DISABLED" on MySQL 8.4 with TLS' );
};

done_testing();
