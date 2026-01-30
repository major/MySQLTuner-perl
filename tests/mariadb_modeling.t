#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Load the script first to get the subroutines
{
    local @ARGV = (); 
    no warnings 'redefine';
    require './mysqltuner.pl';
}

my @mock_output;
# Mock functions
{
    no warnings 'redefine';
    *main::infoprint = sub { diag "MOCK INFO: $_[0]"; push @mock_output, "INFO: $_[0]" };
    *main::badprint = sub { diag "MOCK BAD: $_[0]"; push @mock_output, "BAD: $_[0]" };
    *main::goodprint = sub { diag "MOCK GOOD: $_[0]"; push @mock_output, "GOOD: $_[0]" };
    *main::debugprint = sub { diag "MOCK DEBUG: $_[0]"; push @mock_output, "DEBUG: $_[0]" };
    *main::subheaderprint = sub { diag "MOCK SUBHEADER: $_[0]"; push @mock_output, "SUBHEADER: $_[0]" };
}

# Mock select_array to handle multiple different queries
my %mock_queries;
{
    no warnings 'redefine';
    *main::select_array = sub {
        my ($query) = @_;
        diag "MOCK SELECT_ARRAY: $query";
        foreach my $pattern (sort { length($b) <=> length($a) } keys %mock_queries) {
            if ($query =~ /$pattern/si) {
                diag "MOCK MATCHED: $pattern";
                return @{$mock_queries{$pattern}};
            }
        }
        return ();
    };
}

sub has_output {
    my ($pattern) = @_;
    return grep { $_ =~ /$pattern/ } @mock_output;
}

subtest 'MariaDB 10.x Modeling Checks' => sub {
    # 1. Setup MariaDB 10.11 Mock Environment
    %main::myvar = (
        'version' => '10.11.5-MariaDB',
    );
    @main::generalrec = ();
    @main::modeling = ();
    @mock_output = ();

    # Mock queries for MariaDB (should use IGNORED column)
    %mock_queries = (
        'DATA_TYPE = \'json\'' => [],
        'IGNORED = \'YES\'' => [
            "test_db\tusers\tidx_email_ignored",
        ],
    );

    # 2. Execute Logic
    main::mysql_80_modeling_checks();

    # 3. Assertions
    ok(has_output(qr/SUBHEADER: MariaDB 10\.x\+ Specific Modeling/), 'Correct header for MariaDB');
    ok(has_output(qr/INFO: Index test_db\.users\.idx_email_ignored is INVISIBLE/), 'Invisible (Ignored) index detected on MariaDB');
    ok(grep { $_ =~ /Index test_db\.users\.idx_email_ignored is INVISIBLE/ } @main::modeling, 'Finding added to @modeling');
};

subtest 'MySQL 8.0 Modeling Checks (Regression)' => sub {
    # 1. Setup MySQL 8.0 Mock Environment
    %main::myvar = (
        'version' => '8.0.35',
    );
    @main::generalrec = ();
    @main::modeling = ();
    @mock_output = ();

    # Mock queries for MySQL (should use IS_VISIBLE column)
    %mock_queries = (
        'DATA_TYPE = \'json\'' => [],
        'IS_VISIBLE = \'NO\'' => [
            "test_db\tusers\tidx_email_invisible",
        ],
    );

    # 2. Execute Logic
    main::mysql_80_modeling_checks();

    # 3. Assertions
    ok(has_output(qr/SUBHEADER: MySQL 8\.0\+ Specific Modeling/), 'Correct header for MySQL');
    ok(has_output(qr/INFO: Index test_db\.users\.idx_email_invisible is INVISIBLE/), 'Invisible index detected on MySQL');
};

done_testing();
