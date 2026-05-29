use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

# --- PI-006 Coverage Boost: Pure utility functions ---

# 1. trim
subtest 'trim' => sub {
    is(main::trim("  hello  "), "hello", "Trims both sides");
    is(main::trim("hello"), "hello", "No-op on clean string");
    is(main::trim("  "), "", "Whitespace-only becomes empty");
    is(main::trim("\t\n hello \n\t"), "hello", "Trims tabs and newlines");
    is(main::trim(""), "", "Empty string stays empty");
    is(main::trim(undef), "", "Undef returns empty string");
};

# 2. remove_cr
subtest 'remove_cr' => sub {
    my @input = ("line1\n", "  line2\n", "   \n", "line3");
    my @result = main::remove_cr(@input);
    is($result[0], "line1", "Strips trailing newline");
    is($result[1], "  line2", "Preserves leading spaces, strips newline");
    is($result[2], "", "Whitespace-only line becomes empty");
    is($result[3], "line3", "No newline — unchanged");

    my @empty = main::remove_cr();
    is(scalar @empty, 0, "Empty input returns empty list");
};

# 3. remove_empty
subtest 'remove_empty' => sub {
    my @input = ("a", "", "b", "", "c");
    my @result = main::remove_empty(@input);
    is_deeply(\@result, ["a", "b", "c"], "Filters out empty strings");

    my @all_empty = main::remove_empty("", "", "");
    is(scalar @all_empty, 0, "All empty returns empty list");

    my @none_empty = main::remove_empty("x", "y");
    is(scalar @none_empty, 2, "No empty strings — all kept");
};

# 4. escape_html
subtest 'escape_html' => sub {
    is(main::escape_html("<script>"), "&lt;script&gt;", "Escapes angle brackets");
    is(main::escape_html('He said "hello"'), 'He said &quot;hello&quot;', "Escapes double quotes");
    is(main::escape_html("It's fine"), "It&#39;s fine", "Escapes single quotes");
    is(main::escape_html("A & B"), "A &amp; B", "Escapes ampersand");
    is(main::escape_html("plain text"), "plain text", "Plain text unchanged");
    is(main::escape_html(""), "", "Empty string unchanged");
    is(main::escape_html(undef), "", "Undef returns empty string");
    is(main::escape_html('<img src="x" onerror="alert(1)">'),
       '&lt;img src=&quot;x&quot; onerror=&quot;alert(1)&quot;&gt;',
       "Complex XSS payload fully escaped");
};

# 5. hr_bytes_practical_rnd
subtest 'hr_bytes_practical_rnd' => sub {
    is(main::hr_bytes_practical_rnd(0), "0B", "Zero returns 0B");
    is(main::hr_bytes_practical_rnd(-1), "0B", "Negative returns 0B");
    is(main::hr_bytes_practical_rnd(undef), "0B", "Undef returns 0B");
    is(main::hr_bytes_practical_rnd(1024**3), "1G", "Exactly 1 GB");
    is(main::hr_bytes_practical_rnd(1.5 * 1024**3), "2G", "1.5 GB rounds up to 2G");
    is(main::hr_bytes_practical_rnd(3 * 1024**3), "4G", "3 GB rounds up to 4G");
    is(main::hr_bytes_practical_rnd(5 * 1024**3), "8G", "5 GB rounds up to 8G");
    is(main::hr_bytes_practical_rnd(100 * 1024**2), "1G", "100 MB rounds up to 1G");
};

# 6. hr_raw
subtest 'hr_raw' => sub {
    is(main::hr_raw("1G"), 1024*1024*1024, "1G to bytes");
    is(main::hr_raw("1M"), 1024*1024, "1M to bytes");
    is(main::hr_raw("1K"), 1024, "1K to bytes");
    is(main::hr_raw("1024"), 1024, "Plain number unchanged");
    is(main::hr_raw("0"), "0", "Zero returns 0");
    is(main::hr_raw("NULL"), "0", "NULL returns 0");
    is(main::hr_raw(undef), "0", "Undef returns 0");
    is(main::hr_raw(""), "0", "Empty string returns 0");
    is(main::hr_raw("256M"), 256*1024*1024, "256M to bytes");
};

# 7. get_type_max
subtest 'get_type_max' => sub {
    # Signed types
    is(main::get_type_max("tinyint", "tinyint"), 127, "Signed tinyint");
    is(main::get_type_max("smallint", "smallint"), 32767, "Signed smallint");
    is(main::get_type_max("mediumint", "mediumint"), 8388607, "Signed mediumint");
    is(main::get_type_max("int", "int"), 2147483647, "Signed int");
    is(main::get_type_max("bigint", "bigint"), "9223372036854775807", "Signed bigint");

    # Unsigned types
    is(main::get_type_max("tinyint", "tinyint unsigned"), 255, "Unsigned tinyint");
    is(main::get_type_max("smallint", "smallint unsigned"), 65535, "Unsigned smallint");
    is(main::get_type_max("mediumint", "mediumint unsigned"), 16777215, "Unsigned mediumint");
    is(main::get_type_max("int", "int unsigned"), 4294967295, "Unsigned int");
    is(main::get_type_max("bigint", "bigint unsigned"), "18446744073709551615", "Unsigned bigint");

    # Alias
    is(main::get_type_max("integer", "integer"), 2147483647, "integer alias = int");

    # Case insensitive
    is(main::get_type_max("TINYINT", "TINYINT UNSIGNED"), 255, "Case insensitive");

    # Unknown type fallback
    is(main::get_type_max("varchar", "varchar(255)"), "18446744073709551615", "Unknown type uses bigint unsigned max");

    # Undef handling
    is(main::get_type_max(undef, undef), "18446744073709551615", "Undef falls through to default");
};

