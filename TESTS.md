# MySQLTuner-perl Testing Guide

## Unit and Regression Tests
The project uses `Test::More` for unit testing. All tests are located in the `tests/` directory.

### Running Unit Tests
```bash
make unit-tests
# OR
prove -r tests/
```

## Laboratory Tests (Docker)
The laboratory environment allows testing `mysqltuner.pl` against multiple database versions.

### Setup Vendor Repositories
```bash
make vendor_setup
```

### Running Lab Tests
```bash
# Run tests against default environments (mysql84, mariadb1011, percona80)
make test

# Run all database lab tests
make test-all

# Run tests against a specific container
make test-container CONTAINER=my_db_name
```

### Lab Audit
After running tests, you can audit the generated logs:
```bash
make audit-logs
```

## Test Scenarios
Every diagnostic change should ideally be validated in three scenarios:
1. **Standard**: `./mysqltuner.pl --verbose`
2. **Container**: `./mysqltuner.pl --verbose --container [ID]`
3. **Dumpdir**: `./mysqltuner.pl --verbose --dumpdir=dumps`
