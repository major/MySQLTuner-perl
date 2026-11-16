#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_npm_security_overrides.t
# Description: Validates npm security overrides in package.json and resolved
#              dependency versions in package-lock.json against known advisories.
# ===========================================================================
use strict;
use warnings;
use Test::More;
use JSON::PP qw(decode_json);
use File::Spec;
use FindBin;

my $project_root = File::Spec->rel2abs(File::Spec->catfile($FindBin::Bin, '..'));
my $pkg_root_file  = File::Spec->catfile($project_root, 'package.json');
my $lock_root_file = File::Spec->catfile($project_root, 'package-lock.json');
if (!-f $pkg_root_file || !-f $lock_root_file) {
    plan skip_all => 'package.json or package-lock.json not present in minimal/tarball build';
}

sub parse_semver {
    my ($ver_str) = @_;
    return undef unless defined $ver_str;
    $ver_str =~ s/^\s+|\s+$//g;
    $ver_str =~ s/^[\^~>=<\s]+//;
    if ($ver_str =~ /^(\d+)\.(\d+)\.(\d+)/) {
        return [ int($1), int($2), int($3) ];
    }
    return undef;
}

sub semver_ge {
    my ($actual, $min) = @_;
    my $a = parse_semver($actual);
    my $m = parse_semver($min);
    return 0 unless defined $a && defined $m;

    for my $i (0 .. 2) {
        return 1 if $a->[$i] > $m->[$i];
        return 0 if $a->[$i] < $m->[$i];
    }
    return 1;
}

sub read_json_file {
    my ($path) = @_;
    open my $fh, '<', $path or die "Cannot open $path: $!";
    my $raw = do { local $/; <$fh> };
    close $fh;
    return decode_json($raw);
}

subtest 'package.json defines security overrides for transitive advisories' => sub {
    my $pkg_path = File::Spec->catfile($project_root, 'package.json');
    ok(-f $pkg_path, 'package.json exists');

    my $pkg = read_json_file($pkg_path);
    my $overrides = $pkg->{overrides};
    ok(ref $overrides eq 'HASH', 'package.json defines overrides map');

    my %min_overrides = (
        'fast-uri'        => '3.1.9',
        'js-yaml'         => '4.3.2',
        'brace-expansion' => '1.1.21',
    );

    for my $name (sort keys %min_overrides) {
        my $min = $min_overrides{$name};
        ok(exists $overrides->{$name}, "overrides specifies $name");
        ok(semver_ge($overrides->{$name}, $min), "override for $name ($overrides->{$name}) is >= $min");
    }
};

subtest 'package-lock.json resolves patched versions free of GHSA advisories' => sub {
    my $lock_path = File::Spec->catfile($project_root, 'package-lock.json');
    ok(-f $lock_path, 'package-lock.json exists');

    my $lock = read_json_file($lock_path);
    my $packages = $lock->{packages};
    ok(ref $packages eq 'HASH', 'package-lock.json defines packages map');

    my %checked = (
        'fast-uri'        => 0,
        'js-yaml'         => 0,
        'brace-expansion' => 0,
    );

    for my $pkg_key (sort keys %{$packages}) {
        next unless $pkg_key =~ /(?:^|\/)(fast-uri|js-yaml|brace-expansion)$/;
        my $name = $1;
        my $ver  = $packages->{$pkg_key}{version};
        $checked{$name}++;

        if ($name eq 'fast-uri') {
            ok(semver_ge($ver, '3.1.9'), "$pkg_key version ($ver) >= 3.1.9");
        }
        elsif ($name eq 'js-yaml') {
            ok(semver_ge($ver, '4.3.2'), "$pkg_key version ($ver) >= 4.3.2");
        }
        elsif ($name eq 'brace-expansion') {
            my $parsed = parse_semver($ver);
            my $is_safe = ($parsed && $parsed->[0] >= 5)
                ? semver_ge($ver, '5.0.12')
                : semver_ge($ver, '1.1.21');
            ok($is_safe, "$pkg_key version ($ver) is on a patched brace-expansion release");
        }
    }

    for my $name (sort keys %checked) {
        cmp_ok($checked{$name}, '>=', 1, "Found resolved $name package entry in package-lock.json");
    }
};

subtest 'semver helper detects unpatched versions accurately' => sub {
    ok(semver_ge('3.1.9',  '3.1.9'),  '3.1.9 meets minimum 3.1.9');
    ok(semver_ge('3.1.10', '3.1.9'),  '3.1.10 handles multi-digit patch comparison');
    ok(!semver_ge('3.1.7', '3.1.9'),  '3.1.7 is flagged below 3.1.9 (PR 68 level)');
    ok(!semver_ge('3.1.8', '3.1.9'),  '3.1.8 is flagged below 3.1.9');
    ok(!semver_ge('4.3.1', '4.3.2'),  'js-yaml 4.3.1 is flagged below 4.3.2');
    ok(!semver_ge('1.1.20','1.1.21'), 'brace-expansion 1.1.20 is flagged below 1.1.21');
};

done_testing();
