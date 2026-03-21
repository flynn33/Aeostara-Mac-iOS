# Policy Evaluation

Evaluates invariant rules against a repair plan and desired state to determine if repair should proceed.

## evaluatePolicy(plan, invariants, desiredState) → PolicyDecision

```
FOR EACH invariant IN invariants:
  IF invariant.severity == Critical AND NOT invariant.autoRemediate:
    expressionHolds ← evaluateExpression(invariant.expression, desiredState)
    IF NOT expressionHolds:
      RETURN PolicyDecision(
        allowed = false,
        reason = "Critical non-auto-remediate invariant violated: " + invariant.name
      )

RETURN PolicyDecision(allowed = true, reason = "")
```

## evaluateExpression(expression, flattenedState) → Boolean

Expression format: `key.path operator value`

Supported operators: `==`, `!=`, `>`, `<`, `>=`, `<=`

```
FUNCTION evaluateExpression(expression, state) → Boolean:
  parsed ← parseExpression(expression)
  // parsed = { keyPath, operator, expectedValue }

  actualValue ← state[parsed.keyPath]
  IF actualValue is undefined:
    RETURN false

  SWITCH parsed.operator:
    CASE "==": RETURN actualValue == parsed.expectedValue
    CASE "!=": RETURN actualValue != parsed.expectedValue
    CASE ">":  RETURN actualValue > parsed.expectedValue
    CASE "<":  RETURN actualValue < parsed.expectedValue
    CASE ">=": RETURN actualValue >= parsed.expectedValue
    CASE "<=": RETURN actualValue <= parsed.expectedValue
    DEFAULT:   RETURN false
```

## parseExpression(expression) → ParsedExpression

```
// Split on operator tokens
// Example: "server.port == 8080"
// Result: { keyPath: "server.port", operator: "==", expectedValue: 8080 }

operators ← ["==", "!=", ">=", "<=", ">", "<"]

FOR EACH op IN operators (longest first):
  IF expression contains op:
    parts ← split(expression, op)
    keyPath ← trim(parts[0])
    rawValue ← trim(parts[1])
    expectedValue ← parseValue(rawValue)  // string, number, or boolean
    RETURN { keyPath, operator: op, expectedValue }

ERROR "Invalid expression: " + expression
```
