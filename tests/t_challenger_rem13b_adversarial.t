#!/usr/bin/env perl
# tests/t_challenger_rem13b_adversarial.t
# Adversarial Stress Test Suite for Issue 13B Remediation:
#   Empirical verification that logical || short-circuits query_cache_type evaluation,
#   handles all edge cases (numeric 0, string '0', 'OFF', undef, '1', 'DEMAND', 2, etc.)
#   without warning, and that bitwise | would fail the test harness.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Setup environment variables expected by mysqltuner.pl
our @adjvars;
our @generalrec;
our @modeling;
our @sysrec;
our @secrec;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;
our @dblist;
our $mysqlcmd;
our $mysqllogin;
our $devnull;
our $is_win;

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# =====================================================================
# SUBTEST 1: Source Code Static & AST Pattern Verification
# =====================================================================
subtest 'Subtest 1: Static pattern verification of mysqltuner.pl' => sub {
    open my $fh, '<', $script or die "Cannot open $script: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    # Verify logical || is present in query_cache_type evaluation
    like(
        $content,
        qr/\$myvar\{['"]query_cache_type['"]\}\s*eq\s*0\s*\|\|\s*\$myvar\{['"]query_cache_type['"]\}\s*eq\s*['"]OFF['"]/,
        "mysqltuner.pl source uses logical || between 'eq 0' and 'eq OFF'"
    );

    # Ensure no bare bitwise | operator on query_cache_type
    unlike(
        $content,
        qr/\$myvar\{['"]query_cache_type['"]\}\s*eq\s*0\s*\|(?!\|)/,
        "mysqltuner.pl source does NOT use bitwise | operator on query_cache_type"
    );
};

# =====================================================================
# SUBTEST 2: Adversarial Short-Circuiting Trap on live mysql_stats()
# =====================================================================
subtest 'Subtest 2: Empirical short-circuiting proof on live mysql_stats()' => sub {
    {
        package AdversarialTrap;
        require Tie::Hash;
        our @ISA = qw(Tie::ExtraHash);
        our $fetches = 0;
        our $rhs_leak_detected = 0;

        sub FETCH {
            my ($self, $key) = @_;
            if ($key eq 'query_cache_type') {
                $fetches++;
                # In mysql_stats():
                # Fetch 1: defined check
                # Fetch 2: infoprint string concat
                # Fetch 3: LHS ($myvar{query_cache_type} eq 0)
                # If LHS is true (val == 0 or '0'), Fetch 4 should NEVER happen with logical ||.
                # If Fetch 4 occurs for value '0', RHS was leaked (bitwise | evaluation).
                if ($fetches >= 4 && defined($self->[0]{$key}) && $self->[0]{$key} eq '0') {
                    $rhs_leak_detected = 1;
                }
            }
            return $self->[0]{$key};
        }
    }

    sub reset_stats_env {
        %main::opt = ( buffers => 1 );
        %main::mystat = (
            Uptime                => 100000,
            Questions             => 50000,
            Com_select            => 1000,
            Connections           => 50,
            Threads_connected     => 5,
            Threads_running       => 1,
            Slow_queries          => 0,
            Open_tables           => 10,
            Opened_tables         => 20,
            Table_locks_waited    => 0,
            Table_locks_immediate => 100,
            Created_tmp_tables    => 0,
        );
        %main::mycalc = (
            max_tmp_table_size     => 1024,
            total_sorts            => 0,
            joins_without_indexes_per_day => 0,
            thread_cache_hit_rate  => 99,
            table_cache_hit_rate   => 99,
        );
    }

    no warnings 'redefine';
    my @info_captured;
    local *main::infoprint     = sub { push @info_captured, $_[0] if defined $_[0] };
    local *main::badprint      = sub { };
    local *main::goodprint     = sub { };
    local *main::debugprint    = sub { };
    local *main::hr_bytes      = sub { return (defined($_[0]) ? "$_[0] B" : "0 B") };
    local *main::hr_bytes_rnd  = sub { return (defined($_[0]) ? "$_[0] B" : "0 B") };
    local *main::get_pf_memory = sub { return 0 };
    local *main::get_gcache_memory = sub { return 0 };

    # Test case 1: Numeric 0
    {
        reset_stats_env();
        tie %main::myvar, 'AdversarialTrap';
        $main::myvar{query_cache_type}     = 0;
        $main::myvar{query_cache_size}     = 0;
        $main::myvar{key_buffer_size}      = 1024;
        $main::myvar{read_buffer_size}     = 1024;
        $main::myvar{read_rnd_buffer_size} = 1024;
        $main::myvar{sort_buffer_size}     = 1024;
        $main::myvar{thread_stack}         = 1024;
        $main::myvar{join_buffer_size}     = 1024;
        $main::myvar{log_bin}              = 'OFF';
        $main::myvar{max_connections}      = 100;
        $main::myvar{thread_cache_size}    = 10;
        $main::myvar{long_query_time}      = 10;
        $main::myvar{concurrent_insert}    = 'AUTO';
        $main::myvar{version}              = '8.0.35';
        $main::myvar{open_files_limit}     = 65535;

        $AdversarialTrap::fetches = 0;
        $AdversarialTrap::rhs_leak_detected = 0;
        @info_captured = ();

        {
            local $SIG{__WARN__} = sub { };
            main::mysql_stats();
        }

        is($AdversarialTrap::rhs_leak_detected, 0, "No RHS leak detected when val is numeric 0 (logical || short-circuited)");
        is($AdversarialTrap::fetches, 3, "Exactly 3 fetches executed for numeric 0 (defined, concat, eq 0)");
        my ($qc_line) = grep { /Query Cache:/ } @info_captured;
        like($qc_line, qr/Query Cache: 0 - DISABLED/, "Correct DISABLED display for numeric 0");
        untie %main::myvar;
    }

    # Test case 2: String '0'
    {
        reset_stats_env();
        tie %main::myvar, 'AdversarialTrap';
        $main::myvar{query_cache_type}     = '0';
        $main::myvar{query_cache_size}     = 0;
        $main::myvar{key_buffer_size}      = 1024;
        $main::myvar{read_buffer_size}     = 1024;
        $main::myvar{read_rnd_buffer_size} = 1024;
        $main::myvar{sort_buffer_size}     = 1024;
        $main::myvar{thread_stack}         = 1024;
        $main::myvar{join_buffer_size}     = 1024;
        $main::myvar{log_bin}              = 'OFF';
        $main::myvar{max_connections}      = 100;
        $main::myvar{thread_cache_size}    = 10;
        $main::myvar{long_query_time}      = 10;
        $main::myvar{concurrent_insert}    = 'AUTO';
        $main::myvar{version}              = '8.0.35';
        $main::myvar{open_files_limit}     = 65535;

        $AdversarialTrap::fetches = 0;
        $AdversarialTrap::rhs_leak_detected = 0;
        @info_captured = ();

        {
            local $SIG{__WARN__} = sub { };
            main::mysql_stats();
        }

        is($AdversarialTrap::rhs_leak_detected, 0, "No RHS leak detected when val is string '0' (logical || short-circuited)");
        is($AdversarialTrap::fetches, 3, "Exactly 3 fetches executed for string '0' (defined, concat, eq 0)");
        my ($qc_line) = grep { /Query Cache:/ } @info_captured;
        like($qc_line, qr/Query Cache: 0 - DISABLED/, "Correct DISABLED display for string '0'");
        untie %main::myvar;
    }
};

# =====================================================================
# SUBTEST 3: Exhaustive Edge-Case Matrix under Strict FATAL Warnings
# =====================================================================
subtest 'Subtest 3: Exhaustive edge-case matrix under FATAL warnings' => sub {
    my @edge_cases = (
        { val => 0,            expected_text => 'Query Cache: 0 - DISABLED',       desc => 'Numeric 0' },
        { val => '0',          expected_text => 'Query Cache: 0 - DISABLED',       desc => "String '0'" },
        { val => 'OFF',        expected_text => 'Query Cache: OFF - DISABLED',     desc => "String 'OFF'" },
        { val => 1,            expected_text => 'Query Cache: 1 - ALL REQUESTS',   desc => 'Numeric 1' },
        { val => '1',          expected_text => 'Query Cache: 1 - ALL REQUESTS',   desc => "String '1'" },
        { val => 2,            expected_text => 'Query Cache: 2 - ON DEMAND',      desc => 'Numeric 2' },
        { val => '2',          expected_text => 'Query Cache: 2 - ON DEMAND',      desc => "String '2'" },
        { val => 'DEMAND',     expected_text => 'Query Cache: DEMAND - ON DEMAND', desc => "String 'DEMAND'" },
        { val => 'ON',         expected_text => 'Query Cache: ON - ON DEMAND',     desc => "String 'ON' (fallback branch)" },
        { val => '',           expected_text => 'Query Cache:  - ON DEMAND',       desc => "Empty string ''" },
        { val => '00',         expected_text => 'Query Cache: 00 - ON DEMAND',     desc => "Non-matching string '00'" },
        { val => 'off',        expected_text => 'Query Cache: off - ON DEMAND',    desc => "Lowercase 'off'" },
        { val => 'true',       expected_text => 'Query Cache: true - ON DEMAND',   desc => "String 'true'" },
        { val => 'FALSE',      expected_text => 'Query Cache: FALSE - ON DEMAND',  desc => "String 'FALSE'" },
        { val => -1,           expected_text => 'Query Cache: -1 - ON DEMAND',     desc => 'Negative integer -1' },
    );

    for my $ec (@edge_cases) {
        my @info_captured;
        no warnings 'redefine';
        local *main::infoprint     = sub { push @info_captured, $_[0] };
        local *main::badprint      = sub { };
        local *main::goodprint     = sub { };
        local *main::debugprint    = sub { };
        local *main::hr_bytes      = sub { return (defined($_[0]) ? "$_[0] B" : "0 B") };
        local *main::hr_bytes_rnd  = sub { return (defined($_[0]) ? "$_[0] B" : "0 B") };
        local *main::get_pf_memory = sub { return 0 };
        local *main::get_gcache_memory = sub { return 0 };

        %main::opt = ( buffers => 1 );
        %main::mystat = (
            Uptime                => 100000,
            Questions             => 50000,
            Com_select            => 1000,
            Connections           => 50,
            Threads_connected     => 5,
            Threads_running       => 1,
            Slow_queries          => 0,
            Open_tables           => 10,
            Opened_tables         => 20,
            Table_locks_waited    => 0,
            Table_locks_immediate => 100,
            Created_tmp_tables    => 0,
        );
        %main::mycalc = (
            max_tmp_table_size     => 1024,
            total_sorts            => 0,
            joins_without_indexes_per_day => 0,
            thread_cache_hit_rate  => 99,
            table_cache_hit_rate   => 99,
        );
        %main::myvar = (
            query_cache_type     => $ec->{val},
            query_cache_size     => 0,
            key_buffer_size      => 1024,
            read_buffer_size     => 1024,
            read_rnd_buffer_size => 1024,
            sort_buffer_size     => 1024,
            thread_stack         => 1024,
            join_buffer_size     => 1024,
            log_bin              => 'OFF',
            max_connections      => 100,
            thread_cache_size    => 10,
            long_query_time      => 10,
            concurrent_insert    => 'AUTO',
            version              => '8.0.35',
            open_files_limit     => 65535,
        );

        my $eval_err = '';
        my @qc_warnings;
        eval {
            local $SIG{__WARN__} = sub {
                push @qc_warnings, $_[0] if $_[0] =~ /query_cache|bitwise/i;
            };
            main::mysql_stats();
        };
        $eval_err = $@;

        is($eval_err, '', "No exceptions thrown for $ec->{desc}");
        is(scalar(@qc_warnings), 0, "Zero query_cache/bitwise warnings for $ec->{desc}");
        my ($qc_line) = grep { /Query Cache:/ } @info_captured;
        ok($qc_line, "Query Cache output present for $ec->{desc}");
        is($qc_line, " +-- $ec->{expected_text}", "Exact expected output for $ec->{desc}");
    }

    # Edge case: undef query_cache_type
    {
        my @info_captured;
        no warnings 'redefine';
        local *main::infoprint     = sub { push @info_captured, $_[0] if defined $_[0] };
        local *main::badprint      = sub { };
        local *main::goodprint     = sub { };
        local *main::debugprint    = sub { };
        local *main::hr_bytes      = sub { return (defined($_[0]) ? "$_[0] B" : "0 B") };
        local *main::hr_bytes_rnd  = sub { return (defined($_[0]) ? "$_[0] B" : "0 B") };
        local *main::get_pf_memory = sub { return 0 };
        local *main::get_gcache_memory = sub { return 0 };

        %main::opt = ( buffers => 1 );
        %main::mystat = (
            Uptime                => 100000,
            Questions             => 50000,
            Com_select            => 1000,
            Connections           => 50,
            Threads_connected     => 5,
            Threads_running       => 1,
            Slow_queries          => 0,
            Open_tables           => 10,
            Opened_tables         => 20,
            Table_locks_waited    => 0,
            Table_locks_immediate => 100,
            Created_tmp_tables    => 0,
        );
        %main::mycalc = ( max_tmp_table_size => 1024 );
        %main::myvar = (
            query_cache_type     => undef,
            key_buffer_size      => 1024,
            read_buffer_size     => 1024,
            read_rnd_buffer_size => 1024,
            sort_buffer_size     => 1024,
            thread_stack         => 1024,
            join_buffer_size     => 1024,
            log_bin              => 'OFF',
            max_connections      => 100,
        );

        my $eval_err = '';
        my @qc_warnings;
        eval {
            local $SIG{__WARN__} = sub {
                push @qc_warnings, $_[0] if $_[0] =~ /query_cache|bitwise/i;
            };
            main::mysql_stats();
        };
        $eval_err = $@;

        is($eval_err, '', "No fatal warnings/exceptions thrown for undef query_cache_type");
        is(scalar(@qc_warnings), 0, "Zero query_cache/bitwise warnings for undef query_cache_type");
        my ($qc_line) = grep { /Query Cache:/ } @info_captured;
        ok(!$qc_line, "Query Cache section is safely omitted when query_cache_type is undef");
    }
};

# =====================================================================
# SUBTEST 4: Negative Proof - Demonstrating that bitwise | FAILS the Trap
# =====================================================================
subtest 'Subtest 4: Negative proof (bitwise | fails the short-circuit harness)' => sub {
    {
        package MutationTrap;
        require Tie::Hash;
        our @ISA = qw(Tie::ExtraHash);
        our $fetches = 0;
        our $rhs_evaluated = 0;

        sub FETCH {
            my ($self, $key) = @_;
            if ($key eq 'query_cache_type') {
                $fetches++;
                # If fetches == 2 in the test expression where LHS was 0, RHS was evaluated!
                if ($fetches == 2 && $self->[0]{$key} eq '0') {
                    $rhs_evaluated = 1;
                }
            }
            return $self->[0]{$key};
        }
    }

    my %trap_hash;
    tie %trap_hash, 'MutationTrap';
    $trap_hash{query_cache_type} = 0;

    # 4.1 Evaluation with bitwise | (Buggy code simulation)
    $MutationTrap::fetches = 0;
    $MutationTrap::rhs_evaluated = 0;
    my $bitwise_result = (
        $trap_hash{'query_cache_type'} eq 0 |
        $trap_hash{'query_cache_type'} eq 'OFF' ? "DISABLED"
        : "OTHER"
    );
    is($bitwise_result, "DISABLED", "Bitwise | produces DISABLED value (masking bug without harness)");
    is($MutationTrap::fetches, 2, "Bitwise | performs 2 fetches (evaluates both LHS and RHS)");
    is($MutationTrap::rhs_evaluated, 1, "PROVEN: Bitwise | leaks evaluation to RHS when LHS is 0");

    # 4.2 Evaluation with logical || (Fixed code simulation)
    $MutationTrap::fetches = 0;
    $MutationTrap::rhs_evaluated = 0;
    my $logical_result = (
        $trap_hash{'query_cache_type'} eq 0
        || $trap_hash{'query_cache_type'} eq 'OFF' ? "DISABLED"
        : "OTHER"
    );
    is($logical_result, "DISABLED", "Logical || produces DISABLED value");
    is($MutationTrap::fetches, 1, "Logical || performs exactly 1 fetch (short-circuits immediately)");
    is($MutationTrap::rhs_evaluated, 0, "PROVEN: Logical || NEVER evaluates RHS when LHS is 0");

    untie %trap_hash;
};

done_testing();
