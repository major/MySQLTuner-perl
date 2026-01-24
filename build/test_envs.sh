#!/bin/bash
# ==================================================================================
# Script: test_envs.sh
# Description: Unified MySQLTuner Testing Laboratory & Audit Suite.
# Features: Docker Lab, Existing Containers, Remote SSH Auditing.
# Author: Jean-Marie Renouard & Antigravity
# Project: MySQLTuner-perl
# ==================================================================================

# Configuration
PROJECT_ROOT=$(pwd)
EXAMPLES_DIR="$PROJECT_ROOT/examples"
VENDOR_DIR="$PROJECT_ROOT/vendor"
DATE_TAG=$(date +%Y%m%d_%H%M%S)

# Dependencies
MULTI_DB_REPO="https://github.com/jmrenouard/multi-db-docker-env"
TEST_DB_REPO="https://github.com/jmrenouard/test_db"

# Default configurations
DEFAULT_CONFIGS="mysql84 mariadb1011 percona80"
CONFIGS=""
TARGET_DB=""
FORCEMEM_VAL=""
MODE="lab" # Modes: lab, container, remote
EXISTING_CONTAINER=""
REMOTE_HOST=""
SSH_OPTIONS="-q -o TCPKeepAlive=yes -o ServerAliveInterval=50 -o strictHostKeyChecking=no"
DO_AUDIT=false

show_usage() {
    echo "Usage: $0 [options] [configs...]"
    echo "Options:"
    echo "  -c, --configs \"list\"      List of lab configurations to test (e.g. \"mysql84 mariadb1011\")"
    echo "  -e, --container name      Test against an existing running container"
    echo "  -r, --remote host         Perform audit on a remote host (SSH)"
    echo "  -a, --audit               Perform additional audit tasks (pt-summary, pt-mysql-summary, innotop)"
    echo "  -d, --database name       Target database name for MySQLTuner to tune"
    echo "  -f, --forcemem value      Value for --forcemem parameter (in MB)"
    echo "  -s, --ssh-options \"opts\"  Additional SSH options"
    echo "  --cleanup                 Maintain only 10 latest results in examples/"
    echo "  -h, --help                Show this help"
    echo ""
    echo "Modes:"
    echo "  Lab (default): Starts containers from multi-db-docker-env, injects data, runs tests."
    echo "  Container:     Runs MySQLTuner against a running container (Docker/Podman)."
    echo "  Remote:        Runs MySQLTuner and audit tools on a remote server via SSH."
    echo ""
    echo "Examples:"
    echo "  $0 mysql84 mariadb106"
    echo "  $0 -e my_running_mysql_container"
    echo "  $0 -r db-server.example.com -a"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--configs)
            CONFIGS="$CONFIGS $2"
            shift 2
            ;;
        -e|--container)
            MODE="container"
            EXISTING_CONTAINER="$2"
            shift 2
            ;;
        -r|--remote)
            MODE="remote"
            REMOTE_HOST="$2"
            shift 2
            ;;
        -a|--audit)
            DO_AUDIT=true
            shift
            ;;
        -d|--database)
            TARGET_DB="$2"
            shift 2
            ;;
        -f|--forcemem)
            FORCEMEM_VAL="$2"
            shift 2
            ;;
        -s|--ssh-options)
            SSH_OPTIONS="$SSH_OPTIONS $2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        --cleanup)
            MODE="cleanup"
            shift
            ;;
        *)
            CONFIGS="$CONFIGS $1"
            shift
            ;;
    esac
done

# Fallback to defaults for lab mode if no configs provided
if [ "$MODE" = "lab" ] && [ -z "$(echo $CONFIGS | xargs)" ]; then
    CONFIGS=$DEFAULT_CONFIGS
fi

log_step() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_header() {
    echo "======================================================================"
    echo "MySQLTuner Laboratory - $1 - $(date)"
    echo "======================================================================"
}

mkdir -p "$EXAMPLES_DIR"
mkdir -p "$VENDOR_DIR"

