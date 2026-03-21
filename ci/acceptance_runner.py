#!/usr/bin/env python3
"""
Aeostara Acceptance Test Runner
Runs acceptance tests against a platform's built binary.
Copyright (c) 2026 James Daley. All Rights Reserved.

Usage: python ci/acceptance_runner.py <binary_path> <fixtures_dir>

The binary must support: validate, diff, heal commands with
--desired, --invariants, --audit options.
"""

import json
import os
import subprocess
import sys
import tempfile
import shutil


def run_command(binary, args, timeout=30):
    """Run a command and return (exit_code, stdout, stderr)."""
    cmd = [binary] + args
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Timeout"
    except FileNotFoundError:
        return -1, "", f"Binary not found: {binary}"


def test_valid_config_no_drift(binary, fixtures):
    """Scenario 1: Valid config validates successfully."""
    code, stdout, stderr = run_command(binary, [
        "validate",
        os.path.join(fixtures, "valid_config.json"),
        "--desired", os.path.join(fixtures, "desired_state.json"),
    ])
    if code != 0:
        return False, f"Expected exit 0, got {code}. stderr: {stderr}"
    try:
        output = json.loads(stdout)
        if not output.get("valid", False):
            return False, f"Expected valid=true, got {output}"
    except json.JSONDecodeError:
        return False, f"Invalid JSON output: {stdout}"
    return True, "OK"


def test_invalid_config_error(binary, fixtures):
    """Scenario 2: Invalid config produces error."""
    code, stdout, stderr = run_command(binary, [
        "validate",
        os.path.join(fixtures, "invalid_config.json"),
        "--desired", os.path.join(fixtures, "desired_state.json"),
    ])
    if code != 2:
        return False, f"Expected exit 2, got {code}. stderr: {stderr}"
    return True, "OK"


def test_policy_block(binary, fixtures):
    """Scenario 3: Policy-violating config blocks repair."""
    with tempfile.TemporaryDirectory() as tmpdir:
        audit_path = os.path.join(tmpdir, "audit.jsonl")
        config_copy = os.path.join(tmpdir, "policy_blocked_config.json")
        shutil.copy(os.path.join(fixtures, "policy_blocked_config.json"), config_copy)

        code, stdout, stderr = run_command(binary, [
            "heal",
            config_copy,
            "--desired", os.path.join(fixtures, "desired_state.json"),
            "--invariants", os.path.join(fixtures, "invariants.json"),
            "--audit", audit_path,
        ])
        if code != 1:
            return False, f"Expected exit 1, got {code}. stderr: {stderr}"
        try:
            output = json.loads(stdout)
            if output.get("success", True):
                return False, "Expected success=false"
        except json.JSONDecodeError:
            return False, f"Invalid JSON output: {stdout}"
    return True, "OK"


def test_successful_repair(binary, fixtures):
    """Scenario 4: Repairable config heals successfully."""
    with tempfile.TemporaryDirectory() as tmpdir:
        audit_path = os.path.join(tmpdir, "audit.jsonl")
        config_copy = os.path.join(tmpdir, "repairable_config.json")
        shutil.copy(os.path.join(fixtures, "repairable_config.json"), config_copy)

        code, stdout, stderr = run_command(binary, [
            "heal",
            config_copy,
            "--desired", os.path.join(fixtures, "desired_state.json"),
            "--invariants", os.path.join(fixtures, "invariants.json"),
            "--audit", audit_path,
        ])
        if code != 0:
            return False, f"Expected exit 0, got {code}. stderr: {stderr}"
        try:
            output = json.loads(stdout)
            if not output.get("success", False):
                return False, f"Expected success=true, got {output}"
        except json.JSONDecodeError:
            return False, f"Invalid JSON output: {stdout}"
    return True, "OK"


def test_diff_produces_plan(binary, fixtures):
    """Scenario 5: Diff on drifted config produces repair plan."""
    code, stdout, stderr = run_command(binary, [
        "diff",
        os.path.join(fixtures, "repairable_config.json"),
        "--desired", os.path.join(fixtures, "desired_state.json"),
    ])
    if code != 1:
        return False, f"Expected exit 1, got {code}. stderr: {stderr}"
    try:
        output = json.loads(stdout)
        if output.get("driftCount", 0) == 0:
            return False, "Expected drifts"
        if "proposedPlan" not in output:
            return False, "Missing proposedPlan"
    except json.JSONDecodeError:
        return False, f"Invalid JSON output: {stdout}"
    return True, "OK"


SCENARIOS = [
    ("1. Valid config — no drift", test_valid_config_no_drift),
    ("2. Invalid config — parse error", test_invalid_config_error),
    ("3. Policy block — critical invariant", test_policy_block),
    ("4. Successful repair", test_successful_repair),
    ("5. Diff produces repair plan", test_diff_produces_plan),
]


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <binary_path> <fixtures_dir>", file=sys.stderr)
        sys.exit(1)

    binary = os.path.abspath(sys.argv[1])
    fixtures = os.path.abspath(sys.argv[2])

    if not os.path.isfile(binary):
        print(f"Error: Binary not found: {binary}", file=sys.stderr)
        sys.exit(1)

    if not os.path.isdir(fixtures):
        print(f"Error: Fixtures dir not found: {fixtures}", file=sys.stderr)
        sys.exit(1)

    print(f"Running {len(SCENARIOS)} acceptance scenarios...")
    print(f"Binary: {binary}")
    print(f"Fixtures: {fixtures}")
    print()

    failures = 0
    for name, test_fn in SCENARIOS:
        passed, message = test_fn(binary, fixtures)
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {name}: {message}")
        if not passed:
            failures += 1

    print()
    if failures == 0:
        print(f"All {len(SCENARIOS)} scenarios passed.")
        sys.exit(0)
    else:
        print(f"{failures} scenario(s) failed.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
