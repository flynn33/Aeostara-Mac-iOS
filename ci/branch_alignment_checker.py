#!/usr/bin/env python3
"""
Aeostara Branch Alignment Checker
Validates branch content against profile contracts in branch_profiles/*.profile.json.
"""

import argparse
import glob
import json
import os
import re
import sys
from typing import Dict, List


PROFILE_DIR = "branch_profiles"
DEFAULT_SCAN_EXCLUDES = {".git", ".github/wiki", "__pycache__"}


def detect_profile(explicit_profile: str) -> str:
    if explicit_profile:
        return explicit_profile

    env_profile = os.environ.get("AEOSTARA_BRANCH_PROFILE")
    if env_profile:
        return env_profile

    ref = os.environ.get("GITHUB_REF_NAME", "")
    mapping = {
        "main": "main",
        "platform/windows": "platform_windows",
        "platform/macos": "platform_macos",
        "platform/ios": "platform_ios",
    }
    if ref in mapping:
        return mapping[ref]

    return "main"


def load_profile(repo_root: str, profile_name: str) -> Dict:
    profile_path = os.path.join(repo_root, PROFILE_DIR, f"{profile_name}.profile.json")
    if not os.path.isfile(profile_path):
        raise FileNotFoundError(f"Profile not found: {profile_path}")
    with open(profile_path, "r", encoding="utf-8") as f:
        return json.load(f)


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        return f.read()


def should_exclude(path: str) -> bool:
    norm = path.replace("\\", "/")
    return any(token in norm for token in DEFAULT_SCAN_EXCLUDES)


def collect_files_for_paths(repo_root: str, paths: List[str]) -> List[str]:
    files: List[str] = []
    for rel in paths:
        full = os.path.join(repo_root, rel)
        if os.path.isfile(full):
            files.append(full)
        elif os.path.isdir(full):
            for root, _dirs, names in os.walk(full):
                if should_exclude(root):
                    continue
                for name in names:
                    files.append(os.path.join(root, name))
    return files


def check_required_files(repo_root: str, profile: Dict, failures: List[str]) -> None:
    for rel in profile.get("required_files", []):
        full = os.path.join(repo_root, rel)
        if not os.path.isfile(full):
            failures.append(f"Missing required file: {rel}")


def check_required_phrases(repo_root: str, profile: Dict, failures: List[str]) -> None:
    for item in profile.get("required_phrases", []):
        rel = item["file"]
        phrase = item["phrase"]
        full = os.path.join(repo_root, rel)
        if not os.path.isfile(full):
            failures.append(f"Required phrase file missing: {rel}")
            continue
        content = read_text(full)
        if phrase.lower() not in content.lower():
            failures.append(f"Required phrase not found in {rel}: {phrase}")


def check_forbidden_patterns(repo_root: str, profile: Dict, failures: List[str]) -> None:
    for rule in profile.get("forbidden_patterns", []):
        pattern = rule["pattern"]
        compiled = re.compile(pattern, re.IGNORECASE)
        targets = collect_files_for_paths(repo_root, rule.get("paths", []))
        for target in targets:
            if should_exclude(target):
                continue
            content = read_text(target)
            if compiled.search(content):
                rel = os.path.relpath(target, repo_root)
                failures.append(f"Forbidden pattern matched in {rel}: {pattern}")


def check_required_globs(repo_root: str, profile: Dict, failures: List[str]) -> None:
    for item in profile.get("required_globs", []):
        pattern = os.path.join(repo_root, item["pattern"])
        matches = [m for m in glob.glob(pattern, recursive=True) if os.path.isfile(m)]
        min_count = int(item.get("min_count", 1))
        if len(matches) < min_count:
            failures.append(
                f"Required glob {item['pattern']} expected >= {min_count}, found {len(matches)}"
            )


def check_required_any_globs(repo_root: str, profile: Dict, failures: List[str]) -> None:
    for item in profile.get("required_any_globs", []):
        total = 0
        for raw in item.get("patterns", []):
            pattern = os.path.join(repo_root, raw)
            total += len([m for m in glob.glob(pattern, recursive=True) if os.path.isfile(m)])
        min_total = int(item.get("min_total", 1))
        if total < min_total:
            failures.append(
                f"Required any-globs {item.get('patterns', [])} expected total >= {min_total}, found {total}"
            )


def check_forbidden_globs(repo_root: str, profile: Dict, failures: List[str]) -> None:
    for item in profile.get("forbidden_globs", []):
        pattern = os.path.join(repo_root, item["pattern"])
        matches = [m for m in glob.glob(pattern, recursive=True) if os.path.isfile(m)]
        filtered = [m for m in matches if not should_exclude(m)]
        if filtered:
            rel = os.path.relpath(filtered[0], repo_root)
            failures.append(f"Forbidden glob matched ({item['pattern']}): e.g. {rel}")


def run(repo_root: str, profile_name: str) -> int:
    profile = load_profile(repo_root, profile_name)
    failures: List[str] = []

    check_required_files(repo_root, profile, failures)
    check_required_phrases(repo_root, profile, failures)
    check_forbidden_patterns(repo_root, profile, failures)
    check_required_globs(repo_root, profile, failures)
    check_required_any_globs(repo_root, profile, failures)
    check_forbidden_globs(repo_root, profile, failures)

    if failures:
        print(f"FAIL: branch alignment profile '{profile_name}' failed:")
        for issue in failures:
            print(f"  - {issue}")
        return 1

    print(f"PASS: branch alignment profile '{profile_name}' passed.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Aeostara branch alignment profile")
    parser.add_argument("repo_root", nargs="?", default=os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
    parser.add_argument("--profile", default="", help="Profile name (e.g. main, platform_windows)")
    args = parser.parse_args()

    repo_root = os.path.abspath(args.repo_root)
    profile_name = detect_profile(args.profile)

    try:
        return run(repo_root, profile_name)
    except FileNotFoundError as exc:
        print(f"FAIL: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