# Setup Vendor Repositories (only for Lab mode)
setup_vendor() {
    log_step "Setting up vendor repositories..."
    if [ ! -d "$VENDOR_DIR/multi-db-docker-env" ]; then
        git clone "$MULTI_DB_REPO" "$VENDOR_DIR/multi-db-docker-env"
    else
        (cd "$VENDOR_DIR/multi-db-docker-env" && git pull)
    fi

    if [ ! -d "$VENDOR_DIR/test_db" ]; then
        git clone "$TEST_DB_REPO" "$VENDOR_DIR/test_db"
    else
        (cd "$VENDOR_DIR/test_db" && git pull)
    fi
}

# Helper to run commands (local, docker, or ssh)
run_cmd() {
    local cmd=$1
    local out=$2
    case "$MODE" in
        lab|container)
            eval "$cmd" > "$out" 2>&1
            ;;
        remote)
            ssh $SSH_OPTIONS "root@$REMOTE_HOST" "$cmd" > "$out" 2>&1
            ;;
    esac
}

# Maintain only 10 latest results in examples/
cleanup_examples() {
    log_step "Cleaning up old examples (keeping 10 latest)..."
    # List directories in EXAMPLES_DIR, sort by modification time descending, skip first 10, then remove the rest.
    ls -dt "$EXAMPLES_DIR"/*/ 2>/dev/null | tail -n +11 | xargs -r rm -rf
}

# Generate unified HTML report
generate_report() {
    local target_dir=$1
    local name=$2
    local ret_code=$3
    local exec_time=$4
    local db_version=$5
    local db_list=$6
    local repro_cmds=$7
    local current_scenario=$8

    log_step "Generating consolidated HTML report for $name ($current_scenario)..."
    
    local mt_output=$(cat "$target_dir/mysqltuner_output.txt" 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' || echo "No output.")
    
    # helper for panels
    render_panel() {
        local file=$1; local title=$2; local icon=$3; local color=$4; local content=$5; local log_file=$6
        [ -z "$content" ] && [ -f "$target_dir/$file" ] && content=$(cat "$target_dir/$file" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        [ -z "$content" ] && return
        
        local links="<a href='$file' class='text-xs text-blue-400 hover:text-blue-300 transition-colors'>Raw</a>"
        [ -n "$log_file" ] && [ -f "$target_dir/$log_file" ] && links+="<span class='mx-2 text-gray-600'>|</span><a href='$log_file' class='text-xs text-gray-400 hover:text-gray-300 transition-colors'>Log</a>"

        echo "<section class='bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden mb-8'>
            <div class='bg-gray-700 px-6 py-4 flex justify-between items-center'>
                <h2 class='text-lg font-semibold flex items-center'><i class='fas $icon mr-3 $color'></i>$title</h2>
                <div class='flex items-center'>$links</div>
            </div>
            <div class='p-6'>
                <pre class='bg-gray-950 p-4 rounded-lg overflow-x-auto text-xs font-mono text-gray-400 max-h-96 overflow-y-auto'>$content</pre>
            </div>
        </section>"
    }

    # Process Audit Logs
    local audit_html=""
    if [ "$DO_AUDIT" = true ]; then
        for audit_file in pt-summary.txt pt-mysql-summary.txt innotop.txt; do
            audit_html+=$(render_panel "$audit_file" "$audit_file" "fa-microchip" "text-purple-400")
        done
    fi

    # Process Infrastructure Logs
    local infra_sections=""
    infra_sections+=$(render_panel "docker_start.log" "Docker Engine Startup" "fa-rocket" "text-orange-500")
    infra_sections+=$(render_panel "db_injection.log" "Database Data Injection" "fa-syringe" "text-blue-500")
    infra_sections+=$(render_panel "container_logs.log" "Container Runtime Logs" "fa-list-ul" "text-green-500")
    infra_sections+=$(render_panel "container_inspect.json" "Container Metadata" "fa-search" "text-cyan-500")

    # Scenario Selector Bar
    local scenario_bar=""
    if [ -n "$current_scenario" ]; then
        scenario_bar="<div class='flex border-b border-gray-700 mb-8'>"
        for s in Standard Container Dumpdir; do
            local active=""
            [ "$s" = "$current_scenario" ] && active="border-b-2 border-blue-500 text-blue-400" || active="text-gray-400 hover:text-gray-200"
            scenario_bar+="<a href='../$s/report.html' class='px-6 py-3 font-medium transition-colors $active'>$s</a>"
        done
        scenario_bar+="</div>"
    fi

    cat <<EOF > "$target_dir/report.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MySQLTuner Report - $name ($current_scenario)</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen font-sans">
    <div class="max-w-6xl mx-auto px-4 py-8">
        <header class="flex justify-between items-center mb-10 border-b border-gray-700 pb-6">
            <div>
                <h1 class="text-4xl font-extrabold text-blue-500 tracking-tight">MySQLTuner <span class="text-white">Lab</span></h1>
                <p class="text-gray-400 mt-2">Target: <span class="font-mono text-blue-400">$name</span> | Mode: <span class="text-yellow-400 uppercase">$MODE</span></p>
            </div>
            <div class="text-right">
                <div class="text-sm text-gray-400">$(date)</div>
                <div class="font-medium text-xs text-gray-500">$DATE_TAG</div>
            </div>
        </header>

        $scenario_bar

        <!-- Summary Statistics -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-10">
            <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-xl">
                <div class="text-gray-400 text-sm mb-1"><i class="fas fa-check-circle mr-2"></i>Status</div>
                <div class="text-2xl font-bold $( [ $ret_code -eq 0 ] && echo "text-green-500" || echo "text-red-500" )">
                    $( [ $ret_code -eq 0 ] && echo "SUCCESS" || echo "FAILED ($ret_code)" )
                </div>
            </div>
            <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-xl">
                <div class="text-gray-400 text-sm mb-1"><i class="fas fa-bolt mr-2"></i>Runtime</div>
                <div class="text-2xl font-bold text-blue-400">${exec_time}s</div>
            </div>
            <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-xl overflow-hidden">
                <div class="text-gray-400 text-sm mb-1"><i class="fas fa-database mr-2"></i>Version</div>
                <div class="text-lg font-bold truncate" title="$db_version">$db_version</div>
            </div>
            <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-xl">
                <div class="text-gray-400 text-sm mb-1"><i class="fas fa-layer-group mr-2"></i>Databases</div>
                <div class="text-lg font-bold text-purple-400">$(echo "$db_list" | wc -w) DBs</div>
            </div>
        </div>

        <div class="space-y-8">
            <!-- Environment Details -->
            <section class="bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden">
                <div class="bg-gray-700 px-6 py-4">
                    <h2 class="text-lg font-semibold flex items-center"><i class="fas fa-info-circle mr-3 text-yellow-400"></i>Environment Details</h2>
                </div>
                <div class="p-6">
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                        <div>
                            <h3 class="text-sm font-bold text-gray-400 mb-3 uppercase tracking-wider">Database List</h3>
                            <div class="flex flex-wrap gap-2">
                                $(echo "$db_list" | while read db; do echo "<span class='bg-gray-700 px-3 py-1 rounded-full text-xs'>$db</span>"; done)
                            </div>
                        </div>
                        <div>
                            <h3 class="text-sm font-bold text-gray-400 mb-3 uppercase tracking-wider">Parameters</h3>
                            <ul class="text-sm space-y-1 text-gray-300">
                                <li>Mode: <span class="text-blue-400">$MODE</span></li>
                                <li>Scenario: <span class="text-blue-400">$current_scenario</span></li>
                                <li>Database: <span class="text-blue-400">${TARGET_DB:-"All"}</span></li>
                                <li>Force RAM: <span class="text-blue-400">${FORCEMEM_VAL:-"Auto"}</span></li>
                            </ul>
                        </div>
                    </div>
                </div>
            </section>

            <!-- Test Reproduction Scripts -->
            <section class='bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden'>
                <div class='bg-gray-700 px-6 py-4'>
                    <h2 class='text-lg font-semibold flex items-center'><i class='fas fa-redo mr-3 text-green-400'></i>Reproduce Test</h2>
                </div>
                <div class='p-6'>
                    <h3 class='text-sm font-bold text-gray-400 mb-3 uppercase tracking-wider'>Command Sequence</h3>
                    <pre class='bg-gray-950 p-4 rounded-lg overflow-x-auto text-xs font-mono text-green-400 whitespace-pre-wrap'>$repro_cmds</pre>
                </div>
            </section>

            <!-- Infrastructure Logs -->
            $infra_sections

            <!-- Audit Logs (Pt-summary, Innotop etc) -->
            $audit_html

            <!-- MySQLTuner Core Output (At the bottom) -->
            $(render_panel "mysqltuner_output.txt" "MySQLTuner Output" "fa-terminal" "text-blue-400" "$mt_output" "execution.log")
        </div>

        <footer class="mt-12 text-center text-gray-500 text-xs border-t border-gray-800 pt-8">
            <p>Generated by MySQLTuner Laboratory Suite</p>
            <p class="mt-1">&copy; 2026 - Project MySQLTuner-perl</p>
        </footer>
    </div>
</body>
</html>
EOF
}


run_audit_tools() {
    local target_dir=$1
    log_step "Running complementary audit tools..."
    
    case "$MODE" in
        remote)
            ssh $SSH_OPTIONS "root@$REMOTE_HOST" "pt-summary" > "$target_dir/pt-summary.txt" 2>/dev/null
            ssh $SSH_OPTIONS "root@$REMOTE_HOST" "pt-mysql-summary" > "$target_dir/pt-mysql-summary.txt" 2>/dev/null
            ssh $SSH_OPTIONS "root@$REMOTE_HOST" "innotop -C -d1 --count 5 -n" > "$target_dir/innotop.txt" 2>/dev/null
            ;;
        lab|container)
            # Try to run locally or in docker? For now just try local if available
            pt-summary > "$target_dir/pt-summary.txt" 2>/dev/null || rm "$target_dir/pt-summary.txt" 2>/dev/null
            pt-mysql-summary > "$target_dir/pt-mysql-summary.txt" 2>/dev/null || rm "$target_dir/pt-mysql-summary.txt" 2>/dev/null
            innotop -C -d1 --count 5 -n > "$target_dir/innotop.txt" 2>/dev/null || rm "$target_dir/innotop.txt" 2>/dev/null
            ;;
    esac
}

run_test_lab() {
    local config=$1
    local current_date=$(date +%Y%m%d_%H%M%S)
    local root_target_dir="$EXAMPLES_DIR/${current_date}_${config}"
    mkdir -p "$root_target_dir"

    log_header "Testing Lab: $config"
    
    cd "$VENDOR_DIR/multi-db-docker-env" || exit 1
    [ ! -f .env ] && echo "DB_ROOT_PASSWORD=mysqltuner_test" > .env
    
    log_step "Starting container..."
    # Capture docker start log at config level
    make "$config" > "$root_target_dir/docker_start.log" 2>&1 || { log_step "FAILED: Container startup"; exit 1; }
    sleep 30

    log_step "Injecting sample data..."
    export MYSQL_HOST=127.0.0.1
    export MYSQL_TCP_PORT=3306
    export MYSQL_USER=root
    export MYSQL_PWD=mysqltuner_test
    
    find "$VENDOR_DIR/test_db" -name "employees.sql" -exec sh -c 'cd $(dirname {}) && mysql -h 127.0.0.1 -u root -pmysqltuner_test < $(basename {})' \; > "$root_target_dir/db_injection.log" 2>&1 || { log_step "WARNING: Data injection had issues"; }

    db_version=$(mysql -h 127.0.0.1 -u root -pmysqltuner_test -e "SELECT VERSION();" -sN 2>/dev/null)
    db_list=$(mysql -h 127.0.0.1 -u root -pmysqltuner_test -e "SHOW DATABASES;" -sN 2>/dev/null)
    # Detect the actual container name (excluding traefik)
    local container_name=$(docker ps --format '{{.Names}}' | grep -v "traefik" | head -n 1)
    [ -z "$container_name" ] && container_name="$config"

    # Iterate over 3 scenarios
    for scenario in Standard Container Dumpdir; do
        log_step "Executing Scenario: $scenario..."
        local target_dir="$root_target_dir/$scenario"
        mkdir -p "$target_dir"
        
        # COPY common logs instead of symlinking for full portability
        cp "$root_target_dir/docker_start.log" "$target_dir/docker_start.log"
        cp "$root_target_dir/db_injection.log" "$target_dir/db_injection.log"
        
        start_time=$(date +%s)
        
        local db_param=""
        [ -n "$TARGET_DB" ] && db_param="--database $TARGET_DB"
        [ -n "$FORCEMEM_VAL" ] && db_param="$db_param --forcemem $FORCEMEM_VAL"
        
        # Use --noask to prevent hanging and --skippassword to avoid dictionary checks in lab
        local mt_opts="--noask --skippassword"
        
        case "$scenario" in
            Standard)
                perl "$PROJECT_ROOT/mysqltuner.pl" --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose $mt_opts --outputfile "$target_dir/mysqltuner_output.txt" > "$target_dir/execution.log" 2>&1
                local repro_cmds="perl mysqltuner.pl --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose"
                ;;
            Container)
                perl "$PROJECT_ROOT/mysqltuner.pl" --container docker:"$container_name" $db_param --verbose $mt_opts --outputfile "$target_dir/mysqltuner_output.txt" > "$target_dir/execution.log" 2>&1
                local repro_cmds="perl mysqltuner.pl --container docker:\"$container_name\" $db_param --verbose"
                docker logs "$container_name" > "$target_dir/container_logs.log" 2>&1
                docker inspect "$container_name" > "$target_dir/container_inspect.json" 2>/dev/null
                ;;
            Dumpdir)
                mkdir -p "$target_dir/dumps"
                perl "$PROJECT_ROOT/mysqltuner.pl" --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose --dumpdir="$target_dir/dumps" $mt_opts --outputfile "$target_dir/mysqltuner_output.txt" > "$target_dir/execution.log" 2>&1
                local repro_cmds="perl mysqltuner.pl --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose --dumpdir=dumps"
                ;;
        esac
        ret_code=$?

        # Robustness: Check if output exists, if not, grab it from execution.log as fallback
        [ ! -s "$target_dir/mysqltuner_output.txt" ] && cp "$target_dir/execution.log" "$target_dir/mysqltuner_output.txt"
        
        [ "$DO_AUDIT" = true ] && run_audit_tools "$target_dir"
        
        end_time=$(date +%s)
        
        # Full reproduction procedure listed in Standard only or per scenario
        local full_repro="# 1. Setup Vendor Repositories
mkdir -p vendor
git clone $MULTI_DB_REPO vendor/multi-db-docker-env
git clone $TEST_DB_REPO vendor/test_db

# 2. Start Container
cd vendor/multi-db-docker-env
[ ! -f .env ] && echo \"DB_ROOT_PASSWORD=mysqltuner_test\" > .env
make $config

# 3. Inject Sample Data
cd \$PROJECT_ROOT
find \"vendor/test_db\" -name \"employees.sql\" -exec sh -c 'cd \$(dirname {}) && mysql -h 127.0.0.1 -u root -pmysqltuner_test < \$(basename {})' \\;

# 4. Execute Scenario: $scenario
$repro_cmds"

        generate_report "$target_dir" "$config" "$ret_code" "$((end_time - start_time))" "$db_version" "$db_list" "$full_repro" "$scenario"
    done

    # Create a redirect index at config root
    echo "<html><head><meta http-equiv='refresh' content='0; url=Standard/report.html'></head></html>" > "$root_target_dir/report.html"

    log_step "Stopping container..."
    make stop >> "$root_target_dir/docker_start.log" 2>&1
    cd "$PROJECT_ROOT"
}


run_test_container() {
    local container=$1
    local target_dir="$EXAMPLES_DIR/${DATE_TAG}_container_${container}"
    mkdir -p "$target_dir"

    log_header "Container Test: $container"
    start_time=$(date +%s)

    log_step "Executing MySQLTuner against container..."
    local db_param=""
    [ -n "$TARGET_DB" ] && db_param="--database $TARGET_DB"
    [ -n "$FORCEMEM_VAL" ] && db_param="$db_param --forcemem $FORCEMEM_VAL"

    perl mysqltuner.pl --container docker:"$container" $db_param --verbose --outputfile "$target_dir/mysqltuner_output.txt" > "$target_dir/execution.log" 2>&1
    ret_code=$?

    log_step "Capturing container logs and inspection data..."
    docker logs "$container" > "$target_dir/container_logs.log" 2>&1
    docker inspect "$container" > "$target_dir/container_inspect.json" 2>/dev/null

    [ "$DO_AUDIT" = true ] && run_audit_tools "$target_dir"

    # Try to get DB info via container exec
    db_version=$(docker exec "$container" mysql -u root -e "SELECT VERSION();" -sN 2>/dev/null || echo "Unknown")
    db_list=$(docker exec "$container" mysql -u root -e "SHOW DATABASES;" -sN 2>/dev/null || echo "Unknown")

    end_time=$(date +%s)
    
    local repro_cmds="# Execute MySQLTuner against existing container
perl mysqltuner.pl --container docker:\"$container\" $db_param --verbose"

    generate_report "$target_dir" "container:$container" "$ret_code" "$((end_time - start_time))" "$db_version" "$db_list" "$repro_cmds"
}

run_test_remote() {
    local host=$1
    local target_dir="$EXAMPLES_DIR/${DATE_TAG}_remote_${host}"
    mkdir -p "$target_dir"

    log_header "Remote Audit: $host"
    start_time=$(date +%s)

    log_step "Transferring MySQLTuner to remote..."
    scp $SSH_OPTIONS mysqltuner.pl "root@$host:/tmp/mysqltuner.pl" > /dev/null

    log_step "Executing MySQLTuner on remote..."
    local db_param=""
    [ -n "$TARGET_DB" ] && db_param="--database $TARGET_DB"
    [ -n "$FORCEMEM_VAL" ] && db_param="$db_param --forcemem $FORCEMEM_VAL"

    ssh $SSH_OPTIONS "root@$host" "perl /tmp/mysqltuner.pl $db_param --verbose" > "$target_dir/mysqltuner_output.txt" 2>&1
    ret_code=$?
    cat "$target_dir/mysqltuner_output.txt" > "$target_dir/execution.log"

    [ "$DO_AUDIT" = true ] && run_audit_tools "$target_dir"

    db_version=$(ssh $SSH_OPTIONS "root@$host" "mysql -e 'SELECT VERSION();' -sN" 2>/dev/null || echo "Unknown")
    db_list=$(ssh $SSH_OPTIONS "root@$host" "mysql -e 'SHOW DATABASES;' -sN" 2>/dev/null || echo "Unknown")

    end_time=$(date +%s)
    
    local repro_cmds="# 1. Transfer MySQLTuner to remote
scp mysqltuner.pl \"root@$host:/tmp/mysqltuner.pl\"

# 2. Execute MySQLTuner on remote
ssh \"root@$host\" \"perl /tmp/mysqltuner.pl $db_param --verbose\""

    generate_report "$target_dir" "remote:$host" "$ret_code" "$((end_time - start_time))" "$db_version" "$db_list" "$repro_cmds"
}

# Main Execution Flow
case "$MODE" in
    lab)
        setup_vendor
        for config in $CONFIGS; do
            run_test_lab "$config"
        done
        ;;
    container)
        run_test_container "$EXISTING_CONTAINER"
        ;;
    remote)
        run_test_remote "$REMOTE_HOST"
        ;;
    cleanup)
        cleanup_examples
        exit 0
        ;;
esac

# Always cleanup at the end of a successful run
cleanup_examples

echo ""
log_step "All tasks completed. Reports available in $EXAMPLES_DIR"
