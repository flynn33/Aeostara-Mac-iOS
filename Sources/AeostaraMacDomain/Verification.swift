// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Post-repair verification: re-reads the repaired config and validates against desired state and invariants.
public final class Verification {

    private let policyEvaluator: PolicyEvaluator

    public init(policyEvaluator: PolicyEvaluator) {
        self.policyEvaluator = policyEvaluator
    }

    /// Verify that a repaired config matches the desired state and satisfies invariants.
    public func verify(configPath: String, desired: DesiredState, invariants: [Invariant], fileSystem: IFileSystem, timestamp: String) -> VerificationResult {
        var failedChecks: [String] = []

        // Re-read the repaired config
        let repairedData: [String: Any]
        do {
            let content = try fileSystem.readFile(path: configPath)
            guard let data = content.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return VerificationResult(
                    success: false,
                    failedChecks: ["Cannot parse repaired config as JSON dictionary"],
                    verifiedAt: timestamp
                )
            }
            repairedData = parsed
        } catch {
            return VerificationResult(
                success: false,
                failedChecks: ["Cannot re-read repaired config: \(error.localizedDescription)"],
                verifiedAt: timestamp
            )
        }

        // Flatten both for comparison
        let repairedFlat = JsonPath.flatten(repairedData)
        let desiredFlat = JsonPath.flatten(desired.data.mapValues { $0.value })

        // Check all desired keys exist with correct values
        for key in desiredFlat.keys.sorted() {
            let expectedValue = desiredFlat[key]!
            if let actualValue = repairedFlat[key] {
                if !AnyCodable.valuesEqual(actualValue, expectedValue) {
                    failedChecks.append("Value mismatch after repair: \(key)")
                }
            } else {
                failedChecks.append("Missing key after repair: \(key)")
            }
        }

        // Check invariants hold
        for invariant in invariants {
            let holds = policyEvaluator.evaluateExpression(invariant.expression, state: repairedFlat)
            if !holds {
                failedChecks.append("Invariant violated after repair: \(invariant.name)")
            }
        }

        return VerificationResult(
            success: failedChecks.isEmpty,
            failedChecks: failedChecks,
            verifiedAt: timestamp
        )
    }
}

// MARK: - Value comparison helper

extension AnyCodable {
    /// Compare two Any values for equality (used in verification).
    static func valuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
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
}
