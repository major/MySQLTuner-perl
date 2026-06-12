#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

my $script_dir = dirname(abs_path(__FILE__));
my $project_root = abs_path(File::Spec->catfile($script_dir, '..'));

# Change directory to project root
chdir $project_root or die "Can't chdir to $project_root: $!";

subtest 'check_release_files.sh execution verification' => sub {
    my $release_check_script = File::Spec->catfile('tests', 'check_release_files.sh');
    ok(-f $release_check_script, "tests/check_release_files.sh exists");

    my $output = qx(bash "$release_check_script" 2>&1);
    my $exit_code = $? >> 8;

    is($exit_code, 0, "check_release_files.sh executed successfully");
    like($output, qr/All checks passed successfully/i, "check_release_files.sh reports success");
};

done_testing();
