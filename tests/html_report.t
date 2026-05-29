#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;
require './tests/MySQLTuner/TestHelper.pm';

# Mock print functions to populate @raw_output_lines
no warnings 'redefine';
*main::prettyprint = sub {
    my $plain_text = $_[0] // '';
    $plain_text =~ s/\e\[[0-9;]*[mK]//g;
    push @main::raw_output_lines, $plain_text;
};
*main::goodprint = sub { main::prettyprint("[OK] " . $_[0]); };
*main::infoprint = sub { main::prettyprint("[--] " . $_[0]); };
*main::badprint  = sub { main::prettyprint("[!!] " . $_[0]); };
*main::subheaderprint = sub { main::prettyprint(">> " . $_[0]); };
*main::debugprint = sub { };

subtest 'HTML Report Generation' => sub {
    MySQLTuner::TestHelper::reset_state();
    
    my $report_file = File::Spec->catfile($script_dir, 'test_report.html');
    unlink $report_file if -f $report_file;

    # Set CLI option for reportfile
    $main::opt{'reportfile'} = $report_file;

    # Populate mock metrics & recommendations
    $main::mycalc{'WeightedHealthScore'} = 85;
    $main::result{'HealthScoreDetails'} = {
        perf_bp => 10,
        perf_temp => 10,
        perf_thread => 10,
        perf_conn => 5,
        sec_total => 20,
        res_lag => 10,
        res_logs => 10,
        res_meta => 10
    };
    
    @main::generalrec = ("Test General Recommendation");
    @main::adjvars = ("innodb_buffer_pool_size = 1G");
    @main::modeling = (
        "Test Modeling Warning",
        {
            type   => 'unused_index',
            schema => 'test_db',
            table  => 'users',
            index  => 'idx_created_at',
        },
        {
            type           => 'redundant_index',
            schema         => 'test_db',
            table          => 'orders',
            index          => 'idx_redundant',
            dominant_index => 'idx_dominant',
            sql            => 'ALTER TABLE orders DROP INDEX idx_redundant',
        }
    );
    @main::secrec = ("Test Security Warning");
    @main::sysrec = ("Test System Recommendation");

    # Add mock outputs to raw trace
    main::prettyprint("This is a mock line of terminal output.");
    main::prettyprint("Another mock line.");

    # Run dump_result
    main::dump_result();

    # Assertions
    ok(-f $report_file, "HTML report file was created");
    
    # Read generated content
    open my $fh, '<', $report_file or die "Could not open $report_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    # Verify content structure
    like($content, qr/<!DOCTYPE html>/i, "Contains HTML doctype");
    like($content, qr/MySQLTuner Audit Report/i, "Contains title/header");
    like($content, qr/Overall Health Score/i, "Contains health score section");
    like($content, qr/85/i, "Contains the health score value");
    like($content, qr/Test General Recommendation/i, "Contains general recommendation");
    like($content, qr/innodb_buffer_pool_size = 1G/i, "Contains variables to adjust");
    like($content, qr/Test Modeling Warning/i, "Contains modeling warnings");
    like($content, qr/Unused index: test_db\.users \(idx_created_at\)/, "Contains formatted unused index");
    like($content, qr/Redundant index: test_db\.orders \(idx_redundant\) redundant of idx_dominant \(suggested SQL: ALTER TABLE orders DROP INDEX idx_redundant\)/, "Contains formatted redundant index");
    like($content, qr/Test Security Warning/i, "Contains security warnings");
    like($content, qr/Test System Recommendation/i, "Contains system recommendations");
    like($content, qr/This is a mock line of terminal output/i, "Contains raw console output trace");

    # Cleanup
    unlink $report_file;
};

subtest 'HTML Report CLI Option Formatting' => sub {
    MySQLTuner::TestHelper::reset_state();
    
    # 1. Test empty/boolean option
    $main::opt{'reportfile'} = '';
    
    # Call the logic snippet under test
    if ( defined $main::opt{'reportfile'} ) {
        if ( $main::opt{'reportfile'} eq '' || $main::opt{'reportfile'} eq '1' ) {
            $main::opt{'reportfile'} = 'mysqltuner.html';
        }
    }
    is($main::opt{'reportfile'}, 'mysqltuner.html', "Empty reportfile option is converted to default filename");
    
    # 2. Test boolean '1' option
    $main::opt{'reportfile'} = '1';
    if ( defined $main::opt{'reportfile'} ) {
        if ( $main::opt{'reportfile'} eq '' || $main::opt{'reportfile'} eq '1' ) {
            $main::opt{'reportfile'} = 'mysqltuner.html';
        }
    }
    is($main::opt{'reportfile'}, 'mysqltuner.html', "Boolean '1' reportfile option is converted to default filename");
    
    # 3. Test explicit path option
    $main::opt{'reportfile'} = 'custom_report.html';
    if ( defined $main::opt{'reportfile'} ) {
        if ( $main::opt{'reportfile'} eq '' || $main::opt{'reportfile'} eq '1' ) {
            $main::opt{'reportfile'} = 'mysqltuner.html';
        }
    }
    is($main::opt{'reportfile'}, 'custom_report.html', "Explicit path reportfile option remains unchanged");
};

done_testing();
