#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use Cwd qw(abs_path);
use JSON::PP qw(decode_json);

my $repo_root        = abs_path( File::Spec->catdir( File::Spec->curdir() ) );
my $parallel_script  = File::Spec->catfile( $repo_root, 'build', 'parallel_test.sh' );
my $test_envs_script = File::Spec->catfile( $repo_root, 'build', 'test_envs.sh' );

sub run_cmd_capture {
    my ( $env_hash, $cmd ) = @_;
    local %ENV = %ENV;
    if ( ref($env_hash) eq 'HASH' ) {
        for my $k ( keys %{$env_hash} ) {
            $ENV{$k} = $env_hash->{$k};
        }
    }
    my $out = qx($cmd 2>&1);
    my $rc  = $? >> 8;
    return ( $rc, $out );
}

sub write_text_file {
    my ( $path, $content, $mode ) = @_;
    open my $fh, '>', $path or die "Cannot write $path: $!";
    print {$fh} $content;
    close $fh;
    chmod $mode, $path if defined $mode;
}

sub read_text_file {
    my ($path) = @_;
    return '' unless -f $path;
    open my $fh, '<', $path or die "Cannot read $path: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

subtest 'Shell syntax validation (bash -n)' => sub {
    plan tests => 2;

    my ( $rc1, $out1 ) = run_cmd_capture( '', "bash -n \"$parallel_script\"" );
    is( $rc1, 0, 'build/parallel_test.sh passes bash -n' ) or diag($out1);

    my ( $rc2, $out2 ) = run_cmd_capture( '', "bash -n \"$test_envs_script\"" );
    is( $rc2, 0, 'build/test_envs.sh passes bash -n' ) or diag($out2);
};

subtest 'parallel_test.sh version-to-Docker-image mapping' => sub {
    my %expected = (
        'mysql57'     => 'mysql:5.7',
        'mysql80'     => 'mysql:8.0',
        'mysql84'     => 'mysql:8.4',
        'mysql97'     => 'mysql:9.7',
        'mysql267'    => 'mysql:26.7',
        'mysql2610'   => 'mysql:26.10',
        'mariadb1011' => 'mariadb:10.11',
        'mariadb114'  => 'mariadb:11.4',
        'mariadb130'  => 'mariadb:13.0',
        'percona80'   => 'percona/percona-server:8.0',
    );
    plan tests => ( scalar keys %expected ) * 2 + 1;

    # Safe sandbox cwd/PATH prevents legacy pre-fix script from invoking real docker/git
    my $guard = tempdir( CLEANUP => 1 );
    my $gbin  = File::Spec->catdir( $guard, 'bin' );
    make_path($gbin);
    for my $tool (qw(docker git mysqladmin mysql)) {
        write_text_file( File::Spec->catfile( $gbin, $tool ), "#!/usr/bin/env bash\nexit 0\n", 0755 );
    }

    for my $cfg ( sort keys %expected ) {
        my ( $rc, $out ) = run_cmd_capture(
            { PATH => "$gbin:$ENV{PATH}" },
            "bash -c 'cd \"$guard\" && bash \"$parallel_script\" --print-image \"$cfg\"'"
        );
        chomp $out;
        is( $rc,  0,               "--print-image $cfg exits 0" );
        is( $out, $expected{$cfg}, "--print-image $cfg maps to $expected{$cfg}" );
    }

    my ( $bad_rc, $bad_out ) = run_cmd_capture(
        { PATH => "$gbin:$ENV{PATH}" },
        "bash -c 'cd \"$guard\" && bash \"$parallel_script\" --print-image invalid99'"
    );
    isnt( $bad_rc, 0, '--print-image rejects unsupported config' ) or diag($bad_out);
};

subtest 'parallel_test.sh CLI configs, PORT_BASE, and CONTAINER_PREFIX via --dry-run' => sub {
    plan tests => 9;

    my $guard = tempdir( CLEANUP => 1 );
    my $gbin  = File::Spec->catdir( $guard, 'bin' );
    make_path($gbin);
    for my $tool (qw(docker git mysqladmin mysql)) {
        write_text_file( File::Spec->catfile( $gbin, $tool ), "#!/usr/bin/env bash\nexit 0\n", 0755 );
    }

    my ( $rc1, $out1 ) = run_cmd_capture(
        {
            PORT_BASE        => '34500',
            CONTAINER_PREFIX => 'custom-lab',
            PATH             => "$gbin:$ENV{PATH}",
        },
        "bash -c 'cd \"$guard\" && bash \"$parallel_script\" --dry-run mysql84 mariadb114'"
    );
    is( $rc1, 0, '--dry-run with explicit configs exits 0' ) or diag($out1);
    like( $out1, qr/^PORT_BASE=34500$/m,          'respects custom PORT_BASE' );
    like( $out1, qr/^CONTAINER_PREFIX=custom-lab$/m, 'respects custom CONTAINER_PREFIX' );
    like(
        $out1,
        qr/^CONFIG=mysql84 IMAGE=mysql:8\.4 PORT=34500 CONTAINER=custom-lab-mysql84$/m,
        'assigns first config to PORT_BASE with custom CONTAINER_PREFIX'
    );
    like(
        $out1,
        qr/^CONFIG=mariadb114 IMAGE=mariadb:11\.4 PORT=34501 CONTAINER=custom-lab-mariadb114$/m,
        'assigns second config to PORT_BASE+1 with custom CONTAINER_PREFIX'
    );

    my ( $rc2, $out2 ) = run_cmd_capture(
        { PATH => "$gbin:$ENV{PATH}" },
        "bash -c 'cd \"$guard\" && bash \"$parallel_script\" --dry-run'"
    );
    is( $rc2, 0, '--dry-run with default supported configs exits 0' ) or diag($out2);
    like( $out2, qr/^PORT_BASE=33060$/m,                     'defaults PORT_BASE to 33060' );
    like( $out2, qr/^CONTAINER_PREFIX=mysqltuner-parallel$/m, 'defaults CONTAINER_PREFIX to mysqltuner-parallel' );
    like( $out2, qr/^CONFIG=mysql2610 IMAGE=mysql:26\.10 /m,  'default config list maps mysql2610 to mysql:26.10' );
};

subtest 'parallel_test.sh mocked E2E execution (image skip, injection, HTML/JSON reports, scoped cleanup)' => sub {
    plan tests => 33;

    my $sandbox      = tempdir( CLEANUP => 1 );
    my $bin_dir      = File::Spec->catdir( $sandbox, 'bin' );
    my $examples_dir = File::Spec->catdir( $sandbox, 'examples' );
    my $vendor_dir   = File::Spec->catdir( $sandbox, 'vendor' );
    my $build_dir    = File::Spec->catdir( $sandbox, 'build' );
    my $emp_dir      = File::Spec->catdir( $vendor_dir, 'test_db', 'employees' );
    my $sak_dir      = File::Spec->catdir( $vendor_dir, 'test_db', 'sakila' );
    my $pg_dir       = File::Spec->catdir( $vendor_dir, 'test_db', 'postgresql' );
    my $conf_dir     = File::Spec->catdir( $vendor_dir, 'multi-db-docker-env', 'conf' );

    make_path( $bin_dir, $examples_dir, $build_dir, $emp_dir, $sak_dir, $pg_dir, $conf_dir );

    write_text_file( File::Spec->catfile( $sandbox, 'vulnerabilities.csv' ), "1.0.0,CVE-2026-0001\n" );
    write_text_file( File::Spec->catfile( $conf_dir, 'pfs.cnf' ), "[mysqld]\nperformance_schema=ON\n" );
    write_text_file( File::Spec->catfile( $emp_dir, 'employees.sql' ), "connect employees;\nCREATE TABLE employees (id INT);\n" );
    write_text_file( File::Spec->catfile( $pg_dir, 'employees.sql' ), "\\connect employees\n" );
    write_text_file( File::Spec->catfile( $sak_dir, 'sakila-mv-schema.sql' ), "CREATE SCHEMA sakila;\nUSE sakila;\n" );
    write_text_file( File::Spec->catfile( $sak_dir, 'sakila-mv-data.sql' ), "USE sakila;\nINSERT INTO actor VALUES (1);\n" );

    my $mt_calls_log     = File::Spec->catfile( $sandbox, 'mysqltuner_calls.log' );
    my $docker_calls_log = File::Spec->catfile( $sandbox, 'docker_calls.log' );
    my $rm_calls_log     = File::Spec->catfile( $sandbox, 'docker_rm.log' );
    my $sql_pipe_log     = File::Spec->catfile( $sandbox, 'sql_pipe.log' );

    # Stub mysqltuner.pl capturing CLI args and emitting HTML/JSON/text artifacts
    write_text_file(
        File::Spec->catfile( $sandbox, 'mysqltuner.pl' ),
        <<'PERL',
#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long qw(GetOptions :config pass_through);

my $calls_log = $ENV{MOCK_MT_CALLS_LOG} || die "MOCK_MT_CALLS_LOG unset";
open my $log, '>>', $calls_log or die $!;
print {$log} join(' ', @ARGV) . "\n";
close $log;

my ($outputfile, $reportfile, $json, $prettyjson, $silent, $noask);
GetOptions(
    'outputfile=s' => \$outputfile,
    'reportfile:s' => \$reportfile,
    'json!'        => \$json,
    'prettyjson!'  => \$prettyjson,
    'silent!'      => \$silent,
    'noask!'       => \$noask,
);

die "--noask is mandatory" unless $noask;

if ($reportfile) {
    open my $rh, '>', $reportfile or die $!;
    print {$rh} "<!DOCTYPE html><html><body>Mock Report</body></html>\n";
    close $rh;
}

if ($json || $prettyjson) {
    die "JSON requires outputfile in harness" unless $outputfile;
    open my $jh, '>', $outputfile or die $!;
    print {$jh} "{\n  \"MySQLTuner\": {\"version\": \"2.9.4\"},\n  \"HealthScore\": 92\n}\n";
    close $jh;
    print STDERR "json diagnostics captured\n";
} elsif ($outputfile) {
    open my $oh, '>', $outputfile or die $!;
    print {$oh} "Mock MySQLTuner Output\nTerminated successfully\n";
    close $oh;
}
exit 0;
PERL
    );

    # Stub build/audit_logs.pl and build/get_supported_envs.pl
    write_text_file( File::Spec->catfile( $build_dir, 'audit_logs.pl' ), "#!/usr/bin/env perl\nexit 0;\n" );
    write_text_file( File::Spec->catfile( $build_dir, 'get_supported_envs.pl' ), "#!/usr/bin/env perl\nprint \"mysql84\\n\";\n" );

    # Mock docker CLI verifying image checks, internal client injection, and scoped cleanup
    write_text_file(
        File::Spec->catfile( $bin_dir, 'docker' ),
        <<"SH",
#!/usr/bin/env bash
set -u
echo "\$*" >> "$docker_calls_log"
cmd="\$1"
shift || true
case "\$cmd" in
    image)
        if [ "\$1" = "inspect" ]; then
            img="\$2"
            case "\$img" in
                mysql:8.4|mariadb:11.4) exit 0 ;;
                *) exit 1 ;;
            esac
        fi
        exit 1
        ;;
    pull)
        img="\$1"
        case "\$img" in
            mysql:8.4|mariadb:11.4) exit 0 ;;
            *) exit 1 ;;
        esac
        ;;
    run)
        echo "container-id-mock"
        exit 0
        ;;
    inspect)
        if [ "\$1" = "-f" ]; then
            echo "true"
        else
            echo '[{"Name":"/mock"}]'
        fi
        exit 0
        ;;
    cp)
        exit 0
        ;;
    exec)
        cname="\$1"
        shift
        if [ "\$1" = "sh" ] && [ "\$2" = "-c" ]; then
            script="\$3"
            if printf '%s' "\$script" | grep -q "ping"; then
                exit 0
            fi
            mock_cli_dir="$sandbox/mock_cli_\$cname"
            mkdir -p "\$mock_cli_dir"
            if printf '%s' "\$cname" | grep -q "mariadb"; then
                cat > "\$mock_cli_dir/mariadb" <<'CLI'
