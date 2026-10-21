#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_eol_matrix_update.t
# Description: Validates build/sync_eol_dates.pl --update-matrix / --check:
#              ci_matrix.json computation from endoflife.date data (offline
#              fixtures), exact layout round-trip, drift guard and atomic write.
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

my $root     = File::Spec->catdir( $FindBin::Bin, '..' );
my $script   = File::Spec->catfile( $root, 'build', 'sync_eol_dates.pl' );
my $matrix_f = File::Spec->catfile( $root, 'build', 'ci_matrix.json' );

require $script;    # no exit / no network when required

sub slurp { my ($f) = @_; open my $fh, '<', $f or die "$f: $!"; local $/; return <$fh> }

my $today = '2026-10-14';
my $T = JSON::PP::true;
my $F = JSON::PP::false;

# Fixtures mirroring the endoflife.date API shape
my %raw = (
    mysql => [
        { cycle => '26.7', eol => $F, lts => $F },
        { cycle => '9.7', eol => '2034-04-30', lts => $T },
        { cycle => '9.6', eol => '2026-04-21', lts => $F },
        { cycle => '8.4', eol => '2032-04-30', lts => $T },
        { cycle => '8.0', eol => '2026-04-30', lts => $F },
    ],
    mariadb => [
        { cycle => '13.0',  eol => '2026-12-31', lts => $F },
        { cycle => '12.3',  eol => '2029-06-12', lts => $T },
        { cycle => '11.8',  eol => '2028-06-04', lts => $T },
        { cycle => '11.4',  eol => '2029-05-29', lts => $T },
        { cycle => '10.11', eol => '2028-02-16', lts => $T },
        { cycle => '10.6',  eol => '2026-07-06', lts => $T },
        { cycle => '5.1',   eol => '2015-01-01', lts => $F },
    ],
);

subtest 'helpers (pure)' => sub {
    plan tests => 9;
    ok( SyncEolDates::cycle_cmp( '10.11', '10.9' ) > 0, '10.11 > 10.9 (numeric)' );
    ok( SyncEolDates::cycle_cmp( '9.7', '13.0' ) < 0,   '9.7 < 13.0' );
    ok( SyncEolDates::is_active_eol( '2027-01-01', $today ),  'future EOL is active' );
    ok( !SyncEolDates::is_active_eol( '2026-04-30', $today ), 'past EOL is inactive' );
    ok( SyncEolDates::is_active_eol( $F, $today ),            'eol=false is active' );
    ok( SyncEolDates::is_lts_flag( $T, $today ),              'lts=true' );
    ok( !SyncEolDates::is_lts_flag( $F, $today ),             'lts=false' );
    ok( SyncEolDates::is_lts_flag( '2026-01-01', $today ),    'lts date reached' );
    ok( !SyncEolDates::is_lts_flag( '2027-01-01', $today ),   'lts date in the future' );
};

subtest 'render_matrix_json reproduces the repository layout' => sub {
    plan tests => 1;
    my $content = slurp($matrix_f);
    is( SyncEolDates::render_matrix_json( decode_json($content) ), $content,
        'decode + render round-trip is byte-identical' );
};

subtest 'compute_matrix_update: synchronized matrix is unchanged' => sub {
    plan tests => 2;
    my $m   = decode_json( slurp($matrix_f) );
    my $new = SyncEolDates::compute_matrix_update( $m, \%raw, $today );
    is_deeply( [ SyncEolDates::matrix_changes( $m, $new ) ], [], 'no engine change' );
    is( $new->{generated_at}, $m->{generated_at}, 'generated_at not bumped without change' );
};

subtest 'compute_matrix_update: new cycles and EOL' => sub {
    plan tests => 9;
    my $m = decode_json( slurp($matrix_f) );
    my %r = %raw;
    $r{mariadb} = [ @{ $raw{mariadb} }, { cycle => '13.1', eol => '2027-06-30', lts => $F } ];
    $r{mysql}   = [ grep { $_->{cycle} ne '8.4' } @{ $raw{mysql} },
        { cycle => '8.4', eol => '2026-01-01', lts => $T } ];
    my $new = SyncEolDates::compute_matrix_update( $m, \%r, $today );
    my $md  = $new->{engines}{mariadb};
    my $my  = $new->{engines}{mysql};
    is_deeply( $md->{short_term}, [ '13.0', '13.1' ], 'new short-term cycle added' );
    is_deeply( $md->{lts}, [ '10.11', '11.4', '11.8', '12.3' ], 'EOL 10.6 not supported' );
    ok( ( grep { $_ eq '13.1' } @{ $md->{all} } ), '13.1 appended to all' );
    ok( !( grep { $_ eq '5.1' } @{ $md->{all} } ), 'inactive historical cycle not injected' );
    is_deeply( $my->{lts}, ['9.7'], 'EOL MySQL 8.4 dropped from lts' );
    is_deeply( $my->{supported}, $my->{lts}, 'supported mirrors lts' );
    is_deeply( $my->{legacy_supported}, ['8.0'], 'legacy_supported preserved' );
    is_deeply( $my->{ci_default}, [ '8.0', '8.4' ], 'ci_default preserved' );
    is( $new->{generated_at}, $today, 'generated_at bumped on change' );
};

subtest 'run_matrix_step: --check guard and --update-matrix write' => sub {
    plan tests => 6;
    my $dir = tempdir( CLEANUP => 1 );
    my $tmp = File::Spec->catfile( $dir, 'ci_matrix.json' );
    copy( $matrix_f, $tmp ) or die "copy: $!";
    my $m = decode_json( slurp($tmp) );
    $m->{engines}{mariadb}{short_term} = [];
    open my $fh, '>', $tmp or die $!;
    print $fh SyncEolDates::render_matrix_json($m);
    close $fh;
    my $before = slurp($tmp);

    my $out = '';
    my $rc;
    {
        open my $o, '>', \$out or die;
        my $old = select $o;
        $rc = SyncEolDates::run_matrix_step( $tmp, \%raw, $today, 0 );
        select $old;
    }
    is( $rc, 1, '--check exits 1 when outdated' );
    like( $out, qr/mariadb\.short_term: \[\] -> \[13\.0\]/, 'proposed change listed' );
    is( slurp($tmp), $before, '--check does not write' );

    {
        open my $o, '>', \$out or die;
        my $old = select $o;
        $rc = SyncEolDates::run_matrix_step( $tmp, \%raw, $today, 1 );
        select $old;
    }
    is( $rc, 0, '--update-matrix succeeds' );
    is_deeply( decode_json( slurp($tmp) )->{engines}{mariadb}{short_term}, ['13.0'], 'matrix updated' );
    ok( !glob("$tmp.tmp.*"), 'no temporary file left (atomic rename)' );
};

done_testing();
