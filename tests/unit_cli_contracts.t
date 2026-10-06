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

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

sub run_parse_with_args {
    my (@args) = @_;
    local @ARGV = @args;
    local $mock_exit_active = 1;

    # Capture STDERR
    open my $old_err, '>&', \*STDERR or die "Can't dup STDERR: $!";
    close STDERR;
    open STDERR, '>', File::Spec->devnull() or die "Can't redirect STDERR: $!";

    my $exit_code = 0;
    eval {
        main::parse_cli_args();
    };
    if ($@) {
        if ($@ =~ /MOCKED_EXIT:\s*(\d+)/) {
            $exit_code = $1;
        } else {
            die $@;
        }
    }

    open STDERR, '>&', $old_err or die "Can't restore STDERR: $!";
    close $old_err;

    return $exit_code;
}

# [REQ-CLI-01] Verify uniqueness of CLI metadata keys
subtest 'REQ-CLI-01: CLI metadata uniqueness' => sub {
    # Scan mysqltuner.pl directly to verify no duplicate hash keys exist in source
    open my $fh, '<', $script or die "Cannot open $script: $!";
    my %seen_keys;
    my @duplicate_keys;
    while (my $line = <$fh>) {
        if ($line =~ /^\s*'([a-zA-Z0-9_|?!:-]+)'\s*=>\s*\{/) {
            my $key = $1;
            if ($seen_keys{$key}) {
                push @duplicate_keys, $key;
            }
            $seen_keys{$key}++;
        }
    }
    close $fh;

    is(scalar(@duplicate_keys), 0, "No duplicate keys found in %CLI_METADATA source");
    ok(!grep { $_ eq 'server-log' } @duplicate_keys, "server-log is not duplicated");
};

# [REQ-CLI-02] Verify strict numeric and bounds validations
subtest 'REQ-CLI-02: Option type & bounds assertions' => sub {
    # Port validation (1-65535)
    is(run_parse_with_args('--port', '3306'), 0, 'Port 3306 accepted');
    is(run_parse_with_args('--port', '1'), 0, 'Port 1 accepted');
    is(run_parse_with_args('--port', '65535'), 0, 'Port 65535 accepted');
    is(run_parse_with_args('--port', '0'), 1, 'Port 0 rejected');
    is(run_parse_with_args('--port', '65536'), 1, 'Port 65536 rejected');
    is(run_parse_with_args('--port', '-5'), 1, 'Negative port rejected');

    # dump-limit validation (>= 0)
    is(run_parse_with_args('--dump-limit', '1000'), 0, 'dump-limit 1000 accepted');
    is(run_parse_with_args('--dump-limit', '0'), 0, 'dump-limit 0 accepted');
    is(run_parse_with_args('--dump-limit', '-10'), 1, 'Negative dump-limit rejected');

    # max-password-checks (>= 1)
    is(run_parse_with_args('--max-password-checks', '50'), 0, 'max-password-checks 50 accepted');
    is(run_parse_with_args('--max-password-checks', '0'), 1, 'max-password-checks 0 rejected');
    is(run_parse_with_args('--max-password-checks', '-1'), 1, 'Negative max-password-checks rejected');

    # maxportallowed (>= 0)
    is(run_parse_with_args('--maxportallowed', '5'), 0, 'maxportallowed 5 accepted');
    is(run_parse_with_args('--maxportallowed', '0'), 0, 'maxportallowed 0 accepted');
    is(run_parse_with_args('--maxportallowed', '-2'), 1, 'Negative maxportallowed rejected');

    # defaultarch (32 or 64)
    is(run_parse_with_args('--defaultarch', '64'), 0, 'defaultarch 64 accepted');
    is(run_parse_with_args('--defaultarch', '32'), 0, 'defaultarch 32 accepted');
    is(run_parse_with_args('--defaultarch', '128'), 1, 'defaultarch 128 rejected');
};

# [REQ-CLI-03] Reject unvalidated extra non-option positional arguments
subtest 'REQ-CLI-03: Zero unvalidated positional arguments' => sub {
    is(run_parse_with_args('--host', '127.0.0.1', 'extra_arg'), 1, 'Non-option argument rejected');
    is(run_parse_with_args('stray_argument'), 1, 'Stray positional argument rejected');
    is(run_parse_with_args('--silent'), 0, 'Valid flag with no extra arguments accepted');
};

done_testing();
