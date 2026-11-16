#!/usr/bin/env perl
# tests/challenge_m2_adversarial.t
# Adversarial Empirical Challenge Suite for Milestone 2:
#   1. Challenge 1: Process Telemetry & Caching Under Path Variations & Malformed Input
#   2. Challenge 2: Windows Swap Boundary Conditions (0 Swap, Paging Disabled, Scaling)
#   3. Challenge 3: Windows Username Resolution & Fatal getpwuid Interception
#   4. Challenge 4: Outputfile Color Sanitization Under Multi-Flag Permutations
#   5. Challenge 5: Update Tuner Version Hermetic Target Isolation & Truncated Downloads
#   6. Challenge 6: infocmd_tab Output Capture Context & Query Deduplication Invariance
#   7. Challenge 7: Kernel Sysctl & Filesystem Mountpoint Format Verification

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Cwd 'abs_path';

# Intercept CORE::GLOBAL::exit
BEGIN {
    *CORE::GLOBAL::exit = sub { die "MOCK_EXIT\n" };
}

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Pre-declare required globals
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;
our @adjvars;
our @generalrec;
our @sysrec;
our @secrec;
our $outputfile;
our $fh;
our $me;
our $good;
our $bad;
our $cmd;
our $end;
our $is_win;
our $cached_other_process_memory;
our $update_target_dir;

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# =====================================================================
# Challenge 1: Process Telemetry & Caching Under Path Variations & Malformed Input
# =====================================================================
subtest 'Challenge 1: Process telemetry, daemon paths, caching, and malformed ps output' => sub {
    local $main::opt{noprocess} = 0;
    local $main::opt{tbstat}    = 1;
    local $main::is_win         = 0;
    local $main::cached_other_process_memory = undef;

    my @adversarial_ps = (
        "  PID   RSS %CPU COMMAND",
        " 101   1024  0.1 /usr/local/mysql-8.0.35/bin/mysqld --defaults-file=/etc/my.cnf",
        " 102   2048  0.2 /usr/sbin/mariadbd --user=mysql --plugin-dir=/usr/lib/mysql",
        " 103   4096  0.3 /usr/bin/garbd -a gcomm://192.168.1.1 -g cluster1",
        " 104    512  0.0 /opt/percona/bin/mysqld_safe",
        " 105   8192  1.0 /usr/bin/python3 /opt/app/worker.py",
        " 106  16384  2.5 nginx: worker process",
        " 107      0  0.0 [kworker/u16:1-events_unbound]",
        " 108    256  0.0 /lib/systemd/systemd --user",
        " MALFORMED LINE WITHOUT PID",
        " 999        0.0 invalid_fields",
        " 109   4096  0.5 /usr/bin/redis-server 127.0.0.1:6379"
    );

    my $exec_count = 0;
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        $exec_count++ if $cmd =~ /ps eaxo/;
        return @adversarial_ps;
    };

    # First call: parses and calculates
    my $mem1 = main::get_other_process_memory();

    # Expected: python3 (8192) + nginx (16384) + redis-server (4096) = 28672 KB = 29360128 Bytes
    # mysqld, mariadbd, garbd, mysqld_safe, systemd, [kworker], and malformed lines must be skipped.
    is($mem1, 28672 * 1024, 'Filtered correctly to 28672 KB across path variants and malformed lines');
    is($exec_count, 1, 'ps executed exactly once on first call');

    # Second call: must use cached value without running ps again
    my $mem2 = main::get_other_process_memory();
    is($mem2, 28672 * 1024, 'Cached memory matches first call');
    is($exec_count, 1, 'ps was NOT executed on second call (cache hit)');

    # Test fast return when opt{noprocess} = 1
    local $main::opt{noprocess} = 1;
    local $main::cached_other_process_memory = undef;
    my $mem_noproc = main::get_other_process_memory();
    is($mem_noproc, 0, 'Returns 0 immediately when $opt{noprocess} is 1');
    is($exec_count, 1, 'Zero ps executions when $opt{noprocess} is active');
};

