#!/usr/bin/env perl
# ===========================================================================
# Test:        pod_cli_sync.t
# Description: Validates 1-to-1 correspondence between %CLI_METADATA and POD
#              documentation in mysqltuner.pl, preventing phantom options
#              and ensuring all supported CLI options are documented.
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

my $script_path = $ENV{MYSQLTUNER_SCRIPT_PATH} || File::Spec->catfile( $FindBin::Bin, '..', 'mysqltuner.pl' );
plan skip_all => "Cannot find mysqltuner.pl at $script_path" unless -f $script_path;

open my $fh, '<', $script_path or die "Could not open $script_path: $!";
my $content = do { local $/; <$fh> };
close $fh;

my %valid_cli_options;
my %primary_options;
my %option_categories;

subtest 'Extract %CLI_METADATA from mysqltuner.pl' => sub {
    ok( $content =~ /our\s+%CLI_METADATA\s*=\s*\((.*?)\n\);/s, 'Found our %CLI_METADATA block in mysqltuner.pl' );
    my $block = $1 // '';

    while ( $block =~ /^\s*['"]([^'"]+)['"]\s*=>\s*\{([^}]*)\}/msg ) {
        my $spec = $1;
        my $body = $2;

        my @parts = split /\|/, $spec;
        my $primary = $parts[0];
        my $is_negatable = ( $primary =~ /!/ || $body =~ /type\s*=>\s*['"]!['"]/ );
        $primary =~ s/[!+=:].*$//;

        $primary_options{$primary} = 1;

        if ( $body =~ /cat\s*=>\s*['"]([^'"]+)['"]/ ) {
            $option_categories{$primary} = $1;
        }

        for my $opt (@parts) {
            $opt =~ s/[!+=:].*$//;
            $valid_cli_options{$opt} = 1;
            if ($is_negatable) {
                $valid_cli_options{"no$opt"} = 1;
                $valid_cli_options{"no-$opt"} = 1;
            }
        }
    }

    cmp_ok( scalar keys %primary_options, '>=', 70, 'Extracted >= 70 primary options from %CLI_METADATA' );
    is( scalar keys %primary_options, 77, 'Found exactly 77 primary options in %CLI_METADATA' );
};

my %pod_options;
my %pod_duplicates;
my %pod_item_lines;

subtest 'Extract OPTIONS section from POD' => sub {
    ok( $content =~ /=head1\s+OPTIONS\s*\n(.*?)(?=\n=head1|\z)/s, 'Found =head1 OPTIONS in POD' );
    my $pod_options_text = $1 // '';

    while ( $pod_options_text =~ /=item\s+(.+)$/mg ) {
        my $item_line = $1;
        my @opts_in_item;
        while ( $item_line =~ /B<--([a-zA-Z0-9_\-]+)>/g ) {
            my $opt = $1;
            push @opts_in_item, $opt;
            if ( exists $pod_options{$opt} ) {
                $pod_duplicates{$opt}++;
            }
            $pod_options{$opt} = 1;
            $pod_item_lines{$opt} = $item_line;
        }
    }

    cmp_ok( scalar keys %pod_options, '>=', 70, 'Extracted >= 70 documented options in POD' );
    is_deeply( [ sort keys %pod_duplicates ], [], 'No duplicate option items found in POD' );
};

my @phantom;

subtest 'Verify no phantom options in POD' => sub {
    @phantom = sort grep { !exists $valid_cli_options{$_} } keys %pod_options;
    is_deeply( \@phantom, [], 'All options documented in POD exist in %CLI_METADATA' )
      or diag( 'Phantom options in POD: ' . join( ', ', @phantom ) );
};

my @missing;

subtest 'Verify all primary %CLI_METADATA options are documented in POD' => sub {
    for my $opt ( sort keys %primary_options ) {
        unless ( $pod_options{$opt} || $pod_options{"no$opt"} || ( $opt eq 'pass' && $pod_options{'password'} ) ) {
            push @missing, $opt;
        }
    }
    is_deeply( \@missing, [], 'All primary %CLI_METADATA options are documented in POD' )
      or diag( 'Missing in POD: ' . join( ', ', @missing ) );
};

subtest 'Verify 1-to-1 sync and option categorization' => sub {
    is( scalar @phantom, 0, 'Zero phantom options' );
    is( scalar @missing, 0, 'Zero missing options' );
    ok( scalar keys %primary_options >= 76, 'All primary options synchronized' );

    # Ensure critical previously phantom options are strictly absent
    my @banned_phantoms = (
        'ask-pass', 'tli', 'caching-sha2-password', 'ssh-key', 'ssh-port',
        'aws-profile', 'aws-region', 'aws-cluster-identifier', 'aws-instance-identifier',
        'gcp-project', 'gcp-instance', 'azure-resource-group', 'azure-server-name'
    );
    my @resurrected = grep { exists $pod_options{$_} } @banned_phantoms;
    is_deeply( \@resurrected, [], 'None of the 13 legacy phantom options exist in POD' );
};

done_testing();
