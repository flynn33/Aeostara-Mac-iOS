# Acceptance Targets

All downstream implementations must satisfy these ASH-conformance behaviors.

## Core Behavioral Scenarios

### 1. Semantically stable despite superficial drift

Expected outcome:

- `StateValidityDiagnostic.isValid = true`
- `SystemStateClass = STABLE`
- `RecoveryCategory = NO_ACTION`

### 2. Semantically unstable despite minimal/no superficial drift

Expected outcome:

- diagnostic indicates non-valid state
- `SystemStateClass in {UNSTABLE, CORRECTABLE}`
- `RecoveryCategory in {NORMALIZE_STATE, APPLY_CORRECTION}`

### 3. Correction blocked; fallback selected

Expected outcome:

- policy or correction-path block present
- `RecoveryCategory = FALLBACK_REQUIRED`
- `FallbackDecision.selectionOutcome = SELECTED`

### 4. Fallback unavailable; containment entered

Expected outcome:

- fallback selection unable to choose candidate
- containment decision enters restricted mode

### 5. Containment breach; safe halt entered

Expected outcome:

- `SafeHaltDecision.enterSafeHalt = true`
- terminal semantics asserted

### 6. Post-execution verification failure triggers rollback/escalation

Expected outcome:

- verification failure captured
- rollback and/or escalation path executed deterministically

### 7. Policy gate blocks unsafe action before mutation

Expected outcome:

- blocked outcome returned before actuator mutation
- policy/audit records present

## Determinism Requirements

For identical inputs, diagnostics, classification, recovery category, and plan shape must be identical.
