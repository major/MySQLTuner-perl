#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;

# Get the script path
my $script_path = File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..', 'mysqltuner.pl'));

# Load MySQLTuner logic
{
    local @ARGV = ('--silent');
    package main;
    require $script_path;
}

package main;

# Write a mock JSON file for historical delta testing
my $mock_old_file = 'mock_old.json';
open(my $fh, '>', $mock_old_file) or die "Could not open $mock_old_file: $!";
print $fh q({
    "General": { "Date": "2026-06-01" },
    "Stats": {
        "QPS": 10.0,
        "Total Data Size": 83886080
    },
    "HealthScore": 80,
    "SectionalHealthScore": {
        "General": 95,
        "Storage": 70,
        "Security": 90,
        "Replication": 100,
        "Modeling": 90
    }
});
close($fh);

# Ensure cleanup on exit
END {
    if (-e 'mock_old.json') {
        unlink('mock_old.json');
    }
}

# 1. Test get_load_average with mock file2string or fallback to execute_system_command
{
    no warnings 'redefine';
    local *main::file2string = sub {
        my $path = shift;
        if ($path eq '/proc/loadavg') {
            return "1.25 0.80 0.50 2/250 12345\n";
        }
        return undef;
    };
    
    my @load = main::get_load_average();
    is_deeply(\@load, ['1.25', '0.80', '0.50'], "get_load_average should parse /proc/loadavg correctly");
}

{
    no warnings 'redefine';
    local *main::file2string = sub { return undef; };
    local *main::execute_system_command = sub {
        my $cmd = shift;
        if ($cmd eq 'uptime') {
            return " 01:25:00 up 10 days, 1:23,  1 user,  load average: 0.75, 1.10, 1.35\n";
        }
        return undef;
    };
    
    my @load = main::get_load_average();
    is_deeply(\@load, ['0.75', '1.10', '1.35'], "get_load_average should fallback to uptime command");
}

# 2. Reset and Mock Sectional Indicators & Health Scores
sub reset_state {
    @main::generalrec = ();
    @main::sysrec     = ();
    @main::secrec     = ();
    @main::modeling   = ();
    @main::adjvars    = ();
    %main::mycalc     = ();
    %main::mystat     = ();
    %main::myrepl     = ();
    %main::result     = ();
    $main::physical_memory = 16 * 1024 * 1024 * 1024; # 16 GB
    $main::swap_memory     = 2 * 1024 * 1024 * 1024;  # 2 GB
}

# 2a. Test Optimal state: All scores 100
reset_state();
$main::mystat{'Uptime'} = 100000; # > 86400
$main::mycalc{'pct_read_efficiency'} = 98.0;
$main::mycalc{'pct_temp_disk'} = 10.0;
$main::mycalc{'table_cache_hit_rate'} = 80.0;
$main::mystat{'Questions'} = 200000;
$main::mystat{'Innodb_buffer_pool_read_requests'} = 500000;

# Load mock setup for loadavg
{
    no warnings 'redefine';
    local *main::get_load_average = sub { return (0.1, 0.2, 0.3) };
    local *main::get_other_process_memory = sub { return 1024 * 1024; }; # tiny
    main::calculate_sectional_health_scores();
}

is($main::result{'SectionalHealthScore'}{'General'}, 100, "Optimal General score should be 100");
is($main::result{'SectionalHealthScore'}{'Storage'}, 100, "Optimal Storage score should be 100");
is($main::result{'SectionalHealthScore'}{'Security'}, 100, "Optimal Security score should be 100");
is($main::result{'SectionalHealthScore'}{'Replication'}, 100, "Optimal Replication score should be 100");
is($main::result{'SectionalHealthScore'}{'Modeling'}, 100, "Optimal SQL Modeling score should be 100");

# 2b. Test deductions
reset_state();
$main::mystat{'Uptime'} = 5000; # < 86400 -> -20
$main::mycalc{'pct_read_efficiency'} = 90.0; # < 95 -> -25
$main::mycalc{'pct_temp_disk'} = 30.0; # > 25 -> -25
push @main::secrec, "Vulnerable configuration."; # 1 item -> -15
push @main::modeling, "Missing primary key."; # 1 item -> -10

{
    no warnings 'redefine';
    local *main::get_load_average = sub { return (8.0, 8.0, 8.0) };
    $main::mycalc{'cpu_cores'} = 4; # load_1 / cpu_cores = 2.0 > 1.0 -> -20
    local *main::get_other_process_memory = sub { return 8 * 1024 * 1024 * 1024; }; # 50% RAM -> -20
    main::calculate_sectional_health_scores();
}

# Print diagnostics for deduction test
diag("--- Diagnostic Info ---");
diag("General Recs: " . join(", ", @main::generalrec));
diag("Other Mem: " . main::get_other_process_memory());
diag("Load Avg: " . join(", ", main::get_load_average()));
diag("Calculated General Score: " . $main::result{'SectionalHealthScore'}{'General'});

