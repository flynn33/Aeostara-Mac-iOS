// Copyright (c) 2026 James Daley. All Rights Reserved.
// Aeostara — Deterministic JSON Configuration Drift Detection and Healing Platform

import Foundation
import AeostaraMacDomain

/// Foundation-based JSON config adapter. Reads, encodes, and applies repairs to JSON config files.
public final class JsonConfigAdapter: IConfigAdapter {

    private let fileSystem: IFileSystem
    private let timestampProvider: () -> String

    public init(fileSystem: IFileSystem, timestampProvider: @escaping () -> String) {
        self.fileSystem = fileSystem
        self.timestampProvider = timestampProvider
    }

    /// Read and parse a JSON config file into an ObservedState.
    public func observe(filePath: String) throws -> ObservedState {
        let content = try fileSystem.readFile(path: filePath)
        guard let data = content.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AeostaraError.cannotParseJSON(filePath)
        }

        let anyCodableData = convertToAnyCodable(parsed)

        return ObservedState(
            sourceFile: filePath,
            data: anyCodableData,
            timestamp: timestampProvider()
        )
    }

    /// Flatten and encode observed and desired states into dot-path maps.
    public func encode(observed: ObservedState, desired: DesiredState) -> EncodedState {
        let observedFlat = JsonPath.flatten(observed.data.mapValues { $0.value })
        let desiredFlat = JsonPath.flatten(desired.data.mapValues { $0.value })

        return EncodedState(
            observed: observedFlat.mapValues { AnyCodable($0) },
            desired: desiredFlat.mapValues { AnyCodable($0) }
        )
    }

    /// Apply a repair plan to a JSON config file.
    public func applyRepair(filePath: String, plan: RepairPlan) throws -> Bool {
        let content = try fileSystem.readFile(path: filePath)
        guard let data = content.data(using: .utf8),
              var configData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        for action in plan.actions {
            switch action.actionType {
            case .set:
                if let toValue = action.toValue {
                    configData = JsonPath.set(configData, dotPath: action.keyPath, value: toValue.value)
                }
            case .add:
                if let toValue = action.toValue {
                    configData = JsonPath.set(configData, dotPath: action.keyPath, value: toValue.value)
                }
            case .remove:
                configData = JsonPath.remove(configData, dotPath: action.keyPath)
            }
        }

        // Write back as pretty-printed JSON
        let outputData = try JSONSerialization.data(withJSONObject: configData, options: [.prettyPrinted, .sortedKeys])
        guard let outputString = String(data: outputData, encoding: .utf8) else {
            return false
        }

        try fileSystem.writeFile(path: filePath, content: outputString)
        return true
    }

    // MARK: - Private

    private func convertToAnyCodable(_ dict: [String: Any]) -> [String: AnyCodable] {
        return dict.mapValues { value -> AnyCodable in
            if let nested = value as? [String: Any] {
                return AnyCodable(convertToAnyCodable(nested).mapValues { $0.value })
            }
            return AnyCodable(value)
        }
    }
}
