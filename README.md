# Aeostara (macOS Native Realization)

**Downstream ASH-based healing platform** - macOS Swift implementation

This branch is the macOS native realization of Aeostara. Semantic authority is upstream in ASH and downstream conformance specs on `main`; this branch implements native Apple execution behavior.

Copyright (c) 2026 James Daley. All Rights Reserved.
Proprietary and Confidential.

## Branch Role

- Semantic authority: ASH upstream + Aeostara downstream conformance specs from `main`
- Branch responsibility: native macOS implementation using Swift/SwiftPM/XCTest
- Conflict rule: semantic alignment to `main`/ASH; macOS branch owns implementation mechanics

## Native Apple Stack

- Swift
- Foundation
- SwiftPM (`Package.swift`)
- XCTest

## Module Structure

- `AeostaraMacDomain` - domain contracts/algorithms and orchestration interfaces
- `AeostaraMacServices` - file/runtime adapters
- `AeostaraMacCLI` - CLI entrypoints
- `AeostaraMacTests` - unit/acceptance tests

## Build and Test

```bash
swift build
swift test
```

## Execution Guarantees

- Deterministic execution
- Policy gating before mutation
- Backup before mutation
- Verification after execution
- Rollback/escalation on verification failure
- Audit evidence for decision-critical actions

## Branch Alignment

This branch is validated against `platform_macos` profile contract:

- `branch_profiles/platform_macos.profile.json`
- `python3 ci/branch_alignment_checker.py . --profile platform_macos`

## License

Proprietary. All rights reserved. See [LICENSE.md](LICENSE.md).
