#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Declare globals before loading script
our @adjvars;
our @generalrec;
our @modeling;
our @sysrec;
our @secrec;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;

my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

my @mock_output;
my @mock_bad;
my @mock_good;
my @mock_info;

sub reset_mocks {
    @mock_output = ();
    @mock_bad = ();
    @mock_good = ();
    @mock_info = ();
    @main::generalrec = ();
    @main::adjvars = ();
    @main::modeling = ();
    @main::sysrec = ();
    @main::secrec = ();
    %main::result = ();
    %main::opt = (
        forcemem  => 0,
        forceswap => 0,
    );
    %main::myvar = ();
}

{
    no warnings 'redefine';
    *main::infoprint       = sub { push @mock_output, "INFO: $_[0]"; push @mock_info, $_[0]; };
    *main::badprint        = sub { push @mock_output, "BAD: $_[0]"; push @mock_bad, $_[0]; };
    *main::goodprint       = sub { push @mock_output, "GOOD: $_[0]"; push @mock_good, $_[0]; };
    *main::debugprint      = sub { };
    *main::subheaderprint  = sub { push @mock_output, "HEADER: $_[0]"; };
    *main::prettyprint     = sub { push @mock_output, "PRETTY: $_[0]"; };
    *main::infoprintml     = sub { push @mock_output, "INFO_ML: " . join(" ", @_); };
    *main::memerror        = sub { die "memerror called\n"; };
    *main::detect_infrastructure    = sub { return "baremetal"; };
    *main::get_other_process_memory = sub { return 0; };
}

# =====================================================================
# 1. sub cpu_cores under Windows
# =====================================================================
subtest 'cpu_cores Windows Detection and Fallback' => sub {
    # Case 1A: PowerShell CIM returns valid core count
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /powershell.*Win32_Processor.*NumberOfCores/) {
                return "8\n";
            }
            if ($cmd =~ /wmic cpu get NumberOfCores/) {
                return "4\n"; # Should not be reached
            }
            return "";
        };
        my $cores = main::cpu_cores();
        is($cores, 8, 'PowerShell CIM returns valid CPU cores');
    }

    # Case 1B: PowerShell CIM returns empty, fallback to WMIC
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /powershell.*Win32_Processor.*NumberOfCores/) {
                return "";
            }
            if ($cmd =~ /wmic cpu get NumberOfCores/) {
                return "4\n";
            }
            return "";
        };
        my $cores = main::cpu_cores();
        is($cores, 4, 'Fallback to WMIC when PowerShell CIM returns empty');
    }

    # Case 1C: Both PowerShell and WMIC return invalid/empty (returns 0)
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::execute_system_command = sub { return ""; };
        my $cores = main::cpu_cores();
        is($cores, 0, 'Returns 0 when both PowerShell and WMIC return empty');
    }
};

# =====================================================================
# 2. sub logical_cpu_cores under Windows
# =====================================================================
subtest 'logical_cpu_cores Windows Detection and Fallback' => sub {
    # Case 2A: PowerShell CIM returns valid logical core count
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /powershell.*Win32_Processor.*NumberOfLogicalProcessors/) {
                return "16\n";
            }
            if ($cmd =~ /wmic cpu get NumberOfLogicalProcessors/) {
                return "8\n";
            }
            return "";
        };
        my $cores = main::logical_cpu_cores();
        is($cores, 16, 'PowerShell CIM returns valid logical CPU cores');
    }

    # Case 2B: PowerShell CIM returns empty, fallback to WMIC
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /powershell.*Win32_Processor.*NumberOfLogicalProcessors/) {
                return "";
            }
            if ($cmd =~ /wmic cpu get NumberOfLogicalProcessors/) {
                return "8\n";
            }
            return "";
        };
        my $cores = main::logical_cpu_cores();
        is($cores, 8, 'Fallback to WMIC when PowerShell CIM returns empty for logical cores');
    }
};

