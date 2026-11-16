#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';
use JSON;

BEGIN {
    *CORE::GLOBAL::exit = sub { die "EXIT_CALLED\n" };
}

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

subtest 'Adversarial 1: clean_tuning_value under malicious and extreme comment formats' => sub {
    plan tests => 14;

    # Edge case 1: Multiple comment styles combined
    is(main::clean_tuning_value('512M # comment 1 -- comment 2 /* comment 3 */'), '512M', 'Combined comment styles stripped');

    # Edge case 2: C-style block comments with spaces
    is(main::clean_tuning_value('  1024   /* block comment */  '), '1024', 'Trimmed and cleaned block comment');

    # Edge case 3: Bracketed comment
    is(main::clean_tuning_value('2 [non-ACID mode]'), '2', 'Bracketed comments stripped');

    # Edge case 4: Slash-slash comments
    is(main::clean_tuning_value('16G // allocation limit'), '16G', 'C++ style comments stripped');

    # Edge case 5: Complex range comparison
    is(main::clean_tuning_value('(>= 4000) for NVMe drives'), '4000', 'Complex parenthesized threshold stripped');

    # Edge case 6: Parenthesized with start at
    is(main::clean_tuning_value('(start at 64M)'), '64M', 'Start at comment cleaned');

    # Edge case 7: Parenthesized with around
    is(main::clean_tuning_value('(around 128M)'), '128M', 'Around comment cleaned');

    # Edge case 8: Parenthesized with comma warning
    is(main::clean_tuning_value('(> 256.0K, or always use indexes with JOINs)'), '256.0K', 'Comma-delimited paren comment cleaned');

    # Edge case 9: Already clean scalar
    is(main::clean_tuning_value('2000'), '2000', 'Clean numeric scalar untouched');

    # Edge case 10: Clean alphanumeric value
    is(main::clean_tuning_value('STRICT_TRANS_TABLES'), 'STRICT_TRANS_TABLES', 'Clean SQL mode untouched');

    # Edge case 11: Undef value
    is(main::clean_tuning_value(undef), '', 'Undef returns empty string without warnings');

    # Edge case 12: Empty string
    is(main::clean_tuning_value(''), '', 'Empty string returns empty string');

    # Edge case 13: Whitespace only
    is(main::clean_tuning_value("   \t  \n "), '', 'Whitespace only returns empty string');

    # Edge case 14: Only operators
    is(main::clean_tuning_value('>= <= = ()'), '', 'Only operators and parens stripped to empty');
};

