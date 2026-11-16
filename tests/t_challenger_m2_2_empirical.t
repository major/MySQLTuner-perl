#!/usr/bin/env perl
# tests/t_challenger_m2_2_empirical.t
# =============================================================================
# EMPIRICAL CHALLENGER ADVERSARIAL STRESS TEST SUITE — MILESTONE 2
# =============================================================================
# Focus areas:
#   1. OS command deduplication in get_system_info and infocmd_tab:
#      - who, free, top, uptime, ip/ifconfig executed only once and captured
#      - infocmd_tab return behavior in scalar and list contexts
#   2. get_all_vars caching and fallback support:
#      - duplicate SHOW VARIABLES / SHOW STATUS eliminated
#      - fallback to session SHOW when global is empty
#   3. Kernel sysctl and filesystem metrics:
#      - fs.nr_open < 1000000 outputs fs.nr_open > 1M (NOT fs.aio-nr > 1M)
#      - sunrpc.tcp_slot_table_entries < 100 outputs < 100 (NOT < 1M)
#      - get_fs_info mountpoint recommendation pushes $5 (mountpoint), NOT $4 (%)
#   4. --outputfile and --updateversion:
#      - $opt{nocolor} = 1 preserved when --outputfile given; zero ANSI codes in file
#      - update_tuner_version checks download size against -s $fullpath, not $script in CWD
# =============================================================================

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Cwd qw(abs_path getcwd);

BEGIN {
    *CORE::GLOBAL::exit = sub { die "EMPIRICAL_MOCK_EXIT\n" };
}

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Pre-declare all necessary mysqltuner.pl globals
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;
our @adjvars;
our @generalrec;
our @sysrec;
our @secrec;
our @modeling;
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

sub clean_globals {
    @main::generalrec = ();
    @main::adjvars    = ();
    @main::sysrec     = ();
    @main::secrec     = ();
    @main::modeling   = ();
    %main::result     = ();
    %main::opt        = ( dbgpattern => '.*' );
    %main::myvar      = ( version => '8.0.35', have_innodb => 'YES' );
    %main::mystat     = ();
    $main::outputfile = undef;
    $main::fh         = undef;
    $main::me         = undef;
    $main::cached_other_process_memory = undef;
    $main::update_target_dir           = undef;
}

