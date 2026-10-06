#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_boolean_normalization.t
# Description: Validates MySQL Boolean Normalization Engine (Phase 24)
#              in mysqltuner.pl across all MySQL/MariaDB boolean formats.
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;

require "$FindBin::Bin/../mysqltuner.pl";

plan tests => 5;

# --- Subtest 1: Truthy Representations ---
subtest 'Truthy Representations Normalization' => sub {
    my @truthy = ('1', 'ON', 'on', 'On', 'YES', 'yes', 'Yes', 'TRUE', 'true', 'True', 'ENABLE', 'ENABLED', 'enabled');
    plan tests => scalar(@truthy) * 2;

    for my $val (@truthy) {
        is(main::normalize_mysql_bool($val), 1, "normalize_mysql_bool('$val') returns 1");
        is(main::is_mysql_true($val), 1, "is_mysql_true('$val') returns 1");
    }
};

# --- Subtest 2: Falsy Representations ---
subtest 'Falsy Representations Normalization' => sub {
    my @falsy = ('0', 'OFF', 'off', 'Off', 'NO', 'no', 'No', 'FALSE', 'false', 'False', 'DISABLE', 'DISABLED', 'disabled');
    plan tests => scalar(@falsy) * 2;

    for my $val (@falsy) {
        is(main::normalize_mysql_bool($val), 0, "normalize_mysql_bool('$val') returns 0");
        is(main::is_mysql_false($val), 1, "is_mysql_false('$val') returns 1");
    }
};

# --- Subtest 3: Edge Cases, Whitespaces & Undefined Values ---
subtest 'Edge Cases & Invalid Values' => sub {
    plan tests => 10;

    is(main::normalize_mysql_bool(undef), undef, "normalize_mysql_bool(undef) returns undef");
    is(main::is_mysql_true(undef), 0, "is_mysql_true(undef) returns 0");
    is(main::is_mysql_false(undef), 0, "is_mysql_false(undef) returns 0");

    is(main::normalize_mysql_bool("  ON  "), 1, "handles padded whitespace '  ON  '");
    is(main::normalize_mysql_bool("  OFF  "), 0, "handles padded whitespace '  OFF  '");

    is(main::normalize_mysql_bool(""), undef, "empty string returns undef");
    is(main::normalize_mysql_bool("RANDOM_STRING"), undef, "arbitrary string returns undef");
    is(main::normalize_mysql_bool("2"), undef, "number 2 returns undef");
    is(main::is_mysql_true("2"), 0, "is_mysql_true('2') returns 0");
    is(main::is_mysql_false("2"), 0, "is_mysql_false('2') returns 0");
};

# --- Subtest 4: Mutual Exclusivity ---
subtest 'Mutual Exclusivity Guard' => sub {
    plan tests => 6;

    ok(main::is_mysql_true("ON") && !main::is_mysql_false("ON"), "'ON' is true and not false");
    ok(main::is_mysql_false("OFF") && !main::is_mysql_true("OFF"), "'OFF' is false and not true");
    ok(main::is_mysql_true("1") && !main::is_mysql_false("1"), "'1' is true and not false");
    ok(main::is_mysql_false("0") && !main::is_mysql_true("0"), "'0' is false and not true");
    ok(!main::is_mysql_true(undef) && !main::is_mysql_false(undef), "undef is neither true nor false");
    ok(!main::is_mysql_true("INVALID") && !main::is_mysql_false("INVALID"), "invalid string is neither true nor false");
};

# --- Subtest 5: Formatting Output ---
subtest 'format_mysql_bool Standardized Output' => sub {
    plan tests => 6;

    is(main::format_mysql_bool("1"), "ON", "format_mysql_bool('1') -> 'ON'");
    is(main::format_mysql_bool("yes"), "ON", "format_mysql_bool('yes') -> 'ON'");
    is(main::format_mysql_bool("0"), "OFF", "format_mysql_bool('0') -> 'OFF'");
    is(main::format_mysql_bool("FALSE"), "OFF", "format_mysql_bool('FALSE') -> 'OFF'");
    is(main::format_mysql_bool(undef), "UNKNOWN", "format_mysql_bool(undef) -> 'UNKNOWN'");
    is(main::format_mysql_bool("CUSTOM"), "CUSTOM", "format_mysql_bool('CUSTOM') -> 'CUSTOM'");
};

done_testing();
