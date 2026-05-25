#!/bin/bash
# ==================================================================================
# Script: parallel_test.sh
# Description: Runs MySQLTuner laboratory validation tests in parallel.
# ==================================================================================

PROJECT_ROOT=$(pwd)
EXAMPLES_DIR="$PROJECT_ROOT/examples"
VENDOR_DIR="$PROJECT_ROOT/vendor"
DATE_TAG=$(date +%Y%m%d_%H%M%S)
CVE_FILE="$PROJECT_ROOT/vulnerabilities.csv"

# Gathers supported configurations
CONFIGS=$(perl build/get_supported_envs.pl)
echo "Supported configurations: $CONFIGS"

# Cleanup function to run at the end or on interrupt
cleanup() {
    echo "🧹 Cleaning up parallel test containers..."
    for config in $CONFIGS; do
        docker rm -f "mysqltuner-parallel-$config" >/dev/null 2>&1
    done
}
trap cleanup EXIT

# Setup vendor directories
mkdir -p "$EXAMPLES_DIR"
if [ ! -d "$VENDOR_DIR/multi-db-docker-env" ]; then
    git clone "https://github.com/jmrenouard/multi-db-docker-env" "$VENDOR_DIR/multi-db-docker-env"
fi
if [ ! -d "$VENDOR_DIR/test_db" ]; then
    git clone "https://github.com/jmrenouard/test_db" "$VENDOR_DIR/test_db"
fi

# Port counter and container list
port_base=33060
declare -A config_ports
declare -A config_images

# Setup mappings
idx=0
for config in $CONFIGS; do
    port=$((port_base + idx))
    config_ports[$config]=$port
    
    image="mysql:8.0"
    case "$config" in
        mysql96) image="mysql:9.6" ;;
        mysql84) image="mysql:8.4" ;;
        mysql80) image="mysql:8.0" ;;
        mariadb118) image="mariadb:11.8" ;;
        mariadb114) image="mariadb:11.4" ;;
        mariadb1011) image="mariadb:10.11" ;;
        mariadb106) image="mariadb:10.6" ;;
        percona80) image="percona/percona-server:8.0" ;;
    esac
    config_images[$config]=$image
    idx=$((idx + 1))
done

# Start all containers in parallel
echo "🚀 Starting all containers in parallel..."
for config in $CONFIGS; do
    port=${config_ports[$config]}
    image=${config_images[$config]}
    echo "   Starting $config on port $port using image $image..."
    docker run -d \
        --name "mysqltuner-parallel-$config" \
        -p "$port:3306" \
        -e MYSQL_ROOT_PASSWORD=mysqltuner_test \
        -e MARIADB_ROOT_PASSWORD=mysqltuner_test \
        -e MYSQL_ROOT_HOST="%" \
        -v "$VENDOR_DIR/multi-db-docker-env/conf/pfs.cnf:/etc/mysql/conf.d/pfs.cnf" \
        -v "$VENDOR_DIR/multi-db-docker-env/conf/pfs.cnf:/etc/my.cnf.d/pfs.cnf" \
        "$image" >/dev/null 2>&1 &
done
wait

# Wait for all databases to become ready in parallel
echo "⏳ Waiting for databases to initialize..."
for config in $CONFIGS; do
    port=${config_ports[$config]}
    (
        timeout=120
        count=0
        until mysqladmin -h 127.0.0.1 -P "$port" -u root -pmysqltuner_test ping >/dev/null 2>&1; do
            sleep 2
            count=$((count + 2))
            if [ $count -ge $timeout ]; then
                echo "❌ Timeout waiting for $config on port $port"
                exit 1
            fi
        done
        echo "✅ $config on port $port is ready"
    ) &
done
wait

# Inject data in parallel
echo "💉 Injecting test databases (sakila/employees)..."
for config in $CONFIGS; do
    port=${config_ports[$config]}
    (
        # Inject employees (skip for mysql96 due to nested source regression)
        if [ "$config" != "mysql96" ]; then
            mysql -h 127.0.0.1 -P "$port" -u root -pmysqltuner_test < "$VENDOR_DIR/test_db/employees/employees.sql" >/dev/null 2>&1
        fi
        # Inject Sakila
        mysql -h 127.0.0.1 -P "$port" -u root -pmysqltuner_test < "$VENDOR_DIR/test_db/sakila/sakila-mv-schema.sql" >/dev/null 2>&1
        mysql -h 127.0.0.1 -P "$port" -u root -pmysqltuner_test < "$VENDOR_DIR/test_db/sakila/sakila-mv-data.sql" >/dev/null 2>&1
        echo "✅ Data injected into $config"
    ) &
done
wait

# Execute MySQLTuner in parallel
echo "🧪 Running MySQLTuner test suite in parallel..."
for config in $CONFIGS; do
    port=${config_ports[$config]}
    (
        target_dir="$EXAMPLES_DIR/${DATE_TAG}_$config"
        mkdir -p "$target_dir/Standard" "$target_dir/Container" "$target_dir/Dumpdir" "$target_dir/Schemadir"
        
        # Standard Mode
        perl mysqltuner.pl --host 127.0.0.1 --port "$port" --user root --pass mysqltuner_test --verbose --noask --cvefile "$CVE_FILE" --outputfile "$target_dir/Standard/mysqltuner_output.txt" > "$target_dir/Standard/execution.log" 2>&1
        
        # Container Mode
        perl mysqltuner.pl --container docker:"mysqltuner-parallel-$config" --user root --pass mysqltuner_test --verbose --noask --cvefile "$CVE_FILE" --outputfile "$target_dir/Container/mysqltuner_output.txt" > "$target_dir/Container/execution.log" 2>&1
        
        # Dumpdir Mode
        perl mysqltuner.pl --host 127.0.0.1 --port "$port" --user root --pass mysqltuner_test --verbose --noask --dumpdir "$target_dir/Dumpdir/dumps" --cvefile "$CVE_FILE" --outputfile "$target_dir/Dumpdir/mysqltuner_output.txt" > "$target_dir/Dumpdir/execution.log" 2>&1
        
        # Schemadir Mode
        perl mysqltuner.pl --host 127.0.0.1 --port "$port" --user root --pass mysqltuner_test --verbose --noask --schemadir "$target_dir/Schemadir/schemas" --cvefile "$CVE_FILE" --outputfile "$target_dir/Schemadir/mysqltuner_output.txt" > "$target_dir/Schemadir/execution.log" 2>&1

        echo "✅ MySQLTuner tests completed for $config"
    ) &
done
wait

# Audit logs for failures
echo "🔍 Running log checker..."
perl build/audit_logs.pl --dir "$EXAMPLES_DIR"
exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "🎉 Parallel test execution completed successfully with no anomalies!"
else
    echo "❌ Anomalies/failures detected during test validation!"
fi

exit $exit_code
