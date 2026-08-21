#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_skill_buffer_pool.t
# Description: Validates the AI Skill 'analyze_buffer_pool' MCP tool,
#              evaluating calculations, metrics formatting, and recommendations.
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use IPC::Open2;
use File::Path qw(make_path remove_tree);

my $has_python = system("which python3 >/dev/null 2>&1") == 0;
if (!$has_python) {
    plan skip_all => "python3 is required to run skill unit tests";
}

plan tests => 4;

my $test_cache_dir = "$FindBin::Bin/mcp_skill_cache_$$";
remove_tree($test_cache_dir) if -d $test_cache_dir;
make_path($test_cache_dir);

$ENV{'CACHE_DIR'} = $test_cache_dir;
$ENV{'READ_ONLY'} = 'false';

my $mcp_server_path = "$FindBin::Bin/../build/mcp_server.py";

# --- Subtest 1: Schema Introspection for analyze_buffer_pool ---
subtest 'Skill Introspection: analyze_buffer_pool in Tools Catalog' => sub {
    plan tests => 4;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/list", "id": "bp-schema-1"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received tools/list response");
    like($resp, qr/"name"\s*:\s*"analyze_buffer_pool"/, "Tools list includes analyze_buffer_pool");
    like($resp, qr/"target_ram_percentage"/, "inputSchema includes target_ram_percentage");
    like($resp, qr/"include_dirty_pages"/, "inputSchema includes include_dirty_pages");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 2: Execution with Default Parameters ---
subtest 'Skill Execution: analyze_buffer_pool Default Parameters' => sub {
    plan tests => 6;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "analyze_buffer_pool", "arguments": {}}, "id": "bp-exec-1"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received analyze_buffer_pool response");
    like($resp, qr/"jsonrpc"\s*:\s*"2\.0"/, "Valid JSON-RPC 2.0 response");
    like($resp, qr/hit_ratio_pct/, "Response metrics include hit_ratio_pct");
    like($resp, qr/allocated_bytes/, "Response metrics include allocated_bytes");
    like($resp, qr/free_pages_pct/, "Response metrics include free_pages_pct");
    like($resp, qr/status/, "Response includes high-level health status");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 3: Custom Parameters & Filtering ---
subtest 'Skill Execution: Custom Parameters & Options' => sub {
    plan tests => 4;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "analyze_buffer_pool", "arguments": {"target_ram_percentage": 80, "include_dirty_pages": false}}, "id": "bp-exec-2"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received custom parameter response");
    like($resp, qr/(OPTIMAL|UNDERSIZED|OVERSIZED|DIRTY_STALL)/, "Valid status classification returned");
    like($resp, qr/metrics/, "Metrics structure present");
    like($resp, qr/recommendations/, "Recommendations array present");

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

    # Passing null or empty arguments object
    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "analyze_buffer_pool", "arguments": null}, "id": "bp-exec-3"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Handled null arguments gracefully");
    like($resp, qr/hit_ratio_pct/, "Default fallback metrics computed");
    unlike($resp, qr/-32603/, "No unhandled internal error thrown");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# Cleanup
END {
    remove_tree($test_cache_dir) if -d $test_cache_dir;
}

done_testing();
