use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;

# Suppress warnings from mysqltuner.pl initialization if any
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

use Cwd 'abs_path';

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

# 1. Test is_int
subtest 'is_int' => sub {
    ok(main::is_int("123"), "Positive integer");
    ok(main::is_int("-123"), "Negative integer");
    ok(main::is_int("0"), "Zero");
    ok(main::is_int("  456  "), "Integer with whitespace");
    ok(!main::is_int("12.3"), "Float is not int");
    ok(!main::is_int("abc"), "String is not int");
    ok(!main::is_int(""), "Empty string is not int");
    ok(!main::is_int(undef), "Undef is not int");
};

# 2. Test hr_bytes
subtest 'hr_bytes' => sub {
    is(main::hr_bytes(500), "500B", "Bytes");
    is(main::hr_bytes(1024), "1.0K", "1 KB");
    is(main::hr_bytes(1024**2), "1.0M", "1 MB");
    is(main::hr_bytes(1024**3), "1.0G", "1 GB");
    is(main::hr_bytes(1.5 * 1024**3), "1.5G", "1.5 GB");
    is(main::hr_bytes(0), "0B", "Zero bytes");
    is(main::hr_bytes("NULL"), "0B", "NULL string");
    is(main::hr_bytes(""), "0B", "Empty string");
    is(main::hr_bytes(undef), "0B", "Undef");
};

# 3. Test percentage
subtest 'percentage' => sub {
    is(main::percentage(50, 100), "50.00", "50/100 = 50.00");
    is(main::percentage(1, 3), "33.33", "1/3 = 33.33");
    is(main::percentage(0, 100), "0.00", "0/100 = 0.00");
    # Scalar context for list return (100, 0)
    is(scalar main::percentage(100, 0), "100.00", "Division by zero returns 100.00 (correct behavior for idle servers)");
};

# 4. Test hr_num
subtest 'hr_num' => sub {
    is(main::hr_num(500), "500", "Small number");
    is(main::hr_num(1000), "1K", "Thousand");
    is(main::hr_num(1000000), "1M", "Million");
    is(main::hr_num(1000000000), "1B", "Billion");
};

# 5. Test human_size
subtest 'human_size' => sub {
    is(main::human_size(1024), "1.00 KB", "1 KB");
    is(main::human_size(1024*1024), "1.00 MB", "1 MB");
};

# 6. Test arr2hash
subtest 'arr2hash' => sub {
    my %hash = ();
    my @input = (
        "key1 value1",
        "key_2\tvalue2",
        "key_with_digits_3 value3",
        "innodb_redo_log_capacity 15",
        "VERSION 8.0.32"
    );
    main::arr2hash(\%hash, \@input);
    is($hash{'key1'}, 'value1', "Simple key");
    is($hash{'key_2'}, 'value2', "Key with underscore and tab");
    is($hash{'key_with_digits_3'}, 'value3', "Key with digits and underscore");
    is($hash{'innodb_redo_log_capacity'}, '15', "Real variable name");
    is($hash{'VERSION'}, '8.0.32', "Uppercase key with digits");
};

done_testing();
