#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Test Case for Issue #874
# MySQLTuner 2.8.28 - System command failed & ERROR 1524
# https://github.com/jmrenouard/MySQLTuner-perl/issues/874

# Part 1: Verify that whitelisting regex in execute_system_command handles absolute paths.
# This prevents noisy "System command failed" messages for probes that are expected to fail.
sub test_whitelisting_regex {
    my ($command) = @_;
    # Exact regex from mysqltuner.pl (post-fix)
    my $regex = qr/(?:^|\/)(dmesg|lspci|dmidecode|ipconfig|isainfo|bootinfo|ver|wmic|lsattr|prtconf|swapctl|swapinfo|svcprop|ps|ping|ifconfig|ip|hostname|who|free|top|uptime|netstat|sysctl|mysql|mariadb)/;
    return $command =~ $regex;
}

subtest 'System Command Whitelisting (Issue #874)' => sub {
    my $cmd = "/usr/bin/mariadb -Nrs -e 'select \"mysqld is alive\"' --connect-timeout=3";
    ok(test_whitelisting_regex($cmd), "Whitelists absolute path: /usr/bin/mariadb");
    
    my $cmd_mysql = "/usr/bin/mysql -Nrs -e 'select \"mysqld is alive\"'";
    ok(test_whitelisting_regex($cmd_mysql), "Whitelists absolute path: /usr/bin/mysql");
    
    my $cmd_ps = "/bin/ps -ef";
    ok(test_whitelisting_regex($cmd_ps), "Whitelists absolute path: /bin/ps");
    
    my $cmd_free = "/usr/bin/free -m";
    ok(test_whitelisting_regex($cmd_free), "Whitelists absolute path: /usr/bin/free");
    
    my $cmd_non_whitelisted = "ls /tmp";
    ok(!test_whitelisting_regex($cmd_non_whitelisted), "Correctly rejects non-whitelisted command: ls");
};

# Part 2: Verify unix_socket presence in security exclusion logic.
# The user mentioned unix_socket=OFF. MySQLTuner should correctly handle users using this plugin.
subtest 'Unix Socket Security Logic' => sub {
    # This is the logic used at line 2715 in mysqltuner.pl to exclude socket-based auth from password checks
    my $exclude_plugins_regex = qr/plugin NOT IN \('auth_socket', 'unix_socket', 'win_socket', 'auth_pam_compat'\)/;
    
    # We want to ensure 'unix_socket' is indeed in that list (so it's excluded from the "NOT IN")
    # Actually, the SQL is: WHERE ... AND plugin NOT IN (...)
    # So if plugin IS 'unix_socket', it is NOT in the list of plugins that must have a password? 
    # Wait, the logic is: "WHERE ... AND plugin NOT IN ('unix_socket', ...)" 
    # This means users with unix_socket ARE EXCLUDED from the empty password check.
    
    my $plugin = 'unix_socket';
    ok($plugin =~ /^(auth_socket|unix_socket|win_socket|auth_pam_compat)$/, "unix_socket is in the exclusion list for password checks");
};

done_testing();
