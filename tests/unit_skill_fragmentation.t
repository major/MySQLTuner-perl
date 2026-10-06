#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_skill_fragmentation.t
# Description: Validates the AI Skill 'detect_fragmented_tables' MCP tool,
#              evaluating storage waste, reclaimable bytes, and defrag recommendations.
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use IPC::Open2;
use File::Path qw(make_path remove_tree);

my $test_cache_dir = "$FindBin::Bin/mcp_frag_cache_$$";

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

# --- Subtest 1: Schema Introspection for detect_fragmented_tables ---
subtest 'Skill Introspection: detect_fragmented_tables in Tools Catalog' => sub {
    plan tests => 4;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/list", "id": "frag-schema-1"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received tools/list response");
    like($resp, qr/"name"\s*:\s*"detect_fragmented_tables"/, "Tools list includes detect_fragmented_tables");
    like($resp, qr/"min_fragmentation_pct"/, "inputSchema includes min_fragmentation_pct");
    like($resp, qr/"min_table_size_mb"/, "inputSchema includes min_table_size_mb");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 2: Execution with Default Parameters ---
subtest 'Skill Execution: detect_fragmented_tables Default Parameters' => sub {
    plan tests => 5;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "detect_fragmented_tables", "arguments": {}}, "id": "frag-exec-1"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received detect_fragmented_tables response");
    like($resp, qr/"jsonrpc"\s*:\s*"2\.0"/, "Valid JSON-RPC 2.0 response");
    like($resp, qr/status/, "Response includes status key");
    like($resp, qr/(OPTIMAL|FRAGMENTATION_DETECTED)/, "Status matches known fragmentation states");
    like($resp, qr/total_reclaimable_bytes/, "Metrics include total_reclaimable_bytes");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 3: Custom Parameters & Schema Filter ---
subtest 'Skill Execution: Custom Size, Threshold and Schema Filter' => sub {
    plan tests => 4;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "detect_fragmented_tables", "arguments": {"min_fragmentation_pct": 15, "min_table_size_mb": 5, "schema_filter": "ecommerce_prod"}}, "id": "frag-exec-2"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received custom parameters response");
    like($resp, qr/fragmented_tables/, "Response includes fragmented_tables array");
    like($resp, qr/evaluated_min_size_mb/, "Metrics include evaluated_min_size_mb");
    like($resp, qr/evaluated_min_fragmentation_pct/, "Metrics include evaluated_min_fragmentation_pct");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 4: Robustness against Malformed Arguments ---
subtest 'Skill Robustness: Malformed Arguments' => sub {
    plan tests => 3;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "detect_fragmented_tables", "arguments": null}, "id": "frag-exec-3"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Handled null arguments gracefully");
    like($resp, qr/status/, "Default evaluation performed");
    unlike($resp, qr/-32603/, "No unhandled internal error thrown");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

done_testing();
