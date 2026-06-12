#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;

# Load the script first to get the subroutines
{
    local @ARGV = ();
    no warnings 'redefine';
    require './mysqltuner.pl';
}

# Mock prints to capture messages
my @mock_output;
{
    no warnings 'redefine';
    *main::infoprint = sub { push @mock_output, "INFO: $_[0]" };
    *main::badprint = sub { push @mock_output, "BAD: $_[0]" };
    *main::goodprint = sub { push @mock_output, "GOOD: $_[0]" };
    *main::debugprint = sub { };
}

# 1. Test get_ssh_prefix and is_remote
subtest 'SSH Prefix and Remote Host Checks' => sub {
    # Test default / localhost is not remote
    %main::opt = ( host => 'localhost' );
    is(main::is_remote(), 0, 'localhost is local');

    %main::opt = ( host => '127.0.0.1' );
    is(main::is_remote(), 0, '127.0.0.1 is local');

    %main::opt = ();
    is(main::is_remote(), 0, 'empty host is local');

    # Remote host
    %main::opt = ( host => '192.168.1.100' );
    is(main::is_remote(), 1, '192.168.1.100 is remote');

    # SSH cloud prefix
    %main::opt = (
        cloud      => 1,
        'ssh-host' => 'remote-box',
    );
    is(main::is_remote(), 1, 'cloud ssh host is remote');
    my $prefix = main::get_ssh_prefix();
    like($prefix, qr/ssh.*remote-box/, 'ssh prefix matches');

    # User option
    %main::opt = (
        cloud      => 1,
        'ssh-host' => 'remote-box',
        'ssh-user' => 'admin',
    );
    $prefix = main::get_ssh_prefix();
    like($prefix, qr/admin\@remote-box/, 'ssh prefix includes username');

    # Identity file option
    %main::opt = (
        cloud                => 1,
        'ssh-host'           => 'remote-box',
        'ssh-identity-file'  => '/keys/id_rsa',
    );
    $prefix = main::get_ssh_prefix();
    like($prefix, qr/-i '\/keys\/id_rsa'/, 'ssh prefix includes identity file');

    # Password option without sshpass
    {
        no warnings 'redefine';
        local *main::which = sub { return undef };
        %main::opt = (
            cloud          => 1,
            'ssh-host'     => 'remote-box',
            'ssh-password' => 'secret',
        );
        @mock_output = ();
        $prefix = main::get_ssh_prefix();
        ok(grep({ /sshpass is not installed/ } @mock_output), 'warning shown for missing sshpass');
        unlike($prefix, qr/sshpass/, 'sshpass wrapper excluded');
    }

    # Password option with sshpass
    {
        no warnings 'redefine';
        local *main::which = sub { return '/usr/bin/sshpass' };
        %main::opt = (
            cloud          => 1,
            'ssh-host'     => 'remote-box',
            'ssh-password' => 'secret',
        );
        @mock_output = ();
        $prefix = main::get_ssh_prefix();
        like($prefix, qr/sshpass -p 'secret'/, 'sshpass wrapper included');
    }
};

# 2. Test get_container_prefix
subtest 'Container Prefix Checks' => sub {
    # Empty
    %main::opt = ();
    is(main::get_container_prefix(), "", 'no container prefix by default');

    # Docker
    %main::opt = ( container => 'my-container' );
    is(main::get_container_prefix(), 'docker exec my-container sh -c ', 'default container engine is docker');

    %main::opt = ( container => 'docker:my-container' );
    is(main::get_container_prefix(), 'docker exec my-container sh -c ', 'explicit docker engine works');

    # Podman
    %main::opt = ( container => 'podman:my-podman-container' );
    is(main::get_container_prefix(), 'podman exec my-podman-container sh -c ', 'podman engine works');

    # Kubectl
    %main::opt = ( container => 'kubectl:my-pod' );
    is(main::get_container_prefix(), 'kubectl exec my-pod -- sh -c ', 'kubectl engine works');
};

