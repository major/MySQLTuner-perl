#!/usr/bin/env perl
# tests/unit_m2_system_kernel_fs.t
# Validates Milestone 2 System Telemetry, Kernel & Filesystem Fixes:
#   - Issue 10: infocmd_tab returns output, avoids duplicate OS command executions in get_system_info
#   - Issue 10: get_all_vars eliminates duplicate SHOW VARIABLES / SHOW STATUS
#   - Issue 11: get_kernel_info corrects fs.nr_open recommendation from fs.aio-nr to fs.nr_open
#   - Issue 11: get_kernel_info corrects sunrpc threshold warning display to < 100
#   - Issue 11: get_fs_info interpolates mountpoint ($5) instead of percentage ($4)

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
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

my @mock_output;
my @mock_badprints;
sub reset_mocks {
    @mock_output      = ();
    @mock_badprints   = ();
    @main::generalrec = ();
    @main::adjvars    = ();
    @main::modeling   = ();
    @main::sysrec     = ();
    @main::secrec     = ();
    %main::result     = ();
    %main::opt        = ( dbgpattern => '.*' );
    %main::myvar      = ( version => '8.0.35', have_innodb => 'YES' );
    %main::mystat     = ();
}

{
    no warnings 'redefine';
    *main::infoprint      = sub { push @mock_output, "INFO: $_[0]" };
    *main::badprint       = sub { push @mock_output, "BAD: $_[0]"; push @mock_badprints, $_[0]; };
    *main::goodprint      = sub { push @mock_output, "GOOD: $_[0]" };
    *main::debugprint     = sub { };
    *main::subheaderprint = sub { push @mock_output, "HEADER: $_[0]" };
    *main::prettyprint    = sub { push @mock_output, "PRETTY: $_[0]" };
}

# =====================================================================
# Subtest 1: Issue 10 — infocmd_tab return value and single command execution
# =====================================================================
subtest 'Issue 10: infocmd_tab returns output and avoids duplicate OS executions' => sub {
    reset_mocks();
    my %cmd_counts;
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        $cmd_counts{$cmd}++;
        if ($cmd eq 'who') {
            return wantarray ? ("alice pts/0 2026-10-31\n", "bob pts/1 2026-10-31\n")
                             : "alice pts/0 2026-10-31\nbob pts/1 2026-10-31\n";
        }
        elsif ($cmd eq 'free -m | grep -v +') {
            return wantarray ? ("Mem: 16000 8000 8000 0 0 8000\n")
                             : "Mem: 16000 8000 8000 0 0 8000\n";
        }
        elsif ($cmd eq "top -n 1 -b | grep 'load average:'") {
            return wantarray ? ("load average: 0.15, 0.20, 0.18\n")
                             : "load average: 0.15, 0.20, 0.18\n";
        }
        elsif ($cmd eq 'uptime') {
            return wantarray ? ("up 10 days, 2:30\n")
                             : "up 10 days, 2:30\n";
        }
        elsif ($cmd =~ /ip addr \| grep -A1 mtu/) {
            return wantarray ? ("1: lo: <LOOPBACK> mtu 65536\n")
                             : "1: lo: <LOOPBACK> mtu 65536\n";
        }
        elsif ($cmd eq 'hostname -I') {
            return wantarray ? ("192.168.1.100\n")
                             : "192.168.1.100\n";
        }
        return wantarray ? () : "";
    };
    local *main::which = sub {
        my ($bin) = @_;
        return "/bin/$bin" if $bin =~ /^(?:ip|ping|curl)$/;
        return undef;
    };
    local *main::get_http_cli = sub { return '/bin/curl' };
    local *main::cpu_cores = sub { return 4 };

    # 1. Direct test of infocmd_tab return value in scalar and list context
    my $scalar_out = main::infocmd_tab("who");
    like($scalar_out, qr/alice pts\/0/, "infocmd_tab returns multiline string in scalar context");
    like($scalar_out, qr/bob pts\/1/, "infocmd_tab contains second line in scalar context");

    my @list_out = main::infocmd_tab("who");
    is(scalar(@list_out), 2, "infocmd_tab returns list in list context");
    is($list_out[0], "alice pts/0 2026-10-31", "first element stripped of newline");

    # 2. Test get_system_info execution counts
    %cmd_counts = ();
    main::get_system_info();

    is($cmd_counts{'who'}, 1, "who executed exactly once in get_system_info");
    is($cmd_counts{'free -m | grep -v +'}, 1, "free -m executed exactly once in get_system_info");
    is($cmd_counts{"top -n 1 -b | grep 'load average:'"}, 1, "top executed exactly once in get_system_info");
    is($cmd_counts{'uptime'}, 1, "uptime executed exactly once in get_system_info");
    is($cmd_counts{'ip addr | grep -A1 mtu'}, 1, "ip addr executed exactly once in get_system_info");

    # 3. Verify %result fields are populated correctly from single call
    like($main::result{'OS'}{'Logged users'}, qr/alice pts\/0/, "result Logged users populated");
    like($main::result{'OS'}{'Free Memory RAM'}, qr/Mem: 16000/, "result Free Memory RAM populated");
    like($main::result{'OS'}{'Load Average'}, qr/load average: 0.15/, "result Load Average populated");
    like($main::result{'OS'}{'Uptime'}, qr/up 10 days/, "result Uptime populated");
};

