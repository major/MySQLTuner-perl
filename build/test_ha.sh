#!/bin/bash
# ===========================================================================
# Script:      test_ha.sh
# Description: E2E test suite for MySQLTuner against High Availability
#              topologies provided by multi-db-docker-env.
# Author:      Jean-Marie Renouard & Antigravity
# Usage:       bash build/test_ha.sh [galera|innodb|repli|all]
# Dependencies: Docker, multi-db-docker-env (cloned via vendor/)
# ===========================================================================
set -euo pipefail

# Configuration
PROJECT_ROOT=$(pwd)
VENDOR_DIR="$PROJECT_ROOT/vendor"
MULTI_DB_DIR="$VENDOR_DIR/multi-db-docker-env"
MULTI_DB_REPO="https://github.com/jmrenouard/multi-db-docker-env"
EXAMPLES_DIR="$PROJECT_ROOT/examples"
PROFILES_DIR="$PROJECT_ROOT/build/ha_profiles"
ANALYZER="$PROJECT_ROOT/build/analyze_mt_output.pl"
CVE_FILE="$PROJECT_ROOT/vulnerabilities.csv"
DATE_TAG=$(date +%Y%m%d_%H%M%S)
DB_PASS="${DB_ROOT_PASSWORD:-mysqltuner_test}"

# Topologies to test (default: all)
TOPOS="${1:-all}"

PASS_TOTAL=0
FAIL_TOTAL=0
WARN_TOTAL=0

log_step() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_header() {
    echo "======================================================================"
    echo "  MySQLTuner HA E2E Test - $1 - $(date)"
    echo "======================================================================"
}

# Setup vendor repositories
setup_vendor() {
    log_step "Setting up vendor repositories..."
    mkdir -p "$VENDOR_DIR"
    if [ ! -d "$MULTI_DB_DIR" ]; then
        git clone "$MULTI_DB_REPO" "$MULTI_DB_DIR"
    else
        (cd "$MULTI_DB_DIR" && git pull --ff-only 2>/dev/null || true)
    fi

    # Ensure .env exists
    if [ ! -f "$MULTI_DB_DIR/.env" ]; then
        echo "DB_ROOT_PASSWORD=$DB_PASS" > "$MULTI_DB_DIR/.env"
    fi
}

# Wait for a MySQL port to be ready
wait_for_port() {
    local port=$1
    local max_wait=${2:-120}
    local count=0
    log_step "Waiting for port $port to be ready (max ${max_wait}s)..."
    until mysqladmin -h 127.0.0.1 -P "$port" -u root -p"$DB_PASS" ping >/dev/null 2>&1; do
        sleep 2
        count=$((count + 2))
        if [ $count -ge $max_wait ]; then
            log_step "ERROR: Timeout waiting for port $port"
            return 1
        fi
    done
    log_step "Port $port is ready (${count}s)."
    return 0
}

# Run MySQLTuner against a specific port and capture output
run_mysqltuner_on_port() {
    local port=$1
    local target_dir=$2
    local node_label=$3
    local profile_file=$4

    local output_file="$target_dir/${node_label}_output.txt"
    local report_file="$target_dir/${node_label}_report.html"

    log_step "Running MySQLTuner on $node_label (port $port)..."

    local mt_args="--host 127.0.0.1 --port $port --user root --pass $DB_PASS"
    mt_args="$mt_args --verbose --forcemem 256"
    [ -f "$CVE_FILE" ] && mt_args="$mt_args --cvefile $CVE_FILE"
    mt_args="$mt_args --reportfile $report_file"

    local start_time=$(date +%s)
    perl "$PROJECT_ROOT/mysqltuner.pl" $mt_args > "$output_file" 2>&1 || true
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_step "MySQLTuner finished on $node_label in ${duration}s"

    # Run analyzer
    log_step "Analyzing output for $node_label..."
    local analyzer_args="$output_file"
    [ -n "$profile_file" ] && [ -f "$profile_file" ] && analyzer_args="--profile $profile_file $analyzer_args"

    local analyze_exit=0
    perl "$ANALYZER" $analyzer_args 2>&1 | tee "$target_dir/${node_label}_analysis.txt" || analyze_exit=$?

    # Also produce JSON
    perl "$ANALYZER" --json $analyzer_args > "$target_dir/${node_label}_analysis.json" 2>/dev/null || true

    return $analyze_exit
}

