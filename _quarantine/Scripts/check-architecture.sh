#!/usr/bin/env bash
# Aeostara Architecture Check Script (macOS/Linux)
# Copyright (c) 2026 James Daley. All Rights Reserved.
# Proprietary and Confidential.
#
# Usage: bash Scripts/check-architecture.sh [source_dir]

SOURCE_DIR="${1:-$(dirname "$0")/..}"
SOURCE_DIR=$(cd "$SOURCE_DIR" && pwd)
FAILURES=0

# Apple-extended file type list
EXTENSIONS="--include=*.h --include=*.hpp --include=*.cpp --include=*.cc --include=*.cxx --include=*.m --include=*.mm --include=*.swift"

echo "Aeostara Architecture Check (Apple)"
echo "Source: $SOURCE_DIR"
echo ""

# 1. No Python in product source
PYTHON_HITS=$(grep -rl -E 'python|Python' "$SOURCE_DIR/include" "$SOURCE_DIR/src" $EXTENSIONS 2>/dev/null || true)
if [ -n "$PYTHON_HITS" ]; then
    echo "[FAIL] Python references in product source:"
    echo "$PYTHON_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] No Python references in product source"
fi

# 2. No YAML in product source
YAML_HITS=$(grep -rl -E 'yaml|YAML|Yaml|yaml-cpp' "$SOURCE_DIR/include" "$SOURCE_DIR/src" $EXTENSIONS 2>/dev/null || true)
if [ -n "$YAML_HITS" ]; then
    echo "[FAIL] YAML references in product source:"
    echo "$YAML_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] No YAML references in product source"
fi

# 3. No Forsetti includes or imports
FORSETTI_HITS=$(grep -rl -E '#include.*Forsetti|import\s+Forsetti' "$SOURCE_DIR/include" "$SOURCE_DIR/src" $EXTENSIONS 2>/dev/null || true)
if [ -n "$FORSETTI_HITS" ]; then
    echo "[FAIL] Forbidden Forsetti includes/imports:"
    echo "$FORSETTI_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] No Forsetti includes/imports"
fi

# 4. No Forsetti namespace
NS_HITS=$(grep -rl 'namespace Forsetti' "$SOURCE_DIR/include" "$SOURCE_DIR/src" $EXTENSIONS 2>/dev/null || true)
if [ -n "$NS_HITS" ]; then
    echo "[FAIL] Forsetti namespace in Aeostara source:"
    echo "$NS_HITS"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] Namespace isolation (Aeostara only)"
fi

# 5. Core does not depend on CLI
CORE_CLI=$(grep -rl '#include.*AeostaraCLI' "$SOURCE_DIR/include/AeostaraCore" "$SOURCE_DIR/src/AeostaraCore" $EXTENSIONS 2>/dev/null || true)
if [ -n "$CORE_CLI" ]; then
    echo "[FAIL] Core depends on CLI:"
    echo "$CORE_CLI"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] Dependency direction correct (CLI→Core)"
fi

# 6. Copyright headers
MISSING_COPYRIGHT=()
while IFS= read -r -d '' file; do
    if ! grep -q 'Copyright (c) 2026 James Daley' "$file" 2>/dev/null; then
        MISSING_COPYRIGHT+=("$file")
    fi
done < <(find "$SOURCE_DIR/include" "$SOURCE_DIR/src" \( -name "*.h" -o -name "*.hpp" -o -name "*.cpp" -o -name "*.cc" -o -name "*.m" -o -name "*.mm" -o -name "*.swift" \) -print0 2>/dev/null)

if [ ${#MISSING_COPYRIGHT[@]} -gt 0 ]; then
    echo "[FAIL] Missing copyright headers:"
    printf '%s\n' "${MISSING_COPYRIGHT[@]}"
    FAILURES=$((FAILURES + 1))
else
    echo "[OK] All source files have copyright headers"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "Architecture check PASSED"
    exit 0
else
    echo "Architecture check FAILED ($FAILURES issues)"
    exit 1
fi
