# Repair Planning

Converts drift events into a deterministic repair plan with a FNV-1a hashed plan ID.

## generateRepairPlan(drifts) → RepairPlan

```
actions ← empty list

FOR EACH drift IN drifts:
  SWITCH drift.type:
    CASE ValueChanged:
      actions.add(RepairAction(
        keyPath = drift.keyPath,
        actionType = Set,
        fromValue = drift.observedValue,
        toValue = drift.desiredValue,
        rationale = "Value changed from observed to desired"
      ))
    CASE KeyAdded:
      actions.add(RepairAction(
        keyPath = drift.keyPath,
        actionType = Add,
        fromValue = null,
        toValue = drift.desiredValue,
        rationale = "Key missing in observed, adding from desired"
      ))
    CASE KeyRemoved:
      actions.add(RepairAction(
        keyPath = drift.keyPath,
        actionType = Remove,
        fromValue = drift.observedValue,
        toValue = null,
        rationale = "Key not in desired, removing from observed"
      ))

planID ← fnv1aHash(serialize(actions))
timestamp ← currentISO8601()

RETURN RepairPlan(
  planID = planID,
  actions = actions,
  timestamp = timestamp,
  requiresBackup = true
)
```

## FNV-1a Hash (for deterministic plan IDs)

```
FUNCTION fnv1aHash(data: bytes) → string:
  hash ← 0xcbf29ce484222325  // FNV offset basis (64-bit)
  prime ← 0x100000001b3       // FNV prime (64-bit)

  FOR EACH byte IN data:
    hash ← hash XOR byte
    hash ← hash * prime

  RETURN hexString(hash)
```
