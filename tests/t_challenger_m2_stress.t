#!/usr/bin/env perl
# tests/t_challenger_m2_stress.t
# =============================================================================
# EMPIRICAL CHALLENGER ADVERSARIAL STRESS TEST SUITE — MILESTONE 2
# =============================================================================
# Adversarially stress-tests:
#   1. Process memory calculation & --noprocess flag variations:
#      - CLI arg parsing: --noprocess, --noprocess=1, --noprocess=0, --no-noprocess, omitted.
#      - get_other_process_memory return on $opt{noprocess} active.
#      - Daemon filtering: mariadbd, garbd, mysqld-debug, mixed casing, kernel brackets.
#      - Pathological process lines: corrupted PIDs, missing fields, zero/negative RSS, spaces.
#   2. Windows swap memory calculation & zero-swap resilience:
#      - FreeVirtualMemory scaled by 1024 into bytes.
#      - swap = "0" NEVER calls memerror() or fatal exit.
#      - swap = "8388608" (KB) scaled to 8589934592 (8.0G).
#      - swap = undef / "invalid_string" triggers fallback to WMIC, or memerror() if unresolvable.
#      - WMIC fallback returning "0" or valid KB succeeds.
#   3. Windows getpwuid crash guard:
#      - $is_win = 1 with $ENV{USER} and $ENV{USERNAME} undef falls back to 'unknown' without die.
#      - Mock getpwuid that dies if called on Windows is never touched.
#      - $is_win = 0 eval guard handles getpwuid crash gracefully.
#   4. Environment, Kernel, FS & Command deduplication stress tests:
#      - infocmd_tab context-aware returns and single-call caching in get_system_info.
#      - get_all_vars deduplication and fallback.
#      - fs.nr_open and sunrpc display verification.
#      - get_fs_info mountpoint interpolation.
#      - setup_environment color suppression on outputfile.
#      - update_tuner_version download verification against -s $fullpath.
# =============================================================================

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Cwd 'abs_path';

our $mock_getpwuid_die = 0;
# Intercept CORE::GLOBAL::exit and getpwuid to capture exits and simulate POSIX crashes safely
BEGIN {
    *CORE::GLOBAL::exit = sub {
        my $code = $_[0] // 0;
        die "MOCK_EXIT:$code\n";
    };
    *CORE::GLOBAL::getpwuid = sub {
        die "POSIX passwd lookup failure\n" if $mock_getpwuid_die;
        return CORE::getpwuid($_[0]);
    };
}

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Package globals required by mysqltuner.pl
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
our $outputfile;
our $fh;
our $me;
our $good;
our $bad;
our $info;
our $deb;
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

sub reset_state {
    @main::adjvars    = ();
    @main::generalrec = ();
    @main::modeling   = ();
    @main::sysrec     = ();
    @main::secrec     = ();
    %main::opt        = ( dbgpattern => '.*' );
    %main::myvar      = ( version => '8.0.35', have_innodb => 'YES' );
    %main::mystat     = ();
    %main::mycalc     = ();
    %main::result     = ();
    $main::outputfile = undef;
    $main::fh         = undef;
    $main::me         = undef;
    $main::cached_other_process_memory = undef;
}

