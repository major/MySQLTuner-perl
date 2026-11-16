#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Challenger M4-2: Empirical Adversarial Stress Test Suite for Issue 17
# Tests all 4 connected diagnostic auditors under extreme edge cases,
# zero/negative/undef values, boundary conditions, and operational integration.

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

# -----------------------------------------------------------------------------
# 1. audit_table_definition_cache: Extreme Boundary & Edge-Case Stress Testing
# -----------------------------------------------------------------------------
subtest 'Challenger 17.1: audit_table_definition_cache adversarial stress' => sub {
    plan tests => 14;

    # Zero / negative uptime & cache (Division by zero prevention)
    is( scalar(main::audit_table_definition_cache( 400, 400, 1000, 0 )), 0,
        'Zero uptime returns empty findings without division by zero' );
    is( scalar(main::audit_table_definition_cache( 400, 400, 1000, -100 )), 0,
        'Negative uptime returns empty findings' );
    is( scalar(main::audit_table_definition_cache( 0, 400, 1000, 3600 )), 0,
        'Zero cache size returns empty findings without division by zero' );
    is( scalar(main::audit_table_definition_cache( -200, 400, 1000, 3600 )), 0,
        'Negative cache size returns empty findings' );
    is( scalar(main::audit_table_definition_cache( undef, undef, undef, undef )), 0,
        'All undef arguments cleanly handled' );
    is( scalar(main::audit_table_definition_cache( 0, 0, 0, 0 )), 0,
        'All zero arguments handled cleanly' );

    # Fractional uptime
    my @frac_findings = main::audit_table_definition_cache( 400, 395, 20000, 0.5 );
    is( scalar(@frac_findings), 1, 'Fractional sub-second uptime handled accurately' );

    # Boundary tests for fill_ratio threshold (90.0%)
    # Fill ratio: 89.9% (359/400) -> should NOT trigger
    my @f_89 = main::audit_table_definition_cache( 1000, 899, 100000, 100 );
    is( scalar(@f_89), 0, 'Fill ratio 89.9% does not trigger warning' );

    # Fill ratio: 90.0% (900/1000) -> triggers warning when open_rate > 5 and opened > cache*2
    my @f_90 = main::audit_table_definition_cache( 1000, 900, 100000, 100 );
    is( scalar(@f_90), 1, 'Fill ratio 90.0% triggers warning at boundary' );

    # Boundary tests for open_rate threshold (5.0 opened/sec)
    # open_rate = 500 / 100 = 5.0 -> should NOT trigger (must be > 5.0)
    my @f_rate5 = main::audit_table_definition_cache( 1000, 950, 5000, 1000 );
    is( scalar(@f_rate5), 0, 'Eviction rate exactly 5.0 opened/sec does not trigger' );

    # Boundary tests for opened_table_definitions threshold (> cache * 2)
    # opened = cache * 2 (2000 for cache 1000) -> should NOT trigger (must be > 2000)
    my @f_opened2x = main::audit_table_definition_cache( 1000, 950, 2000, 10 );
    is( scalar(@f_opened2x), 0, 'Opened definitions equal to 2x cache size does not trigger' );

    # Sizing recommendation calculation:
    # 1. When cache is small (400), 400 * 1.5 = 600 < 2000 -> suggests >= 2000
    my @f_small = main::audit_table_definition_cache( 400, 395, 10000, 100 );
    like( $f_small[0]->{recommendation}, qr/suggest >= 2000/, 'Small cache recommendation clamps to 2000 minimum' );

    # 2. When cache is large (4000), 4000 * 1.5 = 6000 > 2000 -> suggests >= 6000
    my @f_large = main::audit_table_definition_cache( 4000, 3950, 100000, 100 );
    like( $f_large[0]->{recommendation}, qr/suggest >= 6000/, 'Large cache recommendation scales to 1.5x (6000)' );

    # Huge numbers (stress memory & formatting)
    my @f_huge = main::audit_table_definition_cache( 100000, 99999, 10000000000, 1000000 );
    is( scalar(@f_huge), 1, 'Astronomical metrics handled without overflow or scientific notation crash' );
};

