#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;

# Mock these before loading the script if possible, or handle them carefully
our @adjvars;
our @generalrec;
our @modeling;
our @sysrec;
our @secrec;
our %opt;
our %myvar;

# Load the script first to get the subroutines
{
    local @ARGV = (); # Empty ARGV for GetOptions
    no warnings 'redefine';
    require './mysqltuner.pl';
}

my @mock_output;
# Now mock the functions at runtime
{
    no warnings 'redefine';
    *main::infoprint = sub { push @mock_output, "INFO: $_[0]" };
    *main::badprint = sub { push @mock_output, "BAD: $_[0]" };
    *main::goodprint = sub { push @mock_output, "GOOD: $_[0]" };
    *main::debugprint = sub { push @mock_output, "DEBUG: $_[0]" };
    *main::subheaderprint = sub { push @mock_output, "SUBHEADER: $_[0]" };
    *main::hr_bytes = sub { return $_[0] };
    *main::select_one = sub { 
        my ($query) = @_;
        if ($query =~ /sys_version/) { return "2.1.1"; }
        return "0";
    };
}

# Mock select_array to handle multiple different queries
my %mock_queries;
{
    no warnings 'redefine';
    *main::select_array = sub {
        my ($query) = @_;
        foreach my $pattern (keys %mock_queries) {
            if ($query =~ /$pattern/si) {
                return @{$mock_queries{$pattern}};
            }
        }
        return ();
    };
}

subtest 'Unused and Redundant Index Checks' => sub {
    %mock_queries = (
        'SHOW DATABASES' => ['mysql', 'information_schema', 'performance_schema', 'sys', 'test_db'],
        'sys.schema_unused_indexes' => ['test_db.users (idx_unused)'],
        'sys.schema_redundant_indexes' => ['test_db.orders (idx_redundant) redundant of idx_dominant - SQL: ALTER TABLE `test_db`.`orders` DROP INDEX `idx_redundant`'],
    );
    @main::generalrec = ();
    @main::modeling = ();
    @mock_output = ();
    $main::opt{'pfstat'} = 1;
    $main::myvar{'performance_schema'} = 'ON';
    
    main::mysql_pfs();
    
    # Check Unused Indexes
    ok(grep({ $_ =~ /Unused indexes found: 1 index\(es\) should be reviewed/ } @main::generalrec), 'Unused index recommendation found');
    ok(grep({ $_ =~ /BAD: Performance schema: 1 unused index\(es\) found/ } @mock_output), 'Unused index BAD message found');
    ok(grep({ ref($_) eq 'HASH' && $_->{type} eq 'unused_index' } @main::modeling), 'Unused index modeling finding found');

    # Check Redundant Indexes
    ok(grep({ $_ =~ /Redundant indexes found: 1 index\(es\) should be reviewed/ } @main::generalrec), 'Redundant index recommendation found');
    ok(grep({ $_ =~ /BAD: Performance schema: 1 redundant index\(es\) found/ } @mock_output), 'Redundant index BAD message found');
    ok(grep({ ref($_) eq 'HASH' && $_->{type} eq 'redundant_index' } @main::modeling), 'Redundant index modeling finding found');
};

done_testing();
