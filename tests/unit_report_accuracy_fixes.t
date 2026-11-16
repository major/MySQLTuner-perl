#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use Cwd qw(abs_path);

my $repo_root = abs_path( File::Spec->catdir( File::Basename::dirname(__FILE__), '..' ) );
my $script    = File::Spec->catfile( $repo_root, 'mysqltuner.pl' );
my $analyzer  = File::Spec->catfile( $repo_root, 'build', 'analyze_mt_output.pl' );

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
    require './tests/MySQLTuner/TestHelper.pm';
}

my @captured_output;
my @captured_bad;
my @captured_good;
my @captured_info;

sub reset_local_mocks {
    MySQLTuner::TestHelper::reset_state();
    @captured_output = ();
    @captured_bad    = ();
    @captured_good   = ();
    @captured_info   = ();
    $main::opt{'nocolor'}    = 1;
    $main::opt{'dbgpattern'} = '.*';
    $main::opt{'sysstat'}    = 1;
    $main::opt{'structstat'} = 1;
    $main::opt{'dbstat'}     = 1;
    $main::is_win            = 0;
    $main::is_cloud          = 0;
    $main::maxlines          = 10000;
}

{
    no warnings 'redefine';
    *main::infoprint      = sub { push @captured_output, "INFO: $_[0]";      push @captured_info, $_[0]; };
    *main::badprint       = sub { push @captured_output, "BAD: $_[0]";       push @captured_bad,  $_[0]; };
    *main::goodprint      = sub { push @captured_output, "GOOD: $_[0]";      push @captured_good, $_[0]; };
    *main::debugprint     = sub { };
    *main::subheaderprint = sub { push @captured_output, "SUBHEADER: $_[0]"; };
    *main::prettyprint    = sub { push @captured_output, "PRETTY: $_[0]"; };
}

