#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_deprecated_vars_audit.t
# Description: Validates Deprecated System Variables & Synonyms Audit (Phase 25)
#              across MySQL 5.7, 8.0, 8.4, 9.x and MariaDB versions.
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;

require "$FindBin::Bin/../mysqltuner.pl";

plan tests => 5;

# --- Subtest 1: Obsolete Synonyms (log_slow_queries & table_cache) ---
subtest 'Obsolete Synonyms Detection' => sub {
    plan tests => 5;

    # Reset globals
    %main::myvar = (
        'version'          => '8.0.36',
        'log_slow_queries' => 'ON',
        'table_cache'      => '512'
    );
    @main::generalrec = ();
    @main::sysrec     = ();
    %main::result     = ();

    main::audit_deprecated_variables();

    is(scalar(@main::generalrec), 2, "2 recommendations generated for obsolete synonyms");
    ok(grep(/replace log_slow_queries with slow_query_log/, @main::generalrec), "Found slow query log synonym advice");
    ok(grep(/replace table_cache with table_open_cache/, @main::generalrec), "Found table_cache synonym advice");
    is(scalar(@{ $main::result{'Deprecated_Variables'} }), 2, "Recorded in result structure");
    is($main::result{'Deprecated_Variables'}->[0]{variable}, 'log_slow_queries', "First recorded variable is log_slow_queries");
};

# --- Subtest 2: tx_isolation & tx_read_only Deprecation in MySQL 8.0+ ---
subtest 'Transaction Isolation Deprecated Variables in MySQL 8.0+' => sub {
    plan tests => 4;

    # Scenario: MySQL 8.0 with tx_isolation
    %main::myvar = (
        'version'      => '8.0.36',
        'tx_isolation' => 'REPEATABLE-READ',
        'tx_read_only' => '0'
    );
    @main::generalrec = ();
    @main::sysrec     = ();
    %main::result     = ();

    main::audit_deprecated_variables();

    is(scalar(@main::generalrec), 2, "2 recommendations generated for tx_* variables");
    ok(grep(/replace tx_isolation with transaction_isolation/, @main::generalrec), "Recommended transaction_isolation");
    ok(grep(/replace tx_read_only with transaction_read_only/, @main::generalrec), "Recommended transaction_read_only");
    is(scalar(@{ $main::result{'Deprecated_Variables'} }), 2, "Recorded 2 deprecations");
};

# --- Subtest 3: Legacy MySQL 5.7 (tx_isolation should NOT be flagged as removed) ---
subtest 'tx_isolation allowed in MySQL 5.7' => sub {
    plan tests => 2;

    %main::myvar = (
        'version'      => '5.7.44',
        'tx_isolation' => 'REPEATABLE-READ'
    );
    @main::generalrec = ();
    @main::sysrec     = ();
    %main::result     = ();

    main::audit_deprecated_variables();

    is(scalar(@main::generalrec), 0, "No deprecation flagged for tx_isolation on MySQL 5.7");
    ok(!exists $main::result{'Deprecated_Variables'}, "Deprecated_Variables hash key not populated");
};

# --- Subtest 4: Query Cache Removal on MySQL 8.0+ ---
subtest 'Query Cache Removed on MySQL 8.0+' => sub {
    plan tests => 3;

    %main::myvar = (
        'version'          => '8.0.36',
        'query_cache_size' => '16777216',
        'query_cache_type' => 'ON'
    );
    @main::generalrec = ();
    @main::sysrec     = ();
    %main::result     = ();

    main::audit_deprecated_variables();

    is(scalar(@main::generalrec), 1, "1 recommendation generated for removed query cache");
    ok(grep(/Query Cache subsystem was completely removed in MySQL 8.0/, @main::sysrec), "Found query cache removal warning");
    is($main::result{'Deprecated_Variables'}->[0]{variable}, 'query_cache_size', "Query cache size flagged");
};

# --- Subtest 5: default_authentication_plugin on MySQL 8.4+ ---
subtest 'default_authentication_plugin on MySQL 8.4+ LTS' => sub {
    plan tests => 3;

    %main::myvar = (
        'version'                       => '8.4.0',
        'default_authentication_plugin' => 'caching_sha2_password'
    );
    @main::generalrec = ();
    @main::sysrec     = ();
    %main::result     = ();

    main::audit_deprecated_variables();

    is(scalar(@main::generalrec), 1, "1 recommendation generated for default_authentication_plugin in 8.4");
    ok(grep(/replace default_authentication_plugin with authentication_policy/, @main::generalrec), "Found authentication_policy recommendation");
    is($main::result{'Deprecated_Variables'}->[0]{variable}, 'default_authentication_plugin', "Flagged default_authentication_plugin");
};

done_testing();
