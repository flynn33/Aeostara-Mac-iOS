# Changelog

All notable changes to Aeostara will be documented in this file.

## [0.2.0] - 2026-03-21

### Added

- **Specification-first branch model**: `main` holds platform-agnostic specs, `platform/*` branches hold native implementations
- **11 JSON Schema contract definitions** in `specs/contracts/`
- **9 pseudo code algorithm specs** in `specs/algorithms/` (healing flow, drift analysis, repair planning, etc.)
- **5 interface pseudo code specs** in `specs/interfaces/` (IHealingEngine, IConfigAdapter, IBackupProvider, IAuditSink, IFileSystem)
- **Architecture documents** in `specs/architecture/` (boundaries, branching strategy, compliance rules, native target architecture)
- **Acceptance targets and compliance checklist** in `specs/acceptance/`
- **Shared test fixtures** in `fixtures/`
- **CI scripts** (Python) for schema validation, acceptance testing, and compliance checking
- **Platform branches**: `platform/windows` (full implementation), `platform/macos` (implemented), `platform/ios` (alpha)

### Changed

- Renamed `master` branch to `main`
- `main` branch now contains only specifications (no compilable source code)
- All C++20 source code moved to `platform/windows` branch

## [0.1.0] - 2026-03-20

### Added

- **Core Contracts**: 11 structs (ObservedState, DesiredState, EncodedState, DriftEvent, RepairAction, RepairPlan, VerificationResult, RollbackPlan, AuditEvent, ModuleManifest, Invariant) with nlohmann/json serialization
- **JsonPath**: Dot-path get/set/exists/flatten/unflatten for nested JSON
- **InvariantParser**: Load invariant rules from JSON files
- **DriftAnalyzer**: Compare encoded states, emit ValueChanged/KeyAdded/KeyRemoved drift events
- **RepairPlanner**: Generate deterministic repair plans with FNV-1a hashed plan IDs
- **PolicyEvaluator**: Expression-based invariant evaluation (==, !=, >, <, >=, <=) gating repair execution
- **BackupManager**: Timestamped file backups via IFileSystem abstraction
- **Verifier**: Post-repair verification against desired state and invariants
- **RollbackManager**: Automatic rollback from backup on verification failure
- **JsonLinesAuditTrail**: Append-only .jsonl audit logging
- **JsonConfigAdapter**: JSON config file read/encode/repair adapter
- **HealingEngine**: Central orchestrator implementing the full healing flow
- **CLI**: `aeostara validate|diff|heal` commands with `--desired`, `--invariants`, `--audit` options
- **Module-ready interfaces**: IHealingEngine, IConfigAdapter, IBackupProvider, IAuditSink, IFileSystem
- **CppUnitTest suite**: 14 test files covering all core components and 5 acceptance scenarios
- **Architecture enforcement tests**: Verify no Forsetti includes, all classes final, correct namespace, copyright headers
- **PowerShell verification scripts**: verify-aeostara-guardrails.ps1, check-architecture.ps1

### Technical Details

- C++20, CMake 3.28+, MSVC 2022, vcpkg
- Single dependency: nlohmann/json
- /W4 /WX (warnings as errors)
- JSON-only configuration scope
- Namespace: `Aeostara` (standalone, no Forsetti dependency)
