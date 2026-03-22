#!/usr/bin/env bash
# Parse Swift source modules and generate a Markdown API reference.
# Usage: parse-swift-modules.sh <repo-root> <output-file>
# Copyright (c) 2026 James Daley. All Rights Reserved.

set -euo pipefail

REPO_ROOT="${1:-.}"
OUTPUT="${2:-swift-api-reference.md}"
BRANCH="${BRANCH_NAME:-unknown}"

{
  echo "# Swift Module Reference (${BRANCH})"
  echo
  echo "Auto-generated from Swift source files."
  echo

  if [ ! -f "${REPO_ROOT}/Package.swift" ]; then
    echo "No \`Package.swift\` found on this branch."
    exit 0
  fi

  # Extract target names and paths from Package.swift
  echo "## Package.swift Summary"
  echo
  echo '```swift'
  grep -E '^\s*\.(executableTarget|target|testTarget|library)\(' "${REPO_ROOT}/Package.swift" | sed 's/^[[:space:]]*//' || true
  echo '```'
  echo

  # Find all Swift source directories
  for dir in "${REPO_ROOT}/Sources"/*/ ; do
    [ -d "$dir" ] || continue
    module_name="$(basename "$dir")"

    echo "## Module: \`${module_name}\`"
    echo

    file_count=$(find "$dir" -name "*.swift" -type f | wc -l)
    echo "**Files:** ${file_count}"
    echo

    if [ "$file_count" -eq 0 ]; then
      echo "_No Swift files._"
      echo
      continue
    fi

    echo "### Public API"
    echo

    # Collect public declarations
    has_declarations=false

    while IFS= read -r swift_file; do
      fname="$(basename "$swift_file")"
      declarations=""

      # Extract public protocols
      protocols=$(grep -n 'public protocol ' "$swift_file" 2>/dev/null | sed 's/:.*//' | while read -r line; do
        grep -oP 'public protocol \K\w+' <<< "$(sed -n "${line}p" "$swift_file")" 2>/dev/null
      done || true)

      # Extract public structs
      structs=$(grep -oP 'public struct \K\w+' "$swift_file" 2>/dev/null || true)

      # Extract public classes
      classes=$(grep -oP 'public (final )?class \K\w+' "$swift_file" 2>/dev/null || true)

      # Extract public enums
      enums=$(grep -oP 'public enum \K\w+' "$swift_file" 2>/dev/null || true)

      # Combine
      all_types=""
      [ -n "$protocols" ] && all_types="${all_types}${protocols}"$'\n'
      [ -n "$structs" ] && all_types="${all_types}${structs}"$'\n'
      [ -n "$classes" ] && all_types="${all_types}${classes}"$'\n'
      [ -n "$enums" ] && all_types="${all_types}${enums}"$'\n'

      all_types="$(echo "$all_types" | sed '/^$/d' | sort -u)"

      if [ -n "$all_types" ]; then
        has_declarations=true
        echo "**\`${fname}\`**"
        echo "$all_types" | while read -r type_name; do
          [ -z "$type_name" ] && continue
          # Determine kind
          if grep -q "public protocol ${type_name}" "$swift_file" 2>/dev/null; then
            echo "- \`protocol ${type_name}\`"
          elif grep -q "public struct ${type_name}" "$swift_file" 2>/dev/null; then
            echo "- \`struct ${type_name}\`"
          elif grep -q "public.*class ${type_name}" "$swift_file" 2>/dev/null; then
            echo "- \`final class ${type_name}\`"
          elif grep -q "public enum ${type_name}" "$swift_file" 2>/dev/null; then
            echo "- \`enum ${type_name}\`"
          else
            echo "- \`${type_name}\`"
          fi
        done
        echo
      fi
    done < <(find "$dir" -name "*.swift" -type f | sort)

    if [ "$has_declarations" = false ]; then
      echo "_No public declarations found (internal module)._"
      echo
    fi

    echo "---"
    echo
  done

  # Test modules
  for dir in "${REPO_ROOT}/Tests"/*/ ; do
    [ -d "$dir" ] || continue
    module_name="$(basename "$dir")"
    file_count=$(find "$dir" -name "*.swift" -type f | wc -l)

    echo "## Test Module: \`${module_name}\`"
    echo
    echo "**Test files:** ${file_count}"
    echo

    if [ "$file_count" -gt 0 ]; then
      find "$dir" -name "*.swift" -type f | sort | while read -r f; do
        echo "- \`$(basename "$f")\`"
      done
      echo
    fi

    echo "---"
    echo
  done

} > "$OUTPUT"

echo "Generated Swift module reference: $OUTPUT"
