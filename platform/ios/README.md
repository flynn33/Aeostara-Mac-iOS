# Aeostara for iOS — Platform Details

**Status**: Source-complete (Swift/SwiftUI/SwiftPM), build-unverified

Native Swift reimplementation of the Aeostara deterministic JSON configuration drift detection and healing platform for iOS, compliant with Apple Forsetti framework requirements.

## Architecture

```
AeostaraApp (SwiftUI application)
  └── AeostaraServices (Swift module — sandbox I/O)
        └── AeostaraDomain (Swift module — healing logic)
              └── Foundation (JSON, FileManager, Date)
```

- **AeostaraDomain**: 11 contracts, 9 algorithms, 5 protocols — full healing engine in pure Swift
- **AeostaraServices**: iOS-specific I/O (sandbox FileManager, document picker integration)
- **AeostaraApp**: SwiftUI interface — file import, validate/diff/heal actions, audit viewer
- **XCTest + XCUITest**: Full test coverage including UI flows

## Build Requirements

- Xcode 15+ or Swift 5.9+ toolchain
- iOS 16.0+ deployment target
- No external dependencies (Foundation only)

## Build & Test

```bash
swift build
swift test
# Or via Xcode:
xcodebuild -scheme AeostaraApp -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild test -scheme AeostaraTests -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Features

- **File Import**: Document picker to import config and desired state JSON files
- **Sandbox Staging**: Files copied to app container for safe manipulation
- **Validate**: Check config against desired state and invariants
- **Diff**: Show drift events and proposed repair plan
- **Heal**: Apply deterministic repair with backup, verification, and rollback
- **Audit Trail**: View JSONL audit events in-app
- **Backup/Rollback**: Automatic rollback on verification failure

## Compliance

- Swift-native — no C++, no Objective-C++, no interpreted runtime
- JSON-only configuration scope (Foundation JSONSerialization)
- No Python or YAML in shipped product
- Forsetti-compliant (host-agnostic domain, protocol-first, all classes final)
- ASH-inspired healing semantics
- Deterministic outputs across platforms
- No third-party dependencies
