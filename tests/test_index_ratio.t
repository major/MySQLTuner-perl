#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';

use Test::More tests => 1;
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
    
    # Mock data return for the query
    my @mock_ratio_tables = (
        "db1|table_under|10000000|1000000|60000",  # Ratio = 0.10 (< 0.3, Under-indexed)
        "db1|table_over|1000000|800000|80000",     # Ratio = 0.80 (> 0.6, Over-indexed)
        "db1|table_ideal|1000000|500000|70000"     # Ratio = 0.50 (Ideal)
    );
    local *main::select_array = sub { return @mock_ratio_tables; };

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

    is($dumped_file, 'table_indexes_potential_issues.csv', 'CSV file is correctly dumped');
    like($dumped_content, qr/"db1","table_under",0.10,10000000,1000000,"Under-indexed",60000/, 'Under-indexed table correctly identified');
    like($dumped_content, qr/"db1","table_over",0.80,1000000,800000,"Over-indexed",80000/, 'Over-indexed table correctly identified');
    like($dumped_content, qr/"db1","table_ideal",0.50,1000000,500000,"Ideal",70000/, 'Ideal table correctly identified');
};

1;