subtest 'Container mode cgroup v2/v1 memory and swap detection in os_setup' => sub {
    plan tests => 11;

    # 1. Local cgroup v2 finite memory & swap limits cap /proc/meminfo host values
    reset_local_mocks();
    my $cg_v2 = tempdir( CLEANUP => 1 );
    open my $mf, '>', File::Spec->catfile( $cg_v2, 'memory.max' ) or die $!;
    print {$mf} "1073741824\n";
    close $mf;
    open my $sf, '>', File::Spec->catfile( $cg_v2, 'memory.swap.max' ) or die $!;
    print {$sf} "536870912\n";
    close $sf;
    my $mock_meminfo = File::Spec->catfile( $cg_v2, 'meminfo' );
    open my $mif, '>', $mock_meminfo or die $!;
    print {$mif} "MemTotal:       16777216 kB\nSwapTotal:       4194304 kB\n";
    close $mif;
    my $mock_meminfo_noswap = File::Spec->catfile( $cg_v2, 'meminfo_noswap' );
    open my $minsf, '>', $mock_meminfo_noswap or die $!;
    print {$minsf} "MemTotal:       16777216 kB\nSwapTotal:             0 kB\n";
    close $minsf;

    {
        no warnings 'redefine';
        local $ENV{MYSQLTUNER_CGROUP_DIR}      = $cg_v2;
        local $ENV{MYSQLTUNER_PROC_MEMINFO}    = $mock_meminfo;
        local *main::is_docker                 = sub { return 1; };
        local *main::get_transport_prefix      = sub { return ''; };
        local *main::detect_infrastructure     = sub { return {}; };
        local *main::get_other_process_memory  = sub { return 0; };
        local *main::execute_system_command    = sub {
            my ($cmd) = @_;
            return '16777216' if $cmd =~ /memtotal/i;
            return '4194304'  if $cmd =~ /swaptotal/i;
            return 'Linux';
        };
        local $^O = 'linux';
        $main::opt{'forcemem'}  = 0;
        $main::opt{'forceswap'} = 0;
        $main::opt{'container'} = '';
        main::os_setup();
    }
    is( $main::physical_memory, 1073741824, 'cgroup v2 memory.max caps physical_memory to 1 GiB' );
    is( $main::swap_memory,     536870912,  'cgroup v2 memory.swap.max caps swap_memory to 512 MiB' );

    # 1b. Host with SwapTotal: 0 kB stays at 0 even when memory.swap.max is higher
    reset_local_mocks();
    {
        no warnings 'redefine';
        local $ENV{MYSQLTUNER_CGROUP_DIR}      = $cg_v2;
        local $ENV{MYSQLTUNER_PROC_MEMINFO}    = $mock_meminfo_noswap;
        local *main::is_docker                 = sub { return 1; };
        local *main::get_transport_prefix      = sub { return ''; };
        local *main::detect_infrastructure     = sub { return {}; };
        local *main::get_other_process_memory  = sub { return 0; };
        local *main::execute_system_command    = sub {
            my ($cmd) = @_;
            return '16777216' if $cmd =~ /memtotal/i;
            return '0'        if $cmd =~ /swaptotal/i;
            return 'Linux';
        };
        local $^O = 'linux';
        $main::opt{'forcemem'}  = 0;
        $main::opt{'forceswap'} = 0;
        $main::opt{'container'} = '';
        main::os_setup();
    }
    is( $main::swap_memory, 0, 'cgroup v2 memory.swap.max does not inflate 0 host swap' );

    # 2. Local cgroup v2 unlimited ("max") keeps host memory without error
    reset_local_mocks();
    my $cg_unlim = tempdir( CLEANUP => 1 );
    open my $umf, '>', File::Spec->catfile( $cg_unlim, 'memory.max' ) or die $!;
    print {$umf} "max\n";
    close $umf;
    open my $usf, '>', File::Spec->catfile( $cg_unlim, 'memory.swap.max' ) or die $!;
    print {$usf} "max\n";
    close $usf;

    {
        no warnings 'redefine';
        local $ENV{MYSQLTUNER_CGROUP_DIR}      = $cg_unlim;
        local $ENV{MYSQLTUNER_PROC_MEMINFO}    = $mock_meminfo;
        local *main::is_docker                 = sub { return 1; };
        local *main::get_transport_prefix      = sub { return ''; };
        local *main::detect_infrastructure     = sub { return {}; };
        local *main::get_other_process_memory  = sub { return 0; };
        local *main::execute_system_command    = sub { return 'Linux'; };
        local $^O = 'linux';
        $main::opt{'forcemem'}  = 0;
        $main::opt{'forceswap'} = 0;
        main::os_setup();
    }
    ok( $main::physical_memory > 0, 'cgroup v2 "max" leaves host physical_memory intact' );
    is( scalar(@captured_bad), 0, 'cgroup v2 "max" triggers no errors' );

    # 3. Remote --container cgroup v1 (memory.limit_in_bytes + memory.memsw.limit_in_bytes)
    reset_local_mocks();
    {
        no warnings 'redefine';
        local *main::is_docker               = sub { return 1; };
        local *main::get_transport_prefix    = sub { return 'docker exec mock_db sh -c '; };
        local *main::detect_infrastructure   = sub { return {}; };
        local *main::get_other_process_memory = sub { return 0; };
        local *main::execute_system_command  = sub {
            my ($cmd) = @_;
            return 'Linux' if $cmd eq 'uname';
            return '16000000' if $cmd =~ /memtotal/i;
            return '4000000'  if $cmd =~ /swaptotal/i;
            if ( $cmd =~ /memory\.limit_in_bytes/ ) {
                return ( "MEM:1073741824\n", "MEMSW:2147483648\n" );
            }
            return '';
        };
        local $^O = 'linux';
        $main::opt{'forcemem'}  = 0;
        $main::opt{'forceswap'} = 0;
        $main::opt{'container'} = 'docker:mock_db';
        main::os_setup();
    }
    is( $main::physical_memory, 1073741824, 'remote container cgroup v1 caps physical_memory to 1 GiB' );
    is( $main::swap_memory,     1073741824, 'remote container cgroup v1 derives swap from memsw - mem' );
    is( scalar(@captured_bad),  0,          'remote cgroup probe emits zero badprint errors' );

    # 4. --forcemem / --forceswap precedence remains intact even in container mode
    reset_local_mocks();
    {
        no warnings 'redefine';
        local $ENV{MYSQLTUNER_CGROUP_DIR}      = $cg_v2;
        local *main::is_docker               = sub { return 1; };
        local *main::get_transport_prefix    = sub { return ''; };
        local *main::detect_infrastructure   = sub { return {}; };
        local *main::get_other_process_memory = sub { return 0; };
        local *main::execute_system_command  = sub { return 'Linux'; };
        $main::opt{'forcemem'}  = 2048;
        $main::opt{'forceswap'} = 512;
        $main::opt{'container'} = 'docker:mock_db';
        main::os_setup();
    }
    is( $main::physical_memory, 2048 * 1048576, '--forcemem overrides cgroup memory limit' );
    is( $main::swap_memory,     512 * 1048576,  '--forceswap overrides cgroup swap limit' );
    ok( scalar( grep { /Assuming 2048 MB of physical memory/ } @captured_info ), 'logs --forcemem override' );
};

