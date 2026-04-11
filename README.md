# Aeostara (iOS Native Realization)

**Downstream ASH-based healing platform** - iOS Swift/SwiftUI implementation

This branch is the iOS native realization of Aeostara. Semantic authority is upstream in ASH and downstream conformance specs on `main`; this branch implements native Apple execution behavior.

Copyright (c) 2026 James Daley. All Rights Reserved.
Proprietary and Confidential.

## Branch Role

- Semantic authority: ASH upstream + Aeostara downstream conformance specs from `main`
- Branch responsibility: native iOS implementation using Swift/SwiftUI/SwiftPM/XCTest/XCUITest
- Conflict rule: semantic alignment to `main`/ASH; iOS branch owns implementation mechanics

## Native Apple Stack

- Swift
- SwiftUI
- Foundation
- SwiftPM (`Package.swift`)
- XCTest/XCUITest

## Module Structure

- `AeostaraDomain` - domain contracts/algorithms and orchestration interfaces
- `AeostaraServices` - iOS sandbox/file adapters
- `AeostaraApp` - SwiftUI app shell and interaction flows
- `AeostaraTests` and `AeostaraUITests` - unit/acceptance/UI tests

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

This branch is validated against `platform_ios` profile contract:

- `branch_profiles/platform_ios.profile.json`
- `python3 ci/branch_alignment_checker.py . --profile platform_ios`

## License

Proprietary. All rights reserved. See [LICENSE.md](LICENSE.md).
