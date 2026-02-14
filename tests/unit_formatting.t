use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Suppress warnings from mysqltuner.pl initialization if any
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

# 1. Test pretty_uptime
subtest 'pretty_uptime' => sub {
    is(main::pretty_uptime(30), "30s", "30 seconds");
    is(main::pretty_uptime(90), "1m 30s", "90 seconds");
    is(main::pretty_uptime(3600), "1h 0m 0s", "1 hour");
    is(main::pretty_uptime(86400), "1d 0h 0m 0s", "1 day");
    is(main::pretty_uptime(90061), "1d 1h 1m 1s", "Complex uptime");
};

# 2. Test arr2hash
subtest 'arr2hash' => sub {
    my @input = (
        'max_connections = 151',
        'innodb_buffer_pool_size = 134217728'
    );
    my %expected = (
        'max_connections' => '151',
        'innodb_buffer_pool_size' => '134217728'
    );
    my %result;
    main::arr2hash(\%result, \@input, '=');
    is_deeply(\%result, \%expected, "Array of strings to hash mapping");
};

done_testing();
