#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_ponytail_audit_fixes.t
# Description: TDD validation for Wave 4 /ponytail audit remediations (#1-#9,
#              #11, #14-#16, #18): Core JSON::PP migration, exit codes, shell
#              and SQL escaping, replica lag NULL safety, is_mariadb() version
#              gating, check_query_anti_patterns, historical_comparison keys,
#              --agent-json formatting, PFS error_log, update_tuner_version,
#              HTML XSS / CSV escaping, dumpdir guard, OS/kernel/FS guards,
#              and --feature allowlisting.
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Temp qw(tempdir tempfile);
use File::Spec;
use File::Basename;
use Cwd 'abs_path';
use JSON::PP qw(decode_json);

our $mock_exit_active = 0;
our $mock_exit_code;

BEGIN {
    *CORE::GLOBAL::exit = sub {
        my $code = shift // 0;
        if ($mock_exit_active) {
            $mock_exit_code = $code;
            die "MOCK_EXIT:$code\n";
        }
        CORE::exit($code);
    };
}

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

my $script_dir = dirname( abs_path(__FILE__) );
my $root_dir   = abs_path( File::Spec->catdir( $script_dir, '..' ) );
my $script     = File::Spec->catfile( $root_dir, 'mysqltuner.pl' );

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}
require File::Spec->catfile( $root_dir, 'tests', 'MySQLTuner', 'TestHelper.pm' );

# ---------------------------------------------------------------------------
# Subtest 1 (#1): Core JSON::PP enforcement, compliance whitelist, MAIN rc
# ---------------------------------------------------------------------------
subtest '#1: Core JSON::PP migration, compliance whitelist, and dump_result exit propagation' => sub {
    plan tests => 6;

    open my $sfh, '<', $script or die "Cannot read $script: $!";
    my $code = '';
    while ( my $line = <$sfh> ) {
        last if $line =~ /^__(?:END|DATA)__/;
        next if $line =~ /^\s*#/;
        $code .= $line;
    }
    close $sfh;

    is( scalar( () = $code =~ /\brequire\s+JSON\b(?!::PP)/g ), 0, 'mysqltuner.pl does not require non-core JSON' );
    is( scalar( () = $code =~ /\bJSON->new\b/g ), 0, 'mysqltuner.pl does not invoke JSON->new (uses JSON::PP)' );

    my $comp = File::Spec->catfile( $root_dir, 'build', 'check_compliance.pl' );
    open my $cfh, '<', $comp or die "Cannot read $comp: $!";
    my $comp_src = do { local $/; <$cfh> };
    close $cfh;
    unlike( $comp_src, qr/'JSON'(?!::PP)/, "build/check_compliance.pl removes non-core 'JSON' from whitelist" );

    my $comp_out = `perl \Q$comp\E 2>&1`;
    is( $? >> 8, 0, 'check_compliance.pl exits 0 cleanly' );

    # dump_result returns non-zero when --json and --yaml are mutually exclusive
    MySQLTuner::TestHelper::reset_state();
    local %main::opt = ( 'json' => 1, 'yaml' => 1, 'silent' => 1 );
    my $stderr_buf = '';
    {
        open my $olderr, '>&', \*STDERR or die $!;
        close STDERR;
        open STDERR, '>', \$stderr_buf or die $!;
        my $rc = main::dump_result();
        close STDERR;
        open STDERR, '>&', $olderr or die $!;
        is( $rc, 1, 'dump_result returns 1 on --json + --yaml mutual exclusion' );
    }

    like( $code, qr/\$dump_rc\s*=\s*dump_result/, 'MAIN captures dump_result() return code and propagates non-zero exit' );
};

# ---------------------------------------------------------------------------
# Subtest 2 (#2): get_all_vars exits with 1 instead of 256 on DB failure
# ---------------------------------------------------------------------------
subtest '#2: get_all_vars exits with non-zero code 1 instead of 256' => sub {
    plan tests => 2;
    MySQLTuner::TestHelper::reset_state();
    no warnings 'redefine';
    local *main::badprint   = sub { };
    local *main::infoprint  = sub { };
    local *main::debugprint = sub { };
    local *main::select_one = sub { return undef; };

    # Mock sleep via CORE::GLOBAL? Avoid 2s test delay by temporarily redefining select_one?
    # Note: 3 retries * 1s sleep is brief; test exact exit code.
    local $mock_exit_active = 1;
    local $mock_exit_code   = undef;
    eval { main::get_all_vars(); };
    like( $@, qr/MOCK_EXIT:1/, 'get_all_vars exited via MOCK_EXIT' );
    is( $mock_exit_code, 1, 'get_all_vars exits with code 1 (not 256 which wraps to 0 in POSIX wait)' );
};