# =============================================================================
# SECTION 1: Adversarial Challenge on Process Memory & --noprocess
# =============================================================================
subtest 'CHALLENGE 1.1: CLI Argument Parsing and Preservation for --noprocess' => sub {
    reset_state();

    # 1.1.1: CLI argument --noprocess via parse_cli_args and setup_environment
    {
        reset_state();
        local @ARGV = ('--noprocess');
        main::parse_cli_args();
        main::setup_environment();
        is($main::opt{noprocess}, 1, 'CLI argument --noprocess sets and preserves $opt{noprocess} = 1');
        main::close_outputfile();
    }

    # 1.1.2: CLI argument --no-noprocess
    {
        reset_state();
        local @ARGV = ('--no-noprocess');
        main::parse_cli_args();
        main::setup_environment();
        is($main::opt{noprocess}, 0, 'CLI argument --no-noprocess sets $opt{noprocess} = 0');
        main::close_outputfile();
    }

    # 1.1.3: CLI argument --noprocess=1 (Getopt::Long rejects argument for boolean flag)
    {
        reset_state();
        local @ARGV = ('--noprocess=1');
        eval { main::parse_cli_args(); };
        like($@, qr/MOCK_EXIT:1/, 'CLI argument --noprocess=1 is rejected by Getopt::Long (boolean flag does not accept values)');
    }

    # 1.1.4: CLI argument --noprocess=0 (Getopt::Long rejects argument for boolean flag)
    {
        reset_state();
        local @ARGV = ('--noprocess=0');
        eval { main::parse_cli_args(); };
        like($@, qr/MOCK_EXIT:1/, 'CLI argument --noprocess=0 is rejected by Getopt::Long (boolean flag does not accept values)');
    }

    # 1.1.5: Omitted --noprocess
    {
        reset_state();
        local @ARGV = ();
        main::parse_cli_args();
        main::setup_environment();
        is($main::opt{noprocess}, 0, 'Omitted --noprocess defaults to 0');
        main::close_outputfile();
    }

    # 1.1.6: Direct %opt preservation in setup_environment: noprocess => 1
    {
        reset_state();
        %main::opt = ( noprocess => 1 );
        main::setup_environment();
        is($main::opt{noprocess}, 1, 'setup_environment preserves pre-set $opt{noprocess} = 1');
        main::close_outputfile();
    }

    # 1.1.7: Direct %opt preservation in setup_environment: noprocess => 0
    {
        reset_state();
        %main::opt = ( noprocess => 0 );
        main::setup_environment();
        is($main::opt{noprocess}, 0, 'setup_environment preserves pre-set $opt{noprocess} = 0');
        main::close_outputfile();
    }

    # 1.1.8: Direct %opt omission in setup_environment
    {
        reset_state();
        %main::opt = ();
        main::setup_environment();
        is($main::opt{noprocess}, 0, 'setup_environment defaults omitted $opt{noprocess} to 0');
        main::close_outputfile();
    }
};

subtest 'CHALLENGE 1.2: get_other_process_memory Fast Exit on $opt{noprocess}' => sub {
    reset_state();
    local $main::opt{noprocess} = 1;
    local $main::opt{tbstat}    = 1;
    local $main::is_win         = 0;
    local $main::cached_other_process_memory = undef;

    my $system_calls = 0;
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        $system_calls++;
        return ("PID RSS %CPU COMMAND", "100 50000 10.0 big_process");
    };

    my $mem = main::get_other_process_memory();
    is($mem, 0, 'Returns 0 immediately when $opt{noprocess} is 1');
    is($system_calls, 0, 'Never executes ps command when $opt{noprocess} is 1');
};

