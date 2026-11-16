#!/usr/bin/env perl
# tests/unit_m2_process_swap.t
# Validates Milestone 2 Telemetry Fixes:
#   - Issue 3: setup_environment preserves $opt{noprocess}
#   - Issue 3: get_other_process_memory returns 0 when $opt{noprocess} is active
#   - Issue 3: get_other_process_memory filters out mariadbd and garbd
#   - Issue 4: Windows FreeVirtualMemory multiplied by 1024 (KB -> bytes)
#   - Issue 4: Windows swap == 0 does not trigger memerror exit
#   - Issue 4: Invalid or undefined swap triggers memerror

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Declare globals
our %opt;
our %result;
our $is_win;
our $cached_other_process_memory;

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# =====================================================================
# Subtest 1: Issue 3 — setup_environment preserves $opt{noprocess}
# =====================================================================
subtest 'Issue 3: setup_environment preserves $opt{noprocess}' => sub {
    # Case A: --noprocess set (1)
    %main::opt = ( noprocess => 1 );
    main::setup_environment();
    is($main::opt{noprocess}, 1, '$opt{noprocess} remains 1 after setup_environment (not reset to 0)');
    main::close_outputfile();

    # Case B: --no-noprocess explicitly set (0)
    %main::opt = ( noprocess => 0 );
    main::setup_environment();
    is($main::opt{noprocess}, 0, '$opt{noprocess} remains 0 when explicitly disabled');
    main::close_outputfile();

    # Case C: Unset / undef
    %main::opt = ();
    main::setup_environment();
    is($main::opt{noprocess}, 0, '$opt{noprocess} defaults to 0 when omitted');
    main::close_outputfile();
};

# =====================================================================
# Subtest 2: Issue 3 — get_other_process_memory returns 0 on noprocess
# =====================================================================
subtest 'Issue 3: get_other_process_memory returns 0 when $opt{noprocess} is active' => sub {
    local $main::opt{noprocess} = 1;
    local $main::opt{tbstat}    = 1;
    local $main::is_win         = 0;
    local $main::cached_other_process_memory = undef;

    my $exec_called = 0;
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        $exec_called++ if $cmd =~ /ps eaxo/;
        return (
            "  PID   RSS %CPU COMMAND",
            " 5678  2048  1.2 nginx"
        );
    };

    my $mem = main::get_other_process_memory();
    is($mem, 0, 'get_other_process_memory returns 0 when $opt{noprocess} == 1');
    is($exec_called, 0, 'ps command was never executed (fast return)');
};

# =====================================================================
# Subtest 3: Issue 3 — Process filtering excludes mariadbd and garbd
# =====================================================================
subtest 'Issue 3: Process filtering excludes mariadbd and garbd' => sub {
    local $main::opt{noprocess} = 0;
    local $main::opt{tbstat}    = 1;
    local $main::is_win         = 0;
    local $main::opt{dumpdir}   = '/tmp/test_m2_dumpdir';
    local $main::cached_other_process_memory = undef;

    my @mock_procs = (
        "  PID   RSS %CPU COMMAND",
        " 1001  1024  0.5 mysqld",
        " 1002  2048  1.0 /usr/sbin/mariadbd --basedir=/usr",
        " 1003   512  0.2 /usr/bin/garbd --group=my_cluster",
        " 1004  4096  0.8 redis-server *:6379",
        " 1005  8192  1.5 java -jar app.jar",
        "   99   256  0.0 systemd",
        "    2     0  0.0 [kthreadd]"
    );

    my $dumped_file;
    my $dumped_content;
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        return @mock_procs if $cmd =~ /ps eaxo/;
        return ();
    };
    local *main::dump_into_file = sub {
        ($dumped_file, $dumped_content) = @_;
    };

    my $mem = main::get_other_process_memory();

    # Only redis-server (4096 KB) + java (8192 KB) = 12288 KB = 12582912 Bytes
    is($mem, 12288 * 1024, 'Memory correctly sums only non-DB user processes (12288 KB)');
    is($dumped_file, 'non_mysqld_processes.csv', 'Dump file is non_mysqld_processes.csv');
    like($dumped_content, qr/redis-server/, 'CSV includes redis-server');
    like($dumped_content, qr/java/, 'CSV includes java');
    unlike($dumped_content, qr/mariadbd/, 'CSV excludes mariadbd');
    unlike($dumped_content, qr/garbd/, 'CSV excludes garbd');
    unlike($dumped_content, qr/mysqld/, 'CSV excludes mysqld');
};

