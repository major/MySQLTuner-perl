#!/usr/bin/env perl
# ===========================================================================
# Test:        e2e_mcp_server.t
# Description: E2E test for the MCP server against a real MariaDB container.
#              Validates JSON-RPC protocol with live database interaction.
# Dependencies: Docker, Python3
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use IPC::Open2;
use File::Path qw(make_path remove_tree);

# --- Pre-flight checks ---
my $has_docker = system("docker info >/dev/null 2>&1") == 0;
my $has_python = system("which python3 >/dev/null 2>&1") == 0;

unless ($has_docker && $has_python) {
    plan skip_all => "Docker and Python3 are required for MCP E2E tests"
        . ($has_docker ? "" : " (Docker unavailable)")
        . ($has_python ? "" : " (Python3 unavailable)");
}

plan tests => 2;

my $DB_PASS      = "mcp_test_pass";
my $DB_PORT      = 13306;  # Non-standard port to avoid conflicts
my $CONTAINER    = "mysqltuner_mcp_e2e_$$";
my $MCP_SCRIPT   = "$FindBin::Bin/../build/mcp_server.py";
my $MT_SCRIPT    = "$FindBin::Bin/../mysqltuner.pl";
my $CACHE_DIR    = "$FindBin::Bin/mcp_e2e_cache_$$";

# --- Helper: cleanup ---
sub cleanup {
    system("docker rm -f $CONTAINER >/dev/null 2>&1");
    remove_tree($CACHE_DIR) if -d $CACHE_DIR;
}

# Ensure cleanup on exit
END { cleanup(); }

# --- Start MariaDB container ---
subtest 'MCP E2E: Database Container Lifecycle' => sub {
    plan tests => 3;

    # Start container
    my $docker_cmd = "docker run -d --name $CONTAINER "
        . "-e MARIADB_ROOT_PASSWORD=$DB_PASS "
        . "-p $DB_PORT:3306 "
        . "mariadb:11.4";
    my $cid = `$docker_cmd 2>&1`;
    chomp $cid;
    ok(length($cid) > 10, "MariaDB container started: " . substr($cid, 0, 12));

    # Wait for readiness (max 60s)
    my $ready = 0;
    for my $i (1..30) {
        my $ping = system("docker exec $CONTAINER mariadb -uroot -p$DB_PASS -e 'SELECT 1' >/dev/null 2>&1");
        if ($ping == 0) {
            $ready = 1;
            last;
        }
        sleep 2;
    }
    ok($ready, "MariaDB is accepting connections");

    # Verify version
    my $version = `docker exec $CONTAINER mariadb -uroot -p$DB_PASS -sNe "SELECT VERSION();" 2>/dev/null`;
    chomp $version;
    like($version, qr/11\.4/, "MariaDB version is 11.4.x: $version");
};

# --- MCP Server JSON-RPC E2E ---
subtest 'MCP E2E: JSON-RPC Tools with Live Database' => sub {
    plan tests => 8;

    make_path($CACHE_DIR);

    # Set environment for MCP server
    local $ENV{'DB_HOST'}       = '127.0.0.1';
    local $ENV{'DB_PORT'}       = $DB_PORT;
    local $ENV{'DB_USER'}       = 'root';
    local $ENV{'DB_PASSWORD'}   = $DB_PASS;
    local $ENV{'CACHE_DIR'}     = $CACHE_DIR;
    local $ENV{'MYSQLTUNER_PL'} = $MT_SCRIPT;
    local $ENV{'READ_ONLY'}     = 'true';

    my ($chld_out, $chld_in);
    my $pid = eval {
        open2($chld_out, $chld_in, "python3", $MCP_SCRIPT);
    };
    unless ($pid) {
        fail("Failed to spawn mcp_server.py: $@");
        return;
    }

    # Enable autoflush
    my $old_fh = select($chld_in);
    $| = 1;
    select($old_fh);

    # Helper to send JSON-RPC and get response
    my $send_rpc = sub {
        my ($method, $id, $params) = @_;
        my $req = "{\"jsonrpc\": \"2.0\", \"method\": \"$method\", \"id\": \"$id\"";
        $req .= ", \"params\": $params" if $params;
        $req .= "}\n";
        print $chld_in $req;
        my $resp = <$chld_out>;
        return $resp || '';
    };

    # 1. Initialize
    my $init_resp = $send_rpc->('initialize', 'e2e-1');
    like($init_resp, qr/"jsonrpc"\s*:\s*"2.0"/, 'Initialize: valid JSON-RPC 2.0');
    like($init_resp, qr/"name"\s*:\s*"mysqltuner-mcp"/, 'Initialize: server name correct');

    # 2. List tools
    my $tools_resp = $send_rpc->('tools/list', 'e2e-2');
    like($tools_resp, qr/run_audit/, 'Tools list: contains run_audit');
    like($tools_resp, qr/get_latest_audit/, 'Tools list: contains get_latest_audit');

    # 3. Get latest audit (should be empty initially)
    my $get_resp = $send_rpc->('tools/call', 'e2e-3',
        '{"name": "get_latest_audit", "arguments": {}}');
    like($get_resp, qr/No cached audit|content/, 'Get latest audit: returns expected response');

    # 4. Run audit (live database)
    # This may take 10-30s for MySQLTuner to run
    diag("Running live audit (this may take 30s)...");
    local $SIG{ALRM} = sub { fail("Audit timed out after 120s"); };
    alarm(120);
    my $audit_resp = $send_rpc->('tools/call', 'e2e-4',
        '{"name": "run_audit", "arguments": {}}');
    alarm(0);

    # Audit should return content (not an error)
    ok(length($audit_resp) > 100, 'Run audit: received substantial response (' . length($audit_resp) . ' bytes)');

    # 5. Apply recommendation (should be rejected in read-only mode)
    my $apply_resp = $send_rpc->('tools/call', 'e2e-5',
        '{"name": "apply_recommendation", "arguments": {"statement": "SET GLOBAL slow_query_log = ON"}}');
    like($apply_resp, qr/read-only|isError/i, 'Apply recommendation: rejected in read-only mode');

    # 6. List resources
    my $res_resp = $send_rpc->('resources/list', 'e2e-6');
    like($res_resp, qr/mysqltuner:\/\/reports\/latest\.json/, 'Resources list: contains latest report');

    # Cleanup
    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

done_testing();
