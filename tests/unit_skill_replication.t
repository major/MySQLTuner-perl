#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_skill_replication.t
# Description: Validates the AI Skill 'diagnose_replication_lag' MCP tool,
#              evaluating replication latency detection, thread state, and errors.
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use IPC::Open2;
use File::Path qw(make_path remove_tree);

my $test_cache_dir = "$FindBin::Bin/mcp_repl_cache_$$";

# Cleanup
END {
    local $?;
    remove_tree($test_cache_dir) if defined $test_cache_dir && -d $test_cache_dir;
}

my $has_python = system("which python3 >/dev/null 2>&1") == 0;
if (!$has_python) {
    plan skip_all => "python3 is required to run skill unit tests";
}

plan tests => 4;

remove_tree($test_cache_dir) if -d $test_cache_dir;
make_path($test_cache_dir);

$ENV{'CACHE_DIR'} = $test_cache_dir;
$ENV{'READ_ONLY'} = 'false';

my $mcp_server_path = "$FindBin::Bin/../build/mcp_server.py";

# --- Subtest 1: Schema Introspection for diagnose_replication_lag ---
subtest 'Skill Introspection: diagnose_replication_lag in Tools Catalog' => sub {
    plan tests => 4;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/list", "id": "rep-schema-1"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received tools/list response");
    like($resp, qr/"name"\s*:\s*"diagnose_replication_lag"/, "Tools list includes diagnose_replication_lag");
    like($resp, qr/"max_acceptable_lag_seconds"/, "inputSchema includes max_acceptable_lag_seconds");
    like($resp, qr/"channel_name"/, "inputSchema includes channel_name");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 2: Execution on Standalone Instance (No Replication) ---
subtest 'Skill Execution: diagnose_replication_lag Default Parameters' => sub {
    plan tests => 5;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "diagnose_replication_lag", "arguments": {}}, "id": "rep-exec-1"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received diagnose_replication_lag response");
    like($resp, qr/"jsonrpc"\s*:\s*"2\.0"/, "Valid JSON-RPC 2.0 response");
    like($resp, qr/status/, "Response includes status key");
    like($resp, qr/(NOT_A_REPLICA|HEALTHY|DEGRADED_LAG|THREAD_FAILED)/, "Status matches known replication states");
    like($resp, qr/metrics/, "Response contains structured metrics");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 3: Custom Parameters (Lag Threshold & Channels) ---
subtest 'Skill Execution: Custom Lag Threshold and Channel' => sub {
    plan tests => 3;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "diagnose_replication_lag", "arguments": {"max_acceptable_lag_seconds": 15, "channel_name": "ch_analytics"}}, "id": "rep-exec-2"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received custom parameters response");
    like($resp, qr/recommendations/, "Response includes recommendations array");
    like($resp, qr/parallel_workers/, "Response includes parallel_workers metric");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 4: Robustness against Malformed Arguments ---
subtest 'Skill Robustness: Null & Invalid Parameters' => sub {
    plan tests => 3;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "diagnose_replication_lag", "arguments": null}, "id": "rep-exec-3"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Handled null arguments gracefully");
    like($resp, qr/status/, "Default evaluation performed");
    unlike($resp, qr/-32603/, "No unhandled internal error thrown");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

done_testing();