is($main::result{'SectionalHealthScore'}{'General'}, 40, "General score should deduct for uptime, load, and other processes memory");
is($main::result{'SectionalHealthScore'}{'Storage'}, 50, "Storage score should deduct for read efficiency and temp disk tables");
is($main::result{'SectionalHealthScore'}{'Security'}, 85, "Security score should deduct for 1 recommendation");
is($main::result{'SectionalHealthScore'}{'Modeling'}, 90, "SQL Modeling score should deduct for 1 modeling finding");

# 3. Test Resource Saturation & Throughput Efficiency Index
reset_state();
$main::mystat{'Uptime'} = 10000;
$main::mycalc{'pct_max_physical_memory'} = "88%";
$main::mycalc{'pct_connections_used'} = "75.5%";
$main::mycalc{'pct_read_efficiency'} = 97.5; # disk read pressure = 2.5 * 20 = 50%
$main::mycalc{'pct_temp_disk'} = 40.0; # max(50, 40) = 50% IO sat
$main::mystat{'Questions'} = 50000; # QPS = 5.0
$main::mystat{'Innodb_buffer_pool_read_requests'} = 100000; # Reads/sec = 10.0
# TEI = QPS / Reads/sec = 5.0 / 10.0 = 0.5

{
    no warnings 'redefine';
    local *main::get_load_average = sub { return (2.5, 2.5, 2.5) };
    $main::mycalc{'cpu_cores'} = 4; # CPU sat = 2.5 / 4 = 62.5% -> 62%
    local *main::get_other_process_memory = sub { return 0; };
    main::calculate_sectional_health_scores();
}

is($main::result{'ResourceSaturation'}{'CPU'}, 62, "CPU saturation calculation");
is($main::result{'ResourceSaturation'}{'Memory'}, 88, "Memory saturation calculation");
is($main::result{'ResourceSaturation'}{'Connections'}, 75, "Connections saturation calculation");
is($main::result{'ResourceSaturation'}{'IO'}, 50, "Disk I/O saturation calculation");

is($main::result{'ThroughputEfficiency'}{'QPS'}, 5.0, "Throughput Efficiency QPS");
is($main::result{'ThroughputEfficiency'}{'LogicalReadsSec'}, 10.0, "Throughput Efficiency Reads/sec");
is($main::result{'ThroughputEfficiency'}{'Index'}, 0.5, "Throughput Efficiency Index (TEI)");

# 4. Test get_top_findings ranking logic
reset_state();
push @main::secrec, "Unencrypted connection detected."; # Critical keyword
push @main::secrec, "Check password complexity."; # Standard finding
push @main::secrec, "Accounts with empty password (risk)."; # Critical keyword (contains risk)
push @main::secrec, "Some minor issue.";

my @top_sec = main::get_top_findings(\@main::secrec);
is(scalar(@top_sec), 3, "get_top_findings returns at most 3 items");
is($top_sec[0]->{badge}, "Critical", "First item should be critical due to keyword");
is($top_sec[1]->{badge}, "Critical", "Second item should be critical due to keyword");
is($top_sec[2]->{badge}, "Finding", "Third item should be standard finding");

# 5. Test historical delta trend analysis
reset_state();
$main::result{'Stats'}{'QPS'} = 12.5;
$main::result{'HealthScore'} = 85;
$main::result{'Stats'}{'Total Data Size'} = 104857600; # 100MB
$main::result{'SectionalHealthScore'}{'General'} = 90;
$main::result{'SectionalHealthScore'}{'Storage'} = 80;
$main::result{'SectionalHealthScore'}{'Security'} = 95;
$main::result{'SectionalHealthScore'}{'Replication'} = 100;
$main::result{'SectionalHealthScore'}{'Modeling'} = 90;

{
    no warnings 'redefine';
    $main::opt{'compare-file'} = $mock_old_file;
    main::historical_comparison();
}

is($main::result{'Trends'}{'SnapshotDate'}, '2026-06-01', "Snapshot date correctly parsed");
like($main::result{'Trends'}{'QPS'}, qr/\+25\.00%/, "QPS trend delta should show +25.00%");
like($main::result{'Trends'}{'HealthScore'}, qr/\+5/, "Health score trend delta should show +5");
like($main::result{'Trends'}{'TotalDataSize'}, qr/80.0M -> 100.0M \(20.0M\)/, "Data growth should show correct formatting");
is($main::result{'Trends'}{'Sectional'}{'General'}, '95 -> 90 (-5)', "General score delta trend");
is($main::result{'Trends'}{'Sectional'}{'Storage'}, '70 -> 80 (+10)', "Storage score delta trend");

done_testing();
