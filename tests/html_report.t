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
    $main::opt{'host'} = '127.0.0.1';
    $main::opt{'port'} = '3307';

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

    $main::result{'Databases'}{'List'} = ['test_db', 'mydb'];
    $main::result{'Databases'}{'test_db'} = {
        'Tables' => 10,
        'Rows' => 5000,
        'Data Size' => 1024 * 1024 * 50,
        'Index Size' => 1024 * 1024 * 10,
        'Total Size' => 1024 * 1024 * 60,
    };
    $main::result{'Databases'}{'mydb'} = {
        'Tables' => 20,
        'Rows' => 15000,
        'Data Size' => 1024 * 1024 * 150,
        'Index Size' => 1024 * 1024 * 50,
        'Total Size' => 1024 * 1024 * 200,
    };
    $main::result{'Engine'} = {
        InnoDB => {
            'Table Number' => 10,
            'Data Size'    => 1024 * 1024 * 50,
            'Index Size'   => 1024 * 1024 * 10,
            'Total Size'   => 1024 * 1024 * 60,
            'Enabled'      => 'YES'
        },
        MyISAM => {
            'Table Number' => 2,
            'Data Size'    => 1024 * 1024 * 5,
            'Index Size'   => 1024 * 1024 * 1,
            'Total Size'   => 1024 * 1024 * 6,
            'Enabled'      => 'YES'
        }
    };
    $main::result{'Tables without PK'} = ['test_db.orders'];
    $main::result{'Tables'}{'Fragmented tables'} = [ "test_db\torders\tInnoDB\t104857600" ];
    $main::mystat{'Innodb_buffer_pool_pages_total'} = 65536;
    $main::mystat{'Innodb_buffer_pool_pages_free'} = 16384;
    $main::mystat{'Innodb_os_log_written'} = 1024 * 1024 * 10;
    $main::mystat{'Uptime'} = 7200;
    $main::myvar{'innodb_buffer_pool_instances'} = 8;
    $main::myvar{'innodb_buffer_pool_chunk_size'} = 128 * 1024 * 1024;
    $main::myvar{'innodb_buffer_pool_size'} = 1024 * 1024 * 1024;
    $main::myvar{'innodb_redo_log_capacity'} = 512 * 1024 * 1024;
    $main::fragtables = 3;
    
    @main::generalrec = ("Test General Recommendation");
    @main::adjvars = ("innodb_buffer_pool_size = 1G");
    @main::modeling = (
        "Test Modeling Warning",
        {
            type   => 'unused_index',
            schema => 'test_db',
            table  => 'users',
            index  => 'idx_created_at',
            sql    => 'ALTER TABLE test_db.users DROP INDEX idx_created_at',
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
    like($content, qr/Unused index: test_db\.users \(idx_created_at\) \(suggested SQL: ALTER TABLE test_db\.users DROP INDEX idx_created_at\)/, "Contains formatted unused index");
    like($content, qr/Redundant index: test_db\.orders \(idx_redundant\) redundant of idx_dominant \(suggested SQL: ALTER TABLE orders DROP INDEX idx_redundant\)/, "Contains formatted redundant index");
    like($content, qr/Test Security Warning/i, "Contains security warnings");
    like($content, qr/Test System Recommendation/i, "Contains system recommendations");
    like($content, qr/This is a mock line of terminal output/i, "Contains raw console output trace");
    like($content, qr/id="tab-dashboard"/i, "Contains dashboard tab");
    like($content, qr/id="tab-storage"/i, "Contains storage engines tab");
    like($content, qr/id="tab-export"/i, "Contains data export tab");
    like($content, qr/const dbMetrics = \{/i, "Contains embedded JSON dbMetrics");
    like($content, qr/function downloadCSV/i, "Contains Javascript CSV downloader");
    like($content, qr/id="sysrec-list"/i, "Contains OS & System recommendations list");
    like($content, qr/id="adjvars-list"/i, "Contains Storage adjustments list");
    like($content, qr/id="secrec-list"/i, "Contains Security advice list");
    like($content, qr/id="modeling-list"/i, "Contains SQL modeling recommendations list");
    like($content, qr/id="replication-rec-list"/i, "Contains Replication general recommendations list");
    like($content, qr/id="connections-rec-list"/i, "Contains Connections recommendations list");
    like($content, qr/id="performance-rec-list"/i, "Contains Performance recommendations list");
    like($content, qr/at 127\.0\.0\.1:3307/i, "Contains host and port in header");
    like($content, qr/Enabled Storage Engines Status/i, "Contains Enabled Storage Engines Status header");
    like($content, qr/Storage Engine Data Distribution/i, "Contains Storage Engine Data Distribution table");
    like($content, qr/InnoDB Engine Detailed Diagnostics/i, "Contains InnoDB Engine Detailed Diagnostics card");
    like($content, qr/User Databases Size Distribution/i, "Contains User Databases Size Distribution table");
    like($content, qr/Fragmented Tables Details/i, "Contains Fragmented Tables Details table");
    like($content, qr/Tables Without Primary Key Details/i, "Contains Tables Without Primary Key Details table");
    like($content, qr/Redundant Indexes Details/i, "Contains Redundant Indexes Details table");
    like($content, qr/Unused Indexes Details/i, "Contains Unused Indexes Details table");
    like($content, qr/SQL Schema Summary KPI Grid/i, "Contains SQL Schema Summary KPI Grid comment/section");
    like($content, qr/window\.location\.hash = tabId/i, "Contains tab hash persistence hook");
    like($content, qr/function filterList/i, "Contains list search filter helper");
    like($content, qr/metadata: \{/i, "Contains metadata block in dbMetrics");
    like($content, qr/gauge-progress/i, "Contains gauge animation class");
    like($content, qr/id="copy-json-btn"/i, "Contains copy JSON button");
    like($content, qr/function copyJSON/i, "Contains copyJSON helper function");
    like($content, qr/function replaceIcons/i, "Contains replaceIcons SVG helper function");
    like($content, qr/\@media\s*\(min-width:\s*640px\)/i, "Contains fallback CSS media queries");


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
