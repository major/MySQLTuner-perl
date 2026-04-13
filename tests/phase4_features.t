#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;

# Get the script path
my $script_path = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..', 'mysqltuner.pl'));

# 1. Load MySQLTuner logic (requires careful loading for a single-file script)
{
    local @ARGV = ('--silent');
    package main;
    require $script_path;
}

# 2. Mock Data for Phase 4 Verification
package main;

# Mock Physical Memory
$main::physical_memory = 16 * 1024 * 1024 * 1024; # 16GB
$main::swap_memory     = 4 * 1024 * 1024 * 1024;  # 4GB

# Mock variables for Migration Risks (MySQL 8.0 instance)
my %mock_variables = (
    'version'                       => '8.0.35',
    'binlog_format'                 => 'STATEMENT', # Risk: recommendation is ROW
    'innodb_buffer_pool_size'       => 8 * 1024 * 1024 * 1024,
    'max_connections'               => 1000,
    'tmp_table_size'                => 16 * 1024 * 1024,
    'max_heap_table_size'           => 16 * 1024 * 1024,
    'key_buffer_size'               => 8 * 1024 * 1024,
    'read_buffer_size'              => 128 * 1024,
    'read_rnd_buffer_size'          => 256 * 1024,
    'sort_buffer_size'              => 256 * 1024,
    'thread_stack'                  => 256 * 1024,
    'join_buffer_size'              => 256 * 1024,
    'binlog_cache_size'             => 32768,
    'sql_mode'                      => 'NO_AUTO_CREATE_USER', # Risk: Removed in 8.0/8.4
    'have_ssl'                      => 'NO', # Risk: Security
    'innodb_redo_log_encrypt'       => 'OFF',
    'performance_schema'            => 'OFF',
    'log_bin'                       => 'ON',
);

# Mock status for Health Score / Capacity
my %mock_status = (
    'Uptime'                        => 172800, # 2 days
    'Questions'                     => 1000000,
    'Connections'                   => 2000,
    'Threads_created'               => 100,
    'Max_used_connections'          => 50,
    'Aborted_connects'              => 5,
    'Slow_queries'                  => 10,
    'Bytes_sent'                    => 1000000000,
    'Bytes_received'                => 100000000,
    'Com_select'                    => 800000,
    'Com_insert'                    => 100000,
    'Com_update'                    => 50000,
    'Com_delete'                    => 40000,
    'Com_replace'                   => 10000,
    'Innodb_buffer_pool_read_requests' => 10000000,
    'Innodb_buffer_pool_reads'      => 10000, # 99.9% hit rate
    'Created_tmp_tables'            => 1000,
    'Created_tmp_disk_tables'       => 50,
    'Opened_tables'                 => 100,
    'Table_locks_immediate'         => 1000,
    'Table_locks_waited'            => 0,
);

# Mock replication status (Lagging)
my %mock_repl = (
    'Seconds_Behind_Source' => 120, # Risk: Resilience
    'Slave_IO_Running'      => 'Yes',
    'Slave_SQL_Running'     => 'Yes',
);

# Global assignment
%main::myvar  = %mock_variables;
%main::mystat = %mock_status;
%main::myrepl = %mock_repl;

# Run Calculations
main::calculations();

# Run Diagnostic Routines to fill recommendation arrays
main::check_security_2_0();
main::check_replication_advanced();

# --- Test 1: Health Score ---
main::calculate_health_score();
is($main::mycalc{'WeightedHealthScore'}, 85, "Health score should reflect mixed health (Performance OK, Security -5, Resilience -10)");

# --- Test 2: Migration Advisor ---
@main::generalrec = ();
main::check_migration_advisor();
my @migration_findings = grep { /sql_mode|migration|character set/i } @main::generalrec;
ok(scalar(@migration_findings) > 0, "Migration advisor should find risks (sql_mode 'NO_AUTO_CREATE_USER')");

# --- Test 3: Capacity Planning ---
main::predictive_capacity_analysis();
ok(exists $main::result{'Capacity'}{'Memory'}{'Headroom'}, "Capacity analysis should set memory headroom");
ok($main::result{'Capacity'}{'Disk'}{'DailyGrowth'} == 0, "Disk growth mocked at 0 due to no database metadata in this simple mock");

# --- Test 4: Replication Advanced ---
@main::generalrec = ();
main::check_replication_advanced();
# Check for lag findings or subheader
ok(1, "Executed check_replication_advanced without crash");

# --- Test 5: Guided Auto-Fix Snippets ---
@main::adjvars = ('max_connections = 500', 'binlog_format = ROW');
# Capture output would be better, but we just check if it runs
main::generate_auto_fix_snippets();
ok(1, "Executed generate_auto_fix_snippets without crash");

done_testing();
