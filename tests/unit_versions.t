use strict;
use warnings;
no warnings 'once';
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Suppress warnings from mysqltuner.pl initialization if any
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Load mysqltuner.pl as a library
my $script_dir = dirname( abs_path(__FILE__) );
my $script =
  abs_path( File::Spec->catfile( $script_dir, '..', 'mysqltuner.pl' ) );
require $script;

# 1. Test compare_tuner_version
# This function is not pure, it uses global $tunerversion and prints.
subtest 'compare_tuner_version' => sub {
    no warnings 'redefine';
    local *main::goodprint            = sub { };
    local *main::badprint             = sub { };
    local *main::update_tuner_version = sub { };

    $main::tunerversion = "2.8.33";

    # It returns undef, so we just check if it runs without crashing for now
    # or check the behavior if we mocked the prints to capture output.
    ok( defined eval { main::compare_tuner_version("2.8.33"); 1 },
        "Runs with same version" );
    ok( defined eval { main::compare_tuner_version("2.9.0"); 1 },
        "Runs with newer version" );
};

subtest 'mysql_version comparisons with cache' => sub {
    $main::myvar{'version'} = '8.0.33';
    ok( main::mysql_version_eq( 8, 0, 33 ), '8.0.33 eq 8.0.33' );
    ok( main::mysql_version_eq( 8, 0 ),     '8.0.33 eq 8.0' );
    ok( main::mysql_version_eq(8),          '8.0.33 eq 8' );
    ok( !main::mysql_version_eq( 5, 7 ),    '8.0.33 not eq 5.7' );

    ok( main::mysql_version_ge( 8, 0, 30 ), '8.0.33 ge 8.0.30' );
    ok( main::mysql_version_ge( 8,  0 ), '8.0.33 ge 8.0' );
    ok( !main::mysql_version_ge( 9, 0 ), '8.0.33 not ge 9.0' );

    ok( main::mysql_version_le( 8, 0, 35 ), '8.0.33 le 8.0.35' );
    ok( main::mysql_version_le( 9,  0 ), '8.0.33 le 9.0' );
    ok( !main::mysql_version_le( 5, 7 ), '8.0.33 not le 5.7' );
};

subtest '_to_yaml serialization' => sub {
    my $data = {
        name    => 'MySQLTuner',
        version => '2.9.0',
        special => '2:9#0',
        active  => 1,
        details => {
            perf_bp   => 10,
            empty_val => '',
        },
        list => [ 'a', 'b', { k => 'v' } ],
    };

    my $yaml = main::_to_yaml($data);

    # Check that strings are generated correctly
    like( $yaml, qr/name: MySQLTuner/, 'Plain scalar serialized correctly' );
    like( $yaml, qr/version: 2\.9\.0/, 'Unquoted scalar serialized correctly' );
    like(
        $yaml,
        qr/special: '2:9#0'/,
        'Quoted scalar (with special chars) serialized correctly'
    );
    like( $yaml, qr/active: 1/,     'Number serialized correctly' );
    like( $yaml, qr/empty_val: ''/, 'Empty string serialized correctly' );
    like( $yaml, qr/perf_bp: 10/,   'Nested hash scalar serialized correctly' );
    like( $yaml, qr/list:/,         'Array prefix serialized correctly' );
    like( $yaml, qr/-\s+a/,         'Array items serialized correctly' );
    like( $yaml, qr/-\s+k:\s+v/,
        'Array with nested hash serialized correctly' );
};

subtest 'historical_comparison health score' => sub {
    no warnings 'redefine';
    my $captured_trend;
    local *main::infoprint = sub {
        my $msg = shift;
        if ( $msg =~ /Health Score Trend/ ) {
            $captured_trend = $msg;
        }
    };
    local *main::badprint = sub { };

    # Prepare current results
    $main::result{'HealthScore'} = 85;

    # Mocking reading from file
    my $compare_json =
'{"General":{"Date":"2026-06-15"},"HealthScore":70,"Stats":{"QPS":1.5,"Total Data Size":1000}}';

    my $temp_file = File::Spec->catfile( $script_dir, 'temp_compare.json' );
    open my $tfh, '>', $temp_file or die $!;
    print $tfh $compare_json;
    close $tfh;

    local $main::opt{'compare-file'} = $temp_file;
    main::historical_comparison();

    unlink $temp_file;

    ok( defined $captured_trend,
        "Health score trend comparison was triggered" );
    like(
        $captured_trend,
        qr/70 -> 85 \(\+15\)/,
        "Trend correctly shows +15 improvement"
    );
};

done_testing();
