# Verification

Post-repair verification: re-reads the repaired config and checks it matches the desired state and satisfies all invariants.

## verify(configPath, desired, invariants, fileSystem) → VerificationResult

```
FUNCTION verify(configPath, desired, invariants, fs) → VerificationResult:
  failedChecks ← empty list

  // Re-read the repaired config
  TRY:
    content ← fs.readFile(configPath)
    repairedData ← parseJSON(content)
  CATCH error:
    RETURN VerificationResult(
      success = false,
      failedChecks = ["Cannot re-read repaired config: " + error],
      verifiedAt = currentISO8601()
    )

  // Flatten both for comparison
  repairedFlat ← flatten(repairedData)
  desiredFlat ← flatten(desired.data)

  // Check all desired keys exist with correct values
  FOR EACH (key, expectedValue) IN desiredFlat:
    IF key NOT IN repairedFlat:
      failedChecks.add("Missing key after repair: " + key)
    ELSE IF repairedFlat[key] != expectedValue:
      failedChecks.add("Value mismatch after repair: " + key)

  // Check invariants hold
  FOR EACH invariant IN invariants:
    holds ← evaluateExpression(invariant.expression, repairedFlat)
    IF NOT holds:
      failedChecks.add("Invariant violated after repair: " + invariant.name)

  RETURN VerificationResult(
    success = (failedChecks is empty),
    failedChecks = failedChecks,
    verifiedAt = currentISO8601()
  )
```
