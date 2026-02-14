#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# 1. Global mocks before loading
BEGIN {
    *CORE::GLOBAL::exit = sub { die "EXIT_CALLED\n" };
}

# 2. Preparation
our %opt = (
    'host' => '127.0.0.1',
    'user' => 'root',
    'pass' => 'mysqltuner_test',
    'noask' => 1,
    'skippassword' => 1,
    'debug' => 0,
);
our %myvar = (
    'version' => '8.0.32',
    'lower_case_table_names' => '0',
);
our %mystat = ();
our @generalrec = ();
our @modeling = ();
our $mysqlcmd = 'mysql';
our $mysqllogin = '';
our $devnull = '/dev/null';

# Capture output
our @captured_output = ();
sub mock_badprint { push @captured_output, "BAD: " . join(' ', @_); }
sub mock_goodprint { push @captured_output, "GOOD: " . join(' ', @_); }
sub mock_infoprint { push @captured_output, "INFO: " . join(' ', @_); }
sub mock_subheaderprint { push @captured_output, "SUBHEADER: " . join(' ', @_); }

# Mock SQL execution
sub mock_select_array {
    my $req = shift;
    if ($req =~ /information_schema\.tables/ && $req =~ /TABLE_NAME/) {
        return (
            "employees\tdepartments",
            "employees\temployees",
            "employees\tsalaries",
            "employees\ttitles"
        );
    }
    if ($req =~ /information_schema\.referential_constraints/) {
        return (
            "employees\tdept_manager\temp_no\temployees\temp_no\tCASCADE",
            "employees\tdept_manager\tdept_no\tdepartments\tdept_no\tCASCADE",
            "employees\tdept_emp\temp_no\temployees\temp_no\tCASCADE"
        );
    }
    if ($req =~ /information_schema\.columns/ && $req =~ /TABLE_SCHEMA/) {
        return (
            "employees\tdepartments\tdept_name\tvarchar",
            "employees\ttitles\tfrom_date\tdate"
        );
    }
    if ($req =~ /information_schema\.statistics/ && $req =~ /IS_VISIBLE/) {
        return (); # No invisible indexes
    }
    return ();
}

# 3. Load the script
{
    local @ARGV = ('--help'); # Minimize impact
    eval { require "./mysqltuner.pl"; };
    # ignore EXIT_CALLED or other errors from the main part
}

# 4. Redefine after load to override script's definitions
{
    no warnings 'redefine';
    *main::badprint = \&mock_badprint;
    *main::goodprint = \&mock_goodprint;
    *main::infoprint = \&mock_infoprint;
    *main::subheaderprint = \&mock_subheaderprint;
    *main::select_array = \&mock_select_array;
    *main::select_one = sub { return ""; };
}

# 5. Run tests
ok(defined &mysql_naming_conventions, "mysql_naming_conventions defined");
ok(defined &mysql_foreign_key_checks, "mysql_foreign_key_checks defined");

@captured_output = ();
eval { mysql_naming_conventions(); };
is($@, '', "mysql_naming_conventions executed without crash");

my @plural_warnings = grep { /Plural name detected/ } @captured_output;
is(scalar(@plural_warnings), 4, "Detected 4 plural table names");
ok((grep { /employees.departments/ } @plural_warnings), "Detected departments as plural");

@captured_output = ();
eval { mysql_foreign_key_checks(); };
is($@, '', "mysql_foreign_key_checks executed without crash");

my @cascade_info = grep { /uses ON DELETE CASCADE/ } @captured_output;
is(scalar(@cascade_info), 3, "Detected 3 CASCADE constraints");

# Test "nothing found"
{
    no warnings 'redefine';
    *main::select_array = sub { return (); };
}

@captured_output = ();
eval { mysql_80_modeling_checks(); };
ok((grep { /No MySQL 8.0\+ specific modeling issues found/ } @captured_output), "Verified MySQL 8.0 message");

@captured_output = ();
eval { mysql_datatype_optimization(); };
ok((grep { /No data type optimization recommendations/ } @captured_output), "Verified Datatype message");

@captured_output = ();
$main::namingIssues = 0; # Reset if needed, though it's local in the sub
eval { mysql_naming_conventions(); };
ok((grep { /No naming convention issues found/ } @captured_output), "Verified Naming message");

@captured_output = ();
eval { mysql_foreign_key_checks(); };
ok((grep { /No foreign key issues found/ } @captured_output), "Verified FK message");

@captured_output = ();
eval { mysql_schema_sanitization(); };
ok((grep { /No empty or view-only schemas detected/ } @captured_output), "Verified Schema message");

done_testing();
