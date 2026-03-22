# Quarantined Artifacts — Non-Compliant Architecture

These files are the original C++20/CMake/vcpkg/Catch2 implementation of Aeostara for macOS.
They are **reference-only** and are **not part of the shipped product**.

## Why Quarantined

The Apple Forsetti framework requires native Apple technologies:
- Swift (not C++20)
- SwiftPM or Xcode-native projects (not CMake)
- Foundation (not nlohmann/json)
- XCTest (not Catch2)

These artifacts were moved here during the Apple Forsetti remediation to preserve
them as reference material while removing them from active shipped product paths.

## Contents

| Directory/File | Original Location | Description |
|---|---|---|
| `AeostaraCore_src/` | `src/AeostaraCore/` | C++ core implementation (14 .cpp files) |
| `AeostaraCore_include/` | `include/AeostaraCore/` | C++ public headers (19 .h files) |
| `AeostaraCLI_src/` | `src/AeostaraCLI/` | C++ CLI executable source |
| `AeostaraCoreTests/` | `tests/AeostaraCoreTests/` | Catch2 unit tests |
| `AeostaraArchitectureTests/` | `tests/AeostaraArchitectureTests/` | Architecture enforcement tests |
| `CLISmokeTests/` | `tests/CLISmokeTests/` | CLI smoke test scripts |
| `CMakeLists.txt` | `CMakeLists.txt` | Root CMake build file |
| `CMakePresets.json` | `CMakePresets.json` | CMake presets |
| `vcpkg.json` | `vcpkg.json` | vcpkg dependency manifest |
| `tests_CMakeLists.txt` | `tests/CMakeLists.txt` | Test CMake file |
| `ForsettiBridge.h` | `platform/macos/ForsettiBridge.h` | Forsetti bridge stub |
| `Resources/` | `Resources/` | Test fixture copies |
| `Scripts/` | `Scripts/` | Build/compliance scripts |

## Status

**Non-compliant. Do not include in build or ship.**