# =====================================================================
# 3. sub os_setup Windows Memory Metrics Detection and Fallback
# =====================================================================
subtest 'os_setup Windows Memory Detection and Fallback' => sub {
    # Case 3A: PowerShell CIM returns valid physical and swap memory
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::get_transport_prefix = sub { return ""; };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /powershell.*Win32_ComputerSystem.*TotalPhysicalMemory/) {
                return "17179869184\n"; # 16 GB
            }
            if ($cmd =~ /powershell.*Win32_OperatingSystem.*FreeVirtualMemory/) {
                return "8388608\n"; # 8 GB virtual
            }
            return "";
        };
        main::os_setup();
        is($main::result{'OS'}{'Physical Memory'}{'bytes'}, "17179869184", 'Physical memory captured via PowerShell CIM');
        is($main::result{'OS'}{'Swap Memory'}{'bytes'}, "8388608", 'Swap memory captured via PowerShell CIM');
        is($main::result{'OS'}{'OS Type'}, 'windows', 'OS Type set to windows');
    }

    # Case 3B: PowerShell CIM returns empty, fallback to WMIC
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::get_transport_prefix = sub { return ""; };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /powershell.*Win32_ComputerSystem.*TotalPhysicalMemory/) {
                return "";
            }
            if ($cmd =~ /wmic ComputerSystem get TotalPhysicalMemory/) {
                return "8589934592\n"; # 8 GB
            }
            if ($cmd =~ /powershell.*Win32_OperatingSystem.*FreeVirtualMemory/) {
                return "";
            }
            if ($cmd =~ /wmic OS get FreeVirtualMemory/) {
                return "4194304\n"; # 4 GB
            }
            return "";
        };
        main::os_setup();
        is($main::result{'OS'}{'Physical Memory'}{'bytes'}, "8589934592", 'Physical memory captured via WMIC fallback');
        is($main::result{'OS'}{'Swap Memory'}{'bytes'}, "4194304", 'Swap memory captured via WMIC fallback');
    }

    # Case 3C: Both fail triggers memerror
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::get_transport_prefix = sub { return ""; };
        local *main::execute_system_command = sub { return ""; };
        eval { main::os_setup(); };
        like($@, qr/memerror called/, 'Triggers memerror when both PowerShell and WMIC fail');
    }
};

# =====================================================================
# 4. sub get_fs_info_win Windows Filesystem Metrics and Fallback
# =====================================================================
subtest 'get_fs_info_win Windows Filesystem Detection and Fallback' => sub {
    # Case 4A: PowerShell CIM returns formatted disk table
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /powershell.*Win32_LogicalDisk/) {
                return (
                    "  58879045632 C:       1021821579264\n",
                    "  90000000000 D:       100000000000\n",
                );
            }
            return ();
        };
        main::get_fs_info_win();
        is($main::result{'Filesystem'}{'Total Space'}{'C:'}, 1021821579264, 'C: total space parsed');
        is($main::result{'Filesystem'}{'Free Space'}{'C:'}, 58879045632, 'C: free space parsed');
        is($main::result{'Filesystem'}{'Used Space'}{'C:'}, 1021821579264 - 58879045632, 'C: used space calculated');
        is($main::result{'Filesystem'}{'Space Pct'}{'C:'}, 94, 'C: space pct calculated (> 85%)');
        ok(grep({ /Add some space to DIsk C:/ } @main::generalrec), 'General recommendation emitted for C: disk usage > 85%');

        is($main::result{'Filesystem'}{'Space Pct'}{'D:'}, 10, 'D: space pct calculated (10%)');
        ok(grep({ /Disk D: is using 10 % total space/ } @mock_info), 'Infoprint emitted for D: normal usage');
    }

    # Case 4B: PowerShell CIM returns empty lines, fallback to WMIC
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /powershell.*Win32_LogicalDisk/) {
                return ();
            }
            if ($cmd =~ /wmic logicaldisk get Name,Size,FreeSpace/) {
                return (
                    "FreeSpace    Name  Size\n",
                    "58879045632  C:    1021821579264\n",
                );
            }
            return ();
        };
        main::get_fs_info_win();
        is($main::result{'Filesystem'}{'Total Space'}{'C:'}, 1021821579264, 'C: total space parsed via WMIC fallback');
        is($main::result{'Filesystem'}{'Free Space'}{'C:'}, 58879045632, 'C: free space parsed via WMIC fallback');
    }
};

