#!/usr/bin/env perl
# tests/unit_m2_env_windows_update.t
# Validates Milestone 2 Environment, Windows Safety & Version Update Fixes:
#   - Issue 7: Protect getpwuid($<) against fatal crashes on Windows ($is_win = 1)
#   - Issue 14A: Preserve $opt{nocolor} = 1 when $outputfile is defined
#   - Issue 14B: update_tuner_version checks download size against -s $fullpath rather than $script

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Cwd 'abs_path';

# Intercept CORE::GLOBAL::exit to prevent script termination during tests
BEGIN {
    *CORE::GLOBAL::exit = sub { die "MOCK_EXIT\n" };
}

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Declare package globals prior to loading mysqltuner.pl
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;
our $outputfile;
our $fh;
our $me;
our $good;
our $bad;
our $info;
our $deb;
our $cmd;
our $end;
our $is_win;

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# Captured mock output
my @mock_good;
my @mock_bad;
my @mock_info;
my @mock_debug;

sub reset_test_state {
    @mock_good  = ();
    @mock_bad   = ();
    @mock_info  = ();
    @mock_debug = ();
    %main::opt  = ();
    $main::outputfile = undef;
    $main::fh         = undef;
    $main::me         = undef;
}

# =====================================================================
# Subtest 1: Issue 7 — getpwuid safety on Windows ($is_win = 1)
# =====================================================================
subtest 'Issue 7: getpwuid safety on Windows ($is_win = 1)' => sub {
    reset_test_state();

    # Case 1: Windows environment with USERNAME set
    {
        local $main::is_win = 1;
        local $ENV{USER}     = undef;
        local $ENV{USERNAME} = 'WinAdminUser';
        local %main::opt    = ( color => 0, nocolor => 1 );

        eval { main::setup_environment(); };
        is( $@, '', 'setup_environment does not die on simulated Windows' );
        is( $main::me, 'WinAdminUser', '$me is correctly resolved from $ENV{USERNAME} without calling getpwuid' );
        like( $main::cmd, qr/WinAdminUser/, '$cmd prompt includes Windows username' );
        main::close_outputfile();
    }

    # Case 2: Windows environment with no username in environment (falls back to 'unknown')
    {
        local $main::is_win = 1;
        local $ENV{USER}     = undef;
        local $ENV{USERNAME} = undef;
        local %main::opt    = ( color => 0, nocolor => 1 );

        eval { main::setup_environment(); };
        is( $@, '', 'setup_environment handles missing USER/USERNAME without fatal exception' );
        is( $main::me, 'unknown', '$me safely falls back to "unknown"' );
        like( $main::cmd, qr/unknown/, '$cmd prompt includes "unknown"' );
        main::close_outputfile();
    }

    # Case 3: Unix environment ($is_win = 0) with valid getpwuid or fallback
    {
        local $main::is_win = 0;
        local $ENV{USER}     = 'unix_dev';
        local %main::opt    = ( color => 0, nocolor => 1 );

        eval { main::setup_environment(); };
        is( $@, '', 'setup_environment executes cleanly on POSIX' );
        ok( defined $main::me && length($main::me) > 0, '$me is populated on POSIX' );
        main::close_outputfile();
    }
};

