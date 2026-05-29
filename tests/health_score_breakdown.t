#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
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
    require './tests/MySQLTuner/TestHelper.pm';
}

package main;

# 1. Reset state
@main::generalrec = ();
@main::sysrec     = ();
@main::secrec     = ();
@main::modeling   = ();
@main::adjvars    = ();
%main::mycalc     = ();
%main::mystat     = ();
%main::myrepl     = ();

# 2. Mock optimal metrics (Performance: 40/40, Security: 30/30, Resilience: 30/30)
$main::mycalc{'pct_read_efficiency'}    = 99.5; # -> perf_bp = 10
$main::mycalc{'pct_temp_disk'}          = 5.0;  # -> perf_temp = 10
$main::mycalc{'thread_cache_hit_rate'}  = 95.0; # -> perf_thread = 10
$main::mycalc{'pct_connections_used'}   = 50.0; # -> perf_conn = 10
$main::myrepl{'Seconds_Behind_Source'} = 0;    # -> res_lag = 10

# Run calculations and checks
main::calculate_health_score();

is($main::mycalc{'WeightedHealthScore'}, 100, "Optimal configuration should score 100/100");
my $details = $main::result{'HealthScoreDetails'};
is($details->{'perf_bp'}, 10, "Buffer pool hit rate details should be 10");
is($details->{'perf_temp'}, 10, "Temp tables on disk details should be 10");
is($details->{'perf_thread'}, 10, "Thread cache hit rate details should be 10");
is($details->{'perf_conn'}, 10, "Connections usage details should be 10");
is($details->{'sec_total'}, 30, "Security score details should be 30");
is($details->{'res_lag'}, 10, "Replication lag details should be 10");
is($details->{'res_logs'}, 10, "Logs safety details should be 10");
is($details->{'res_meta'}, 10, "Metadata checks details should be 10");

# 3. Test Security deduction
push @main::secrec, "Insecure password.";
push @main::secrec, "Anonymous user.";
main::calculate_health_score();
is($main::mycalc{'WeightedHealthScore'}, 90, "Weighted health score should deduct 10 points for two security findings");
is($main::result{'HealthScoreDetails'}->{'sec_total'}, 20, "Security sub-score should be 20/30");

# 4. Test display_health_score
my $output_called = 0;
no warnings 'redefine';
local *main::prettyprint = sub {
    my $msg = shift;
    if ($msg =~ /Performance:\s+(\d+)\/40/) {
        is($1, 40, "Performance sub-score printed correctly");
        $output_called++;
    }
    if ($msg =~ /Security:\s+(\d+)\/30/) {
        is($1, 20, "Security sub-score printed correctly");
        $output_called++;
    }
    if ($msg =~ /Resilience:\s+(\d+)\/30/) {
        is($1, 30, "Resilience sub-score printed correctly");
        $output_called++;
    }
};
local *main::subheaderprint = sub {};
local *main::badprint = sub {};
local *main::infoprint = sub {};
local *main::goodprint = sub {};

main::display_health_score();
is($output_called, 3, "All three sub-score categories printed in the breakdown");

done_testing();
