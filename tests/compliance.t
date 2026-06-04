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

subtest 'Compliance Check Verification' => sub {
    my $compliance_script = File::Spec->catfile('build', 'check_compliance.pl');
    ok(-f $compliance_script, "build/check_compliance.pl exists");

    my $output = qx(perl "$compliance_script" 2>&1);
    my $exit_code = $? >> 8;

    is($exit_code, 0, "check_compliance.pl executed successfully");
    like($output, qr/Compliance check passed/i, "check_compliance.pl reports success");
};

done_testing();
