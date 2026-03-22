#!/bin/bash
# Aeostara CLI Smoke Tests
# Validates that the CLI commands work end-to-end with test fixtures.
# Copyright (c) 2026 James Daley. All Rights Reserved.
#
# Usage: smoke_test.sh <build_dir>
#   build_dir: path to the CMake build directory (e.g., build)

set -euo pipefail

BUILD_DIR="${1:?Usage: smoke_test.sh <build_dir>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES="$REPO_ROOT/fixtures"
CLI="$BUILD_DIR/src/AeostaraCLI/aeostara"

if [ ! -f "$CLI" ]; then
    # Try alternate build paths
    CLI="$BUILD_DIR/src/AeostaraCLI/Debug/aeostara"
fi

if [ ! -f "$CLI" ]; then
    echo "[FAIL] CLI executable not found in $BUILD_DIR"
    exit 1
fi

PASS=0
FAIL=0

run_test() {
    local name="$1"
    local expected_exit="$2"
    shift 2
    local actual_exit=0

    "$CLI" "$@" > /dev/null 2>&1 || actual_exit=$?

    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "[PASS] $name (exit=$actual_exit)"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $name (expected exit=$expected_exit, got=$actual_exit)"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "=== Aeostara CLI Smoke Tests ==="
echo "CLI: $CLI"
echo "Fixtures: $FIXTURES"
echo ""

# Test 1: validate — valid config, no drift
run_test "validate: valid config (no drift)" 0 \
    validate "$FIXTURES/valid_config.json" \
    --desired "$FIXTURES/desired_state.json" \
    --invariants "$FIXTURES/invariants.json"

# Test 2: diff — repairable config has drift
run_test "diff: repairable config (drift detected)" 1 \
    diff "$FIXTURES/repairable_config.json" \
    --desired "$FIXTURES/desired_state.json" \
    --invariants "$FIXTURES/invariants.json"

# Test 3: validate — invalid config
run_test "validate: invalid config (error)" 2 \
    validate "$FIXTURES/invalid_config.json" \
    --desired "$FIXTURES/desired_state.json"

# Test 4: heal — repairable config
TEMP_CONFIG=$(mktemp)
cp "$FIXTURES/repairable_config.json" "$TEMP_CONFIG"
TEMP_AUDIT=$(mktemp)

run_test "heal: repairable config (success)" 0 \
    heal "$TEMP_CONFIG" \
    --desired "$FIXTURES/desired_state.json" \
    --invariants "$FIXTURES/invariants.json" \
    --audit "$TEMP_AUDIT"

rm -f "$TEMP_CONFIG" "$TEMP_AUDIT"

# Test 5: help flag
run_test "help: --help flag" 0 --help

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

exit 0