subtest 'Container mode host-noise suppression across detect_infrastructure, execute_system_command, and system_recommendations' => sub {
    plan tests => 10;

    # 1. detect_infrastructure skips lsblk when container mode is active
    reset_local_mocks();
    my @infra_cmds;
    {
        no warnings 'redefine';
        local *main::is_docker              = sub { return 1; };
        local *main::get_transport_prefix   = sub { return 'docker exec mock_db sh -c '; };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            push @infra_cmds, $cmd;
            return 'x86_64';
        };
        $main::opt{'container'} = 'docker:mock_db';
        main::detect_infrastructure();
    }
    ok( !grep( { /lsblk/ } @infra_cmds ), 'detect_infrastructure does not execute lsblk in container mode' );

    # 2. execute_system_command suppresses "System command failed" when lsblk exits non-zero
    reset_local_mocks();
    my $lsblk_bin = tempdir( CLEANUP => 1 );
    open my $lfh, '>', File::Spec->catfile( $lsblk_bin, 'lsblk' ) or die $!;
    print {$lfh} "#!/bin/sh\nexit 127\n";
    close $lfh;
    chmod 0755, File::Spec->catfile( $lsblk_bin, 'lsblk' );
    {
        local $ENV{PATH} = "$lsblk_bin:$ENV{PATH}";
        local $main::opt{'container'} = '';
        main::execute_system_command("lsblk -d -n -o NAME,ROTA,DISC-GRAN,MODEL 2>/dev/null");
    }
    ok( !grep( { /System command failed:\s*lsblk/ } @captured_bad ), 'execute_system_command non-fatal whitelist suppresses lsblk failure warning' );

    # 3. system_recommendations in container mode suppresses ip/hostname/free/top/uptime/df/sysctl
    reset_local_mocks();
    my @sys_cmds;
    {
        no warnings 'redefine';
        local *main::is_remote              = sub { return 0; };
        local *main::is_docker              = sub { return 1; };
        local *main::get_transport_prefix   = sub { return 'docker exec mock_db sh -c '; };
        local *main::cpu_cores              = sub { return 4; };
        local *main::get_os_release         = sub { return 'Ubuntu 24.04'; };
        local *main::get_fs_info            = sub { push @sys_cmds, 'CALL_GET_FS_INFO'; };
        local *main::get_kernel_info        = sub { push @sys_cmds, 'CALL_GET_KERNEL_INFO'; };
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            push @sys_cmds, $cmd;
            return 'Linux' if $cmd eq 'uname';
            return '';
        };
        $main::opt{'container'}             = 'docker:mock_db';
        $main::physical_memory              = 1073741824;
        $main::mystat{'Uptime'}             = 3600;
        $main::myvar{'hostname'}            = 'mock_db';
        main::system_recommendations();
    }

    ok( !grep( { /\b(?:ip addr|hostname|free -m|top -n|uptime|who)\b/ } @sys_cmds ), 'no missing container tool probes (ip/hostname/free/top/uptime/who)' );
    ok( !grep( { /CALL_GET_FS_INFO/ } @sys_cmds ),     'skips Filesystem Linux Recommendations (get_fs_info) in container mode' );
    ok( !grep( { /CALL_GET_KERNEL_INFO/ } @sys_cmds ), 'skips Kernel Information Recommendations in container mode' );
    ok( grep( { /Machine type\s*:\s*Container/ } @captured_info ), 'preserves Machine type : Container' );
    ok( grep( { /Physical Memory \(RAM\)\s*:/ } @captured_info ),  'preserves Physical Memory (RAM) reporting' );
    ok( grep( { /Number of Core CPU\s*:\s*4/ } @captured_info ),   'preserves CPU count reporting' );
    ok( grep( { /There is less than 1,5 Gb of RAM/ } @captured_bad ), 'reports RAM size check cleanly on 1G container limit' );

    # 4. Direct get_system_info call in container mode checks tool presence before running ip/hostname/free/top/uptime
    reset_local_mocks();
    my @direct_cmds;
    {
        no warnings 'redefine';
        local *main::is_docker              = sub { return 1; };
        local *main::get_transport_prefix   = sub { return 'docker exec mock_db sh -c '; };
        local *main::cpu_cores              = sub { return 2; };
        local *main::get_os_release         = sub { return 'Debian 12'; };
        local *main::which                  = sub { return '/usr/bin/ip'; };    # Simulate host having tools container lacks
        local *main::execute_system_command = sub {
            my ($cmd) = @_;
            push @direct_cmds, $cmd;
            return '' if $cmd =~ /^command -v /;                                # Simulate missing inside container
            return 'Linux' if $cmd =~ /^uname/;
            return '';
        };
        $main::opt{'container'} = 'docker:mock_db';
        main::get_system_info();
    }
    ok( !grep( { /^(?:ip addr|hostname -I|who|free -m|top -n|uptime)/ } @direct_cmds ), 'get_system_info skips missing container tools when command -v fails' );
};