# -----------------------------------------------------------------------------
# 2. audit_innodb_ahi: Adversarial Stress Testing
# -----------------------------------------------------------------------------
subtest 'Challenger 17.2: audit_innodb_ahi adversarial stress' => sub {
    plan tests => 14;

    # Disabled variations (case variations and numeric flags)
    is( scalar(main::audit_innodb_ahi( 'off', 100, 99999, 1, 8 )), 0, 'Lowercase "off" returns empty findings' );
    is( scalar(main::audit_innodb_ahi( '0', 100, 99999, 1, 8 )), 0, 'Numeric "0" returns empty findings' );
    is( scalar(main::audit_innodb_ahi( 'FALSE', 100, 99999, 1, 8 )), 0, 'String "FALSE" returns empty findings' );
    is( scalar(main::audit_innodb_ahi( 'no', 100, 99999, 1, 8 )), 0, 'String "no" returns empty findings' );
    is( scalar(main::audit_innodb_ahi( 'DISABLED', 100, 99999, 1, 8 )), 0, 'String "DISABLED" returns empty findings' );

    # All undef baseline (defensive defaults)
    is( scalar(main::audit_innodb_ahi( undef, undef, undef, undef, undef )), 0, 'All undef arguments cleanly handled' );

    # Search count boundary (threshold is > 50000)
    # Total = 50000 exactly -> should NOT trigger low hit ratio warning
    my @f_tot50k = main::audit_innodb_ahi( 'ON', 500, 49500, 8, 8 );
    is( scalar(@f_tot50k), 0, 'Total searches exactly 50000 does not trigger hit ratio warning' );

    # Total = 50001 with hit ratio >= 15.00% -> should NOT trigger (must be < 15.0%)
    # 7501 / 50001 = 15.0016%
    my @f_ratio15 = main::audit_innodb_ahi( 'ON', 7501, 42500, 8, 8 );
    is( scalar(@f_ratio15), 0, 'Hit ratio >= 15.0% does not trigger warning' );

    # Total = 50001 with hit ratio < 15.0% (e.g. 7490 / 50001 = 14.979%)
    my @f_low = main::audit_innodb_ahi( 'ON', 7490, 42511, 8, 8 );
    is( scalar(@f_low), 1, 'Hit ratio < 15.0% triggers warning' );
    like( $f_low[0]->{recommendation}, qr/innodb_adaptive_hash_index/, 'Recommends tuning innodb_adaptive_hash_index' );

    # Buffer pool instances & partition contention
    # bp_instances <= 1 -> should NEVER trigger partition contention warning
    is( scalar(main::audit_innodb_ahi( 'ON', 90000, 10000, 1, 1 )), 0, 'Single buffer pool instance does not warn on parts=1' );
    is( scalar(main::audit_innodb_ahi( 'ON', 90000, 10000, 1, 0 )), 0, 'Zero buffer pool instances does not warn on parts=1' );
    is( scalar(main::audit_innodb_ahi( 'ON', 90000, 10000, 1, -4 )), 0, 'Negative buffer pool instances does not warn on parts=1' );

    # Multi-instance with parts > 1 -> should NOT trigger partition warning
    is( scalar(main::audit_innodb_ahi( 'ON', 90000, 10000, 4, 8 )), 0, 'Multi-instance with multiple parts (4) does not warn' );
};

