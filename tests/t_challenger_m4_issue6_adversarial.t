#!/usr/bin/env perl
# tests/t_challenger_m4_issue6_adversarial.t
# Adversarial Empirical Challenge Suite specifically targeting Issue 6:
# Auto-fix snippet generation and --agent-json output with pathological values.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';
use JSON;

# Pre-declare required globals
our @generalrec;
our @adjvars;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;

# Intercept exit to catch exit(0) inside dump_result
BEGIN {
    *CORE::GLOBAL::exit = sub { die "EXIT_CALLED\n" };
}

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

my @captured_pretty;

sub reset_state {
    @captured_pretty    = ();
    @generalrec         = ();
    @adjvars            = ();
    %result             = ();
    %opt                = ();
    %myvar              = ();
    %mystat             = ();
    %mycalc             = ();
}

{
    no warnings 'redefine';
    *main::infoprint      = sub { };
    *main::prettyprint    = sub { push @captured_pretty, $_[0] };
    *main::subheaderprint = sub { };
}

# =====================================================================
# Challenge 1: Static Variable Invariants in generate_auto_fix_snippets
# =====================================================================
subtest 'Challenge 1: Static Variable Invariants in generate_auto_fix_snippets' => sub {
    reset_state();
    $opt{'silent'}     = 0;
    $opt{'json'}       = 0;
    $opt{'yaml'}       = 0;
    $opt{'agent-json'} = 0;

    my @static_vars = (
        'performance_schema = ON',
        'innodb_file_per_table = ON',
        'innodb_log_file_size = 512M',
        'innodb_buffer_pool_instances = 8',
        'lower_case_table_names = 1',
        'skip-name-resolve = ON',
        'skip_name_resolve = ON',
        'innodb_page_size = 64K',
        'ft_min_word_len = 3',
    );

    my @dynamic_vars = (
        'max_connections = 500',
        'sort_buffer_size = 4M',
        'read_buffer_size = 2M',
        'query_cache_size = 0',
        'long_query_time = 2',
        'tmp_table_size = 64M',
        'max_heap_table_size = 64M',
        'innodb_buffer_pool_size = 4G',
    );

    @adjvars = ( @static_vars, @dynamic_vars );

    main::generate_auto_fix_snippets();

    my $all_output = join("\n", @captured_pretty);

    for my $s (@static_vars) {
        $s =~ /^([a-zA-Z0-9_-]+)/;
        my $var = $1;
        unlike( $all_output, qr/SET\s+GLOBAL\s+$var\b/i,
            "Static variable '$var' must NOT be emitted as SET GLOBAL" );
        like( $all_output, qr/#\s*my\.cnf:\s*$var\s*=/i,
            "Static variable '$var' must be emitted as '# my.cnf: $var = ...'" );
    }

    for my $d (@dynamic_vars) {
        $d =~ /^([a-zA-Z0-9_-]+)/;
        my $var = $1;
        like( $all_output, qr/SET\s+GLOBAL\s+$var\s*=/i,
            "Dynamic variable '$var' must be emitted as SET GLOBAL" );
    }

    for my $all (@static_vars, @dynamic_vars) {
        $all =~ /^([a-zA-Z0-9_-]+)/;
        my $var = $1;
        like( $all_output, qr/^\s{4}$var\s*=/m,
            "Variable '$var' must appear in [mysqld] config section" );
    }
};

