#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir tempfile);
use File::Spec;

# 1. Load MySQLTuner logic
# Set $opt{nocolor} before requiring to avoid color codes in output
$main::opt{nocolor} = 1;
$main::opt{nocolor} = 1;
require './mysqltuner.pl';

# Initialize print styles usually set in setup_environment
$main::good = '[OK]';
$main::bad  = '[!!]';
$main::info = '[--]';
$main::deb  = '[DG]';
$main::end  = '';

# Mocking execute_system_command to simulate environment
my $mock_system_output = '';
{
    no warnings 'redefine';
    *main::execute_system_command = sub {
        my $cmd = shift;
        if ($cmd =~ /systemctl list-units/) {
            return $mock_system_output;
        }
        return `sh -c "$cmd"`;
    };
}

# Test get_log_file_real_path detection logic
subtest 'get_log_file_real_path detection' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    
    # 1. Test systemd detection
    $mock_system_output = "mariadb.service\n";
    
    my $path = main::get_log_file_real_path('/nonexistent/log', 'myhost', '/tmp/');
    if (main::which('journalctl', $ENV{'PATH'})) {
        is($path, 'systemd:mariadb.service', 'Detected mariadb.service via systemctl');
    }
};

# Test log_file_recommendations with syslog mock
subtest 'syslog fallback in log_file_recommendations' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $syslog_path = File::Spec->catfile($tmpdir, 'syslog');
    
    open my $fh, '>', $syslog_path or die $!;
    print $fh "Feb 14 14:00:00 server mysqld[123]: [ERROR] [MY-010119] [Server] Aborting\n";
    print $fh "Feb 14 14:00:01 server mariadb[124]: [Warning] Some warning\n";
    close $fh;
    
    @main::generalrec = ();
    %main::myvar = (
        log_error => $syslog_path,
        hostname => 'localhost',
        datadir => $tmpdir
    );
    $main::maxlines = 100;
    
    # Use temporary file to capture STDOUT
    my ($out_fh, $out_path) = tempfile(DIR => $tmpdir, UNLINK => 1);
    
    # Redirect STDOUT to capture output
    open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!";
    open STDOUT, '>', $out_path or die "Can't redirect STDOUT: $!";
    
    main::log_file_recommendations();
    
    open STDOUT, ">&", $oldout or die "Can't restore STDOUT: $!";
    
    # Read output back
    open my $in, '<', $out_path or die "Can't read output: $!";
    my $output = do { local $/; <$in> };
    close $in;
    
    # Since it's a mock syslog, it should contain 1 error and 1 warning
    like($output, qr/contains 1 warning/, 'Detected warning in mock syslog');
    like($output, qr/contains 1 error/, 'Detected error in mock syslog');
};

done_testing();
