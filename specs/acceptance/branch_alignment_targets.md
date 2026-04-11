# Branch Alignment Targets

## Objective

Ensure all active branches remain semantically aligned after remediation.

## Targets

1. Each branch satisfies its declared profile in `branch_profiles/`.
2. Branch README language stays downstream ASH-conformance consistent.
3. Platform branch native technology posture is preserved (Windows C++ profile, Apple Swift profile).
4. Acceptance and conformance references are present on each branch.
5. Disallowed authority language is absent.

## Validation Command

- `python3 ci/branch_alignment_checker.py --profile main`
- `python3 ci/branch_alignment_checker.py --profile platform_windows`
- `python3 ci/branch_alignment_checker.py --profile platform_macos`
- `python3 ci/branch_alignment_checker.py --profile platform_ios`
