#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

my $script_dir = dirname(abs_path(__FILE__));
my $project_root = abs_path(File::Spec->catfile($script_dir, '..'));

chdir $project_root or die "Can't chdir to $project_root: $!";

subtest 'SQL Static Linter Verification' => sub {
    my $linter_script = File::Spec->catfile('build', 'check_sql_linter.pl');
    ok(-f $linter_script, "build/check_sql_linter.pl exists");

    my $output = qx(perl "$linter_script" 2>&1);
    my $exit_code = $? >> 8;

    is($exit_code, 0, "check_sql_linter.pl executed successfully");
    like($output, qr/No SQL issues or formatting anomalies detected/i, "check_sql_linter.pl reports success");
};

done_testing();
