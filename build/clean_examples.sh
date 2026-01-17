#!/bin/bash
# ==================================================================================
# Script: clean_examples.sh
# Description: Cleans up the examples directory, keeping only recent test executions.
# Author: Jean-Marie Renouard
# Project: MySQLTuner-perl
# ==================================================================================

set -euo pipefail

# Configuration
EXAMPLES_DIR="examples"
KEEP=${1:-5}

if [ ! -d "$EXAMPLES_DIR" ]; then
    echo "Directory $EXAMPLES_DIR does not exist. Nothing to clean."
    exit 0
fi

echo "Cleaning up $EXAMPLES_DIR, keeping the last $KEEP executions..."

# List directories, sort them in reverse order (newest first), skip the first $KEEP ones, then delete the rest.
# Note: This assumes directories follow the YYYYMMDD_HHMMSS_config format.
DIRS_TO_DELETE=$(ls -1d "$EXAMPLES_DIR"/*/ 2>/dev/null | sort -r | tail -n +$((KEEP + 1)))

if [ -z "$DIRS_TO_DELETE" ]; then
    echo "No directories to delete."
else
    for dir in $DIRS_TO_DELETE; do
        echo "Deleting $dir"
        rm -rf "$dir"
    done
    echo "Cleanup completed."
fi
