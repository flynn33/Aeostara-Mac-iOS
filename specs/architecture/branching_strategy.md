# Branching Strategy

## Branch Model

| Branch | Purpose |
|--------|---------|
| `main` | Specifications, contracts, pseudo code, architecture docs, CI scripts, test fixtures |
| `platform/windows` | Windows native implementation (C++20, MSVC, CppUnitTest) |
| `platform/macos` | macOS native implementation (scaffold) |
| `platform/ios` | iOS native implementation (scaffold) |

## Branch Responsibilities

### main
- JSON contract schemas
- Algorithm pseudo code
- Interface specifications
- Architecture documents
- Shared test fixtures
- CI/CD workflows (Python/YAML allowed)
- Acceptance targets
- Compliance rules

Must NOT contain:
- Compilable source code
- Platform-specific build systems
- Platform-specific UI or runtime code

### platform/* branches
Each platform branch contains:
- Native implementation of all contracts and algorithms
- Platform-specific build configuration
- Platform-specific test framework
- Platform-specific shell/UI
- Forsetti platform bridge (stub or implementation)
- Platform manifest

## Merge Policy

```
main (specs) ──→ platform/windows
              ──→ platform/macos
              ──→ platform/ios
```

- Spec changes on `main` merge DOWN into platform branches
- Platform code NEVER merges back to `main`
- Platform branches may diverge in implementation language and patterns
- All platform branches must pass the same acceptance targets

## Release Policy

Each platform branch is independently releasable once it passes:
1. Shared acceptance targets (from `specs/acceptance/`)
2. Platform-specific build validation
3. Shipped-product compliance validation (no Python, no YAML)
