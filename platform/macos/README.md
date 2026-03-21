# Aeostara for macOS

**Status**: Implemented v0.1.0

Deterministic JSON configuration drift detection and healing platform — macOS native implementation.

## Architecture

```
AeostaraCLI (executable)
  └── AeostaraCore (static library)
        └── nlohmann/json (vcpkg)
```

- **AeostaraCore**: 11 contracts, 9 algorithms, 5 interfaces — full healing engine
- **AeostaraCLI**: `validate`, `diff`, `heal` commands matching Windows behavioral parity
- **Catch2**: Fixture-driven test suite covering all 5 acceptance scenarios

## Build Requirements

- macOS 13.0+
- Apple Clang (Xcode Command Line Tools)
- CMake 3.28+
- Ninja build system
- vcpkg (for nlohmann/json and Catch2)

## Build

```bash
export VCPKG_ROOT=/path/to/vcpkg
cmake --preset debug
cmake --build --preset debug
```

## Test

```bash
ctest --preset debug
```

## CLI Usage

```bash
aeostara validate <config> --desired <desired> [--invariants <invariants>]
aeostara diff    <config> --desired <desired> [--invariants <invariants>]
aeostara heal    <config> --desired <desired> [--invariants <invariants>] [--audit <audit.jsonl>]
```

Exit codes: 0 = success/no drift, 1 = drift/policy blocked, 2 = error

## Compliance

- C++20 native — no interpreted runtime
- JSON-only configuration scope
- No Python or YAML in shipped product
- Forsetti-compliant (host-agnostic core, interface-first, all types final)
- ASH-inspired healing semantics
- Deterministic outputs across platforms
