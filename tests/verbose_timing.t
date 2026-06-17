#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Suppress warnings from mysqltuner.pl initialization
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

# Ensure verbose is on, and clear state
$main::opt{'verbose'} = 1;
@main::section_timings = ();
@main::raw_output_lines = ();
$main::tuner_start_time = (eval { require Time::HiRes; Time::HiRes::time(); } || time()) - 1.0;
$main::current_section_name = undef;

# Call subheaderprint twice to trigger timing print of first section
main::subheaderprint("Section A");
$main::current_section_start = $main::current_section_start - 0.5; # Fake elapsed time of 0.5s
main::subheaderprint("Section B");

# Check if timing for Section A was printed
my @section_a_lines = grep { /Section A execution time:/ } @main::raw_output_lines;
ok(scalar @section_a_lines > 0, "Execution time for Section A is printed when verbose is enabled");
like($section_a_lines[0], qr/Section A execution time: 0\.\d+s/, "Duration format is correct");

# Run print_execution_timings
@main::raw_output_lines = ();
main::print_execution_timings();

# Check if summary block is printed with percentages
my @summary_lines = grep { /Section B\s*:/ || /Total Execution Time:/ } @main::raw_output_lines;
ok(scalar @summary_lines >= 2, "Summary block and total execution time are printed at the end");
my @pct_lines = grep { /\(\d+\.\d+%\)/ } @main::raw_output_lines;
ok(scalar @pct_lines >= 2, "Percentages are printed next to each section duration");

# Run again with verbose = 0 and verify NO timings are printed
$main::opt{'verbose'} = 0;
@main::section_timings = ();
@main::raw_output_lines = ();
$main::current_section_name = undef;

main::subheaderprint("Section A");
main::subheaderprint("Section B");
main::print_execution_timings();

my @no_timing_lines = grep { /execution time:/ || /Total Execution Time:/ } @main::raw_output_lines;
is(scalar @no_timing_lines, 0, "No timing messages are printed when verbose is disabled");

# 3. Test print_audit_snapshot_summary
subtest 'print_audit_snapshot_summary' => sub {
    @main::raw_output_lines = ();
    $main::tunerversion = "9.9.9";
    $main::opt{'host'} = "127.0.0.1";
    $main::opt{'port'} = 3307;
    $main::physical_memory = 16 * 1024 * 1024 * 1024;
    $main::swap_memory = 4 * 1024 * 1024 * 1024;
    $main::myvar{'version'} = "10.11.4-MariaDB";
    $main::mystat{'Uptime'} = 172800;

    # We mock select_one so that we don't try to query database for CURRENT_USER
    no warnings 'redefine';
    local *main::select_one = sub { return 'root@localhost'; };

    main::print_audit_snapshot_summary();

    my $output = join("\n", @main::raw_output_lines);
    like($output, qr/Audit Snapshot Summary/, "Header printed");
    like($output, qr/MySQLTuner Version : 9\.9\.9/, "MySQLTuner version matched");
    like($output, qr/Server Connection  : 127\.0\.0\.1:3307/, "Connection matched");
    like($output, qr/Database User      : root\@localhost/, "Database user matched");
    like($output, qr/Database Version   : 10\.11\.4-MariaDB/, "Database version matched");
    like($output, qr/System Physical RAM: 16\.0G/, "System RAM matched");
    like($output, qr/System Swap Memory : 4\.0G/, "System Swap matched");
    like($output, qr/Database Uptime    : 2d 0h 0m 0s/, "Database uptime matched");
};

done_testing();
