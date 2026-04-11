#!/usr/bin/env python3
"""
Aeostara Compliance Checker
Modes:
  - downstream-conformance: validate required remediation/conformance docs/language
  - source-safety: scan product source for Python/YAML references
  - all (default): run both checks
"""

import argparse
import os
import re
import sys
from typing import List, Tuple


REQUIRED_FILES = [
    "REMEDIATION_STATUS.md",
    "README.md",
    "specs/architecture/ash_authority_and_aeostara_conformance.md",
    "specs/acceptance/ash_conformance_targets.md",
    "specs/acceptance/traceability_matrix.md",
    "specs/acceptance/remediation_acceptance_targets.md",
    "specs/acceptance/acceptance_targets.md",
    "specs/acceptance/acceptance_execution_model.md",
    "specs/acceptance/compliance_checklist.md",
]

REQUIRED_PHRASES = [
    ("REMEDIATION_STATUS.md", "ASH is the immutable upstream semantic authority"),
    ("README.md", "downstream ASH-based"),
]

DISALLOWED_PATTERNS = [
    re.compile(r"Aeostara core defines ASH semantics", re.IGNORECASE),
    re.compile(r"ASH subsystem of Aeostara", re.IGNORECASE),
    re.compile(r"generic diff engine.*ASH compliant", re.IGNORECASE),
]

SCAN_PATHS = [
    "README.md",
    "specs/architecture",
    "specs/acceptance",
]

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


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        return f.read()


def gather_scan_files(repo_root: str) -> List[str]:
    files: List[str] = []
    for rel in SCAN_PATHS:
        full = os.path.join(repo_root, rel)
        if os.path.isfile(full):
            files.append(full)
            continue
        if os.path.isdir(full):
            for root, _dirs, names in os.walk(full):
                for name in names:
                    if name.endswith(".md"):
                        files.append(os.path.join(root, name))
    return files


def run_downstream_conformance(repo_root: str) -> Tuple[bool, List[str]]:
    failures: List[str] = []

    for rel in REQUIRED_FILES:
        full = os.path.join(repo_root, rel)
        if not os.path.isfile(full):
            failures.append(f"Missing required artifact: {rel}")

    for rel, phrase in REQUIRED_PHRASES:
        full = os.path.join(repo_root, rel)
        if not os.path.isfile(full):
            continue
        content = read_text(full)
        if phrase.lower() not in content.lower():
            failures.append(f"Required phrase not found in {rel}: {phrase}")

    scan_files = gather_scan_files(repo_root)
    for path in scan_files:
        content = read_text(path)
        for pattern in DISALLOWED_PATTERNS:
            if pattern.search(content):
                rel = os.path.relpath(path, repo_root)
                failures.append(f"Disallowed authority language in {rel}: {pattern.pattern}")

    return len(failures) == 0, failures


def scan_file(filepath: str, patterns: List[re.Pattern], label: str):
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


def run_source_safety(repo_root: str) -> Tuple[bool, List[str]]:
    failures: List[str] = []

    for root, _dirs, files in os.walk(repo_root):
        rel = os.path.relpath(root, repo_root)
        if (
            rel.startswith(".github")
            or rel.startswith("ci")
            or rel.startswith("_quarantine")
            or rel.startswith("tests")
            or rel.startswith("Tests")
        ):
            continue

        for filename in files:
            ext = os.path.splitext(filename)[1].lower()
            if ext not in SOURCE_EXTENSIONS:
                continue

            filepath = os.path.join(root, filename)
            relpath = os.path.relpath(filepath, repo_root)

            for line_num, line, label in scan_file(filepath, PYTHON_PATTERNS, "Python"):
                failures.append(f"[{label}] {relpath}:{line_num}: {line}")

            for line_num, line, label in scan_file(filepath, YAML_PATTERNS, "YAML"):
                failures.append(f"[{label}] {relpath}:{line_num}: {line}")

    return len(failures) == 0, failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Aeostara compliance checker")
    parser.add_argument("repo_root", nargs="?", default=os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
    parser.add_argument(
        "--mode",
        choices=["all", "downstream-conformance", "source-safety"],
        default="all",
        help="Which compliance mode to run"
    )
    args = parser.parse_args()

    repo_root = os.path.abspath(args.repo_root)

    overall_failures: List[str] = []

    if args.mode in {"all", "downstream-conformance"}:
        ok, failures = run_downstream_conformance(repo_root)
        if ok:
            print("PASS: downstream conformance checks passed.")
        else:
            print("FAIL: downstream conformance checks failed:")
            for issue in failures:
                print(f"  - {issue}")
            overall_failures.extend(failures)

    if args.mode in {"all", "source-safety"}:
        ok, failures = run_source_safety(repo_root)
        if ok:
            print("PASS: source safety checks passed.")
        else:
            print("FAIL: source safety checks failed:")
            for issue in failures:
                print(f"  - {issue}")
            overall_failures.extend(failures)

    return 0 if not overall_failures else 1


if __name__ == "__main__":
    sys.exit(main())
