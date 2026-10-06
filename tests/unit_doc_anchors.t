#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_doc_anchors.t
# Description: Validates Dynamic Documentation Anchors & KB References (Phase 18.2).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

# Plan: 4 structured subtests
plan tests => 4;

my $script = File::Spec->catfile( $FindBin::Bin, '..', 'mysqltuner.pl' );
require $script;

# --- Subtest 1: Standard Topic Anchors ---
subtest 'Standard Reference Anchor Mapping' => sub {
    plan tests => 8;

    is( main::get_doc_anchor('buffer_pool'),        '[REF: INNODB-BUFFER-POOL]', "buffer_pool anchor" );
    is( main::get_doc_anchor('innodb_buffer_pool'), '[REF: INNODB-BUFFER-POOL]', "innodb_buffer_pool anchor" );
    is( main::get_doc_anchor('query_cache'),        '[REF: QUERY-CACHE]',        "query_cache anchor" );
    is( main::get_doc_anchor('replication_lag'),    '[REF: REPLICATION-LAG]',    "replication_lag anchor" );
    is( main::get_doc_anchor('table_cache'),        '[REF: TABLE-CACHE]',        "table_cache anchor" );
    is( main::get_doc_anchor('connection_limits'),  '[REF: CONNECTION-LIMITS]',  "connection_limits anchor" );
    is( main::get_doc_anchor('security_auth'),      '[REF: SECURITY-AUTH]',      "security_auth anchor" );
    is( main::get_doc_anchor('galera_cluster'),     '[REF: GALERA-CLUSTER]',     "galera_cluster anchor" );
};

# --- Subtest 2: Fallback & Normalization Behavior ---
subtest 'Fallback and Case/Punctuation Normalization' => sub {
    plan tests => 4;

    is( main::get_doc_anchor('BUFFER_POOL'),       '[REF: INNODB-BUFFER-POOL]', "Uppercase topic normalized" );
    is( main::get_doc_anchor('InnoDB-Buffer-Pool'),'[REF: INNODB-BUFFER-POOL]', "Hyphenated topic normalized" );
    is( main::get_doc_anchor('non_existent_topic'),'[REF: MYSQLTUNER-DOCS]',    "Unknown topic falls back to default" );
    is( main::get_doc_anchor(undef),               '[REF: MYSQLTUNER-DOCS]',    "Undef topic falls back to default" );
};

# --- Subtest 3: Knowledge Base URL Resolution ---
subtest 'Knowledge Base URL Resolution' => sub {
    plan tests => 6;

    like( main::get_doc_url('buffer_pool'),      qr/innodb-buffer-pool\.html/, "Buffer pool URL" );
    like( main::get_doc_url('query_cache'),      qr/mariadb\.com\/kb\/en\/query-cache/, "Query cache KB URL" );
    like( main::get_doc_url('replication_lag'),  qr/replication\.html/, "Replication lag URL" );
    like( main::get_doc_url('security_auth'),    qr/pluggable-authentication\.html/, "Security auth URL" );
    like( main::get_doc_url('unknown_topic'),    qr/github\.com\/jmrenouard\/MySQLTuner-perl/, "Fallback to project repo" );
    like( main::get_doc_url(undef),              qr/github\.com\/jmrenouard\/MySQLTuner-perl/, "Undef fallback" );
};

# --- Subtest 4: CLI Compilation & Help Screen Verification ---
subtest 'CLI Compilation & Help Screen' => sub {
    plan tests => 2;

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "mysqltuner.pl compiles cleanly" );

    my $help_out = `perl "$script" --help 2>&1`;
    like( $help_out, qr/MySQLTuner/, "--help executes without crash" );
};

done_testing();
