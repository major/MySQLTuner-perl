#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';
use JSON;

# Override exit to catch exit in dump_result
BEGIN {
    *CORE::GLOBAL::exit = sub { die "EXIT_CALLED\n" };
}

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

subtest 'Issue 6A: clean_tuning_value strips comments and extracts clean target value' => sub {
    plan tests => 11;

    # 1. Trailing # comment
    is(main::clean_tuning_value('150 # increase pool'), '150', 'Strips trailing # comment');

    # 2. Trailing -- comment
    is(main::clean_tuning_value('ROW -- binary format'), 'ROW', 'Strips trailing -- comment');

    # 3. Trailing /* ... */ comment
    is(main::clean_tuning_value('1024 /* buffer size */'), '1024', 'Strips C-style block comment');

    # 4. Trailing parenthetical recommendation
    is(main::clean_tuning_value('0 (Recommended for SSD/NVMe)'), '0', 'Strips trailing parenthetical note');

    # 5. Explanatory text after parenthesized value
    is(main::clean_tuning_value('(>= 2000) for SSD/NVMe storage'), '2000', 'Strips trailing note after parenthesized value');

    # 6. Comma-separated comment inside parentheses
    is(main::clean_tuning_value('(> 256.0K, or always use indexes with JOINs)'), '256.0K', 'Strips comment inside parentheses');

    # 7. Start-at prefix in parentheses
    is(main::clean_tuning_value('(start at 4)'), '4', 'Strips start at prefix in parentheses');

    # 8. Standard parenthesized value
    is(main::clean_tuning_value('(>= 1G)'), '1G', 'Extracts clean value from (>= 1G)');

    # 9. Comma-separated comment when leading parenthesis consumed
    is(main::clean_tuning_value('256.0K, always use indexes with JOINs)'), '256.0K', 'Strips comma comment without leading paren');

    # 10. Start-at phrase when leading parenthesis consumed
    is(main::clean_tuning_value('start at 4)'), '4', 'Strips start at phrase without leading paren');

    # 11. Explanatory text when leading parenthesis consumed
    is(main::clean_tuning_value('2000) for SSD/NVMe storage'), '2000', 'Strips trailing note without leading paren');
};

