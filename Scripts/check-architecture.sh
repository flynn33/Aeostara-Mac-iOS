#!/usr/bin/env bash
# Aeostara Architecture Check Script (iOS/Apple)
# Copyright (c) 2026 James Daley. All Rights Reserved.
# Proprietary and Confidential.
#
# Usage: bash Scripts/check-architecture.sh [source_dir]

SOURCE_DIR="${1:-$(dirname "$0")/..}"
SOURCE_DIR=$(cd "$SOURCE_DIR" && pwd)
FAILURES=0

echo "Aeostara Architecture Check (Apple/iOS)"
echo "Source: $SOURCE_DIR"
echo ""

# Scan all Apple-relevant source directories
SCAN_DIRS=""
for d in AeostaraCore/include AeostaraCore/src platform/ios/AeostaraKit platform/ios/AeostaraApp; do
    if [ -d "$SOURCE_DIR/$d" ]; then
        SCAN_DIRS="$SCAN_DIRS $SOURCE_DIR/$d"
    fi
done

if [ -z "$SCAN_DIRS" ]; then
    echo "No source directories found to scan"
    exit 0
fi

# 1. No Python in product source (exclude vendored third-party headers)
PYTHON_HITS=$(grep -rl -E 'python|Python' $SCAN_DIRS --include="*.h" --include="*.hpp" --include="*.cpp" --include="*.cc" --include="*.m" --include="*.mm" --include="*.swift" 2>/dev/null | grep -v '/nlohmann/' || true)
if [ -n "$PYTHON_HITS" ]; then
    echo "[FAIL] Python references in product source:"
    echo "$PYTHON_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] No Python references in product source"
fi

# 2. No YAML in product source
YAML_HITS=$(grep -rl -E 'yaml|YAML|Yaml|yaml-cpp' $SCAN_DIRS --include="*.h" --include="*.hpp" --include="*.cpp" --include="*.cc" --include="*.m" --include="*.mm" --include="*.swift" 2>/dev/null || true)
if [ -n "$YAML_HITS" ]; then
    echo "[FAIL] YAML references in product source:"
    echo "$YAML_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] No YAML references in product source"
fi

# 3. No Forsetti includes or imports
FORSETTI_HITS=$(grep -rl -E '#include.*Forsetti|import\s+Forsetti' $SCAN_DIRS --include="*.h" --include="*.hpp" --include="*.cpp" --include="*.cc" --include="*.m" --include="*.mm" --include="*.swift" 2>/dev/null || true)
if [ -n "$FORSETTI_HITS" ]; then
    echo "[FAIL] Forbidden Forsetti includes/imports:"
    echo "$FORSETTI_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] No Forsetti includes/imports"
fi

# 4. No Forsetti namespace
NS_HITS=$(grep -rl 'namespace Forsetti' $SCAN_DIRS --include="*.h" --include="*.hpp" --include="*.cpp" --include="*.cc" --include="*.m" --include="*.mm" 2>/dev/null || true)
if [ -n "$NS_HITS" ]; then
    echo "[FAIL] Forsetti namespace in Aeostara source:"
    echo "$NS_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] Namespace isolation (Aeostara only)"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "Architecture check PASSED"
    exit 0
else
    echo "Architecture check FAILED ($FAILURES issues)"
    exit 1
fi
