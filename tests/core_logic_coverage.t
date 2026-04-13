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
our %mycalc;
our @generalrec;
our @adjvars;

subtest 'mysql_innodb' => sub {
    no warnings 'redefine';
    my @info_prints;
    my @good_prints;
    my @bad_prints;
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::subheaderprint = sub { };
    local *main::execute_system_command = sub { return "" };
    local *main::debugprint = sub { };

    # Case 1: InnoDB enabled with good metrics
    %main::myvar = (
        'version' => '8.0.30',
        'version_comment' => 'MySQL Community Server (GPL)',
        'have_innodb' => 'YES',
        'innodb_buffer_pool_size' => 1024 * 1024 * 1024,
        'innodb_log_file_size' => 256 * 1024 * 1024,
        'innodb_log_files_in_group' => 2,
        'innodb_flush_log_at_trx_commit' => 1,
        'innodb_buffer_pool_instances' => 8,
        'max_connections' => 151
    );
    %main::mystat = (
        'Innodb_buffer_pool_pages_total' => 65536,
        'Innodb_buffer_pool_pages_free' => 10000,
        'Innodb_buffer_pool_read_requests' => 1000000,
        'Innodb_buffer_pool_reads' => 100,
        'Innodb_os_log_pending_writes' => 0,
        'Innodb_os_log_pending_fsyncs' => 0,
        'Innodb_log_waits' => 0,
        'Innodb_log_write_requests' => 1000,
        'Innodb_log_writes' => 100
    );
    %main::mycalc = (
        'total_innodb_indexes' => 512 * 1024 * 1024,
        'pct_innodb_buffer_pool_used' => 80,
        'pct_innodb_buffer_pool_hit_rate' => 99.9,
        'innodb_log_file_size_total' => 512 * 1024 * 1024,
        'pct_innodb_keys_from_mem' => 99.9
    );
    @main::generalrec = ();
    @main::adjvars = ();

    main::mysql_innodb();
    ok(grep(/InnoDB is enabled/, @info_prints), "Detects InnoDB enabled");
    ok(grep(/InnoDB buffer pool /, @good_prints), "Detects buffer pool hit rate in goodprint");
};

subtest 'mysql_stats' => sub {
    no warnings 'redefine';
    my @info_prints;
    my @good_prints;
    my @bad_prints;
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::subheaderprint = sub { };
    local *main::execute_system_command = sub { return "" };

    %main::myvar = (
        'version' => '8.0.30',
        'max_connections' => 151,
        'key_buffer_size' => 16 * 1024 * 1024,
        'query_cache_size' => 0,
        'innodb_buffer_pool_size' => 128 * 1024 * 1024,
        'innodb_additional_mem_pool_size' => 0,
        'innodb_log_buffer_size' => 8 * 1024 * 1024,
        'max_allowed_packet' => 16 * 1024 * 1024,
        'read_buffer_size' => 128 * 1024,
        'read_rnd_buffer_size' => 256 * 1024,
        'sort_buffer_size' => 256 * 1024,
        'join_buffer_size' => 256 * 1024,
        'thread_stack' => 256 * 1024,
        'binlog_cache_size' => 32 * 1024,
        'tmp_table_size' => 16 * 1024 * 1024,
        'max_heap_table_size' => 16 * 1024 * 1024
    );
    %main::mystat = (
        'Max_used_connections' => 10,
        'Threads_connected' => 5,
        'Uptime' => 86400
    );
    %main::mycalc = (
        'total_mysql_memory' => 512 * 1024 * 1024,
        'pct_physical_memory' => 50
    );

    main::mysql_stats();
    ok(grep(/Maximum possible memory usage/, @info_prints) || grep(/Maximum possible memory usage/, @good_prints), "Calculates max possible memory usage");
};

subtest 'mysql_myisam' => sub {
    no warnings 'redefine';
    my @info_prints;
    my @good_prints;
    my @bad_prints;
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::subheaderprint = sub { };
    local *main::execute_system_command = sub { return "" };
    local *main::select_one = sub { return 1 };
    local *main::select_array = sub { return () };
    local %main::opt = ( 'myisamstat' => 1 );

    %main::myvar = (
        'version' => '5.7.35',
        'key_buffer_size' => 128 * 1024 * 1024,
        'key_cache_block_size' => 1024,
        'concurrent_insert' => 'ALWAYS'
    );
    %main::mystat = (
        'Key_blocks_unused' => 1000,
        'Key_read_requests' => 10000,
        'Key_reads' => 100,
        'Key_write_requests' => 5000,
        'Key_writes' => 50
    );
    %main::mycalc = (
        'total_myisam_indexes' => 64 * 1024 * 1024,
        'pct_key_buffer_used' => 50,
        'pct_keys_from_mem' => 99,
        'pct_wkeys_from_mem' => 99
    );

    main::mysql_myisam();
    ok(grep(/Key buffer used/, @good_prints) || grep(/Key buffer used/, @bad_prints) || grep(/Key buffer used/, @info_prints), "Detects MyISAM metrics");
};

subtest 'mysql_query_cache' => sub {
    no warnings 'redefine';
    my @info_prints;
    my @good_prints;
    my @bad_prints;
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::subheaderprint = sub { };
    local *main::execute_system_command = sub { return "" };

    %main::myvar = (
        'version' => '5.7.35',
        'query_cache_size' => 64 * 1024 * 1024,
        'query_cache_type' => 'ON',
        'query_cache_limit' => 1024 * 1024
    );
    %main::mystat = (
        'Uptime' => 86400,
        'Qcache_free_memory' => 32 * 1024 * 1024,
        'Qcache_hits' => 1000,
        'Qcache_inserts' => 500,
        'Qcache_lowmem_prunes' => 10,
        'Com_select' => 1500
    );
    %main::mycalc = (
        'query_cache_efficiency' => 40,
        'query_cache_prunes_per_day' => 5
    );

    main::mysql_stats();
    ok(grep(/Query cache efficiency/, @good_prints) || grep(/Query cache efficiency/, @bad_prints) || grep(/Query cache efficiency/, @info_prints), "Detects Query Cache metrics");
};

done_testing();
