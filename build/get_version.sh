#!/bin/bash
# ==================================================================================
# Script:      build/get_version.sh
# Description: Centralized script to extract current MySQLTuner version string.
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ==================================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/../CURRENT_VERSION.txt"

if [ -f "$VERSION_FILE" ]; then
    cat "$VERSION_FILE" | tr -d '[:space:]'
else
    grep -E '^\s*\$tunerversion\s*=\s*' "$SCRIPT_DIR/../mysqltuner.pl" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1
fi
echo ""
