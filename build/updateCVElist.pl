#!/usr/bin/env perl
use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use Data::Dumper;

# Configuration
my $NVD_API_URL = "https://services.nvd.nist.gov/rest/json/cves/2.0";
my $OUTPUT_FILE = "./vulnerabilities.csv";
my $RESULTS_PER_PAGE = 2000; # Max allowed by NVD API 2.0
my $DELAY_SECONDS = 6;      # Delay between pagination calls to stay under rate limits

# Target CPEs
my @TARGET_CPES = (
    "cpe:2.3:a:oracle:mysql_server",
    "cpe:2.3:a:mariadb:mariadb"
);

my $ua = LWP::UserAgent->new(timeout => 30);
$ua->agent("MySQLTuner-CVE-Updater/2.0");

# Delete old file
unlink $OUTPUT_FILE if -f $OUTPUT_FILE;

open(my $out_fh, ">", $OUTPUT_FILE) or die "Cannot open $OUTPUT_FILE: $!";
print "Fetching vulnerabilities from NVD API 2.0...\n";

foreach my $cpe (@TARGET_CPES) {
    print "Processing CPE: $cpe\n";
    my $start_index = 0;
    my $total_results = 1; # Initial dummy value

    while ($start_index < $total_results) {
        my $url = "$NVD_API_URL?virtualMatchString=$cpe&resultsPerPage=$RESULTS_PER_PAGE&startIndex=$start_index";
        print "  Requesting: $url\n";
        
        my $response = $ua->get($url);
        if (!$response->is_success) {
            warn "  ERROR: Failed to fetch data: " . $response->status_line;
            last;
        }

        my $data = eval { decode_json($response->decoded_content) };
        if (!$data) {
            warn "  ERROR: Failed to parse JSON response: $@";
            last;
        }

        $total_results = $data->{totalResults} // 0;
        my @vulnerabilities = @{$data->{vulnerabilities} // []};
        print "  Found " . scalar(@vulnerabilities) . " vulnerabilities (Total: $total_results)\n";

        foreach my $v (@vulnerabilities) {
            my $cve = $v->{cve};
            my $cve_id = $cve->{id};
            my $status = $cve->{vulnStatus} // 'PUBLISHED';
            
            # Extract English description
            my $description = "";
            foreach my $desc (@{$cve->{descriptions} // []}) {
                if ($desc->{lang} eq 'en') {
                    $description = $desc->{value};
                    last;
                }
            }
            $description =~ s/;/ /g; # Replace semicolons to avoid breaking CSV
            $description =~ s/\n/ /g; # Replace newlines
            $description = substr($description, 0, 200) . "..." if length($description) > 200;

            # Extract vulnerable versions from configurations
            my %seen_versions;
            foreach my $config (@{$cve->{configurations} // []}) {
                foreach my $node (@{$config->{nodes} // []}) {
                    foreach my $match (@{$node->{cpeMatch} // []}) {
                        if ($match->{criteria} =~ /^\Q$cpe\E/) {
                            my $v_end = $match->{versionEndIncluding} 
                                     || $match->{versionEndExcluding} 
                                     || "";
                            
                            # If no specific version end is mentioned, but criteria has a version
                            if (!$v_end && $match->{criteria} =~ /:([^:]+)$/) {
                                $v_end = $1;
                                next if $v_end eq '*'; # Skip wildcard
                            }

                            if ($v_end && $v_end =~ /^(\d+)\.(\d+)\.(\d+)/) {
                                my $major = $1;
                                my $minor = $2;
                                my $micro = $3;
                                
                                # Decrement micro if versionEndExcluding
                                if ($match->{versionEndExcluding}) {
                                    if ($micro > 0) {
                                        $micro--;
                                    } else {
                                        # Skip version 0.0.0 cases if we can't easily decrement
                                        next;
                                    }
                                }

                                my $full_v = "$major.$minor.$micro";
                                next if $seen_versions{$full_v};
                                $seen_versions{$full_v} = 1;

                                # Format: version;major;minor;micro;CVE-ID;Status;Description
                                # MySQLTuner format: $cve[1].$cve[2].$cve[3]
                                print $out_fh "$full_v;$major;$minor;$micro;$cve_id;$status;$description\n";
                            }
                        }
                    }
                }
            }
        }

        $start_index += $RESULTS_PER_PAGE;
        if ($start_index < $total_results) {
            print "  Waiting $DELAY_SECONDS seconds before next page...\n";
            sleep($DELAY_SECONDS);
        }
    }
}

close($out_fh);
print "Done! Output saved to $OUTPUT_FILE\n";
exit(0);
