#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';
use JSON;

# Override exit to throw an exception that can be caught in tests
BEGIN {
    *CORE::GLOBAL::exit = sub { die "EXIT_CALLED\n" };
}

my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

subtest 'Agent Actionable JSON Schema Verification' => sub {
    no warnings 'once';
    
    # Populates mock variables and options
    @main::adjvars = (
        'innodb_buffer_pool_size (>= 1G)',
        'performance_schema=ON',
        'query_cache_size (=0)'
    );
    
    %main::myvar = (
        'innodb_buffer_pool_size' => '134217728',
        'performance_schema' => 'OFF',
        'query_cache_size' => '16777216'
    );
    
    %main::opt = (
        'agent-json' => 1
    );

    # Capture stdout
    my $stdout_content = '';
    open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$stdout_content or die "Can't redirect STDOUT: $!";
    
    # Execute dump_result
    eval { main::dump_result(); };
    my $err = $@;

    # Restore stdout
    close STDOUT;
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";

    like($err, qr/EXIT_CALLED/, 'dump_result exited cleanly');
    
    # Verify JSON structure
    my $data = eval { decode_json($stdout_content) };
    ok(defined $data, 'Stdout is valid JSON');
    ok(exists $data->{findings}, 'JSON contains findings key');
    
    my $findings = $data->{findings};
    is(scalar(@$findings), 3, 'Found exactly 3 findings');
    
    # 1. Verify innodb_buffer_pool_size
    my $ibp = $findings->[0];
    is($ibp->{id}, 'innodb_buffer_pool_size_adjust', 'Correct ID for buffer pool');
    is($ibp->{topic}, 'Performance', 'Correct topic');
    is($ibp->{risk_level}, 'Medium', 'Correct risk level');
    is($ibp->{requires_restart}, JSON::false, 'Requires restart is false');
    is($ibp->{action}->{type}, 'SQL', 'Action type is SQL');
    is($ibp->{action}->{statement}, 'SET GLOBAL innodb_buffer_pool_size = 1G;', 'Correct SQL statement');
    is($ibp->{action}->{rollback_statement}, 'SET GLOBAL innodb_buffer_pool_size = 134217728;', 'Correct rollback SQL statement');

    # 2. Verify performance_schema
    my $pfs = $findings->[1];
    is($pfs->{id}, 'performance_schema_enable', 'Correct ID for performance schema');
    is($pfs->{requires_restart}, JSON::true, 'Requires restart is true');
    is($pfs->{action}->{type}, 'Config', 'Action type is Config');
    is($pfs->{action}->{statement}, 'performance_schema = ON', 'Correct config statement');
    is($pfs->{action}->{rollback_statement}, 'performance_schema = OFF', 'Correct rollback config statement');
};

done_testing();
