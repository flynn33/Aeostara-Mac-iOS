# Aeostara — macOS Platform Target

## Status: Scaffold

This branch will contain the macOS native implementation of Aeostara.

## Target Architecture

- **Language**: C++ (Clang) or Swift, with potential AppKit/SwiftUI shell
- **Build System**: CMake + Ninja/Clang, or Xcode native project
- **Test Framework**: Catch2 or XCTest
- **Dependencies**: nlohmann/json (via vcpkg or FetchContent)

## Implementation Approach

1. Implement all 11 contracts from `specs/contracts/` in native types
2. Implement all 9 algorithms following `specs/algorithms/` pseudo code
3. Implement all 5 interfaces from `specs/interfaces/`
4. Build a CLI shell matching the same command interface as Windows
5. Add platform-specific Forsetti bridge (stub initially)

## Build Instructions

*Not yet implemented. This branch contains scaffold files only.*

## Future GUI Shell

The macOS GUI will use AppKit or SwiftUI for:
- Configuration file management
- Drift visualization
- Heal operation monitoring
- Audit trail viewing

The GUI shell will wrap the core healing engine via the IHealingEngine interface.
