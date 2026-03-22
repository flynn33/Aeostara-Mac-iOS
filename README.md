# Aeostara

**Deterministic JSON Configuration Drift Detection and Healing Platform** - v0.1

Aeostara observes live configuration, compares it against a declared desired state, detects drift, evaluates invariant policy, and executes repairs with backup, verification, rollback, and audit trail.

Copyright (c) 2026 James Daley. All Rights Reserved.
Proprietary and Confidential.

## Branch Model

This repository uses a specification-first branch strategy:

| Branch | Purpose |
|--------|---------|
| `main` | Platform-agnostic specifications: JSON contract schemas, pseudo code algorithms, interface definitions, architecture docs, test fixtures |
| `platform/windows` | Windows native implementation (C++20, MSVC, CMake, vcpkg) |
| `platform/macos` | macOS native implementation (Swift, SwiftPM, XCTest) |
| `platform/ios` | iOS native implementation (Swift, SwiftUI, XCTest/XCUITest) |

Spec changes on `main` merge down into platform branches. Platform code never merges back to `main`.

## iOS Implementation

This branch (`platform/ios`) contains the native Swift/SwiftUI implementation for iOS.

### Module Structure

- **AeostaraDomain** — Pure Swift healing engine (contracts, algorithms, protocols)
- **AeostaraServices** — iOS sandbox I/O (FileManager, document picker integration)
- **AeostaraApp** — SwiftUI application (file import, validate/diff/heal, audit viewer)
- **AeostaraTests** — XCTest suite (unit + acceptance)
- **AeostaraUITests** — XCUITest suite (UI flow tests)

### Build & Test

```bash
swift build
swift test
```

No external dependencies — Foundation only.

## Specifications

### Contracts (11 types)
JSON Schema definitions in `specs/contracts/`:
ObservedState, DesiredState, EncodedState, Invariant, DriftEvent, RepairAction, RepairPlan, VerificationResult, RollbackPlan, AuditEvent, ModuleManifest

### Algorithms (9)
Pseudo code in `specs/algorithms/`:
healing_flow, drift_analysis, repair_planning, policy_evaluation, json_path, verification, rollback, backup, audit

### Interfaces (5)
Pseudo code in `specs/interfaces/`:
IHealingEngine, IConfigAdapter, IBackupProvider, IAuditSink, IFileSystem

## Compliance

- **Native only** — shipped product is a compiled Swift binary
- **JSON-only** — all configuration files are JSON; no YAML parser
- **No Python** — shipped product has no Python dependency
- **No C++/Obj-C++** — pure Swift implementation
- **Forsetti-compliant** — protocol-based integration, host-agnostic domain
- **ASH-inspired** — healing semantics follow the Aeostara Self-Healing pattern

## License

Proprietary. All rights reserved. See [LICENSE.md](LICENSE.md).
