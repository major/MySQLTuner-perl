use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

# Mock global variables
our %myvar;
our %mystat;
our @generalrec;

subtest 'mariadb_galera' => sub {
    no warnings 'redefine';
    my @info_prints;
    my @good_prints;
    my @bad_prints;
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::subheaderprint = sub { };
    local *main::get_wsrep_options = sub { return () };
    local *main::get_wsrep_option = sub { return 0 };
    local *main::cpu_cores = sub { 4 };

    # Case 1: Galera enabled
    %main::myvar = (
        'have_galera' => 'YES',
        'wsrep_on' => 'ON',
        'wsrep_cluster_name' => 'my_cluster',
        'wsrep_provider_vendor' => 'Codership'
    );
    %main::mystat = (
        'wsrep_local_state_comment' => 'Synced',
        'wsrep_cluster_size' => 3
    );
    @main::generalrec = ();
    
    main::mariadb_galera();
    ok(grep(/Galera is enabled/, @info_prints), "Detects Galera info");
};

subtest 'mariadb_threadpool' => sub {
    no warnings 'redefine';
    my @info_prints;
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::subheaderprint = sub { };
    local *main::logical_cpu_cores = sub { 8 };

    # Case 1: Thread pool enabled
    %main::myvar = (
        'version' => '10.5.0-MariaDB',
        'thread_handling' => 'pool-of-threads',
        'thread_pool_size' => 8,
        'thread_pool_max_threads' => 1000,
        'Max_used_connections' => 600
    );
    %main::mystat = (
        'Max_used_connections' => 600
    );
    main::mariadb_threadpool();
    ok(grep(/ThreadPool stat is enabled/, @info_prints), "Detects thread pool enabled");
    ok(grep(/Thread Pool Size: 8/, @info_prints), "Detects thread pool size");
};

subtest 'mariadb_aria' => sub {
    no warnings 'redefine';
    my @info_prints;
    my @good_prints;
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::badprint = sub { };
    local *main::subheaderprint = sub { };

    %main::myvar = (
        'have_aria' => 'YES',
        'aria_pagecache_buffer_size' => 128 * 1024 * 1024
    );
    %main::mystat = (
        'Aria_pagecache_blocks_unused' => 1000,
        'Aria_pagecache_read_requests' => 10000,
        'Aria_pagecache_reads' => 100
    );
    %main::mycalc = (
        'total_aria_indexes' => 64 * 1024 * 1024,
        'pct_aria_pagecache_used' => 50,
        'pct_aria_keys_from_mem' => 99
    );
    
    main::mariadb_aria();
    ok(grep(/Aria Storage Engine is enabled/, @info_prints), "Detects Aria enabled");
    ok(grep(/Aria pagecache size \/ total Aria indexes/, @good_prints), "Detects Aria metrics in goodprint");
};

done_testing();