#!/usr/bin/env bash
if [ ! -t 0 ]; then
    cat >> "\$MOCK_SQL_PIPE_LOG"
fi
for arg in "\$@"; do
    if printf '%s' "\$arg" | grep -q "information_schema.TABLES"; then
        echo "6/1000"
        exit 0
    fi
done
exit 0
CLI
                chmod 0755 "\$mock_cli_dir/mariadb"
            else
                cat > "\$mock_cli_dir/mysql" <<'CLI'
#!/usr/bin/env bash
if [ ! -t 0 ]; then
    payload=\$(cat)
    printf '%s\n' "\$payload" >> "\$MOCK_SQL_PIPE_LOG"
    if printf '%s' "\$payload" | grep -q "CREATE TABLE employees"; then
        echo "ERROR 9999: simulated employees edge error" >&2
        exit 1
    fi
fi
for arg in "\$@"; do
    if printf '%s' "\$arg" | grep -q "information_schema.TABLES"; then
        echo "16/4200"
        exit 0
    fi
done
exit 0
CLI
                chmod 0755 "\$mock_cli_dir/mysql"
            fi
            mkdir -p "$sandbox/container_tmp_\$cname/test_db/employees" "$sandbox/container_tmp_\$cname/test_db/sakila"
            cp "$emp_dir/employees.sql" "$sandbox/container_tmp_\$cname/test_db/employees/"
            cp "$sak_dir/sakila-mv-schema.sql" "$sak_dir/sakila-mv-data.sql" "$sandbox/container_tmp_\$cname/test_db/sakila/"
            # Build an isolated PATH without host mysql/mariadb so container client detection is faithfully tested
            iso_sys="$sandbox/iso_sys"
            mkdir -p "\$iso_sys"
            for tool in sh bash sed rm cat grep; do
                tool_path=\$(command -v "\$tool" || true)
                [ -n "\$tool_path" ] && ln -sf "\$tool_path" "\$iso_sys/\$tool"
            done
            rewritten=\$(printf '%s' "\$script" | sed "s|/tmp/test_db|$sandbox/container_tmp_\$cname/test_db|g")
            MOCK_SQL_PIPE_LOG="$sql_pipe_log" PATH="\$mock_cli_dir:\$iso_sys" sh -c "\$rewritten" "\${\@:4}"
            exit \$?
        fi
        exit 0
        ;;
    logs)
        echo "mock container log"
        exit 0
        ;;
    rm)
        echo "\$*" >> "$rm_calls_log"
        exit 0
        ;;
    ps)
        echo "UNEXPECTED_DOCKER_PS_CALL" >&2
        exit 99
        ;;
    *)
        exit 0
        ;;
