# Aeostara for iOS

**Status**: Implemented Alpha v0.1.0

Deterministic JSON configuration drift detection and healing platform — iOS native client.

## Architecture

```
SwiftUI App (AeostaraApp/)
  └── Obj-C++ Bridge (AeostaraKit/)
        └── C++ Core (AeostaraCore/)
              └── nlohmann/json
```

- **AeostaraCore**: 11 contracts, 9 algorithms, 5 interfaces — identical C++20 core shared with macOS
- **AeostaraKit**: Thin Objective-C++ bridge — translates Foundation types to/from C++, no healing logic
- **AeostaraApp**: SwiftUI shell — file import, validate/diff/heal actions, result display, audit viewer

## Build Requirements

- Xcode (latest stable)
- iOS 16.0+ deployment target
- Swift 5.9+
- nlohmann/json (via SPM or embedded)

## Build

### Generate Xcode Project (via CMake)

```bash
cmake -G Xcode -B build/ios
open build/ios/Aeostara.xcodeproj
```

Then build and run in Xcode for iOS Simulator or device.

### Dependencies

nlohmann/json is embedded as a single-header in `AeostaraCore/include/nlohmann/json.hpp` — no external package manager required.

## Test

XCTest suite in `AeostaraTests/AeostaraBridgeTests.mm` covers:
- C++ core tests (JsonPath, DriftAnalyzer, RepairPlanner, HealingEngine)
- Obj-C++ bridge tests (validate, diff, heal through AeostaraEngine wrapper)
- Acceptance scenarios (no drift, successful repair)

```bash
xcodebuild test -project build/ios/Aeostara.xcodeproj -scheme AeostaraTests
```

## Features

- **File Import**: Document picker to import config and desired state JSON files
- **Sandbox Staging**: Files copied to app container for safe manipulation
- **Validate**: Check config against desired state and invariants
- **Diff**: Show drift events and proposed repair plan
- **Heal**: Apply deterministic repair with backup, verification, and rollback
- **Audit Trail**: View JSONL audit events in-app
- **Backup**: Stored in `Documents/backups/`
- **Rollback**: Automatic rollback on verification failure

## iOS Constraints

- No CLI — all interaction via SwiftUI interface
- File system sandboxed — uses app container and document picker
- Backup and audit stored in app's Documents directory
- Bridge layer is thin — all healing logic in C++ core

## Compliance

- C++20 native core — no interpreted runtime
- JSON-only configuration scope
- No Python or YAML in shipped product
- Forsetti-compliant (host-agnostic core, interface-first, all types final)
- ASH-inspired healing semantics
- Deterministic outputs matching Windows and macOS behavior