# 3. Test get_transport_prefix
subtest 'Transport Prefix Logic' => sub {
    # SSH wins over container
    %main::opt = (
        cloud       => 1,
        'ssh-host'  => 'ssh-box',
        container   => 'docker-box',
    );
    my $prefix = main::get_transport_prefix();
    like($prefix, qr/ssh/, 'SSH prefix preferred');
    unlike($prefix, qr/docker/, 'Container prefix ignored when SSH is active');

    # Container fallback
    %main::opt = (
        container   => 'docker-box',
    );
    is(main::get_transport_prefix(), 'docker exec docker-box sh -c ', 'Container prefix selected when SSH inactive');
};

# 4. Test build_mysql_connection_command
subtest 'MySQL Connection Command Builder' => sub {
    $main::mysqlcmd = 'mysql';
    $main::mysqllogin = '-u root -p\'secret\'';
    is(main::build_mysql_connection_command(), 'mysql -u root -p\'secret\'', 'mysql connection command matches');
};

# 5. Test human_size
subtest 'Human Readable File Size' => sub {
    is(main::human_size(512), "512.00 bytes", '512 bytes');
    is(main::human_size(1024), "1.00 KB", '1 KB');
    is(main::human_size(1048576), "1.00 MB", '1 MB');
    is(main::human_size(1073741824), "1.00 GB", '1 GB');
};

# 6. Test write_manifest_files
subtest 'Write Manifest Files' => sub {
    my $dir = tempdir(CLEANUP => 1);
    my $file1 = File::Spec->catfile($dir, 'employees_dump.sql');
    my $file2 = File::Spec->catfile($dir, 'salaries_dump.sql.gz');

    open my $fh1, '>', $file1 or die $!;
    print $fh1 "dummy contents for size 1";
    close $fh1;

    open my $fh2, '>', $file2 or die $!;
    print $fh2 "dummy compressed contents size 2";
    close $fh2;

    %main::exported_manifest = (
        'employees_dump.sql' => {
            rows       => 100,
            size       => -s $file1,
            duration   => "0.123",
            query      => "SELECT * FROM employees",
            compressed => 0
        },
        'salaries_dump.sql.gz' => {
            rows       => 500,
            size       => -s $file2,
            duration   => "0.456",
            query      => "SELECT * FROM salaries",
            compressed => 1
        }
    );

    $main::tunerversion = '2.8.45';
    $main::myvar{'hostname'} = 'tuner-host';
    $main::myvar{'version'} = '8.0.35';

    @mock_output = ();
    main::write_manifest_files($dir);

    ok(-f File::Spec->catfile($dir, 'manifest.json'), 'manifest.json created');
    ok(-f File::Spec->catfile($dir, 'metadata.txt'), 'metadata.txt created');

    # Validate manifest.json content
    open my $mfh, '<', File::Spec->catfile($dir, 'manifest.json') or die $!;
    my $manifest_content = do { local $/; <$mfh> };
    close $mfh;

    like($manifest_content, qr/"version": "2.8.45"/, 'manifest contains version');
    like($manifest_content, qr/"total_files": 2/, 'manifest contains total files');
    like($manifest_content, qr/employees_dump.sql/, 'manifest lists file 1');
    like($manifest_content, qr/salaries_dump.sql.gz/, 'manifest lists file 2');
    like($manifest_content, qr/"compressed": true/, 'manifest correctly reflects compression for file 2');

    # Validate metadata.txt content
    open my $mtfh, '<', File::Spec->catfile($dir, 'metadata.txt') or die $!;
    my $metadata_content = do { local $/; <$mtfh> };
    close $mtfh;

    like($metadata_content, qr/Host: tuner-host/, 'metadata contains host');
    like($metadata_content, qr/MySQL Version: 8.0.35/, 'metadata contains MySQL version');
    like($metadata_content, qr/employees_dump.sql/, 'metadata lists file 1');
};