esac
SH
        0755
    );

    # Ensure host git/mysqladmin/mysql are stubbed in sandbox (parallel_test.sh should use container internal client)
    write_text_file( File::Spec->catfile( $bin_dir, 'git' ),        "#!/usr/bin/env bash\nexit 0\n", 0755 );
    write_text_file( File::Spec->catfile( $bin_dir, 'mysqladmin' ), "#!/usr/bin/env bash\nexit 0\n", 0755 );
    write_text_file( File::Spec->catfile( $bin_dir, 'mysql' ),      "#!/usr/bin/env bash\nexit 0\n", 0755 );

    my %env_map = (
        PROJECT_ROOT      => $sandbox,
        EXAMPLES_DIR      => $examples_dir,
        VENDOR_DIR        => $vendor_dir,
        CVE_FILE          => "$sandbox/vulnerabilities.csv",
        MOCK_MT_CALLS_LOG => $mt_calls_log,
        DATE_TAG          => '20261116_000000',
        PORT_BASE         => '35100',
        CONTAINER_PREFIX  => 'testlab-run',
        READY_TIMEOUT     => '10',
        PATH              => "$bin_dir:$ENV{PATH}",
    );

    my ( $rc, $out ) = run_cmd_capture(
        \%env_map,
        "bash -c 'cd \"$sandbox\" && bash \"$parallel_script\" mysql84 mysql267 mysql2610 mariadb114'"
    );

    is( $rc, 0, 'parallel_test.sh completes with exit code 0 when unavailable images are skipped' ) or diag($out);
    like( $out, qr/\[SKIP\] mysql267: image mysql:26\.7 unavailable/,   'logs explicit skip for mysql267' );
    like( $out, qr/\[SKIP\] mysql2610: image mysql:26\.10 unavailable/, 'logs explicit skip for mysql2610' );

    my $docker_calls = read_text_file($docker_calls_log);
    unlike( $docker_calls, qr/^ps\b/m, 'never invokes unfiltered docker ps' );
    like( $docker_calls, qr/run -d --name testlab-run-mysql84 -p 35100:3306/,     'starts mysql84 with custom prefix & PORT_BASE' );
    like( $docker_calls, qr/run -d --name testlab-run-mariadb114 -p 35103:3306/,  'starts mariadb114 on port PORT_BASE+idx' );
    unlike( $docker_calls, qr/testlab-run-mysql267|testlab-run-mysql2610/,       'never starts containers for skipped images' );

    my $rm_calls = read_text_file($rm_calls_log);
    like( $rm_calls, qr/testlab-run-mysql84/,    'cleans up active mysql84 container' );
    like( $rm_calls, qr/testlab-run-mariadb114/, 'cleans up active mariadb114 container' );
    unlike( $rm_calls, qr/mysql267|mysql2610|pg_formation_bouncer|sas_finance/, 'cleanup never touches skipped or unrelated containers' );

    my $sql_piped = read_text_file($sql_pipe_log);
    like( $sql_piped,   qr/^USE employees;/m, 'converts connect statements in employees.sql to USE' );
    unlike( $sql_piped, qr/^connect /mi,      'no raw connect directive reaches SQL client' );

    for my $cfg (qw(mysql84 mariadb114)) {
        my $base = File::Spec->catdir( $examples_dir, "20261116_000000_$cfg" );
        my $inj  = read_text_file( File::Spec->catfile( $base, 'db_injection.log' ) );
        like( $inj, qr/\[SUMMARY\] $cfg: .*sakila=OK/, "$cfg db_injection.log confirms sakila loaded even if employees warned" );

        for my $scen (qw(Standard Container Dumpdir Schemadir)) {
            my $html = File::Spec->catfile( $base, $scen, 'mysqltuner_report.html' );
            ok( -s $html, "$cfg/$scen/mysqltuner_report.html exists and is non-empty" );
        }

        my $json_path = File::Spec->catfile( $base, 'Standard', 'mysqltuner_report.json' );
        ok( -s $json_path, "$cfg/Standard/mysqltuner_report.json exists and is non-empty" );
        my $parsed = eval { decode_json( read_text_file($json_path) ) };
        is( $@, '', "$cfg/Standard/mysqltuner_report.json contains valid JSON" );
        ok( -e File::Spec->catfile( $base, 'Standard', 'json_execution.log' ), "$cfg/Standard/json_execution.log captured" );
    }

    my $mt_calls = read_text_file($mt_calls_log);
    like( $mt_calls, qr/--container docker:testlab-run-mysql84/,    'Container scenario targets custom CONTAINER_PREFIX container' );
    like( $mt_calls, qr/--json\b.*--outputfile .*mysqltuner_report\.json/, 'Standard scenario invokes mysqltuner.pl with --json and --outputfile' );

    my $tap = read_text_file( File::Spec->catfile( $examples_dir, '20261116_000000_parallel_test.tap' ) );
    like( $tap, qr/^ok \d+ - mysql84$/m,                                         'TAP records active mysql84 pass' );
    like( $tap, qr/^ok \d+ - mariadb114$/m,                                      'TAP records active mariadb114 pass' );
    like( $tap, qr/^ok \d+ - mysql2610 # SKIP image mysql:26\.10 unavailable$/m, 'TAP tracks skipped unavailable image cleanly' );
};

