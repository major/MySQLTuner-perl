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
CVE_FILE="$PROJECT_ROOT/vulnerabilities.csv"
# log_step moved below declaration

# Dependencies
MULTI_DB_REPO="https://github.com/jmrenouard/multi-db-docker-env"
TEST_DB_REPO="https://github.com/jmrenouard/test_db"

# Default configurations
get_supported_versions() {
    local type=$1
    local file="$PROJECT_ROOT/${type}_support.md"
    if [ -f "$file" ]; then
        grep "| Supported |" "$file" | awk -v t="$type" -F'|' '{gsub(/ /, "", $2); gsub(/\./, "", $2); print t$2}' | xargs
    fi
}

MYSQL_SUPPORTED=$(get_supported_versions "mysql")
MARIADB_SUPPORTED=$(get_supported_versions "mariadb")
DEFAULT_CONFIGS="$MYSQL_SUPPORTED $MARIADB_SUPPORTED percona80"

CONFIGS=""
TARGET_DB=""
FORCEMEM_VAL=""
MODE="lab" # Modes: lab, container, remote
EXISTING_CONTAINER=""
REMOTE_HOST=""
SSH_OPTIONS="-q -o TCPKeepAlive=yes -o ServerAliveInterval=50 -o strictHostKeyChecking=no"
DO_AUDIT=false
KEEP_ALIVE=false
NO_INJECTION=false

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
    echo "  -k, --keep-alive          Keep laboratory containers running after tests"
    echo "  -n, --no-injection         Skip database data injection phase"
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
        -k|--keep-alive)
            KEEP_ALIVE=true
            shift
            ;;
        -n|--no-injection)
            NO_INJECTION=true
            shift
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

# Helper to check exit code and log to execution.log
check_exit_code() {
    local ret=$1
    local msg=$2
    local log=$3
    local output_file=$4
    if [ $ret -ne 0 ]; then
        log_step "WARNING: $msg (Exit code: $ret)"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $msg failed with exit code $ret" >> "$log"
        return $ret
    fi
    # If output_file is provided, check for "Terminated successfully"
    if [ -n "$output_file" ]; then
        if [ ! -f "$output_file" ] || ! grep -q "Terminated successfully" "$output_file"; then
             log_step "WARNING: $msg (Missing or incomplete output)"
             echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $msg failed (Missing or incomplete output)" >> "$log"
             return 254
        fi
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $msg" >> "$log"
    return 0
}

