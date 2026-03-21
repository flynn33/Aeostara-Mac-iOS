# Apple Platform Policy Supplement — iOS

## Scope

This document supplements the root `agentic-coding-policy.json` with Apple-native interpretations of Forsetti compliance rules for the iOS platform.

## Allowed Toolchain

| Component | Allowed |
|-----------|---------|
| IDE | Xcode |
| Compiler | Apple Clang (C++20), Swift 5.9+ |
| Build system | Xcode project or CMake generating Xcode |
| Dependencies | nlohmann/json (via SPM or embedded) |
| Test framework | XCTest |
| Bridge layer | Objective-C++ (.mm files) |
| UI framework | SwiftUI |
| Deployment target | iOS 16.0+ |

## Forbidden in Shipped Product

| Forbidden | Reason |
|-----------|--------|
| Python runtime | R001: no interpreted runtimes |
| YAML parser | R001: JSON-only for v0.1 |
| Forsetti SDK/headers in core | Host-agnostic core requirement |
| Healing logic in bridge or Swift | Bridge must be thin |
| Direct file mutation outside sandbox | iOS sandbox rules |
| Globals, singletons, mutable statics | R005: constructor DI only |

## iOS-Specific Constraints

- All file operations occur within the app sandbox
- Config files imported via document picker, copied to app container
- Backups stored in `Documents/backups/`
- Audit trail stored in `Documents/audit/`
- Bridge layer (`AeostaraKit/`) translates types only — no drift/repair logic
- SwiftUI shell is a thin presentation layer over the bridge

## Architectural Invariants

1. All concrete C++ classes must be `final`
2. All C++ dependencies injected via constructor
3. `namespace Aeostara` exclusively (no `Forsetti` namespace)
4. One-way dependency: SwiftUI App → AeostaraKit Bridge → C++ Core → nlohmann/json
5. Every mutation path requires backup + rollback capability
6. Deterministic outputs: same input → same output on all platforms
7. Copyright header: `Copyright (c) 2026 James Daley. All Rights Reserved.`