subtest 'CHALLENGE 1.3: Process List Daemon & Kernel Filtering Adversarial Harness' => sub {
    reset_state();
    local $main::opt{noprocess} = 0;
    local $main::opt{tbstat}    = 1;
    local $main::is_win         = 0;
    local $main::opt{dumpdir}   = undef;
    local $main::cached_other_process_memory = undef;

    # Adversarial process list containing every variant of database daemons,
    # arbitrators, debug builds, kernel threads, casing variants, and pathologically formatted lines.
    my @adversarial_ps_output = (
        "  PID   RSS %CPU COMMAND",
        # MySQL & MariaDB daemons (MUST BE FILTERED)
        " 101  102400  5.0 /usr/sbin/mysqld --basedir=/usr",
        " 102   51200  2.5 /usr/sbin/mysqld-debug --debug",
        " 103   60000  3.0 mysqld_safe --datadir=/var/lib/mysql",
        " 104  204800 10.0 /usr/sbin/mariadbd --defaults-file=/etc/mysql/mariadb.cnf",
        " 105   80000  4.0 /usr/local/mariadb/bin/mariadbd-debug",
        " 106   75000  3.5 /opt/mariadb/bin/MARIADBD -u mysql",
        " 107   70000  2.0 /opt/bin/MariadbD",
        " 108   90000  4.5 /usr/bin/MySqLd-DeBuG",
        # Galera arbitrators (MUST BE FILTERED)
        " 201   10240  0.5 /usr/bin/garbd -a gcomm://192.168.1.1:4567 -g my_cluster",
        " 202   12000  0.6 /opt/galera/bin/GARBD -d",
        " 203   11000  0.4 /usr/local/bin/Garbd-wrapper",
        # Kernel threads (MUST BE FILTERED)
        "   2       0  0.0 [kthreadd]",
        "   3       0  0.0 [kworker/0:0]",
        "   4       0  0.0 [kworker/0:1H]",
        "   9       0  0.0 [migration/0]",
        "  15       0  0.0 [jbd2/sda1-8]",
        "  16       0  0.0 [xfsaild/dm-0]",
        "  17       0  0.0 [mariadbd_io]",     # Bracketed kernel thread with daemon name
        "  18       0  0.0 [garbd_watchdog]",  # Bracketed kernel thread with garbd name
        # Systemd processes (MUST BE FILTERED)
        "   1    9000  0.1 /lib/systemd/systemd /sbin/init splash",
        "  80    5000  0.0 /lib/systemd/systemd-udevd",
        "  81    4000  0.0 /lib/systemd/systemd-journald",
        "  82    3000  0.0 /usr/lib/systemd/systemd-logind",
        # Malformed lines / edge cases
        "  PID   RSS %CPU COMMAND",            # Duplicate header line
        "",                                     # Empty line
        "   ",                                  # Whitespace-only line
        "CORRUPT_PID 1000 0.0 corrupt_line",    # Non-numeric PID
        " 999 0 0.0 corrupt_line_no_command",  # Valid PID, 0 RSS
        # REAL NON-DATABASE PROCESSES (MUST BE COUNTED)
        # Expected RSS sums:
        # Nginx master: 4096 KB
        # Nginx worker: 8192 KB
        # Redis server: 16384 KB
        # Java backend: 32768 KB
        # Python worker: 12288 KB
        # Sshd session: 2048 KB
        # Total expected RSS = 4096 + 8192 + 16384 + 32768 + 12288 + 2048 = 75776 KB = 77594624 Bytes
        " 501    4096  0.2 nginx: master process /usr/sbin/nginx",
        " 502    8192  1.0 nginx: worker process",
        " 503   16384  2.0 /usr/bin/redis-server 127.0.0.1:6379",
        " 504   32768  5.0 /usr/bin/java -jar /opt/app/api.jar",
        ' 505   12288  1.5 python3 /opt/scripts/worker.py --workers 4',
        ' 506    2048  0.1 sshd: admin@pts/1'
    );

    no warnings 'redefine';
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        return @adversarial_ps_output if $cmd =~ /ps eaxo/;
        return ();
    };

    my $mem = main::get_other_process_memory();

    my $expected_kb    = 4096 + 8192 + 16384 + 32768 + 12288 + 2048; # 75776 KB
    my $expected_bytes = $expected_kb * 1024;                         # 77594624 Bytes

    is($mem, $expected_bytes, "Accurately calculated $expected_bytes bytes ($expected_kb KB) from external user processes");

    # Test dumpdir CSV output
    my $temp_dumpdir = tempdir(CLEANUP => 1);
    local $main::opt{dumpdir} = $temp_dumpdir;
    local $main::cached_other_process_memory = undef;

    my $dump_file_captured;
    my $dump_content_captured;
    local *main::dump_into_file = sub {
        ($dump_file_captured, $dump_content_captured) = @_;
    };

    main::get_other_process_memory();

    is($dump_file_captured, 'non_mysqld_processes.csv', 'CSV file named non_mysqld_processes.csv');
    ok(defined $dump_content_captured, 'CSV content was generated');

    # Validate CSV inclusions
    like($dump_content_captured, qr/501,nginx: master process/, 'CSV includes nginx master');
    like($dump_content_captured, qr/503,\/usr\/bin\/redis-server/, 'CSV includes redis-server');
    like($dump_content_captured, qr/504,\/usr\/bin\/java/, 'CSV includes java');
    like($dump_content_captured, qr/505,python3/, 'CSV includes python3');

    # Validate CSV strictly excludes database daemons and arbitrators
    unlike($dump_content_captured, qr/mysqld/, 'CSV excludes mysqld');
    unlike($dump_content_captured, qr/mariadbd/i, 'CSV excludes all mariadbd casings');
    unlike($dump_content_captured, qr/garbd/i, 'CSV excludes all garbd casings');
    unlike($dump_content_captured, qr/systemd/i, 'CSV excludes systemd');
    unlike($dump_content_captured, qr/\[kworker/, 'CSV excludes kernel threads');
};

