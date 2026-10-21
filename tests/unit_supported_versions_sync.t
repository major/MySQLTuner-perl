#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_supported_versions_sync.t
# Description: Validates that build/ci_matrix.json is the single source of
#              truth for validate_mysql_version() supported cycles, through
#              build/sync_supported_versions.pl (generation + --check).
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
no warnings 'once';
use Test::More;
use FindBin;
use File::Spec;
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use JSON::PP;

my $root      = File::Spec->catdir( $FindBin::Bin, '..' );
my $generator = File::Spec->catfile( $root, 'build', 'sync_supported_versions.pl' );
my $matrix_f  = File::Spec->catfile( $root, 'build', 'ci_matrix.json' );
my $tuner_f   = File::Spec->catfile( $root, 'mysqltuner.pl' );

require $generator;    # loads build_lists / render_block / replace_block (no exit when required)
{
    local @ARGV = ();
    no warnings 'redefine';
    require $tuner_f;
}

sub slurp { my ($f) = @_; open my $fh, '<', $f or die "$f: $!"; local $/; my $c = <$fh>; close $fh; $c }
my $matrix = decode_json( slurp($matrix_f) );

subtest 'build_lists from ci_matrix structure' => sub {
    plan tests => 4;
    my ( $lts, $short ) = SyncSupportedVersions::build_lists(
        {
            engines => {
                mysql   => { lts => [ '9.7', '8.4' ], legacy_supported => ['8.0'], short_term => [] },
                mariadb => { lts => [ '10.11', '12.3' ], short_term => [ '13.0', '12.3' ] },
            }
        }
    );
    is_deeply( $lts, [qw(8.0 8.4 9.7 10.11 12.3)], 'lts + legacy_supported merged, numerically sorted' );
    is_deeply( $short, ['13.0'], 'short_term kept, LTS duplicates removed' );
    eval { SyncSupportedVersions::build_lists( { engines => { mysql => { lts => ['8.x'] } } } ) };
    like( $@, qr/Invalid cycle '8\.x'/, 'invalid cycle rejected' );
    my ( $l2, $s2 ) = SyncSupportedVersions::build_lists( { engines => {} } );
    is_deeply( [ $l2, $s2 ], [ [], [] ], 'missing engines => empty lists' );
};

subtest 'render_block / replace_block' => sub {
    plan tests => 4;
    my $block = SyncSupportedVersions::render_block( [qw(8.4 9.7)], ['13.0'] );
    like( $block, qr/^our \@SUPPORTED_LTS_VERSIONS        = qw\(8\.4 9\.7\);$/m,  'LTS line rendered' );
    like( $block, qr/^our \@SUPPORTED_SHORT_TERM_VERSIONS = qw\(13\.0\);$/m,     'short-term line rendered' );
    my $src = "a\n# BEGIN GENERATED SUPPORTED VERSIONS (x)\nold\n# END GENERATED SUPPORTED VERSIONS\nb\n";
    is( SyncSupportedVersions::replace_block( $src, $block ), "a\n${block}b\n", 'block replaced between markers' );
    eval { SyncSupportedVersions::replace_block( "no markers\n", $block ) };
    like( $@, qr/markers not found/, 'missing markers => die' );
};

subtest 'mysqltuner.pl is in sync with ci_matrix.json' => sub {
    plan tests => 4;
    my ( $lts, $short ) = SyncSupportedVersions::build_lists($matrix);
    is_deeply( [@main::SUPPORTED_LTS_VERSIONS],        $lts,   '@SUPPORTED_LTS_VERSIONS matches lts + legacy_supported' );
    is_deeply( [@main::SUPPORTED_SHORT_TERM_VERSIONS], $short, '@SUPPORTED_SHORT_TERM_VERSIONS matches short_term' );
    my $out = `$^X "$generator" --check 2>&1`;
    is( $? >> 8, 0, '--check exits 0 on repository' );
    like( $out, qr/\[OK\]/, '--check reports OK' );
};

subtest '--check detects drift and write mode regenerates' => sub {
    plan tests => 5;
    my $dir = tempdir( CLEANUP => 1 );
    my $m2  = File::Spec->catfile( $dir, 'ci_matrix.json' );
    my $t2  = File::Spec->catfile( $dir, 'mysqltuner.pl' );
    copy( $tuner_f, $t2 ) or die "copy: $!";
    my $altered = decode_json( slurp($matrix_f) );
    push @{ $altered->{engines}{mariadb}{short_term} }, '13.1';
    open my $fh, '>', $m2 or die $!;
    print {$fh} encode_json($altered);
    close $fh;

    `$^X "$generator" --check --matrix "$m2" --tuner "$t2" 2>&1`;
    is( $? >> 8, 1, '--check exits 1 when matrix and script differ' );
    my $out = `$^X "$generator" --matrix "$m2" --tuner "$t2" 2>&1`;
    is( $? >> 8, 0, 'write mode exits 0' );
    like( slurp($t2), qr/^our \@SUPPORTED_SHORT_TERM_VERSIONS = qw\([^)]*\b13\.1\b[^)]*\);$/m, 'block regenerated with new cycle' );
    `$^X "$generator" --check --matrix "$m2" --tuner "$t2" 2>&1`;
    is( $? >> 8, 0, '--check passes after regeneration' );
    is( slurp($tuner_f) =~ /13\.1/ ? 1 : 0, 0, 'repository mysqltuner.pl untouched' );
};

subtest 'mysql_version_in_cycles helper' => sub {
    plan tests => 4;
    local $main::myvar{'version'} = '13.0.2-MariaDB';
    ok( main::mysql_version_in_cycles(qw(12.3 13.0)),  '13.0.2 in (12.3, 13.0)' );
    ok( !main::mysql_version_in_cycles(qw(13.1)),      '13.0.2 not in (13.1)' );
    ok( !main::mysql_version_in_cycles(),              'empty list => false' );
    local $main::myvar{'version'} = '10.11.19-MariaDB';
    ok( !main::mysql_version_in_cycles(qw(10.1)),      '10.11 does not match 10.1' );
};

done_testing();
