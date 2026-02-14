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
    *main::prettyprint = sub { };
}

sub has_output {
    my ($pattern) = @_;
    return grep { $_ =~ /$pattern/ } @mock_output;
}

subtest 'CVE Recommendation Logic' => sub {
    # 1. Prepare Mock CVE file
    my $cve_file = "tests/test_vulnerabilities.csv";
    open(my $fh, ">", $cve_file) or die $!;
    # Format: version;major;minor;micro;CVE-ID;Status;Description
    print $fh "8.0.30;8;0;30;CVE-2023-1234;PUBLISHED;Critical vulnerability in the MySQL Server product\n";
    print $fh "8.0.32;8;0;32;CVE-2023-5678;PUBLISHED;Another vulnerability for 8.0.32\n";
    print $fh "5.7.40;5;7;40;CVE-2023-9999;PUBLISHED;Vulnerability for 5.7.40\n";
    close($fh);

    # 2. Test Case: Version 8.0.25 (User should see CVE-2023-1234 since 8.0.25 <= 8.0.30)
    @main::generalrec = ();
    @mock_output = ();
    $main::opt{'cvefile'} = $cve_file;
    $main::myvar{'version'} = "8.0.25";

    main::validate_mysql_version();
    main::cve_recommendations();

    ok(has_output(qr/BAD: CVE-2023-1234\(<= 8\.0\.30\) : Critical vulnerability/), 'CVE-2023-1234 detected for 8.0.25');
    ok(has_output(qr/BAD: CVE-2023-5678\(<= 8\.0\.32\) : Another vulnerability/), 'CVE-2023-5678 detected for 8.0.25');
    ok(!has_output(qr/CVE-2023-9999/), 'CVE-2023-9999 not detected for 8.0.25 (major mismatch)');

    # 3. Test Case: Version 8.0.31 (User should only see CVE-2023-5678 since 8.0.31 > 8.0.30)
    @main::generalrec = ();
    @mock_output = ();
    $main::myvar{'version'} = "8.0.31";

    main::validate_mysql_version();
    main::cve_recommendations();

    ok(!has_output(qr/CVE-2023-1234/), 'CVE-2023-1234 NOT detected for 8.0.31');
    ok(has_output(qr/BAD: CVE-2023-5678\(<= 8\.0\.32\) : Another vulnerability/), 'CVE-2023-5678 detected for 8.0.31');

    # 4. Test Case: Version 8.0.40 (No CVE found)
    @main::generalrec = ();
    @mock_output = ();
    $main::myvar{'version'} = "8.0.40";

    main::validate_mysql_version();
    main::cve_recommendations();
    ok(has_output(qr/GOOD: NO SECURITY CVE FOUND/), 'No CVE found for 8.0.40');

    # Cleanup
    unlink($cve_file);
};

done_testing();
