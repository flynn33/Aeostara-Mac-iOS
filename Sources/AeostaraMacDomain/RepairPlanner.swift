// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Converts drift events into a deterministic repair plan with FNV-1a hashed plan ID.
public final class RepairPlanner {

    public init() {}

    /// Generate a repair plan from a list of drift events.
    public func generateRepairPlan(drifts: [DriftEvent], timestamp: String) -> RepairPlan {
        var actions: [RepairAction] = []

        for drift in drifts {
            switch drift.type {
            case .valueChanged:
                actions.append(RepairAction(
                    keyPath: drift.keyPath,
                    actionType: .set,
                    fromValue: drift.observedValue,
                    toValue: drift.desiredValue,
                    rationale: "Value changed from observed to desired"
                ))
            case .keyAdded:
                actions.append(RepairAction(
                    keyPath: drift.keyPath,
                    actionType: .add,
                    fromValue: nil,
                    toValue: drift.desiredValue,
                    rationale: "Key missing in observed, adding from desired"
                ))
            case .keyRemoved:
                actions.append(RepairAction(
                    keyPath: drift.keyPath,
                    actionType: .remove,
                    fromValue: drift.observedValue,
                    toValue: nil,
                    rationale: "Key not in desired, removing from observed"
                ))
            }
        }

        let planID = computePlanID(actions: actions)

        return RepairPlan(
            planID: planID,
            actions: actions,
            timestamp: timestamp,
            requiresBackup: true
        )
    }

    /// Compute a deterministic plan ID using FNV-1a hash of serialized actions.
    private func computePlanID(actions: [RepairAction]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(actions) else {
            return "error-computing-plan-id"
        }
        let hash = FNV1a.hash64(data: data)
        return String(hash, radix: 16, uppercase: false)
    }
}

// MARK: - FNV-1a Hash

/// FNV-1a 64-bit hash implementation for deterministic plan ID generation.
public enum FNV1a {
    private static let offsetBasis: UInt64 = 0xcbf29ce484222325
    private static let prime: UInt64 = 0x100000001b3

    public static func hash64(data: Data) -> UInt64 {
        var hash = offsetBasis
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }

    public static func hash64(string: String) -> UInt64 {
        return hash64(data: Data(string.utf8))
    }
}
