#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_login_explicit_failure.t
# Description: A login failure with explicit credentials (--pass or
#              --login-path) is reported once and stops; no fallback login
#              method re-prints the same client error (PI-026 residual).
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
no warnings 'once';

my $exit_val;
BEGIN {
    *CORE::GLOBAL::exit = sub {
        $exit_val = shift // 0;
        die "MOCK_EXIT\n";
    };
}

use Test::More;
use FindBin;
use File::Spec;

{
    local @ARGV = ();
    no warnings 'redefine';
    require File::Spec->catfile( $FindBin::Bin, '..', 'mysqltuner.pl' );
}
require File::Spec->catfile( $FindBin::Bin, 'MySQLTuner', 'TestHelper.pm' );

my $auth_err =
  "ERROR 1045 (28000): Access denied for user 'bob'\@'10.0.0.1' (using password: YES)\n";

my ( @bad, @cmds );

sub run_setup {
    my (%o) = @_;
    no warnings 'redefine';
    local *main::badprint   = sub { push @bad, $_[0] };
    local *main::goodprint  = sub { };
    local *main::infoprint  = sub { };
    local *main::debugprint = sub { };
    local *main::get_transport_prefix   = sub { '' };
    local *main::my_file_readable       = sub { 0 };
    local *main::which                  = sub { undef };
    local *main::execute_system_command = sub {
        my $cmd = shift;
        push @cmds, $cmd;
        return '' if $cmd =~ /--print-defaults/;
        return $auth_err;
    };
    MySQLTuner::TestHelper::reset_state();
    @bad = @cmds = ();
    $exit_val = undef;
    local %main::opt = (
        %main::opt,
        mysqladmin => '/bin/true',
        mysqlcmd   => '/bin/true',
        noask      => 1,
        host       => '',
        pass       => 0,
        user       => 0,
        container  => '',
        'login-path'          => '',
        'defaults-file'       => '',
        'defaults-extra-file' => '',
        'ssl-ca'              => '',
        socket => 0, pipe => 0, protocol => '', port => 0,
        %o,
    );
    local $ENV{HOME} = '/nonexistent';
    my $ok = eval { main::mysql_setup(); 1 };
    return $ok ? 'returned' : $@;
}

sub count_client_errors { scalar grep { /^Client error:/ } @bad }
sub login_attempts      { scalar grep { /mysqld is alive|ping/ } @cmds }

subtest '--user + --pass failure: reported once, no fallback' => sub {
    plan tests => 5;
    my $r = run_setup( user => 'bob', pass => 'wrong' );
    is( $r, "MOCK_EXIT\n", 'exit() called' );
    is( $exit_val, 1, 'exit code 1' );
    is( count_client_errors(), 1, 'client error printed exactly once' );
    ok( grep( /but they were invalid/, @bad ), 'invalid credentials message' );
    is( login_attempts(), 1, 'no fallback login attempt' );
};

subtest '--login-path failure: reported once, no fallback' => sub {
    plan tests => 3;
    my $r = run_setup( 'login-path' => 'prod' );
    is( $r, "MOCK_EXIT\n", 'exit() called' );
    is( count_client_errors(), 1, 'client error printed exactly once' );
    is( login_attempts(), 1, 'no fallback login attempt' );
};

subtest '--user only (no password): falls back, error printed once' => sub {
    plan tests => 4;
    my $r = run_setup( user => 'bob' );
    is( $r, "MOCK_EXIT\n", 'exit() called by --noask fallback' );
    is( $exit_val, 1, 'exit code 1' );
    is( count_client_errors(), 1, 'client error printed exactly once' );
    is( login_attempts(), 2, 'fallback login was still attempted' );
};

done_testing();
