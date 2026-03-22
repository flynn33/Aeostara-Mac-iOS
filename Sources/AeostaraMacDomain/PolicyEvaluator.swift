// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Evaluates invariant rules against a repair plan and desired state.
public final class PolicyEvaluator {

    public init() {}

    /// Evaluate whether a repair plan is allowed given invariant rules and the desired state.
    /// Critical non-auto-remediatable invariants that would be violated block the plan.
    public func evaluatePolicy(plan: RepairPlan, invariants: [Invariant], desiredState: [String: AnyCodable]) -> PolicyDecision {
        let desiredFlat = flattenAnyCodable(desiredState)

        for invariant in invariants {
            if invariant.severity == .critical && !invariant.autoRemediate {
                let holds = evaluateExpression(invariant.expression, state: desiredFlat)
                if !holds {
                    return PolicyDecision(
                        allowed: false,
                        reason: "Critical non-auto-remediate invariant violated: \(invariant.name)"
                    )
                }
            }
        }

        return PolicyDecision(allowed: true, reason: "")
    }

    /// Check invariants against a flattened state, returning descriptions of violated invariants.
    public func checkInvariants(_ invariants: [Invariant], state: [String: AnyCodable]) -> [String] {
        let flat = flattenAnyCodable(state)
        var violations: [String] = []
        for invariant in invariants {
            if !evaluateExpression(invariant.expression, state: flat) {
                violations.append("Invariant violated: \(invariant.name) (\(invariant.expression))")
            }
        }
        return violations
    }

    /// Evaluate a single expression string against a flattened state.
    /// Expression format: "key.path operator value"
    /// Supported operators: ==, !=, >=, <=, >, <
    public func evaluateExpression(_ expression: String, state: [String: Any]) -> Bool {
        guard let parsed = parseExpression(expression) else { return false }

        guard let actualValue = state[parsed.keyPath] else { return false }

        return compare(actual: actualValue, op: parsed.op, expected: parsed.expectedValue)
    }

    // MARK: - Private

    private struct ParsedExpression {
        let keyPath: String
        let op: String
        let expectedValue: Any
    }

    private func parseExpression(_ expression: String) -> ParsedExpression? {
        // Try operators longest-first to avoid matching ">" before ">="
        let operators = ["==", "!=", ">=", "<=", ">", "<"]

        for op in operators {
            guard let range = expression.range(of: " \(op) ") else { continue }

            let keyPath = String(expression[expression.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(expression[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            let expectedValue = parseValue(rawValue)

            return ParsedExpression(keyPath: keyPath, op: op, expectedValue: expectedValue)
        }

        return nil
    }

    private func parseValue(_ raw: String) -> Any {
        // Boolean
        if raw == "true" { return true }
        if raw == "false" { return false }

        // Quoted string
        if raw.hasPrefix("\"") && raw.hasSuffix("\"") {
            return String(raw.dropFirst().dropLast())
        }

        // Integer
        if let intVal = Int(raw) { return intVal }

        // Double
        if let doubleVal = Double(raw) { return doubleVal }

        // Fallback: treat as string
        return raw
    }

    private func compare(actual: Any, op: String, expected: Any) -> Bool {
        // Unwrap AnyCodable if needed
        let actualUnwrapped = (actual as? AnyCodable)?.value ?? actual
        let expectedUnwrapped = (expected as? AnyCodable)?.value ?? expected

        switch op {
        case "==":
            return isEqual(actualUnwrapped, expectedUnwrapped)
        case "!=":
            return !isEqual(actualUnwrapped, expectedUnwrapped)
        case ">":
            return numericCompare(actualUnwrapped, expectedUnwrapped) == .orderedDescending
        case "<":
            return numericCompare(actualUnwrapped, expectedUnwrapped) == .orderedAscending
        case ">=":
            let result = numericCompare(actualUnwrapped, expectedUnwrapped)
            return result == .orderedDescending || result == .orderedSame
        case "<=":
            let result = numericCompare(actualUnwrapped, expectedUnwrapped)
            return result == .orderedAscending || result == .orderedSame
        default:
            return false
        }
    }

    private func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        switch (lhs, rhs) {
        case let (l as Bool, r as Bool): return l == r
        case let (l as Int, r as Int): return l == r
        case let (l as Double, r as Double): return l == r
        case let (l as String, r as String): return l == r
        case let (l as Int, r as Double): return Double(l) == r
        case let (l as Double, r as Int): return l == Double(r)
        case (is NSNull, is NSNull): return true
        default: return false
        }
    }

    private func numericCompare(_ lhs: Any, _ rhs: Any) -> ComparisonResult {
        let lDouble = toDouble(lhs)
        let rDouble = toDouble(rhs)

        guard let l = lDouble, let r = rDouble else {
            // String comparison fallback
            if let ls = lhs as? String, let rs = rhs as? String {
                return ls.compare(rs)
            }
            return .orderedSame
        }

        if l < r { return .orderedAscending }
        if l > r { return .orderedDescending }
        return .orderedSame
    }

    private func toDouble(_ value: Any) -> Double? {
        switch value {
        case let i as Int: return Double(i)
        case let d as Double: return d
        case let s as String: return Double(s)
        default: return nil
        }
    }

    private func flattenAnyCodable(_ dict: [String: AnyCodable]) -> [String: Any] {
        let unwrapped = dict.mapValues { $0.value }
        return JsonPath.flatten(unwrapped)
    }
}
