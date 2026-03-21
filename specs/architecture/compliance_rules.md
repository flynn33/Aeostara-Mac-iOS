# Compliance Rules

## Shipped Product Rules

1. **Native only** — shipped product must be a native compiled binary
2. **No Python** — shipped product must not depend on Python runtime
3. **No YAML** — shipped product must not include a YAML parser
4. **JSON-only v0.1** — all configuration files are JSON
5. **Host-agnostic core** — core healing logic has no platform UI dependencies
6. **Interface-based Forsetti** — Forsetti integration via interfaces, not direct coupling

## Repository Automation (Exempt)

Python and YAML are permitted in:
- GitHub Actions workflows (`.github/workflows/`)
- CI scripts (`ci/`)
- Repository automation scripts (`.github/scripts/`)

These are not part of the shipped product.

## Per-Platform Rules

### Windows (platform/windows)
- R001: Only MSVC, CMake, vcpkg, nlohmann/json, CppUnitTest, Windows SDK, WinUI 3
- R005: Interface-first design, all concrete types `final`, constructor DI
- /W4 /WX (warnings as errors)

### macOS (platform/macos)
- Native toolchain: Clang/Xcode, CMake or Xcode native
- Same dependency constraints adapted to Apple ecosystem

### iOS (platform/ios)
- Native toolchain: Xcode, Swift + C++ bridging
- Same dependency constraints adapted to iOS ecosystem