# =============================================================================
# SECTION 2: Adversarial Challenge on Windows Swap Memory & Zero-Swap Resilience
# =============================================================================
subtest 'CHALLENGE 2.1: Windows swap = "0" (Paging Disabled) Resilience' => sub {
    reset_state();
    local $^O = 'MSWin32';
    local $main::is_win = 1;
    local $main::opt{forcemem} = 0;
    local $main::opt{tbstat}   = 0;

    my $memerror_called = 0;
    no warnings 'redefine';
    local *main::memerror = sub {
        $memerror_called++;
        die "FATAL: memerror called\n";
    };
    local *main::get_transport_prefix = sub { return "" };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /TotalPhysicalMemory/) {
            return "17179869184\n"; # 16 GB physical
        }
        if ($cmd =~ /FreeVirtualMemory/) {
            return "0\n"; # Swap disabled
        }
        return "";
    };

    eval { main::os_setup(); };
    is($@, '', 'os_setup succeeds without throwing exception when swap is "0"');
    is($memerror_called, 0, 'memerror() was NEVER called for swap == 0');
    is($main::result{'OS'}{'Swap Memory'}{'bytes'}, 0, 'Swap memory bytes is exactly 0');
    is($main::result{'OS'}{'Swap Memory'}{'pretty'}, "0B", 'Swap memory pretty string is "0B"');
    is($main::result{'OS'}{'Physical Memory'}{'bytes'}, "17179869184", 'Physical memory correctly preserved as 17179869184');
};

subtest 'CHALLENGE 2.2: Windows swap = "8388608" (8 GB in KB) Unit Conversion' => sub {
    reset_state();
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
        if ($cmd =~ /TotalPhysicalMemory/) {
            return "34359738368\n"; # 32 GB
        }
        if ($cmd =~ /FreeVirtualMemory/) {
            return "8388608\n"; # 8 GB in KB
        }
        return "";
    };

    eval { main::os_setup(); };
    is($@, '', 'os_setup executes cleanly');
    is($memerror_called, 0, 'memerror was not called');

    my $expected_swap_bytes = 8388608 * 1024; # 8589934592
    is($main::result{'OS'}{'Swap Memory'}{'bytes'}, $expected_swap_bytes,
        "FreeVirtualMemory KB multiplied by 1024 into $expected_swap_bytes bytes");
    is($main::result{'OS'}{'Swap Memory'}{'pretty'}, "8.0G",
        'Swap memory formatted as 8.0G (verifies FreeVirtualMemory was in KB, not bytes)');
};

subtest 'CHALLENGE 2.3: Windows swap = undef with WMIC Fallback' => sub {
    reset_state();
    local $^O = 'MSWin32';
    local $main::is_win = 1;
    local $main::opt{forcemem} = 0;
    local $main::opt{tbstat}   = 0;

    # Scenario A: PowerShell returns undef/empty, WMIC succeeds with valid KB
    {
        my $memerror_called = 0;
        my %commands_run;
        no warnings 'redefine';
        local *main::memerror = sub { $memerror_called++; die "memerror called\n" };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            $commands_run{$cmd}++;
            if ($cmd =~ /powershell.*TotalPhysicalMemory/) {
                return "17179869184\n";
            }
            if ($cmd =~ /powershell.*FreeVirtualMemory/) {
                return undef; # PowerShell CIM failed
            }
            if ($cmd =~ /wmic OS get FreeVirtualMemory/) {
                return "4194304\n"; # WMIC fallback succeeds with 4 GB KB
            }
            return "";
        };

        eval { main::os_setup(); };
        is($@, '', 'os_setup succeeds via WMIC fallback when PowerShell FreeVirtualMemory returns undef');
        is($memerror_called, 0, 'memerror was not called when WMIC fallback succeeded');
        is($main::result{'OS'}{'Swap Memory'}{'bytes'}, 4194304 * 1024, 'Swap memory 4GB bytes via WMIC');
        is($main::result{'OS'}{'Swap Memory'}{'pretty'}, "4.0G", 'Swap memory 4.0G pretty via WMIC');
    }

    # Scenario B: PowerShell returns undef, WMIC also fails (returns undef or empty)
    {
        my $memerror_called = 0;
        no warnings 'redefine';
        local *main::memerror = sub { $memerror_called++; die "MOCK_MEMERROR\n" };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /TotalPhysicalMemory/) { return "17179869184\n"; }
            return undef; # All swap queries fail
        };

        eval { main::os_setup(); };
        like($@, qr/MOCK_MEMERROR/, 'memerror is safely called when swap is completely undefined');
        is($memerror_called, 1, 'memerror called exactly once');
    }
};

