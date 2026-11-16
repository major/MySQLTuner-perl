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

my $test_cache_dir = "$FindBin::Bin/mcp_skill_cache_$$";

# Cleanup
END {
    local $?;
    remove_tree($test_cache_dir) if defined $test_cache_dir && -d $test_cache_dir;
}

my $has_python = system("which python3 >/dev/null 2>&1") == 0;
if (!$has_python) {
    plan skip_all => "python3 is required to run skill unit tests";
}

plan tests => 5;

remove_tree($test_cache_dir) if -d $test_cache_dir;
make_path($test_cache_dir);

my $mock_bin = "$test_cache_dir/bin";
my $fail_bin = "$test_cache_dir/fail_bin";
make_path($mock_bin, $fail_bin);

{
    open my $mfh, '>', "$mock_bin/mysql" or die "Cannot write mock mysql: $!";
    print $mfh <<'SH';
#!/usr/bin/env bash
query=""
while [ $# -gt 0 ]; do
    case "$1" in
        -Bse) query="$2"; shift 2 ;;
        *) shift ;;
    esac
done
if printf '%s' "$query" | grep -q "SHOW GLOBAL STATUS"; then
    printf "Innodb_buffer_pool_read_requests\t1000000\n"
    printf "Innodb_buffer_pool_reads\t500\n"
    printf "Innodb_buffer_pool_pages_total\t8192\n"
    printf "Innodb_buffer_pool_pages_data\t7500\n"
    printf "Innodb_buffer_pool_pages_free\t692\n"
    printf "Innodb_buffer_pool_pages_dirty\t120\n"
    printf "Innodb_page_size\t16384\n"
elif printf '%s' "$query" | grep -q "SHOW GLOBAL VARIABLES"; then
    printf "innodb_buffer_pool_size\t134217728\n"
    printf "innodb_buffer_pool_instances\t1\n"
elif printf '%s' "$query" | grep -q "information_schema.TABLES"; then
    printf "67108864\n"
fi
exit 0
SH
    close $mfh;
    chmod 0755, "$mock_bin/mysql";

    open my $ffh, '>', "$fail_bin/mysql" or die "Cannot write failing mock mysql: $!";
    print $ffh <<'SH';
#!/usr/bin/env bash
echo "ERROR 2002 (HY000): Can't connect to local MySQL server" >&2
exit 1
SH
    close $ffh;
    chmod 0755, "$fail_bin/mysql";
}

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

    local $ENV{'PATH'} = "$mock_bin:$ENV{'PATH'}";
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
    plan tests => 5;

    local $ENV{'PATH'} = "$mock_bin:$ENV{'PATH'}";
    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "analyze_buffer_pool", "arguments": {"target_ram_percentage": 80, "include_dirty_pages": false}}, "id": "bp-exec-2"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received custom parameter response");
    like($resp, qr/(OPTIMAL|UNDERSIZED|OVERSIZED|DIRTY_STALL)/, "Valid status classification returned");
    like($resp, qr/metrics/, "Metrics structure present");
    like($resp, qr/target_ram_percentage.*80/, "Metrics reflect requested target_ram_percentage");
    like($resp, qr/recommendations/, "Recommendations array present");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 4: Robustness against Malformed Arguments ---
subtest 'Skill Robustness: Malformed Arguments' => sub {
    plan tests => 3;

    local $ENV{'PATH'} = "$mock_bin:$ENV{'PATH'}";
    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    # Passing null or empty arguments object
    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "analyze_buffer_pool", "arguments": null}, "id": "bp-exec-3"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Handled null arguments gracefully");
    like($resp, qr/hit_ratio_pct/, "Parsed metrics computed cleanly on null arguments");
    unlike($resp, qr/-32603/, "No unhandled internal error thrown");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

# --- Subtest 5: Fail-Closed Error Handling on DB Failure ---
subtest 'Skill Fail-Closed: Returns isError on Database Query Failure' => sub {
    plan tests => 4;

    local $ENV{'PATH'} = "$fail_bin:$ENV{'PATH'}";
    my ($chld_out, $chld_in);
    my $pid = open2($chld_out, $chld_in, "python3", $mcp_server_path);
    my $old_fh = select($chld_in); $| = 1; select($old_fh);

    print $chld_in '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "analyze_buffer_pool", "arguments": {}}, "id": "bp-exec-err"}' . "\n";
    my $resp = <$chld_out>;
    ok($resp, "Received error response on DB failure");
    like($resp, qr/"isError"\s*:\s*true/, "Returns isError: true when DB query fails");
    like($resp, qr/Can't connect/, "Propagates DB error message");
    unlike($resp, qr/OPTIMAL/, "Does not fabricate OPTIMAL fallback metrics on DB failure");

    close $chld_in;
    close $chld_out;
    waitpid($pid, 0);
};

done_testing();
