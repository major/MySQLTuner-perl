use strict;
use warnings;
use Test::More;

# Mocking variables and functions from mysqltuner.pl
our %myvar;
our %mystat;
our %mycalc;
our @adjvars;
our @generalrec;

sub subheaderprint { }
sub infoprint { }
sub badprint { }
sub goodprint { }
sub debugprint { }
sub hr_bytes { return $_[0]; }
sub hr_num { return $_[0]; }

# Mocked cpu_cores
our $mock_cpu_cores = 12;
sub cpu_cores { return $mock_cpu_cores; }

# Improved logic from mysqltuner.pl (proposed)
sub mariadb_threadpool_new {
    my $is_mariadb = ( ($myvar{'version'} // '') =~ /mariadb/i );
    my $is_percona = ( ($myvar{'version'} // '') =~ /percona/i or ($myvar{'version_comment'} // '') =~ /percona/i );

    return unless ($is_mariadb or $is_percona);

    my $thread_handling = $myvar{'thread_handling'} // 'one-thread-per-connection';
    my $is_threadpool_enabled = ( $thread_handling eq 'pool-of-threads' );

    # Recommendation to ENABLE thread pool
    if (!$is_threadpool_enabled && ($mystat{'Max_used_connections'} // 0) >= 512) {
        push(@generalrec, "Enabling the thread pool is recommended for servers with max_connections >= 512");
        push(@adjvars, "thread_handling=pool-of-threads");
    }

    # If it IS enabled, show metrics and recommendations
    if ($is_threadpool_enabled) {
        if (($mystat{'Max_used_connections'} // 0) < 512) {
            push(@generalrec, "Thread pool is usually only efficient for servers with max_connections >= 512");
        }

        my $np = cpu_cores();
        return if $np <= 0; # Avoid division by zero or weirdness
        
        my $min_tps = $np;
        my $max_tps = int($np * 1.5);

        if ($myvar{'thread_pool_size'} < $min_tps or $myvar{'thread_pool_size'} > $max_tps) {
            push(@adjvars, "thread_pool_size between $min_tps and $max_tps");
        }
    }
}

# Test Case 1: Percona, ThreadPool DISABLED, but Max Connections High
%myvar = (
    version => '5.7.23-23-percona',
    thread_handling => 'one-thread-per-connection',
    max_connections => 1000
);
%mystat = ( Max_used_connections => 600 );
@adjvars = (); @generalrec = ();
mariadb_threadpool_new();
ok(grep(/thread_handling=pool-of-threads/, @adjvars), "Should suggest enabling thread pool if Max_used_connections >= 512");

# Test Case 2: MariaDB, ThreadPool ENABLED, but Size Wrong (too low)
%myvar = (
    version => '10.3.10-MariaDB',
    thread_handling => 'pool-of-threads',
    thread_pool_size => 8
);
%mystat = ( Max_used_connections => 600 );
$mock_cpu_cores = 12;
@adjvars = (); @generalrec = ();
mariadb_threadpool_new();
ok(grep(/thread_pool_size between 12 and 18/, @adjvars), "Should suggest increasing thread_pool_size to match CPUs (12-18)");

# Test Case 3: MariaDB, ThreadPool ENABLED, but Size Wrong (too high)
%myvar = (
    version => '10.3.10-MariaDB',
    thread_handling => 'pool-of-threads',
    thread_pool_size => 40
);
%mystat = ( Max_used_connections => 600 );
$mock_cpu_cores = 16;
@adjvars = (); @generalrec = ();
mariadb_threadpool_new();
ok(grep(/thread_pool_size between 16 and 24/, @adjvars), "Should suggest decreasing thread_pool_size to match CPUs (16-24)");

# Test Case 4: ThreadPool ENABLED but Max Connections Low
%myvar = (
    version => '10.3.10-MariaDB',
    thread_handling => 'pool-of-threads',
    thread_pool_size => 16
);
%mystat = ( Max_used_connections => 100 );
$mock_cpu_cores = 16;
@adjvars = (); @generalrec = ();
mariadb_threadpool_new();
ok(grep(/Thread pool is usually only efficient for servers with max_connections >= 512/, @generalrec), "Should warn if thread pool is enabled for low connection count");

# Test Case 5: Not MariaDB/Percona (Standard MySQL)
%myvar = (
    version => '8.0.21',
    thread_handling => 'one-thread-per-connection',
);
%mystat = ( Max_used_connections => 600 );
@adjvars = (); @generalrec = ();
mariadb_threadpool_new();
is(scalar @adjvars, 0, "Should NOT suggest thread pool for standard MySQL (community doesn't have it)");

done_testing();