# =====================================================================
# Challenge 2: Windows Swap Boundary Conditions (0 Swap, Paging Disabled, Scaling)
# =====================================================================
subtest 'Challenge 2: Windows swap boundary conditions (0 swap, disabled paging, scaling)' => sub {
    local $^O = 'MSWin32';
    local $main::is_win = 1;
    local $main::opt{forcemem} = 0;
    local $main::opt{tbstat}   = 0;

    # Scenario A: 0 swap (paging completely disabled on Windows host)
    {
        my $memerror_tripped = 0;
        no warnings 'redefine';
        local *main::memerror = sub { $memerror_tripped++; die "memerror_fatal\n" };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            return "17179869184\n" if $cmd =~ /TotalPhysicalMemory/;
            return "0\n" if $cmd =~ /FreeVirtualMemory/;
            return "";
        };

        eval { main::os_setup(); };
        is($@, '', 'os_setup survives 0 swap without dying');
        is($memerror_tripped, 0, 'memerror was not triggered for swap == 0');
        is($main::result{'OS'}{'Swap Memory'}{'bytes'}, 0, 'Swap memory bytes is 0');
        is($main::result{'OS'}{'Swap Memory'}{'pretty'}, "0B", 'Swap memory pretty format is 0B');
    }

    # Scenario B: High swap memory scaling (e.g. 64 GB swap = 67108864 KB)
    {
        no warnings 'redefine';
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            return "68719476736\n" if $cmd =~ /TotalPhysicalMemory/; # 64 GB
            return "67108864\n"    if $cmd =~ /FreeVirtualMemory/;   # 64 GB in KB
            return "";
        };

        main::os_setup();
        is($main::result{'OS'}{'Swap Memory'}{'bytes'}, 67108864 * 1024, 'Scaled 64GB KB to bytes accurately');
        is($main::result{'OS'}{'Swap Memory'}{'pretty'}, "64.0G", 'Pretty format displays 64.0G');
    }

    # Scenario C: Non-numeric garbage string from both providers
    {
        my $memerror_tripped = 0;
        no warnings 'redefine';
        local *main::memerror = sub { $memerror_tripped++; die "memerror_fatal\n" };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            return "17179869184\n" if $cmd =~ /TotalPhysicalMemory/;
            return "Error: Access Denied\n" if $cmd =~ /powershell.*FreeVirtualMemory/;
            return "No Instance(s) Available.\n" if $cmd =~ /wmic.*FreeVirtualMemory/;
            return "";
        };

        eval { main::os_setup(); };
        like($@, qr/memerror_fatal/, 'Corrupted swap output triggers memerror safety halt');
        is($memerror_tripped, 1, 'memerror invoked once for non-numeric swap');
    }
};

# =====================================================================
# Challenge 3: Windows Username Resolution & Fatal getpwuid Interception
# =====================================================================
subtest 'Challenge 3: Windows username resolution and fatal getpwuid interception' => sub {
    # Scenario A: getpwuid dies with fatal POSIX exception on simulated Windows
    {
        local $main::is_win = 1;
        local $ENV{USER}     = undef;
        local $ENV{USERNAME} = 'DomainAdmin';
        local %main::opt    = ( color => 0, nocolor => 1 );

        # Emulate getpwuid dying if invoked
        no warnings 'redefine';
        local *CORE::GLOBAL::getpwuid = sub { die "Fatal: POSIX getpwuid not implemented on Win32\n" };

        eval { main::setup_environment(); };
        is($@, '', 'setup_environment does not execute getpwuid on Windows');
        is($main::me, 'DomainAdmin', 'Resolves $me to DomainAdmin cleanly');
        main::close_outputfile();
    }

    # Scenario B: Windows with both USER and USERNAME missing
    {
        local $main::is_win = 1;
        local $ENV{USER}     = undef;
        local $ENV{USERNAME} = undef;
        local %main::opt    = ( color => 0, nocolor => 1 );

        eval { main::setup_environment(); };
        is($@, '', 'setup_environment handles missing user environment variables');
        is($main::me, 'unknown', 'Safely defaults to unknown');
        main::close_outputfile();
    }
};