subtest 'parallel_test.sh graceful exit when all images are unavailable' => sub {
    plan tests => 4;

    my $sandbox      = tempdir( CLEANUP => 1 );
    my $bin_dir      = File::Spec->catdir( $sandbox, 'bin' );
    my $examples_dir = File::Spec->catdir( $sandbox, 'examples' );
    my $vendor_dir   = File::Spec->catdir( $sandbox, 'vendor' );
    make_path(
        $bin_dir,
        $examples_dir,
        File::Spec->catdir( $vendor_dir, 'multi-db-docker-env' ),
        File::Spec->catdir( $vendor_dir, 'test_db' )
    );

    write_text_file( File::Spec->catfile( $bin_dir, 'docker' ),     "#!/usr/bin/env bash\nexit 1\n", 0755 );
    write_text_file( File::Spec->catfile( $bin_dir, 'git' ),        "#!/usr/bin/env bash\nexit 0\n", 0755 );
    write_text_file( File::Spec->catfile( $bin_dir, 'mysqladmin' ), "#!/usr/bin/env bash\nexit 0\n", 0755 );
    write_text_file( File::Spec->catfile( $bin_dir, 'mysql' ),      "#!/usr/bin/env bash\nexit 0\n", 0755 );
    make_path( File::Spec->catdir( $sandbox, 'build' ) );
    write_text_file( File::Spec->catfile( $sandbox, 'build', 'get_supported_envs.pl' ), "#!/usr/bin/env perl\nprint \"mysql2610\\n\";\n" );
    write_text_file( File::Spec->catfile( $sandbox, 'build', 'audit_logs.pl' ), "#!/usr/bin/env perl\nexit 0;\n" );

    my %env_map = (
        PROJECT_ROOT => $sandbox,
        EXAMPLES_DIR => $examples_dir,
        VENDOR_DIR   => $vendor_dir,
        DATE_TAG     => '20261116_000001',
        PATH         => "$bin_dir:$ENV{PATH}",
    );

    my ( $rc, $out ) = run_cmd_capture(
        \%env_map,
        "bash -c 'cd \"$sandbox\" && bash \"$parallel_script\" mysql267 mysql2610'"
    );
    is( $rc, 0, 'exits 0 cleanly when all images are unavailable' ) or diag($out);
    like( $out, qr/\[SKIP\] mysql267: image mysql:26\.7 unavailable/,   'skips mysql267 without waiting' );
    like( $out, qr/\[SKIP\] mysql2610: image mysql:26\.10 unavailable/, 'skips mysql2610 without waiting' );

    my $tap_file = File::Spec->catfile( $examples_dir, '20261116_000001_parallel_test.tap' );
    ok( -s $tap_file, 'TAP file created when all images skipped' );
};