# =====================================================================
# Subtest 2: Issue 10 — get_all_vars eliminates duplicate SHOW queries
# =====================================================================
subtest 'Issue 10: get_all_vars eliminates duplicate SHOW queries' => sub {
    reset_mocks();
    my %query_counts;
    no warnings 'redefine';
    local *main::select_one = sub {
        my ($q) = @_;
        return "8.0.35-MySQL" if $q =~ /VERSION/;
        return "";
    };
    local *main::select_array = sub {
        my ($q) = @_;
        $query_counts{$q}++;
        if ($q eq 'SHOW GLOBAL VARIABLES') {
            return ("max_connections\t151", "innodb_buffer_pool_size\t134217728");
        }
        elsif ($q eq 'SHOW VARIABLES') {
            return ("max_connections\t100");
        }
        elsif ($q eq 'SHOW GLOBAL STATUS') {
            return ("Uptime\t3600", "Connections\t100");
        }
        elsif ($q eq 'SHOW STATUS') {
            return ("Uptime\t10", "Connections\t1");
        }
        elsif ($q eq 'SHOW ENGINES') {
            return ("InnoDB\tDEFAULT\tSupports transactions");
        }
        return ();
    };
    local *main::check_privileges = sub { };
    local *main::adjust_aborted_connects = sub { return (0, 100) };

    main::get_all_vars();

    is($query_counts{'SHOW GLOBAL VARIABLES'}, 1, "SHOW GLOBAL VARIABLES queried once");
    is($query_counts{'SHOW VARIABLES'} // 0, 0, "SHOW VARIABLES not queried when SHOW GLOBAL succeeds");
    is($query_counts{'SHOW GLOBAL STATUS'}, 1, "SHOW GLOBAL STATUS queried once");
    is($query_counts{'SHOW STATUS'} // 0, 0, "SHOW STATUS not queried when SHOW GLOBAL succeeds");

    is($main::myvar{'max_connections'}, 151, "myvar populated with global variables");
    is($main::mystat{'Uptime'}, 3600, "mystat populated with global status");
};

# =====================================================================
# Subtest 3: Issue 10 — get_all_vars fallback when SHOW GLOBAL is empty
# =====================================================================
subtest 'Issue 10: get_all_vars fallback to SHOW VARIABLES when GLOBAL is empty' => sub {
    reset_mocks();
    my %query_counts;
    no warnings 'redefine';
    local *main::select_one = sub {
        my ($q) = @_;
        return "5.1.73" if $q =~ /VERSION/;
        return "";
    };
    local *main::select_array = sub {
        my ($q) = @_;
        $query_counts{$q}++;
        if ($q eq 'SHOW GLOBAL VARIABLES') {
            return (); # simulate unsupported / empty
        }
        elsif ($q eq 'SHOW VARIABLES') {
            return ("max_connections\t100");
        }
        elsif ($q eq 'SHOW GLOBAL STATUS') {
            return (); # simulate unsupported / empty
        }
        elsif ($q eq 'SHOW STATUS') {
            return ("Uptime\t1800", "Connections\t50");
        }
        return ();
    };
    local *main::check_privileges = sub { };
    local *main::adjust_aborted_connects = sub { return (0, 50) };

    main::get_all_vars();

    is($query_counts{'SHOW GLOBAL VARIABLES'}, 1, "SHOW GLOBAL VARIABLES attempted");
    is($query_counts{'SHOW VARIABLES'}, 1, "Fallback to SHOW VARIABLES executed");
    is($query_counts{'SHOW GLOBAL STATUS'}, 1, "SHOW GLOBAL STATUS attempted");
    is($query_counts{'SHOW STATUS'}, 1, "Fallback to SHOW STATUS executed");

    is($main::myvar{'max_connections'}, 100, "myvar populated via fallback");
    is($main::mystat{'Uptime'}, 1800, "mystat populated via fallback");
};

# =====================================================================
# Subtest 4: Issue 11 — get_kernel_info fs.nr_open and sunrpc display
# =====================================================================
subtest 'Issue 11: get_kernel_info fixes fs.nr_open recommendation and sunrpc display' => sub {
    reset_mocks();
    no warnings 'redefine';
    local *main::get_transport_prefix = sub { return '' };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /sysctl -n fs\.nr_open/) {
            return "65536"; # < 1000000
        }
        elsif ($cmd =~ /sysctl -n sunrpc\.tcp_slot_table_entries/) {
            return "16"; # < 100
        }
        elsif ($cmd =~ /sysctl -n vm\.swappiness/) {
            return "5"; # <= 10
        }
        return "1000000";
    };

    main::get_kernel_info();

    # fs.nr_open exists on Linux hosts:
    if (grep { /fs\.nr_open/ } @main::adjvars) {
        ok(grep { /^fs\.nr_open > 1M/ } @main::adjvars,
            "fs.nr_open recommendation correctly prefixed with 'fs.nr_open > 1M'");
        ok(!grep { /^fs\.aio-nr > 1M.*fs\.nr_open/ } @main::adjvars,
            "no wrong 'fs.aio-nr' prefix for fs.nr_open recommendation");
    }
    else {
        pass("fs.nr_open check safely skipped if /proc/sys/fs/nr_open not present");
    }

    if (grep { /Initial TCP slot entries/ } @mock_badprints) {
        ok(grep { /Initial TCP slot entries is < 100/ } @mock_badprints,
            "sunrpc warning displays '< 100' instead of '< 1M'");
        ok(!grep { /Initial TCP slot entries is < 1M/ } @mock_badprints,
            "no misleading '< 1M' displayed for sunrpc");
    }
    else {
        pass("sunrpc check safely skipped if /proc/sys/sunrpc not present");
    }

    # Verify source code integrity of both fixes directly:
    open my $fh, '<', $script or die "Cannot open $script: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like($content, qr/Initial TCP slot entries is < 100/, "mysqltuner.pl contains corrected sunrpc '< 100' string");
    unlike($content, qr/Initial TCP slot entries is < 1M/, "mysqltuner.pl does not contain erroneous '< 1M' sunrpc string");
    like($content, qr/'fs\.nr_open > 1M \(echo 1048576 > \/proc\/sys\/fs\/nr_open\)/, "mysqltuner.pl contains corrected fs.nr_open > 1M recommendation");
    unlike($content, qr/'fs\.aio-nr > 1M \(echo 1048576 > \/proc\/sys\/fs\/nr_open\)/, "mysqltuner.pl does not contain erroneous fs.aio-nr prefix for nr_open");
};

# =====================================================================
# Subtest 5: Issue 11 — get_fs_info interpolates mountpoint ($5)
# =====================================================================
subtest 'Issue 11: get_fs_info interpolates mountpoint ($5) instead of percentage ($4)' => sub {
    reset_mocks();
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /df -P \| grep '%'/) {
            return (
                "Filesystem      1024-blocks      Used Available Capacity Mounted on\n",
                "/dev/sda1          10485760   9437184   1048576      90% /data\n", # >85%
            );
        }
        elsif ($cmd =~ /df -Pi\| grep '%'/) {
            return (
                "Filesystem            Inodes   IUsed     IFree IUse% Mounted on\n",
                "/dev/sda1            1000000  500000    500000   50% /data\n", # <=85%
            );
        }
        return ();
    };

    main::get_fs_info();

    ok(grep({ /Add some space to \/data mountpoint\./ } @main::generalrec),
        "generalrec contains mountpoint path '/data'");
    ok(!grep({ /Add some space to 90 mountpoint\./ } @main::generalrec),
        "generalrec does NOT interpolate percentage '90' as mountpoint");
};

done_testing();
