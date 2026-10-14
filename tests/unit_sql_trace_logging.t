#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_sql_trace_logging.t
# Description: Validates SQL Error Trace Logging & Query Safety (Phase 23.3).
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

# --- Subtest 1: Trace Buffering & Query Logging ---
subtest 'Trace Buffering & Recording' => sub {
    plan tests => 5;

    main::clear_sql_traces();
    my @initial = main::get_sql_traces();
    is( scalar(@initial), 0, "Trace buffer starts empty" );

    main::log_sql_trace( 'SELECT * FROM mysql.user', 'Access denied for user guest@localhost', 'ER_ACCESS_DENIED' );
    my @traces = main::get_sql_traces();
    is( scalar(@traces), 1, "Recorded 1 SQL trace" );
    is( $traces[0]->{query}, 'SELECT * FROM mysql.user', "Query text captured" );
    is( $traces[0]->{error}, 'Access denied for user guest@localhost', "Error message captured" );
    is( $traces[0]->{status_code}, 'ER_ACCESS_DENIED', "Status code captured" );
};

# --- Subtest 2: Multiple Traces and Default Values ---
subtest 'Multiple Traces & Default Parameters' => sub {
    plan tests => 4;

    main::clear_sql_traces();
    main::log_sql_trace('SHOW ENGINE INNODB STATUS');
    main::log_sql_trace('SELECT count(*) FROM performance_schema.events_statements_summary_by_digest', 'Table does not exist', 'ER_NO_SUCH_TABLE');

    my @traces = main::get_sql_traces();
    is( scalar(@traces), 2, "Recorded 2 traces" );
    is( $traces[0]->{status_code}, "ERROR", "Default status code is ERROR" );
    is( $traces[0]->{error}, "Unknown SQL error", "Default error message" );
    is( $traces[1]->{status_code}, "ER_NO_SUCH_TABLE", "Custom status code preserved" );
};

# --- Subtest 3: Buffer Clear & Report Formatting ---
subtest 'Trace Formatting & Buffer Clear' => sub {
    plan tests => 3;

    main::clear_sql_traces();
    my $empty_report = main::format_sql_trace_report();
    like( $empty_report, qr/No SQL errors or execution anomalies recorded/, "Empty report message" );

    main::log_sql_trace('SELECT @@global.tx_isolation', 'Unknown system variable', 'ER_UNKNOWN_SYSTEM_VARIABLE');
    my $report = main::format_sql_trace_report();
    like( $report, qr/Recorded 1 SQL execution anomalies/, "Report shows anomaly count" );
    like( $report, qr/ER_UNKNOWN_SYSTEM_VARIABLE/, "Report includes status code" );
};

# --- Subtest 4: Syntax & Perl Cleanliness ---
subtest 'mysqltuner.pl Compilation' => sub {
    plan tests => 1;

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "mysqltuner.pl compiles cleanly" );
};

done_testing();
