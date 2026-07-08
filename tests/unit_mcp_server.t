#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use IPC::Open2;
use File::Path qw(make_path remove_tree);

# Ensure python3 is available
my $has_python = system("which python3 >/dev/null 2>&1") == 0;
if (!$has_python) {
    plan skip_all => "python3 is required to run MCP server tests";
}

subtest 'MCP Server JSON-RPC Protocol Compliance' => sub {
    # Set cache directory inside the workspace/tests directory to avoid permission issues
    my $test_cache_dir = "$FindBin::Bin/mcp_cache";
    remove_tree($test_cache_dir) if -d $test_cache_dir;
    make_path($test_cache_dir);
    
    local $ENV{'CACHE_DIR'} = $test_cache_dir;

    my ($chld_out, $chld_in);
    my $pid = eval {
        open2($chld_out, $chld_in, "python3", "$FindBin::Bin/../build/mcp_server.py");
    };
    if (!$pid) {
        fail("Failed to spawn mcp_server.py: $@");
        remove_tree($test_cache_dir);
        return;
    }
    
    # Enable autoflush
    my $old_fh = select($chld_in);
    $| = 1;
    select($old_fh);

    # 1. Initialize call
    my $init_req = '{"jsonrpc": "2.0", "method": "initialize", "id": "req-1"}' . "\n";
    print $chld_in $init_req;
    my $init_resp = <$chld_out>;
    like($init_resp, qr/"jsonrpc"\s*:\s*"2.0"/, 'Initialize returns JSON-RPC 2.0');
    like($init_resp, qr/"name"\s*:\s*"mysqltuner-mcp"/, 'Initialize returns server name');
    like($init_resp, qr/"id"\s*:\s*"req-1"/, 'Initialize retains transaction ID');

    # 2. List tools call
    my $tools_req = '{"jsonrpc": "2.0", "method": "tools/list", "id": "req-2"}' . "\n";
    print $chld_in $tools_req;
    my $tools_resp = <$chld_out>;
    like($tools_resp, qr/get_latest_audit/, 'Lists get_latest_audit tool');
    like($tools_resp, qr/run_audit/, 'Lists run_audit tool');
    like($tools_resp, qr/apply_recommendation/, 'Lists apply_recommendation tool');
    like($tools_resp, qr/rollback_recommendation/, 'Lists rollback_recommendation tool');

    # 3. List resources call
    my $res_req = '{"jsonrpc": "2.0", "method": "resources/list", "id": "req-3"}' . "\n";
    print $chld_in $res_req;
    my $res_resp = <$chld_out>;
    like($res_resp, qr/mysqltuner:\/\/reports\/latest.json/, 'Lists report resources');

    # Clean up subprocess
    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
    remove_tree($test_cache_dir);
    pass('Subprocess terminated cleanly');
};

done_testing();
