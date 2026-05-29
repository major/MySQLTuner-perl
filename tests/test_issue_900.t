#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
no warnings 'once';
use File::Basename;
use File::Spec;

# Setup environment for MySQLTuner
$main::is_remote = 0;
$main::mysqlcmd = "mysql";
$main::mysqllogin = "";
$main::remotestring = "";
$main::devnull = File::Spec->devnull();

# Load the script first to get the subroutines
{
    local @ARGV = ();
    no warnings 'redefine';
    my $script_dir = dirname(File::Spec->rel2abs(__FILE__));
    my $script = File::Spec->catfile($script_dir, '..', 'mysqltuner.pl');
    require $script;
}

# Mock functions
my @mock_output;
my @mocked_sys_commands;
{
    no warnings 'redefine';
    *main::infoprint = sub { diag "MOCK INFO: $_[0]"; push @mock_output, "INFO: $_[0]" };
    *main::badprint = sub { diag "MOCK BAD: $_[0]"; push @mock_output, "BAD: $_[0]" };
    *main::goodprint = sub { diag "MOCK GOOD: $_[0]"; push @mock_output, "GOOD: $_[0]" };
    *main::debugprint = sub { diag "MOCK DEBUG: $_[0]"; push @mock_output, "DEBUG: $_[0]" };
    *main::subheaderprint = sub { diag "MOCK SUBHEADER: $_[0]"; push @mock_output, "SUBHEADER: $_[0]" };
    *main::prettyprint = sub { };

    *main::execute_system_command = sub {
        my ($cmd) = @_;
        push @mocked_sys_commands, $cmd;
        return "";
    };

    *main::select_one = sub { return 0; };
    *main::get_password_column_name = sub { return 'authentication_string'; };
}

# 1. Test get_state_file_path
subtest 'get_state_file_path formatting' => sub {
    $main::opt{host} = '127.0.0.1';
    $main::opt{port} = 3306;
    $main::opt{socket} = undef;
    $main::opt{'ssh-host'} = undef;
    $main::opt{container} = undef;
    my $path = main::get_state_file_path();
    like($path, qr/127\.0\.0\.1_3306$/, 'Should format host and port in file path');

    $main::opt{'ssh-host'} = 'ssh.example.com';
    $main::opt{container} = 'my-container';
    my $path_with_transport = main::get_state_file_path();
    like($path_with_transport, qr/127\.0\.0\.1_3306_ssh_ssh\.example\.com_container_my-container$/, 'Should include sanitized ssh-host and container in path');
};

# 2. Test adjust_aborted_connects with simulated state
subtest 'adjust_aborted_connects logic' => sub {
    use File::Temp ();
    my ($temp_fh, $temp_state_file) = File::Temp::tempfile(UNLINK => 1);
    close($temp_fh);
    
    # Mock get_state_file_path to use our test state file
    no warnings 'redefine';
    local *main::get_state_file_path = sub { return $temp_state_file; };

    # Scenario A: Server has not restarted (uptime is larger or equal to stored)
    %main::mystat = (
        'Uptime' => 500,
        'Aborted_connects' => 1000,
        'Connections' => 2000,
    );
    
    # Write a mock state: uptime 100, attempts 620
    open(my $fh, '>', $temp_state_file) or die $!;
    print $fh "100:620\n";
    close($fh);

    ($main::mystat{'Aborted_connects'}, $main::mystat{'Connections'}) = main::adjust_aborted_connects();

    is($main::mystat{'Aborted_connects'}, 1000 - 620, 'Should subtract stored attempts from Aborted_connects');
    is($main::mystat{'Connections'}, 2000 - 620, 'Should subtract stored attempts from Connections');
    is($main::previous_failed_attempts, 620, 'Should load previous_failed_attempts');

    # Scenario B: Server has restarted (uptime is less than stored)
    %main::mystat = (
        'Uptime' => 50,
        'Aborted_connects' => 10,
        'Connections' => 20,
    );
    $main::previous_failed_attempts = 0;

    # Write a mock state: uptime 100, attempts 620
    open($fh, '>', $temp_state_file) or die $!;
    print $fh "100:620\n";
    close($fh);

    ($main::mystat{'Aborted_connects'}, $main::mystat{'Connections'}) = main::adjust_aborted_connects();

    is($main::mystat{'Aborted_connects'}, 10, 'Should not subtract stored attempts if server restarted');
    is($main::mystat{'Connections'}, 20, 'Should not subtract stored connections if server restarted');
    is($main::previous_failed_attempts, 0, 'previous_failed_attempts should remain 0');
};

# 3. Test offline password check for mysql_native_password
subtest 'offline password check logic' => sub {
    use File::Temp ();
    my ($pw_fh, $pw_file) = File::Temp::tempfile(UNLINK => 1);
    print $pw_fh "weakpassword123\n";
    close($pw_fh);

    $main::basic_password_files = $pw_file;
    $main::myvar{'version'} = "8.0.25"; 
    $main::myvar{'version_comment'} = "MySQL";
    $main::opt{skippassword} = 0;
    $main::opt{user} = 'root';
    $main::opt{'max-password-checks'} = 100;

    # Mock select_array to return a user list with a weak mysql_native_password hash
    # Hash for "weakpassword123":
    # Digest::SHA::sha1("weakpassword123") -> binary
    # Digest::SHA::sha1_hex(binary) -> e43f5ee161f95161ac77ef4e9d784f784e123d3c
    # Double SHA1 hex -> e43f5ee161f95161ac77ef4e9d784f784e123d3c (which is *E43F5EE161F95161AC77EF4E9D784F784E123D3C)
    no warnings 'redefine';
    local *main::select_array = sub {
        my ($sql) = @_;
        if ($sql =~ /FROM mysql.user/ || $sql =~ /FROM mysql.global_priv/) {
            return (
                "root\thostname\tmysql_native_password\t*E43F5EE161F95161AC77EF4E9D784F784E123D3C"
            );
        }
        return ();
    };

    @main::generalrec = ();
    @mock_output = ();
    @mocked_sys_commands = ();
    $main::failed_connection_attempts = 0;

    main::security_recommendations();

    # Check if weak password was detected offline (without leaking password in message)
    my @found = grep { /User 'root'\@'hostname' is using a weak password/ } @mock_output;
    ok(scalar(@found) > 0, 'Offline check detected weak native password');
    is($main::failed_connection_attempts, 3, 'Only 3 behavioral checks failed attempts should be recorded');
};