# -----------------------------------------------------------------------------
# 3. audit_tls_ciphers_protocols: Adversarial Stress Testing
# -----------------------------------------------------------------------------
subtest 'Challenger 17.3: audit_tls_ciphers_protocols adversarial stress' => sub {
    plan tests => 13;

    # Disabled SSL variations
    is( scalar(main::audit_tls_ciphers_protocols( 'DISABLED', 'TLSv1', 'RC4-MD5' )), 0, 'DISABLED SSL emits no warnings' );
    is( scalar(main::audit_tls_ciphers_protocols( '0', 'TLSv1', 'RC4-MD5' )), 0, 'Numeric 0 SSL emits no warnings' );
    is( scalar(main::audit_tls_ciphers_protocols( 'NO', 'TLSv1', 'RC4-MD5' )), 0, 'NO SSL emits no warnings' );
    is( scalar(main::audit_tls_ciphers_protocols( 'OFF', 'TLSv1', 'RC4-MD5' )), 0, 'OFF SSL emits no warnings' );
    is( scalar(main::audit_tls_ciphers_protocols( undef, undef, undef )), 0, 'All undef arguments cleanly handled' );

    # Protocol variations
    # TLSv1.0 alias
    my @f_proto1 = main::audit_tls_ciphers_protocols( 'YES', 'TLSv1.0', '' );
    is( scalar(@f_proto1), 1, 'TLSv1.0 detected as deprecated' );

    # TLSv1.1 alias
    my @f_proto11 = main::audit_tls_ciphers_protocols( 'YES', 'TLSv1.1', '' );
    is( scalar(@f_proto11), 1, 'TLSv1.1 detected as deprecated' );

    # TLSv1 bare alias
    my @f_protov1 = main::audit_tls_ciphers_protocols( 'YES', 'TLSv1', '' );
    is( scalar(@f_protov1), 1, 'TLSv1 bare detected as deprecated' );

    # Case-insensitive lowercase
    my @f_proto_lc = main::audit_tls_ciphers_protocols( 'YES', 'tlsv1.0,TLSv1.2', '' );
    is( scalar(@f_proto_lc), 1, 'tlsv1.0 detected as deprecated' );

    # Pure modern TLS
    my @f_modern = main::audit_tls_ciphers_protocols( 'YES', 'TLSv1.2,TLSv1.3', '' );
    is( scalar(@f_modern), 0, 'Modern TLSv1.2,TLSv1.3 emits no deprecated protocol warnings' );

    # Comprehensive Weak Cipher Detection
    my @f_ciphers = main::audit_tls_ciphers_protocols(
        'YES',
        'TLSv1.2',
        'ECDHE-RSA-AES128-GCM-SHA256:RC4-MD5:DES-CBC3-SHA:ADH-AES128-SHA:NULL-SHA256:EXP-DES-CBC-SHA'
    );
    is( scalar(@f_ciphers), 1, 'Weak ciphers identified in mixed suite' );
    like( $f_ciphers[0]->{message}, qr/RC4-MD5/, 'Identified RC4-MD5' );
    like( $f_ciphers[0]->{message}, qr/DES-CBC3-SHA/, 'Identified 3DES' );
};

# -----------------------------------------------------------------------------
# 4. audit_pfs_stage_profiling: Adversarial Stress Testing
# -----------------------------------------------------------------------------
subtest 'Challenger 17.4: audit_pfs_stage_profiling adversarial stress' => sub {
    plan tests => 11;

    # No arguments / undef arguments
    is( scalar(main::audit_pfs_stage_profiling()), 0, 'Call with zero arguments safe' );
    is( scalar(main::audit_pfs_stage_profiling(undef, undef)), 0, 'Call with undef arguments safe' );
    is( scalar(main::audit_pfs_stage_profiling({}, {})), 0, 'Call with empty hashes safe' );

    # Stage event exact boundaries
    # Creating tmp table: count > 1000 and latency > 5000
    is( scalar(main::audit_pfs_stage_profiling(
        { 'stage/sql/Creating tmp table' => { count => 1000, latency_ms => 6000 } }, {}
    )), 0, 'Tmp table count 1000 (boundary) does not trigger' );

    is( scalar(main::audit_pfs_stage_profiling(
        { 'stage/sql/Creating tmp table' => { count => 2000, latency_ms => 5000 } }, {}
    )), 0, 'Tmp table latency 5000 (boundary) does not trigger' );

    is( scalar(main::audit_pfs_stage_profiling(
        { 'stage/sql/Creating tmp table' => { count => 1001, latency_ms => 5001 } }, {}
    )), 1, 'Tmp table count 1001 and latency 5001 triggers warning' );

    # Sorting result: count > 5000 and latency > 10000
    is( scalar(main::audit_pfs_stage_profiling(
        { 'stage/sql/Sorting result' => { count => 5000, latency_ms => 15000 } }, {}
    )), 0, 'Sorting count 5000 (boundary) does not trigger' );

    is( scalar(main::audit_pfs_stage_profiling(
        { 'stage/sql/Sorting result' => { count => 6000, latency_ms => 10000 } }, {}
    )), 0, 'Sorting latency 10000 (boundary) does not trigger' );

    is( scalar(main::audit_pfs_stage_profiling(
        { 'stage/sql/Sorting result' => { count => 5001, latency_ms => 10001 } }, {}
    )), 1, 'Sorting count 5001 and latency 1001 triggers warning' );

    # Mutex & IO Wait event exact boundaries
    is( scalar(main::audit_pfs_stage_profiling(
        {},
        { 'wait/synch/mutex/innodb/buf_pool_mutex' => { count => 100, latency_ms => 10000 } }
    )), 0, 'Mutex wait latency 10000 (boundary) does not trigger' );

    is( scalar(main::audit_pfs_stage_profiling(
        {},
        { 'wait/io/file/innodb/innodb_data_file' => { count => 100, latency_ms => 50000 } }
    )), 0, 'IO wait latency 50000 (boundary) does not trigger' );
};