# =====================================================================
# 5. sub check_architecture Windows Architecture Check and Fallback
# =====================================================================
subtest 'check_architecture Windows 64-bit Architecture Check and Fallback' => sub {
    # Case 5A: PowerShell CIM returns 64-bit
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::is_remote = sub () { return 0 };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /powershell.*OSArchitecture/) {
                return "64-bit\n";
            }
            return "";
        };
        main::check_architecture();
        is($main::result{'OS'}{'Architecture'}, '64 bits', 'Architecture set to 64 bits via PowerShell CIM');
        ok(grep({ /Operating on 64-bit architecture/ } @mock_good), 'Logged 64-bit confirmation');
    }

    # Case 5B: PowerShell CIM returns empty, fallback to WMIC
    {
        reset_mocks();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        no warnings 'redefine';
        local *main::is_remote = sub () { return 0 };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /powershell.*OSArchitecture/) {
                return "";
            }
            if ($cmd eq 'wmic os get osarchitecture') {
                return "64-bit OS\n";
            }
            return "";
        };
        main::check_architecture();
        is($main::result{'OS'}{'Architecture'}, '64 bits', 'Architecture set to 64 bits via WMIC fallback');
        ok(grep({ /Operating on 64-bit architecture/ } @mock_good), 'Logged 64-bit confirmation via WMIC');
    }
};

# =====================================================================
# 6. execute_system_command Whitelist Error Suppression
# =====================================================================
subtest 'execute_system_command Whitelist Regex Error Suppression' => sub {
    reset_mocks();
    no warnings 'redefine';

    # Verify that regex in execute_system_command matches powershell and pwsh
    my $whitelist_regex = qr/(?:^|\/)(dmesg|lspci|dmidecode|ipconfig|isainfo|bootinfo|ver|wmic|powershell|pwsh|lsattr|prtconf|swapctl|swapinfo|svcprop|ps|ping|ifconfig|ip|hostname|who|free|top|uptime|netstat|sysctl|mysql|mariadb|curl|wget|which)/;

    like('powershell -NoProfile -Command "test"', $whitelist_regex, 'powershell matches whitelist');
    like('/usr/bin/powershell -NoProfile -Command "test"', $whitelist_regex, '/usr/bin/powershell matches whitelist');
    like('pwsh -NoProfile -Command "test"', $whitelist_regex, 'pwsh matches whitelist');
    like('/usr/bin/pwsh -NoProfile -Command "test"', $whitelist_regex, '/usr/bin/pwsh matches whitelist');
    like('wmic cpu get NumberOfCores', $whitelist_regex, 'wmic matches whitelist');
    unlike('unknown_command_xyz --flag', $whitelist_regex, 'unknown command does not match whitelist');

    # Test error suppression behavior in execute_system_command when command fails ($? != 0)
    # Case 6A: Failing powershell command does NOT log "System command failed"
    @mock_bad = ();
    main::execute_system_command('powershell -NoProfile -Command "exit 1"');
    ok(!grep({ /System command failed: powershell/ } @mock_bad), 'Suppresses benign error message for failing powershell command');

    # Case 6B: Failing pwsh command does NOT log "System command failed"
    @mock_bad = ();
    main::execute_system_command('pwsh -NoProfile -Command "exit 1"');
    ok(!grep({ /System command failed: pwsh/ } @mock_bad), 'Suppresses benign error message for failing pwsh command');

    # Case 6C: Failing non-whitelisted command DOES log "System command failed"
    @mock_bad = ();
    main::execute_system_command('perl -e "exit 1"');
    ok(grep({ /System command failed: perl/ } @mock_bad), 'Logs "System command failed" for non-whitelisted command');
};

done_testing();
