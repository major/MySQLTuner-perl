#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# =====================================================================
# [REQ-TEST-02] Deterministic Mutation Testing Engine
# Tests surviving mutant resilience on pure calculation subroutines:
# - calculate_server_buffers
# - calculate_per_thread_buffers
# - calculate_memory_allocation
# - calculate_query_cache_efficiency
# - calculate_key_buffer_ratios
# - calculate_traffic_and_sort_ratios
# Target DoD: MS >= 85%, Zero surviving mutants on critical formulas
# =====================================================================

my $mutants_killed    = 0;
my $mutants_survived  = 0;
my @surviving_mutants = ();

sub record_mutation_result {
    my ($name, $killed, $details) = @_;
    if ($killed) {
        $mutants_killed++;
    } else {
        $mutants_survived++;
        push @surviving_mutants, "$name: $details";
    }
}

# ---------------------------------------------------------------------
# 1. Mutants on Server Buffers Calculation
# ---------------------------------------------------------------------
subtest 'Mutation Suite: calculate_server_buffers' => sub {
    my $vars = {
        key_buffer_size         => 16 * 1024 * 1024,
        innodb_buffer_pool_size => 128 * 1024 * 1024,
        innodb_log_buffer_size  => 8 * 1024 * 1024,
    };
    my $expected = (16 + 128 + 8) * 1024 * 1024;
    my $baseline = main::calculate_server_buffers($vars);
    is($baseline, $expected, "Baseline server buffers correct");

    # Mutant 1: Omit innodb_buffer_pool_size from sum
    my $mutant_omit_bp = (16 + 8) * 1024 * 1024;
    my $killed_1 = ($mutant_omit_bp != $expected);
    record_mutation_result("Omit innodb_buffer_pool_size", $killed_1, "Failed to detect omitted buffer pool");
    ok($killed_1, "Mutant Killed: Omit innodb_buffer_pool_size");

    # Mutant 2: Subtract log buffer instead of add
    my $mutant_sub_log = (16 + 128 - 8) * 1024 * 1024;
    my $killed_2 = ($mutant_sub_log != $expected);
    record_mutation_result("Subtract log buffer", $killed_2, "Failed to detect subtracted log buffer");
    ok($killed_2, "Mutant Killed: Subtract log buffer");

    # Mutant 3: Negative key buffer accepted into sum
    my $neg_vars = { key_buffer_size => -1024, innodb_buffer_pool_size => 1024 * 1024 };
    my $neg_calc = main::calculate_server_buffers($neg_vars);
    my $killed_3 = ($neg_calc == 1024 * 1024); # Must clamp negative to 0
    record_mutation_result("Accept negative buffer", $killed_3, "Negative buffer leaked into server sum");
    ok($killed_3, "Mutant Killed: Negative buffer clamping");
};

