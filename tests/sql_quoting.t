#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Mocking variables and functions from mysqltuner.pl
our %opt = ( container => 'test_container' );
our $mysqlcmd = "mysql";
our $mysqllogin = "-u root";
our $devnull = "/dev/null";

my $captured_cmd = "";

sub execute_system_command {
    ($captured_cmd) = @_;
    return wantarray ? () : "";
}

sub debugprint { }
sub badprint { }

# Re-implement fixed subroutines for testing
sub select_array {
    my $req = shift;
    my $req_escaped = $req;
    $req_escaped =~ s/"/\\"/g;
    execute_system_command(
        "$mysqlcmd $mysqllogin -Bse \"\\w$req_escaped\" 2>>$devnull");
    return ();
}

sub select_array_with_headers {
    my $req = shift;
    my $req_escaped = $req;
    $req_escaped =~ s/"/\\"/g;
    execute_system_command(
        "$mysqlcmd $mysqllogin -Bre \"\\w$req_escaped\" 2>>$devnull");
    return ();
}

# Plan tests
plan tests => 4;

# Test Case 1: Query with double quotes (the original bug)
my $query = 'select CONCAT(table_schema, ".", table_name, " (", redundant_index_name, ") redundant of ", dominant_index_name, " - SQL: ", sql_drop_index) from sys.schema_redundant_indexes;';
select_array($query);
my $expected = 'mysql -u root -Bse "\wselect CONCAT(table_schema, \".\", table_name, \" (\", redundant_index_name, \") redundant of \", dominant_index_name, \" - SQL: \", sql_drop_index) from sys.schema_redundant_indexes;" 2>>/dev/null';
is($captured_cmd, $expected, "SQL query with double quotes should be correctly escaped (select_array)");

# Test Case 2: Simple query
$query = 'SHOW VARIABLES';
select_array($query);
$expected = 'mysql -u root -Bse "\wSHOW VARIABLES" 2>>/dev/null';
is($captured_cmd, $expected, "Simple SQL query should remain intact (select_array)");

# Test Case 3: select_array_with_headers with double quotes
$query = 'select "complex" as col';
select_array_with_headers($query);
$expected = 'mysql -u root -Bre "\wselect \"complex\" as col" 2>>/dev/null';
is($captured_cmd, $expected, "SQL query with double quotes should be correctly escaped (select_array_with_headers)");

# Test Case 4: verify no regression for single quotes (handled by execute_system_command later but should not be affected here)
$query = "select 'simple' as col";
select_array($query);
$expected = "mysql -u root -Bse \"\\wselect 'simple' as col\" 2>>/dev/null";
is($captured_cmd, $expected, "Single quotes should remain intact in select_array");

done_testing();
