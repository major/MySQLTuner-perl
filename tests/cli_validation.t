use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;

my $script = File::Spec->catfile(dirname(__FILE__), '..', 'mysqltuner.pl');

# 1. Test validation - Invalid Port (Caught by Getopt::Long)
my $output = `perl $script --port abc 2>&1`;
like($output, qr/invalid for option port/i, "Should catch non-numeric port");

# 2. Test validation - Invalid DefaultArch (Caught by custom validation)
$output = `perl $script --defaultarch 48 2>&1`;
like($output, qr/ERROR:\s+Value "48" invalid for option defaultarch/, "Should catch invalid architecture (must be 32 or 64)");

# 3. Test validation - Valid Port
$output = `perl $script --port 3307 --help 2>&1`;
is($?, 0, "Should allow valid numeric port");

# 4. Test error format - check that it doesn't show warnings for missing sections
$output = `perl $script --invalid-option 2>&1`;
unlike($output, qr/at .* line \d+/, "pod2usage should not trigger internal warnings about missing sections");
like($output, qr/Unknown option: invalid-option/i, "Should show unknown option error");
like($output, qr/mysqltuner failed with errors/i, "Should show failed with errors message");

# 5. Test missing value for an option that requires an argument
$output = `perl $script --port 2>&1`;
like($output, qr/Option port requires an argument/i, "Should show error for missing argument");
like($output, qr/mysqltuner failed with errors/i, "Should show failed with errors message for missing argument");

# 6. Test authentication failure (wrong credentials)
$output = `perl $script --user nonexistent --pass wrong 2>&1`;
like($output, qr/Attempted to use login credentials, but they were invalid/i, "Should show invalid credentials error");

done_testing();
