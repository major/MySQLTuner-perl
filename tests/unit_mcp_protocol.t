#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_mcp_protocol.t
# Description: Validates MCP Server JSON-RPC 2.0 protocol compliance,
#              standard error codes, SQL safety guardrails, and SSE endpoints.
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use IPC::Open2;
use File::Path qw(make_path remove_tree);

my $has_python = system("which python3 >/dev/null 2>&1") == 0;
if (!$has_python) {
    plan skip_all => "python3 is required to run MCP protocol unit tests";
}

plan tests => 6;

my $test_cache_dir = "$FindBin::Bin/mcp_test_cache_$$";
remove_tree($test_cache_dir) if -d $test_cache_dir;
make_path($test_cache_dir);

$ENV{'CACHE_DIR'} = $test_cache_dir;
$ENV{'READ_ONLY'} = 'false';

my $mcp_server_path = "$FindBin::Bin/../build/mcp_server.py";

# --- Subtest 1: Initialize & Capabilities ---
subtest 'MCP Protocol: Initialize & Capabilities' => sub {
    plan tests => 6;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    # Send initialize request
    print $chld_in '{"jsonrpc": "2.0", "method": "initialize", "id": "init-01"}' . "\n";
    my $resp_line = <$chld_out>;
    ok($resp_line, "Received initialize response");
    like($resp_line, qr/"jsonrpc"\s*:\s*"2\.0"/, "JSON-RPC 2.0 version returned");
    like($resp_line, qr/"protocolVersion"\s*:\s*"2024-11-05"/, "MCP protocol version 2024-11-05");
    like($resp_line, qr/"name"\s*:\s*"mysqltuner-mcp"/, "Server name returned");
    like($resp_line, qr/"tools"/, "Capabilities include tools");
    like($resp_line, qr/"resources"/, "Capabilities include resources");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 2: Standard JSON-RPC Error Handling ---
subtest 'MCP Protocol: Standard JSON-RPC 2.0 Error Codes' => sub {
    plan tests => 5;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    # 1. Parse error (-32700)
    print $chld_in '{malformed_json_without_quotes' . "\n";
    my $err1 = <$chld_out>;
    like($err1, qr/-32700/, "Code -32700 (Parse error) returned for invalid JSON");

    # 2. Invalid Request (-32600): missing method
    print $chld_in '{"jsonrpc": "2.0", "id": "test-inv"}' . "\n";
    my $err2 = <$chld_out>;
    like($err2, qr/-32600/, "Code -32600 (Invalid Request) returned for missing method");

    # 3. Method not found (-32601)
    print $chld_in '{"jsonrpc": "2.0", "method": "non_existent_method", "id": "test-nm"}' . "\n";
    my $err3 = <$chld_out>;
    like($err3, qr/-32601/, "Code -32601 (Method not found) returned for invalid method");

    # 4. Invalid params (-32602)
    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": "not_an_object", "id": "test-ip"}' . "\n";
    my $err4 = <$chld_out>;
    like($err4, qr/-32602/, "Code -32602 (Invalid params) returned for string params");

    # 5. Unknown tool in tools/call returns isError: true
    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "ghost_tool"}, "id": "test-gt"}' . "\n";
    my $err5 = <$chld_out>;
    like($err5, qr/"isError"\s*:\s*true/, "Unknown tool returns isError: true in result");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 3: SQL Safety Guardrails & Injection Prevention ---