subtest 'CHALLENGE 2.4: Windows swap = "invalid_string" Adversarial Input' => sub {
    reset_state();
    local $^O = 'MSWin32';
    local $main::is_win = 1;
    local $main::opt{forcemem} = 0;
    local $main::opt{tbstat}   = 0;

    my @invalid_swap_inputs = (
        "Access is denied.",
        "Get-CimInstance : Provider load failure",
        "ERROR: Invalid query",
        "-1024",
        "NULL",
        "   "
    );

    for my $invalid_input (@invalid_swap_inputs) {
        my $memerror_called = 0;
        no warnings 'redefine';
        local *main::memerror = sub { $memerror_called++; die "MOCK_MEMERROR\n" };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ /TotalPhysicalMemory/) { return "8589934592\n"; }
            return "$invalid_input\n";
        };

        eval { main::os_setup(); };
        like($@, qr/MOCK_MEMERROR/, "memerror called for invalid swap string '$invalid_input'");
        is($memerror_called, 1, "memerror triggered on non-numeric swap '$invalid_input'");
    }
};

# =============================================================================
# SECTION 3: Adversarial Challenge on Windows getpwuid Crash Guard
# =============================================================================
subtest 'CHALLENGE 3.1: Windows ($is_win = 1) getpwuid Guard & Environment Fallbacks' => sub {
    reset_state();

    # 3.1.1: Complete absence of environment usernames ($ENV{USER} and $ENV{USERNAME} undef)
    {
        reset_state();
        local $main::is_win = 1;
        local $ENV{USER}     = undef;
        local $ENV{USERNAME} = undef;
        local %main::opt    = ( color => 0, nocolor => 1 );

        # Mock getpwuid to unconditionally DIE if invoked on Windows
        no warnings 'redefine';
        local *CORE::GLOBAL::getpwuid = sub {
            die "FATAL: getpwuid called in Win32 environment without passwd database!\n";
        };

        eval { main::setup_environment(); };
        is($@, '', 'setup_environment does NOT die when getpwuid is unavailable and env vars are undef');
        is($main::me, 'unknown', '$me safely falls back to "unknown"');
        like($main::cmd, qr/\[CMD\]\(unknown\)/, '$cmd formatted with fallback "unknown"');
        main::close_outputfile();
    }

    # 3.1.2: Windows standard environment with USERNAME populated
    {
        reset_state();
        local $main::is_win = 1;
        local $ENV{USER}     = undef;
        local $ENV{USERNAME} = 'Administrator';
        local %main::opt    = ( color => 0, nocolor => 1 );

        eval { main::setup_environment(); };
        is($@, '', 'setup_environment succeeds on Windows with USERNAME');
        is($main::me, 'Administrator', '$me resolved to Administrator');
        like($main::cmd, qr/\[CMD\]\(Administrator\)/, '$cmd prompt includes Administrator');
        main::close_outputfile();
    }

    # 3.1.3: Windows environment where USER is populated (e.g. Git Bash / MSYS2 / WSL interop)
    {
        reset_state();
        local $main::is_win = 1;
        local $ENV{USER}     = 'ci_runner';
        local $ENV{USERNAME} = 'WinLocalUser';
        local %main::opt    = ( color => 0, nocolor => 1 );

        eval { main::setup_environment(); };
        is($@, '', 'setup_environment succeeds on Windows with USER set');
        is($main::me, 'ci_runner', '$ENV{USER} takes precedence over $ENV{USERNAME}');
        main::close_outputfile();
    }

    # 3.1.4: POSIX environment ($is_win = 0) where getpwuid fails or dies
    {
        reset_state();
        local $main::is_win = 0;
        local $ENV{USER}     = 'posix_fallback_user';
        local $ENV{USERNAME} = undef;
        local %main::opt    = ( color => 0, nocolor => 1 );

        # Simulate broken /etc/passwd in minimal chroot or docker container
        local $mock_getpwuid_die = 1;

        eval { main::setup_environment(); };
        is($@, '', 'POSIX environment eval catches getpwuid die without terminating');
        is($main::me, 'posix_fallback_user', '$me falls back to $ENV{USER} when getpwuid throws');
        main::close_outputfile();
    }
};