# =====================================================================
# Challenge 2: Real-World Pathological Value Extraction
# =====================================================================
subtest 'Challenge 2: Real-World Pathological Value Extraction in Snippets' => sub {
    reset_state();
    $opt{'silent'}     = 0;
    $opt{'json'}       = 0;
    $opt{'yaml'}       = 0;
    $opt{'agent-json'} = 0;

    # Exact strings pushed by mysqltuner.pl subroutines:
    @adjvars = (
        "innodb_flush_neighbors = 0 (Recommended for SSD/NVMe)",
        "innodb_buffer_pool_instances (<= 64)",
        "innodb_buffer_pool_instances (=1)",
        "long_query_time (<= 10)",
        "query_cache_size (=0)",
        "query_cache_size = 0 (Deprecated in 8.0)",
        "thread_cache_size (start at 4)",
        "innodb_io_capacity (>= 2000) for SSD/NVMe storage",
        "key_buffer_size=0",
        "binlog_format = ROW",
        "sort_buffer_size = 2M # session buffer",
        "read_rnd_buffer_size = 1M -- per thread buffer",
        "join_buffer_size = 512K /* per join */",
        "join_buffer_size (> 256.0K, always use indexes with JOINs)",
    );

    main::generate_auto_fix_snippets();

    my $all_output = join("\n", @captured_pretty);

    like( $all_output, qr/SET GLOBAL innodb_flush_neighbors = 0;/, 'innodb_flush_neighbors comment stripped' );
    like( $all_output, qr/# my\.cnf:\s*innodb_buffer_pool_instances = 64/, 'innodb_buffer_pool_instances (<= 64) extracted as 64' );
    like( $all_output, qr/# my\.cnf:\s*innodb_buffer_pool_instances = 1/, 'innodb_buffer_pool_instances (=1) extracted as 1' );
    like( $all_output, qr/SET GLOBAL long_query_time = 10;/, 'long_query_time (<= 10) extracted as 10' );
    like( $all_output, qr/SET GLOBAL query_cache_size = 0;/, 'query_cache_size (=0) extracted as 0' );
    like( $all_output, qr/SET GLOBAL thread_cache_size = 4;/, 'thread_cache_size (start at 4) extracted as 4' );
    like( $all_output, qr/SET GLOBAL innodb_io_capacity = 2000;/, 'innodb_io_capacity (>= 2000) for SSD/NVMe storage extracted as 2000' );
    like( $all_output, qr/SET GLOBAL key_buffer_size = 0;/, 'key_buffer_size=0 extracted' );
    like( $all_output, qr/SET GLOBAL binlog_format = (?:'ROW'|ROW);/, 'binlog_format = ROW extracted' );
    like( $all_output, qr/SET GLOBAL sort_buffer_size = 2097152;/, 'sort_buffer_size # stripped' );
    like( $all_output, qr/SET GLOBAL read_rnd_buffer_size = 1048576;/, 'read_rnd_buffer_size -- stripped' );
    like( $all_output, qr/SET GLOBAL join_buffer_size = 524288;/, 'join_buffer_size /* */ stripped' );
    like( $all_output, qr/SET GLOBAL join_buffer_size = 262144;/, 'join_buffer_size (> 256.0K, ...) extracted as 262144' );
    like( $all_output, qr/^\s{4}join_buffer_size = 256\.0K$/m, 'join_buffer_size = 256.0K present in [mysqld] section' );
};

# =====================================================================
# Challenge 3: Sysctl and Dot Keys Excluded from Auto-Fix and JSON
# =====================================================================
subtest 'Challenge 3: Sysctl Dot Keys Excluded from Auto-Fix and JSON' => sub {
    reset_state();
    $opt{'silent'}     = 0;
    $opt{'json'}       = 0;
    $opt{'yaml'}       = 0;
    $opt{'agent-json'} = 0;

    @adjvars = (
        'vm.swappiness = 10',
        'fs.file-max = 65536',
        'fs.aio-max-nr = 1048576',
        'net.core.somaxconn = 4096',
        'gcs.fc_limit = 16',
        'gcs.fc_factor = 0.8',
        'max_connections = 350',
    );

    main::generate_auto_fix_snippets();

    my $all_output = join("\n", @captured_pretty);

    unlike( $all_output, qr/vm\.swappiness/, 'vm.swappiness excluded from auto-fix' );
    unlike( $all_output, qr/fs\.file-max/, 'fs.file-max excluded from auto-fix' );
    unlike( $all_output, qr/fs\.aio-max-nr/, 'fs.aio-max-nr excluded from auto-fix' );
    unlike( $all_output, qr/net\.core\.somaxconn/, 'net.core.somaxconn excluded from auto-fix' );
    unlike( $all_output, qr/gcs\.fc_limit/, 'gcs.fc_limit excluded from auto-fix' );
    unlike( $all_output, qr/gcs\.fc_factor/, 'gcs.fc_factor excluded from auto-fix' );
    like( $all_output, qr/SET GLOBAL max_connections = 350;/, 'max_connections emitted' );

    # Now verify --agent-json
    reset_state();
    $opt{'agent-json'} = 1;
    @adjvars = (
        'vm.swappiness = 10',
        'fs.file-max = 65536',
        'gcs.fc_limit = 16',
        'max_connections = 350',
    );

    my $stdout_capture = '';
    open my $orig_stdout, ">&STDOUT" or die "Cannot dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$stdout_capture or die "Cannot redirect STDOUT: $!";
    eval { main::dump_result(); };
    close STDOUT;
    open STDOUT, ">&", $orig_stdout or die "Cannot restore STDOUT: $!";

    my $json_data = decode_json($stdout_capture);
    my @finding_ids = map { $_->{id} } @{ $json_data->{findings} };

    ok( !grep( /swappiness/, @finding_ids ), 'vm.swappiness excluded from agent-json findings' );
    ok( !grep( /file-max/, @finding_ids ), 'fs.file-max excluded from agent-json findings' );
    ok( !grep( /fc_limit/, @finding_ids ), 'gcs.fc_limit excluded from agent-json findings' );
    ok( grep( /^max_connections_adjust$/, @finding_ids ), 'max_connections present in agent-json' );
};

# =====================================================================
# Challenge 4: Agent JSON Schema and Static vs Dynamic Typing
# =====================================================================
subtest 'Challenge 4: Agent JSON Schema and Static vs Dynamic Typing' => sub {
    reset_state();
    $opt{'agent-json'} = 1;

    @adjvars = (
        'innodb_buffer_pool_instances = 8',
        'lower_case_table_names = 1',
        'skip-name-resolve = ON',
        'performance_schema = ON',
        'innodb_file_per_table = 1',
        'innodb_log_file_size = 512M',
        'innodb_page_size = 64K',
        'ft_min_word_len = 3',
        'max_connections = 400',
        'innodb_buffer_pool_size = 8G',
        'long_query_time (<= 1)',
        'query_cache_size = 0 (Deprecated in 8.0)',
        'thread_cache_size (start at 4)',
        'innodb_io_capacity (>= 2000) for SSD/NVMe storage',
        'join_buffer_size (> 256.0K, always use indexes with JOINs)',
    );

    %myvar = (
        'innodb_buffer_pool_instances' => '1',
        'lower_case_table_names'       => '0',
        'skip-name-resolve'            => 'OFF',
        'performance_schema'           => 'OFF',
        'innodb_file_per_table'        => '0',
        'innodb_log_file_size'         => '134217728',
        'innodb_page_size'             => '16384',
        'ft_min_word_len'              => '4',
        'max_connections'              => '151',
        'innodb_buffer_pool_size'      => '134217728',
        'long_query_time'              => '10.0',
        'query_cache_size'             => '16777216',
        'join_buffer_size'             => '131072',
    );

    my $stdout_capture = '';
    open my $orig_stdout, ">&STDOUT" or die "Cannot dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$stdout_capture or die "Cannot redirect STDOUT: $!";
    eval { main::dump_result(); };
    close STDOUT;
    open STDOUT, ">&", $orig_stdout or die "Cannot restore STDOUT: $!";

    my $decoded = decode_json($stdout_capture);
    ok( ref($decoded->{findings}) eq 'ARRAY', 'Findings is an array' );

    my %map = map { $_->{id} => $_ } @{ $decoded->{findings} };

    # 1. innodb_buffer_pool_instances
    is( $map{'innodb_buffer_pool_instances_adjust'}->{requires_restart}, JSON::true,
        'innodb_buffer_pool_instances requires restart' );
    is( $map{'innodb_buffer_pool_instances_adjust'}->{action}->{type}, 'Config',
        'innodb_buffer_pool_instances action type is Config' );
    is( $map{'innodb_buffer_pool_instances_adjust'}->{action}->{statement},
        'innodb_buffer_pool_instances = 8', 'innodb_buffer_pool_instances statement format' );
    is( $map{'innodb_buffer_pool_instances_adjust'}->{action}->{rollback_statement},
        'innodb_buffer_pool_instances = 1', 'innodb_buffer_pool_instances rollback statement format' );

    # 2. lower_case_table_names
    is( $map{'lower_case_table_names_adjust'}->{requires_restart}, JSON::true,
        'lower_case_table_names requires restart' );
    is( $map{'lower_case_table_names_adjust'}->{action}->{type}, 'Config',
        'lower_case_table_names action type is Config' );

    # 3. skip_name_resolve
    is( $map{'skip_name_resolve_enable'}->{requires_restart}, JSON::true,
        'skip_name_resolve requires restart' );
    is( $map{'skip_name_resolve_enable'}->{action}->{type}, 'Config',
        'skip_name_resolve action type is Config' );

    # 4. performance_schema
    is( $map{'performance_schema_enable'}->{requires_restart}, JSON::true,
        'performance_schema requires restart' );
    is( $map{'performance_schema_enable'}->{action}->{type}, 'Config',
        'performance_schema action type is Config' );

    # 5. innodb_file_per_table
    is( $map{'innodb_file_per_table_enable'}->{requires_restart}, JSON::true,
        'innodb_file_per_table requires restart' );
    is( $map{'innodb_file_per_table_enable'}->{action}->{type}, 'Config',
        'innodb_file_per_table action type is Config' );

    # 6. innodb_log_file_size
    is( $map{'innodb_log_file_size_adjust'}->{requires_restart}, JSON::true,
        'innodb_log_file_size requires restart' );
    is( $map{'innodb_log_file_size_adjust'}->{action}->{type}, 'Config',
        'innodb_log_file_size action type is Config' );

    # 7. Additional static variables: innodb_page_size, ft_min_word_len
    is( $map{'innodb_page_size_adjust'}->{requires_restart}, JSON::true,
        'innodb_page_size requires restart' );
    is( $map{'innodb_page_size_adjust'}->{action}->{type}, 'Config',
        'innodb_page_size action type is Config' );
    is( $map{'ft_min_word_len_adjust'}->{requires_restart}, JSON::true,
        'ft_min_word_len requires restart' );
    is( $map{'ft_min_word_len_adjust'}->{action}->{type}, 'Config',
        'ft_min_word_len action type is Config' );

    # 8. max_connections (dynamic)
    is( $map{'max_connections_adjust'}->{requires_restart}, JSON::false,
        'max_connections does not require restart' );
    is( $map{'max_connections_adjust'}->{action}->{type}, 'SQL',
        'max_connections action type is SQL' );
    is( $map{'max_connections_adjust'}->{action}->{statement},
        'SET GLOBAL max_connections = 400;', 'max_connections SET GLOBAL format' );
    is( $map{'max_connections_adjust'}->{action}->{rollback_statement},
        'SET GLOBAL max_connections = 151;', 'max_connections rollback format' );

    # 9. Pathological value extraction in agent-json
    ok( exists $map{'thread_cache_size_adjust'}, 'thread_cache_size finding exists in agent-json' );
    is( $map{'thread_cache_size_adjust'}->{action}->{statement},
        'SET GLOBAL thread_cache_size = 4;', 'thread_cache_size (start at 4) statement extracted as 4' );
    is( $map{'thread_cache_size_adjust'}->{requires_restart}, JSON::false,
        'thread_cache_size does not require restart' );
    is( $map{'thread_cache_size_adjust'}->{action}->{type}, 'SQL',
        'thread_cache_size action type is SQL' );

    ok( exists $map{'innodb_io_capacity_adjust'}, 'innodb_io_capacity finding exists in agent-json' );
    is( $map{'innodb_io_capacity_adjust'}->{action}->{statement},
        'SET GLOBAL innodb_io_capacity = 2000;', 'innodb_io_capacity statement extracted as 2000' );
    is( $map{'innodb_io_capacity_adjust'}->{requires_restart}, JSON::false,
        'innodb_io_capacity does not require restart' );
    is( $map{'innodb_io_capacity_adjust'}->{action}->{type}, 'SQL',
        'innodb_io_capacity action type is SQL' );

    ok( exists $map{'join_buffer_size_adjust'}, 'join_buffer_size finding exists in agent-json' );
    is( $map{'join_buffer_size_adjust'}->{action}->{statement},
        'SET GLOBAL join_buffer_size = 262144;', 'join_buffer_size statement extracted as 262144' );
    is( $map{'join_buffer_size_adjust'}->{requires_restart}, JSON::false,
        'join_buffer_size does not require restart' );
    is( $map{'join_buffer_size_adjust'}->{action}->{type}, 'SQL',
        'join_buffer_size action type is SQL' );

    ok( exists $map{'query_cache_size_disable'}, 'query_cache_size finding exists in agent-json' );
    is( $map{'query_cache_size_disable'}->{action}->{statement},
        'SET GLOBAL query_cache_size = 0;', 'query_cache_size with deprecation comment extracted as 0' );
    is( $map{'query_cache_size_disable'}->{requires_restart}, JSON::false,
        'query_cache_size does not require restart' );
    is( $map{'query_cache_size_disable'}->{action}->{type}, 'SQL',
        'query_cache_size action type is SQL' );
};

# =====================================================================
# Challenge 5: Invariance under Undef and Empty Variables
# =====================================================================
subtest 'Challenge 5: Invariance under Undef and Empty Variables' => sub {
    reset_state();
    $opt{'agent-json'} = 1;

    # Empty target or unparseable text
    @adjvars = (
        '',
        '   ',
        'SET =',
        'unparseable text without equals',
        'some_var = ',
    );

    my $stdout_capture = '';
    open my $orig_stdout, ">&STDOUT" or die "Cannot dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$stdout_capture or die "Cannot redirect STDOUT: $!";
    eval { main::dump_result(); };
    close STDOUT;
    open STDOUT, ">&", $orig_stdout or die "Cannot restore STDOUT: $!";

    my $decoded = decode_json($stdout_capture);
    ok( defined $decoded, 'Valid JSON produced even with junk adjvars' );
    is( scalar(@{ $decoded->{findings} }), 0, 'No findings created from empty or junk adjvars' );
};

# =====================================================================
# Challenge 6: Hostile Boundary Stress Test and Agent-JSON Schema Enforcement
# =====================================================================
subtest 'Challenge 6: Hostile Boundary Stress Test and Agent-JSON Schema Enforcement' => sub {
    reset_state();
    $opt{'agent-json'} = 1;

    @adjvars = (
        'sort_buffer_size = 1.5M',
        'innodb_buffer_pool_size = 2.5G',
        'table_open_cache(>=4000)',
        'slow_query_log = ON',
        'general_log = OFF',
        'skip_name_resolve = 1',
        'net.ipv4.tcp_max_syn_backlog = 2048',
        'vm.dirty_background_ratio = 5',
        'gcs.fc_limit = 16',
        'gcs.fc_factor = 0.8',
    );

    %myvar = (
        'sort_buffer_size'        => '262144',
        'innodb_buffer_pool_size' => '134217728',
        'table_open_cache'        => '2000',
        'slow_query_log'          => 'OFF',
        'general_log'             => 'OFF',
        'skip_name_resolve'       => '0',
    );

    my $stdout_capture = '';
    open my $orig_stdout, ">&STDOUT" or die "Cannot dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$stdout_capture or die "Cannot redirect STDOUT: $!";
    eval { main::dump_result(); };
    close STDOUT;
    open STDOUT, ">&", $orig_stdout or die "Cannot restore STDOUT: $!";

    my $decoded = decode_json($stdout_capture);
    ok( defined $decoded && ref($decoded->{findings}) eq 'ARRAY', 'Decoded valid findings array' );

    my @findings = @{ $decoded->{findings} };
    # Verify non-DB keys are strictly absent
    for my $bad (qw(net.ipv4.tcp_max_syn_backlog vm.dirty_background_ratio gcs.fc_limit gcs.fc_factor)) {
        ok( (!grep { $_->{id} =~ /\Q$bad\E/ } @findings), "Hostile key '$bad' strictly omitted from findings" );
    }

    # Verify schema conformance on every emitted finding
    for my $f (@findings) {
        ok( defined $f->{id} && length($f->{id}) > 0, "Finding $f->{id} has non-empty id" );
        ok( defined $f->{topic} && length($f->{topic}) > 0, "Finding $f->{id} has valid topic" );
        ok( defined $f->{description} && length($f->{description}) > 0, "Finding $f->{id} has valid description" );
        ok( defined $f->{impact_score} && $f->{impact_score} =~ /^\d+$/, "Finding $f->{id} has integer impact_score" );
        ok( defined $f->{risk_level} && $f->{risk_level} =~ /^(?:Low|Medium|High|Critical)$/, "Finding $f->{id} has valid risk_level" );
        ok( JSON::is_bool($f->{requires_restart}), "Finding $f->{id} requires_restart is strict JSON boolean" );
        ok( defined $f->{action} && ref($f->{action}) eq 'HASH', "Finding $f->{id} action is a HASH" );
        ok( defined $f->{action}->{type} && $f->{action}->{type} =~ /^(?:SQL|Config)$/, "Finding $f->{id} action.type is SQL or Config" );
        ok( defined $f->{action}->{statement} && length($f->{action}->{statement}) > 0, "Finding $f->{id} action.statement is non-empty" );
        ok( defined $f->{action}->{rollback_statement} && length($f->{action}->{rollback_statement}) > 0, "Finding $f->{id} action.rollback_statement is non-empty" );

        if ($f->{requires_restart}) {
            is( $f->{action}->{type}, 'Config', "Finding $f->{id} requires_restart=true implies type=Config" );
            unlike( $f->{action}->{statement}, qr/^SET GLOBAL/i, "Finding $f->{id} Config statement does not contain SET GLOBAL" );
            unlike( $f->{action}->{statement}, qr/;$/, "Finding $f->{id} Config statement does not end with semicolon" );
        } else {
            is( $f->{action}->{type}, 'SQL', "Finding $f->{id} requires_restart=false implies type=SQL" );
            like( $f->{action}->{statement}, qr/^SET GLOBAL\s+[a-zA-Z0-9_]+\s*=\s*.+;$/, "Finding $f->{id} SQL statement matches SET GLOBAL format" );
            like( $f->{action}->{rollback_statement}, qr/^SET GLOBAL\s+[a-zA-Z0-9_]+\s*=\s*.+;$/, "Finding $f->{id} SQL rollback matches SET GLOBAL format" );
        }
    }
};

done_testing();
