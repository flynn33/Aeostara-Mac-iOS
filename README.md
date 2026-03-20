# Aeostara

**Self-Healing Configuration Platform** - v0.1.0

Aeostara is a deterministic JSON configuration drift detection and healing engine. It observes live configuration, compares it against a declared desired state, detects drift, evaluates invariant policy, and executes repairs with backup, verification, rollback, and audit trail.

Copyright (c) 2026 James Daley. All Rights Reserved.
Proprietary and Confidential.

## Features

- **Drift Detection** - Compare live config against desired state, producing structured drift events
- **Invariant Policy** - Define rules (e.g., "database.port == 5432") that gate repair execution
- **Deterministic Repair Plans** - Sorted, hashed repair actions with FNV-1a plan IDs
- **Backup & Rollback** - Timestamped backups before repair; automatic rollback on verification failure
- **Verification** - Post-repair verification against desired state and invariants
- **JSON Lines Audit Trail** - Append-only audit log of all healing operations
- **Module-Ready Interfaces** - IHealingEngine, IConfigAdapter, IBackupProvider, IAuditSink for future extensibility

## Requirements

- **Windows 10/11** with Visual Studio 2022
- **CMake 3.28+**
- **vcpkg** (for nlohmann/json dependency)
- **MSVC** C++20 compiler

## Build

```powershell
# Configure
cmake --preset debug

# Build
cmake --build --preset debug

# Test
ctest --preset debug
```

## CLI Usage

```
aeostara validate <config> --desired <desired> [--invariants <invariants>]
aeostara diff    <config> --desired <desired> [--invariants <invariants>]
aeostara heal    <config> --desired <desired> [--invariants <invariants>] [--audit <audit.jsonl>]
```

### Commands

| Command    | Description                                                  | Exit Code |
|------------|--------------------------------------------------------------|-----------|
| `validate` | Parse and validate config, check for drift and invariants    | 0=valid, 1=drift, 2=error |
| `diff`     | Show drift events and proposed repair plan                   | 0=no drift, 1=drift, 2=error |
| `heal`     | Execute full healing flow with backup, repair, verification  | 0=success, 1=blocked, 2=error |

### Examples

```powershell
# Validate a config file
aeostara validate config.json --desired desired_state.json --invariants rules.json

# Show drift between configs
aeostara diff config.json --desired desired_state.json

# Heal with audit trail
aeostara heal config.json --desired desired_state.json --invariants rules.json --audit audit.jsonl
```

## Architecture

```
AeostaraCLI (exe)
  └─→ AeostaraCore (static lib)
        ├── IHealingEngine ← HealingEngine (orchestrator)
        ├── IConfigAdapter ← JsonConfigAdapter
        ├── DriftAnalyzer, RepairPlanner, PolicyEvaluator
        ├── IBackupProvider ← BackupManager
        ├── Verifier, RollbackManager
        ├── IAuditSink ← JsonLinesAuditTrail
        ├── IFileSystem ← DefaultFileSystem
        └── Contracts (11 structs), JsonPath, InvariantParser
```

One-way dependency: CLI → Core → nlohmann/json. No reverse dependencies.

## Invariant Rule Format

```json
[
  {
    "invariant_id": "INV-001",
    "name": "Database Port Standard",
    "description": "Database port must be 5432",
    "severity": "high",
    "expression": "database.port == 5432",
    "applies_to": ["database"],
    "auto_remediate": true
  }
]
```

Supported operators: `==`, `!=`, `>`, `<`, `>=`, `<=`

## Verification

```powershell
# Run guardrails verification
powershell -ExecutionPolicy Bypass -File Scripts/verify-aeostara-guardrails.ps1

# Run architecture check
powershell -ExecutionPolicy Bypass -File Scripts/check-architecture.ps1
```

## Compliance

- **C++20 native** — standalone Windows executable, no interpreted runtime
- **JSON-only** — all configuration files are JSON; no YAML parser included
- **No Python dependency** — build, test, and run require only MSVC, CMake, and vcpkg
- **Forsetti-compliant** — R001 (approved dependencies only), R005 (interface-first, all types final)
- **ASH-inspired** — healing semantics follow the Aeostara Self-Healing architectural pattern
- **Host-agnostic core** — AeostaraCore has no Forsetti runtime coupling; future hosting via adapter

## License

Proprietary. All rights reserved. See [LICENSE.md](LICENSE.md).