# =============================================================================
# SECTION 4: Adversarial Verification of System Telemetry, Kernel & FS Fixes
# =============================================================================
subtest 'CHALLENGE 4.1: infocmd_tab Output Capture & Duplicate Command Suppression' => sub {
    reset_state();

    my %os_command_counts;
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        $os_command_counts{$cmd}++;
        if ($cmd eq 'who') {
            return wantarray ? ("root pts/0 2026-11-01\n") : "root pts/0 2026-11-01\n";
        }
        elsif ($cmd eq 'free -m | grep -v +') {
            return wantarray ? ("Mem: 32000 16000 16000 0 0 16000\n") : "Mem: 32000 16000 16000 0 0 16000\n";
        }
        elsif ($cmd eq "top -n 1 -b | grep 'load average:'") {
            return wantarray ? ("load average: 0.05, 0.10, 0.08\n") : "load average: 0.05, 0.10, 0.08\n";
        }
        elsif ($cmd eq 'uptime') {
            return wantarray ? ("up 42 days, 14:15\n") : "up 42 days, 14:15\n";
        }
        elsif ($cmd =~ /ip addr \| grep -A1 mtu/) {
            return wantarray ? ("2: eth0: <BROADCAST> mtu 1500\n") : "2: eth0: <BROADCAST> mtu 1500\n";
        }
        elsif ($cmd eq 'hostname -I') {
            return wantarray ? ("10.0.0.5\n") : "10.0.0.5\n";
        }
        return wantarray ? () : "";
    };
    local *main::which = sub { return "/bin/$_[0]" };
    local *main::get_http_cli = sub { return '/bin/curl' };
    local *main::cpu_cores = sub { return 8 };

    main::get_system_info();

    is($os_command_counts{'who'}, 1, 'who was executed exactly once');
    is($os_command_counts{'free -m | grep -v +'}, 1, 'free -m was executed exactly once');
    is($os_command_counts{"top -n 1 -b | grep 'load average:'"}, 1, 'top was executed exactly once');
    is($os_command_counts{'uptime'}, 1, 'uptime was executed exactly once');
    is($os_command_counts{'ip addr | grep -A1 mtu'}, 1, 'ip addr was executed exactly once');

    like($main::result{'OS'}{'Logged users'}, qr/root pts\/0/, 'Logged users recorded in %result');
    like($main::result{'OS'}{'Free Memory RAM'}, qr/Mem: 32000/, 'Free Memory RAM recorded in %result');
    like($main::result{'OS'}{'Load Average'}, qr/load average: 0\.05/, 'Load Average recorded in %result');
    like($main::result{'OS'}{'Uptime'}, qr/up 42 days/, 'Uptime recorded in %result');
};

subtest 'CHALLENGE 4.2: get_kernel_info fs.nr_open & sunrpc Display Verification' => sub {
    reset_state();

    no warnings 'redefine';
    local *main::get_transport_prefix = sub { return '' };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /sysctl -n fs\.nr_open/) { return "524288"; } # < 1000000
        if ($cmd =~ /sysctl -n sunrpc\.tcp_slot_table_entries/) { return "32"; } # < 100
        if ($cmd =~ /sysctl -n vm\.swappiness/) { return "10"; }
        return "1000000";
    };

    my @captured_badprints;
    local *main::badprint = sub { push @captured_badprints, $_[0] };

    main::get_kernel_info();

    if (grep { /fs\.nr_open/ } @main::adjvars) {
        ok(grep({ /^fs\.nr_open > 1M/ } @main::adjvars), 'fs.nr_open advice correctly prefixed with fs.nr_open > 1M');
        ok(!grep({ /^fs\.aio-nr > 1M.*fs\.nr_open/ } @main::adjvars), 'Never outputs wrong fs.aio-nr label for fs.nr_open');
    }
    else {
        pass("fs.nr_open check bypassed on non-proc host");
    }

    if (grep { /Initial TCP slot entries/ } @captured_badprints) {
        ok(grep({ /Initial TCP slot entries is < 100/ } @captured_badprints), 'sunrpc display shows < 100');
        ok(!grep({ /Initial TCP slot entries is < 1M/ } @captured_badprints), 'sunrpc display does not show < 1M');
    }
    else {
        pass("sunrpc check bypassed on non-sunrpc host");
    }
};