# Generate unified HTML report
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
    local duration_startup=${9:-0}
    local duration_ready=${10:-0}
    local duration_inject=${11:-0}
    local db_total_rows=${12:-0}
    local db_total_size=${13:-0}

    log_step "Generating consolidated HTML report for $name ($current_scenario)..."
    
    local mt_output=$(cat "$target_dir/mysqltuner_output.txt" 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' || echo "No output.")
    
    # helper for panels
    render_panel() {
        local file=$1; local title=$2; local icon=$3; local color=$4; local content=$5; local log_file=$6; local open=${7:-""}
        [ -z "$content" ] && [ -f "$target_dir/$file" ] && content=$(cat "$target_dir/$file" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        [ -z "$content" ] && return
        
        local links="<a href='$file' class='text-xs text-blue-400 hover:text-blue-300 transition-colors'>Raw</a>"
        [ -n "$log_file" ] && [ -f "$target_dir/$log_file" ] && links+="<span class='mx-2 text-gray-600'>|</span><a href='$log_file' class='text-xs text-gray-400 hover:text-gray-300 transition-colors'>Log</a>"

        echo "<section class='bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden mb-8'>
            <details $open class='group'>
                <summary class='bg-gray-700 px-6 py-4 flex justify-between items-center cursor-pointer list-none'>
                    <h2 class='text-lg font-semibold flex items-center'>
                        <i class='fas fa-chevron-right mr-3 text-gray-500 transition-transform group-open:rotate-90'></i>
                        <i class='fas $icon mr-3 $color'></i>$title
                    </h2>
                    <div class='flex items-center'>$links</div>
                </summary>
                <div class='p-6 border-t border-gray-700'>
                    <pre class='bg-gray-950 p-4 rounded-lg overflow-x-auto text-xs font-mono text-gray-400 max-h-96 overflow-y-auto'>$content</pre>
                </div>
            </details>
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
        for s in Standard Container Dumpdir Schemadir; do
            local active=""
            [ "$s" = "$current_scenario" ] && active="border-b-2 border-blue-500 text-blue-400" || active="text-gray-400 hover:text-gray-200"
            scenario_bar+="<a href='../$s/report.html' class='px-6 py-3 font-medium transition-colors $active'>$s</a>"
        done
        scenario_bar+="</div>"
    fi

    # Scenario Descriptions
    local scenario_desc=""
    case "$current_scenario" in
        Standard)
            scenario_desc="Performs local network connection auditing using standard TCP/IP transport (loopback) to query database engine metrics, system status variables, and global performance indicators."
            ;;
        Container)
            scenario_desc="Audits system configurations using native container socket transport (e.g. docker:container_name), skipping local TCP connections to inspect runtime environment contexts directly from the host system."
            ;;
        Dumpdir)
            scenario_desc="Executes off-line schema and configuration analysis by exporting status variables and system variables to a temporary dump directory, validating remote auditing capabilities without a live database connection."
            ;;
        Schemadir)
            scenario_desc="Performs structural modeling schema audits, analyzing table designs, constraints, indexes, data types, and naming conventions by dumping schema layouts without querying full datasets."
            ;;
        *)
            scenario_desc="Custom audit scenario execution."
            ;;
    esac

    local desc_html=""
    if [ -n "$current_scenario" ]; then
        desc_html="<div class='bg-blue-950/40 border-l-4 border-blue-500 p-4 rounded-r-xl mb-8 shadow-md'>
            <h3 class='text-sm font-semibold text-blue-400 uppercase tracking-wider mb-1'>Scenario Description: $current_scenario</h3>
            <p class='text-gray-300 text-sm'>$scenario_desc</p>
        </div>"
    fi

    # Step Breakdown / Execution Timeline HTML
    local total_time ratio_startup ratio_ready ratio_inject ratio_tuner breakdown_html=""
    if [ "$duration_startup" -gt 0 ] || [ "$duration_ready" -gt 0 ] || [ "$duration_inject" -gt 0 ]; then
        total_time=$((duration_startup + duration_ready + duration_inject + exec_time))
        [ $total_time -eq 0 ] && total_time=1
        ratio_startup=$((duration_startup * 100 / total_time))
        ratio_ready=$((duration_ready * 100 / total_time))
        ratio_inject=$((duration_inject * 100 / total_time))
        ratio_tuner=$((exec_time * 100 / total_time))

        breakdown_html="<section class='bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden mb-10'>
            <div class='bg-gray-700 px-6 py-4'>
                <h2 class='text-lg font-semibold flex items-center'>
                    <i class='fas fa-clock mr-3 text-blue-400'></i>Execution Timeline &amp; Step Breakdown
                </h2>
            </div>
            <div class='p-6 space-y-6'>
                <div class='w-full bg-gray-950 rounded-full h-4 flex overflow-hidden'>"
        [ $duration_startup -gt 0 ] && breakdown_html+="<div class='bg-orange-500 h-full transition-all duration-500' style='width: ${ratio_startup}%' title='Startup: ${duration_startup}s (${ratio_startup}%)'></div>"
        [ $duration_ready -gt 0 ] && breakdown_html+="<div class='bg-yellow-500 h-full transition-all duration-500' style='width: ${ratio_ready}%' title='Readiness Check: ${duration_ready}s (${ratio_ready}%)'></div>"
        [ $duration_inject -gt 0 ] && breakdown_html+="<div class='bg-green-500 h-full transition-all duration-500' style='width: ${ratio_inject}%' title='Data Injection: ${duration_inject}s (${ratio_inject}%)'></div>"
        [ $exec_time -gt 0 ] && breakdown_html+="<div class='bg-blue-500 h-full transition-all duration-500' style='width: ${ratio_tuner}%' title='MySQLTuner: ${exec_time}s (${ratio_tuner}%)'></div>"
        breakdown_html+="</div>

                <div class='grid grid-cols-1 md:grid-cols-4 gap-6'>
                    <div class='space-y-2'>
                        <div class='flex justify-between items-center text-sm'>
                            <span class='font-medium text-gray-300 flex items-center'>
                                <span class='w-3 h-3 rounded-full bg-orange-500 mr-2'></span>Container Startup
                            </span>
                            <span class='font-mono text-gray-400'>${duration_startup}s (${ratio_startup}%)</span>
                        </div>
                        <div class='w-full bg-gray-900 rounded-full h-1.5'>
                            <div class='bg-orange-500 h-1.5 rounded-full' style='width: ${ratio_startup}%'></div>
                        </div>
                    </div>
                    <div class='space-y-2'>
                        <div class='flex justify-between items-center text-sm'>
                            <span class='font-medium text-gray-300 flex items-center'>
                                <span class='w-3 h-3 rounded-full bg-yellow-500 mr-2'></span>Readiness Check
                            </span>
                            <span class='font-mono text-gray-400'>${duration_ready}s (${ratio_ready}%)</span>
                        </div>
                        <div class='w-full bg-gray-900 rounded-full h-1.5'>
                            <div class='bg-yellow-500 h-1.5 rounded-full' style='width: ${ratio_ready}%'></div>
                        </div>
                    </div>
                    <div class='space-y-2'>
                        <div class='flex justify-between items-center text-sm'>
                            <span class='font-medium text-gray-300 flex items-center'>
                                <span class='w-3 h-3 rounded-full bg-green-500 mr-2'></span>Data Injection
                            </span>
                            <span class='font-mono text-gray-400'>${duration_inject}s (${ratio_inject}%)</span>
                        </div>
                        <div class='w-full bg-gray-900 rounded-full h-1.5'>
                            <div class='bg-green-500 h-1.5 rounded-full' style='width: ${ratio_inject}%'></div>
                        </div>
                    </div>
                    <div class='space-y-2'>
                        <div class='flex justify-between items-center text-sm'>
                            <span class='font-medium text-gray-300 flex items-center'>
                                <span class='w-3 h-3 rounded-full bg-blue-500 mr-2'></span>MySQLTuner Run
                            </span>
                            <span class='font-mono text-gray-400'>${exec_time}s (${ratio_tuner}%)</span>
                        </div>
                        <div class='w-full bg-gray-900 rounded-full h-1.5'>
                            <div class='bg-blue-500 h-1.5 rounded-full' style='width: ${ratio_tuner}%'></div>
                        </div>
                    </div>
                </div>
            </div>
        </section>"
    fi
    # Run log audit
    local audit_status_icon="<span class='text-green-500 mr-2'><i class='fas fa-check-circle'></i></span>"
    local audit_status_text="No anomalies or execution errors detected during MySQLTuner runtime."
    local audit_status_class="border-green-500 bg-green-950/20 text-green-400"
    local has_errors=false

    # Check for Performance Schema Disabled
    local err_ps=$(grep -i "Performance_schema should be activated" "$target_dir/execution.log" "$target_dir/mysqltuner_output.txt" 2>/dev/null)
    # Check for SQL Execution Failure
    local err_sql=$(grep -i "FAIL Execute SQL" "$target_dir/execution.log" "$target_dir/mysqltuner_output.txt" 2>/dev/null)
    # Check for Syntax Anomaly
    local err_syntax=$(grep -i -E "Syntax error|unexpected" "$target_dir/execution.log" "$target_dir/mysqltuner_output.txt" 2>/dev/null)
    # Check for Perl Warnings
    local err_perl=$(grep -i -E "uninitialized value|deprecated" "$target_dir/execution.log" "$target_dir/mysqltuner_output.txt" 2>/dev/null | grep -v -i -E "✔|\[OK\]|uses DEPRECATED|uses DISABLED")

    local err_list=""
    if [ -n "$err_ps" ]; then
        has_errors=true
        err_list+="<div class='text-red-400 font-semibold mb-1'>[Performance Schema Disabled]</div><pre class='bg-gray-950 p-3 rounded-lg text-xs font-mono text-gray-400 mb-4 overflow-x-auto whitespace-pre-wrap'>$err_ps</pre>"
    fi
    if [ -n "$err_sql" ]; then
        has_errors=true
        err_list+="<div class='text-red-400 font-semibold mb-1'>[SQL Execution Failure]</div><pre class='bg-gray-950 p-3 rounded-lg text-xs font-mono text-gray-400 mb-4 overflow-x-auto whitespace-pre-wrap'>$err_sql</pre>"
    fi
    if [ -n "$err_syntax" ]; then
        has_errors=true
        err_list+="<div class='text-red-400 font-semibold mb-1'>[Syntax Anomaly]</div><pre class='bg-gray-950 p-3 rounded-lg text-xs font-mono text-gray-400 mb-4 overflow-x-auto whitespace-pre-wrap'>$err_syntax</pre>"
    fi
    if [ -n "$err_perl" ]; then
        has_errors=true
        err_list+="<div class='text-red-400 font-semibold mb-1'>[Perl Warning / Deprecation]</div><pre class='bg-gray-950 p-3 rounded-lg text-xs font-mono text-gray-400 mb-4 overflow-x-auto whitespace-pre-wrap'>$err_perl</pre>"
    fi

    if [ "$has_errors" = true ]; then
        audit_status_icon="<span class='text-red-500 mr-2'><i class='fas fa-times-circle'></i></span>"
        audit_status_text="Anomalies or syntax warnings detected in MySQLTuner execution logs."
        audit_status_class="border-red-500 bg-red-950/20 text-red-400"
    fi

    local audit_log_panel="<section class='bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden mb-8'>
        <div class='bg-gray-700 px-6 py-4 flex justify-between items-center'>
            <h2 class='text-lg font-semibold flex items-center'>
                <i class='fas fa-shield-alt mr-3 text-cyan-400'></i>Runtime Audit &amp; Failure Analysis
            </h2>
        </div>
        <div class='p-6 space-y-4'>
            <div class='flex items-center border-l-4 p-4 rounded-r-lg $audit_status_class shadow-inner'>
                <span class='text-2xl flex items-center'>$audit_status_icon</span>
                <div class='ml-3'>
                    <p class='text-sm font-semibold'>$audit_status_text</p>
                </div>
            </div>"
    if [ "$has_errors" = true ]; then
        audit_log_panel+="<div class='mt-6 space-y-4'>
            <h3 class='text-sm font-bold text-gray-400 uppercase tracking-wider'>Detected Anomalies Log</h3>
            $err_list
        </div>"
    fi
    audit_log_panel+="</div>
    </section>"

    # Table of Produced Files
    local main_files_html=""
    local ps_files_html=""
    local ifs_files_html=""
    local sys_files_html=""

    add_file_row() {
        local path=$1; local label=$2; local desc=$3
        local full_path="$target_dir/$path"
        if [ ! -f "$full_path" ]; then
            # Check relative to base if not absolute
            full_path="$path"
        fi
        [ -f "$full_path" ] || return
        
        local row="<tr>
            <td class='px-6 py-4 whitespace-nowrap text-sm font-semibold text-blue-400'>
                <a href='$path' class='hover:underline flex flex-col'>
                    <span>$label</span>
                    <span class='text-[10px] text-gray-500 font-mono mt-0.5'>$(basename "$path")</span>
                </a>
            </td>
            <td class='px-6 py-4 text-sm text-gray-300'>$desc</td>
        </tr>"

        local base=$(basename "$path")
        if [[ "$base" =~ ^ps_ ]]; then
            ps_files_html+="$row"
        elif [[ "$base" =~ ^ifs_ ]]; then
            ifs_files_html+="$row"
        elif [[ "$base" =~ ^sys ]]; then
            sys_files_html+="$row"
        else
            main_files_html+="$row"
        fi
    }

    add_file_row "report.html" "HTML Report" "The consolidated interactive dashboard and timing report."
    add_file_row "mysqltuner_report.html" "MySQLTuner HTML Report" "The standalone HTML report generated by MySQLTuner."
    add_file_row "mysqltuner_output.txt" "MySQLTuner Raw Output" "The plain text output generated by MySQLTuner execution."
    add_file_row "execution.log" "Execution Log" "Standard output and standard error traces captured during the run."
    add_file_row "docker_start.log" "Docker Startup Log" "Logs from the Docker engine container startup."
    add_file_row "db_injection.log" "DB Injection Log" "Logs from the sample database employees schema and data import."
    add_file_row "container_logs.log" "Container Runtime Logs" "Standard output/error logs queried from the database container."
    add_file_row "container_inspect.json" "Container Metadata" "JSON metadata details retrieved from docker inspect."

    # Helper subroutine get_dynamic_desc in Perl
    local perl_desc_sub='
             sub get_dynamic_desc {
                 my ($f) = @_;
                 my $base = File::Basename::basename($f);
                 if (!-e $f) {
                     return "Snapshot file.";
                 }
                 
                 my $desc = "Snapshot file.";
                 if ($base =~ /^naming_convention_deviations\.csv(?:\.gz)?$/) {
                     $desc = "List of database schema tables and columns that violate naming conventions (e.g. plural names, case issues).";
                 }
                 elsif ($base =~ /^primary_key_issues\.csv(?:\.gz)?$/) {
                     $desc = "Audit report highlighting tables with missing, misnamed, or suboptimal surrogate primary keys.";
                 }
                 elsif ($base =~ /^missing_foreign_keys\.csv(?:\.gz)?$/) {
                     $desc = "List of table columns whose names suggest they should be foreign keys, but no foreign key constraints exist.";
                 }
                 elsif ($base =~ /^json_columns_without_virtual\.csv(?:\.gz)?$/) {
                     $desc = "Audit of JSON columns in the database that do not have associated virtual generated columns for indexing.";
                 }
                 elsif ($base =~ /^insecure_authentication_plugins\.csv(?:\.gz)?$/) {
                     $desc = "List of database user accounts configured with legacy or insecure authentication plugins.";
                 }
                 elsif ($base =~ /^ssl_issues\.csv(?:\.gz)?$/) {
                     $desc = "Security report detailing active SSL/TLS vulnerabilities or missing secure configurations.";
                 }
                 elsif ($base =~ /^user_with_general_wildcard\.csv(?:\.gz)?$/) {
                     $desc = "Accounts configured with a general wildcard host ('%'), which presents security risks.";
                 }
                 elsif ($base =~ /^columns_utf8\.csv(?:\.gz)?$/) {
                     $desc = "Inventory of table columns that correctly use UTF-8/UTF8MB4 character sets.";
                 }
                 elsif ($base =~ /^columns_non_utf8\.csv(?:\.gz)?$/) {
                     $desc = "Audit list of columns using legacy or non-UTF-8 character encodings (e.g. latin1).";
                 }
                 elsif ($base =~ /^fulltext_columns\.csv(?:\.gz)?$/) {
                     $desc = "List of columns that have full-text indexes configured.";
                 }
                 elsif ($base =~ /^non_mysqld_processes\.csv(?:\.gz)?$/) {
                     $desc = "List of running system processes not related to mysqld that are consuming CPU/RAM resources.";
                 }
                 elsif ($base =~ /^fragmented_tables\.csv(?:\.gz)?$/) {
                     $desc = "Tables with fragmented data space.";
                 }
                 elsif ($base =~ /^tables_non_innodb\.csv(?:\.gz)?$/) {
                     $desc = "Audit of database tables utilizing storage engines other than InnoDB.";
                 }
                 elsif ($base =~ /^tables_without_primary_keys\.csv(?:\.gz)?$/) {
                     $desc = "Audit list of tables lacking a primary key constraint.";
                 }
                 elsif ($base =~ /^raw_mysqltuner\.txt$/) {
                     $desc = "Plain text unformatted output captured from MySQLTuner execution.";
                 }
                 elsif ($base =~ /^ifs_(.*)\.csv(?:\.gz)?$/) {
                     my $table = $1;
                     $desc = "Information Schema table dump for INFORMATION_SCHEMA.$table.";
                 }
                 elsif ($base =~ /^ps_(.*)\.csv(?:\.gz)?$/) {
                     my $table = $1;
                     $desc = "Performance Schema table dump for performance_schema.$table.";
                 }
                 elsif ($base =~ /^sys_x\$(.*)\.csv(?:\.gz)?$/) {
                     my $table = $1;
                     $desc = "Sys Schema raw/unformatted table view for sys.x$$table.";
                 }
                 elsif ($base =~ /^sys_(.*)\.csv(?:\.gz)?$/) {
                     my $table = $1;
                     $desc = "Sys Schema table view for sys.$table.";
                 }
                 elsif ($base =~ /\.sql(?:\.gz)?$/) {
                     if (-z $f) {
                         $desc = "SQL database schema script.";
                     } else {
                         my @tables;
                         my $fh;
                         if ($f =~ /\.gz$/) {
                             open($fh, "gzip -dc \x27$f\x27 |") or $desc = "SQL script.";
                         } else {
                             open($fh, "<", $f) or $desc = "SQL script.";
                         }
                         if (defined $fh) {
                             my $lines_read = 0;
                             while (my $line = <$fh>) {
                                 if ($line =~ /CREATE TABLE\s+[`\x27\"]?(\w+)[`\x27\"]?/i) {
                                     push @tables, $1;
                                 }
                                 $lines_read++;
                                 last if @tables >= 5 || $lines_read > 500;
                             }
                             close($fh);
                             if (@tables) {
                                 my $t_list = join(", ", @tables);
                                 $desc = "SQL DDL schema definitions for tables: <strong>$t_list</strong>" . (scalar(@tables) >= 5 ? "..." : "") . ".";
                             } else {
                                 $desc = "SQL database schema script.";
                             }
                         }
                     }
                 }
                 elsif ($base =~ /\.md$/) {
                     if (-z $f) {
                         $desc = "Markdown documentation.";
                     } else {
                         my $fh;
                         if (open($fh, "<", $f)) {
                             my $header = <$fh>;
                             close($fh);
                             if ($header) {
                                 chomp($header);
                                 $header =~ s/^#+\s*//;
                                 $desc = "Markdown documentation: <strong>$header</strong>.";
                             } else {
                                 $desc = "Markdown documentation.";
                             }
                         } else {
                             $desc = "Markdown documentation.";
                         }
                     }
                 }
                 elsif ($base =~ /\.txt$/) {
                     $desc = "Configuration or metric metadata log.";
                 }
                 
                 if (-z $f) {
                     if ($base =~ /\.csv(?:\.gz)?$/) {
                         $desc .= " (Empty - no issues/records detected)";
                     } else {
                         $desc .= " (Empty)";
                     }
                 }
                 
                 return $desc;
             }
    '

    # Dynamically find and list all files in dumps/ if it exists
    if [ -d "$target_dir/dumps" ]; then
        while IFS='|' read -r rel_path label desc; do
            add_file_row "$rel_path" "$label" "$desc"
        done < <(perl -MFile::Basename -e '
            my $dir = shift;
            opendir(my $dh, $dir) or return;
            my @files = sort grep { -f "$dir/$_" } readdir($dh);
            closedir($dh);
            
            for my $base (@files) {
                my $file = "$dir/$base";
                next if $base eq "manifest.json" || $base eq "metadata.txt";
                
                my $rel_path = "dumps/$base";
                my $label = "MySQL Dump: $base";
                if ($base =~ /naming_convention_deviations\.csv/) {
                    $label = "Naming Conventions CSV";
                } elsif ($base =~ /primary_key_issues\.csv/) {
                    $label = "Primary Key Issues CSV";
                } elsif ($base =~ /missing_foreign_keys\.csv/) {
                    $label = "Missing Foreign Keys CSV";
                } elsif ($base =~ /json_columns_without_virtual\.csv/) {
                    $label = "JSON Virtual Columns CSV";
                }
                
                my $desc = get_dynamic_desc($file);
                print "$rel_path|$label|$desc\n";
            }
            '"$perl_desc_sub" "$target_dir/dumps")
    fi

    # Dynamically find and list all files in schemas/ if it exists
    if [ -d "$target_dir/schemas" ]; then
        while IFS='|' read -r rel_path label desc; do
            add_file_row "$rel_path" "$label" "$desc"
        done < <(perl -MFile::Basename -e '
            my $dir = shift;
            opendir(my $dh, $dir) or return;
            my @files = sort grep { -f "$dir/$_" } readdir($dh);
            closedir($dh);
            
            for my $base (@files) {
                my $file = "$dir/$base";
                my $rel_path = "schemas/$base";
                my $label = "Schema Layout: $base";
                
                my $desc = get_dynamic_desc($file);
                print "$rel_path|$label|$desc\n";
            }
            '"$perl_desc_sub" "$target_dir/schemas")
    fi

    # Helper function to render a table panel
    render_table_panel() {
        local title=$1; local icon=$2; local color=$3; local content=$4
        [ -z "$content" ] && return
        
        echo "<section class='bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden mb-8'>
            <div class='bg-gray-700 px-6 py-4 flex justify-between items-center'>
                <h2 class='text-lg font-semibold flex items-center'>
                    <i class='fas $icon mr-3 $color'></i>$title
                </h2>
            </div>
            <div class='p-6 overflow-x-auto'>
                <table class='min-w-full divide-y divide-gray-700'>
                    <thead class='bg-gray-900/50'>
                        <tr>
                            <th scope='col' class='px-6 py-3 text-left text-xs font-bold text-gray-400 uppercase tracking-wider'>Artifact / File</th>
                            <th scope='col' class='px-6 py-3 text-left text-xs font-bold text-gray-400 uppercase tracking-wider'>Description</th>
                        </tr>
                    </thead>
                    <tbody class='divide-y divide-gray-700 bg-gray-800/40'>
                        $content
                    </tbody>
                </table>
            </div>
        </section>"
    }

    local main_table=$(render_table_panel "General Logs &amp; Artifacts" "fa-file-alt" "text-yellow-400" "$main_files_html")
    local ps_table=$(render_table_panel "Performance Schema Files" "fa-tachometer-alt" "text-orange-400" "$ps_files_html")
    local ifs_table=$(render_table_panel "Information Schema Files" "fa-info-circle" "text-blue-400" "$ifs_files_html")
    local sys_table=$(render_table_panel "Sys Schema Files" "fa-cogs" "text-green-400" "$sys_files_html")
    
    local produced_files_panel="${main_table}${ps_table}${ifs_table}${sys_table}"

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

        $desc_html

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

        $breakdown_html

        <div class="space-y-8">
            <!-- Environment Details -->
            <section class="bg-gray-800 rounded-xl border border-gray-700 shadow-xl overflow-hidden">
                <div class="bg-gray-700 px-6 py-4">
                    <h2 class="text-lg font-semibold flex items-center"><i class="fas fa-info-circle mr-3 text-yellow-400"></i>Environment Details</h2>
                </div>
                <div class="p-6">
                    <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
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
                        <div>
                            <h3 class="text-sm font-bold text-gray-400 mb-3 uppercase tracking-wider">Storage Metrics (information_schema)</h3>
                            <ul class="text-sm space-y-1 text-gray-300">
                                <li>Total Rows: <span class="text-blue-400 font-mono">$(printf "%'d" ${db_total_rows:-0} 2>/dev/null || echo ${db_total_rows:-0})</span></li>
                                <li>Total Size: <span class="text-blue-400 font-mono">${db_total_size:-0} MB</span></li>
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
            $(render_panel "mysqltuner_output.txt" "MySQLTuner Output" "fa-terminal" "text-blue-400" "$mt_output" "" "open")

            <!-- Execution Trace (Log) -->
            $(render_panel "execution.log" "Full Execution Trace" "fa-file-code" "text-yellow-400")

            $audit_log_panel

            $produced_files_panel
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
    
    local duration_startup=0
    local duration_ready=0
    local duration_inject=0

    log_step "Starting container..."
    local t_start_container=$(date +%s)
    # Capture docker start log at config level
    make "$config" > "$root_target_dir/docker_start.log" 2>&1
    local ret=$?
    local t_end_container=$(date +%s)
    duration_startup=$((t_end_container - t_start_container))

    if [ $ret -ne 0 ]; then
        log_step "CRITICAL FAILED: Container startup ($config)."
        echo "ERROR: make $config failed with exit code $ret" >> "$root_target_dir/execution.log"
        generate_report "$root_target_dir" "$config" "$ret" "0" "N/A" "N/A" "make $config" "FailedStartup" "$duration_startup" "0" "0"
        exit 1
    fi
    sleep 10
    log_step "Waiting for database to be ready..."
    local t_start_ready=$(date +%s)
    local timeout=120
    local count=0
    until mysqladmin -h 127.0.0.1 -u root -pmysqltuner_test ping >/dev/null 2>&1; do
        sleep 2
        count=$((count + 2))
        if [ $count -ge $timeout ]; then
            log_step "ERROR: Database readiness timeout reached."
            break
        fi
    done
    sleep 5
    local t_end_ready=$(date +%s)
    duration_ready=$((t_end_ready - t_start_ready))

    if [ "$NO_INJECTION" = false ]; then
        log_step "Injecting sample data..."
        local t_start_inject=$(date +%s)
        export MYSQL_HOST=127.0.0.1
        export MYSQL_TCP_PORT=3306
        export MYSQL_USER=root
        export MYSQL_PWD=mysqltuner_test
        
        find "$VENDOR_DIR/test_db" -name "employees.sql" -exec sh -c 'cd $(dirname {}) && mysql -h 127.0.0.1 -u root -pmysqltuner_test < $(basename {})' \; > "$root_target_dir/db_injection.log" 2>&1
        check_exit_code $? "Database Data Injection" "$root_target_dir/execution.log"
        local t_end_inject=$(date +%s)
        duration_inject=$((t_end_inject - t_start_inject))
    else
        log_step "Skipping data injection as requested (--no-injection)."
        echo "Data injection skipped by user request." > "$root_target_dir/db_injection.log"
    fi

    db_version=$(mysql -h 127.0.0.1 -u root -pmysqltuner_test -e "SELECT VERSION();" -sN 2>/dev/null)
    db_list=$(mysql -h 127.0.0.1 -u root -pmysqltuner_test -e "SHOW DATABASES;" -sN 2>/dev/null)
    local db_total_rows=$(mysql -h 127.0.0.1 -u root -pmysqltuner_test -e "SELECT SUM(TABLE_ROWS) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys');" -sN 2>/dev/null || echo "0")
    local db_total_size=$(mysql -h 127.0.0.1 -u root -pmysqltuner_test -e "SELECT ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys');" -sN 2>/dev/null || echo "0")
    # Detect the actual container name (excluding traefik)
    local container_name=$(docker ps --format '{{.Names}}' | grep -v "traefik" | head -n 1)
    [ -z "$container_name" ] && container_name="$config"

    # Iterate over 4 scenarios
    for scenario in Standard Container Dumpdir Schemadir; do
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
        
        # Use --noask to prevent hanging in lab
        local mt_opts="--noask"
        
        case "$scenario" in
            Standard)
                perl "$PROJECT_ROOT/mysqltuner.pl" --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose $mt_opts --cvefile "$CVE_FILE" --outputfile "$target_dir/mysqltuner_output.txt" --reportfile="$target_dir/mysqltuner_report.html" > "$target_dir/execution.log" 2>&1
                ret_code=$?
                local repro_cmds="perl mysqltuner.pl --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose --cvefile vulnerabilities.csv --reportfile=mysqltuner_report.html"
                ;;
            Container)
                # Scenario where we force container mode
                perl "$PROJECT_ROOT/mysqltuner.pl" --container docker:"$container_name" --user root --pass mysqltuner_test $db_param --verbose $mt_opts --cvefile "$CVE_FILE" --outputfile "$target_dir/mysqltuner_output.txt" --reportfile="$target_dir/mysqltuner_report.html" > "$target_dir/execution.log" 2>&1
                ret_code=$?
                local repro_cmds="perl mysqltuner.pl --container docker:\"$container_name\" --verbose --cvefile vulnerabilities.csv --reportfile=mysqltuner_report.html"
                docker logs "$container_name" > "$target_dir/container_logs.log" 2>&1
                docker inspect "$container_name" > "$target_dir/container_inspect.json" 2>/dev/null
                ;;
            Dumpdir)
                # Scenario where we use dumpdir (Offline analysis mode)
                mkdir -p "$target_dir/dumps"
                # First, we need to generate the dumps (using Standard mode but with --dumpdir)
                perl "$PROJECT_ROOT/mysqltuner.pl" --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose --dumpdir="$target_dir/dumps" $mt_opts --cvefile "$CVE_FILE" --outputfile "$target_dir/mysqltuner_output.txt" --reportfile="$target_dir/mysqltuner_report.html" > "$target_dir/execution.log" 2>&1
                ret_code=$?
                local repro_cmds="perl mysqltuner.pl --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose --dumpdir=dumps --cvefile vulnerabilities.csv --reportfile=mysqltuner_report.html"
                ;;
            Schemadir)
                # Scenario where we use schemadir (Independent schema documentation)
                mkdir -p "$target_dir/schemas"
                perl "$PROJECT_ROOT/mysqltuner.pl" --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose --schemadir="$target_dir/schemas" $mt_opts --cvefile "$CVE_FILE" --outputfile "$target_dir/mysqltuner_output.txt" --reportfile="$target_dir/mysqltuner_report.html" > "$target_dir/execution.log" 2>&1
                ret_code=$?
                local repro_cmds="perl mysqltuner.pl --host 127.0.0.1 --user root --pass mysqltuner_test $db_param --verbose --schemadir=schemas --cvefile vulnerabilities.csv --reportfile=mysqltuner_report.html"
                ;;
        esac
        # ret_code=$?  # MOVED ABOVE to avoid being overwritten by local
        check_exit_code $ret_code "MySQLTuner Execution ($scenario)" "$target_dir/execution.log" "$target_dir/mysqltuner_output.txt"

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

        generate_report "$target_dir" "$config" "$ret_code" "$((end_time - start_time))" "$db_version" "$db_list" "$full_repro" "$scenario" "$duration_startup" "$duration_ready" "$duration_inject" "$db_total_rows" "$db_total_size"
    done

    # Create a redirect index at config root
    echo "<html><head><meta http-equiv='refresh' content='0; url=Standard/report.html'></head></html>" > "$root_target_dir/report.html"

    log_step "Stopping container..."
    if [ "$KEEP_ALIVE" = false ]; then
        make stop >> "$root_target_dir/docker_start.log" 2>&1
        sleep 5
    else
        log_step "KEEP ALIVE: Container remains running."
        echo "KEEP ALIVE: Container left running for manual debugging." >> "$root_target_dir/docker_start.log"
    fi
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

    perl mysqltuner.pl --container docker:"$container" $db_param --verbose --cvefile "$CVE_FILE" --outputfile "$target_dir/mysqltuner_output.txt" --reportfile="$target_dir/mysqltuner_report.html" > "$target_dir/execution.log" 2>&1
    ret_code=$?
    check_exit_code $ret_code "MySQLTuner Execution (Container: $container)" "$target_dir/execution.log" "$target_dir/mysqltuner_output.txt"

    log_step "Capturing container logs and inspection data..."
    docker logs "$container" > "$target_dir/container_logs.log" 2>&1
    docker inspect "$container" > "$target_dir/container_inspect.json" 2>/dev/null

    [ "$DO_AUDIT" = true ] && run_audit_tools "$target_dir"

    # Try to get DB info via container exec
    db_version=$(docker exec "$container" mysql -u root -e "SELECT VERSION();" -sN 2>/dev/null || echo "Unknown")
    db_list=$(docker exec "$container" mysql -u root -e "SHOW DATABASES;" -sN 2>/dev/null || echo "Unknown")
    local db_total_rows=$(docker exec "$container" mysql -u root -e "SELECT SUM(TABLE_ROWS) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys');" -sN 2>/dev/null || echo "0")
    local db_total_size=$(docker exec "$container" mysql -u root -e "SELECT ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys');" -sN 2>/dev/null || echo "0")

    end_time=$(date +%s)
    
    local repro_cmds="# Execute MySQLTuner against existing container
