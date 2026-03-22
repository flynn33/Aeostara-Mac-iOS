# Apple Platform Policy Supplement — macOS

## Scope

This document supplements the root `agentic-coding-policy.json` with Apple-native Forsetti compliance rules for the `platform/macos` branch.

## Required Toolchain

| Component | Required |
|-----------|----------|
| Language | Swift (latest stable) |
| UI framework | SwiftUI (if UI is used) |
| Build system | SwiftPM (Package.swift) or Xcode-native project |
| Dependencies | Foundation only — no third-party packages in shipped product |
| Test framework | XCTest |
| JSON handling | Foundation JSONSerialization / JSONDecoder / JSONEncoder |
| File I/O | Foundation FileManager |

## Forbidden in Shipped Product Paths

| Forbidden | Reason |
|-----------|--------|
| C++ source files (`.cpp`, `.hpp`, `.h`, `.cc`, `.cxx`) | R001: Swift-only |
| Objective-C++ files (`.mm`) | R001: no bridging layer |
| CMake, CMakeLists.txt, CMakePresets.json | R001: Xcode-native/SwiftPM only |
| vcpkg, vcpkg.json | R001: no third-party package managers |
| nlohmann/json | R001: use Foundation JSON APIs |
| Catch2 | R001: use XCTest |
| Python runtime | R001: no interpreted runtimes |
| YAML parser | R001: JSON-only for v0.1 |
| Forsetti SDK/headers in domain | Host-agnostic domain requirement |
| Boost or non-Apple third-party | R001 compliance |
| Globals, singletons, mutable statics | R005: initializer DI only |

## Allowed Exceptions

| Exception | Scope |
|-----------|-------|
| Python scripts | CI automation only (`.github/`, `ci/`) |
| YAML files | GitHub Actions workflows only (`.github/workflows/`) |
| Shell scripts | Build/compliance automation (`Scripts/`) |
| C++/Obj-C++ artifacts | `_quarantine/` directory only (reference, non-shipped) |

## Compliance Scanning

Source file extensions checked in shipped paths: `.swift`

Patterns scanned:
- Python references (`python`, `Python`, `.py`) in Swift sources
- YAML references (`yaml`, `YAML`, `.yml`, `yaml-cpp`) in Swift sources
- Forsetti imports (`import Forsetti`, `ForsettiCore`, `ForsettiPlatform`)
- C/C++ imports (`#include`, `#import`) in any shipped-path file
- Domain-to-CLI/App reverse dependency
- Missing copyright headers

## Architectural Invariants

1. All concrete classes must be `final`
2. All dependencies injected via initializer (protocol-based DI)
3. Domain module has no UI or platform-specific imports (Foundation only)
4. One-way dependency: CLI → Services → Domain → Foundation
5. Every mutation path requires backup + rollback capability
6. Deterministic outputs: same input produces same output on all platforms
7. Copyright header: `Copyright (c) 2026 James Daley. All Rights Reserved.`
8. Contracts are `Codable` structs — no class-based data models
9. FNV-1a hash computed in pure Swift — no C dependency
