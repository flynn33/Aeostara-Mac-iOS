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

## macOS Implementation

This branch (`platform/macos`) contains the native Swift implementation for macOS.

### Module Structure

- **AeostaraMacDomain** — Pure Swift healing engine (contracts, algorithms, protocols)
- **AeostaraMacServices** — Platform I/O (FileManager-based config adapter, filesystem)
- **AeostaraMacCLI** — Command-line interface (`validate`, `diff`, `heal`)
- **AeostaraMacTests** — XCTest suite (unit + acceptance)

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

### Architecture
Design documents in `specs/architecture/`:
product_boundaries, branching_strategy, compliance_rules, native_target_architecture

## Compliance

- **Native only** — shipped product is a compiled Swift binary
- **JSON-only** — all configuration files are JSON; no YAML parser
- **No Python** — shipped product has no Python dependency
- **No C++/Obj-C++** — pure Swift implementation
- **Forsetti-compliant** — domain contracts are Forsetti-independent; platform services may integrate with macOS Forsetti framework per boundary rules
- **ASH-inspired** — healing semantics follow the Aeostara Self-Healing pattern

## License

Proprietary. All rights reserved. See [LICENSE.md](LICENSE.md).
