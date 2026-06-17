use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Load mysqltuner.pl as a library
my $script_dir = dirname( abs_path(__FILE__) );
my $script = abs_path( File::Spec->catfile( $script_dir, '..', 'mysqltuner.pl' ) );
require $script;
require './tests/MySQLTuner/TestHelper.pm';

subtest 'Issue #927: MariaDB query cache efficiency uses correct formula' => sub {
    no warnings 'redefine';
    local *main::infoprint    = sub { };
    local *main::goodprint    = sub { };
    local *main::badprint     = sub { };
    local *main::subheaderprint = sub { };
    local *main::debugprint   = sub { };
    local *main::select_one   = sub { return 0 };
    local *main::select_array = sub { return () };
    local *main::execute_system_command = sub { return "" };
    local *main::get_pf_memory  = sub { return 0 };
    local *main::get_gcache_memory = sub { return 0 };
    local *main::is_remote      = sub () { return 0 };
    local *main::mysql_cloud_discovery = sub { return "none" };

    # Use stats from the issue report: MariaDB 10.11 where
    # Com_select = Qcache_hits + Qcache_inserts + Qcache_not_cached
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = (
        %main::myvar,
        'version'          => '10.11.14-MariaDB',
        'query_cache_size' => 33554432,
        'query_cache_type' => 'ON',
        'read_buffer_size' => 1024,
        'read_rnd_buffer_size' => 1024,
        'sort_buffer_size' => 1024,
        'thread_stack'     => 1024,
        'join_buffer_size' => 1024,
        'binlog_cache_size' => 1024,
        'tmp_table_size'   => 1024,
        'max_heap_table_size' => 2048,
        'max_connections'  => 10,
    );
    %main::mystat = (
        %main::mystat,
        'Com_select'          => 454794,
        'Qcache_hits'         => 383668,
        'Qcache_free_memory'  => 512,
        'Qcache_lowmem_prunes' => 0,
        'Questions'           => 454794,
        'Uptime'              => 86400,
    );
    local %main::mycalc = ( %main::mycalc );

    eval { main::calculations(); };
    if ($@) {
        fail("calculations() crashed: $@");
    }
    else {
        # MariaDB: efficiency = Qcache_hits / Com_select * 100
        # 383668 / 454794 * 100 = 84.4%
        my $expected = sprintf( "%.1f", ( 383668 / 454794 ) * 100 );
        is( $main::mycalc{'query_cache_efficiency'}, $expected,
            "MariaDB: query_cache_efficiency = Qcache_hits / Com_select (got $main::mycalc{'query_cache_efficiency'}%, expected $expected%)"
        );
        cmp_ok( $main::mycalc{'query_cache_efficiency'}, '>', 80,
            "MariaDB: efficiency correctly reported above 80% (not underreported as ~45%)" );
    }
};

subtest 'Issue #927: MySQL (non-MariaDB) query cache efficiency uses original formula' => sub {
    no warnings 'redefine';
    local *main::infoprint    = sub { };
    local *main::goodprint    = sub { };
    local *main::badprint     = sub { };
    local *main::subheaderprint = sub { };
    local *main::debugprint   = sub { };
    local *main::select_one   = sub { return 0 };
    local *main::select_array = sub { return () };
    local *main::execute_system_command = sub { return "" };
    local *main::get_pf_memory  = sub { return 0 };
    local *main::get_gcache_memory = sub { return 0 };
    local *main::is_remote      = sub () { return 0 };
    local *main::mysql_cloud_discovery = sub { return "none" };

    MySQLTuner::TestHelper::reset_state();
    %main::myvar = (
        %main::myvar,
        'version'          => '5.7.44-MySQL',
        'query_cache_size' => 33554432,
        'query_cache_type' => 'ON',
        'read_buffer_size' => 1024,
        'read_rnd_buffer_size' => 1024,
        'sort_buffer_size' => 1024,
        'thread_stack'     => 1024,
        'join_buffer_size' => 1024,
        'binlog_cache_size' => 1024,
        'tmp_table_size'   => 1024,
        'max_heap_table_size' => 2048,
        'max_connections'  => 10,
    );
    %main::mystat = (
        %main::mystat,
        'Com_select'          => 100,
        'Qcache_hits'         => 383668,
        'Qcache_free_memory'  => 512,
        'Qcache_lowmem_prunes' => 0,
        'Questions'           => 100,
        'Uptime'              => 86400,
    );
    local %main::mycalc = ( %main::mycalc );

    eval { main::calculations(); };
    if ($@) {
        fail("calculations() crashed: $@");
    }
    else {
        # MySQL: efficiency = Qcache_hits / (Com_select + Qcache_hits) * 100
        my $expected = sprintf( "%.1f", ( 383668 / ( 100 + 383668 ) ) * 100 );
        is( $main::mycalc{'query_cache_efficiency'}, $expected,
            "MySQL: query_cache_efficiency = Qcache_hits / (Com_select + Qcache_hits) (got $main::mycalc{'query_cache_efficiency'}%, expected $expected%)"
        );
    }
};

done_testing();
