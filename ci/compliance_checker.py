#!/usr/bin/env python3
"""
Aeostara Compliance Checker
Scans platform branch source directories for forbidden dependencies.
Copyright (c) 2026 James Daley. All Rights Reserved.

Usage: python ci/compliance_checker.py <source_dir>
"""

import os
import re
import sys


PYTHON_PATTERNS = [
    re.compile(r"\bpython\b", re.IGNORECASE),
    re.compile(r"\.py[\"'\s>]"),
]

YAML_PATTERNS = [
    re.compile(r"\byaml\b", re.IGNORECASE),
    re.compile(r"\.yml\b"),
    re.compile(r"yaml-cpp", re.IGNORECASE),
]

SOURCE_EXTENSIONS = {".h", ".hpp", ".cpp", ".c", ".cc", ".cxx", ".m", ".mm", ".swift"}


def scan_file(filepath, patterns, label):
    """Scan a file for forbidden patterns. Returns list of (line_num, line, pattern)."""
    violations = []
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            for line_num, line in enumerate(f, 1):
                for pattern in patterns:
                    if pattern.search(line):
                        violations.append((line_num, line.strip(), label))
                        break
    except OSError:
        pass
    return violations


def scan_directory(source_dir):
    """Scan all source files in a directory for forbidden patterns."""
    all_violations = []

    for root, _dirs, files in os.walk(source_dir):
        # Skip .github, ci, and _quarantine directories (automation/reference exempt)
        rel = os.path.relpath(root, source_dir)
        if rel.startswith(".github") or rel.startswith("ci") or rel.startswith("_quarantine"):
            continue

        for filename in files:
            ext = os.path.splitext(filename)[1].lower()
            if ext not in SOURCE_EXTENSIONS:
                continue

            filepath = os.path.join(root, filename)

            for v in scan_file(filepath, PYTHON_PATTERNS, "Python"):
                all_violations.append((filepath, *v))

            for v in scan_file(filepath, YAML_PATTERNS, "YAML"):
                all_violations.append((filepath, *v))

    return all_violations


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <source_dir>", file=sys.stderr)
        sys.exit(1)

    source_dir = os.path.abspath(sys.argv[1])
    if not os.path.isdir(source_dir):
        print(f"Error: {source_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    print(f"Scanning {source_dir} for forbidden dependencies...")
    violations = scan_directory(source_dir)

    if not violations:
        print("PASS: No Python or YAML references found in product source.")
        sys.exit(0)
    else:
        print(f"FAIL: {len(violations)} forbidden reference(s) found:")
        for filepath, line_num, line, label in violations:
            rel_path = os.path.relpath(filepath, source_dir)
            print(f"  [{label}] {rel_path}:{line_num}: {line}")
        sys.exit(1)


if __name__ == "__main__":
    main()
