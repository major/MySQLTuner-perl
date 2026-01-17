#!/bin/bash

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
CONFIGS=${*:-$DEFAULT_CONFIGS}

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
    local target_dir="$EXAMPLES_DIR/${DATE_TAG}_${config}"
    mkdir -p "$target_dir"

    echo "=== Testing configuration: $config ==="
    
    cd "$VENDOR_DIR/multi-db-docker-env"
    
    # Ensure .env exists with default password
    if [ ! -f .env ]; then
        echo "DB_ROOT_PASSWORD=mysqltuner_test" > .env
    fi

    # Start the DB
    start_time=$(date +%s)
    make "$config" > "$target_dir/docker_start.log" 2>&1
    
    # Wait for DB to be ready
    echo "Waiting for DB to be healthy..."
    sleep 15
    
    # Inject test data
    echo "Injecting employees database..."
    if [ -d "$VENDOR_DIR/test_db" ]; then
        cd "$VENDOR_DIR/test_db"
        # We need to pass connection details to the test_db setup
        # The test_db repo usually expects a local mysql client or environment variables
        export MYSQL_HOST=127.0.0.1
        export MYSQL_TCP_PORT=3306
        export MYSQL_USER=root
        export MYSQL_PWD=mysqltuner_test
        
        # Check if we need to map port (multi-db-docker-env might use different port)
        # For now, assuming default 3306 as set in .env above
        
        # Run the injection
        if [ -f "employees.sql" ]; then
            mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PWD" < employees.sql > "$target_dir/db_injection.log" 2>&1
        elif [ -f "setup_employees.sh" ]; then
            bash setup_employees.sh >> "$target_dir/db_injection.log" 2>&1
        else
            echo "Searching for employees database entry point..."
            find . -name "employees.sql" -exec mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PWD" < {} + >> "$target_dir/db_injection.log" 2>&1
        fi
        cd "$VENDOR_DIR/multi-db-docker-env"
    else
        echo "Warning: test_db repository not found. Skipping employees injection."
    fi
    
    cd "$PROJECT_ROOT"
    
    # Run MySQLTuner
    echo "Running MySQLTuner..."
    perl mysqltuner.pl --host 127.0.0.1 --user root --pass mysqltuner_test --outputfile "$target_dir/mysqltuner_output.txt" > "$target_dir/execution.log" 2>&1
    ret_code=$?
    end_time=$(date +%s)
    exec_time=$((end_time - start_time))

    # Compile report
    {
        echo "Configuration: $config"
        echo "Date: $(date)"
        echo "Return Code: $ret_code"
        echo "Execution Time: ${exec_time}s"
        echo "Environment: Docker via multi-db-docker-env"
        echo "Databases:"
        mysql -h 127.0.0.1 -u root -pmysqltuner_test -e "SHOW DATABASES;" 2>/dev/null || echo "Could not list databases"
    } > "$target_dir/report.txt"

    # Stop the DB
    cd "$VENDOR_DIR/multi-db-docker-env"
    make stop >> "$target_dir/docker_start.log" 2>&1
    
    echo "Done with $config. Results in $target_dir"
}

setup_vendor

for config in $CONFIGS; do
    run_test "$config"
done

echo "All tests completed."
