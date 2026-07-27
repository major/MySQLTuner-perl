#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

my $script_dir   = dirname(abs_path(__FILE__));
my $project_root = abs_path(File::Spec->catfile($script_dir, '..'));

chdir $project_root or die "Can't chdir to $project_root: $!";

subtest 'Issue 932 - Dockerfile defaults.cnf and entrypoint verification' => sub {
    my $dockerfile = 'Dockerfile';
    ok(-f $dockerfile, 'Dockerfile exists');

    open my $fh, '<', $dockerfile or die "Cannot open Dockerfile: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like($content, qr/touch \/defaults\.cnf/, 'Dockerfile creates /defaults.cnf via touch command');
    like($content, qr/--defaults-file.*\/defaults\.cnf/, 'Dockerfile ENTRYPOINT references /defaults.cnf');
    unlike($content, qr/"--verbose"\s*\]/, 'Dockerfile ENTRYPOINT does not hardcode --verbose');
};

subtest 'Issue 932 - mysqltuner.pl container option help text' => sub {
    open my $fh, '<', 'mysqltuner.pl' or die "Cannot open mysqltuner.pl: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like($content, qr/requires docker, podman, or kubectl client/, 'mysqltuner.pl container option description mentions required CLI clients');
};

subtest 'Issue 932 - README Docker volume mounting documentation' => sub {
    my @readme_files = ('README.md', 'README.fr.md', 'README.it.md', 'README.ru.md');

    for my $readme (@readme_files) {
        ok(-f $readme, "$readme exists");
        open my $fh, '<', $readme or die "Cannot open $readme: $!";
        my $content = do { local $/; <$fh> };
        close $fh;

        like($content, qr/-v \$\(pwd\)\/results:\/results/, "$readme documents volume mounting for /results");
        like($content, qr/-v \$\(pwd\)\/my\.cnf:\/defaults\.cnf/, "$readme documents volume mounting for /defaults.cnf");
    }
};

done_testing();
