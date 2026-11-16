#!/usr/bin/env bash
# ===========================================================================
# Script:      build/parallel_test.sh
# Description: Runs MySQLTuner laboratory validation tests in parallel.
# Author:      Jean-Marie Renouard / Antigravity
# Usage:       bash build/parallel_test.sh [options] [configs...]
# ===========================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
EXAMPLES_DIR="${EXAMPLES_DIR:-$PROJECT_ROOT/examples}"
VENDOR_DIR="${VENDOR_DIR:-$PROJECT_ROOT/vendor}"
DATE_TAG="${DATE_TAG:-$(date +%Y%m%d_%H%M%S)}"
CVE_FILE="${CVE_FILE:-$PROJECT_ROOT/vulnerabilities.csv}"
PORT_BASE="${PORT_BASE:-33060}"
CONTAINER_PREFIX="${CONTAINER_PREFIX:-mysqltuner-parallel}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-mysqltuner_test}"
READY_TIMEOUT="${READY_TIMEOUT:-120}"

# Map a configuration token (e.g. mysql84, mysql2610, mariadb114, percona80) to its Docker image
resolve_docker_image() {
    local config="$1"
    local ver=""
    if [[ "$config" =~ ^mysql([0-9]+)$ ]]; then
        ver="${BASH_REMATCH[1]}"
        if [ "${#ver}" -ge 3 ]; then
            printf 'mysql:%s.%s\n' "${ver:0:2}" "${ver:2}"
        else
            printf 'mysql:%s.%s\n' "${ver:0:1}" "${ver:1}"
        fi
        return 0
    elif [[ "$config" =~ ^mariadb([0-9]+)$ ]]; then
        ver="${BASH_REMATCH[1]}"
        if [[ "${ver:0:1}" == "5" ]]; then
            printf 'mariadb:%s.%s\n' "${ver:0:1}" "${ver:1}"
        else
            printf 'mariadb:%s.%s\n' "${ver:0:2}" "${ver:2}"
        fi
        return 0
    elif [[ "$config" =~ ^percona([0-9]+)$ ]]; then
        ver="${BASH_REMATCH[1]}"
        if [ "${#ver}" -ge 3 ]; then
            printf 'percona/percona-server:%s.%s\n' "${ver:0:2}" "${ver:2}"
        else
            printf 'percona/percona-server:%s.%s\n' "${ver:0:1}" "${ver:1}"
        fi
        return 0
    fi
    return 1
}

show_usage() {
    cat <<EOF
Usage: $0 [options] [configs...]
Options:
  --print-image <config>   Print resolved Docker image for <config> and exit
  --dry-run                Print resolved configs, images, ports, and container names without Docker execution
  -h, --help               Show this help message
EOF
}

DRY_RUN=false
POSITIONAL_CONFIGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --print-image)
            if [ $# -lt 2 ]; then
                echo "ERROR: --print-image requires a config argument" >&2
                exit 1
            fi
            if ! resolve_docker_image "$2"; then
                echo "ERROR: Unsupported configuration '$2'" >&2
                exit 1
            fi
            exit 0
            ;;
        --print-image=*)
            cfg="${1#*=}"
            if [ -z "$cfg" ] || ! resolve_docker_image "$cfg"; then
                echo "ERROR: Unsupported configuration '$cfg'" >&2
                exit 1
            fi
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        --)
            shift
            while [ $# -gt 0 ]; do
                POSITIONAL_CONFIGS+=("$1")
                shift
            done
            ;;
        -*)
            echo "ERROR: Unknown option '$1'" >&2
            exit 1
            ;;
        *)
            POSITIONAL_CONFIGS+=("$1")
            shift
            ;;
    esac
done

if ! [[ "$PORT_BASE" =~ ^[0-9]+$ ]]; then
    echo "ERROR: PORT_BASE must be numeric (got '$PORT_BASE')" >&2
    exit 1
fi

if [ "${#POSITIONAL_CONFIGS[@]}" -gt 0 ]; then
    CONFIGS="${POSITIONAL_CONFIGS[*]}"
else
    CONFIGS=$(cd "$PROJECT_ROOT" && perl "$PROJECT_ROOT/build/get_supported_envs.pl")
fi

declare -A config_ports
declare -A config_images
declare -a ACTIVE_CONFIGS=()
declare -a SKIPPED_CONFIGS=()
declare -A skip_reasons
declare -a CREATED_CONFIGS=()