subtest 'MCP Safety Guardrails: SQL Sanitization' => sub {
    plan tests => 5;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    # 1. Multi-statement injection attempt
    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "apply_recommendation", "arguments": {"statement": "SET GLOBAL max_connections = 200; DROP DATABASE production;"}}, "id": "sec-1"}' . "\n";
    my $sec1 = <$chld_out>;
    like($sec1, qr/"isError"\s*:\s*true/, "Multi-statement injection rejected");
    like($sec1, qr/Multiple SQL statements/i, "Reason mentions multiple statements rejected");

    # 2. Block-comment evasion attempt with DROP
    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "apply_recommendation", "arguments": {"statement": "/* safe comment */ DROP TABLE users"}}, "id": "sec-2"}' . "\n";
    my $sec2 = <$chld_out>;
    like($sec2, qr/"isError"\s*:\s*true/, "Comment-wrapped DROP command rejected");

    # 3. Disallowed statement (DELETE)
    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "apply_recommendation", "arguments": {"statement": "DELETE FROM mysql.user WHERE user = \'root\'"}}, "id": "sec-3"}' . "\n";
    my $sec3 = <$chld_out>;
    like($sec3, qr/"isError"\s*:\s*true/, "DELETE statement rejected");

    # 4. Disallowed statement (GRANT ALL)
    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "apply_recommendation", "arguments": {"statement": "GRANT ALL PRIVILEGES ON *.* TO \'attacker\'@\'%\'"}}, "id": "sec-4"}' . "\n";
    my $sec4 = <$chld_out>;
    like($sec4, qr/"isError"\s*:\s*true/, "Privilege escalation GRANT rejected");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 4: Tools & Schema Introspection ---
subtest 'MCP Protocol: Tools & JSON Schema Introspection' => sub {
    plan tests => 4;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/list", "id": "tool-list-1"}' . "\n";
    my $resp = <$chld_out>;

    like($resp, qr/"inputSchema"/, "All tools provide inputSchema");
    like($resp, qr/"get_latest_audit"/, "get_latest_audit is present");
    like($resp, qr/"run_audit"/, "run_audit is present");
    like($resp, qr/"apply_recommendation"/, "apply_recommendation is present");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 5: Resources List & Read ---
subtest 'MCP Protocol: Resources Management' => sub {
    plan tests => 3;

    # Write dummy cache file
    my $sample_json = '{"status": "ok", "version": "2.9.2"}';
    open my $fh, ">", "$test_cache_dir/latest.json" or die $!;
    print $fh $sample_json;
    close $fh;

    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    # List resources
    print $chld_in '{"jsonrpc": "2.0", "method": "resources/list", "id": "res-1"}' . "\n";
    my $list_resp = <$chld_out>;
    like($list_resp, qr/mysqltuner:\/\/reports\/latest\.json/, "Resource URI listed");

    # Read resource
    print $chld_in '{"jsonrpc": "2.0", "method": "resources/read", "params": {"uri": "mysqltuner://reports/latest.json"}, "id": "res-2"}' . "\n";
    my $read_resp = <$chld_out>;
    like($read_resp, qr/latest\.json/, "Resource read returned expected URI");
    like($read_resp, qr/application\/json/, "MimeType application/json returned");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 6: SSE HTTP Transport Integration ---
subtest 'MCP Server: SSE HTTP Server Mode' => sub {
    plan tests => 3;

    my $test_port = 18000 + int(rand(1000));
    my $server_cmd = "python3 $mcp_server_path --sse --port $test_port --host 127.0.0.1";
    my $pid = fork();
    if ($pid == 0) {
        # Child process
        exec($server_cmd);
        exit(0);
    }

    # Wait for server to bind
    sleep(1);

    # 1. Health check GET
    my $health_resp = `curl -s http://127.0.0.1:$test_port/health`;
    like($health_resp, qr/"status":\s*"healthy"/, "SSE HTTP /health endpoint returns healthy");

    # 2. JSON-RPC POST to /message
    my $post_payload = '{"jsonrpc": "2.0", "method": "tools/list", "id": "http-1"}';
    my $post_resp = `curl -s -X POST -H "Content-Type: application/json" -d '$post_payload' http://127.0.0.1:$test_port/message`;
    like($post_resp, qr/"tools"/, "SSE HTTP /message POST returns JSON-RPC tools list");

    # 3. GET /sse event-stream header verification
    my $sse_headers = `curl -s -m 2 -I http://127.0.0.1:$test_port/sse | tr -d '\r'`;
    like($sse_headers, qr/Content-Type:\s*text\/event-stream/i, "GET /sse returns text/event-stream content type");

    # Kill SSE server process
    kill('TERM', $pid);
    waitpid($pid, 0);
};

# Cleanup
END {
    remove_tree($test_cache_dir) if -d $test_cache_dir;
}

done_testing();