# Run a complete HA topology test
run_ha_test() {
    local topo=$1
    local profile_file="$PROFILES_DIR/${topo}.json"

    if [ ! -f "$profile_file" ]; then
        log_step "ERROR: Profile not found: $profile_file"
        FAIL_TOTAL=$((FAIL_TOTAL + 1))
        return 1
    fi

    # Parse profile with perl (Core module JSON)
    local display_name
    display_name=$(perl -MJSON -e 'local $/; open my $f, "<", shift; print decode_json(<$f>)->{display_name}' "$profile_file")
    local startup_cmd
    startup_cmd=$(perl -MJSON -e 'local $/; open my $f, "<", shift; print decode_json(<$f>)->{startup_command}' "$profile_file")
    local shutdown_cmd
    shutdown_cmd=$(perl -MJSON -e 'local $/; open my $f, "<", shift; print decode_json(<$f>)->{shutdown_command}' "$profile_file")
    local ports_json
    ports_json=$(perl -MJSON -e 'local $/; open my $f, "<", shift; print encode_json(decode_json(<$f>)->{ports})' "$profile_file")
    local inject_cmd
    inject_cmd=$(perl -MJSON -e 'local $/; open my $f, "<", shift; print decode_json(<$f>)->{inject_command}' "$profile_file")

    log_header "$display_name"

    local target_dir="$EXAMPLES_DIR/${DATE_TAG}_ha_${topo}"
    mkdir -p "$target_dir"

    # Navigate to multi-db-docker-env
    cd "$MULTI_DB_DIR" || return 1

    # Start topology
    log_step "Starting $display_name via 'make $startup_cmd'..."
    make "$startup_cmd" > "$target_dir/docker_start.log" 2>&1 || {
        log_step "CRITICAL: Failed to start $display_name"
        cat "$target_dir/docker_start.log"
        FAIL_TOTAL=$((FAIL_TOTAL + 1))
        cd "$PROJECT_ROOT"
        return 1
    }

    # Wait for all ports
    local ports
    ports=$(echo "$ports_json" | perl -MJSON -e 'local $/; my $a = decode_json(<STDIN>); print join(" ", @$a)')
    local all_ready=true
    for port in $ports; do
        if ! wait_for_port "$port" 120; then
            all_ready=false
            break
        fi
    done

    if [ "$all_ready" = false ]; then
        log_step "ERROR: Not all ports ready for $display_name"
        docker compose -f "docker-compose-${topo}.yml" logs > "$target_dir/container_logs.log" 2>&1 || true
        make "$shutdown_cmd" > /dev/null 2>&1 || true
        FAIL_TOTAL=$((FAIL_TOTAL + 1))
        cd "$PROJECT_ROOT"
        return 1
    fi

    # Inject data
    if [ -n "$inject_cmd" ]; then
        log_step "Injecting test data via 'make $inject_cmd'..."
        make $inject_cmd > "$target_dir/db_injection.log" 2>&1 || {
            log_step "WARNING: Data injection failed (non-fatal)"
        }
    fi

    # Capture container logs
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" > "$target_dir/container_status.txt" 2>/dev/null || true

    # Return to project root
    cd "$PROJECT_ROOT"

    # Run MySQLTuner on each node
    local node_idx=0
    local topo_errors=0
    for port in $ports; do
        node_idx=$((node_idx + 1))
        local node_label="node${node_idx}_port${port}"
        local exit_code=0
        run_mysqltuner_on_port "$port" "$target_dir" "$node_label" "$profile_file" || exit_code=$?

        case $exit_code in
            0) PASS_TOTAL=$((PASS_TOTAL + 1)) ;;
            1) WARN_TOTAL=$((WARN_TOTAL + 1)) ;;
            *)
                FAIL_TOTAL=$((FAIL_TOTAL + 1))
                topo_errors=$((topo_errors + 1))
                ;;
        esac
    done

    # Shutdown topology
    cd "$MULTI_DB_DIR"
    log_step "Shutting down $display_name via 'make $shutdown_cmd'..."
    make "$shutdown_cmd" > "$target_dir/docker_shutdown.log" 2>&1 || true
    cd "$PROJECT_ROOT"

    # Generate consolidated summary
    log_step "Generating summary for $display_name..."
    {
        echo "# HA E2E Test Summary: $display_name"
        echo "**Date:** $(date)"
        echo "**Topology:** $topo"
        echo "**Nodes tested:** $node_idx"
        echo "**Errors:** $topo_errors"
        echo ""
        echo "## Node Results"
        for f in "$target_dir"/*_analysis.txt; do
            [ -f "$f" ] && echo "### $(basename "$f" _analysis.txt)" && cat "$f" && echo ""
        done
    } > "$target_dir/summary.md"

    if [ $topo_errors -eq 0 ]; then
        log_step "✅ $display_name: ALL NODES PASSED"
    else
        log_step "❌ $display_name: $topo_errors NODE(S) FAILED"
    fi

    return $topo_errors
}

# =====================================================================
# Main Execution
# =====================================================================
setup_vendor

case "$TOPOS" in
    galera)
        run_ha_test "galera"
        ;;
    innodb|innodb_cluster)
        run_ha_test "innodb_cluster"
        ;;
    repli|replication)
        run_ha_test "replication"
        ;;
    all)
        run_ha_test "galera" || true
        run_ha_test "innodb_cluster" || true
        run_ha_test "replication" || true
        ;;
    *)
        echo "Usage: $0 [galera|innodb|repli|all]"
        exit 1
        ;;
esac

echo ""
echo "======================================================================"
echo "  HA E2E Test Complete"
echo "  PASS: $PASS_TOTAL | WARN: $WARN_TOTAL | FAIL: $FAIL_TOTAL"
echo "  Reports: $EXAMPLES_DIR"
echo "======================================================================"

if [ $FAIL_TOTAL -gt 0 ]; then
    exit 1
fi
exit 0
