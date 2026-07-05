#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

our $mock_exit_active = 0;
BEGIN {
    *CORE::GLOBAL::exit = sub {
        my $code = shift // 0;
        if ($mock_exit_active) {
            die "MOCKED_EXIT: $code\n";
        }
        CORE::exit($code);
    };
}

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Declare globals before loading script
our @adjvars;
our @generalrec;
our @modeling;
our @sysrec;
our @secrec;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;
our $mysqlcmd;
our $devnull;

my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

my @mock_output;
sub reset_mocks {
    @mock_output = ();
    @main::generalrec = ();
    @main::adjvars = ();
    @main::modeling = ();
    @main::sysrec = ();
    @main::secrec = ();
    %main::result = ();
    %main::opt = ();
    %main::myvar = ();
}

{
    no warnings 'redefine';
    *main::infoprint       = sub { push @mock_output, "INFO: $_[0]" };
    *main::badprint        = sub { push @mock_output, "BAD: $_[0]" };
    *main::goodprint       = sub { push @mock_output, "GOOD: $_[0]" };
    *main::debugprint      = sub { };
    *main::subheaderprint  = sub { push @mock_output, "HEADER: $_[0]" };
    *main::prettyprint     = sub { push @mock_output, "PRETTY: $_[0]" };
}

# =====================================================================
# 1. parse_cli_args
# =====================================================================
subtest 'parse_cli_args' => sub {
    reset_mocks();
    local @ARGV = ('--host', '192.168.1.100', '--user', 'tuner_user');
    main::parse_cli_args();
    is($main::opt{host}, '192.168.1.100', 'host option parsed');
    is($main::opt{user}, 'tuner_user', 'user option parsed');
};

subtest 'parse_cli_args invalid option' => sub {
    reset_mocks();
    local @ARGV = ('--invalid-opt-name-xyz');
    local $mock_exit_active = 1;
    # Capture STDERR or redirect it to avoid clutter
    open my $old_err, '>&', \*STDERR or die "Can't dup STDERR: $!";
    close STDERR;
    open STDERR, '>', File::Spec->devnull() or die "Can't redirect STDERR: $!";
    eval {
        main::parse_cli_args();
    };
    my $err = $@;
    # Restore STDERR
    open STDERR, '>&', $old_err or die "Can't restore STDERR: $!";
    close $old_err;
    like($err, qr/MOCKED_EXIT: 1/, 'exit code 1 on invalid option');
};

# =====================================================================
# 2. show_help
# =====================================================================
subtest 'show_help' => sub {
    reset_mocks();
    local $mock_exit_active = 1;
    my $help_output = '';
    # Capture STDOUT
    open my $old_out, '>&', \*STDOUT or die "Can't dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$help_output or die "Can't redirect STDOUT: $!";
    eval {
        main::show_help();
    };
    my $err = $@;
    # Restore STDOUT
    open STDOUT, '>&', $old_out or die "Can't restore STDOUT: $!";
    close $old_out;
    like($err, qr/MOCKED_EXIT: 0/, 'exit code 0 on show_help');
    like($help_output, qr/Usage: \.\/mysqltuner\.pl/, 'help usage output present');
    like($help_output, qr/CONNECTION AND AUTHENTICATION/, 'help categories present');
};

# =====================================================================
# 3. get_http_cli
# =====================================================================
subtest 'get_http_cli' => sub {
    reset_mocks();
    # Case 1: curl exists
    {
        no warnings 'redefine';
        local *main::which = sub {
            my ($cmd) = @_;
            return "/usr/bin/curl\n" if $cmd eq 'curl';
            return "";
        };
        is(main::get_http_cli(), "/usr/bin/curl", 'curl detected');
    }
    # Case 2: wget exists (curl does not)
    {
        no warnings 'redefine';
        local *main::which = sub {
            my ($cmd) = @_;
            return "/usr/bin/wget\n" if $cmd eq 'wget';
            return "";
        };
        is(main::get_http_cli(), "/usr/bin/wget", 'wget fallback works');
    }
    # Case 3: neither exists
    {
        no warnings 'redefine';
        local *main::which = sub { return ""; };
        is(main::get_http_cli(), "", 'empty returned if neither exists');
    }
};

done_testing();