# =====================================================================
# Subtest 4: Issue 4 — Windows FreeVirtualMemory multiplied by 1024
# =====================================================================
subtest 'Issue 4: Windows FreeVirtualMemory multiplied by 1024 (KB to bytes)' => sub {
    local $^O = 'MSWin32';
    local $main::is_win = 1;
    local $main::opt{forcemem} = 0;
    local $main::opt{tbstat}   = 0;
    no warnings 'redefine';
    local *main::get_transport_prefix = sub { return "" };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /powershell.*Win32_ComputerSystem.*TotalPhysicalMemory/) {
            return "17179869184\n"; # 16 GB in bytes
        }
        if ($cmd =~ /powershell.*Win32_OperatingSystem.*FreeVirtualMemory/) {
            return "8388608\n"; # 8 GB in KB
        }
        return "";
    };

    main::os_setup();
    is($main::result{'OS'}{'Physical Memory'}{'bytes'}, "17179869184", 'Physical memory in bytes');
    is($main::result{'OS'}{'Swap Memory'}{'bytes'}, 8388608 * 1024, 'Swap memory multiplied by 1024 into bytes (8589934592)');
    is($main::result{'OS'}{'Swap Memory'}{'pretty'}, "8.0G", 'Swap memory pretty-printed as 8.0G (not 8.0M)');
};

# =====================================================================
# Subtest 5: Issue 4 — Windows swap == 0 does not trigger memerror
# =====================================================================
subtest 'Issue 4: Windows swap == 0 does not trigger memerror' => sub {
    local $^O = 'MSWin32';
    local $main::is_win = 1;
    local $main::opt{forcemem} = 0;
    local $main::opt{tbstat}   = 0;
    my $memerror_called = 0;
    no warnings 'redefine';
    local *main::memerror = sub { $memerror_called++; die "memerror called\n" };
    local *main::get_transport_prefix = sub { return "" };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /powershell.*Win32_ComputerSystem.*TotalPhysicalMemory/) {
            return "8589934592\n"; # 8 GB in bytes
        }
        if ($cmd =~ /powershell.*Win32_OperatingSystem.*FreeVirtualMemory/) {
            return "0\n"; # 0 swap (disabled paging)
        }
        return "";
    };

    eval { main::os_setup(); };
    is($@, '', 'os_setup completed without throwing exception on 0 swap');
    is($memerror_called, 0, 'memerror was NOT called for swap == 0');
    is($main::result{'OS'}{'Swap Memory'}{'bytes'}, 0, 'Swap memory bytes is 0');
    is($main::result{'OS'}{'Swap Memory'}{'pretty'}, "0B", 'Swap memory pretty format is 0B');
};

# =====================================================================
# Subtest 6: Issue 4 — Invalid or undefined swap triggers memerror
# =====================================================================
subtest 'Issue 4: Invalid or undefined swap triggers memerror' => sub {
    local $^O = 'MSWin32';
    local $main::is_win = 1;
    local $main::opt{forcemem} = 0;
    local $main::opt{tbstat}   = 0;
    my $memerror_called = 0;
    no warnings 'redefine';
    local *main::memerror = sub { $memerror_called++; die "memerror called\n" };
    local *main::get_transport_prefix = sub { return "" };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /TotalPhysicalMemory/) { return "8589934592\n"; }
        return ""; # FreeVirtualMemory fails from both PowerShell and WMIC
    };

    eval { main::os_setup(); };
    like($@, qr/memerror called/, 'memerror correctly called when swap cannot be determined');
    is($memerror_called, 1, 'memerror called exactly once');
};

done_testing();
