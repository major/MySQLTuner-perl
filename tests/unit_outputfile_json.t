#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 5;
use File::Temp qw(tempdir);
use File::Spec;
use JSON;

require './mysqltuner.pl';

subtest 'prettyjson flag enables json export mode' => sub {
    plan tests => 2;

    local %main::opt = (
        'prettyjson' => 1,
        'color'      => 0,
    );

    main::setup_environment();
    is($main::opt{'prettyjson'}, 1, 'prettyjson is set');
    is($main::opt{'json'},       1, 'json is automatically enabled when prettyjson is true');
};

subtest 'outputfile with json does not open raw text fh' => sub {
    plan tests => 2;

    my $tempdir = tempdir(CLEANUP => 1);
    my $target_json = File::Spec->catfile($tempdir, 'output.json');

    local %main::opt = (
        'json'       => 1,
        'outputfile' => $target_json,
        'color'      => 0,
    );

    main::setup_environment();
    ok(!defined($main::fh), 'raw text $fh is NOT opened when json mode is active');
    main::close_outputfile();
    ok(!defined($main::fh), 'close_outputfile keeps $fh undefined');
};

subtest 'outputfile creates nested parent directories automatically' => sub {
    plan tests => 2;

    my $tempdir = tempdir(CLEANUP => 1);
    my $nested_dir = File::Spec->catdir($tempdir, 'nested', 'reports');
    my $target_json = File::Spec->catfile($nested_dir, 'run.json');

    local %main::opt = (
        'json'       => 1,
        'outputfile' => $target_json,
        'color'      => 0,
    );

    ok(!-d $nested_dir, 'nested directory does not exist prior to setup');
    main::setup_environment();
    ok(-d $nested_dir, 'setup_environment automatically creates parent directory for outputfile');
    main::close_outputfile();
};

subtest 'close_outputfile properly closes and undefs fh' => sub {
    plan tests => 3;

    my $tempdir = tempdir(CLEANUP => 1);
    my $text_file = File::Spec->catfile($tempdir, 'text_output.txt');

    local %main::opt = (
        'outputfile' => $text_file,
        'color'      => 0,
    );

    main::setup_environment();
    ok(defined($main::fh), '$fh is opened for text output');
    main::close_outputfile();
    ok(!defined($main::fh), '$fh is undefined after close_outputfile');
    eval { main::close_outputfile(); };
    is($@, '', 'idempotent call to close_outputfile causes no errors');
};

subtest 'dump_result exports clean JSON without raw CLI interference' => sub {
    plan tests => 3;

    my $tempdir = tempdir(CLEANUP => 1);
    my $target_json = File::Spec->catfile($tempdir, 'audit.json');

    local %main::opt = (
        'prettyjson' => 1,
        'outputfile' => $target_json,
        'silent'     => 1,
    );

    main::setup_environment();

    {
        no warnings 'once';
        %main::result = (
            'MySQLTuner'  => { 'version' => '2.9.3' },
            'HealthScore' => 85,
        );
    }

    main::dump_result();
    main::goodprint("Terminated successfully");
    main::close_outputfile();

    ok(-f $target_json, 'target JSON file was created');

    open my $fh, '<', $target_json or die "Cannot open $target_json: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $decoded;
    eval {
        $decoded = JSON::decode_json($content);
    };
    is($@, '', 'output file is strictly valid JSON without raw CLI contamination');
    is($decoded->{'HealthScore'}, 85, 'HealthScore metric was parsed correctly from exported JSON');
};
