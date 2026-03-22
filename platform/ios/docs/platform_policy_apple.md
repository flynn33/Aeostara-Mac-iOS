# Apple Platform Policy Supplement — iOS

## Scope

This document supplements the root `agentic-coding-policy.json` with Apple-native Forsetti compliance rules for the `platform/ios` branch.

## Required Toolchain

| Component | Required |
|-----------|----------|
| Language | Swift (latest stable) |
| UI framework | SwiftUI |
| Build system | SwiftPM (Package.swift) or Xcode-native project |
| Dependencies | Foundation only — no third-party packages in shipped product |
| Test framework | XCTest, XCUITest |
| JSON handling | Foundation JSONSerialization / JSONDecoder / JSONEncoder |
| File I/O | Foundation FileManager |
| Deployment target | iOS 16.0+ |

## Forbidden in Shipped Product Paths

| Forbidden | Reason |
|-----------|--------|
| C++ source files (`.cpp`, `.hpp`, `.h`, `.cc`, `.cxx`) | R001: Swift-only |
| Objective-C++ files (`.mm`) | R001: no bridging layer |
| CMake, CMakeLists.txt | R001: Xcode-native/SwiftPM only |
| vcpkg, nlohmann/json | R001: use Foundation JSON APIs |
| Catch2 | R001: use XCTest |
| Python runtime | R001: no interpreted runtimes |
| YAML parser | R001: JSON-only for v0.1 |
| Forsetti SDK/headers in domain | Host-agnostic domain requirement |
| Globals, singletons, mutable statics | R005: initializer DI only |

## iOS-Specific Constraints

- All file operations occur within the app sandbox
- Config files imported via document picker, copied to app container
- Backups stored in `Documents/backups/`
- Audit trail stored in `Documents/audit/`
- Healing logic is fully in Swift (AeostaraDomain module)
- SwiftUI views bind to ViewModel which calls domain protocols

## Allowed Exceptions

| Exception | Scope |
|-----------|-------|
| Python scripts | CI automation only (`.github/`, `ci/`) |
| YAML files | GitHub Actions workflows only (`.github/workflows/`) |
| C++/Obj-C++ artifacts | `_quarantine/` directory only (reference, non-shipped) |

## Architectural Invariants

1. All concrete classes must be `final`
2. All dependencies injected via initializer (protocol-based DI)
3. Domain module has no UI imports (Foundation only)
4. One-way dependency: App/Views → ViewModel → Services → Domain → Foundation
5. Every mutation path requires backup + rollback capability
6. Deterministic outputs: same input produces same output on all platforms
7. Copyright header: `Copyright (c) 2026 James Daley. All Rights Reserved.`
8. Contracts are `Codable` structs — no class-based data models