# =============================================================================
# 1. Stress-test OS command deduplication in get_system_info and infocmd_tab
# =============================================================================
subtest '1. OS command deduplication in get_system_info and infocmd_tab' => sub {
    clean_globals();

    # 1.A infocmd_tab context handling: scalar vs list
    {
        my @captured_info;
        no warnings 'redefine';
        local *main::infoprint = sub { push @captured_info, $_[0] };

        # Multiline command output
        local *main::execute_system_command = sub {
            return ( "alpha\n", "beta\n", "gamma\n" );
        };

        # List context
        @captured_info = ();
        my @list_out = main::infocmd_tab("dummy_cmd");
        is_deeply( \@list_out, [ "alpha", "beta", "gamma" ],
            "infocmd_tab in list context returns array with trailing newlines removed" );
        is( scalar(@captured_info), 3, "infoprint called for each line" );
        is( $captured_info[0], "\talpha", "infoprint line indented with tab" );

        # Scalar context
        @captured_info = ();
        my $scalar_out = main::infocmd_tab("dummy_cmd");
        is( $scalar_out, "alpha\nbeta\ngamma",
            "infocmd_tab in scalar context returns newline-joined string" );

        # Empty output
        local *main::execute_system_command = sub { return () };
        my @empty_list = main::infocmd_tab("empty_cmd");
        is( scalar(@empty_list), 0, "infocmd_tab in list context returns empty list on empty output" );
        my $empty_scalar = main::infocmd_tab("empty_cmd");
        is( $empty_scalar, "", "infocmd_tab in scalar context returns empty string on empty output" );
    }

    # 1.B get_system_info execution count validation: commands executed EXACTLY ONCE
    {
        clean_globals();
        my %cmd_tracker;
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            my ($c) = @_;
            $cmd_tracker{$c}++;
            if ($c eq 'who') {
                return ( "user1 pts/0 (192.168.1.10)\n", "user2 pts/1 (192.168.1.20)\n" );
            }
            elsif ($c eq 'free -m | grep -v +') {
                return ( "              total        used        free      shared  buff/cache   available\n",
                         "Mem:          16384        8192        4096         256        4096       12000\n" );
            }
            elsif ($c eq "top -n 1 -b | grep 'load average:'") {
                return ("top - 14:00:00 up 5 days, load average: 0.10, 0.25, 0.30\n");
            }
            elsif ($c eq 'uptime') {
                return (" 14:00:00 up 5 days,  2 users,  load average: 0.10, 0.25, 0.30\n");
            }
            elsif ($c =~ /ip addr \| grep -A1 mtu/) {
                return ( "2: eth0: <BROADCAST,MULTICAST,UP> mtu 1500\n", "    inet 192.168.1.50/24\n" );
            }
            elsif ($c =~ /ifconfig\| grep -A1 mtu/) {
                return ( "eth0: flags=4163<UP,BROADCAST>  mtu 1500\n", "        inet 192.168.1.50\n" );
            }
            elsif ($c eq 'hostname -I') {
                return ("192.168.1.50\n");
            }
            elsif ($c eq 'uname -r') {
                return ("6.8.0-generic\n");
            }
            return ("mock\n");
        };

        local *main::get_os_release       = sub { return "Linux Ubuntu 24.04" };
        local *main::get_transport_prefix = sub { return "" };
        local *main::is_docker            = sub { return 0 };
        local *main::get_http_cli         = sub { return undef };
        local *main::cpu_cores            = sub { return 4 };
        local $main::is_win               = 0;

        # Case 1: 'ip' command available
        local *main::which = sub {
            my ($bin) = @_;
            return "/bin/ip" if $bin eq 'ip';
            return undef;
        };

        %cmd_tracker = ();
        main::get_system_info();

        is( $cmd_tracker{'who'} // 0, 1, "'who' executed EXACTLY ONCE" );
        is( $cmd_tracker{'free -m | grep -v +'} // 0, 1, "'free -m' executed EXACTLY ONCE" );
        is( $cmd_tracker{"top -n 1 -b | grep 'load average:'"} // 0, 1, "'top' executed EXACTLY ONCE" );
        is( $cmd_tracker{'uptime'} // 0, 1, "'uptime' executed EXACTLY ONCE" );
        is( $cmd_tracker{'ip addr | grep -A1 mtu'} // 0, 1, "'ip addr' executed EXACTLY ONCE" );
        is( $cmd_tracker{'ifconfig| grep -A1 mtu'} // 0, 0, "'ifconfig' was NOT called when 'ip' exists" );

        # Verify hash values in %result are clean multiline strings captured in scalar context
        like( $main::result{'OS'}{'Logged users'}, qr/user1 pts\/0/, "Logged users captured cleanly" );
        like( $main::result{'OS'}{'Free Memory RAM'}, qr/Mem:\s+16384/, "Free Memory RAM captured cleanly" );
        like( $main::result{'OS'}{'Load Average'}, qr/load average: 0\.10/, "Load Average captured cleanly" );
        like( $main::result{'OS'}{'Uptime'}, qr/14:00:00 up 5 days/, "Uptime captured cleanly" );
        like( $main::result{'Network'}{'Internal Ip'}, qr/eth0:.*mtu 1500/s, "Network cards captured cleanly" );

        # Case 2: 'ip' missing, 'ifconfig' available
        local *main::which = sub {
            my ($bin) = @_;
            return "/sbin/ifconfig" if $bin eq 'ifconfig';
            return undef;
        };

        %cmd_tracker = ();
        main::get_system_info();
        is( $cmd_tracker{'ifconfig| grep -A1 mtu'} // 0, 1, "'ifconfig' executed EXACTLY ONCE when 'ip' missing" );
        is( $cmd_tracker{'ip addr | grep -A1 mtu'} // 0, 0, "'ip addr' NOT called" );
        like( $main::result{'Network'}{'Internal Ip'}, qr/flags=4163.*mtu 1500/s, "ifconfig output captured" );
    }
};

# =============================================================================
# 2. Stress-test get_all_vars caching and fallback support
# =============================================================================
subtest '2. get_all_vars caching and fallback support' => sub {
    clean_globals();

    my %query_tracker;
    no warnings 'redefine';
    local *main::select_one = sub { return "8.0.35-MySQL" };
    local *main::check_privileges = sub { };
    local *main::adjust_aborted_connects = sub { return ( 2, 150 ) };

    # 2.A Primary path: SHOW GLOBAL succeeds -> SHOW VARIABLES/STATUS eliminated
    {
        %query_tracker = ();
        local *main::select_array = sub {
            my ($q) = @_;
            $query_tracker{$q}++;
            if ($q eq 'SHOW GLOBAL VARIABLES') {
                return ( "max_connections\t200", "table_open_cache\t4000" );
            }
            elsif ($q eq 'SHOW VARIABLES') {
                return ( "max_connections\t50" );
            }
            elsif ($q eq 'SHOW GLOBAL STATUS') {
                return ( "Uptime\t86400", "Connections\t150" );
            }
            elsif ($q eq 'SHOW STATUS') {
                return ( "Uptime\t100" );
            }
            return ();
        };

        main::get_all_vars();

        is( $query_tracker{'SHOW GLOBAL VARIABLES'}, 1, "SHOW GLOBAL VARIABLES queried once" );
        is( $query_tracker{'SHOW VARIABLES'} // 0, 0, "Duplicate SHOW VARIABLES eliminated" );
        is( $query_tracker{'SHOW GLOBAL STATUS'}, 1, "SHOW GLOBAL STATUS queried once" );
        is( $query_tracker{'SHOW STATUS'} // 0, 0, "Duplicate SHOW STATUS eliminated" );

        is( $main::myvar{'max_connections'}, 200, "myvar populated with global variables" );
        is( $main::mystat{'Uptime'}, 86400, "mystat populated with global status" );
    }

    # 2.B Fallback path: SHOW GLOBAL returns empty -> SHOW VARIABLES/STATUS executed
    {
        clean_globals();
        %query_tracker = ();
        local *main::select_array = sub {
            my ($q) = @_;
            $query_tracker{$q}++;
            if ($q eq 'SHOW GLOBAL VARIABLES') {
                return (); # empty or permission denied
            }
            elsif ($q eq 'SHOW VARIABLES') {
                return ( "max_connections\t100", "table_open_cache\t2000" );
            }
            elsif ($q eq 'SHOW GLOBAL STATUS') {
                return (); # empty
            }
            elsif ($q eq 'SHOW STATUS') {
                return ( "Uptime\t3600", "Connections\t50" );
            }
            return ();
        };

        main::get_all_vars();

        is( $query_tracker{'SHOW GLOBAL VARIABLES'}, 1, "SHOW GLOBAL VARIABLES attempted" );
        is( $query_tracker{'SHOW VARIABLES'}, 1, "Fell back to SHOW VARIABLES" );
        is( $query_tracker{'SHOW GLOBAL STATUS'}, 1, "SHOW GLOBAL STATUS attempted" );
        is( $query_tracker{'SHOW STATUS'}, 1, "Fell back to SHOW STATUS" );

        is( $main::myvar{'max_connections'}, 100, "myvar populated from fallback query" );
        is( $main::mystat{'Uptime'}, 3600, "mystat populated from fallback query" );
    }

    # 2.C Partial fallback: GLOBAL VARIABLES succeeds, GLOBAL STATUS is empty
    {
        clean_globals();
        %query_tracker = ();
        local *main::select_array = sub {
            my ($q) = @_;
            $query_tracker{$q}++;
            if ($q eq 'SHOW GLOBAL VARIABLES') {
                return ( "max_connections\t300" );
            }
            elsif ($q eq 'SHOW VARIABLES') {
                return ( "max_connections\t999" );
            }
            elsif ($q eq 'SHOW GLOBAL STATUS') {
                return (); # empty
            }
            elsif ($q eq 'SHOW STATUS') {
                return ( "Uptime\t7200" );
            }
            return ();
        };

        main::get_all_vars();

        is( $query_tracker{'SHOW GLOBAL VARIABLES'}, 1, "GLOBAL VARIABLES executed" );
        is( $query_tracker{'SHOW VARIABLES'} // 0, 0, "SESSION VARIABLES was NOT executed" );
        is( $query_tracker{'SHOW GLOBAL STATUS'}, 1, "GLOBAL STATUS executed" );
        is( $query_tracker{'SHOW STATUS'}, 1, "SESSION STATUS executed as fallback" );

        is( $main::myvar{'max_connections'}, 300, "myvar populated with global value" );
        is( $main::mystat{'Uptime'}, 7200, "mystat populated with fallback session value" );
    }
};

# =============================================================================
# 3. Stress-test kernel sysctl and filesystem metrics
# =============================================================================
subtest '3. Kernel sysctl recommendations and filesystem mountpoint parsing' => sub {
    clean_globals();

    # 3.A Check get_kernel_info: fs.nr_open < 1000000 outputs fs.nr_open > 1M (NOT fs.aio-nr)
    {
        clean_globals();
        no warnings 'redefine';
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($c) = @_;
            return "500000\n" if $c =~ /fs\.nr_open/;
            return "2000000\n" if $c =~ /fs\.aio-max-nr/;
            return "128\n" if $c =~ /sunrpc\.tcp_slot_table_entries/;
            return "5\n" if $c =~ /vm\.swappiness/;
            return "0\n";
        };

        main::get_kernel_info();

        if ( -f "/proc/sys/fs/nr_open" ) {
            ok( grep( { /setup running number of open request greater than 1M/ } @main::generalrec ),
                "generalrec contains running number of open request greater than 1M" );
            ok( grep( { /^fs\.nr_open > 1M \(echo 1048576 > \/proc\/sys\/fs\/nr_open\)/ } @main::adjvars ),
                "adjvars contains 'fs.nr_open > 1M' recommendation" );
            ok( !grep( { /^fs\.aio-nr > 1M.*\/proc\/sys\/fs\/nr_open/ } @main::adjvars ),
                "adjvars DOES NOT contain wrong 'fs.aio-nr' label for nr_open" );
            ok( grep( { /^fs\.nr_open > 1M/ } @main::sysrec ),
                "sysrec contains 'fs.nr_open > 1M' recommendation" );
        }
        else {
            pass("Host lacks /proc/sys/fs/nr_open (simulated in file verification below)");
        }
    }

    # 3.B Check get_kernel_info: sunrpc.tcp_slot_table_entries < 100 displays < 100 (NOT < 1M)
    {
        clean_globals();
        my @intercepted_bads;
        no warnings 'redefine';
        local *main::badprint = sub { push @intercepted_bads, $_[0] };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($c) = @_;
            return "32\n" if $c =~ /sunrpc\.tcp_slot_table_entries/;
            return "2000000\n";
        };

        main::get_kernel_info();

        if ( -d "/proc/sys/sunrpc" ) {
            ok( grep( { /Initial TCP slot entries is < 100/ } @intercepted_bads ),
                "badprint explicitly warns 'Initial TCP slot entries is < 100'" );
            ok( !grep( { /Initial TCP slot entries is < 1M/ } @intercepted_bads ),
                "badprint DOES NOT contain '< 1M' for sunrpc" );
            ok( grep( { /setup Initial TCP slot entries greater than 100/ } @main::generalrec ),
                "generalrec contains 'setup Initial TCP slot entries greater than 100'" );
            ok( grep( { /^sunrpc\.tcp_slot_table_entries > 100/ } @main::adjvars ),
                "adjvars contains sunrpc > 100 advice" );
        }
        else {
            pass("Host lacks /proc/sys/sunrpc (simulated in file verification below)");
        }
    }

    # Verify source file exact string content for kernel sysctl fixes
    {
        open my $fh, '<', $script or die "Cannot open $script: $!";
        my $source_code = do { local $/; <$fh> };
        close $fh;

        like( $source_code, qr/Initial TCP slot entries is < 100/,
            "mysqltuner.pl contains corrected sunrpc warning '< 100'" );
        unlike( $source_code, qr/Initial TCP slot entries is < 1M/,
            "mysqltuner.pl does NOT contain erroneous sunrpc '< 1M' warning" );
        like( $source_code, qr/'fs\.nr_open > 1M \(echo 1048576 > \/proc\/sys\/fs\/nr_open\)/,
            "mysqltuner.pl contains corrected fs.nr_open > 1M recommendation" );
        unlike( $source_code, qr/'fs\.aio-nr > 1M \(echo 1048576 > \/proc\/sys\/fs\/nr_open\)/,
            "mysqltuner.pl does NOT contain erroneous fs.aio-nr prefix for nr_open" );
    }

    # 3.C Check get_fs_info mountpoint parsing: pushes $5 (mountpoint), NOT $4 (percentage)
    {
        clean_globals();
        no warnings 'redefine';
        local *main::execute_system_command = sub {
            my ($c) = @_;
            if ($c =~ /df -P \| grep '%'/) {
                return (
                    "Filesystem      1024-blocks      Used Available Capacity Mounted on\n",
                    "/dev/sda1          10485760   9437184   1048576      90% /var/lib/mysql\n",
                    "/dev/sdb1          20971520  19922944   1048576      95% /mnt/database volume\n",
                    "/dev/sdc1           5242880   1048576   4194304      20% /opt/app\n",
                    "/dev/loop0           100000     99000      1000      99% /snap/core/1234\n",
                    "tmpfs                100000     95000      5000      95% /run\n",
                );
            }
            elsif ($c =~ /df -Pi\| grep '%'/) {
                return (
                    "Filesystem            Inodes   IUsed     IFree IUse% Mounted on\n",
                    "/dev/sda1            1000000  950000     50000   95% /var/lib/mysql\n",
                    "/dev/sdb1            2000000  100000   1900000    5% /mnt/database volume\n",
                );
            }
            return ();
        };

        main::get_fs_info();

        ok( grep( { /Add some space to \/var\/lib\/mysql mountpoint\./ } @main::generalrec ),
            "generalrec pushed mountpoint path '/var/lib/mysql' (interpolating \$5)" );
        ok( grep( { /Add some space to \/mnt\/database volume mountpoint\./ } @main::generalrec ),
            "generalrec correctly handles mountpoint with spaces: '/mnt/database volume'" );

        ok( !grep( { /Add some space to 90 mountpoint\./ } @main::generalrec ),
            "generalrec DOES NOT push percentage '90' as mountpoint" );
        ok( !grep( { /Add some space to 95 mountpoint\./ } @main::generalrec ),
            "generalrec DOES NOT push percentage '95' as mountpoint" );

        ok( !grep( { /Add some space to \/snap/ } @main::generalrec ),
            "Excluded filesystem /snap was filtered out" );
        ok( !grep( { /Add some space to \/run/ } @main::generalrec ),
            "Excluded filesystem /run was filtered out" );

        ok( grep( { /Cleanup files from \/var\/lib\/mysql mountpoint or reformat your filesystem\./ } @main::generalrec ),
            "Inode exhaustion recommendation pushes mountpoint path '/var/lib/mysql'" );
    }
};

# =============================================================================
# 4. Stress-test --outputfile and --updateversion
# =============================================================================
subtest '4. --outputfile ANSI code suppression and --updateversion -s $fullpath check' => sub {
    clean_globals();

    # 4.A Verify $opt{nocolor} = 1 is preserved with --outputfile, and file has NO ANSI codes
    {
        my $td = tempdir(CLEANUP => 1);
        my $target_report = File::Spec->catfile($td, 'mysql_tuner_audit.txt');

        local %main::opt = (
            'outputfile' => $target_report,
            'color'      => 1, # User explicitly specified color
        );

        main::setup_environment();

        is( $main::opt{nocolor}, 1, '$opt{nocolor} is 1 when outputfile is specified, overriding color' );

        unlike( $main::good, qr/\e\[/, '$good prefix contains no ANSI sequences' );
        unlike( $main::bad,  qr/\e\[/, '$bad prefix contains no ANSI sequences' );
        unlike( $main::info, qr/\e\[/, '$info prefix contains no ANSI sequences' );
        unlike( $main::deb,  qr/\e\[/, '$deb prefix contains no ANSI sequences' );
        unlike( $main::cmd,  qr/\e\[/, '$cmd prefix contains no ANSI sequences' );
        unlike( $main::end,  qr/\e\[/, '$end prefix contains no ANSI sequences' );

        # Call real printing methods that write to $fh
        main::goodprint("Storage engine InnoDB is active");
        main::badprint("Table scan threshold exceeded");
        main::infoprint("Buffer pool size configured to 16GB");
        main::cmdprint("SHOW GLOBAL STATUS");

        main::close_outputfile();

        # Read back the generated file and verify absence of escape sequences
        open my $rfh, '<', $target_report or die "Cannot open $target_report: $!";
        my $file_content = do { local $/; <$rfh> };
        close $rfh;

        unlike( $file_content, qr/\e\[[0-9;]*[a-zA-Z]/,
            "Target outputfile is completely clean of ANSI escape sequences" );
        like( $file_content, qr/(?:\[OK\]|✔)\s+Storage engine InnoDB is active/, "File contains uncolored OK/checkmark" );
        like( $file_content, qr/(?:\[!!\]|✘)\s+Table scan threshold exceeded/, "File contains uncolored !!/cross" );
        like( $file_content, qr/(?:\[--\]|ℹ)\s+Buffer pool size configured to 16GB/, "File contains uncolored --/info icon" );
    }

    # 4.A2 Verify with noprettyicon=1 that ASCII tags [OK], [!!], [--] appear without ANSI
    {
        my $td = tempdir(CLEANUP => 1);
        my $target_report = File::Spec->catfile($td, 'mysql_tuner_audit_nopretty.txt');

        clean_globals();
        local %main::opt = (
            'outputfile'   => $target_report,
            'color'        => 1,
            'noprettyicon' => 1,
        );

        main::setup_environment();

        is( $main::opt{nocolor}, 1, '$opt{nocolor} is 1 when outputfile is specified with noprettyicon' );
        is( $main::good, '[OK]', '$good is plain [OK]' );
        is( $main::bad,  '[!!]', '$bad is plain [!!]' );
        is( $main::info, '[--]', '$info is plain [--]' );

        main::goodprint("Storage engine InnoDB is active");
        main::badprint("Table scan threshold exceeded");
        main::infoprint("Buffer pool size configured to 16GB");

        main::close_outputfile();

        open my $rfh, '<', $target_report or die "Cannot open $target_report: $!";
        my $file_content = do { local $/; <$rfh> };
        close $rfh;

        unlike( $file_content, qr/\e\[/, "Outputfile contains zero ANSI codes" );
        like( $file_content, qr/\[OK\] Storage engine InnoDB is active/, "File contains plain [OK]" );
        like( $file_content, qr/\[!!\] Table scan threshold exceeded/, "File contains plain [!!]" );
        like( $file_content, qr/\[--\] Buffer pool size configured to 16GB/, "File contains plain [--]" );
    }

    # 4.B Inverted case: --color=1 WITHOUT --outputfile preserves colored output on terminal
    {
        clean_globals();
        local %main::opt = ( 'color' => 1 );
        local $main::is_win = 0;

        main::setup_environment();

        is( $main::opt{nocolor}, 0, '$opt{nocolor} is 0 when color requested without outputfile' );
        like( $main::good, qr/\e\[0;32m/, '$good icon has ANSI green sequence' );
        like( $main::bad,  qr/\e\[0;31m/, '$bad icon has ANSI red sequence' );
        main::close_outputfile();
    }

    # 4.C update_tuner_version checks -s $fullpath rather than -s $script in CWD
    {
        clean_globals();
        my $target_dir = tempdir(CLEANUP => 1);
        my $cwd_dir    = tempdir(CLEANUP => 1);

        # Scenario 1: Truncated/0-byte download at $fullpath, while CWD has existing script (>0 bytes)
        # Previous bug checked -s $script in CWD and falsely claimed success.
        # Fixed code checks -s $fullpath and correctly flags failure.
        {
            clean_globals();
            my $cwd_script = File::Spec->catfile($cwd_dir, 'mysqltuner.pl');
            open my $cfh, '>', $cwd_script or die "Cannot write $cwd_script: $!";
            print $cfh "#!/usr/bin/perl\n# Existing script in CWD\n" x 5;
            close $cfh;

            local $main::update_target_dir = $target_dir;
            local $main::opt{'updateversion'} = 1;
            local *main::get_http_cli = sub { return '/usr/bin/curl' };

            my @bad_prints;
            my @good_prints;
            no warnings 'redefine';
            local *main::badprint  = sub { push @bad_prints,  $_[0] };
            local *main::goodprint = sub { push @good_prints, $_[0] };
            local *main::execute_system_command = sub {
                my ($c) = @_;
                if ($c =~ />\s+(.+)$/) {
                    my $dest = $1;
                    open my $dfh, '>', $dest or die "Cannot write $dest: $!";
                    # 0 bytes (download failed/truncated)
                    close $dfh;
                }
                return "";
            };

            my $orig_cwd = getcwd();
            chdir $cwd_dir or die "Cannot chdir to $cwd_dir: $!";

            eval { main::update_tuner_version(); };
            chdir $orig_cwd;

            like( $@, qr/EMPIRICAL_MOCK_EXIT/, "update_tuner_version completed and exited" );
            ok( grep( { /Couldn't update mysqltuner\.pl/ } @bad_prints ),
                "Correctly reports failure because -s \$fullpath is 0 bytes (does not falsely trust CWD script)" );
            ok( !grep( { /Successfully updated MySQLTuner script/ } @good_prints ),
                "Does NOT declare overall success when download failed" );
        }

        # Scenario 2: Successful download at $fullpath (>0 bytes), while CWD has NO script
        # Previous bug checked -s $script in CWD (which didn't exist) and falsely failed.
        # Fixed code checks -s $fullpath and correctly succeeds.
        {
            clean_globals();
            local $main::update_target_dir = $target_dir;
            local $main::opt{'updateversion'} = 1;
            local *main::get_http_cli = sub { return '/usr/bin/curl' };

            my @bad_prints;
            my @good_prints;
            no warnings 'redefine';
            local *main::badprint  = sub { push @bad_prints,  $_[0] };
            local *main::goodprint = sub { push @good_prints, $_[0] };
            local *main::execute_system_command = sub {
                my ($c) = @_;
                if ($c =~ />\s+(.+)$/) {
                    my $dest = $1;
                    open my $dfh, '>', $dest or die "Cannot write $dest: $!";
                    print $dfh "#!/usr/bin/perl\nprint 'UPDATED';\n";
                    close $dfh;
                }
                return "OK";
            };

            my $orig_cwd = getcwd();
            chdir $cwd_dir or die "Cannot chdir: $!";

            eval { main::update_tuner_version(); };
            chdir $orig_cwd;

            like( $@, qr/EMPIRICAL_MOCK_EXIT/, "update_tuner_version completed and exited" );
            ok( grep( { /Successfully updated MySQLTuner script/ } @good_prints ),
                "Reports overall success based on -s \$fullpath" );
            is( scalar(@bad_prints), 0, "No download errors reported" );
        }

        # Scenario 3: wget command directs output to -O $fullpath
        {
            clean_globals();
            local $main::update_target_dir = $target_dir;
            local $main::opt{'updateversion'} = 1;
            local *main::get_http_cli = sub { return '/usr/bin/wget' };

            my @intercepted_wget_cmds;
            no warnings 'redefine';
            local *main::execute_system_command = sub {
                my ($c) = @_;
                push @intercepted_wget_cmds, $c;
                if ($c =~ /-O\s+(\S+)/) {
                    my $dest = $1;
                    open my $dfh, '>', $dest or die "Cannot write $dest: $!";
                    print $dfh "#!/usr/bin/perl\n# WGET SUCCESS\n";
                    close $dfh;
                }
                return "OK";
            };

            eval { main::update_tuner_version(); };
            like( $@, qr/EMPIRICAL_MOCK_EXIT/, "wget update finished" );
            for my $wcmd (@intercepted_wget_cmds) {
                like( $wcmd, qr/-O\s+\Q$target_dir\E\/(?:mysqltuner\.pl|basic_passwords\.txt|vulnerabilities\.csv)/,
                    "wget uses -O \$fullpath rather than -O \$script" );
            }
        }
    }
};

# =============================================================================
# 5. Additional M2 telemetry & Windows compatibility stress tests
# =============================================================================
subtest '5. Telemetry & Windows compatibility stress tests' => sub {
    clean_globals();

    # 5.A setup_environment preserves $opt{noprocess} = 1
    {
        clean_globals();
        %main::opt = ( noprocess => 1 );
        main::setup_environment();
        is( $main::opt{noprocess}, 1, '$opt{noprocess} preserved as 1 in setup_environment' );
        main::close_outputfile();
    }

    # 5.B get_other_process_memory immediately returns 0 on noprocess
    {
        clean_globals();
        local $main::opt{noprocess} = 1;
        local $main::cached_other_process_memory = undef;
        my $ps_executed = 0;
        no warnings 'redefine';
        local *main::execute_system_command = sub { $ps_executed++; return (); };

        my $mem = main::get_other_process_memory();
        is( $mem, 0, 'get_other_process_memory returns 0 on $opt{noprocess}' );
        is( $ps_executed, 0, 'ps command was not executed' );
    }

    # 5.C Process filtering: mariadbd and garbd exclusion
    {
        clean_globals();
        local $main::opt{noprocess} = 0;
        local $main::opt{tbstat}    = 1;
        local $main::is_win         = 0;
        local $main::opt{dumpdir}   = '/tmp/test_dump';
        local $main::cached_other_process_memory = undef;

        my @sample_ps = (
            "  PID   RSS %CPU COMMAND",
            " 1001  2048  0.2 /usr/sbin/mysqld --basedir=/usr",
            " 1002  4096  0.5 /usr/sbin/mariadbd --user=mysql",
            " 1003   512  0.1 /usr/bin/garbd --group=my_wsrep_cluster",
            " 1004  8192  1.2 /usr/bin/java -jar /opt/backend.jar", # 8192 KB
            " 1005  2048  0.4 /usr/sbin/nginx -g daemon on;"       # 2048 KB
        );

        my ($dump_file, $dump_body);
        no warnings 'redefine';
        local *main::execute_system_command = sub { return @sample_ps; };
        local *main::dump_into_file = sub { ($dump_file, $dump_body) = @_; };

        my $total_bytes = main::get_other_process_memory();

        # Expected: java (8192) + nginx (2048) = 10240 KB * 1024 = 10485760 bytes
        is( $total_bytes, 10240 * 1024, "Correctly summed only non-DB user processes (10240 KB)" );
        unlike( $dump_body, qr/mariadbd/, "mariadbd excluded from non_mysqld_processes dump" );
        unlike( $dump_body, qr/garbd/, "garbd excluded from non_mysqld_processes dump" );
        unlike( $dump_body, qr/mysqld/, "mysqld excluded from non_mysqld_processes dump" );
        like( $dump_body, qr/java/, "java included in non_mysqld_processes dump" );
        like( $dump_body, qr/nginx/, "nginx included in non_mysqld_processes dump" );
    }

    # 5.D Windows swap calculation: FreeVirtualMemory KB converted to bytes (* 1024)
    {
        clean_globals();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        local $main::opt{forcemem} = 0;
        local $main::opt{tbstat}   = 0;
        no warnings 'redefine';
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($c) = @_;
            return "17179869184\n" if $c =~ /TotalPhysicalMemory/;
            return "8388608\n"     if $c =~ /FreeVirtualMemory/; # 8 GB in KB
            return "";
        };

        main::os_setup();
        is( $main::result{'OS'}{'Swap Memory'}{'bytes'}, 8388608 * 1024,
            "FreeVirtualMemory scaled by 1024 into bytes (8589934592)" );
        is( $main::result{'OS'}{'Swap Memory'}{'pretty'}, "8.0G",
            "Swap memory pretty-printed as 8.0G" );
    }

    # 5.E Windows swap = 0 (paging disabled) does NOT trigger memerror
    {
        clean_globals();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        local $main::opt{forcemem} = 0;
        local $main::opt{tbstat}   = 0;
        my $memerror_called = 0;
        no warnings 'redefine';
        local *main::memerror = sub { $memerror_called++; die "MEMERROR\n" };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($c) = @_;
            return "8589934592\n" if $c =~ /TotalPhysicalMemory/;
            return "0\n"          if $c =~ /FreeVirtualMemory/; # 0 swap
            return "";
        };

        eval { main::os_setup(); };
        is( $@, '', "os_setup did not die on swap == 0" );
        is( $memerror_called, 0, "memerror was NOT called for swap == 0" );
        is( $main::result{'OS'}{'Swap Memory'}{'bytes'}, 0, "Swap bytes recorded as 0" );
    }

    # 5.F Windows undefined or non-numeric swap DOES call memerror
    {
        clean_globals();
        local $^O = 'MSWin32';
        local $main::is_win = 1;
        local $main::opt{forcemem} = 0;
        local $main::opt{tbstat}   = 0;
        my $memerror_called = 0;
        no warnings 'redefine';
        local *main::memerror = sub { $memerror_called++; die "MEMERROR\n" };
        local *main::get_transport_prefix = sub { return "" };
        local *main::execute_system_command = sub {
            my ($c) = @_;
            return "8589934592\n" if $c =~ /TotalPhysicalMemory/;
            return ""; # Both CIM and WMIC fail to return swap
        };

        eval { main::os_setup(); };
        like( $@, qr/MEMERROR/, "memerror invoked when swap cannot be determined" );
        is( $memerror_called, 1, "memerror called once" );
    }

    # 5.G Windows getpwuid guard prevents fatal crash
    {
        clean_globals();
        local $main::is_win = 1;
        local $ENV{USER}     = undef;
        local $ENV{USERNAME} = 'LocalAdmin';
        local %main::opt    = ( color => 0, nocolor => 1 );

        eval { main::setup_environment(); };
        is( $@, '', "setup_environment survives on Windows without /etc/passwd" );
        is( $main::me, 'LocalAdmin', '$me resolved from $ENV{USERNAME}' );
        main::close_outputfile();
    }
};

done_testing();