# 4. Test security protections: symlinks, atomic writes, and password leaks
subtest 'security protections checks' => sub {
    # A. Ensure plaintext password is not leaked in mock outputs
    my @leaked = grep { /weakpassword123/ } @mock_output;
    is(scalar(@leaked), 0, 'Plaintext password should not be leaked in diagnostic messages');

    # B. Symlink protection test
    use File::Temp ();
    my ($target_fh, $target_file) = File::Temp::tempfile(UNLINK => 1);
    close($target_fh);

    my $symlink_file = File::Spec->catfile(dirname($target_file), "mysqltuner_symlink_test_" . int(rand(100000)));
    symlink($target_file, $symlink_file) or diag "Could not create symlink: $!";

    if (-l $symlink_file) {
        # Mock get_state_file_path to return the symlink
        no warnings 'redefine';
        local *main::get_state_file_path = sub { return $symlink_file; };

        # Run adjust_aborted_connects
        %main::mystat = (
            'Uptime' => 500,
            'Aborted_connects' => 1000,
            'Connections' => 2000,
        );
        my ($ab_adj, $conn_adj) = main::adjust_aborted_connects();
        is($ab_adj, 1000, 'adjust_aborted_connects should skip symlinks');

        # Run save_aborted_connects_state
        $main::failed_connection_attempts = 10;
        main::save_aborted_connects_state();
        
        # Verify target file remained empty (did not write through symlink)
        my $target_size = (stat($target_file))[7] // 0;
        is($target_size, 0, 'save_aborted_connects_state should not write through symlink');
        
        unlink($symlink_file);
    } else {
        diag "Skipping symlink test: symlinks not supported on this OS";
    }

    # C. Atomic Write & Permissions check
    my ($tmp_fh2, $test_state_file) = File::Temp::tempfile(UNLINK => 1);
    close($tmp_fh2);
    unlink($test_state_file); # ensure it doesn't exist yet

    no warnings 'redefine';
    local *main::get_state_file_path = sub { return $test_state_file; };

    %main::mystat = ( 'Uptime' => 300 );
    $main::previous_failed_attempts = 5;
    $main::failed_connection_attempts = 15;

    main::save_aborted_connects_state();

    ok(-f $test_state_file, 'State file should be created');
    if (-f $test_state_file) {
        # Verify content
        open(my $rfh, '<', $test_state_file);
        my $content = <$rfh>;
        close($rfh);
        chomp($content) if defined $content;
        is($content, "300:20", 'State file content should be uptime:total_attempts');

        # Verify mode is 0600 (permission checks only on Unix-like OS)
        if ($^O ne 'MSWin32') {
            my $mode = (stat($test_state_file))[2];
            is($mode & 07777, 0600, 'State file mode should be 0600');
        }
    }
};

# 5. Test replication standalone detection (issue #900)
subtest 'replication standalone detection' => sub {
    @mock_output = ();
    %main::myvar = (
        'version' => '10.5.15-MariaDB',
        'have_galera' => 'NO',
        'binlog_format' => 'MIXED',
        'innodb_support_xa' => 'ON',
    );
    
    # Simulate empty SHOW REPLICA STATUS / SHOW SLAVE STATUS returning empty array
    my @mysqlreplica = ();
    %main::myrepl = ();
    main::arr2hash( \%main::myrepl, \@mysqlreplica, ':' );

    # Run the terminology mapping logic (the one wrapped in the fix)
    if ( scalar( keys %main::myrepl ) > 0 ) {
        $main::myrepl{'Seconds_Behind_Replica'} = $main::myrepl{'Seconds_Behind_Source'}
          // $main::myrepl{'Seconds_Behind_Master'}
          if !defined $main::myrepl{'Seconds_Behind_Replica'};
        $main::myrepl{'Replica_IO_Running'} = $main::myrepl{'Replica_IO_Running'}
          // $main::myrepl{'Slave_IO_Running'}
          if !defined $main::myrepl{'Replica_IO_Running'};
        $main::myrepl{'Replica_SQL_Running'} = $main::myrepl{'Replica_SQL_Running'}
          // $main::myrepl{'Slave_SQL_Running'}
          if !defined $main::myrepl{'Replica_SQL_Running'};
    }

    %main::myreplicas = ();

    # Execute replication status analysis
    main::get_replication_status();

    # Assertions
    my @standalone_found = grep { /This is a standalone server/ } @mock_output;
    ok(scalar(@standalone_found) > 0, 'Should detect standalone server when replication is empty');

    my @bad_found = grep { /This replication replica is not running/ } @mock_output;
    is(scalar(@bad_found), 0, 'Should not output replica not running warnings on standalone server');

    my @parallel_found = grep { /Parallel replication/ } @mock_output;
    is(scalar(@parallel_found), 0, 'Should not output parallel replication warnings on standalone server');
};

done_testing();
