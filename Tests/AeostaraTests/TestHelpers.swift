// Copyright (c) 2026 James Daley. All Rights Reserved.

import Foundation
@testable import AeostaraDomain

/// In-memory file system for testing. No disk I/O.
class InMemoryFileSystem: IFileSystem {
    var files: [String: String] = [:]

    func readFile(path: String) throws -> String {
        guard let content = files[path] else {
            throw AeostaraError.fileNotFound(path)
        }
        return content
    }

    func writeFile(path: String, content: String) throws {
        files[path] = content
    }

    func fileExists(path: String) -> Bool {
        return files[path] != nil
    }

    func copyFile(from sourcePath: String, to destinationPath: String) throws -> Bool {
        guard let content = files[sourcePath] else { return false }
        files[destinationPath] = content
        return true
    }

    func appendFile(path: String, content: String) throws {
        if let existing = files[path] {
            files[path] = existing + content
        } else {
            files[path] = content
        }
    }
}

/// Fixed timestamp provider for deterministic tests.
func fixedTimestamp(_ value: String = "2026-03-22T00:00:00Z") -> () -> String {
    return { value }
}

/// Sequential event ID provider for deterministic tests.
func sequentialEventID() -> () -> String {
    var counter = 0
    return {
        counter += 1
        return "event-\(counter)"
    }
}

/// Build a fully wired HealingEngine for integration testing.
func buildTestEngine(fileSystem: InMemoryFileSystem) -> HealingEngine {
    let adapter = TestConfigAdapter(fileSystem: fileSystem)
    let backupManager = BackupManager(fileSystem: fileSystem, timestampProvider: fixedTimestamp("20260322_000000"))
    let driftAnalyzer = DriftAnalyzer()
    let repairPlanner = RepairPlanner()
    let policyEvaluator = PolicyEvaluator()
    let invariantParser = InvariantParser()
    let verification = Verification(policyEvaluator: policyEvaluator)
    let rollbackManager = RollbackManager(backupProvider: backupManager)

    return HealingEngine(
        adapter: adapter,
        backupManager: backupManager,
        driftAnalyzer: driftAnalyzer,
        repairPlanner: repairPlanner,
        policyEvaluator: policyEvaluator,
        invariantParser: invariantParser,
        verification: verification,
        rollbackManager: rollbackManager,
        fileSystem: fileSystem,
        timestampProvider: fixedTimestamp(),
        eventIDProvider: sequentialEventID()
    )
}

/// Test config adapter backed by InMemoryFileSystem.
final class TestConfigAdapter: IConfigAdapter {
    private let fileSystem: InMemoryFileSystem

    init(fileSystem: InMemoryFileSystem) {
        self.fileSystem = fileSystem
    }

    func observe(filePath: String) throws -> ObservedState {
        let content = try fileSystem.readFile(path: filePath)
        guard let data = content.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AeostaraError.cannotParseJSON(filePath)
        }
        return ObservedState(
            sourceFile: filePath,
            data: parsed.mapValues { AnyCodable($0) },
            timestamp: "2026-03-22T00:00:00Z"
        )
    }

    func encode(observed: ObservedState, desired: DesiredState) -> EncodedState {
        let observedFlat = JsonPath.flatten(observed.data.mapValues { $0.value })
        let desiredFlat = JsonPath.flatten(desired.data.mapValues { $0.value })
        return EncodedState(
            observed: observedFlat.mapValues { AnyCodable($0) },
            desired: desiredFlat.mapValues { AnyCodable($0) }
        )
    }

    func applyRepair(filePath: String, plan: RepairPlan) throws -> Bool {
        let content = try fileSystem.readFile(path: filePath)
        guard let data = content.data(using: .utf8),
              var configData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        for action in plan.actions {
            switch action.actionType {
            case .set, .add:
                if let toValue = action.toValue {
                    configData = JsonPath.set(configData, dotPath: action.keyPath, value: toValue.value)
                }
            case .remove:
                configData = JsonPath.remove(configData, dotPath: action.keyPath)
            }
        }

        let outputData = try JSONSerialization.data(withJSONObject: configData, options: [.prettyPrinted, .sortedKeys])
        guard let outputString = String(data: outputData, encoding: .utf8) else { return false }
        try fileSystem.writeFile(path: filePath, content: outputString)
        return true
    }
}
