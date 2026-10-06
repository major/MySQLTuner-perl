#!/usr/bin/env bash
# ===========================================================================
# Script:      build/validate_release.sh
# Description: Wrapper executing the pure Perl unified release validator.
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

exec perl "${ROOT_DIR}/build/validate_release.pl"