# ---------------------------------------------------------------------------
# Subtest 3 (#3): Transport escaping, --ssh-host remote mode, remote -r/-f
# ---------------------------------------------------------------------------
subtest '#3: SSH/Container shell escaping, standalone --ssh-host, and remote file check bypass' => sub {
    plan tests => 9;

    # Standalone --ssh-host works without --cloud
    local %main::opt = (
        'cloud'        => 0,
        'ssh-host'     => 'db.internal',
        'ssh-user'     => 'ops',
        'ssh-password' => "p'ass;id",
        'ssh-identity-file' => "/tmp/id'key",
    );
    no warnings 'redefine';
    local *main::which = sub {
        my ($cmd) = @_;
        return '/usr/bin/sshpass' if $cmd && $cmd eq 'sshpass';
        return undef;
    };

    is( main::is_remote(), 1, '--ssh-host enables is_remote() without requiring --cloud' );
    my $ssh_pfx = main::get_ssh_prefix();
    ok( $ssh_pfx ne '', 'get_ssh_prefix() works without --cloud' );
    like( $ssh_pfx, qr/SSHPASS='p'\\''ass;id'\s+sshpass -e/, 'ssh-password uses SSHPASS env var with escaped single quotes' );
    unlike( $ssh_pfx, qr/sshpass\s+-p\b/, 'sshpass -p is avoided so password stays hidden from ps' );
    like( $ssh_pfx, qr/-i '\/tmp\/id'\\''key'/, 'ssh-identity-file single-quote escaped' );
    like( $ssh_pfx, qr/'ops\@db\.internal'/, 'ssh target user@host single-quote escaped' );

    # Container target escaping prevents breakout when special chars appear
    local %main::opt = ( container => "docker:my'box;id" );
    my $cpfx = main::get_container_prefix();
    like( $cpfx, qr/docker exec 'my'\\''box;id' sh -c /, 'get_container_prefix escapes unsafe container names' );

    # mysql_setup with active SSH transport skips local -r/-f checks on remote defaults/ssl-ca
    MySQLTuner::TestHelper::reset_state();
    my @executed;
    local *main::goodprint  = sub { };
    local *main::badprint   = sub { };
    local *main::infoprint  = sub { };
    local *main::debugprint = sub { };
    local *main::which = sub { return '/usr/bin/mysql' if $_[0] =~ /mysql/; return undef; };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        push @executed, $cmd;
        return 'mysqld is alive' if $cmd =~ /select "mysqld is alive"/;
        return '';
    };
    local %main::opt = (
        'ssh-host'            => 'remote-db',
        'defaults-file'       => "/remote/etc/my'prod.cnf",
        'defaults-extra-file' => "/remote/etc/ex'tra.cnf",
        'login-path'          => "prod'path",
        'ssl-ca'              => "/remote/ssl/ca'cert.pem",
        'user'                => 'root',
        'pass'                => 'secret',
        'forcemem'            => 1024,
        'forceswap'           => 512,
    );
    local $mock_exit_active = 1;
    my $ok_setup = eval { main::mysql_setup(); 1 };
    ok( $ok_setup, 'mysql_setup succeeds under SSH transport without failing local -r/-f check on remote paths' );
    my $joined = join( "\n", @executed );
    like( $joined, qr/--defaults-file='\/remote\/etc\/my'\\''prod\.cnf'.*--defaults-extra-file='\/remote\/etc\/ex'\\''tra\.cnf'.*--login-path='prod'\\''path'/,
        'mysql_setup shell-escapes defaults-file, defaults-extra-file, and login-path' );
};

# ---------------------------------------------------------------------------
# Subtest 4 (#4): Replication NULL lag, stopped threads, SHOW REPLICA HOSTS
# ---------------------------------------------------------------------------
subtest '#4: Replication NULL lag warnings/false-healthy fix and SHOW REPLICA HOSTS tab parse' => sub {
    plan tests => 9;

    my @warns;
    local $SIG{__WARN__} = sub { push @warns, $_[0] unless $_[0] =~ /redefined/; };

    # Case A: NULL lag and Replica_IO_Running = No
    MySQLTuner::TestHelper::reset_state();
    %main::myrepl = (
        'Seconds_Behind_Source' => 'NULL',
        'Replica_IO_Running'    => 'No',
        'Replica_SQL_Running'   => 'Yes',
    );
    main::calculate_health_score();
    is( $main::result{'HealthScoreDetails'}{'res_lag'}, 0, 'res_lag is 0 when Seconds_Behind_Source is NULL and IO thread is No' );
    is( scalar( grep { /isn't numeric/i } @warns ), 0, 'Zero numeric warnings for NULL lag in calculate_health_score' );

    # Case B: Slave_SQL_Running = No even with numeric lag 0
    MySQLTuner::TestHelper::reset_state();
    %main::myrepl = (
        'Seconds_Behind_Source' => '0',
        'Slave_IO_Running'      => 'Yes',
        'Slave_SQL_Running'     => 'No',
    );
    main::calculate_health_score();
    is( $main::result{'HealthScoreDetails'}{'res_lag'}, 0, 'res_lag is 0 when Slave_SQL_Running is No even if lag is 0' );

    # Case C: check_replication_advanced must not emit healthy false-positive on Slave_SQL_Running = No / NULL lag
    my ( @good, @bad );
    no warnings 'redefine';
    local *main::subheaderprint = sub { };
    local *main::infoprint      = sub { };
    local *main::goodprint      = sub { push @good, $_[0] };
    local *main::badprint       = sub { push @bad,  $_[0] };
    local *main::debugprint     = sub { };
    local *main::discover_cluster_topology = sub { return {} };
    $main::is_local_only = 0;
    @warns = ();
    main::check_replication_advanced();
    is( scalar( grep { /Replication is healthy/i } @good ), 0, 'check_replication_advanced does not report healthy when SQL thread is No' );
    ok( scalar(@bad) > 0, 'check_replication_advanced emits badprint when SQL thread is No' );
    is( scalar( grep { /isn't numeric/i } @warns ), 0, 'Zero numeric warnings in check_replication_advanced' );

    # Case D: get_all_vars issues SHOW REPLICA HOSTS without \G and parses tab-separated lines
    MySQLTuner::TestHelper::reset_state();
    my @queries;
    local *main::check_privileges         = sub { };
    local *main::adjust_aborted_connects  = sub { return ( 0, 10 ) };
    local *main::select_one               = sub { return '11.4.2-MariaDB' if $_[0] =~ /VERSION/; return '0'; };
    local *main::select_array             = sub {
        my ($q) = @_;
        push @queries, $q;
        return ("version\t11.4.2-MariaDB", "have_innodb\tNO") if $q eq 'SHOW GLOBAL VARIABLES';
        return ("Uptime\t100", "Questions\t10")                 if $q eq 'SHOW GLOBAL STATUS';
        return ("101\treplica-01\t3306\t1\t0000-uuid-1111")     if $q eq 'SHOW REPLICA HOSTS';
        return ();
    };
    main::get_all_vars();
    ok( scalar( grep { $_ eq 'SHOW REPLICA HOSTS' } @queries ) == 1, 'SHOW REPLICA HOSTS queried without \\G' );
    ok( !grep( { /SHOW (?:REPLICA|SLAVE) HOSTS\\G/ } @queries ), 'Neither SHOW REPLICA HOSTS\\G nor SHOW SLAVE HOSTS\\G uses \\G' );
    is( $main::result{'Replication'}{'Replicas'}{'101'}, '0000-uuid-1111', 'Tab-separated replica host row parsed cleanly' );
};

# ---------------------------------------------------------------------------
# Subtest 5 (#5): is_mariadb() & version gates (MySQL 26.10, MariaDB 11+, stripped)
# ---------------------------------------------------------------------------
subtest '#5: Authoritative is_mariadb() and MySQL 26.10 / MariaDB 10-13 version gates' => sub {
    plan tests => 14;
    MySQLTuner::TestHelper::reset_state();
    no warnings 'redefine';
    local *main::infoprint      = sub { };
    local *main::badprint       = sub { };
    local *main::goodprint      = sub { };
    local *main::debugprint     = sub { };
    local *main::subheaderprint = sub { };

    %main::myvar = ( 'version' => '26.10.0', 'version_comment' => 'MySQL Community Server - GPL' );
    is( main::is_mariadb(), 0, 'MySQL 26.10.0 is_mariadb() == 0' );

    %main::myvar = ( 'version' => '26.7.0' );
    is( main::is_mariadb(), 0, 'Bare MySQL 26.7.0 without version_comment is_mariadb() == 0' );

    %main::myvar = ( 'version' => '8.4.3' );
    is( main::is_mariadb(), 0, 'MySQL 8.4.3 is_mariadb() == 0' );

    %main::myvar = ( 'version' => '11.4.2-MariaDB', 'version_comment' => 'mariadb.org binary distribution' );
    is( main::is_mariadb(), 1, 'MariaDB 11.4.2-MariaDB is_mariadb() == 1' );

    # Stripping in calculations preserves MariaDB detection
    %main::mystat = ( 'Questions' => 100, 'Uptime' => 100, 'Connections' => 10, 'Aborted_connects' => 0 );
    %main::real_vars = ( 'version' => '11.4.2-MariaDB' );
    %main::opt = ( 'noprocess' => 1, 'tbstat' => 0 );
    local *main::get_pf_memory    = sub { return 0 };
    local *main::get_gcache_memory = sub { return 0 };
    local *main::calculate_per_thread_buffers = sub {
        return {
            per_thread_buffers             => 1024,
            per_thread_buffers_without_tmp => 1024,
            total_per_thread_buffers       => 1024,
            max_total_per_thread_buffers   => 1024,
        };
    };
    local *main::calculate_server_buffers = sub { return 1024 };
    main::calculations();
    is( $main::myvar{'version'}, '11.4.2', 'calculations() strips -MariaDB suffix' );
    is( main::is_mariadb(), 1, 'is_mariadb() remains 1 after calculations() strips -MariaDB' );

    # Switching back to MySQL 26.10 must NOT leak stale %real_vars
    %main::myvar = ( 'version' => '26.10.0', 'version_comment' => 'MySQL Community Server - GPL' );
    is( main::is_mariadb(), 0, 'is_mariadb() accurately returns 0 after switching to MySQL 26.10.0' );

    # 1. security_recommendations must NOT query mysql.global_priv on MySQL 26.10
    my @sec_queries;
    local *main::select_one = sub { push @sec_queries, $_[0]; return 0; };
    local *main::select_array = sub {
        push @sec_queries, $_[0];
        return ('authentication_string') if $_[0] =~ /information_schema\.columns/i && $_[0] =~ /COLUMN_NAME/i;
        return ();
    };
    local %main::opt = ( 'skippassword' => 0 );
    main::security_recommendations();
    ok( !grep( { /mysql\.global_priv/i } @sec_queries ), 'MySQL 26.10 does not query MariaDB-only mysql.global_priv' );
    ok( grep( { /FROM mysql\.user/i } @sec_queries ), 'MySQL 26.10 queries mysql.user' );

    # 2. mysql_myisam must NOT push key_buffer_size=0 on MariaDB 10.11 when MyISAM tables > 0
    MySQLTuner::TestHelper::reset_state();
    %main::opt   = ( 'myisamstat' => 1 );
    %main::myvar = ( 'version' => '10.11.8-MariaDB', 'key_buffer_size' => 134217728, 'key_cache_block_size' => 1024 );
    %main::mystat = ( 'Key_read_requests' => 100, 'Key_reads' => 1, 'Key_write_requests' => 10, 'Key_writes' => 1 );
    %main::mycalc = (
        'pct_keys_from_mem'   => 99,
        'pct_wkeys_from_mem'  => 90,
        'total_myisam_indexes' => 1048576,
        'pct_key_buffer_used' => 50,
    );
    local *main::select_one = sub { return 2; };
    local *main::select_array = sub { return ('app.legacy'); };
    local *main::dump_into_file = sub { };
    main::mysql_myisam();
    ok( !grep( { /key_buffer_size=0/ } @main::adjvars ), 'MariaDB 10.11 with MyISAM tables does not receive false MySQL 8+ key_buffer_size=0 advice' );

    # 3. mysql_pfs recommends mysql-sys on MySQL 26.10 (not mariadb-sys)
    MySQLTuner::TestHelper::reset_state();
    %main::opt   = ( 'pfstat' => 1 );
    %main::myvar = ( 'version' => '26.10.0', 'performance_schema' => 'ON' );
    local *main::select_array = sub { return (); };
    local *main::select_one   = sub { return 0; };
    main::mysql_pfs();
    ok( grep( { /mysql\/mysql-sys/ } @main::generalrec ), 'MySQL 26.10 recommends mysql/mysql-sys when sys missing' );
    unlike( join( ' ', @main::generalrec ), qr/mariadb-sys/, 'MySQL 26.10 does not recommend mariadb-sys' );

    # 4. get_mariadb_variable_origin returns '' on MySQL 26.10 without querying SYSTEM_VARIABLES
    my @orig_queries;
    local *main::select_one = sub { push @orig_queries, $_[0]; return 'CONFIG'; };
    is( main::get_mariadb_variable_origin('tx_isolation'), '', 'get_mariadb_variable_origin skips MySQL 26.10' );
    is( scalar(@orig_queries), 0, 'No MariaDB SYSTEM_VARIABLES query sent on MySQL 26.10' );
};

# ---------------------------------------------------------------------------
# Subtest 6 (#6): check_query_anti_patterns PFS check & historical_comparison keys
# ---------------------------------------------------------------------------
subtest '#6: check_query_anti_patterns PFS check and historical_comparison real %result keys' => sub {
    plan tests => 6;
    MySQLTuner::TestHelper::reset_state();
    no warnings 'redefine';
    local *main::infoprint      = sub { };
    local *main::badprint       = sub { };
    local *main::goodprint      = sub { };
    local *main::subheaderprint = sub { };

    # 1. check_query_anti_patterns handles real tab-delimited SHOW VARIABLES output
    %main::myvar = ( 'version' => '8.4.3' );
    my @pfs_q;
    local *main::select_one = sub { return "performance_schema\tON"; };
    local *main::select_array = sub {
        push @pfs_q, $_[0];
        return ("SELECT * FROM t\t10\t5\t0") if $_[0] =~ /sum_no_index_used/;
        return ();
    };
    main::check_query_anti_patterns();
    ok( scalar(@pfs_q) >= 1, 'check_query_anti_patterns runs when select_one returns tab-separated performance_schema\\tON' );
    ok( scalar( grep { /high full scans/ } @main::modeling ) >= 1, 'check_query_anti_patterns pushes finding when PFS ON' );

    # 2. check_query_anti_patterns respects %myvar{performance_schema} = OFF without spurious execution
    MySQLTuner::TestHelper::reset_state();
    %main::myvar = ( 'version' => '8.4.3', 'performance_schema' => 'OFF' );
    @pfs_q = ();
    local *main::select_array = sub { push @pfs_q, $_[0]; return (); };
    main::check_query_anti_patterns();
    is( scalar(@pfs_q), 0, 'check_query_anti_patterns skips when myvar{performance_schema} is OFF' );

    # 3. historical_comparison reads real ThroughputEfficiency.QPS, Databases, MySQLTuner.datetime keys
    MySQLTuner::TestHelper::reset_state();
    my ( $fh, $snap_file ) = tempfile( SUFFIX => '.json', UNLINK => 1 );
    print $fh JSON::PP->new->encode(
        {
            MySQLTuner           => { datetime => 'Mon Nov 16 00:00:00 2026' },
            HealthScore          => 70,
            ThroughputEfficiency => { QPS      => 10.0 },
            Databases            => { 'All databases' => { 'Total Size' => 10485760 } },
        }
    );
    close $fh;

    %main::result = (
        HealthScore          => 85,
        ThroughputEfficiency => { QPS => 15.0 },
        Databases            => { 'All databases' => { 'Total Size' => 20971520 } },
        SectionalHealthScore => {},
    );
    local %main::opt = ( 'compare-file' => $snap_file );
    main::historical_comparison();
    is( $main::result{'Trends'}{'SnapshotDate'}, 'Mon Nov 16 00:00:00 2026', 'Reads MySQLTuner.datetime fallback snapshot date' );
    like( $main::result{'Trends'}{'QPS'}, qr/10\.00 -> 15\.00 \(\+50\.00%\)/, 'Reads ThroughputEfficiency.QPS for QPS trend' );
    like( $main::result{'Trends'}{'TotalDataSize'}, qr/10\.0M -> 20\.0M/, 'Reads Databases.All databases.Total Size for size trend' );
};

# ---------------------------------------------------------------------------
# Subtest 7 (#7): Core JSON::PP _serialize_to_json, SET GLOBAL formatting, --agent-json --outputfile
# ---------------------------------------------------------------------------
subtest '#7: JSON::PP _serialize_to_json, byte/string SQL formatting, and --agent-json --outputfile' => sub {
    plan tests => 9;

    # _serialize_to_json properly quotes leading-zero string "007" and control characters
    my $encoded = main::_serialize_to_json( { code => '007', ctrl => "a\x08b", num => 42, b => \1 } );
    my $dec = eval { decode_json($encoded) };
    is( $@, '', '_serialize_to_json produces strictly valid JSON via JSON::PP' );
    like( $encoded, qr/"code":"007"/, 'Leading-zero string "007" remains a JSON string' );
    is( $dec->{num}, 42, 'Integer stays JSON number' );
    ok( JSON::PP::is_bool( $dec->{b} ) && $dec->{b}, 'Scalar ref \\1 serializes as JSON boolean true' );

    # generate_auto_fix_snippets converts K/M/G/T in SET GLOBAL and single-quotes non-numeric strings
    MySQLTuner::TestHelper::reset_state();
    my @pretty;
    no warnings 'redefine';
    local *main::prettyprint    = sub { push @pretty, $_[0] };
    local *main::subheaderprint = sub { };
    local *main::infoprint      = sub { };
    @main::adjvars = (
        'innodb_buffer_pool_size (>= 256M)',
        'join_buffer_size (> 256.0K)',
        'slave_parallel_mode=optimistic',
        'max_connections = 500',
    );
    local %main::opt = ( silent => 0, json => 0, yaml => 0, 'agent-json' => 0 );
    main::generate_auto_fix_snippets();
    my $snippets = join( "\n", @pretty );
    like( $snippets, qr/SET GLOBAL innodb_buffer_pool_size = 268435456;/, '256M converted to integer bytes in SET GLOBAL' );
    like( $snippets, qr/SET GLOBAL join_buffer_size = 262144;/, '256.0K converted to integer bytes in SET GLOBAL' );
    like( $snippets, qr/SET GLOBAL slave_parallel_mode = 'optimistic';/, 'Non-numeric string quoted in SET GLOBAL' );
    like( $snippets, qr/^\s{4}join_buffer_size = 256\.0K$/m, 'Human-readable unit preserved in [mysqld] section' );

    # setup_environment + dump_result writes valid JSON to --outputfile when --agent-json is active
    my $tmpdir   = tempdir( CLEANUP => 1 );
    my $out_json = File::Spec->catfile( $tmpdir, 'agent_out.json' );
    local @ARGV = ( '--agent-json', '--outputfile', $out_json, '--cvefile', '' );
    local %main::opt = ( 'agent-json' => 1, 'outputfile' => $out_json, debug => 0, experimental => 0 );
    main::setup_environment();
    main::headerprint();
    @main::adjvars = ('max_connections = 300');
    %main::myvar   = ( 'max_connections' => '151' );

    my $stdout_buf = '';
    {
        open my $oldout, '>&', \*STDOUT or die $!;
        close STDOUT;
        open STDOUT, '>', \$stdout_buf or die $!;
        local $mock_exit_active = 1;
        eval { main::dump_result(); };
        close STDOUT;
        open STDOUT, '>&', $oldout or die $!;
    }
    open my $ofh, '<', $out_json or die "Cannot read $out_json: $!";
    my $file_json = do { local $/; <$ofh> };
    close $ofh;
    my $parsed = eval { decode_json($file_json) };
    ok( defined $parsed && exists $parsed->{findings} && $parsed->{findings}[0]{id} eq 'max_connections_adjust',
        '--agent-json with --outputfile writes clean banner-free JSON to outputfile' );
};

# ---------------------------------------------------------------------------
# Subtest 8 (#8): PFS error_log [PRIO], ASC order, active without --dbstat, open guard
# ---------------------------------------------------------------------------
subtest '#8: PFS error_log [PRIO] chronological query, active without --dbstat, and open guard' => sub {
    plan tests => 6;
    MySQLTuner::TestHelper::reset_state();
    my $tmpdir   = tempdir( CLEANUP => 1 );
    my $cmd_log  = File::Spec->catfile( $tmpdir, 'pfs_cmd.log' );
    my $mock_bin = File::Spec->catfile( $tmpdir, 'mysql' );
    open my $mfh, '>', $mock_bin or die $!;
    print {$mfh} <<"SH";
#!/usr/bin/env bash
printf '%s\\n' "\$*" > "$cmd_log"
printf '%s\\n' "[Warning] Old warning first"
printf '%s\\n' "[ERROR] Newer error second"
exit 0
SH
    close $mfh;
    chmod 0755, $mock_bin;

    my ( @good, @bad );
    no warnings 'redefine';
    local $ENV{PATH}             = "$tmpdir:$ENV{PATH}";
    local *main::is_remote       = sub { return 0; };
    local *main::is_docker       = sub { return 0; };
    local *main::select_one      = sub { return 1; };
    local *main::goodprint       = sub { push @good, $_[0] };
    local *main::badprint        = sub { push @bad,  $_[0] };
    local *main::infoprint       = sub { };
    local *main::debugprint      = sub { };
    local *main::subheaderprint  = sub { };
    local $main::mysqlcmd        = $mock_bin;
    local $main::mysqllogin      = '-u root';
    local %main::opt             = ( dbstat => 0, 'server-log' => '', container => '' );
    local %main::myvar           = (
        version             => '8.4.3',
        performance_schema  => 'ON',
        log_error_verbosity => 2,
        log_error           => 'stderr',
        hostname            => 'localhost',
        datadir             => '/var/lib/mysql/',
    );
    $main::maxlines = 100;

    main::log_file_recommendations();
    open my $cfh, '<', $cmd_log or die "Cannot read $cmd_log: $!";
    my $issued = do { local $/; <$cfh> };
    close $cfh;

    like( $issued, qr/CONCAT\('\[',\s*PRIO,\s*'\]\s*',\s*DATA\)/i, 'PFS query formats [PRIO] DATA prefix even with dbstat => 0' );
    like( $issued, qr/ORDER BY LOGGED DESC.*ORDER BY LOGGED ASC/si, 'PFS query fetches latest N rows DESC then orders chronologically ASC' );
    ok( grep( { /performance_schema\.error_log contains 1 warning\(s\)\./ } @bad ), 'Detects [Warning] from PFS error_log with dbstat => 0' );
    ok( grep( { /performance_schema\.error_log contains 1 error\(s\)\./ } @bad ),   'Detects [ERROR] from PFS error_log with dbstat => 0' );

    # Verify check_sql_linter.pl passes
    my $linter = File::Spec->catfile( $root_dir, 'build', 'check_sql_linter.pl' );
    `perl \Q$linter\E 2>&1`;
    is( $? >> 8, 0, 'build/check_sql_linter.pl exits 0 on updated PFS query' );

    # Failed open guard must produce zero warnings
    my @warns;
    local $SIG{__WARN__} = sub { push @warns, $_[0] unless $_[0] =~ /redefined/; };
    local $main::mysqlcmd = '/nonexistent_dir_xyz/nonexistent_mysql_bin';
    main::log_file_recommendations();
    is( scalar( grep { /unopened filehandle|readline/i } @warns ), 0, 'Failed PFS pipe open returns cleanly with zero filehandle warnings' );
};

# ---------------------------------------------------------------------------
# Subtest 9 (#9): update_tuner_version atomic validation, HTML XSS, CSV "" escaping
# ---------------------------------------------------------------------------
subtest '#9: update_tuner_version temp+syntax guard, HTML <script> XSS escaping, CSV quoting' => sub {
    plan tests => 5;
    MySQLTuner::TestHelper::reset_state();

    # 1. update_tuner_version refuses to overwrite live mysqltuner.pl with 404 HTML error page
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $live_pl = File::Spec->catfile( $tmpdir, 'mysqltuner.pl' );
    open my $lfh, '>', $live_pl or die $!;
    print $lfh "#!/usr/bin/env perl\nprint \"LIVE_ORIGINAL_OK\\n\";\n";
    close $lfh;

    no warnings 'redefine';
    local $main::update_target_dir     = $tmpdir;
    local $main::opt{'updateversion'}  = 1;
    local *main::get_http_cli          = sub { return '/usr/bin/curl' };
    local *main::goodprint             = sub { };
    local *main::badprint              = sub { };
    local *main::infoprint             = sub { };
    local *main::debugprint            = sub { };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ( $cmd =~ />\s+(\S+)/ ) {
            my $tmp_target = $1;
            open my $tfh, '>', $tmp_target or die $!;
            print $tfh "<html><body><h1>404 Not Found</h1></body></html>\n";
            close $tfh;
        }
        return '';
    };
    {
        local $mock_exit_active = 1;
        eval { main::update_tuner_version(); };
    }
    open my $rfh, '<', $live_pl or die $!;
    my $live_after = do { local $/; <$rfh> };
    close $rfh;
    like( $live_after, qr/LIVE_ORIGINAL_OK/, 'update_tuner_version preserves live mysqltuner.pl when downloaded payload fails perl -c' );

    # 2. HTML <script> escaping neutralizes </script> and quotes in metadata and arrays
    MySQLTuner::TestHelper::reset_state();
    my $html_path = File::Spec->catfile( $tmpdir, 'xss_report.html' );
    local %main::opt = (
        reportfile => $html_path,
        host       => 'evil"</script><script>alert(1)</script>',
        port       => '3306',
    );
    %main::myvar     = ( 'custom_var' => 'bad</script><script>alert(2)</script>' );
    @main::generalrec = ('Recommendation with "</script><script>alert(3)</script>');
    main::dump_result();

    open my $hfh, '<', $html_path or die "Cannot open $html_path: $!";
    my $html = do { local $/; <$hfh> };
    close $hfh;
    my ($script_block) = $html =~ /<!-- JSON embedded data & CSV download script -->\s*<script>(.*?)<\/script>/s;
    ok( defined $script_block && length($script_block) > 0, 'Extracted HTML report embedded <script> block' );
    unlike( $script_block, qr/<\/script>/i, 'Embedded <script> block contains zero raw </script> sequences' );
    like( $html, qr/replace\(\/"\/g,\s*'""'\)/, 'HTML downloadCSV uses CSV quote escaping' );

    # 3. select_csv_file escapes embedded double quotes per RFC 4180
    my $csv_path = File::Spec->catfile( $tmpdir, 'quoted.csv' );
    local *main::select_array_with_headers = sub { return ( "col_a\tcol_b", qq{val"one\tval two} ); };
    main::select_csv_file( $csv_path, 'SELECT 1' );
    open my $qfh, '<', $csv_path or die $!;
    my $csv_content = do { local $/; <$qfh> };
    close $qfh;
    like( $csv_content, qr/"val""one","val two"/, 'select_csv_file escapes double quotes as "" inside fields' );
};

# ---------------------------------------------------------------------------
# Subtest 10 (#11, #14, #15, #16, #18): Performance, System/SQL/FS/Kernel, CLI
# ---------------------------------------------------------------------------
subtest '#11/#14/#15/#16/#18: Dumpdir query guard, stderr redirection, FS/kernel/debian.cnf/SQL, cores/audit_tests, handles/--feature' => sub {
    plan tests => 15;
    MySQLTuner::TestHelper::reset_state();
    no warnings 'redefine';
    local *main::infoprint      = sub { };
    local *main::badprint       = sub { };
    local *main::goodprint      = sub { };
    local *main::debugprint     = sub { };
    local *main::subheaderprint = sub { };

    # #11: mysql_table_structures skips utf8columns / ftcolumns queries when dumpdir is empty
    my @struct_queries;
    local %main::opt = ( structstat => 1, colstat => 0, dumpdir => '' );
    local %main::myvar = ( 'version' => '8.4.3' );
    local *main::select_array = sub { push @struct_queries, $_[0]; return (); };
    local *main::select_one   = sub { return 0; };
    local *main::dump_into_file = sub { };
    local *main::mysql_naming_conventions = sub { };
    local *main::mysql_foreign_key_checks = sub { };
    local *main::mysql_80_modeling_checks = sub { };
    local *main::mysql_datatype_optimization = sub { };
    local *main::mysql_schema_sanitization   = sub { };
    main::mysql_table_structures();
    ok( !grep( { /(?<!NOT )LIKE 'utf8%'|data_type='FULLTEXT'/i } @struct_queries ), '#11: utf8columns and ftcolumns skipped without --dumpdir' );

    # #14: execute_system_command does not append 2>&1 when command already contains 2>
    my $stderr_echo = main::execute_system_command( q{perl -e 'print "OUT\n"; print STDERR "ERR\n"' 2>/dev/null} );
    is( $stderr_echo, "OUT\n", '#14: execute_system_command honors existing 2>/dev/null without overwriting it with 2>&1' );

    # #15a: get_fs_info_win guards $size == 0
    local *main::execute_system_command = sub { return ( "0  Z:  0\n", "1000  C:  2000\n" ); };
    my @div_warns;
    {
        local $SIG{__WARN__} = sub { push @div_warns, $_[0] unless $_[0] =~ /redefined/; };
        eval { main::get_fs_info_win(); };
    }
    is( $@, '', '#15: get_fs_info_win does not die on zero-size logical disk' );
    is( scalar( grep { /division by zero/i } @div_warns ), 0, '#15: Zero division warnings' );

    # #15b: get_fs_info keeps /srv/devops while skipping /run, /dev, /sys, /proc, /snap, /init
    %main::result = ();
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        return (
            "Filesystem 1024-blocks Used Available Capacity Mounted on\n",
            "/dev/sdb1 10000 5000 5000 50% /srv/devops\n",
            "tmpfs 1000 100 900 10% /run/user/1000\n",
        ) if $cmd =~ /df -P/;
        return ( "Filesystem Inodes IUsed IFree IUse% Mounted on\n" ) if $cmd =~ /df -Pi/;
        return ();
    };
    main::get_fs_info();
    ok( exists $main::result{'Filesystem'}{'Space Pct'}{'/srv/devops'}, '#15: /srv/devops not falsely skipped by unanchored mount filter' );
    ok( !exists $main::result{'Filesystem'}{'Space Pct'}{'/run/user/1000'}, '#15: /run/user/1000 still skipped cleanly' );

    # #15c: get_kernel_info safely ignores non-numeric swappiness without isn't numeric warning
    my @kern_warns;
    local $SIG{__WARN__} = sub { push @kern_warns, $_[0] unless $_[0] =~ /redefined/; };
    local *main::get_transport_prefix = sub { return 'ssh mock-host '; };
    local *main::execute_system_command = sub { return 'n/a' if $_[0] =~ /vm\.swappiness/; return ''; };
    main::get_kernel_info();
    is( scalar( grep { /isn't numeric/i } @kern_warns ), 0, '#15: Non-numeric vm.swappiness causes zero numeric warnings' );

    # #15d: SQL single-quote escaping in select_tables_db
    my $seen_sql = '';
    local *main::select_array = sub { $seen_sql = $_[0]; return (); };
    main::select_tables_db("shop'db");
    like( $seen_sql, qr/TABLE_SCHEMA='shop''db'/, '#15: select_tables_db escapes single quotes in schema name' );

    # #16: build/audit_tests.pl flags "isn't numeric" warnings as failure
    my $audit_pl = File::Spec->catfile( $root_dir, 'build', 'audit_tests.pl' );
    open my $afh, '<', $audit_pl or die "Cannot read $audit_pl: $!";
    my $audit_src = do { local $/; <$afh> };
    close $afh;
    like( $audit_src, qr/isn't numeric/, "#16: build/audit_tests.pl checks for isn't numeric Perl warnings" );

    # #18a: arr2hash ignores non-matching lines instead of reusing stale $1/$2
    my %parsed_hash;
    my @lines_with_blank = ( "valid_key\tvalid_val", "", "no_match_line!!!" );
    main::arr2hash( \%parsed_hash, \@lines_with_blank );
    is( scalar( keys %parsed_hash ), 1, '#18: arr2hash skips non-matching lines without reusing stale $1/$2' );

    # #18b: --feature validation & dump_result + close_outputfile propagation
    open my $msrc_fh, '<', $script or die $!;
    my $msrc = do { local $/; <$msrc_fh> };
    close $msrc_fh;
    like( $msrc, qr/allowed_features.*\@REPORT_SECTION_NAMES.*\@AUDIT_SUBROUTINE_NAMES/s,
        '#18: MAIN validates --feature against \@REPORT_SECTION_NAMES and \@AUDIT_SUBROUTINE_NAMES' );
    ok( $msrc =~ /dump_result.*close_outputfile/s && $msrc !~ /for my \$feature.*?dump_csv_files;\s*make_recommendations;\s*print_execution_timings\(\);\s*goodprint "Terminated successfully";\s*exit\(0\);/s,
        '#18: --feature branch calls dump_result() and close_outputfile() before exiting' );
    # Check #16 logical_cpu_cores() fallback in calculate_sectional_health_scores
    like( $msrc, qr/logical_cpu_cores\(\)\s*\|\|\s*1/, '#16: calculate_sectional_health_scores uses logical_cpu_cores() || 1 fallback' );

    # #15e: /etc/mysql/debian.cnf must NOT override explicit --defaults-extra-file
    MySQLTuner::TestHelper::reset_state();
    my ( $ext_fh, $ext_cnf ) = tempfile( SUFFIX => '.cnf', UNLINK => 1 );
    print $ext_fh "[client]\nuser=custom\n";
    close $ext_fh;
    my @deb_cmds;
    local $main::doremote      = 0;
    local $main::mysqlcmd      = 'mysql';
    local $main::mysqladmincmd = 'mysqladmin';
    local *main::which         = sub { return '/usr/bin/mysql' if $_[0] =~ /mysql/; return undef; };
    local *main::my_file_readable = sub { return 1 if $_[0] eq '/etc/mysql/debian.cnf'; return 0; };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        push @deb_cmds, $cmd;
        return 'mysqld is alive' if $cmd =~ /ping/;
        return '';
    };
    local %main::opt = ( 'defaults-extra-file' => $ext_cnf, user => '', pass => '' );
    main::mysql_setup();
    ok( !grep( { /debian\.cnf/ } @deb_cmds ), '#15: /etc/mysql/debian.cnf does not override --defaults-extra-file' );

    # #14b: dump_csv_files captures mysqldump output locally without redirecting > $sql_file remotely
    MySQLTuner::TestHelper::reset_state();
    my $dump_tmp = tempdir( CLEANUP => 1 );
    my @dump_cmds;
    local $main::mysqlcmd = 'mysql';
    local $main::mysqllogin = '-u root';
    local $main::devnull = '/dev/null';
    local %main::opt = ( dumpdir => $dump_tmp, 'compress-dump' => 0 );
    $main::result{'Databases'}{'List'} = ['shop'];
    local *main::select_array = sub { return (); };
    local *main::select_user_dbs = sub { return ('shop'); };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        push @dump_cmds, $cmd;
        return "CREATE TABLE t (id INT);\n" if $cmd =~ /mysqldump/;
        return '';
    };
    local *main::dump_sys_statement_analysis_statistical = sub { };
    main::dump_csv_files();
    main::close_outputfile();
    ok( scalar( grep { /--no-data --databases 'shop'/ && !/>\s*\Q$dump_tmp\E/ } @dump_cmds ) >= 1
        && -s File::Spec->catfile( $dump_tmp, 'schema_shop.sql' ),
        '#14: dump_csv_files runs mysqldump without container/remote file redirection and writes local schema_*.sql' );
};

done_testing();
