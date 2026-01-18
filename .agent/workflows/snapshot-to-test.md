---
description: Transform a running production issue into a reproducible test case
---

# Snapshot to Test Workflow

This workflow helps capture the state of a running database (where a bug is observed) and converts it into a standalone Perl test case for TDD.

## 1. Context Acquisition

Identify the target container or host where the issue is reproducible.

```bash
# Example: Define target
TARGET_CONTAINER="mysql_8_0" 
```

## 2. Capture Variables and Status

Extract the raw data required by MySQLTuner to mock the environment.

```bash
# Extract Global Variables
docker exec -i $TARGET_CONTAINER mysql -NBe "SHOW GLOBAL VARIABLES" > /tmp/vars.txt

# Extract Global Status
docker exec -i $TARGET_CONTAINER mysql -NBe "SHOW GLOBAL STATUS" > /tmp/status.txt
```

## 3. Generate Test Skeleton

Create a new test file in `tests/` (e.g., `tests/repro_issue_XXX.t`).

Use the following template:

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Data::Dumper;

# 1. Load MySQLTuner logic
# (Adjust path if needed to load specific subroutines)
require 'mysqltuner.pl';

# 2. Mock Data
# Insert data captured from /tmp/vars.txt and /tmp/status.txt
my %mock_variables = (
    # ... content from vars.txt formatted as hash ...
    'version' => '8.0.32',
    'innodb_buffer_pool_size' => '1073741824',
);

my %mock_status = (
    # ... content from status.txt formatted as hash ...
    'Uptime' => '3600',
    'Questions' => '500',
);

# 3. Setup Environment
# Overlay mock data onto the script's global hashes
*main::myvar = \%mock_variables;
*main::mystat = \%mock_status;

# 4. Execute Logic
# Call the specific subroutine under test
# e.g., setup_innodb_buffer_pool();

# 5. Assertions
# Verify the expected behavior (bug reproduction or fix verification)
ok(1, "Placeholder assertion");

done_testing();
```

## 4. Run and Refine

Run the test to confirm it fails (if reproducing a bug) or passes (if verifying logic).

```bash
prove tests/repro_issue_XXX.t
```