# Setup port and image mappings across all requested configs
idx=0
for config in $CONFIGS; do
    port=$((PORT_BASE + idx))
    config_ports["$config"]=$port
    if image=$(resolve_docker_image "$config"); then
        config_images["$config"]="$image"
    else
        config_images["$config"]=""
    fi
    idx=$((idx + 1))
done

if [ "$DRY_RUN" = "true" ]; then
    echo "PORT_BASE=$PORT_BASE"
    echo "CONTAINER_PREFIX=$CONTAINER_PREFIX"
    for config in $CONFIGS; do
        echo "CONFIG=$config IMAGE=${config_images[$config]:-UNSUPPORTED} PORT=${config_ports[$config]} CONTAINER=${CONTAINER_PREFIX}-${config}"
    done
    exit 0
fi

# Scoped, idempotent cleanup removing only containers created with CONTAINER_PREFIX
cleanup_done=false
cleanup() {
    if [ "$cleanup_done" = "true" ]; then
        return 0
    fi
    cleanup_done=true
    if [ "${#CREATED_CONFIGS[@]}" -eq 0 ]; then
        return 0
    fi
    echo "Cleaning up parallel test containers..."
    local cfg
    for cfg in "${CREATED_CONFIGS[@]}"; do
        docker rm -f "${CONTAINER_PREFIX}-${cfg}" >/dev/null 2>&1 || true
    done
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

echo "Supported configurations: $CONFIGS"

# Setup vendor directories (only clone when absent)
mkdir -p "$EXAMPLES_DIR" "$VENDOR_DIR"
if [ ! -d "$VENDOR_DIR/multi-db-docker-env" ]; then
    git clone "https://github.com/jmrenouard/multi-db-docker-env" "$VENDOR_DIR/multi-db-docker-env" || true
fi
if [ ! -d "$VENDOR_DIR/test_db" ]; then
    git clone "https://github.com/jmrenouard/test_db" "$VENDOR_DIR/test_db" || true
fi

# Pre-check Docker image availability before starting containers
echo "Checking Docker image availability..."
for config in $CONFIGS; do
    image="${config_images[$config]:-}"
    if [ -z "$image" ]; then
        echo "[SKIP] $config: unsupported configuration"
        SKIPPED_CONFIGS+=("$config")
        skip_reasons["$config"]="unsupported configuration"
        continue
    fi
    if docker image inspect "$image" >/dev/null 2>&1 || docker pull "$image" >/dev/null 2>&1; then
        ACTIVE_CONFIGS+=("$config")
    else
        echo "[SKIP] $config: image $image unavailable"
        SKIPPED_CONFIGS+=("$config")
        skip_reasons["$config"]="image $image unavailable"
    fi
done

TAP_FILE="$EXAMPLES_DIR/${DATE_TAG}_parallel_test.tap"
if [ "${#ACTIVE_CONFIGS[@]}" -eq 0 ]; then
    total_count=0
    for _c in $CONFIGS; do
        total_count=$((total_count + 1))
    done
    if [ "$total_count" -eq 0 ]; then
        echo "1..0 # SKIP no configurations specified" > "$TAP_FILE"
    else
        echo "1..$total_count" > "$TAP_FILE"
        idx=1
        for config in $CONFIGS; do
            echo "ok $idx - $config # SKIP ${skip_reasons[$config]:-unavailable}" >> "$TAP_FILE"
            idx=$((idx + 1))
        done
    fi
    echo "[WARN] No active configurations with available images. TAP report written to $TAP_FILE"
    exit 0
fi

# Start all active containers in parallel
echo "Starting active containers in parallel (${ACTIVE_CONFIGS[*]})..."
pfs_mounts=()
if [ -f "$VENDOR_DIR/multi-db-docker-env/conf/pfs.cnf" ]; then
    pfs_mounts=(
        -v "$VENDOR_DIR/multi-db-docker-env/conf/pfs.cnf:/etc/mysql/conf.d/pfs.cnf:ro"
        -v "$VENDOR_DIR/multi-db-docker-env/conf/pfs.cnf:/etc/my.cnf.d/pfs.cnf:ro"
    )
fi

for config in "${ACTIVE_CONFIGS[@]}"; do
    port="${config_ports[$config]}"
    image="${config_images[$config]}"
    cname="${CONTAINER_PREFIX}-${config}"
    target_dir="$EXAMPLES_DIR/${DATE_TAG}_$config"
    mkdir -p "$target_dir/Standard" "$target_dir/Container" "$target_dir/Dumpdir/dumps" "$target_dir/Schemadir/schemas"
    CREATED_CONFIGS+=("$config")

    echo "   Starting $config on port $port using image $image ($cname)..."
    docker rm -f "$cname" >/dev/null 2>&1 || true
    docker run -d \
        --name "$cname" \
        -p "$port:3306" \
        --cpus="1.0" \
        --memory="1024m" \
        -e MYSQL_ROOT_PASSWORD="$DB_ROOT_PASSWORD" \
        -e MARIADB_ROOT_PASSWORD="$DB_ROOT_PASSWORD" \
        -e MYSQL_ROOT_HOST="%" \
        "${pfs_mounts[@]}" \
        "$image" > "$target_dir/docker_start.log" 2>&1 &
done
wait

# Wait for all active databases to become ready in parallel via each container's native admin binary
echo "Waiting for databases to initialize..."
for config in "${ACTIVE_CONFIGS[@]}"; do
    port="${config_ports[$config]}"
    cname="${CONTAINER_PREFIX}-${config}"
    target_dir="$EXAMPLES_DIR/${DATE_TAG}_$config"
    (
        rm -f "$target_dir/.ready_ok" "$target_dir/.ready_fail"
        timeout="$READY_TIMEOUT"
        count=0
        until docker exec "$cname" sh -c '
            if command -v mariadb-admin >/dev/null 2>&1; then
                mariadb-admin -h 127.0.0.1 -u root "-p$1" ping >/dev/null 2>&1
            else
                mysqladmin -h 127.0.0.1 -u root "-p$1" ping >/dev/null 2>&1
            fi
        ' _ "$DB_ROOT_PASSWORD"; do
            running=$(docker inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo "false")
            if [ "$running" != "true" ] && [ "$count" -ge 4 ]; then
                echo "[ERROR] Container $cname exited before becoming ready" > "$target_dir/.ready_fail"
                exit 1
            fi
            sleep 2
            count=$((count + 2))
            if [ "$count" -ge "$timeout" ]; then
                echo "[ERROR] Timeout waiting for $config ($cname) on port $port" | tee "$target_dir/.ready_fail"
                exit 1
            fi
        done
        echo "ok" > "$target_dir/.ready_ok"
        echo "[OK] $config on port $port is ready ($cname)"
    ) &
done
wait

# Inject test datasets (employees and sakila) in parallel inside each active container
echo "Injecting test databases (employees/sakila)..."
for config in "${ACTIVE_CONFIGS[@]}"; do
    cname="${CONTAINER_PREFIX}-${config}"
    target_dir="$EXAMPLES_DIR/${DATE_TAG}_$config"
    (
        inject_log="$target_dir/db_injection.log"
        : > "$inject_log"
        if [ ! -f "$target_dir/.ready_ok" ]; then
            echo "[SKIP] Skipping injection for $config because container failed readiness check" >> "$inject_log"
            exit 0
        fi
        if [ ! -d "$VENDOR_DIR/test_db" ]; then
            echo "[WARN] $VENDOR_DIR/test_db not found; skipping injection for $config" >> "$inject_log"
            exit 0
        fi

        if ! docker cp "$VENDOR_DIR/test_db/." "$cname:/tmp/test_db" >> "$inject_log" 2>&1; then
            echo "[ERROR] Failed to copy test_db into $cname" >> "$inject_log"
            exit 1
        fi

        docker exec "$cname" sh -c '
            set -u
            pass="$1"
            cfg="$2"
            if command -v mariadb >/dev/null 2>&1; then
                db_cli="mariadb"
            else
                db_cli="mysql"
            fi

            emp_status="SKIPPED"
            if [ -f /tmp/test_db/employees/employees.sql ]; then
                echo "[INFO] Loading employees dataset into $cfg via $db_cli..."
                if (cd /tmp/test_db/employees && sed "s/^connect /USE /i" employees.sql | "$db_cli" -h 127.0.0.1 -u root "-p$pass"); then
                    emp_status="OK"
                else
                    emp_rc=$?
                    echo "[WARN] employees dataset load exited $emp_rc on $cfg; continuing to sakila"
                    emp_status="WARN_RC_${emp_rc}"
                fi
            fi

            sak_status="SKIPPED"
            if [ -f /tmp/test_db/sakila/sakila-mv-schema.sql ] && [ -f /tmp/test_db/sakila/sakila-mv-data.sql ]; then
                echo "[INFO] Loading sakila dataset into $cfg via $db_cli..."
                if "$db_cli" -h 127.0.0.1 -u root "-p$pass" < /tmp/test_db/sakila/sakila-mv-schema.sql && \
                   "$db_cli" -h 127.0.0.1 -u root "-p$pass" < /tmp/test_db/sakila/sakila-mv-data.sql; then
                    sak_status="OK"
                else
                    sak_rc=$?
                    echo "[ERROR] sakila dataset load failed with exit code $sak_rc on $cfg"
                    sak_status="FAIL_RC_${sak_rc}"
                fi
            fi

            emp_counts=$("$db_cli" -h 127.0.0.1 -u root "-p$pass" -N -B -e "SELECT CONCAT(COUNT(*), '\''/'\'', COALESCE(SUM(TABLE_ROWS),0)) FROM information_schema.TABLES WHERE TABLE_SCHEMA='\''employees'\'';" 2>/dev/null || echo "0/0")
            sak_counts=$("$db_cli" -h 127.0.0.1 -u root "-p$pass" -N -B -e "SELECT CONCAT(COUNT(*), '\''/'\'', COALESCE(SUM(TABLE_ROWS),0)) FROM information_schema.TABLES WHERE TABLE_SCHEMA='\''sakila'\'';" 2>/dev/null || echo "0/0")
            echo "[SUMMARY] $cfg: employees=$emp_status (tables/rows=$emp_counts) | sakila=$sak_status (tables/rows=$sak_counts)"
            rm -rf /tmp/test_db
        ' _ "$DB_ROOT_PASSWORD" "$config" >> "$inject_log" 2>&1

        echo "[OK] Data injection finished for $config"
    ) &
done
wait

# Execute MySQLTuner across all 4 scenarios plus Standard JSON export in parallel
echo "Running MySQLTuner test suite in parallel..."
for config in "${ACTIVE_CONFIGS[@]}"; do
    port="${config_ports[$config]}"
    cname="${CONTAINER_PREFIX}-${config}"
    target_dir="$EXAMPLES_DIR/${DATE_TAG}_$config"
    (
        if [ ! -f "$target_dir/.ready_ok" ]; then
            echo "[SKIP] Skipping MySQLTuner execution for $config (container not ready)"
            exit 0
        fi

        docker inspect "$cname" > "$target_dir/Container/container_inspect.json" 2>/dev/null || true

        scenario_rc=0

        # 1. Standard Mode (HTML + Text + JSON)
        perl "$PROJECT_ROOT/mysqltuner.pl" \
            --host 127.0.0.1 --port "$port" --user root --pass "$DB_ROOT_PASSWORD" \
            --verbose --noask --cvefile "$CVE_FILE" \
            --outputfile "$target_dir/Standard/mysqltuner_output.txt" \
            --reportfile "$target_dir/Standard/mysqltuner_report.html" \
            > "$target_dir/Standard/execution.log" 2>&1 || scenario_rc=$?

        perl "$PROJECT_ROOT/mysqltuner.pl" \
            --host 127.0.0.1 --port "$port" --user root --pass "$DB_ROOT_PASSWORD" \
            --verbose --noask --cvefile "$CVE_FILE" \
            --json --prettyjson --silent \
            --outputfile "$target_dir/Standard/mysqltuner_report.json" \
            >/dev/null 2> "$target_dir/Standard/json_execution.log" || scenario_rc=$?

        # 2. Container Mode
        perl "$PROJECT_ROOT/mysqltuner.pl" \
            --container "docker:$cname" --user root --pass "$DB_ROOT_PASSWORD" \
            --verbose --noask --cvefile "$CVE_FILE" \
            --outputfile "$target_dir/Container/mysqltuner_output.txt" \
            --reportfile "$target_dir/Container/mysqltuner_report.html" \
            > "$target_dir/Container/execution.log" 2>&1 || scenario_rc=$?
        docker logs "$cname" > "$target_dir/Container/container_logs.log" 2>&1 || true

        # 3. Dumpdir Mode
        perl "$PROJECT_ROOT/mysqltuner.pl" \
            --host 127.0.0.1 --port "$port" --user root --pass "$DB_ROOT_PASSWORD" \
            --verbose --noask --dumpdir "$target_dir/Dumpdir/dumps" --cvefile "$CVE_FILE" \
            --outputfile "$target_dir/Dumpdir/mysqltuner_output.txt" \
            --reportfile "$target_dir/Dumpdir/mysqltuner_report.html" \
            > "$target_dir/Dumpdir/execution.log" 2>&1 || scenario_rc=$?

        # 4. Schemadir Mode
        perl "$PROJECT_ROOT/mysqltuner.pl" \
            --host 127.0.0.1 --port "$port" --user root --pass "$DB_ROOT_PASSWORD" \
            --verbose --noask --schemadir "$target_dir/Schemadir/schemas" --cvefile "$CVE_FILE" \
            --outputfile "$target_dir/Schemadir/mysqltuner_output.txt" \
            --reportfile "$target_dir/Schemadir/mysqltuner_report.html" \
            > "$target_dir/Schemadir/execution.log" 2>&1 || scenario_rc=$?

        echo "$scenario_rc" > "$target_dir/.scenario_rc"
        echo "[OK] MySQLTuner tests completed for $config (rc=$scenario_rc)"
    ) &
done
wait

# Verify artifacts and audit logs across active configs while emitting SKIP entries for unavailable images
echo "Running log and artifact checker..."
total_count=0
for _c in $CONFIGS; do
    total_count=$((total_count + 1))
done
echo "1..$total_count" > "$TAP_FILE"

idx=1
overall_success=true
for config in $CONFIGS; do
    if [ -n "${skip_reasons[$config]:-}" ]; then
        line="ok $idx - $config # SKIP ${skip_reasons[$config]}"
        echo "$line" >> "$TAP_FILE"
        echo "$line"
        idx=$((idx + 1))
        continue
    fi

    target_dir="$EXAMPLES_DIR/${DATE_TAG}_$config"
    config_ok=true
    fail_reason=""

    if [ ! -f "$target_dir/.ready_ok" ]; then
        config_ok=false
        fail_reason="container readiness failed"
    fi

    if [ "$config_ok" = "true" ]; then
        scen_rc=$(cat "$target_dir/.scenario_rc" 2>/dev/null || echo "1")
        if [ "$scen_rc" != "0" ]; then
            config_ok=false
            fail_reason="mysqltuner execution exited $scen_rc"
        fi
    fi

    if [ "$config_ok" = "true" ]; then
        for scen in Standard Container Dumpdir Schemadir; do
            if [ ! -s "$target_dir/$scen/mysqltuner_report.html" ]; then
                config_ok=false
                fail_reason="missing or empty $scen/mysqltuner_report.html"
                break
            fi
        done
    fi

    if [ "$config_ok" = "true" ]; then
        json_file="$target_dir/Standard/mysqltuner_report.json"
        if [ ! -s "$json_file" ]; then
            config_ok=false
            fail_reason="missing or empty Standard/mysqltuner_report.json"
        elif ! perl -MJSON::PP -e 'local $/; open my $f, "<", shift or exit 1; my $c = <$f>; JSON::PP::decode_json($c);' "$json_file" >/dev/null 2>&1; then
            config_ok=false
            fail_reason="invalid JSON in Standard/mysqltuner_report.json"
        fi
    fi

    if [ "$config_ok" = "true" ] && [ -f "$target_dir/db_injection.log" ]; then
        if grep -q "sakila=FAIL_" "$target_dir/db_injection.log"; then
            config_ok=false
            fail_reason="sakila dataset injection failed"
        fi
    fi

    if [ "$config_ok" = "true" ]; then
        if ! perl "$PROJECT_ROOT/build/audit_logs.pl" --dir "$target_dir" >/dev/null 2>&1; then
            config_ok=false
            fail_reason="audit_logs.pl detected anomalies"
        fi
    fi

    if [ "$config_ok" = "true" ]; then
        echo "ok $idx - $config" >> "$TAP_FILE"
        echo "ok $idx - $config"
    else
        echo "not ok $idx - $config # $fail_reason" >> "$TAP_FILE"
        echo "not ok $idx - $config # $fail_reason"
        overall_success=false
    fi
    idx=$((idx + 1))
done

echo "Compiled TAP Report written to $TAP_FILE"

if [ "$overall_success" = "true" ]; then
    exit_code=0
    echo "[OK] Parallel test execution completed successfully with no anomalies."
else
    exit_code=1
    echo "[FAIL] Anomalies or missing artifacts detected during test validation."
fi

exit $exit_code