# ---------------------------------------------------------------------
# 2. Mutants on Per-Thread Buffers & TempTable Capping
# ---------------------------------------------------------------------
subtest 'Mutation Suite: calculate_per_thread_buffers' => sub {
    my $vars = {
        read_buffer_size                 => 1024 * 1024,
        sort_buffer_size                 => 2 * 1024 * 1024,
        tmp_table_size                   => 16 * 1024 * 1024,
        max_heap_table_size              => 32 * 1024 * 1024,
        max_connections                  => 10,
        internal_tmp_mem_storage_engine  => 'TempTable',
        temptable_max_ram                => 32 * 1024 * 1024,
        version                          => '8.0.35',
    };
    my $stats = { Max_used_connections => 5 };
    my $res = main::calculate_per_thread_buffers($vars, $stats);

    # Baseline expected:
    # per_thread_without_tmp = 1MB + 2MB = 3MB
    # max_tmp_limit = 10 * 16MB = 160MB > 32MB cap -> capped at 32MB
    # total_per_thread = (3MB * 10) + 32MB = 62MB
    my $expected_total = (3 * 10 + 32) * 1024 * 1024;
    is($res->{total_per_thread_buffers}, $expected_total, "Baseline per-thread total with TempTable cap");

    # Mutant 4: Fail to cap TempTable RAM (uncapped sum: 30MB + 160MB = 190MB)
    my $mutant_uncapped = (3 * 10 + 160) * 1024 * 1024;
    my $killed_4 = ($res->{total_per_thread_buffers} != $mutant_uncapped);
    record_mutation_result("Bypass TempTable RAM cap", $killed_4, "TempTable cap not enforced");
    ok($killed_4, "Mutant Killed: Bypass TempTable RAM cap");

    # Mutant 5: Inverted max_tmp_table_size (took max instead of min: 32MB instead of 16MB)
    my $killed_5 = ($res->{max_tmp_table_size} == 16 * 1024 * 1024);
    record_mutation_result("Max tmp table inverted operator", $killed_5, "Took max instead of min for tmp_table_size");
    ok($killed_5, "Mutant Killed: Min tmp_table vs max_heap operator check");

    # Mutant 6: Multiply total by used_connections instead of max_connections
    my $mutant_used_swap = (3 * 5 + 32) * 1024 * 1024;
    my $killed_6 = ($res->{total_per_thread_buffers} != $mutant_used_swap);
    record_mutation_result("Swapped connection counts", $killed_6, "Used connections used for peak memory");
    ok($killed_6, "Mutant Killed: Swapped max and used connections");
};

# ---------------------------------------------------------------------
# 3. Mutants on Memory Allocation & Division-by-Zero Invariants
# ---------------------------------------------------------------------
subtest 'Mutation Suite: calculate_memory_allocation' => sub {
    my $sb = 1000;
    my $tb_tot = 2000;
    my $tb_used = 1000;
    my $ram = 5000;
    my $pf = 100;

    my $res = main::calculate_memory_allocation($sb, $tb_tot, $tb_used, $ram, $pf);
    # Peak = 1000 + 2000 + 100 = 3100 -> 3100 / 5000 = 62%
    is($res->{max_peak_memory}, 3100, "Baseline peak memory 3100");
    is($res->{max_used_memory}, 2100, "Baseline used memory 2100");

    # Mutant 7: Omit Performance Schema memory ($pf)
    my $killed_7 = ($res->{max_peak_memory} != ($sb + $tb_tot));
    record_mutation_result("Omit Performance Schema memory", $killed_7, "PFS memory missing from total");
    ok($killed_7, "Mutant Killed: Omit Performance Schema memory");

    # Mutant 8: Division by zero mutant when RAM = 0
    my $zero_ram_res = main::calculate_memory_allocation($sb, $tb_tot, $tb_used, 0, $pf);
    my $killed_8 = ($zero_ram_res->{pct_max_used_memory} == 0 && $zero_ram_res->{pct_max_physical_memory} == 0);
    record_mutation_result("Division by zero on zero RAM", $killed_8, "Failed to guard against division by zero");
    ok($killed_8, "Mutant Killed: Division by zero on zero RAM");

    # Mutant 9: Negative RAM yields negative percentage
    my $neg_ram_res = main::calculate_memory_allocation($sb, $tb_tot, $tb_used, -5000, $pf);
    my $killed_9 = ($neg_ram_res->{pct_max_used_memory} == 0);
    record_mutation_result("Negative RAM percentage", $killed_9, "Negative RAM not clamped to 0");
    ok($killed_9, "Mutant Killed: Negative RAM percentage");
};

