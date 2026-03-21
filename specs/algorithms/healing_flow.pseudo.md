# Healing Flow

The complete 15-step deterministic healing flow orchestrated by HealingEngine.

## heal(configPath, desiredPath, invariantsPath, auditPath)

```
1.  observed ← adapter.observe(configPath)
    // Parse the config file into an ObservedState
    // On failure: RETURN failure("Cannot load config")

2.  desired ← loadJSON(desiredPath)
    // Parse the desired state file into a DesiredState
    // On failure: RETURN failure("Cannot load desired state")

3.  invariants ← parseInvariants(invariantsPath)
    // Load invariant rules from file (optional — empty list if not provided)

4.  encoded ← adapter.encode(observed, desired)
    // Flatten both states into dot-path maps for comparison

5.  drifts ← analyzeDrift(encoded)
    // Compare encoded.observed vs encoded.desired key by key

6.  IF drifts is empty:
      audit("NoDrift", configPath)
      RETURN success("No drift detected")

7.  plan ← generateRepairPlan(drifts)
    // Convert each drift into a RepairAction, assign FNV-1a plan ID

8.  violations ← evaluatePolicy(plan, invariants, encoded.desired)
    // Check if any non-auto-remediatable invariants would be violated

9.  IF violations exist:
      audit("PolicyBlocked", configPath, violations)
      RETURN blocked("Policy blocked: " + reason)

10. audit("HealStarted", configPath, planID)

11. backupPath ← backup.createBackup(configPath)
    audit("BackupCreated", configPath, backupPath)

12. applied ← adapter.applyRepair(configPath, plan)
    IF NOT applied:
      rollback(backupPath, configPath)
      audit("RollbackExecuted", configPath, "Repair apply failed")
      RETURN failure("Repair apply failed, rolled back")
    audit("RepairApplied", configPath, planID)

13. verification ← verify(configPath, desired, invariants)
    // Re-read the repaired file and check against desired + invariants

14. IF verification.success:
      audit("VerificationSucceeded", configPath, planID)
      RETURN success(plan, verification)

15. ELSE:
      audit("VerificationFailed", configPath, failedChecks)
      rollback(backupPath, configPath)
      audit("RollbackExecuted", configPath, "Verification failed")
      RETURN failure("Verification failed, rolled back to backup")
```

## validate(configPath, desiredPath, invariantsPath)

```
1. observed ← adapter.observe(configPath)
2. desired ← loadJSON(desiredPath)
3. invariants ← parseInvariants(invariantsPath)
4. encoded ← adapter.encode(observed, desired)
5. drifts ← analyzeDrift(encoded)
6. violations ← checkInvariants(invariants, encoded.observed)
7. valid ← (drifts is empty)
8. RETURN ValidationResult(valid, errors, drifts, violations)
```

## diff(configPath, desiredPath, invariantsPath)

```
1. observed ← adapter.observe(configPath)
2. desired ← loadJSON(desiredPath)
3. encoded ← adapter.encode(observed, desired)
4. drifts ← analyzeDrift(encoded)
5. plan ← generateRepairPlan(drifts)
6. RETURN DiffResult(drifts, plan)
```