# -----------------------------------------------------------------------------
# 5. Operational Integration & Duplicate Warning Prevention
# -----------------------------------------------------------------------------
subtest 'Challenger 17.5: Operational integration & duplicate warning prevention' => sub {
    plan tests => 9;

    # Reset globals
    %main::myvar   = ();
    %main::mystat  = ();
    %main::mycalc  = ();
    %main::result  = ();
    @main::adjvars = ();
    @main::generalrec = ();
    @main::ssl_csv_rows = ();

    no warnings 'redefine';
    local *main::select_one = sub { return undef; };
    local *main::select_array = sub { return (); };
    use warnings 'redefine';

    # 1. Verify TLS warnings are not duplicated in ssl_tls_recommendations
    $main::myvar{'have_ssl'}    = 'YES';
    $main::myvar{'tls_version'} = 'TLSv1.0,TLSv1.2';
    $main::myvar{'ssl_cipher'}  = 'RC4-SHA';

    my @printed_lines;
    no warnings 'redefine';
    local *main::badprint = sub { push @printed_lines, $_[0] };
    local *main::goodprint = sub { };
    local *main::infoprint = sub { };
    use warnings 'redefine';

    main::ssl_tls_recommendations();

    my @insecure_tls_lines = grep { /Insecure (?:TLS|deprecated)/i } @printed_lines;
    is( scalar(@insecure_tls_lines), 1, 'Insecure TLS warning printed exactly ONCE (no duplicates)' );

    my @cipher_lines = grep { /Weak or vulnerable SSL cipher/i } @printed_lines;
    is( scalar(@cipher_lines), 1, 'Weak cipher warning printed exactly once' );

    ok( defined $main::result{'TLSCiphersProtocols'}, 'TLSCiphersProtocols structured findings stored in %result' );

    # 2. Verify Table Definition Cache integration in mysql_stats
    %main::myvar  = ( 'table_definition_cache' => 400 );
    %main::mystat = (
        'Open_table_definitions'   => 395,
        'Opened_table_definitions' => 20000,
        'Uptime'                   => 100
    );
    @main::generalrec = ();

    main::mysql_stats();
    ok( grep( { /Increase table_definition_cache/ } @main::generalrec ),
        'Table definition cache recommendation added to @generalrec in mysql_stats' );
    ok( defined $main::result{'TableDefinitionCache'},
        'TableDefinitionCache structured findings stored in %result' );

    # 3. Verify AHI integration in mysql_innodb
    %main::myvar = (
        'have_innodb'                      => 'YES',
        'innodb_adaptive_hash_index'       => 'ON',
        'innodb_adaptive_hash_index_parts' => 1,
        'innodb_buffer_pool_instances'     => 4
    );
    $main::enginestats{'InnoDB'} = 10;
    %main::mystat = (
        'Innodb_adaptive_hash_searches'       => 1000,
        'Innodb_adaptive_hash_searches_btree' => 99000,
    );
    @main::generalrec = ();

    main::mysql_innodb();
    ok( grep( { /innodb_adaptive_hash_index_parts/ } @main::generalrec ),
        'AHI partition contention recommendation added to @generalrec in mysql_innodb' );
    ok( defined $main::result{'InnoDBAHI'},
        'InnoDBAHI structured findings stored in %result' );

    # 4. Verify PFS stage profiling integration in mysql_pfs
    %main::myvar = ( 'performance_schema' => 'ON' );
    $main::opt{pfstat} = 1;
    @main::generalrec = ();

    no warnings 'redefine';
    local *main::select_array = sub {
        my ($sql) = @_;
        if ( $sql =~ /events_stages_summary_global_by_event_name/ ) {
            return ("stage/sql/Creating tmp table\t2000\t8000.50");
        }
        elsif ( $sql =~ /events_waits_summary_global_by_event_name/ ) {
            return ("wait/synch/mutex/innodb/buf_pool_mutex\t5000\t15000.25");
        }
        elsif ( $sql =~ /SHOW DATABASES/ ) {
            return (); # Sys schema not installed
        }
        return ();
    };
    use warnings 'redefine';

    main::mysql_pfs();
    ok( grep( { /Review queries generating temporary tables/ } @main::generalrec ),
        'PFS stage profiling recommendation added to @generalrec in mysql_pfs' );
    ok( defined $main::result{'PFSStageProfiling'},
        'PFSStageProfiling structured findings stored in %result' );
};

done_testing();
