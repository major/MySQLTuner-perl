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

subtest 'doc_sync.pl execution verification' => sub {
    my $doc_sync_script = File::Spec->catfile('build', 'doc_sync.pl');
    ok(-f $doc_sync_script, "build/doc_sync.pl exists");

    my $output = qx(perl "$doc_sync_script" 2>&1);
    my $exit_code = $? >> 8;

    is($exit_code, 0, "doc_sync.pl executed successfully");
    like($output, qr/Documentation synchronized/i, "doc_sync.pl reports success");
};

done_testing();
# Verify pre-commit hook execution
