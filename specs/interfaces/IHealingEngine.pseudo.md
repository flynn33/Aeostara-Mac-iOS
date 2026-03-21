# IHealingEngine Interface

Top-level abstract interface for the healing engine. Designed to parallel the Forsetti module interface shape for future hosting.

## Methods

### validate(configPath, desiredPath, invariantsPath) → ValidationResult

Parse and validate a config file, detect drift and invariant violations.

**Parameters:**
- `configPath` (string) — path to the configuration file
- `desiredPath` (string) — path to the desired state file
- `invariantsPath` (string) — path to the invariant rules file (optional, may be empty)

**Returns:** ValidationResult
- `valid` (boolean) — true if no drift detected
- `errors` (list of string) — parse or load errors
- `drifts` (list of DriftEvent) — detected drifts
- `violations` (list of InvariantViolation) — invariant violations

### diff(configPath, desiredPath, invariantsPath) → DiffResult

Show drift events and a proposed deterministic repair plan.

**Parameters:** same as validate

**Returns:** DiffResult
- `drifts` (list of DriftEvent) — detected drifts
- `proposedPlan` (RepairPlan) — the proposed repair plan

### heal(configPath, desiredPath, invariantsPath, auditPath) → HealResult

Execute the full healing flow: backup, repair, verify, rollback on failure.

**Parameters:**
- `configPath` (string) — path to the configuration file
- `desiredPath` (string) — path to the desired state file
- `invariantsPath` (string) — path to the invariant rules file (optional)
- `auditPath` (string) — path to the audit trail file

**Returns:** HealResult
- `success` (boolean) — true if heal completed successfully
- `executedPlan` (RepairPlan) — the plan that was executed
- `verification` (VerificationResult) — result of post-repair verification
- `rollback` (RollbackPlan, optional) — rollback plan if triggered
- `auditEvents` (list of AuditEvent) — all audit events generated
- `message` (string) — human-readable outcome message