subtest 'Adversarial 2: generate_auto_fix_snippets stress test with malformed and static entries' => sub {
    plan tests => 8;

    @main::adjvars = (
        '   ',
        'invalid_statement_without_equals_or_parentheses',
        'net.ipv4.tcp_tw_reuse = 1',
        'vm.dirty_background_ratio = 10',
        'performance_schema = ON (requires restart)',
        'skip-name-resolve = 1',
        'innodb_page_size = 64k',
        'ft_min_word_len = 3',
        'max_connections = 1000 # prod ceiling'
    );

    %main::opt = (
        'silent'     => 0,
        'json'       => 0,
        'yaml'       => 0,
        'agent-json' => 0,
    );

    my $output = '';
    open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$output or die "Can't redirect STDOUT: $!";

    eval { main::generate_auto_fix_snippets(); };
    my $err = $@;

    close STDOUT;
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";

    ok(!$err, 'generate_auto_fix_snippets executed without exception');

    # Malformed lines and sysctl lines should NOT appear in SET GLOBAL
    unlike($output, qr/SET GLOBAL\s+invalid_statement/, 'Malformed statement omitted from SET GLOBAL');
    unlike($output, qr/SET GLOBAL\s+net\.ipv4/, 'Sysctl net.ipv4 omitted from SET GLOBAL');
    unlike($output, qr/SET GLOBAL\s+vm\.dirty/, 'Sysctl vm.dirty omitted from SET GLOBAL');

    # Static variables must emit # my.cnf: comments
    like($output, qr/# my\.cnf:\s*performance_schema\s*=\s*ON/, 'performance_schema emitted as # my.cnf');
    like($output, qr/# my\.cnf:\s*skip-name-resolve\s*=\s*1/, 'skip-name-resolve emitted as # my.cnf');
    like($output, qr/# my\.cnf:\s*innodb_page_size\s*=\s*64k/, 'innodb_page_size emitted as # my.cnf');

    # Clean dynamic variable
    like($output, qr/SET GLOBAL max_connections = 1000;/, 'max_connections properly emitted with stripped comment');
};

subtest 'Adversarial 3: dump_result (--agent-json) boolean types, static flags, and schema validation' => sub {
    plan tests => 19;

    @main::adjvars = (
        'net.core.somaxconn = 4096',
        'performance_schema = ON',
        'innodb_page_size = 32k',
        'skip-name-resolve = 1',
        'skip_name_resolve = 1',
        'ft_min_word_len = 3',
        'table_open_cache = 4000 (Recommended for 1000 tables)'
    );

    %main::myvar = (
        'table_open_cache'   => '2000',
        'performance_schema' => 'OFF',
        'skip_name_resolve'  => '0',
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

    like($err, qr/EXIT_CALLED/, 'dump_result executed exit 0');

    my $data = eval { decode_json($stdout_content) };
    ok(defined $data, 'Stdout produced valid parseable JSON');

    # Verify sysctl key was completely omitted
    my @somaxconn = grep { $_->{action}->{statement} =~ /somaxconn/i } @{ $data->{findings} };
    is(scalar(@somaxconn), 0, 'Sysctl net.core.somaxconn omitted from findings');

    my %by_id = map { $_->{id} => $_ } @{ $data->{findings} };

    # Test static variables: requires_restart is strictly JSON::true and action.type is 'Config'
    ok(exists $by_id{'performance_schema_enable'}, 'Finding exists for static var performance_schema');
    is($by_id{'performance_schema_enable'}->{requires_restart}, JSON::true, 'performance_schema requires_restart is true');
    is($by_id{'performance_schema_enable'}->{action}->{type}, 'Config', 'performance_schema action.type is Config');

    ok(exists $by_id{'innodb_page_size_adjust'}, 'Finding exists for static var innodb_page_size');
    is($by_id{'innodb_page_size_adjust'}->{requires_restart}, JSON::true, 'innodb_page_size requires_restart is true');
    is($by_id{'innodb_page_size_adjust'}->{action}->{type}, 'Config', 'innodb_page_size action.type is Config');

    ok(exists $by_id{'skip_name_resolve_enable'}, 'Finding exists for static var skip_name_resolve');
    is($by_id{'skip_name_resolve_enable'}->{requires_restart}, JSON::true, 'skip_name_resolve requires_restart is true');
    is($by_id{'skip_name_resolve_enable'}->{action}->{type}, 'Config', 'skip_name_resolve action.type is Config');

    ok(exists $by_id{'ft_min_word_len_adjust'}, 'Finding exists for static var ft_min_word_len');
    is($by_id{'ft_min_word_len_adjust'}->{requires_restart}, JSON::true, 'ft_min_word_len requires_restart is true');
    is($by_id{'ft_min_word_len_adjust'}->{action}->{type}, 'Config', 'ft_min_word_len action.type is Config');

    # Test dynamic variable
    ok(exists $by_id{'table_open_cache_adjust'}, 'Finding exists for table_open_cache');
    is($by_id{'table_open_cache_adjust'}->{requires_restart}, JSON::false, 'table_open_cache has requires_restart = false');
    is($by_id{'table_open_cache_adjust'}->{action}->{type}, 'SQL', 'table_open_cache has action.type = SQL');
    is($by_id{'table_open_cache_adjust'}->{action}->{statement}, 'SET GLOBAL table_open_cache = 4000;', 'Statement cleaned of recommendation note');
};

subtest 'Adversarial 4: Connected auditors robustness against zero division, negative values, and non-numerics' => sub {
    plan tests => 7;

    # 1. audit_table_definition_cache with 0 uptime and 0 cache size
    my @tdc_zero = main::audit_table_definition_cache(0, 0, 0, 0);
    is(scalar(@tdc_zero), 0, 'TDC zero values do not trigger divide-by-zero');

    my @tdc_neg = main::audit_table_definition_cache(-100, -50, -500, -10);
    is(scalar(@tdc_neg), 0, 'TDC negative values handled safely');

    # 2. audit_innodb_ahi with zero searches and zero instances
    my @ahi_zero = main::audit_innodb_ahi('ON', 0, 0, 0, 0);
    is(scalar(@ahi_zero), 0, 'AHI zero searches do not trigger divide-by-zero');

    my @ahi_neg = main::audit_innodb_ahi('ON', -10, -50, -1, -2);
    is(scalar(@ahi_neg), 0, 'AHI negative values handled safely');

    # 3. audit_tls_ciphers_protocols with malformed and legacy strings
    my @tls_malformed = main::audit_tls_ciphers_protocols('YES', 'TLSv1.0,SSLv3,TLSv1', 'NULL-MD5:ADH-RC4:UNKNOWN');
    ok(scalar(@tls_malformed) >= 1, 'TLS catches deprecated protocols and weak ciphers');

    my @tls_empty = main::audit_tls_ciphers_protocols('YES', '', '');
    is(scalar(@tls_empty), 0, 'TLS empty strings produce no findings and no errors');

    # 4. audit_pfs_stage_profiling with empty hashrefs
    my @pfs_empty = main::audit_pfs_stage_profiling( {}, {} );
    is(scalar(@pfs_empty), 0, 'PFS empty hashes produce no findings');
};

done_testing();
