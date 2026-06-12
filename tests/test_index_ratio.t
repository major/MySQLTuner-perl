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

subtest 'InnoDB Table Index/Data Ratio Check' => sub {
    no warnings 'redefine';
    no warnings 'uninitialized';
    local *main::subheaderprint = sub { };
    local *main::infoprint = sub { };
    local *main::badprint = sub { };
    local *main::goodprint = sub { };
    
    # Mock data return for the query using tab delimiters
    my @mock_ratio_tables = (
        "db1\ttable_under\t10000000\t1000000\t60000",  # Ratio = 0.10 (< 0.3, Under-indexed)
        "db1\ttable_over\t1000000\t800000\t80000",     # Ratio = 0.80 (> 0.6, Over-indexed)
        "db1\ttable_ideal\t1000000\t500000\t70000"     # Ratio = 0.50 (Ideal)
    );
    my $captured_query = '';
    local *main::select_array = sub {
        $captured_query = $_[0];
        return @mock_ratio_tables;
    };

    # Mock dump_into_file to track generated CSV content
    my $dumped_file = '';
    my $dumped_content = '';
    local *main::dump_into_file = sub {
        $dumped_file = $_[0];
        $dumped_content = $_[1];
    };

    %main::myvar = (
        'have_innodb' => 'YES',
    );
    %main::opt = (
        'dumpdir' => '/tmp/mockdump',
    );

    main::mysql_innodb();

    # Assert correct query targets InnoDB tables with > 50,000 rows
    like($captured_query, qr/information_schema\.TABLES/i, 'Query targets information_schema.TABLES');
    like($captured_query, qr/TABLE_ROWS\s*>\s*50000/i, 'Query filters for tables > 50,000 rows');
    like($captured_query, qr/ENGINE\s*=\s*'InnoDB'/i, 'Query filters for InnoDB engine');

    is($dumped_file, 'table_indexes_potential_issues.csv', 'CSV file is correctly dumped');
    like($dumped_content, qr/"db1","table_under",0.10,10000000,1000000,"Under-indexed",60000/, 'Under-indexed table correctly identified');
    like($dumped_content, qr/"db1","table_over",0.80,1000000,800000,"Over-indexed",80000/, 'Over-indexed table correctly identified');
    like($dumped_content, qr/"db1","table_ideal",0.50,1000000,500000,"Ideal",70000/, 'Ideal table correctly identified');
};

subtest 'InnoDB Table Index/Data Ratio Check Edge Cases' => sub {
    no warnings 'redefine';
    no warnings 'uninitialized';
    local *main::subheaderprint = sub { };
    local *main::infoprint = sub { };
    local *main::badprint = sub { };
    local *main::goodprint = sub { };
    
    # 1. Scenario: InnoDB is absent (have_innodb != 'YES')
    %main::myvar = (
        'have_innodb' => 'NO',
    );
    %main::opt = (
        'dumpdir' => '/tmp/mockdump',
    );
    
    my $select_array_called = 0;
    local *main::select_array = sub {
        $select_array_called = 1;
        return ();
    };
    
    my $dumped_file = '';
    local *main::dump_into_file = sub {
        $dumped_file = $_[0];
    };
    
    main::mysql_innodb();
    is($select_array_called, 0, 'No query executed when InnoDB is disabled');
    is($dumped_file, '', 'No CSV is dumped when InnoDB is disabled');
    
    # 2. Scenario: dumpdir is not configured
    %main::myvar = (
        'have_innodb' => 'YES',
    );
    %main::opt = (
        'dumpdir' => undef,
    );
    
    my @mock_ratio_tables = (
        "db1\ttable_under\t10000000\t1000000\t60000",
    );
    
    local *main::select_array = sub {
        return @mock_ratio_tables;
    };
    
    $dumped_file = '';
    main::mysql_innodb();
    is($dumped_file, '', 'No CSV file is dumped when dumpdir is not configured');
};

done_testing();

1;