# 8. merge_hash
subtest 'merge_hash' => sub {
    my $h1 = { a => 1, b => 2 };
    my $h2 = { b => 99, c => 3 };
    my $merged = main::merge_hash($h1, $h2);
    is(ref($merged), 'HASH', "Returns a hash reference");
    is($merged->{a}, 1, "Key from first hash");
    is($merged->{b}, 2, "Overlapping key keeps first hash value");
    is($merged->{c}, 3, "Key from second hash");

    # Empty hashes
    my $m2 = main::merge_hash({}, { x => 10 });
    is($m2->{x}, 10, "Empty first hash takes second");

    my $m3 = main::merge_hash({ y => 20 }, {});
    is($m3->{y}, 20, "Empty second hash keeps first");
};

# 9. parse_human_size_to_mb
subtest 'parse_human_size_to_mb' => sub {
    is(main::parse_human_size_to_mb("100M"), 100, "100M = 100 MB");
    is(main::parse_human_size_to_mb("1G"), 1024, "1G = 1024 MB");
    is(main::parse_human_size_to_mb("512K"), 0.5, "512K = 0.5 MB");
    is(main::parse_human_size_to_mb("1T"), 1048576, "1T = 1048576 MB");
    is(main::parse_human_size_to_mb("100"), 100, "Plain number defaults to MB");
    is(main::parse_human_size_to_mb("0"), 0, "Zero handled");
    is(main::parse_human_size_to_mb(""), 0, "Empty string returns 0");
    is(main::parse_human_size_to_mb(undef), 0, "Undef returns 0");

    # Case insensitive
    is(main::parse_human_size_to_mb("2g"), 2048, "Lowercase g = 2048 MB");

    # Fractional
    is(main::parse_human_size_to_mb("1.5G"), 1536, "1.5G = 1536 MB");

    # Bytes
    ok(main::parse_human_size_to_mb("1048576B") - 1 < 0.01, "1048576B ≈ 1 MB");
};

# 10. format_recommendation_item
subtest 'format_recommendation_item' => sub {
    # Simple string pass-through
    is(main::format_recommendation_item("Increase innodb_buffer_pool_size"),
       "Increase innodb_buffer_pool_size",
       "Plain string returned as-is");

    # Undef
    is(main::format_recommendation_item(undef), "", "Undef returns empty string");

    # Unused index hash
    my $unused = {
        type   => 'unused_index',
        schema => 'mydb',
        table  => 'users',
        index  => 'idx_email',
    };
    like(main::format_recommendation_item($unused),
         qr/Unused index: mydb\.users \(idx_email\)/,
         "Unused index formatted correctly");

    # Redundant index hash
    my $redundant = {
        type           => 'redundant_index',
        schema         => 'mydb',
        table          => 'orders',
        index          => 'idx_date',
        dominant_index => 'idx_date_status',
        sql            => 'ALTER TABLE orders DROP INDEX idx_date',
    };
    like(main::format_recommendation_item($redundant),
         qr/Redundant index: mydb\.orders \(idx_date\) redundant of idx_date_status/,
         "Redundant index formatted correctly");

    # Generic hash (no type)
    my $generic = { foo => 'bar', baz => 'qux' };
    my $result = main::format_recommendation_item($generic);
    like($result, qr/baz: qux/, "Generic hash contains baz key");
    like($result, qr/foo: bar/, "Generic hash contains foo key");
};

# 11. get_compatible_styles
subtest 'get_compatible_styles' => sub {
    my @snake = main::get_compatible_styles("user_name");
    ok(grep(/snake_case/, @snake), "user_name is snake_case");

    my @camel = main::get_compatible_styles("userName");
    ok(grep(/camelCase/, @camel), "userName is camelCase");

    my @pascal = main::get_compatible_styles("UserName");
    ok(grep(/PascalCase/, @pascal), "UserName is PascalCase");

    my @kebab = main::get_compatible_styles("user-name");
    ok(grep(/kebab-case/, @kebab), "user-name is kebab-case");

    my @upper = main::get_compatible_styles("USER_NAME");
    ok(grep(/UPPER_SNAKE_CASE/, @upper), "USER_NAME is UPPER_SNAKE_CASE");

    # Single lowercase word matches multiple styles
    my @single = main::get_compatible_styles("id");
    ok(scalar @single >= 2, "Single word 'id' matches multiple styles");

    # Empty / undef
    my @empty = main::get_compatible_styles("");
    is(scalar @empty, 0, "Empty string returns no styles");

    my @undef_result = main::get_compatible_styles(undef);
    is(scalar @undef_result, 0, "Undef returns no styles");
};

# 12. find_dominant_style
subtest 'find_dominant_style' => sub {
    # All snake_case
    my @snake_names = ("user_name", "first_name", "last_name", "email_address");
    is(main::find_dominant_style(\@snake_names), "snake_case", "All snake_case detected");

    # Mixed with camelCase dominant
    my @camel_names = ("userName", "firstName", "lastName", "user_name");
    is(main::find_dominant_style(\@camel_names), "camelCase", "camelCase dominant");

    # Empty list defaults to snake_case
    my @empty_names = ();
    is(main::find_dominant_style(\@empty_names), "snake_case", "Empty list defaults to snake_case");

    # UPPER_SNAKE_CASE
    my @upper_names = ("USER_ID", "FIRST_NAME", "LAST_NAME", "EMAIL");
    is(main::find_dominant_style(\@upper_names), "UPPER_SNAKE_CASE", "UPPER_SNAKE_CASE dominant");
};

done_testing();
