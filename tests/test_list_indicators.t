#!/usr/bin/env perl
# ===========================================================================
# Test:        tests/test_list_indicators.t
# Description: Unit test suite for --list-indicators offline JSON export contract.
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
use Test::More;
use File::Spec;
use FindBin;
use JSON::PP qw(decode_json);

my $PROJECT_ROOT  = File::Spec->catdir( $FindBin::Bin, '..' );
my $MYSQLTUNER_PL = File::Spec->catfile( $PROJECT_ROOT, 'mysqltuner.pl' );

ok( -f $MYSQLTUNER_PL, "mysqltuner.pl exists at $MYSQLTUNER_PL" );

my $cmd = "$^X " . File::Spec->catfile( $PROJECT_ROOT, 'mysqltuner.pl' ) . " --list-indicators 2>&1";
my $raw_output = `$cmd`;
my $exit_code  = $? >> 8;

my $data;

# --- Subtest 1: CLI Execution & Offline Exit Status ---
subtest 'Subtest 1: CLI Execution & Exit Status 0 (Offline)' => sub {
    plan tests => 3;

    is( $exit_code, 0, 'mysqltuner.pl --list-indicators exits cleanly with status 0' );
    ok( length($raw_output) > 100, 'Produced substantial stdout payload (> 100 bytes)' );
    like( $raw_output, qr/^\s*\{/, 'Stdout starts with JSON object delimiter {' );
};

# --- Subtest 2: JSON Decoding and Top-Level Schema Validation ---
subtest 'Subtest 2: JSON Decoding and Top-Level Schema Validation' => sub {
    plan tests => 8;

    $data = eval { decode_json($raw_output) };
    ok( defined $data, 'Successfully parsed stdout via JSON::PP::decode_json' )
      or diag("JSON parse error: $@");

    is( ref $data, 'HASH', 'Top-level payload is a JSON Object (HASH)' );
    like( $data->{version}, qr/^\d+\.\d+\.\d+/, "Version field is present and formatted ($data->{version})" );
    is( ref $data->{features},    'ARRAY', 'features key is an ARRAY ref' );
    is( ref $data->{summary},     'HASH',  'summary key is a HASH ref' );
    is( ref $data->{cli_options}, 'HASH',  'cli_options key is a HASH ref' );
    is( ref $data->{diagnostics}, 'HASH',  'diagnostics key is a HASH ref' );
    is( ref $data->{indicators},  'ARRAY', 'indicators key is an ARRAY ref' );
};

# --- Subtest 3: Features Contract Verification ---
subtest 'Subtest 3: Features Contract Verification' => sub {
    plan tests => 5;

    my @features = @{ $data->{features} // [] };
    cmp_ok( scalar @features, '>=', 39, 'Features catalog contains at least 39 items' );

    my %feat_map = map { $_ => 1 } @features;
    ok( $feat_map{'validate_mysql_version'},     'Contains report section: validate_mysql_version' );
    ok( $feat_map{'system_recommendations'},     'Contains report section: system_recommendations' );
    ok( $feat_map{'audit_deprecated_variables'}, 'Contains standalone audit sub: audit_deprecated_variables' );
    ok( $feat_map{'generate_auto_fix_snippets'}, 'Contains report section: generate_auto_fix_snippets' );
};

# --- Subtest 4: Indicators Metadata & Required Fields ---
subtest 'Subtest 4: Indicators Metadata & Required Fields' => sub {
    plan tests => 8;

    my @indicators = @{ $data->{indicators} // [] };
    cmp_ok( scalar @indicators, '>=', 500, 'Catalog contains >= 500 indicators' );

    my $valid_severities = { OK => 1, WARN => 1, INFO => 1, REC => 1 };
    my $valid_types      = { good => 1, bad => 1, info => 1, rec => 1 };
    my $valid_categories = {
        General     => 1,
        System      => 1,
        Storage     => 1,
        Modeling    => 1,
        Performance => 1,
        Security    => 1,
        HA          => 1,
        Capacity    => 1,
        Automation  => 1,
    };

    my $invalid_id       = 0;
    my $invalid_sev      = 0;
    my $invalid_type     = 0;
    my $invalid_cat      = 0;
    my $missing_sub      = 0;
    my $missing_desc     = 0;

    for my $ind (@indicators) {
        $invalid_id++   unless defined $ind->{id} && $ind->{id} =~ /^IND-\d{4,}$/;
        $invalid_sev++  unless defined $ind->{severity} && $valid_severities->{ $ind->{severity} };
        $invalid_type++ unless defined $ind->{type} && $valid_types->{ $ind->{type} };
        $invalid_cat++  unless defined $ind->{category} && $valid_categories->{ $ind->{category} };
        $missing_sub++  unless defined $ind->{subroutine} && length( $ind->{subroutine} );
        $missing_desc++ unless defined $ind->{description};
    }

    is( $invalid_id,   0, '100% of indicators have compliant identifier format (IND-XXXX)' );
    is( $invalid_sev,  0, '100% of indicators have valid severity (OK, WARN, INFO, REC)' );
    is( $invalid_type, 0, '100% of indicators have valid status/type (good, bad, info, rec)' );
    is( $invalid_cat,  0, '100% of indicators map to recognized functional categories' );
    is( $missing_sub,  0, '100% of indicators identify enclosing subroutine' );
    is( $missing_desc, 0, '100% of indicators have defined description string' );

    my $first = $indicators[0];
    ok( defined $first && $first->{id} eq 'IND-0001', 'First indicator is indexed as IND-0001' );
};

# --- Subtest 5: Summary Metrics & Mathematical Consistency ---
subtest 'Subtest 5: Summary Metrics & Mathematical Consistency' => sub {
    plan tests => 7;

    my $sum = $data->{summary} // {};

    cmp_ok( $sum->{good}, '>', 0, "good indicators count > 0 ($sum->{good})" );
    cmp_ok( $sum->{bad},  '>', 0, "bad indicators count > 0 ($sum->{bad})" );
    cmp_ok( $sum->{info}, '>', 0, "info indicators count > 0 ($sum->{info})" );
    cmp_ok( $sum->{rec},  '>', 0, "rec indicators count > 0 ($sum->{rec})" );

    my $computed_total = $sum->{good} + $sum->{bad} + $sum->{info} + $sum->{rec};
    is( $sum->{total}, $computed_total, "Mathematical consistency: total ($sum->{total}) == good + bad + info + rec ($computed_total)" );
    is( $sum->{total}, scalar @{ $data->{indicators} }, 'summary.total matches indicators array length' );
    is( $sum->{features}, scalar @{ $data->{features} }, 'summary.features matches features array length' );
};

# --- Subtest 6: CLI Options Schema Verification ---
subtest 'Subtest 6: CLI Options Schema Verification' => sub {
    plan tests => 7;

    my $opts = $data->{cli_options} // {};
    cmp_ok( scalar keys %$opts, '>=', 77, 'cli_options schema exports >= 77 primary options' );

    ok( exists $opts->{'list-indicators'}, 'Export contains list-indicators option' );
    my $li = $opts->{'list-indicators'} // {};
    is( $li->{cat}, 'PERFORMANCE', 'list-indicators belongs to PERFORMANCE category' );
    is( $li->{type}, '!', 'list-indicators type is boolean negatable (!)' );
    is( $li->{default}, 0, 'list-indicators default is 0' );
    ok( length( $li->{desc} ) > 10, 'list-indicators has informative description' );

    ok( exists $opts->{'help'} && exists $opts->{'user'} && exists $opts->{'host'}, 'Contains standard options: help, user, host' );
};

# --- Subtest 7: Diagnostics Buckets Invariant for Release Notes Generator ---
subtest 'Subtest 7: Diagnostics Buckets Invariant for Release Notes Generator' => sub {
    plan tests => 4;

    my $diag = $data->{diagnostics} // {};
    is( ref $diag, 'HASH', 'diagnostics is a HASH' );

    cmp_ok( scalar keys %{ $diag->{good} // {} }, '>', 0, 'diagnostics.good bucket is populated' );
    cmp_ok( scalar keys %{ $diag->{bad}  // {} }, '>', 0, 'diagnostics.bad bucket is populated' );
    cmp_ok( scalar keys %{ $diag->{info} // {} }, '>', 0, 'diagnostics.info bucket is populated' );
};

done_testing();
