# Native Target Architecture

## Model

Aeostara is structured as:
- **Shared specifications** on `main` — language-agnostic contract schemas, pseudo code algorithms, interface definitions
- **Platform implementations** on `platform/*` branches — native code implementing the specs

## Shared Spec Responsibilities

The specifications on `main` define:
- 11 contract data types (JSON Schema)
- 9 algorithms (pseudo code)
- 5 interfaces (pseudo code)
- Acceptance scenarios
- Compliance rules

## Platform Implementation Responsibilities

Each `platform/*` branch independently implements:
- All 11 contracts in the platform's native language
- All algorithms following the pseudo code specifications
- All 5 interfaces with platform-appropriate implementations
- Platform-specific shell (CLI, GUI, or mobile app)
- Platform-specific build and test infrastructure

## Implementation Languages

| Platform | Language | Build System | Test Framework |
|----------|----------|-------------|----------------|
| Windows | C++20 | CMake + MSVC | CppUnitTest |
| macOS | C++/Swift/Obj-C | CMake/Xcode | TBD |
| iOS | Swift + C++ bridging | Xcode | XCTest |

## Shared Test Fixtures

JSON test fixtures in `fixtures/` are shared across all platforms via merge from `main`. All platforms test against the same input data to ensure deterministic cross-platform behavior.
