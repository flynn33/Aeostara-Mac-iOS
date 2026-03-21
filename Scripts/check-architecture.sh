#!/usr/bin/env bash
# Aeostara Architecture Check Script (macOS/Linux)
# Copyright (c) 2026 James Daley. All Rights Reserved.
# Proprietary and Confidential.
#
# Usage: bash Scripts/check-architecture.sh [source_dir]

SOURCE_DIR="${1:-$(dirname "$0")/..}"
SOURCE_DIR=$(cd "$SOURCE_DIR" && pwd)
FAILURES=0

echo "Aeostara Architecture Check"
echo "Source: $SOURCE_DIR"
echo ""

# 1. No Python in product source
PYTHON_HITS=$(grep -rl -E 'python|Python' "$SOURCE_DIR/include" "$SOURCE_DIR/src" --include="*.h" --include="*.cpp" 2>/dev/null || true)
if [ -n "$PYTHON_HITS" ]; then
    echo "[FAIL] Python references in product source:"
    echo "$PYTHON_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] No Python references in product source"
fi

# 2. No YAML in product source
YAML_HITS=$(grep -rl -E 'yaml|YAML|Yaml|yaml-cpp' "$SOURCE_DIR/include" "$SOURCE_DIR/src" --include="*.h" --include="*.cpp" 2>/dev/null || true)
if [ -n "$YAML_HITS" ]; then
    echo "[FAIL] YAML references in product source:"
    echo "$YAML_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] No YAML references in product source"
fi

# 3. No Forsetti includes
FORSETTI_HITS=$(grep -rl '#include.*Forsetti' "$SOURCE_DIR/include" "$SOURCE_DIR/src" --include="*.h" --include="*.cpp" 2>/dev/null || true)
if [ -n "$FORSETTI_HITS" ]; then
    echo "[FAIL] Forbidden Forsetti includes:"
    echo "$FORSETTI_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] No Forsetti includes"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "Architecture check PASSED"
    exit 0
else
    echo "Architecture check FAILED ($FAILURES issues)"
    exit 1
fi
