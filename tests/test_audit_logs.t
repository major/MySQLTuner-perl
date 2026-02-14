#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;

# Regression tests for build/audit_logs.pl

my $audit_script = 'build/audit_logs.pl';

# 1. Check if script exists and is executable
ok(-x $audit_script, 'Audit script is executable');

# 2. Test with no anomalies
sub test_no_anomalies {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $log_dir = File::Spec->catdir($tmpdir, 'TestRun');
    mkdir $log_dir;
    my $log_file = File::Spec->catfile($log_dir, 'execution.log');
    
    open my $fh, '>', $log_file or die $!;
    print $fh "Infrastructure startup OK\n";
    print $fh "MySQLTuner execution finished successfully\n";
    close $fh;
    
    my $output = `perl $audit_script --dir=$tmpdir 2>&1`;
    my $exit_code = $? >> 8;
    
    is($exit_code, 0, 'Exit code 0 for no anomalies');
    like($output, qr/No anomalies found/, 'Correct output for no anomalies');
}

# 3. Test with Performance Schema anomaly
sub test_pfs_anomaly {
    my $tmpdir = tempdir(CLEANUP => 1);
    mkdir File::Spec->catdir($tmpdir, 'Subdir');
    my $log_file = File::Spec->catfile($tmpdir, 'Subdir', 'execution.log');
    
    open my $fh, '>', $log_file or die $!;
    print $fh "✘ Performance_schema should be activated.\n";
    close $fh;
    
    my $output = `perl $audit_script --dir=$tmpdir 2>&1`;
    my $exit_code = $? >> 8;
    
    is($exit_code, 1, 'Exit code 1 for PFS anomaly');
    like($output, qr/Performance Schema Disabled/, 'Detected PFS anomaly');
}

# 4. Test with SQL Execution Failure
sub test_sql_failure {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $log_file = File::Spec->catfile($tmpdir, 'execution.log');
    
    open my $fh, '>', $log_file or die $!;
    print $fh "FAIL Execute SQL: SELECT * FROM non_existing_table\n";
    close $fh;
    
    my $output = `perl $audit_script --dir=$tmpdir 2>&1`;
    my $exit_code = $? >> 8;
    
    is($exit_code, 1, 'Exit code 1 for SQL failure');
    like($output, qr/SQL Execution Failure/, 'Detected SQL failure');
}

# 5. Test with Perl Warning
sub test_perl_warning {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $log_file = File::Spec->catfile($tmpdir, 'execution.log');
    
    open my $fh, '>', $log_file or die $!;
    print $fh "Use of uninitialized value in concatenation (.) at mysqltuner.pl line 123.\n";
    close $fh;
    
    my $output = `perl $audit_script --dir=$tmpdir 2>&1`;
    my $exit_code = $? >> 8;
    
    is($exit_code, 1, 'Exit code 1 for Perl warning');
    like($output, qr/Perl Warning/, 'Detected Perl warning');
}

test_no_anomalies();
test_pfs_anomaly();
test_sql_failure();
test_perl_warning();

done_testing();