# =====================================================================
# Subtest 2: Issue 14A — setup_environment preserves nocolor=1 on outputfile
# =====================================================================
subtest 'Issue 14A: setup_environment preserves nocolor=1 when outputfile is defined' => sub {
    reset_test_state();

    my $tempdir  = tempdir(CLEANUP => 1);
    my $out_file = File::Spec->catfile($tempdir, 'm2_audit_report.txt');

    # Case 1: outputfile defined while color default is 1 (interactive terminal simulation)
    {
        local %main::opt = (
            'outputfile' => $out_file,
            'color'      => 1,
        );

        main::setup_environment();
        is( $main::opt{nocolor}, 1, 'nocolor is preserved as 1 even when $opt{color} is 1' );
        unlike( $main::good, qr/\e\[/, '$good icon contains no ANSI escape codes' );
        unlike( $main::bad,  qr/\e\[/, '$bad icon contains no ANSI escape codes' );
        unlike( $main::cmd,  qr/\e\[/, '$cmd prompt contains no ANSI escape codes' );
        unlike( $main::end,  qr/\e\[/, '$end reset contains no ANSI escape codes' );
        main::close_outputfile();
    }

    # Case 2: outputfile NOT defined and color is 1 (color should be enabled on POSIX terminal)
    {
        local %main::opt = (
            'color' => 1,
        );

        local $main::is_win = 0;
        main::setup_environment();
        is( $main::opt{nocolor}, 0, 'nocolor is 0 (colors active) when outputfile is NOT specified' );
        like( $main::good, qr/\e\[/, '$good icon contains ANSI escape sequences' );
        main::close_outputfile();
    }

    # Case 3: outputfile defined with explicit nocolor=1
    {
        local %main::opt = (
            'outputfile' => $out_file,
            'color'      => 0,
            'nocolor'    => 1,
        );

        main::setup_environment();
        is( $main::opt{nocolor}, 1, 'nocolor remains 1 with explicit nocolor option' );
        main::close_outputfile();
    }
};

# =====================================================================
# Subtest 3: Issue 14B — update_tuner_version verifies download against -s $fullpath
# =====================================================================
subtest 'Issue 14B: update_tuner_version checks download size against -s $fullpath' => sub {
    reset_test_state();

    no warnings 'redefine';
    local *main::goodprint  = sub { push @mock_good,  $_[0] };
    local *main::badprint   = sub { push @mock_bad,   $_[0] };
    local *main::infoprint  = sub { push @mock_info,  $_[0] };
    local *main::debugprint = sub { push @mock_debug, $_[0] };

    my $tempdir = tempdir(CLEANUP => 1);
    local $main::update_target_dir = $tempdir;

    # Case 1: curl download verifies target fullpath file size
    {
        reset_test_state();
        local $main::opt{'updateversion'} = 1;
        local *main::get_http_cli         = sub { return '/usr/bin/curl' };

        # Mock execute_system_command to simulate writing to the redirected $fullpath
        my @intercepted_commands;
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            push @intercepted_commands, $cmd;
            # Extract target redirect path: > ($fullpath)
            if ( $cmd =~ />\s+(.+)$/ ) {
                my $target_path = $1;
                open my $out_fh, '>', $target_path or die "Cannot write to mock target $target_path: $!";
                print $out_fh "# Mock downloaded script content\n";
                close $out_fh;
            }
            return "Downloaded successfully";
        };

        eval { main::update_tuner_version(); };
        like( $@, qr/MOCK_EXIT/, 'update_tuner_version completed and exited' );
        ok( grep( { /Successfully updated MySQLTuner script/ } @mock_good ), 'curl download reports success when $fullpath has size > 0' );
        is( scalar(@mock_bad), 0, 'No download failures reported' );
        is( scalar(@intercepted_commands), 3, 'Executed 3 download commands for scripts' );
    }

    # Case 2: curl download detects 0-byte or failed download at $fullpath
    {
        reset_test_state();
        local $main::opt{'updateversion'} = 1;
        local *main::get_http_cli         = sub { return '/usr/bin/curl' };

        # Mock execute_system_command creating 0-byte files
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ( $cmd =~ />\s+(.+)$/ ) {
                my $target_path = $1;
                open my $out_fh, '>', $target_path or die "Cannot write to mock target $target_path: $!";
                # Write nothing (0-byte file)
                close $out_fh;
            }
            return "";
        };

        eval { main::update_tuner_version(); };
        like( $@, qr/MOCK_EXIT/, 'update_tuner_version exited' );
        ok( grep( { /Couldn't update mysqltuner\.pl/ } @mock_bad ), 'Flags failure when downloaded $fullpath is 0 bytes' );
        ok( grep( { /Couldn't update MySQLTuner script/ } @mock_bad ), 'Final update status reports failure' );
    }

    # Case 3: wget download uses -O $fullpath and verifies -s $fullpath
    {
        reset_test_state();
        local $main::opt{'updateversion'} = 1;
        local *main::get_http_cli         = sub { return '/usr/bin/wget' };

        my @intercepted_wget_commands;
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            push @intercepted_wget_commands, $cmd;
            if ( $cmd =~ /-O\s+(\S+)/ ) {
                my $target_path = $1;
                open my $out_fh, '>', $target_path or die "Cannot write to mock target $target_path: $!";
                print $out_fh "# Mock wget downloaded script\n";
                close $out_fh;
            }
            return "Downloaded successfully";
        };

        eval { main::update_tuner_version(); };
        like( $@, qr/MOCK_EXIT/, 'wget download completed and exited' );
        ok( grep( { /Successfully updated MySQLTuner script/ } @mock_good ), 'wget download reports success' );
        for my $cmd (@intercepted_wget_commands) {
            like( $cmd, qr/-O\s+\S+\/(?:mysqltuner\.pl|basic_passwords\.txt|vulnerabilities\.csv)/, 'wget command writes to $fullpath' );
        }
    }
};

done_testing();