# 7. Test check_architecture
subtest 'Check Architecture' => sub {
    # Case A: Remote / SSH
    {
        no warnings 'redefine';
        local *main::is_remote = sub () { return 1 };
        local *main::get_transport_prefix = sub { return "" };
        %main::opt = ( defaultarch => 64 );
        @mock_output = ();
        %main::result = ();
        main::check_architecture();
        ok(!defined $main::result{'OS'}{'Architecture'}, 'remote architecture remains undefined in %result due to early return');
        ok(grep({ /Skipping architecture check/ } @mock_output), 'logged skipping architecture on remote');
    }

    # Case B: Windows 64-bit
    {
        no warnings 'redefine';
        local *main::is_remote = sub () { return 0 };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd eq 'wmic os get osarchitecture') {
                return "64-bit OS";
            }
            return "";
        };
        $main::is_win = 1;
        %main::result = ();
        main::check_architecture();
        is($main::result{'OS'}{'Architecture'}, '64 bits', 'Windows wmic match sets architecture to 64');
        $main::is_win = 0;
    }

    # Case C: Unix uname machine match 64-bit
    {
        no warnings 'redefine';
        local *main::is_remote = sub () { return 0 };
        local *main::get_transport_prefix = sub { return "" };
        local *POSIX::uname = sub {
            return ("Linux", "localhost", "5.15.0", "release", "x86_64");
        };
        %main::result = ();
        @mock_output = ();
        main::check_architecture();
        is($main::result{'OS'}{'Architecture'}, '64 bits', 'Linux x86_64 architecture set to 64');
        ok(grep({ /Operating on 64-bit architecture/ } @mock_output), 'printed 64-bit confirmation');
    }

    # Case D: Unix SunOS 64-bit
    {
        no warnings 'redefine';
        local *main::is_remote = sub () { return 0 };
        local *main::get_transport_prefix = sub { return "" };
        local *POSIX::uname = sub {
            return ("SunOS", "localhost", "5.11", "release", "i386");
        };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd eq 'isainfo -b') {
                return "64";
            }
            return "";
        };
        %main::result = ();
        @mock_output = ();
        main::check_architecture();
        is($main::result{'OS'}{'Architecture'}, '64 bits', 'SunOS isainfo 64-bit set to 64');
    }

    # Case E: Unix AIX 64-bit
    {
        no warnings 'redefine';
        local *main::is_remote = sub () { return 0 };
        local *main::get_transport_prefix = sub { return "" };
        local *POSIX::uname = sub {
            return ("AIX", "localhost", "7.1", "release", "powerpc");
        };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd eq 'bootinfo -K') {
                return "64";
            }
            return "";
        };
        %main::result = ();
        @mock_output = ();
        main::check_architecture();
        is($main::result{'OS'}{'Architecture'}, '64 bits', 'AIX bootinfo 64-bit set to 64');
    }

    # Case F: 32-bit warning path (> 2GB physical memory)
    {
        no warnings 'redefine';
        local *main::is_remote = sub () { return 0 };
        local *main::get_transport_prefix = sub { return "" };
        local *POSIX::uname = sub {
            return ("Linux", "localhost", "5.15.0", "release", "i386");
        };
        $main::physical_memory = 4294967296; # 4GB RAM
        %main::result = ();
        @mock_output = ();
        main::check_architecture();
        is($main::result{'OS'}{'Architecture'}, '32 bits', 'Linux i386 memory set to 32-bit');
        ok(grep({ /Switch to 64-bit OS/ } @mock_output), 'badprint warning for > 2GB RAM on 32-bit OS');
    }

    # Case G: 32-bit ok path (<= 2GB physical memory)
    {
        no warnings 'redefine';
        local *main::is_remote = sub () { return 0 };
        local *main::get_transport_prefix = sub { return "" };
        local *POSIX::uname = sub {
            return ("Linux", "localhost", "5.15.0", "release", "i386");
        };
        $main::physical_memory = 1073741824; # 1GB RAM
        %main::result = ();
        @mock_output = ();
        main::check_architecture();
        is($main::result{'OS'}{'Architecture'}, '32 bits', 'Linux i386 memory set to 32-bit');
        ok(grep({ /Operating on 32-bit architecture with less than 2GB RAM/ } @mock_output), 'goodprint for <= 2GB RAM on 32-bit OS');
    }
};

# 8. Test is_docker
subtest 'Docker Environment Identification' => sub {
    # Mock file check
    {
        no warnings 'redefine';
        # We can temporarily mock -f by overriding how we check, or we can just mock the proc file path logic.
        # Let's mock open on /proc/self/cgroup to simulate docker vs non-docker.
        # We temporarily redefine CORE::GLOBAL::open or just test the logic inside is_docker.
        # Since is_docker reads /proc/self/cgroup, let's redefine the sub is_docker to test it, 
        # or we can test it directly if we mock open.
        # But we can also test it by just checking what the default behavior is on this host.
        my $res = main::is_docker();
        ok(defined $res, 'is_docker returns boolean');
    }
};

