use strict;
use warnings;
no warnings 'once';
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

# 1. Test compare_tuner_version
# This function is not pure, it uses global $tunerversion and prints.
subtest 'compare_tuner_version' => sub {
    no warnings 'redefine';
    local *main::goodprint = sub { };
    local *main::badprint = sub { };
    local *main::update_tuner_version = sub { };
    
    $main::tunerversion = "2.8.33";
    
    # It returns undef, so we just check if it runs without crashing for now
    # or check the behavior if we mocked the prints to capture output.
    ok(defined eval { main::compare_tuner_version("2.8.33"); 1 }, "Runs with same version");
    ok(defined eval { main::compare_tuner_version("2.9.0"); 1 }, "Runs with newer version");
};

done_testing();
