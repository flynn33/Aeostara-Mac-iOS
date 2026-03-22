// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation

/// Compares encoded observed and desired states to detect drift.
public final class DriftAnalyzer {

    public init() {}

    /// Analyze drift between encoded observed and desired states.
    /// Returns a list of DriftEvent describing all differences.
    public func analyzeDrift(encoded: EncodedState) -> [DriftEvent] {
        var drifts: [DriftEvent] = []

        let observedFlat = encoded.observed
        let desiredFlat = encoded.desired

        // Check for ValueChanged and KeyRemoved
        for key in observedFlat.keys.sorted() {
            let observedValue = observedFlat[key]!
            if let desiredValue = desiredFlat[key] {
                if observedValue != desiredValue {
                    drifts.append(DriftEvent(
                        keyPath: key,
                        type: .valueChanged,
                        observedValue: observedValue,
                        desiredValue: desiredValue,
                        description: "Value differs between observed and desired"
                    ))
                }
            } else {
                drifts.append(DriftEvent(
                    keyPath: key,
                    type: .keyRemoved,
                    observedValue: observedValue,
                    desiredValue: nil,
                    description: "Key exists in observed but not in desired"
                ))
            }
        }

        // Check for KeyAdded
        for key in desiredFlat.keys.sorted() {
            if observedFlat[key] == nil {
                drifts.append(DriftEvent(
                    keyPath: key,
                    type: .keyAdded,
                    observedValue: nil,
                    desiredValue: desiredFlat[key],
                    description: "Key exists in desired but not in observed"
                ))
            }
        }

        return drifts
    }

    /// Quick check: does any drift exist?
    public func hasDrift(encoded: EncodedState) -> Bool {
        return !analyzeDrift(encoded: encoded).isEmpty
    }
}