perl mysqltuner.pl --container docker:\"$container\" $db_param --verbose --reportfile=mysqltuner_report.html"

    generate_report "$target_dir" "container:$container" "$ret_code" "$((end_time - start_time))" "$db_version" "$db_list" "$repro_cmds" "" "0" "0" "0" "$db_total_rows" "$db_total_size"
}

run_test_remote() {
    local host=$1
    local target_dir="$EXAMPLES_DIR/${DATE_TAG}_remote_${host}"
    mkdir -p "$target_dir"

    log_header "Remote Audit: $host"
    start_time=$(date +%s)

    log_step "Transferring MySQLTuner and CVE list to remote..."
    scp $SSH_OPTIONS mysqltuner.pl vulnerabilities.csv "root@$host:/tmp/" > /dev/null

    log_step "Executing MySQLTuner on remote..."
    local db_param=""
    [ -n "$TARGET_DB" ] && db_param="--database $TARGET_DB"
    [ -n "$FORCEMEM_VAL" ] && db_param="$db_param --forcemem $FORCEMEM_VAL"

    ssh $SSH_OPTIONS "root@$host" "perl /tmp/mysqltuner.pl $db_param --verbose --cvefile /tmp/vulnerabilities.csv --reportfile=/tmp/mysqltuner_report.html" > "$target_dir/mysqltuner_output.txt" 2>&1
    ret_code=$?
    scp $SSH_OPTIONS "root@$host:/tmp/mysqltuner_report.html" "$target_dir/mysqltuner_report.html" > /dev/null 2>&1
    cat "$target_dir/mysqltuner_output.txt" > "$target_dir/execution.log"
    check_exit_code $ret_code "MySQLTuner Execution (Remote: $host)" "$target_dir/execution.log" "$target_dir/mysqltuner_output.txt"

    [ "$DO_AUDIT" = true ] && run_audit_tools "$target_dir"

    db_version=$(ssh $SSH_OPTIONS "root@$host" "mysql -e 'SELECT VERSION();' -sN" 2>/dev/null || echo "Unknown")
    db_list=$(ssh $SSH_OPTIONS "root@$host" "mysql -e 'SHOW DATABASES;' -sN" 2>/dev/null || echo "Unknown")
    local db_total_rows=$(ssh $SSH_OPTIONS "root@$host" "mysql -e \"SELECT SUM(TABLE_ROWS) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys');\" -sN" 2>/dev/null || echo "0")
    local db_total_size=$(ssh $SSH_OPTIONS "root@$host" "mysql -e \"SELECT ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) FROM information_schema.TABLES WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys');\" -sN" 2>/dev/null || echo "0")

    end_time=$(date +%s)
    
    local repro_cmds="# 1. Transfer MySQLTuner to remote
scp mysqltuner.pl \"root@$host:/tmp/mysqltuner.pl\"

# 2. Execute MySQLTuner on remote
ssh \"root@$host\" \"perl /tmp/mysqltuner.pl $db_param --verbose --reportfile=mysqltuner_report.html\""

    generate_report "$target_dir" "remote:$host" "$ret_code" "$((end_time - start_time))" "$db_version" "$db_list" "$repro_cmds" "" "0" "0" "0" "$db_total_rows" "$db_total_size"
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