subtest 'Container mode log_file_recommendations PFS transport wrapping and stderr log capture' => sub {
    plan tests => 10;

    my $tmpdir      = tempdir( CLEANUP => 1 );
    my $docker_log  = File::Spec->catfile( $tmpdir, 'docker_log_calls.txt' );
    my $mock_docker = File::Spec->catfile( $tmpdir, 'docker' );
    open my $dfh, '>', $mock_docker or die $!;
    print {$dfh} <<"SH";
#!/usr/bin/env bash
printf '%s\\n' "\$*" >> "$docker_log"
if [ "\$1" = "exec" ]; then
    printf '%s\\n' "mysql: [Warning] Using a password on the command line interface can be insecure."
    printf '%s\\n' "2026-11-16T01:00:00Z [Warning] Mock PFS server warning"
    printf '%s\\n' "2026-11-16T01:00:01Z [Note] ready for connections"
    exit 0
fi
if [ "\$1" = "logs" ]; then
    printf '%s\\n' "2026-11-16 01:00:00 0 [Warning] Mock MariaDB stderr warning" >&2
    printf '%s\\n' "2026-11-16 01:00:01 0 [ERROR] Mock MariaDB stderr error" >&2
    printf '%s\\n' "2026-11-16 01:00:02 0 [Note] mariadbd: ready for connections." >&2
    exit 0
fi
exit 0
SH
    close $dfh;
    chmod 0755, $mock_docker;

    # 1. MySQL/Percona PFS error_log inside --container executes via transport prefix
    reset_local_mocks();
    {
        no warnings 'redefine';
        local $ENV{PATH}             = "$tmpdir:$ENV{PATH}";
        local *main::is_remote       = sub { return 0; };
        local *main::is_docker       = sub { return 1; };
        local *main::select_one      = sub { return 1; };
        local $main::opt{'container'} = 'docker:mock_mysql84';
        local $main::opt{'dbstat'}    = 1;
        local $main::mysqlcmd        = 'mysql';
        local $main::mysqllogin      = "-u 'root' -p'secret'";
        local $main::myvar{'version'}             = '8.4.11';
        local $main::myvar{'log_error_verbosity'} = 2;
        local $main::myvar{'log_error'}           = 'stderr';
        main::log_file_recommendations();
    }
    open my $rl, '<', $docker_log or die $!;
    my $calls = do { local $/; <$rl> };
    close $rl;
    like( $calls, qr/exec mock_mysql84 sh -c .*performance_schema\.error_log/, 'PFS error_log stream executes inside container transport prefix' );
    ok( grep( { /performance_schema\.error_log contains 1 warning\(s\)\./ } @captured_bad ), 'captures real PFS warning while filtering insecure CLI password warning' );
    ok( grep( { /performance_schema\.error_log doesn't contain any error\./ } @captured_good ), 'reports zero errors when PFS contains no [ERROR]' );

    # 2. MariaDB docker logs captures stderr via 2>&1 and has no stray backtick
    unlink $docker_log;
    reset_local_mocks();
    {
        no warnings 'redefine';
        local $ENV{PATH}             = "$tmpdir:$ENV{PATH}";
        local *main::is_remote       = sub { return 0; };
        local *main::is_docker       = sub { return 1; };
        local *main::select_one      = sub { return ''; };    # No PFS error_log
        local $main::opt{'container'} = 'docker:mock_mdb114';
        local $main::opt{'dbstat'}    = 1;
        local $main::myvar{'version'}      = '11.4.13-MariaDB';
        local $main::myvar{'log_warnings'} = 2;
        local $main::myvar{'log_error'}    = 'stderr';
        main::log_file_recommendations();
    }
    ok( grep( { /^Log from cloud docker:mock_mdb114 exists$/ } @captured_good ), 'Log from cloud line has no stray backtick' );
    ok( !grep( { /Log from cloud`/ } @captured_good ), 'no stray backtick in Log from cloud message' );
    ok( grep( { /docker:mock_mdb114 contains 1 warning\(s\)\./ } @captured_bad ), 'captures MariaDB stderr [Warning] lines via 2>&1' );
    ok( grep( { /docker:mock_mdb114 contains 1 error\(s\)\./ } @captured_bad ),   'captures MariaDB stderr [ERROR] lines via 2>&1' );

    # 3. Source check for systemd stderr capture and stray backtick removal
    open my $sfh, '<', $script or die "Cannot read $script: $!";
    my $src = do { local $/; <$sfh> };
    close $sfh;
    ok( $src =~ /journalctl -n \$maxlines -b\s+-u '\$unit_target' 2>&1/, 'systemd journalctl command captures stderr via 2>&1' );
    ok( $src !~ /Log from cloud`/, 'no stray backtick in Log from cloud source' );
    ok( $src !~ /Log journal`/,    'no stray backtick in Log journal source' );
};

subtest 'SQL modeling false positive fixes and CSV trailing newline' => sub {
    plan tests => 8;

    # 1. mysql_foreign_key_checks filters BASE TABLE and escapes %\_id
    my @fk_queries;
    reset_local_mocks();
    {
        no warnings 'redefine';
        local *main::select_array = sub {
            my ($q) = @_;
            push @fk_queries, $q;
            return ();
        };
        $main::myvar{'version'} = '8.0.35';
        main::mysql_foreign_key_checks();
    }
    my ($id_q) = grep { /COLUMN_NAME LIKE/ } @fk_queries;
    ok( defined $id_q, 'FK check executes unconstrained _id query' );
    like( $id_q, qr/TABLE_TYPE\s*=\s*'BASE TABLE'/i, 'FK check restricts to BASE TABLE (excludes views)' );
    like( $id_q, qr/LIKE\s+'%\\_id'/,                'FK check escapes underscore in LIKE pattern (%\\_id)' );

    # 2. mysql_naming_conventions Column Naming filters BASE TABLE
    my @naming_queries;
    reset_local_mocks();
    {
        no warnings 'redefine';
        local *main::select_array = sub {
            my ($q) = @_;
            push @naming_queries, $q;
            return ();
        };
        $main::myvar{'version'} = '8.0.35';
        main::mysql_naming_conventions();
    }
    my ($col_q) = grep { /information_schema\.columns/i } @naming_queries;
    ok( defined $col_q, 'Naming conventions executes Column Naming query' );
    like( $col_q, qr/JOIN\s+information_schema\.tables.*TABLE_TYPE\s*=\s*'BASE TABLE'/si, 'Column Naming filters to BASE TABLE only' );

    # 3. mysql_table_structures counts distinct tables on composite PKs and drops stray leading underscore
    reset_local_mocks();
    {
        no warnings 'redefine';
        local *main::mysql_naming_conventions = sub { };
        local *main::mysql_foreign_key_checks = sub { };
        local *main::mysql_80_modeling_checks = sub { };
        local *main::mysql_datatype_optimization = sub { };
        local *main::mysql_schema_sanitization   = sub { };
        local *main::dump_into_file              = sub { };
        local *main::select_array = sub {
            my ($q) = @_;
            if ( $q =~ /COLUMN_KEY = 'PRI'/ ) {
                return (
                    "employees\tdept_emp\temp_no\tint\tint\t",
                    "employees\tdept_emp\tdept_no\tchar\tchar(4)\t",
                );
            }
            return ();
        };
        $main::myvar{'version'} = '8.0.35';
        main::mysql_table_structures();
    }
    ok( grep( { $_ eq "Use 'id' or '<table>_id' for Primary Key naming in 1 table(s)" } @main::generalrec ),
        'PK naming counts 1 distinct table for 2-column composite PK without leading underscore' );
    ok( grep( { $_ eq "Use BIGINT UNSIGNED AUTO_INCREMENT for Primary Keys in 1 table(s)" } @main::generalrec ),
        'Surrogate key check counts 1 distinct table for 2-column composite PK' );

    # 4. dump_into_file appends trailing newline to non-empty .csv files
    my $dump_dir = tempdir( CLEANUP => 1 );
    reset_local_mocks();
    $main::opt{'dumpdir'}       = $dump_dir;
    $main::opt{'compress-dump'} = 0;
    main::dump_into_file( 'tables_without_primary_keys.csv', 'Schema,Table' );
    open my $cfh, '<', File::Spec->catfile( $dump_dir, 'tables_without_primary_keys.csv' ) or die $!;
    my $csv_raw = do { local $/; <$cfh> };
    close $cfh;
    is( $csv_raw, "Schema,Table\n", 'dump_into_file ensures non-empty CSV ends with trailing newline' );
};

subtest 'analyze_mt_output.pl accepts Audit Snapshot Summary and report_client_error preserves TLS hint' => sub {
    plan tests => 5;

    my $tmpdir = tempdir( CLEANUP => 1 );

    # 1. Modern report with Audit Snapshot Summary scores RC=0 (PASS)
    my $modern_out = File::Spec->catfile( $tmpdir, 'modern.txt' );
    open my $mfh, '>', $modern_out or die $!;
    print {$mfh} join(
        "\n",
        "-------- Audit Snapshot Summary --------------------------------------------------------------------",
        "-------- Storage Engine Statistics -----------------------------------------------------------------",
        "-------- Analysis Performance Metrics --------------------------------------------------------------",
        "-------- Security Recommendations ------------------------------------------------------------------",
        ("ℹ  sample diagnostic line") x 12,
        "✔  Terminated successfully",
        ""
    );
    close $mfh;

    my $res_modern = qx(perl "$analyzer" --json "$modern_out" 2>&1);
    my $rc_modern  = $? >> 8;
    is( $rc_modern, 0, 'analyze_mt_output.pl returns RC=0 on modern report with Audit Snapshot Summary' ) or diag($res_modern);
    like( $res_modern, qr/"verdict"\s*:\s*"PASS"/, 'modern report verdict is PASS' );

    # 2. Legacy report with General Statistics still scores RC=0 (PASS)
    my $legacy_out = File::Spec->catfile( $tmpdir, 'legacy.txt' );
    open my $lfh, '>', $legacy_out or die $!;
    print {$lfh} join(
        "\n",
        "-------- General Statistics ------------------------------------------------------------------------",
        "-------- Storage Engine Statistics -----------------------------------------------------------------",
        "-------- Performance Metrics -----------------------------------------------------------------------",
        "-------- Security Recommendations ------------------------------------------------------------------",
        ("-- sample diagnostic line") x 12,
        "[OK] Terminated successfully",
        ""
    );
    close $lfh;

    my $res_legacy = qx(perl "$analyzer" --json "$legacy_out" 2>&1);
    my $rc_legacy  = $? >> 8;
    is( $rc_legacy, 0, 'analyze_mt_output.pl still returns RC=0 on legacy report with General Statistics' ) or diag($res_legacy);

    # 3. report_client_error displays actionable TLS error and hint for MariaDB 10.11 vs 11.8 client
    reset_local_mocks();
    main::report_client_error("ERROR 2026 (HY000): TLS/SSL error: SSL is required, but the server does not support it");
    ok( grep( { /Client error: ERROR 2026/ } @captured_bad ), 'report_client_error surfaces ERROR 2026 cleanly' );
    ok( grep( { /TLS negotiation failed.*disable-ssl-verify-server-cert/ } @captured_info ), 'report_client_error preserves TLS negotiation hint' );
};

done_testing();