# =====================================================================
# Challenge 4: Outputfile Color Sanitization Under Multi-Flag Permutations
# =====================================================================
subtest 'Challenge 4: Outputfile color sanitization under multi-flag permutations' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $target_report = File::Spec->catfile($tmpdir, 'audit.txt');

    my @test_cases = (
        { opt => { outputfile => $target_report, color => 1 }, desc => 'outputfile + color=1' },
        { opt => { outputfile => $target_report, color => 1, nocolor => 0 }, desc => 'outputfile + color=1 + nocolor=0' },
        { opt => { outputfile => $target_report }, desc => 'outputfile only' }
    );

    for my $tc (@test_cases) {
        local %main::opt = %{ $tc->{opt} };
        main::setup_environment();

        is($main::opt{nocolor}, 1, "nocolor forced to 1 for $tc->{desc}");
        unlike($main::good, qr/\e\[\d+/, "No ANSI escape codes in good icon for $tc->{desc}");
        unlike($main::bad,  qr/\e\[\d+/, "No ANSI escape codes in bad icon for $tc->{desc}");
        unlike($main::cmd,  qr/\e\[\d+/, "No ANSI escape codes in cmd prompt for $tc->{desc}");
        unlike($main::end,  qr/\e\[\d+/, "No ANSI escape codes in end marker for $tc->{desc}");

        main::close_outputfile();
    }
};

# =====================================================================
# Challenge 5: Update Tuner Version Hermetic Target Isolation & Truncated Downloads
# =====================================================================
subtest 'Challenge 5: Update tuner version target path validation and download integrity' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    local $main::update_target_dir = $tmpdir;
    local $main::opt{'updateversion'} = 1;

    my @mock_good;
    my @mock_bad;
    no warnings 'redefine';
    local *main::goodprint  = sub { push @mock_good, $_[0] };
    local *main::badprint   = sub { push @mock_bad,  $_[0] };
    local *main::infoprint  = sub { };
    local *main::debugprint = sub { };

    # Case A: curl download - 2 files succeed, 1 file is 0 bytes (truncated)
    {
        @mock_good = ();
        @mock_bad  = ();
        local *main::get_http_cli = sub { return '/usr/bin/curl' };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ />\s+(.+)$/) {
                my $target = $1;
                open my $fh, '>', $target or die $!;
                if ($target =~ /vulnerabilities\.csv/) {
                    # Truncated download: 0 bytes
                }
                else {
                    print $fh "Valid file content\n";
                }
                close $fh;
            }
            return "";
        };

        eval { main::update_tuner_version(); };
        like($@, qr/MOCK_EXIT/, 'Exited on completion');
        ok(grep({ /Couldn't update vulnerabilities\.csv/ } @mock_bad), 'Identified truncated file via -s $fullpath');
        ok(grep({ /Couldn't update MySQLTuner script/ } @mock_bad), 'Overall update flagged failure');
        is(scalar(grep({ /Successfully updated MySQLTuner/ } @mock_good)), 0, 'Did not falsely claim complete success');
    }

    # Case B: wget download with all files valid
    {
        @mock_good = ();
        @mock_bad  = ();
        local *main::get_http_cli = sub { return '/usr/bin/wget' };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /-O\s+(\S+)/) {
                my $target = $1;
                open my $fh, '>', $target or die $!;
                print $fh "Wget downloaded data\n";
                close $fh;
            }
            return "";
        };

        eval { main::update_tuner_version(); };
        like($@, qr/MOCK_EXIT/, 'Exited on completion');
        ok(grep({ /Successfully updated MySQLTuner script/ } @mock_good), 'All 3 files verified > 0 bytes');
        is(scalar(@mock_bad), 0, 'No errors emitted on complete download');
    }
};

# =====================================================================
# Challenge 6: infocmd_tab Output Capture Context & Query Deduplication Invariance
# =====================================================================
subtest 'Challenge 6: infocmd_tab output capture context and SHOW query deduplication' => sub {
    # 1. infocmd_tab with empty output
    no warnings 'redefine';
    local *main::execute_system_command = sub { return () };
    local *main::infoprint = sub { };
    local *main::debugprint = sub { };

    my $scalar_empty = main::infocmd_tab("empty_command");
    is($scalar_empty, "", "Empty command returns empty string in scalar context");
    my @list_empty = main::infocmd_tab("empty_command");
    is(scalar(@list_empty), 0, "Empty command returns empty list in list context");

    # 2. get_all_vars deduplication invariance
    my %queries_issued;
    local *main::select_one = sub { return "8.4.0-MySQL" };
    local *main::select_array = sub {
        my ($q) = @_;
        $queries_issued{$q}++;
        if ($q eq 'SHOW GLOBAL VARIABLES') {
            return ("max_connections\t200", "innodb_page_size\t16384");
        }
        if ($q eq 'SHOW GLOBAL STATUS') {
            return ("Uptime\t7200", "Questions\t50000");
        }
        return ();
    };
    local *main::check_privileges = sub { };
    local *main::adjust_aborted_connects = sub { return (0, 100) };

    main::get_all_vars();

    is($queries_issued{'SHOW GLOBAL VARIABLES'}, 1, 'SHOW GLOBAL VARIABLES executed once');
    is($queries_issued{'SHOW VARIABLES'} // 0, 0, 'SHOW VARIABLES was not executed');
    is($queries_issued{'SHOW GLOBAL STATUS'}, 1, 'SHOW GLOBAL STATUS executed once');
    is($queries_issued{'SHOW STATUS'} // 0, 0, 'SHOW STATUS was not executed');
};

# =====================================================================
# Challenge 7: Kernel Sysctl & Filesystem Mountpoint Format Verification
# =====================================================================
subtest 'Challenge 7: Kernel sysctl and filesystem mountpoint formatting' => sub {
    @main::generalrec = ();
    @main::adjvars    = ();
    @main::sysrec     = ();
    my @badprints;

    no warnings 'redefine';
    local *main::badprint  = sub { push @badprints, $_[0] };
    local *main::infoprint = sub { };
    local *main::get_transport_prefix = sub { return '' };

    # 1. Filesystem check with multiple mount points exceeding 85%
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /df -P \| grep '%'/) {
            return (
                "Filesystem      1024-blocks      Used Available Capacity Mounted on\n",
                "/dev/sda1          10485760   9437184   1048576      90% /\n",
                "/dev/sdb1          52428800  49807360   2621440      95% /var/lib/mysql\n"
            );
        }
        elsif ($cmd =~ /df -Pi\| grep '%'/) {
            return (
                "Filesystem            Inodes   IUsed     IFree IUse% Mounted on\n",
                "/dev/sda1            1000000  200000    800000   20% /\n",
                "/dev/sdb1            5000000 4500000    500000   90% /var/lib/mysql\n"
            );
        }
        return ();
    };

    main::get_fs_info();

    ok(grep({ /Add some space to \/ mountpoint\./ } @main::generalrec), 'General recommendation for / has path');
    ok(grep({ /Add some space to \/var\/lib\/mysql mountpoint\./ } @main::generalrec), 'General recommendation for /var/lib/mysql has path');
    ok(!grep({ /Add some space to 90 mountpoint\./ } @main::generalrec), 'No percentage 90 interpolated');
    ok(!grep({ /Add some space to 95 mountpoint\./ } @main::generalrec), 'No percentage 95 interpolated');
    ok(grep({ /Cleanup files from \/var\/lib\/mysql mountpoint/ } @main::generalrec), 'Inode recommendation has mountpoint');

    # 2. Verify exact text strings in mysqltuner.pl
    open my $fh, '<', $script or die "Cannot open $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    like($code, qr/Initial TCP slot entries is < 100/, 'mysqltuner.pl contains exact < 100 string');
    unlike($code, qr/Initial TCP slot entries is < 1M/, 'mysqltuner.pl does not contain < 1M');
    like($code, qr/fs\.nr_open > 1M \(echo 1048576 > \/proc\/sys\/fs\/nr_open\)/, 'mysqltuner.pl contains fs.nr_open > 1M');
    unlike($code, qr/fs\.aio-nr > 1M \(echo 1048576 > \/proc\/sys\/fs\/nr_open\)/, 'mysqltuner.pl does not contain fs.aio-nr > 1M for nr_open');
};

done_testing();
