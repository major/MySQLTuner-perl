#!/bin/bash
# ==================================================================================
# Script: test_envs.sh
# Description: Runs MySQLTuner tests against multiple database configurations.
# Author: Jean-Marie Renouard
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

# Default configurations to test if none provided
DEFAULT_CONFIGS="mysql84 mariadb1011 percona80"
CONFIGS=""
TARGET_DB=""

show_usage() {
    echo "Usage: $0 [options] [configs...]"
    echo "Options:"
    echo "  -c, --configs \"list\"   List of configurations to test (e.g. \"mysql84 mariadb1011\")"
    echo "  -d, --database name    Target database name for MySQLTuner to tune"
    echo "  -h, --help             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 mysql84 mariadb106"
    echo "  $0 -d employees mysql84"
    echo "  $0 --configs \"percona80\" --database my_app_db"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--configs)
            CONFIGS="$CONFIGS $2"
            shift 2
            ;;
        -d|--database)
            TARGET_DB="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            CONFIGS="$CONFIGS $1"
            shift
            ;;
    esac
done

# Fallback to defaults if no configs provided
if [ -z "$(echo $CONFIGS | xargs)" ]; then
    CONFIGS=$DEFAULT_CONFIGS
fi

log_step() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

echo "======================================================================"
echo "MySQLTuner Test Suite - $(date)"
echo "Command: $0 $*"
echo "======================================================================"

mkdir -p "$EXAMPLES_DIR"
mkdir -p "$VENDOR_DIR"

