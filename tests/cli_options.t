use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;

my $script = File::Spec->catfile(dirname(__FILE__), '..', 'mysqltuner.pl');

# 1. Check help command
my $help_output = `perl $script --help 2>&1`;
is($?, 0, "--help should return 0");
like($help_output, qr/MySQLTuner/, "Help should mention MySQLTuner");
like($help_output, qr/CONNECTION AND AUTHENTICATION/, "Help should have CONNECTION category");
like($help_output, qr/--server-log/, "Help should mention --server-log");

# 2. Check defaults in help
like($help_output, qr/--host <host>\s+Connect to a remote host/, "Help should show host option description");
like($help_output, qr/--port <port>.*\(default: 3306\)/, "Help should show correct port default");

# 3. Check negatable options aliases
like($help_output, qr/--colstat \(--no-colstat\)/, "Help should show negation aliases for colstat");
like($help_output, qr/--pfstat \(--no-pfstat\)/, "Help should show negation aliases for pfstat");

# 4. Check for absolute path leak (best practice 12)
unlike($help_output, qr/home\/jmren/, "Help should not contain absolute workstation paths");

done_testing();
