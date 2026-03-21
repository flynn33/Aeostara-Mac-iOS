# Drift Analysis

Compares encoded observed and desired states to produce a list of DriftEvents.

## analyzeDrift(encoded) → List[DriftEvent]

```
drifts ← empty list

// Check for ValueChanged and KeyRemoved
FOR EACH (key, observedValue) IN encoded.observed:
  IF key NOT IN encoded.desired:
    drifts.add(DriftEvent(
      keyPath = key,
      type = KeyRemoved,
      observedValue = observedValue,
      desiredValue = null,
      description = "Key exists in observed but not in desired"
    ))
  ELSE IF observedValue != encoded.desired[key]:
    drifts.add(DriftEvent(
      keyPath = key,
      type = ValueChanged,
      observedValue = observedValue,
      desiredValue = encoded.desired[key],
      description = "Value differs between observed and desired"
    ))

// Check for KeyAdded
FOR EACH (key, desiredValue) IN encoded.desired:
  IF key NOT IN encoded.observed:
    drifts.add(DriftEvent(
      keyPath = key,
      type = KeyAdded,
      observedValue = null,
      desiredValue = desiredValue,
      description = "Key exists in desired but not in observed"
    ))

RETURN drifts
```

## hasDrift(encoded) → Boolean

```
RETURN analyzeDrift(encoded) is NOT empty
```
