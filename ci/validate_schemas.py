#!/usr/bin/env python3
"""
Aeostara Schema Validator
Validates all JSON Schema files in specs/contracts/ are well-formed.
Copyright (c) 2026 James Daley. All Rights Reserved.

Usage: python ci/validate_schemas.py
"""

import json
import os
import sys


def validate_schema(filepath):
    """Validate that a JSON file is well-formed and has required schema fields."""
    with open(filepath, "r", encoding="utf-8") as f:
        try:
            schema = json.load(f)
        except json.JSONDecodeError as e:
            return False, f"Invalid JSON: {e}"

    if "$schema" not in schema:
        return False, "Missing $schema field"
    if "title" not in schema:
        return False, "Missing title field"
    if "type" not in schema:
        return False, "Missing type field"

    return True, "OK"


def main():
    contracts_dir = os.path.join(os.path.dirname(__file__), "..", "specs", "contracts")
    contracts_dir = os.path.abspath(contracts_dir)

    if not os.path.isdir(contracts_dir):
        print(f"Error: {contracts_dir} not found", file=sys.stderr)
        sys.exit(1)

    schema_files = sorted(
        f for f in os.listdir(contracts_dir) if f.endswith(".schema.json")
    )

    if not schema_files:
        print("Error: No schema files found", file=sys.stderr)
        sys.exit(1)

    print(f"Validating {len(schema_files)} contract schemas...")
    failures = 0

    for filename in schema_files:
        filepath = os.path.join(contracts_dir, filename)
        valid, message = validate_schema(filepath)
        status = "PASS" if valid else "FAIL"
        print(f"  [{status}] {filename}: {message}")
        if not valid:
            failures += 1

    print()
    if failures == 0:
        print(f"All {len(schema_files)} schemas valid.")
        sys.exit(0)
    else:
        print(f"{failures} schema(s) failed validation.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
