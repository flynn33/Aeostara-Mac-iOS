# Aeostara (iOS Native Realization)

**Downstream ASH-based healing platform** - iOS Swift/SwiftUI implementation

This branch is the iOS native realization of Aeostara. Semantic authority is upstream in ASH and the pinned Aeostara base release; this branch implements native Apple execution behavior.

Copyright (c) 2026 James Daley. All Rights Reserved.
Proprietary and Confidential.

## Branch Role

- Semantic authority: ASH upstream and `flynn33/aeostara` release `v1.0.0`
- Branch responsibility: native iOS implementation using Swift/SwiftUI/SwiftPM/XCTest/XCUITest
- Conflict rule: semantic alignment to the pinned Aeostara release and ASH; iOS branch owns implementation mechanics

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

The automated branch workflow validates the supported SwiftPM products and tests declared in `Package.swift`. The SwiftUI app shell source is tracked in this branch, but `Package.swift` does not currently define an archiveable app product.

## Execution Guarantees

- Deterministic execution
- Policy gating before mutation
- Backup before mutation
- Verification after execution
- Rollback/escalation on verification failure
- Audit evidence for decision-critical actions

## Base Pin and Migration

- [Aeostara baseline reference](AEOSTARA_BASELINE_REFERENCE.md)
- [Migration provenance](MIGRATION_PROVENANCE.md)

## License

Proprietary. All rights reserved. See [LICENSE.md](LICENSE.md).
