#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_mariadb_var_origin.t
# Description: MariaDB deprecated variables are only reported when they are
#              explicitly configured, based on
#              information_schema.SYSTEM_VARIABLES.GLOBAL_VALUE_ORIGIN
#              (PI-024 tx_isolation, PI-025 innodb_prefix_index_cluster_optimization).
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

my %origin;     # VARIABLE_NAME => GLOBAL_VALUE_ORIGIN returned by mock
my @queries;    # SQL sent to select_one
{
    no warnings 'redefine';
    *main::badprint   = sub { };
    *main::debugprint = sub { };
    *main::select_one = sub {
        my $sql = shift;
        push @queries, $sql;
        return $sql =~ /VARIABLE_NAME = '([A-Z0-9_]+)'/ ? ( $origin{$1} // '' ) : '';
    };
}

sub run_audit {
    my (%vars) = @_;
    %main::myvar      = %vars;
    @main::generalrec = ();
    @main::sysrec     = ();
    %main::result     = ();
    @queries          = ();
    main::audit_deprecated_variables();
    return map { $_->{variable} } @{ $main::result{'Deprecated_Variables'} || [] };
}

my %mariadb_118 = (
    version         => '11.8.3-MariaDB',
    version_comment => 'mariadb.org binary distribution',
);

subtest 'is_user_configured_origin (pure)' => sub {
    plan tests => 8;
    ok( main::is_user_configured_origin('CONFIG'),       'CONFIG is user-set' );
    ok( main::is_user_configured_origin('COMMAND-LINE'), 'COMMAND-LINE is user-set' );
    ok( main::is_user_configured_origin('SQL'),          'SQL (SET GLOBAL) is user-set' );
    ok( main::is_user_configured_origin('config'),       'case-insensitive' );
    ok( !main::is_user_configured_origin('COMPILE-TIME'), 'COMPILE-TIME is a default' );
    ok( !main::is_user_configured_origin('AUTO'),         'AUTO is a default' );
    ok( !main::is_user_configured_origin(''),             'empty origin is not user-set' );
    ok( !main::is_user_configured_origin(undef),          'undef origin is not user-set' );
};

subtest 'get_mariadb_variable_origin' => sub {
    plan tests => 5;
    %main::myvar = %mariadb_118;
    %origin = ( TX_ISOLATION => "CONFIG\n" );
    @queries = ();
    is( main::get_mariadb_variable_origin('tx_isolation'), 'CONFIG', 'origin trimmed' );
    like( $queries[0], qr/information_schema\.SYSTEM_VARIABLES/, 'queries SYSTEM_VARIABLES' );
    like( $queries[0], qr/VARIABLE_NAME = 'TX_ISOLATION'/, 'variable name upper-cased' );
    @queries = ();
    is( main::get_mariadb_variable_origin("x'; DROP TABLE t; --"), '', 'invalid name rejected' );
    is( scalar @queries, 0, 'no SQL sent for invalid name' );
};

subtest 'PI-024: tx_isolation on MariaDB 11.8' => sub {
    plan tests => 4;
    %origin = ( TX_ISOLATION => 'COMPILE-TIME' );
    my @v = run_audit( %mariadb_118, tx_isolation => 'REPEATABLE-READ' );
    ok( !grep( { $_ eq 'tx_isolation' } @v ), 'default alias value is not flagged' );

    %origin = ( TX_ISOLATION => 'CONFIG' );
    @v = run_audit( %mariadb_118, tx_isolation => 'READ-COMMITTED' );
    ok( grep( { $_ eq 'tx_isolation' } @v ), 'value from option file is flagged' );
    ok( grep( /deprecated since MariaDB 11\.1/, @main::sysrec ), 'MariaDB wording says deprecated' );

    %origin = ( TX_ISOLATION => 'COMMAND-LINE' );
    @v = run_audit( %mariadb_118, tx_isolation => 'READ-COMMITTED' );
    ok( grep( { $_ eq 'tx_isolation' } @v ), 'value from command line is flagged' );
};

subtest 'PI-024: tx_isolation unchanged elsewhere' => sub {
    plan tests => 4;
    %origin = ( TX_ISOLATION => 'CONFIG' );
    my @v = run_audit(
        version         => '10.6.20-MariaDB',
        version_comment => 'mariadb.org binary distribution',
        tx_isolation    => 'READ-COMMITTED'
    );
    ok( !grep( { $_ eq 'tx_isolation' } @v ), 'MariaDB 10.6: not deprecated yet' );
    is( scalar @queries, 0, 'MariaDB 10.6: no origin query' );

    %origin = ();
    @v = run_audit( version => '8.0.36', tx_isolation => 'REPEATABLE-READ' );
    ok( grep( { $_ eq 'tx_isolation' } @v ), 'MySQL 8.0: still flagged' );
    is( scalar @queries, 0, 'MySQL: no origin query' );
};

subtest 'PI-025: innodb_prefix_index_cluster_optimization' => sub {
    plan tests => 5;
    my %v1011 = (
        version         => '10.11.9-MariaDB',
        version_comment => 'mariadb.org binary distribution',
        innodb_prefix_index_cluster_optimization => 'ON',
    );
    %origin = ( INNODB_PREFIX_INDEX_CLUSTER_OPTIMIZATION => 'COMPILE-TIME' );
    my @v = run_audit(%v1011);
    ok( !grep( { /prefix_index/ } @v ), '10.11 default ON is not flagged' );

    %origin = ( INNODB_PREFIX_INDEX_CLUSTER_OPTIMIZATION => 'CONFIG' );
    @v = run_audit(%v1011);
    ok( grep( { /prefix_index/ } @v ), '10.11 explicitly configured is flagged' );
    ok( grep( /deprecated since MariaDB 10\.10/, @main::sysrec ), 'reason says deprecated, not removed' );

    @v = run_audit( %v1011, version => '10.6.20-MariaDB' );
    ok( !grep( { /prefix_index/ } @v ), '10.6: not deprecated yet' );

    @v = run_audit(
        version => '8.4.2',
        innodb_prefix_index_cluster_optimization => 'ON'
    );
    ok( !grep( { /prefix_index/ } @v ), 'MySQL: never flagged' );
};

subtest 'PI-025: no longer reported as removed' => sub {
    plan tests => 1;
    %main::myvar = (
        version         => '10.11.9-MariaDB',
        version_comment => 'mariadb.org binary distribution',
        innodb_prefix_index_cluster_optimization => 'ON',
    );
    %main::real_vars  = %main::myvar;
    @main::generalrec = ();
    main::check_removed_innodb_variables();
    ok( !grep( /prefix_index/, @main::generalrec ), 'no "removed" advice for an existing variable' );
};

done_testing();
