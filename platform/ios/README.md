# Aeostara — iOS Platform Target

## Status: Scaffold

This branch will contain the iOS native implementation of Aeostara.

## Target Architecture

- **Language**: Swift + C++ (via Objective-C++ bridging)
- **Build System**: Xcode
- **Test Framework**: XCTest
- **UI Framework**: SwiftUI

## Implementation Approach

1. Implement core healing engine in C++ (shared with macOS where possible)
2. Create Objective-C++ bridging layer (`AeostaraKit/`) to expose C++ API to Swift
3. Build SwiftUI app shell (`AeostaraApp/`) for configuration management
4. Implement all 11 contracts from `specs/contracts/`
5. Implement all algorithms following `specs/algorithms/` pseudo code
6. Add platform-specific Forsetti bridge (stub initially)

## Bridging Architecture

```
SwiftUI App (AeostaraApp/)
  └── AeostaraKit (Obj-C++ bridge)
        └── C++ Core (healing engine, contracts, algorithms)
```

## Build Instructions

*Not yet implemented. This branch contains scaffold files only.*

Open the Xcode project and build for iOS Simulator or device.

## Constraints

- iOS apps cannot run CLI commands — all interaction is via SwiftUI
- File system access is sandboxed — use app container or document picker
- Backup storage uses app-local directories
- Audit trail stored in app container