subtest 'test_envs.sh scoped compose detection, employees.sql handling, and resilient setup_vendor' => sub {
    plan tests => 7;

    my $src = read_text_file($test_envs_script);

    unlike( $src, qr/docker\s+ps\s+--format/, 'test_envs.sh must not use raw unfiltered docker ps' );
    like(
        $src,
        qr/docker\s+compose.*ps\s+--format\s+'\{\{\.Names\}\}'(?:\s+2>\/dev\/null)?\s*\|\s*grep\s+-v\s+"traefik"\s*\|\s*head\s+-n\s+1/,
        'test_envs.sh uses scoped docker compose ps container detection'
    );
    like( $src, qr/sed\s+[^\n]*s\/\^connect \/USE \/i/, 'test_envs.sh rewrites connect statements to USE safely' );
    like( $src, qr/command -v mysql \|\| command -v mariadb/, 'test_envs.sh supports both mysql and mariadb clients' );
    like( $src, qr/dirname\s+/,                          'test_envs.sh runs employees.sql from its directory' );

    my ( $help_rc, $help_out ) = run_cmd_capture( '', "bash \"$test_envs_script\" --help" );
    is( $help_rc, 0, 'test_envs.sh --help exits 0' ) or diag($help_out);

    # Verify setup_vendor does not abort under set -euo pipefail when vendor repos are dirty or offline
    my $sandbox    = tempdir( CLEANUP => 1 );
    my $bin_dir    = File::Spec->catdir( $sandbox, 'bin' );
    my $examples   = File::Spec->catdir( $sandbox, 'examples' );
    my $vendor_dir = File::Spec->catdir( $sandbox, 'vendor' );
    make_path(
        $bin_dir,
        $examples,
        File::Spec->catdir( $vendor_dir, 'multi-db-docker-env', '.git' ),
        File::Spec->catdir( $vendor_dir, 'test_db', '.git' )
    );

    # Mock git: status returns clean (empty), pull fails (simulating offline environment)
    write_text_file(
        File::Spec->catfile( $bin_dir, 'git' ),
        "#!/usr/bin/env bash\nfor a in \"\$@\"; do [ \"\$a\" = \"pull\" ] && exit 128; done\nexit 0\n",
        0755
    );

    my $lib_script = File::Spec->catfile( $sandbox, 'test_envs_lib.sh' );
    my $funcs_only = $src;
    $funcs_only =~ s/^while \[\[.*?\ndone\n//ms;
    $funcs_only =~ s/# Main Execution Flow.*\z//s;
    write_text_file( $lib_script, $funcs_only );

    my $run_setup = File::Spec->catfile( $sandbox, 'run_setup.sh' );
    write_text_file(
        $run_setup,
        <<"SH"
#!/usr/bin/env bash
set -euo pipefail
export PATH="$bin_dir:\$PATH"
cd "$sandbox"
source "$lib_script"
EXAMPLES_DIR="$examples"
VENDOR_DIR="$vendor_dir"
setup_vendor
SH
    );

    my ( $sv_rc, $sv_out ) = run_cmd_capture( '', "bash \"$run_setup\"" );
    is( $sv_rc, 0, 'setup_vendor survives offline/failing git pull under set -euo pipefail' ) or diag($sv_out);
};

done_testing();