# Setup Vendor Repositories
setup_vendor() {
    echo "--- Setting up vendor repositories ---"
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

# Run test for a specific configuration
run_test() {
    local config=$1
    local current_date=$(date +%Y%m%d_%H%M%S)
    local target_dir="$PROJECT_ROOT/examples/${current_date}_${config}"
    
    mkdir -p "$target_dir"
    if [ ! -d "$target_dir" ]; then
        echo "Error: Could not create target directory $target_dir"
        return 1
    fi

    echo "=== Testing configuration: $config ==="
    echo "Results will be stored in: $target_dir"
    
    cd "$VENDOR_DIR/multi-db-docker-env" || { echo "Error: multi-db-docker-env not found"; return 1; }
    
    # Ensure .env exists with default password
    if [ ! -f .env ]; then
        echo "DB_ROOT_PASSWORD=mysqltuner_test" > .env
    fi

    # Start the DB
    log_step "Starting database container for $config..."
    start_time=$(date +%s)
    {
        echo "--- Start: $(date) ---"
        echo "Command: make $config"
        make "$config" 2>&1
        echo "===================="
    } > "$target_dir/docker_start.log"
    
    # Wait for DB to be ready
    log_step "Waiting for DB to be healthy (30s)..."
    sleep 30
    
    # Inject test data
    log_step "Injecting employees database..."
    if [ -d "$VENDOR_DIR/test_db" ]; then
        cd "$VENDOR_DIR/test_db"
        export MYSQL_HOST=127.0.0.1
        export MYSQL_TCP_PORT=3306
        export MYSQL_USER=root
        export MYSQL_PWD=mysqltuner_test
        
        {
            echo "--- Start: $(date) ---"
            if [ -f "employees.sql" ]; then
                echo "Command: cd employees && mysql -h $MYSQL_HOST -u $MYSQL_USER -p\$MYSQL_PWD < employees.sql"
                cd employees && mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PWD" < employees.sql && cd ..
            else
                echo "Command: searching for employees.sql and injecting"
                find . -name "employees.sql" -print0 | while IFS= read -r -d '' sql_file; do
                    sql_dir=$(dirname "$sql_file")
                    sql_base=$(basename "$sql_file")
                    echo "Injecting: $sql_file"
                    (cd "$sql_dir" && mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PWD" < "$sql_base")
                done
            fi
            echo "===================="
        } > "$target_dir/db_injection.log" 2>&1
        cd "$VENDOR_DIR/multi-db-docker-env"
    else
        echo "Warning: test_db repository not found. Skipping employees injection."
    fi
    
    cd "$PROJECT_ROOT"
    
    # Run MySQLTuner
    log_step "Running MySQLTuner..."
    local db_param=""
    if [ -n "$TARGET_DB" ]; then
        db_param="--database $TARGET_DB"
        echo "Tuning specific database: $TARGET_DB"
    fi
    
    {
        echo "--- Start: $(date) ---"
        echo "Command: perl mysqltuner.pl --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose --outputfile $target_dir/mysqltuner_output.txt"
        perl mysqltuner.pl --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose --outputfile "$target_dir/mysqltuner_output.txt"
        echo "===================="
    } > "$target_dir/execution.log" 2>&1
    ret_code=$?
    
    # Capture more info
    log_step "Capturing environment snapshots..."
    docker_stats=$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}")
    db_version=$(mysql -h 127.0.0.1 -u root -pmysqltuner_test -e "SELECT VERSION();" -sN 2>/dev/null || echo "Unknown")
    db_list=$(mysql -h 127.0.0.1 -u root -pmysqltuner_test -e "SHOW DATABASES;" -sN 2>/dev/null || echo "Could not list databases")
    
    end_time=$(date +%s)
    exec_time=$((end_time - start_time))

    # Compile text report
    log_step "Generating text report..."
    {
        echo "Configuration: $config"
        [ -n "$TARGET_DB" ] && echo "Target Database: $TARGET_DB"
        echo "Database Version: $db_version"
        echo "Date: $(date)"
        echo "Return Code: $ret_code"
        echo "Execution Time: ${exec_time}s"
        echo "Environment: Docker via multi-db-docker-env"
        echo "----------------------------------------"
        echo "Databases:"
        echo "$db_list"
        echo "----------------------------------------"
        echo "Docker Stats:"
        echo "$docker_stats"
    } > "$target_dir/report.txt"

    # Prepare HTML content
    log_step "Generating HTML report..."
    mt_output=$(cat "$target_dir/mysqltuner_output.txt" 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' || echo "No MySQLTuner output captured.")
    
    # Generate HTML report
    cat <<EOF > "$target_dir/report.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MySQLTuner Test Report - $config</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen font-sans">
    <div class="max-w-6xl mx-auto px-4 py-8">
        <header class="flex justify-between items-center mb-10 border-b border-gray-700 pb-6">
            <div>
                <h1 class="text-4xl font-extrabold text-blue-500 tracking-tight">MySQLTuner <span class="text-white">Report</span></h1>
                <p class="text-gray-400 mt-2">Configuration: <span class="font-mono text-blue-400">$config</span> $( [ -n "$TARGET_DB" ] && echo "| Target DB: <span class='font-mono text-yellow-400'>$TARGET_DB</span>" )</p>
            </div>
            <div class="text-right">
                <div class="text-sm text-gray-400">Tested on</div>
                <div class="font-medium">$(date)</div>
            </div>
        </header>

        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-10">
            <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-xl">
                <div class="text-gray-400 text-sm mb-1"><i class="fas fa-microchip mr-2"></i>Status</div>
                <div class="text-2xl font-bold $( [ $ret_code -eq 0 ] && echo "text-green-500" || echo "text-red-500" )">
                    $( [ $ret_code -eq 0 ] && echo "SUCCESS" || echo "FAILED ($ret_code)" )
                </div>
            </div>
            <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-xl">
                <div class="text-gray-400 text-sm mb-1"><i class="fas fa-clock mr-2"></i>Runtime</div>
                <div class="text-2xl font-bold text-blue-400">${exec_time}s</div>
            </div>
            <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-xl">
                <div class="text-gray-400 text-sm mb-1"><i class="fas fa-database mr-2"></i>DB Version</div>
                <div class="text-lg font-bold truncate" title="$db_version">$db_version</div>
            </div>
            <div class="bg-gray-800 p-6 rounded-xl border border-gray-700 shadow-xl">
                <div class="text-gray-400 text-sm mb-1"><i class="fas fa-server mr-2"></i>Platform</div>
                <div class="text-lg font-bold text-purple-400">Docker Manager</div>
            </div>
        </div>

        <div class="space-y-8">
            <section class="bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden">
                <div class="bg-gray-700 px-6 py-4 flex justify-between items-center">
                    <h2 class="text-lg font-semibold flex items-center"><i class="fas fa-terminal mr-3 text-blue-400"></i>MySQLTuner Output</h2>
                    <a href="mysqltuner_output.txt" class="text-sm text-blue-400 hover:text-blue-300 transition-colors">View Raw</a>
                </div>
                <div class="p-6">
                    <pre class="bg-gray-950 p-4 rounded-lg overflow-x-auto text-sm font-mono text-gray-300 whitespace-pre-wrap">$mt_output</pre>
                </div>
            </section>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
                <section class="bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden">
                    <div class="bg-gray-700 px-6 py-4">
                        <h2 class="text-lg font-semibold flex items-center"><i class="fas fa-chart-line mr-3 text-green-400"></i>Environment Snapshot</h2>
                    </div>
                    <div class="p-6">
                        <h3 class="text-sm font-bold text-gray-400 mb-3 uppercase tracking-wider">Docker Container Stats</h3>
                        <pre class="bg-gray-950 p-4 rounded-lg text-xs font-mono text-green-400 overflow-x-auto">$docker_stats</pre>
                        
                        <h3 class="text-sm font-bold text-gray-400 mt-6 mb-3 uppercase tracking-wider">Databases Found</h3>
                        <div class="flex flex-wrap gap-2">
                            $(echo "$db_list" | while read db; do echo "<span class='bg-gray-700 px-3 py-1 rounded-full text-xs'>$db</span>"; done)
                        </div>
                    </div>
                </section>

                <section class="bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden">
                    <div class="bg-gray-700 px-6 py-4">
                        <h2 class="text-lg font-semibold flex items-center"><i class="fas fa-list-check mr-3 text-yellow-400"></i>Debug & Logs</h2>
                    </div>
                    <div class="p-6 space-y-4">
                        <a href="execution.log" class="block bg-gray-700 hover:bg-gray-600 p-4 rounded-lg transition-colors group">
                            <div class="flex justify-between items-center">
                                <div>
                                    <h3 class="font-bold group-hover:text-blue-400 transition-colors">Execution Log</h3>
                                    <p class="text-sm text-gray-400">Standard output and error from the test run.</p>
                                </div>
                                <i class="fas fa-chevron-right text-gray-500"></i>
                            </div>
                        </a>
                        <a href="docker_start.log" class="block bg-gray-700 hover:bg-gray-600 p-4 rounded-lg transition-colors group">
                            <div class="flex justify-between items-center">
                                <div>
                                    <h3 class="font-bold group-hover:text-blue-400 transition-colors">Docker Lifecycle</h3>
                                    <p class="text-sm text-gray-400">Logs from container start and stop operations.</p>
                                </div>
                                <i class="fas fa-chevron-right text-gray-500"></i>
                            </div>
                        </a>
                        <a href="db_injection.log" class="block bg-gray-700 hover:bg-gray-600 p-4 rounded-lg transition-colors group">
                            <div class="flex justify-between items-center">
                                <div>
                                    <h3 class="font-bold group-hover:text-blue-400 transition-colors">Database Injection</h3>
                                    <p class="text-sm text-gray-400">Logs from employees database injection.</p>
                                </div>
                                <i class="fas fa-chevron-right text-gray-500"></i>
                            </div>
                        </a>
                    </div>
                </section>
            </div>
        </div>

        <footer class="mt-12 text-center text-gray-500 text-sm border-t border-gray-800 pt-8">
            <p>Generated by MySQLTuner Automation Suite</p>
            <p class="mt-1">&copy; 2026 - Jean-Marie Renouard</p>
        </footer>
    </div>
</body>
</html>
EOF

    # Stop the DB
    log_step "Cleaning up and stopping container..."
    cd "$VENDOR_DIR/multi-db-docker-env" || return 1
    {
        echo "--- Stop: $(date) ---"
        echo "Command: make stop"
        make stop 2>&1
        echo "===================="
    } >> "$target_dir/docker_start.log"
    
    echo "Done with $config. Results in $target_dir"
}

setup_vendor

for config in $CONFIGS; do
    run_test "$config"
done

echo "All tests completed."