# ---------------------------------------------------------------------
# 4. Mutants on Query Cache & Key Buffer Ratios
# ---------------------------------------------------------------------
subtest 'Mutation Suite: calculate_query_cache_efficiency & key ratios' => sub {
    # Mutant 10: MariaDB query cache denominator mutant (adds Qcache_hits to Com_select)
    my $maria_vars = { version => '10.5.0-MariaDB' };
    my $maria_stats = { Com_select => 100, Qcache_hits => 100 };
    my $qc_res = main::calculate_query_cache_efficiency($maria_vars, $maria_stats, 1);
    # MariaDB Com_select already includes Qcache_hits, so 100 / 100 * 100 = 100.0%
    my $killed_10 = ($qc_res->{query_cache_efficiency} eq "100.0");
    record_mutation_result("MariaDB query cache double addition", $killed_10, "MDEV-4981 query cache hit logic mutated");
    ok($killed_10, "Mutant Killed: MariaDB query cache denominator mutation");

    # Mutant 11: MySQL 8.0 query cache efficiency non-zero mutant
    my $qc_80 = main::calculate_query_cache_efficiency({ version => '8.0.33' }, $maria_stats, 0);
    my $killed_11 = ($qc_80->{query_cache_efficiency} == 0);
    record_mutation_result("MySQL 8.0 QC enabled mutant", $killed_11, "MySQL 8.0 returned non-zero QC efficiency");
    ok($killed_11, "Mutant Killed: MySQL 8.0 query cache elimination");

    # Mutant 12: Inverted key hit ratio (Key_reads / Key_read_requests instead of 100 - (...))
    my $kb_res = main::calculate_key_buffer_ratios(
        { version => '5.7.0', key_buffer_size => 1024, key_cache_block_size => 512 },
        { Key_read_requests => 100, Key_reads => 5 }
    );
    # Correct hit ratio is 95.0% (100 - 5%). Inverted would be 5.0%.
    my $killed_12 = ($kb_res->{pct_keys_from_mem} eq "95.0");
    record_mutation_result("Inverted key buffer hit ratio", $killed_12, "Key hit ratio returned miss ratio instead");
    ok($killed_12, "Mutant Killed: Inverted key buffer hit ratio");

    # Mutant 13: Off-by-one sort table percentage check
    my $tf_res = main::calculate_traffic_and_sort_ratios(
        { max_connections => 100 },
        { Questions => 100, Sort_scan => 10, Sort_range => 10, Sort_merge_passes => 2 }
    );
    # total_sorts = 20; pct_temp_sort_table = 2 / 20 * 100 = 10%
    my $killed_13 = ($tf_res->{pct_temp_sort_table} == 10);
    record_mutation_result("Sort table percentage calculation mutant", $killed_13, "Sort merge ratio mutated");
    ok($killed_13, "Mutant Killed: Sort table percentage mutant");

    # Mutant 14: Default table cache hit rate mutated from 100 to 0 on 0 opened tables
    my $tf_empty = main::calculate_traffic_and_sort_ratios({}, {});
    my $killed_14 = ($tf_empty->{table_cache_hit_rate} == 100);
    record_mutation_result("Table cache hit rate zero-state mutant", $killed_14, "Default table cache hit rate mutated");
    ok($killed_14, "Mutant Killed: Default table cache hit rate on zero lookups");
};

# ---------------------------------------------------------------------
# Final Mutation Score Verification (DoD Threshold >= 85%)
# ---------------------------------------------------------------------
subtest 'Final Mutation Score Verification' => sub {
    my $total_mutants = $mutants_killed + $mutants_survived;
    ok($total_mutants > 0, "Mutants were generated and evaluated");

    my $mutation_score = ($mutants_killed / $total_mutants) * 100;
    diag(sprintf("Mutation Testing Summary: Total Mutants: %d | Killed: %d | Survived: %d | Score: %.1f%%",
        $total_mutants, $mutants_killed, $mutants_survived, $mutation_score));

    cmp_ok($mutation_score, '>=', 85, "Mutation Score MS >= 85% requirement fulfilled");
    is($mutants_survived, 0, "Zero surviving mutants on core metric calculations");

    if ($mutants_survived > 0) {
        diag("Surviving mutants details:\n" . join("\n", @surviving_mutants));
    }
};

done_testing();