subtest 'Issue 6B: generate_auto_fix_snippets handles static variables, sysctl dots, and comments' => sub {
    plan tests => 17;

    @main::adjvars = (
        'max_connections = 500',
        'performance_schema=ON',
        'innodb_file_per_table = ON',
        'innodb_log_file_size = 512M',
        'innodb_buffer_pool_instances = 8',
        'lower_case_table_names = 1',
        'vm.swappiness = 10',
        'fs.file-max = 65536',
        'innodb_flush_neighbors = 0 (Recommended for SSD/NVMe)',
        'sort_buffer_size = 2M # session buffer',
        'join_buffer_size (> 256.0K, always use indexes with JOINs)',
        'thread_cache_size (start at 4)',
        'innodb_io_capacity (>= 2000) for SSD/NVMe storage',
        'query_cache_size = 0 (Deprecated in 8.0)'
    );

    %main::opt = (
        'silent'     => 0,
        'json'       => 0,
        'yaml'       => 0,
        'agent-json' => 0,
    );

    # Capture stdout
    my $output = '';
    open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$output or die "Can't redirect STDOUT: $!";

    main::generate_auto_fix_snippets();

    close STDOUT;
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";

    # Dynamic variables should emit SET GLOBAL
    like($output, qr/SET GLOBAL max_connections = 500;/, 'Dynamic max_connections emitted via SET GLOBAL');
    like($output, qr/SET GLOBAL innodb_flush_neighbors = 0;/, 'Comment stripped from innodb_flush_neighbors');
    like($output, qr/SET GLOBAL sort_buffer_size = 2097152;/, 'Comment stripped and converted to bytes for sort_buffer_size');

    # Static variables must NOT emit SET GLOBAL
    unlike($output, qr/SET GLOBAL performance_schema/, 'Static performance_schema not emitted as SET GLOBAL');
    unlike($output, qr/SET GLOBAL innodb_file_per_table/, 'Static innodb_file_per_table not emitted as SET GLOBAL');
    unlike($output, qr/SET GLOBAL innodb_log_file_size/, 'Static innodb_log_file_size not emitted as SET GLOBAL');

    # Static variables must emit # my.cnf: directives
    like($output, qr/# my\.cnf:\s*performance_schema\s*=\s*ON/, 'Static performance_schema emitted as # my.cnf directive');
    like($output, qr/# my\.cnf:\s*innodb_file_per_table\s*=\s*ON/, 'Static innodb_file_per_table emitted as # my.cnf directive');
    like($output, qr/# my\.cnf:\s*innodb_log_file_size\s*=\s*512M/, 'Static innodb_log_file_size emitted as # my.cnf directive');

    # Sysctl dot keys must be excluded from SET GLOBAL
    unlike($output, qr/SET GLOBAL vm\.swappiness/, 'Sysctl key vm.swappiness excluded from SET GLOBAL');

    # Verify real-world memory and advice recommendations in SQL snippets
    like($output, qr/SET GLOBAL join_buffer_size = 262144;/, 'join_buffer_size with decimal K and comma-comment emitted as bytes');
    like($output, qr/SET GLOBAL thread_cache_size = 4;/, 'thread_cache_size (start at 4) emitted as 4');
    like($output, qr/SET GLOBAL innodb_io_capacity = 2000;/, 'innodb_io_capacity (>= 2000) for SSD/NVMe storage emitted as 2000');
    like($output, qr/SET GLOBAL query_cache_size = 0;/, 'query_cache_size with version string comment emitted as 0');

    # Verify [mysqld] configuration block directives
    like($output, qr/^\s{4}join_buffer_size = 256\.0K$/m, 'join_buffer_size present in [mysqld] section');
    like($output, qr/^\s{4}thread_cache_size = 4$/m, 'thread_cache_size present in [mysqld] section');
    like($output, qr/^\s{4}innodb_io_capacity = 2000$/m, 'innodb_io_capacity present in [mysqld] section');
};

subtest 'Issue 6C: dump_result (--agent-json) restart classification and value cleaning' => sub {
    plan tests => 33;

    @main::adjvars = (
        'max_connections = 300',
        'performance_schema = ON',
        'innodb_file_per_table = 1',
        'innodb_log_file_size = 512M',
        'innodb_buffer_pool_instances = 4',
        'lower_case_table_names = 2',
        'vm.swappiness = 10',
        'innodb_flush_neighbors = 0 (Recommended for SSD/NVMe)',
        'sort_buffer_size = 4M # allocate per session',
        'join_buffer_size (> 256.0K, always use indexes with JOINs)',
        'thread_cache_size (start at 4)',
        'innodb_io_capacity (>= 2000) for SSD/NVMe storage',
    );

    %main::myvar = (
        'max_connections'              => '151',
        'performance_schema'           => 'OFF',
        'innodb_file_per_table'        => '0',
        'innodb_log_file_size'         => '268435456',
        'innodb_buffer_pool_instances' => '1',
        'lower_case_table_names'       => '0',
        'innodb_flush_neighbors'       => '1',
        'sort_buffer_size'             => '2097152',
        'join_buffer_size'             => '131072',
        'thread_cache_size'            => '0',
        'innodb_io_capacity'           => '200',
    );

    %main::opt = (
        'agent-json' => 1
    );

    my $stdout_content = '';
    open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$stdout_content or die "Can't redirect STDOUT: $!";

    eval { main::dump_result(); };
    my $err = $@;

    close STDOUT;
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";

    like($err, qr/EXIT_CALLED/, 'dump_result exited via exit 0');

    my $data = eval { decode_json($stdout_content) };
    ok(defined $data, 'Stdout is valid JSON');
    ok(exists $data->{findings}, 'JSON contains findings array');

    my %findings_by_id = map { $_->{id} => $_ } @{ $data->{findings} };

    # 1. max_connections (dynamic)
    ok(exists $findings_by_id{'max_connections_adjust'}, 'Found max_connections finding');
    is($findings_by_id{'max_connections_adjust'}->{requires_restart}, JSON::false, 'max_connections does not require restart');
    is($findings_by_id{'max_connections_adjust'}->{action}->{type}, 'SQL', 'max_connections action type is SQL');
    is($findings_by_id{'max_connections_adjust'}->{action}->{statement}, 'SET GLOBAL max_connections = 300;', 'Correct SET GLOBAL for max_connections');

    # 2. performance_schema (static)
    ok(exists $findings_by_id{'performance_schema_enable'}, 'Found performance_schema finding');
    is($findings_by_id{'performance_schema_enable'}->{requires_restart}, JSON::true, 'performance_schema requires restart');
    is($findings_by_id{'performance_schema_enable'}->{action}->{type}, 'Config', 'performance_schema action type is Config');
    is($findings_by_id{'performance_schema_enable'}->{action}->{statement}, 'performance_schema = ON', 'performance_schema config statement');

    # 3. innodb_file_per_table (static)
    ok(exists $findings_by_id{'innodb_file_per_table_enable'}, 'Found innodb_file_per_table finding');
    is($findings_by_id{'innodb_file_per_table_enable'}->{requires_restart}, JSON::true, 'innodb_file_per_table requires restart');
    is($findings_by_id{'innodb_file_per_table_enable'}->{action}->{type}, 'Config', 'innodb_file_per_table action type is Config');

    # 4. innodb_log_file_size (static)
    ok(exists $findings_by_id{'innodb_log_file_size_adjust'}, 'Found innodb_log_file_size finding');
    is($findings_by_id{'innodb_log_file_size_adjust'}->{requires_restart}, JSON::true, 'innodb_log_file_size requires restart');
    is($findings_by_id{'innodb_log_file_size_adjust'}->{action}->{type}, 'Config', 'innodb_log_file_size action type is Config');

    # 5. innodb_buffer_pool_instances (static)
    ok(exists $findings_by_id{'innodb_buffer_pool_instances_adjust'}, 'Found innodb_buffer_pool_instances finding');
    is($findings_by_id{'innodb_buffer_pool_instances_adjust'}->{requires_restart}, JSON::true, 'innodb_buffer_pool_instances requires restart');

    # 6. lower_case_table_names (static)
    ok(exists $findings_by_id{'lower_case_table_names_adjust'}, 'Found lower_case_table_names finding');
    is($findings_by_id{'lower_case_table_names_adjust'}->{requires_restart}, JSON::true, 'lower_case_table_names requires restart');

    # 7. Comment stripping in action statement
    ok(exists $findings_by_id{'innodb_flush_neighbors_adjust'}, 'Found innodb_flush_neighbors finding');
    is($findings_by_id{'innodb_flush_neighbors_adjust'}->{action}->{statement}, 'SET GLOBAL innodb_flush_neighbors = 0;', 'Comment stripped from action statement');

    # 8. Sysctl dot key excluded
    ok(!exists $findings_by_id{'vm.swappiness_adjust'}, 'Sysctl key vm.swappiness excluded from agent-json findings');

    # 9. join_buffer_size (dynamic with decimal K)
    ok(exists $findings_by_id{'join_buffer_size_adjust'}, 'Found join_buffer_size finding');
    is($findings_by_id{'join_buffer_size_adjust'}->{requires_restart}, JSON::false, 'join_buffer_size does not require restart');
    is($findings_by_id{'join_buffer_size_adjust'}->{action}->{type}, 'SQL', 'join_buffer_size action type is SQL');
    is($findings_by_id{'join_buffer_size_adjust'}->{action}->{statement}, 'SET GLOBAL join_buffer_size = 262144;', 'join_buffer_size SET GLOBAL format');
    is($findings_by_id{'join_buffer_size_adjust'}->{action}->{rollback_statement}, 'SET GLOBAL join_buffer_size = 131072;', 'join_buffer_size rollback format');

    # 10. thread_cache_size (start at 4)
    ok(exists $findings_by_id{'thread_cache_size_adjust'}, 'Found thread_cache_size finding');
    is($findings_by_id{'thread_cache_size_adjust'}->{action}->{statement}, 'SET GLOBAL thread_cache_size = 4;', 'thread_cache_size extracted as 4 in agent-json');

    # 11. innodb_io_capacity (>= 2000) for SSD/NVMe storage
    ok(exists $findings_by_id{'innodb_io_capacity_adjust'}, 'Found innodb_io_capacity finding');
    is($findings_by_id{'innodb_io_capacity_adjust'}->{action}->{statement}, 'SET GLOBAL innodb_io_capacity = 2000;', 'innodb_io_capacity extracted as 2000 in agent-json');
};

done_testing();
