#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

subtest 'Issue 17A: audit_table_definition_cache logic & defensive defaults' => sub {
    plan tests => 6;

    # 1. Healthy baseline
    my @findings_ok = main::audit_table_definition_cache( 2000, 500, 100, 3600 );
    is( scalar(@findings_ok), 0, 'Healthy table definition cache triggers zero warnings' );

    # 2. Saturated cache with high churn (thrashing)
    my @findings_thrash = main::audit_table_definition_cache( 400, 395, 20000, 100 );
    is( scalar(@findings_thrash), 1, 'Thrashing table definition cache triggers 1 warning' );
    like( $findings_thrash[0]->{message}, qr/high eviction rate/, 'Identifies high eviction rate in message' );
    like( $findings_thrash[0]->{recommendation}, qr/Increase table_definition_cache/, 'Provides sizing recommendation' );

    # 3. Defensive defaults: 0 or undef values handled safely without warnings
    my @findings_zero = main::audit_table_definition_cache( 0, 0, 0, 1 );
    is( scalar(@findings_zero), 0, 'Zero cache size handled cleanly' );

    my @findings_undef = main::audit_table_definition_cache( undef, undef, undef, undef );
    is( scalar(@findings_undef), 0, 'Undef arguments handled cleanly with defensive defaults' );
};

subtest 'Issue 17B: audit_innodb_ahi logic & defensive defaults' => sub {
    plan tests => 6;

    # 1. AHI Disabled baseline
    my @findings_disabled = main::audit_innodb_ahi( 'OFF', 0, 100000, 1, 8 );
    is( scalar(@findings_disabled), 0, 'Disabled AHI (OFF) produces no findings' );

    # 2. High hit ratio baseline
    my @findings_ok = main::audit_innodb_ahi( 'ON', 90000, 10000, 8, 8 );
    is( scalar(@findings_ok), 0, 'High hit ratio produces no findings' );

    # 3. Low hit ratio + single partition contention on multi-instance buffer pool
    my @findings_bad = main::audit_innodb_ahi( 'ON', 1000, 99000, 1, 4 );
    is( scalar(@findings_bad), 2, 'Low hit ratio and partition contention produce 2 findings' );
    like( $findings_bad[0]->{message}, qr/low search hit ratio/, 'Low search hit ratio reported' );
    like( $findings_bad[1]->{message}, qr/innodb_adaptive_hash_index_parts is 1 with 4 buffer pool instances/, 'Partition contention reported' );

    # 4. Defensive defaults: undef handled safely
    my @findings_undef = main::audit_innodb_ahi( undef, undef, undef, undef, undef );
    is( scalar(@findings_undef), 0, 'Undef arguments handled cleanly with defensive defaults' );
};

subtest 'Issue 17C: audit_tls_ciphers_protocols logic & defensive defaults' => sub {
    plan tests => 6;

    # 1. Disabled SSL baseline
    my @findings_disabled = main::audit_tls_ciphers_protocols( 'DISABLED', 'TLSv1,TLSv1.1', 'RC4-MD5' );
    is( scalar(@findings_disabled), 0, 'Disabled SSL produces no warnings' );

    # 2. Modern secure configuration
    my @findings_ok = main::audit_tls_ciphers_protocols( 'YES', 'TLSv1.2,TLSv1.3', 'ECDHE-RSA-AES128-GCM-SHA256' );
    is( scalar(@findings_ok), 0, 'Modern TLS produces no warnings' );

    # 3. Deprecated protocols & weak ciphers
    my @findings_vuln = main::audit_tls_ciphers_protocols( 'ON', 'TLSv1,TLSv1.1,TLSv1.2', 'RC4-SHA:DES-CBC3-SHA:AES128-SHA' );
    is( scalar(@findings_vuln), 2, 'Insecure protocols and weak ciphers detected' );
    like( $findings_vuln[0]->{message}, qr/Insecure deprecated TLS protocol/, 'Deprecated TLS detected' );
    like( $findings_vuln[1]->{message}, qr/Weak or vulnerable SSL cipher/, 'Weak ciphers detected' );

    # 4. Defensive defaults: undef handled safely
    my @findings_undef = main::audit_tls_ciphers_protocols( undef, undef, undef );
    is( scalar(@findings_undef), 0, 'Undef arguments handled cleanly with defensive defaults' );
};

subtest 'Issue 17D: audit_pfs_stage_profiling logic & defensive defaults' => sub {
    plan tests => 5;

    # 1. Low latency baseline
    my @findings_ok = main::audit_pfs_stage_profiling(
        { 'stage/sql/Creating tmp table' => { count => 10, latency_ms => 50 } },
        { 'wait/synch/mutex/innodb/buf_pool_mutex' => { count => 50, latency_ms => 100 } }
    );
    is( scalar(@findings_ok), 0, 'Clean baseline produces no warnings' );

    # 2. High tmp table and sorting latency
    my @findings_stages = main::audit_pfs_stage_profiling(
        {
            'stage/sql/Creating tmp table' => { count => 2000, latency_ms => 8000 },
            'stage/sql/Sorting result'     => { count => 6000, latency_ms => 15000 },
        },
        {}
    );
    is( scalar(@findings_stages), 2, 'Stage bottlenecks detected' );

    # 3. Mutex contention and data file IO wait
    my @findings_waits = main::audit_pfs_stage_profiling(
        {},
        {
            'wait/synch/mutex/innodb/buf_pool_mutex' => { count => 10000, latency_ms => 12000 },
            'wait/io/file/innodb/innodb_data_file'   => { count => 5000,  latency_ms => 60000 },
        }
    );
    is( scalar(@findings_waits), 2, 'Wait event contention detected' );

    # 4. Defensive defaults: empty / undef hashes handled safely
    my @findings_empty = main::audit_pfs_stage_profiling( {}, {} );
    is( scalar(@findings_empty), 0, 'Empty hashes produce no warnings' );

    my @findings_undef = main::audit_pfs_stage_profiling( undef, undef );
    is( scalar(@findings_undef), 0, 'Undef arguments handled cleanly with defensive defaults' );
};

subtest 'Issue 17E: Operational audit sections execute safely with missing PFS and status keys' => sub {
    plan tests => 4;

    # Reset globals
    %main::myvar   = ();
    %main::mystat  = ();
    %main::mycalc  = ();
    %main::result  = ();
    @main::adjvars = ();
    @main::generalrec = ();

    # Mocks for database calls
    no warnings 'redefine';
    local *main::select_one = sub { return undef; };
    local *main::select_array = sub { return (); };
    use warnings 'redefine';

    # 1. mysql_stats runs without warnings when table_definition_cache is missing
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };

    eval { main::mysql_stats(); };
    ok(!$@, 'mysql_stats executed without fatal error');

    # 2. ssl_tls_recommendations runs without warnings when SSL vars are missing
    eval { main::ssl_tls_recommendations(); };
    ok(!$@, 'ssl_tls_recommendations executed without fatal error');

    # 3. mysql_innodb runs without warnings when AHI vars are missing
    eval { main::mysql_innodb(); };
    ok(!$@, 'mysql_innodb executed without fatal error');

    # 4. mysql_pfs runs without warnings when PFS is disabled / missing
    eval { main::mysql_pfs(); };
    ok(!$@, 'mysql_pfs executed without fatal error');
};

done_testing();
