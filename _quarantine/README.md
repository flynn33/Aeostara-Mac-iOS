> Historical reference only. Forsetti is not selected for the current Apple SDK. These artifacts remain excluded from native builds and SDK distribution. Current first-party ownership follows the root Apache License 2.0; third-party terms remain unchanged.

# Quarantined Artifacts — Non-Compliant Architecture

These files are the original C++20/Objective-C++ bridge implementation of Aeostara for iOS.
They are **reference-only** and are **not part of the shipped product**.

## Why Quarantined

The Apple Forsetti framework requires native Apple technologies:
- Swift (not C++20)
- SwiftUI with native Swift domain (not Obj-C++ bridge)
- SwiftPM or Xcode-native projects (not CMake)
- Foundation (not nlohmann/json)
- XCTest (not Obj-C++ test files)

## Contents

| Directory/File | Original Location | Description |
|---|---|---|
| `AeostaraCore/` | `AeostaraCore/` | C++ core (headers, sources, nlohmann/json) |
| `AeostaraKit/` | `platform/ios/AeostaraKit/` | Obj-C++ bridge (AeostaraBridge.mm, AeostaraKit.h) |
| `AeostaraBridgeTests.mm` | `AeostaraTests/AeostaraBridgeTests.mm` | Obj-C++ XCTest file |
| `Aeostara.xcodeproj/` | `Aeostara.xcodeproj/` | CMake-generated Xcode project |
| `CMakeLists.txt` | `CMakeLists.txt` | Root CMake file |
| `Scripts/` | `Scripts/` | Build/compliance scripts |

## Status

**Non-compliant. Do not include in build or ship.**
