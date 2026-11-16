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

sub extract_dockerfile_entrypoint {
    my ($dockerfile_text) = @_;
    return undef unless defined $dockerfile_text;
    if ($dockerfile_text =~ /^\s*ENTRYPOINT\s*(\[[^\]]*\])/m) {
        return $1;
    }
    return undef;
}

subtest 'Issue 932 - Dockerfile defaults.cnf and entrypoint verification' => sub {
    my $dockerfile = 'Dockerfile';
    ok(-f $dockerfile, 'Dockerfile exists');

    open my $fh, '<', $dockerfile or die "Cannot open Dockerfile: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $entrypoint = extract_dockerfile_entrypoint($content);

    my @copied_sources = ($content =~ /^\s*COPY\s+\.\/(\S+)\s+\S+/mg);
    cmp_ok(scalar(@copied_sources), '>=', 3, 'Dockerfile copies expected repository assets');
    for my $src (@copied_sources) {
        ok(-f $src, "Dockerfile COPY source exists in repository: $src");
    }

    like($content, qr/touch \/defaults\.cnf/, 'Dockerfile creates /defaults.cnf via touch command');
    ok(defined $entrypoint, 'Dockerfile defines JSON-array ENTRYPOINT');
    like($entrypoint, qr/"--nosysstat"/, 'Dockerfile ENTRYPOINT includes --nosysstat');
    like($entrypoint, qr/--defaults-file.*\/defaults\.cnf/, 'Dockerfile ENTRYPOINT references /defaults.cnf');
    unlike($entrypoint, qr/"--template"/, 'Dockerfile ENTRYPOINT does not pass removed --template option');
    unlike($entrypoint, qr/"--verbose"/, 'Dockerfile ENTRYPOINT does not hardcode --verbose');
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

subtest 'Issue 932 - ENTRYPOINT vs CMD verbose isolation' => sub {
    my $cmd_only_dockerfile = <<'EOF';
FROM ubuntu:24.04
ENTRYPOINT [ "perl", "/mysqltuner.pl", \
             "--defaults-file", "/defaults.cnf" ]
CMD ["--verbose"]
EOF
    my $ep_cmd_only = extract_dockerfile_entrypoint($cmd_only_dockerfile);
    ok(defined $ep_cmd_only, 'Extracts multiline ENTRYPOINT before CMD');
    unlike($ep_cmd_only, qr/"--verbose"/, 'CMD ["--verbose"] does not taint ENTRYPOINT inspection');
    like($cmd_only_dockerfile, qr/^\s*CMD\s*\[\s*"--verbose"\s*\]/m, 'CMD still sets default --verbose argument');

    my $hardcoded_ep_dockerfile = <<'EOF';
FROM ubuntu:24.04
ENTRYPOINT [ "perl", "/mysqltuner.pl", \
             "--verbose" ]
EOF
    my $ep_hardcoded = extract_dockerfile_entrypoint($hardcoded_ep_dockerfile);
    ok(defined $ep_hardcoded, 'Extracts multiline ENTRYPOINT with verbose flag');
    like($ep_hardcoded, qr/"--verbose"/, 'Detects --verbose when hardcoded inside ENTRYPOINT');
};

done_testing();
