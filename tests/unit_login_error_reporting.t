#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_login_error_reporting.t
# Description: Validates that login failures surface the real mysql client
#              error (TLS, unreachable, access denied) with actionable hints
#              instead of always claiming invalid credentials (PI-026).
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

my ( @bad, @info );
{
    no warnings 'redefine';
    *main::badprint   = sub { push @bad,  $_[0] };
    *main::infoprint  = sub { push @info, $_[0] };
    *main::debugprint = sub { };
}
sub reset_out { @bad = @info = () }

my $tls_err  = "ERROR 2026 (HY000): TLS/SSL error: self-signed certificate in certificate chain\n";
my $auth_err = "ERROR 1045 (28000): Access denied for user 'bob'\@'10.0.0.1' (using password: YES)\n";
my $conn_err = "ERROR 2002 (HY000): Can't connect to server on '10.0.0.9' (115)\n";

subtest 'extract_client_error (pure)' => sub {
    plan tests => 7;
    ok( !defined main::extract_client_error(undef), 'undef output => undef' );
    ok( !defined main::extract_client_error("\n  \n"), 'blank output => undef' );
    is( main::extract_client_error("mysql: [Warning] Using a password on the command line interface can be insecure.\n$tls_err"),
        'ERROR 2026 (HY000): TLS/SSL error: self-signed certificate in certificate chain',
        'password warning filtered, ERROR line selected' );
    is( main::extract_client_error("noise\n$auth_err\ntrailer\n"),
        "ERROR 1045 (28000): Access denied for user 'bob'\@'10.0.0.1' (using password: YES)",
        'ERROR line preferred over other lines' );
    is( main::extract_client_error("sh: 1: mysql: not found\n"), 'sh: 1: mysql: not found',
        'no ERROR line => last non-empty line' );
    unlike( main::extract_client_error("failed: mysql -u x -p'S3cr3t' -h h\n"), qr/S3cr3t/,
        'inline -p password masked' );
    is( length( main::extract_client_error( 'x' x 500 ) ), 303, 'long line truncated to 300 + ...' );
};

subtest 'report_login_failure: authentication error' => sub {
    plan tests => 3;
    reset_out();
    main::report_login_failure( 'Attempted to use login credentials', $auth_err );
    is( $bad[0], 'Attempted to use login credentials, but they were invalid.', 'auth error => invalid credentials' );
    like( $bad[1], qr/^Client error: ERROR 1045/, 'real client error displayed' );
    is( scalar(@info), 0, 'no hint for authentication error' );
};

subtest 'report_login_failure: TLS error' => sub {
    plan tests => 3;
    reset_out();
    main::report_login_failure( 'Attempted to use login credentials', $tls_err );
    is( $bad[0], 'Attempted to use login credentials, but the connection failed.', 'TLS error is not reported as invalid credentials' );
    like( $bad[1], qr/^Client error: ERROR 2026/, 'TLS client error displayed' );
    ok( grep( /--ssl-ca.*disable-ssl-verify-server-cert/, @info ), 'TLS hint displayed' );
};

subtest 'report_login_failure: unreachable server' => sub {
    plan tests => 2;
    reset_out();
    main::report_login_failure( 'Attempted to use login credentials', $conn_err );
    is( $bad[0], 'Attempted to use login credentials, but the connection failed.', 'unreachable => connection failed' );
    ok( grep( /server unreachable/, @info ), 'network hint displayed' );
};

subtest 'report_login_failure: no output keeps legacy message' => sub {
    plan tests => 2;
    reset_out();
    main::report_login_failure( 'Attempted to use login credentials', '' );
    is( $bad[0], 'Attempted to use login credentials, but they were invalid.', 'empty output => legacy message' );
    is( scalar(@bad), 1, 'no client error line when nothing captured' );
};

done_testing();