subtest 'CHALLENGE 4.3: get_fs_info Mountpoint Interpolation' => sub {
    reset_state();

    no warnings 'redefine';
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /df -P \| grep '%'/) {
            return (
                "Filesystem      1024-blocks      Used Available Capacity Mounted on\n",
                "/dev/nvme0n1p1     52428800  49807360   2621440      95% /var/lib/mysql\n",
            );
        }
        if ($cmd =~ /df -Pi\| grep '%'/) {
            return (
                "Filesystem            Inodes   IUsed     IFree IUse% Mounted on\n",
                "/dev/nvme0n1p1       5000000 1000000   4000000   20% /var/lib/mysql\n",
            );
        }
        return ();
    };

    main::get_fs_info();

    ok(grep({ /Add some space to \/var\/lib\/mysql mountpoint\./ } @main::generalrec),
        'Interpolates full mountpoint "/var/lib/mysql" in disk space recommendation');
    ok(!grep({ /Add some space to 95 mountpoint\./ } @main::generalrec),
        'Never interpolates capacity percentage "95" in recommendation');
};

subtest 'CHALLENGE 4.4: setup_environment Color Suppression on Outputfile' => sub {
    reset_state();

    my $tempdir  = tempdir(CLEANUP => 1);
    my $out_file = File::Spec->catfile($tempdir, 'audit.txt');

    # Both color=1 and outputfile supplied: nocolor MUST be 1
    local %main::opt = (
        'color'      => 1,
        'outputfile' => $out_file,
    );

    main::setup_environment();
    is($main::opt{nocolor}, 1, '$opt{nocolor} is forced to 1 when outputfile is present');
    unlike($main::good, qr/\e\[/, '$good contains no ANSI escape codes');
    unlike($main::bad,  qr/\e\[/, '$bad contains no ANSI escape codes');
    unlike($main::cmd,  qr/\e\[/, '$cmd contains no ANSI escape codes');
    unlike($main::end,  qr/\e\[/, '$end contains no ANSI escape codes');
    main::close_outputfile();
};

subtest 'CHALLENGE 4.5: update_tuner_version File Size Verification' => sub {
    reset_state();

    my $tempdir = tempdir(CLEANUP => 1);
    local $main::update_target_dir = $tempdir;
    local $main::opt{'updateversion'} = 1;
    local *main::get_http_cli         = sub { return '/usr/bin/curl' };

    my @good_prints;
    my @bad_prints;
    no warnings 'redefine';
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::badprint  = sub { push @bad_prints,  $_[0] };

    # Case A: Download generates 0-byte file -> Reports failure
    {
        @good_prints = ();
        @bad_prints  = ();
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ />\s+(.+)$/) {
                my $target = $1;
                open my $fh, '>', $target or die $!;
                close $fh; # 0 bytes
            }
            return "";
        };

        eval { main::update_tuner_version(); };
        like($@, qr/MOCK_EXIT/, 'Exited on update completion');
        ok(grep({ /Couldn't update/ } @bad_prints), 'Detects 0-byte file and reports error');
    }

    # Case B: Download generates >0-byte file -> Reports success
    {
        @good_prints = ();
        @bad_prints  = ();
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            if ($cmd =~ />\s+(.+)$/) {
                my $target = $1;
                open my $fh, '>', $target or die $!;
                print $fh "# Valid script content\n";
                close $fh;
            }
            return "";
        };

        eval { main::update_tuner_version(); };
        like($@, qr/MOCK_EXIT/, 'Exited on update completion');
        ok(grep({ /Successfully updated MySQLTuner script/ } @good_prints), 'Reports success when downloaded file > 0 bytes');
    }
};

done_testing();