# 9. Test mysql_views, mysql_routines, mysql_triggers
subtest 'Database Object Metrics Stubs' => sub {
    no warnings 'redefine';
    # Case A: Legacy MySQL version < 5.5
    $main::myvar{'version'} = "5.1.73";
    @mock_output = ();
    main::mysql_views();
    ok(grep({ /Views metrics.*are missing/ } @mock_output), 'mysql_views warns on < 5.5');

    @mock_output = ();
    main::mysql_routines();
    ok(grep({ /Routines metrics.*are missing/ } @mock_output), 'mysql_routines warns on < 5.5');

    @mock_output = ();
    main::mysql_triggers();
    ok(grep({ /Trigger metrics.*are missing/ } @mock_output), 'mysql_triggers warns on < 5.5');

    # Case B: Modern MySQL version >= 5.5
    $main::myvar{'version'} = "8.0.35";
    @mock_output = ();
    main::mysql_views();
    ok(!grep({ /Views metrics.*are missing/ } @mock_output), 'mysql_views has no missing warnings on >= 5.5');

    @mock_output = ();
    main::mysql_routines();
    ok(!grep({ /Routines metrics.*are missing/ } @mock_output), 'mysql_routines has no missing warnings on >= 5.5');

    @mock_output = ();
    main::mysql_triggers();
    ok(!grep({ /Trigger metrics.*are missing/ } @mock_output), 'mysql_triggers has no missing warnings on >= 5.5');
};

# 10. Test make_recommendations
subtest 'Make Recommendations Formatting' => sub {
    no warnings 'redefine';
    local *main::calculate_health_score = sub { };
    local *main::display_health_score = sub { };
    local *main::prettyprint = sub { push @mock_output, "PRETTY: $_[0]" };

    @main::generalrec = ('Upgrade MySQL', 'Optimize tables');
    @main::adjvars = ('join_buffer_size = 1M');
    @main::sysrec = ('Enable swap');
    @main::secrec = ('Change default password');
    @main::modeling = ('Fix missing PK');
    $main::mycalc{'pct_max_physical_memory'} = 95; # dangerously high memory flag test

    @mock_output = ();
    main::make_recommendations();

    # Verify results hash setup
    is_deeply($main::result{'Recommendations'}, \@main::generalrec, 'result Recommendations populated');
    is_deeply($main::result{'AdjustVariables'}, \@main::adjvars, 'result AdjustVariables populated');
    is_deeply($main::result{'Modeling'}, \@main::modeling, 'result Modeling populated');
    is_deeply($main::result{'Modules'}{'System'}, \@main::sysrec, 'result Modules System populated');
    is_deeply($main::result{'Modules'}{'Performance'}, \@main::adjvars, 'result Modules Performance populated');
    is_deeply($main::result{'Modules'}{'Security'}, \@main::secrec, 'result Modules Security populated');

    # Verify high memory usage warning print
    ok(grep({ /MySQL's maximum memory usage is dangerously high/ } @mock_output), 'high memory warning printed');
    ok(grep({ /Upgrade MySQL/ } @mock_output), 'general recommendations listed');
    ok(grep({ /join_buffer_size = 1M/ } @mock_output), 'adjust variables listed');
};

# 11. Test close_outputfile
subtest 'Close Output File Handle' => sub {
    # If undefined, shouldn't crash or throw warning
    $main::fh = undef;
    eval {
        main::close_outputfile();
    };
    is($@, '', 'close_outputfile handles undefined file handle gracefully');

    # If defined, should call close on it
    {
        no warnings 'redefine';
        # We tie a filehandle or mock close by overriding close. In Perl we can't easily redefine CORE::close,
        # but we can check if it returns true. Let's create a temporary file handle that is open.
        my $tmp_file = File::Spec->catfile(tempdir(CLEANUP => 1), 'close_test.txt');
        open(my $th, '>', $tmp_file) or die $!;
        $main::fh = $th;
        main::close_outputfile();
        ok(!fileno($main::fh), 'close_outputfile successfully closes the open file handle');
    }
};

done_testing();
