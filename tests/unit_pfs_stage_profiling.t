#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_pfs_stage_profiling.t
# Description: Validates Performance Schema stage and wait event profiling (Phase 31).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 4;

my $script = File::Spec->catfile( $FindBin::Bin, '..', 'mysqltuner.pl' );
require $script;

# --- Subtest 1: Empty / Clean Profiling Data ---
subtest 'Clean / Low Latency Baseline' => sub {
    plan tests => 1;

    my %stages = (
        'stage/sql/Creating tmp table' => { count => 10, latency_ms => 50 },
        'stage/sql/Sorting result'     => { count => 20, latency_ms => 100 },
    );
    my %waits = (
        'wait/synch/mutex/innodb/buf_pool_mutex' => { count => 50, latency_ms => 120 },
    );

    my @findings = main::audit_pfs_stage_profiling( \%stages, \%waits );
    is( scalar(@findings), 0, "No warnings triggered under low latency baseline" );
};

# --- Subtest 2: High Temp Table & Sorting Stage Bottlenecks ---
subtest 'Stage Bottlenecks Detection' => sub {
    plan tests => 3;

    my %stages = (
        'stage/sql/Creating tmp table' => { count => 2500, latency_ms => 12000 },
        'stage/sql/Sorting result'     => { count => 8000, latency_ms => 25000 },
    );

    my @findings = main::audit_pfs_stage_profiling( \%stages, {} );
    is( scalar(@findings), 2, "Detected 2 stage bottlenecks" );
    like( $findings[0]->{message}, qr/temporary table creation stage latency/, "Temporary table bottleneck identified" );
    like( $findings[1]->{message}, qr/High sorting stage latency/, "Sorting bottleneck identified" );
};

# --- Subtest 3: Mutex Contention & File IO Wait Latency ---
subtest 'Wait Events & Mutex Contention' => sub {
    plan tests => 3;

    my %waits = (
        'wait/synch/mutex/innodb/buf_pool_mutex'           => { count => 50000, latency_ms => 18500 },
        'wait/io/file/innodb/innodb_data_file'            => { count => 12000, latency_ms => 62000 },
    );

    my @findings = main::audit_pfs_stage_profiling( {}, \%waits );
    is( scalar(@findings), 2, "Detected 2 wait contention anomalies" );
    ok( ( grep { $_->{message} =~ /InnoDB mutex contention detected/ } @findings ), "Buffer pool mutex contention identified" );
    ok( ( grep { $_->{message} =~ /High InnoDB data file IO wait latency/ } @findings ), "Data file IO wait identified" );
};

# --- Subtest 4: Script Compilation & Syntax ---
subtest 'Script Compilation & Syntax' => sub {
    plan tests => 1;

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "mysqltuner.pl compiles cleanly" );
};

done_testing();
