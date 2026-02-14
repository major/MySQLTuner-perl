use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;

my $script = File::Spec->catfile(dirname(__FILE__), '..', 'mysqltuner.pl');

# 1. Test validation - Invalid Port (Caught by Getopt::Long)
my $output = `perl $script --port abc 2>&1`;
like($output, qr/invalid for option port/i, "Should catch non-numeric port");

# 2. Test validation - Invalid DefaultArch (Caught by custom validation)
$output = `perl $script --defaultarch 48 2>&1`;
like($output, qr/Error: Invalid value for --defaultarch: 48/, "Should catch invalid architecture (must be 32 or 64)");

# 3. Test validation - Valid Port
$output = `perl $script --port 3307 --help 2>&1`;
is($?, 0, "Should allow valid numeric port");

# 4. Test pod2usage fix - check that it doesn't show warnings for missing sections
$output = `perl $script --invalid-option 2>&1`;
unlike($output, qr/at .* line \d+/, "pod2usage should not trigger internal warnings about missing sections");
like($output, qr/Important Usage Guidelines:/i, "pod2usage should show existing sections");
like($output, qr/Options:/i, "pod2usage should show existing Options section");

done_testing();
