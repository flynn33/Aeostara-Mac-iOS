# Aeostara for macOS — Platform Details

**Status**: Source-complete (Swift/SwiftPM), build-unverified

Native Swift reimplementation of the Aeostara deterministic JSON configuration drift detection and healing platform for macOS, compliant with Apple Forsetti framework requirements.

## Architecture

```
AeostaraMacCLI (executable target)
  └── AeostaraMacServices (Swift module — platform I/O)
        └── AeostaraMacDomain (Swift module — healing logic)
              └── Foundation (JSON, FileManager, Date)
```

- **AeostaraMacDomain**: 11 contracts, 9 algorithms, 5 protocols — full healing engine in pure Swift
- **AeostaraMacServices**: Platform-specific I/O (FileManager-based config adapter, filesystem)
- **AeostaraMacCLI**: `validate`, `diff`, `heal` commands matching spec behavior parity
- **XCTest**: Fixture-driven test suite covering all 5 acceptance scenarios

## Build Requirements

- macOS 13.0+
- Xcode 15+ or Swift 5.9+ toolchain
- No external dependencies (Foundation only)

## Build

```bash
swift build
```

## Test

```bash
swift test
```

## CLI Usage

```bash
swift run AeostaraMacCLI validate <config> --desired <desired> [--invariants <invariants>]
swift run AeostaraMacCLI diff    <config> --desired <desired> [--invariants <invariants>]
swift run AeostaraMacCLI heal    <config> --desired <desired> [--invariants <invariants>] [--audit <audit.jsonl>]
```

Exit codes: 0 = success/no drift, 1 = drift/policy blocked, 2 = error

## Compliance

- Swift-native — no C++, no Objective-C++, no interpreted runtime
- JSON-only configuration scope (Foundation JSONSerialization)
- No Python or YAML in shipped product
- Forsetti-compliant (host-agnostic domain, protocol-first, all classes final)
- ASH-inspired healing semantics
- Deterministic outputs across platforms
- No third-party dependencies
