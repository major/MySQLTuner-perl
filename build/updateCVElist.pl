#!/usr/bin/env perl
# ===========================================================================
# Script:      build/updateCVElist.pl
# Description: Fetches and updates MySQL and MariaDB CVE vulnerabilities
#              from NVD API 2.0 using pure Perl (Core HTTP::Tiny & JSON::PP).
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP;
use File::Spec;
use Cwd qw(getcwd);

my $PROJECT_ROOT = getcwd();
my $OUTPUT_FILE  = File::Spec->catfile( $PROJECT_ROOT, "vulnerabilities.csv" );
my $NVD_API_URL  = "https://services.nvd.nist.gov/rest/json/cves/2.0";
my $RESULTS_PER_PAGE = 2000;
my $DELAY_SECONDS     = 6;

my @TARGET_CPES = (
    "cpe:2.3:a:oracle:mysql_server",
    "cpe:2.3:a:mariadb:mariadb"
);

my $http = HTTP::Tiny->new(
    agent   => "MySQLTuner-CVE-Updater/2.0",
    timeout => 30
);

unlink $OUTPUT_FILE if -f $OUTPUT_FILE;

open( my $out_fh, ">", $OUTPUT_FILE ) or die "Cannot open $OUTPUT_FILE: $!";
print "Fetching vulnerabilities from NVD API 2.0...\n";

foreach my $cpe (@TARGET_CPES) {
    print "Processing CPE: $cpe\n";
    my $start_index   = 0;
    my $total_results = 1;

    while ( $start_index < $total_results ) {
        my $url = "$NVD_API_URL?virtualMatchString=$cpe&resultsPerPage=$RESULTS_PER_PAGE&startIndex=$start_index";
        print "  Requesting: $url\n";

        my $response = $http->get($url);
        if ( !$response->{success} ) {
            warn "  ERROR: Failed to fetch data: $response->{status} $response->{reason}\n";
            last;
        }

        my $data = eval { decode_json( $response->{content} ) };
        if ( !$data ) {
            warn "  ERROR: Failed to parse JSON response: $@\n";
            last;
        }

        $total_results = $data->{totalResults} // 0;
        my @vulnerabilities = @{ $data->{vulnerabilities} // [] };
        print "  Found " . scalar(@vulnerabilities) . " vulnerabilities (Total: $total_results)\n";

        foreach my $v (@vulnerabilities) {
            my $cve    = $v->{cve};
            my $cve_id = $cve->{id};
            my $status = $cve->{vulnStatus} // 'PUBLISHED';

            my $description = "";
            foreach my $desc ( @{ $cve->{descriptions} // [] } ) {
                if ( $desc->{lang} eq 'en' ) {
                    $description = $desc->{value};
                    last;
                }
            }
            $description =~ s/;/ /g;
            $description =~ s/\n/ /g;
            $description = substr( $description, 0, 200 ) . "..." if length($description) > 200;

            my %seen_versions;
            foreach my $config ( @{ $cve->{configurations} // [] } ) {
                foreach my $node ( @{ $config->{nodes} // [] } ) {
                    foreach my $match ( @{ $node->{cpeMatch} // [] } ) {
                        if ( $match->{criteria} =~ /^\Q$cpe\E/ ) {
                            my $v_end = $match->{versionEndIncluding}
                              || $match->{versionEndExcluding}
                              || "";

                            if ( !$v_end && $match->{criteria} =~ /:([^:]+)$/ ) {
                                $v_end = $1;
                                next if $v_end eq '*';
                            }

                            if ( $v_end && $v_end =~ /^(\d+)\.(\d+)\.(\d+)/ ) {
                                my $major = $1;
                                my $minor = $2;
                                my $micro = $3;

                                if ( $match->{versionEndExcluding} ) {
                                    if ( $micro > 0 ) {
                                        $micro--;
                                    }
                                    else {
                                        next;
                                    }
                                }

                                my $full_v = "$major.$minor.$micro";
                                next if $seen_versions{$full_v};
                                $seen_versions{$full_v} = 1;

                                print $out_fh "$full_v;$major;$minor;$micro;$cve_id;$status;$description\n";
                            }
                        }
                    }
                }
            }
        }

        $start_index += $RESULTS_PER_PAGE;
        if ( $start_index < $total_results ) {
            print "  Waiting $DELAY_SECONDS seconds before next page...\n";
            sleep($DELAY_SECONDS);
        }
    }
}

close($out_fh);
print "Done! Output saved to $OUTPUT_FILE\n";
exit(0);
