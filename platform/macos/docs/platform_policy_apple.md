# Apple Platform Policy Supplement

## Scope

This document supplements the root `agentic-coding-policy.json` with Apple-native interpretations of Forsetti compliance rules. It applies to `platform/macos` and `platform/ios` branches.

## Allowed Toolchain

| Component | Allowed |
|-----------|---------|
| Compiler | Apple Clang (Xcode toolchain) |
| Standard | C++20 |
| Build system | CMake 3.28+ with Ninja or Xcode generator |
| Package manager | vcpkg |
| Dependencies | nlohmann/json (only non-platform dependency) |
| Test framework | Catch2 (macOS), XCTest (iOS) |
| iOS bridge | Objective-C++ (.mm files) |
| iOS UI | SwiftUI (Swift 5.9+) |

## Forbidden in Shipped Product

| Forbidden | Reason |
|-----------|--------|
| Python runtime | R001: no interpreted runtimes |
| YAML parser | R001: JSON-only for v0.1 |
| Forsetti SDK/headers in core | Host-agnostic core requirement |
| Forsetti lifecycle logic in healing engine | Core must remain standalone |
| Boost or non-Microsoft/non-Apple third-party | R001 compliance |
| Globals, singletons, mutable statics | R005: constructor DI only |

## Allowed Exceptions

| Exception | Scope |
|-----------|-------|
| Python scripts | CI automation only (`.github/`, `ci/`) |
| YAML files | GitHub Actions workflows only (`.github/workflows/`) |
| Shell scripts | Build/compliance automation (`Scripts/`) |

## Compliance Scanning

Source file extensions checked: `.h`, `.hpp`, `.cpp`, `.cc`, `.cxx`, `.m`, `.mm`, `.swift`

Patterns scanned:
- Python references (`python`, `Python`, `.py`)
- YAML references (`yaml`, `YAML`, `.yml`, `yaml-cpp`)
- Forsetti includes (`#include.*Forsetti`, `import Forsetti`)
- Forsetti namespace (`namespace Forsetti`)
- Core-to-CLI reverse dependency
- Missing copyright headers

## Architectural Invariants

1. All concrete classes must be `final`
2. All dependencies injected via constructor
3. `namespace Aeostara` exclusively (no `Forsetti` namespace)
4. One-way dependency: CLI/App → Core → nlohmann/json
5. Every mutation path requires backup + rollback capability
6. Deterministic outputs: same input → same output on all platforms
7. Copyright header: `Copyright (c) 2026 James Daley. All Rights Reserved.`
